#define _XOPEN_SOURCE 500

#include "lupi.h"
#include <lua.h>
#include <lualib.h>
#include <lauxlib.h>
#include <sys/ioctl.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <sys/statvfs.h>
#include <sys/time.h>
#include <string.h>
#include <stdlib.h>
#include <unistd.h>
#include <fcntl.h>
#include <dirent.h>
#include <ftw.h>
#include <wchar.h>
#include <limits.h>
#include <linux/kd.h>

/* Enable in lupi.h */
#ifdef LOGGING
void logn(const char *message) {
  FILE *file;

  file = fopen("lupi.log", "a");
    
  if (file == NULL) {
    return;
  } else {
    fputs(message, file);
    fputs("\n", file);
    fclose(file);
  }
}

void logi(int message) {
  FILE *file;

  file = fopen("lupi.log", "a");
    
  if (file == NULL) {
    return;
  } else {
    char str[15]={0,0,0,0,0,0,0,0,0,0,0,0,0,0,0};
    sprintf(str, "%d", message);
    fputs(str, file);
    fclose(file);
  }
}

void logm(const char *message) {
  FILE *file;

  file = fopen("lupi.log", "a");
    
  if (file == NULL) {
    return;
  } else {
    fputs(message, file);
    fclose(file);
  }
}
#else
#define logn(m)
#define logi(m)
#define logm(m)
#endif

static int l_sleep (lua_State *L) {
  unsigned int t = lua_tonumber(L, 1);
  usleep(t);
  return 0;
}

/* Filesystem methods */
static int l_fs_exists (lua_State *L) {
  const char* fname = lua_tostring(L, 1);
  if( access( fname, F_OK ) != -1 ) {
    lua_pushboolean(L, 1);
  } else {
    lua_pushboolean(L, 0);
  }
  return 1;
}

static int l_fs_mkdir (lua_State *L) {
  const char* fname = lua_tostring(L, 1);
  if( mkdir( fname, 0755 ) != -1 ) {
    lua_pushboolean(L, 1);
  } else {
    lua_pushboolean(L, 0);
  }
  return 1;
}

static int l_fs_isdir (lua_State *L) {
  const char* fname = lua_tostring(L, 1);
  struct stat s;
  int err = stat(fname, &s);
  if(-1 == err) {
    lua_pushboolean(L, 0);
  } else {
    if(S_ISDIR(s.st_mode)) {
      lua_pushboolean(L, 1);
    } else {
      lua_pushboolean(L, 0);
    }
  }
  return 1;
}

static int l_fs_spaceUsed (lua_State *L) {
  const char* fname = lua_tostring(L, 1);
  struct statvfs s;
  if( statvfs(fname, &s) != -1 ) {
    lua_pushnumber(L, s.f_bsize * s.f_bfree);
  } else {
    lua_pushnumber(L, -1);
  }
  return 1;
}

static int l_fs_open (lua_State *L) {
  const char* fname = lua_tostring(L, 1);
  const char* mode = lua_tostring(L, 2);
  logm("Open file: ");
  logn(fname);
  int m = 0;
  if(mode[0] == 'r') m = O_RDONLY;
  else if(mode[0] == 'w') m = O_WRONLY | O_CREAT /*| O_DIRECT*/;
  else if(mode[0] == 'a') m = O_WRONLY | O_APPEND | O_CREAT /*| O_DIRECT*/;
  else return 0;
  int fd = open(fname, m, 0644);

  if(fd == -1) return 0;
  logm("FD ");
  logi(fd);
  logm(" for ");
  logn(fname);
  lua_pushnumber(L, fd);
  return 1;
}

static int l_fs_seek (lua_State *L) {
  int fd = lua_tonumber(L, 1);
  int whence = lua_tonumber(L, 2);
  long offset = lua_tonumber(L, 3);

  int w = 0;
  if(whence == 0) w = SEEK_CUR;
  else if(whence == 1) w = SEEK_SET;
  else if(whence == 2) w = SEEK_END;
  else return 0;
  int res = lseek(fd, w, offset);
  lua_pushnumber(L, res);
  return 1;
}

static int l_fs_write (lua_State *L) {
  int fd = lua_tonumber(L, 1);
  size_t len = 0;
  const char* data = lua_tolstring(L, 2, &len);

  /* TODO: May not all data be written? */
  if(write(fd, data, len) == -1) {
    lua_pushboolean(L, 0);
  } else {
    lua_pushboolean(L, 1);
  }
  return 1;
}

static int l_fs_spaceTotal (lua_State *L) {
  const char* fname = lua_tostring(L, 1);
  struct statvfs s;
  if( statvfs(fname, &s) != -1 ) {
    lua_pushnumber(L, s.f_frsize * s.f_blocks);
  } else {
    lua_pushnumber(L, -1);
  }
  return 1;
}

static int l_fs_rename (lua_State *L) {
  const char* from = lua_tostring(L, 1);
  const char* to = lua_tostring(L, 1);
  if( rename( from, to ) != -1 ) {
    lua_pushboolean(L, 1);
  } else {
    lua_pushboolean(L, 0);
  }
  return 1;
}

static int l_fs_list (lua_State *L) {
  const char* path = lua_tostring(L, 1);
  
  DIR *dir;
  struct dirent *ent;
  if ((dir = opendir(path)) != NULL) {
    lua_newtable(L);
    int n = 1;
    while ((ent = readdir(dir)) != NULL) { /* TODO: Check if it should be freed */
      if(strcmp(ent->d_name, ".") != 0 && strcmp(ent->d_name, "..") != 0) {
        lua_pushstring(L, ent->d_name);
        lua_rawseti(L, -2, n++);
      }
    }
    closedir(dir);
  } else {
    return 0;
  }
  return 1;
}

static int l_fs_lastModified (lua_State *L) {
  const char* path = lua_tostring(L, 1);
  struct stat s;
  if( stat(path, &s) != -1 ) {
    lua_pushnumber(L, s.st_mtime);
  } else {
    return 0; /* TODO: No error? */
  }
  return 1;
}

static int rm(const char *path, const struct stat *s, int flag, struct FTW *f) {
    int status;
    int (*rm_func)(const char *);

    switch(flag) {
      default:     rm_func = unlink; break;
      case FTW_DP: rm_func = rmdir;
    }
    if(status = rm_func(path), status != 0)
        perror(path);
    return status;
}

static int l_fs_remove (lua_State *L) {
  const char* path = lua_tostring(L, 1);

  if( nftw( path, rm, FOPEN_MAX, FTW_DEPTH )) {
    lua_pushboolean(L, 0);
  } else {
    lua_pushboolean(L, 1);
  }
  return 1;
}

static int l_fs_close (lua_State *L) {
  int fd = lua_tonumber(L, 1);

  if(close(fd) == -1) {
    lua_pushboolean(L, 0);
  } else {
    lua_pushboolean(L, 1);
  }
  return 1;
}

static int l_fs_size (lua_State *L) {
  const char* path = lua_tostring(L, 1);
  struct stat s;
  if( stat(path, &s) != -1 ) {
    lua_pushnumber(L, s.st_size);
  } else {
    return 0; /* TODO: No error? */
  }
  return 1;
}

static int l_fs_read (lua_State *L) {
  unsigned int fd = lua_tonumber(L, 1);
  unsigned int count = lua_tonumber(L, 2);
  size_t cur = lseek(fd, 0, SEEK_CUR);
  size_t end = lseek(fd, 0, SEEK_END);
  lseek(fd, cur, SEEK_SET);
  if(count > end - cur)
    count = end - cur;
  void* buf = malloc(count);
  size_t res = read(fd, buf, count);
  logm("read(");
  logi(fd);
  logm(") bytes:");
  logi(res);
  logm(" of ");
  logi(count);
  logn("");

  if(res > 0) {
    lua_pushlstring(L, buf, res);
    free(buf);
    return 1;
  }
  free(buf);
  return 0;
}

#ifndef CLOCK_TICK_RATE
#define CLOCK_TICK_RATE 1193180
#endif

/* Filesystem end */
static int l_beep (lua_State *L) {
  int freq = lua_tonumber(L, 1);
  int btime = lua_tonumber(L, 2);
  int console_fd = -1;

  if((console_fd = open("/dev/console", O_WRONLY)) == -1) {
    printf("\a");
    return 0;
  }

  if(ioctl(console_fd, KIOCSOUND, (int)(CLOCK_TICK_RATE/freq)) < 0) {
    printf("\a");
    return 0;
  }

  usleep(1000 * btime);
  ioctl(console_fd, KIOCSOUND, 0);
  close(console_fd);
  return 0;
}

static int l_uptime (lua_State *L) { /* Return ms */
  struct timeval tp;
  gettimeofday(&tp, NULL);
  lua_pushnumber(L, tp.tv_sec * 1000 + tp.tv_usec / 1000);
  return 1;
}

static int l_totalMemory (lua_State *L) {
  long pages = sysconf(_SC_PHYS_PAGES);
  long page_size = sysconf(_SC_PAGE_SIZE);
  lua_pushnumber(L, pages * page_size);
  return 1;
}

static int l_freeMemory (lua_State *L) {
  long pages = sysconf(_SC_AVPHYS_PAGES);
  long page_size = sysconf(_SC_PAGE_SIZE);
  lua_pushnumber(L, pages * page_size);
  return 1;
}

static int l_pull (lua_State *L) {
  lua_pushnumber(L, epoll_pull(lua_tonumber(L, 1)));
  return 1;
}

static int l_wcwidth (lua_State *L) {
  lua_pushnumber(L, wcwidth(lua_tonumber(L, 1)));
  return 1;
}

static int l_towupper (lua_State *L) {
  lua_pushnumber(L, towupper(lua_tonumber(L, 1)));
  return 1;
}

static int l_towlower (lua_State *L) {
  lua_pushnumber(L, towlower(lua_tonumber(L, 1)));
  return 1;
}

void luanative_start(lua_State *L) {
  lua_createtable (L, 0, 1);
  
  pushctuple(L, "sleep", l_sleep);

  pushctuple(L, "fs_exists", l_fs_exists);
  pushctuple(L, "fs_mkdir", l_fs_mkdir);
  pushctuple(L, "fs_isdir", l_fs_isdir);
  pushctuple(L, "fs_spaceUsed", l_fs_spaceUsed);
  pushctuple(L, "fs_open", l_fs_open);
  pushctuple(L, "fs_seek", l_fs_seek);
  pushctuple(L, "fs_write", l_fs_write);
  pushctuple(L, "fs_spaceTotal", l_fs_spaceTotal);
  pushctuple(L, "fs_rename", l_fs_rename);
  pushctuple(L, "fs_list", l_fs_list);
  pushctuple(L, "fs_lastModified", l_fs_lastModified);
  pushctuple(L, "fs_remove", l_fs_remove);
  pushctuple(L, "fs_close", l_fs_close);
  pushctuple(L, "fs_size", l_fs_size);
  pushctuple(L, "fs_read", l_fs_read);

  pushctuple(L, "wcwidth", l_wcwidth);
  pushctuple(L, "towlower", l_towlower);
  pushctuple(L, "towupper", l_towupper);

  pushctuple(L, "beep", l_beep);
  pushctuple(L, "uptime", l_uptime);
  pushctuple(L, "totalMemory", l_totalMemory);
  pushctuple(L, "freeMemory", l_freeMemory);
  pushctuple(L, "pull", l_pull);

  lua_setglobal(L, "native");
}
