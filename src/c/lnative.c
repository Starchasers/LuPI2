#define _XOPEN_SOURCE 500

#include "lupi.h"
#include <lua.h>
#include <lualib.h>
#include <lauxlib.h>
#ifndef _WIN32
#include <sys/ioctl.h>
#include <sys/statvfs.h>
#else
#include <windows.h>
#endif
#include <sys/types.h>
#include <sys/stat.h>
#include <sys/time.h>
#include <string.h>
#include <stdlib.h>
#include <unistd.h>
#include <fcntl.h>
#include <dirent.h>
#include <ftw.h>
#include <wchar.h>
#include <limits.h>
/* #include <sys/kd.h> */

#define KIOCSOUND 0x4B2F  /* start sound generation (0 for off) */

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

static int l_log (lua_State *L) {
  const char* t = lua_tostring(L, 1);
  logn(t);
  return 0;
}

#else
#define logn(m)
#define logi(m)
#define logm(m)
static int l_log (lua_State *L) {
  return 0;
}
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
#ifndef _WIN32
  if( mkdir( fname, 0755 ) != -1 ) {
#else
    if( mkdir( fname ) != -1 ) {
#endif
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
#ifndef _WIN32
  struct statvfs s;
  if( statvfs(fname, &s) != -1 ) {
    lua_pushnumber(L, s.f_bsize * s.f_bfree);
  } else {
    lua_pushnumber(L, -1);
  }
#else
  lua_pushnumber(L, -1);
#endif
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
#ifndef _WIN32
  struct statvfs s;
  if( statvfs(fname, &s) != -1 ) {
    lua_pushnumber(L, s.f_frsize * s.f_blocks);
  } else {
    lua_pushnumber(L, -1);
  }
#else
  lua_pushnumber(L, -1);
#endif
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
#ifndef _WIN32
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
#endif /* TODO win32 implementation */
  return 0;
}

static int l_uptime (lua_State *L) { /* Return ms */
  struct timeval tp;
  gettimeofday(&tp, NULL);
  lua_pushnumber(L, tp.tv_sec * 1000 + tp.tv_usec / 1000);
  return 1;
}

static int l_totalMemory (lua_State *L) {
#if defined(_WIN32) && (defined(__CYGWIN__) || defined(__CYGWIN32__))
  MEMORYSTATUS status;
  status.dwLength = sizeof(status);
  GlobalMemoryStatus( &status );
  lua_pushnumber(L, status.dwTotalPhys);
#elif defined(_WIN32)
  MEMORYSTATUSEX status;
  status.dwLength = sizeof(status);
  GlobalMemoryStatusEx( &status );
  lua_pushnumber(L, (size_t)status.ullTotalPhys);
#else
  long pages = sysconf(_SC_PHYS_PAGES);
  long page_size = sysconf(_SC_PAGE_SIZE);
  lua_pushnumber(L, pages * page_size);
#endif
  return 1;
}

static int l_freeMemory (lua_State *L) {
#if defined(_WIN32) && (defined(__CYGWIN__) || defined(__CYGWIN32__))
  MEMORYSTATUS status;
  status.dwLength = sizeof(status);
  GlobalMemoryStatus( &status );
  lua_pushnumber(L, status.dwAvailPhys);
#elif defined(_WIN32)
  MEMORYSTATUSEX status;
  status.dwLength = sizeof(status);
  GlobalMemoryStatusEx( &status );
  lua_pushnumber(L, (size_t)status.ullAvailPhys);
#else
  long pages = sysconf(_SC_AVPHYS_PAGES);
  long page_size = sysconf(_SC_PAGE_SIZE);
  lua_pushnumber(L, pages * page_size);
#endif
  return 1;
}

static int l_pull (lua_State *L) {
  lua_pushnumber(L, event_pull(lua_tonumber(L, 1)));
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

static int l_platform (lua_State *L) { /* returns platform identifiers separated by | */
#ifndef _WIN32
  lua_pushstring(L, "unix|linux|other");
#else
  lua_pushstring(L, "windows");
#endif
  return 1;
}

#ifdef DEBUG
static int l_debug (lua_State *L) {
  return 0;
}
#endif

void luanative_start(lua_State *L) {

  struct luaL_Reg nativelib[] = {
    {"sleep", l_sleep},
    {"log", l_log},
    {"fs_exists", l_fs_exists},
    {"fs_mkdir", l_fs_mkdir},
    {"fs_isdir", l_fs_isdir},
    {"fs_spaceUsed", l_fs_spaceUsed},
    {"fs_open", l_fs_open},
    {"fs_seek", l_fs_seek},
    {"fs_write", l_fs_write},
    {"fs_spaceTotal", l_fs_spaceTotal},
    {"fs_rename", l_fs_rename},
    {"fs_list", l_fs_list},
    {"fs_lastModified", l_fs_lastModified},
    {"fs_remove", l_fs_remove},
    {"fs_close", l_fs_close},
    {"fs_size", l_fs_size},
    {"fs_read", l_fs_read},
    {"wcwidth", l_wcwidth},
    {"towlower", l_towlower},
    {"towupper", l_towupper},
    {"beep", l_beep},
    {"uptime", l_uptime},
    {"totalMemory", l_totalMemory},
    {"freeMemory", l_freeMemory},
    {"pull", l_pull},
    {"platform", l_platform},
    #ifdef DEBUG
      {"debug", l_debug},
    #endif
    {NULL, NULL}
  };

  luaL_openlib(L, "native", nativelib, 0);
}
