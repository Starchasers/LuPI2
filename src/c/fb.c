#define _XOPEN_SOURCE 500

#include "res.h"
#include "lupi.h"
#include <lua.h>
#include <lualib.h>
#include <lauxlib.h>
#ifndef _WIN32
#include <sys/ioctl.h>
#include <sys/types.h>
#include <sys/mman.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <string.h>
#include <stdlib.h>
#include <math.h>
#include <unistd.h>
#include <limits.h>
#include <linux/fb.h>

int fb_ready = 0;
int fb_file;
struct fb_var_screeninfo fb_vinfo;
struct fb_fix_screeninfo fb_finfo;
char *fb_ptr = 0;
char *colbuf = 0;
ushort *chrbuf = 0;
int fb_cw, fb_ch, fb_bpp, fb_bypp, fb_xo, fb_yo, fb_pitch;
int fb_rot = 0;
int palette[256];
float pal_yuv[768];

#define XY_TO_FB(x, y) (((fb_yo + (y)) * fb_pitch) + ((fb_xo + (x)) * fb_bypp))
#define XY_TO_COLBUF(x, y, z) (((((y) * fb_cw) + (x)) * 2) + (z))
#define XY_TO_CHRBUF(x, y) (((y) * fb_cw) + (x))

static inline int fb_xrot(int x, int y) {
  switch (fb_rot) {
    default:
      return x;
    case 1:
      return fb_vinfo.xres - y - 1;
    case 2:
      return fb_vinfo.xres - x - 1;
    case 3:
      return y;
  }
}

static inline int fb_yrot(int x, int y) {
  switch (fb_rot) {
    default:
      return y;
    case 1:
      return x;
    case 2:
      return fb_vinfo.yres - y - 1;
    case 3:
      return fb_vinfo.yres - x - 1;
  }
}

static inline int fb_cxrot(int x, int y) {
  switch (fb_rot) {
    default:
      return x;
    case 1:
      return (fb_vinfo.xres >> 4) - y - 1;
    case 2:
      return (fb_vinfo.xres >> 3) - x - 1;
    case 3:
      return y;
  }
}

static inline int fb_cyrot(int x, int y) {
  switch (fb_rot) {
    default:
      return y;
    case 1:
      return x;
    case 2:
      return (fb_vinfo.yres >> 4) - y - 1;
    case 3:
      return (fb_vinfo.yres >> 3) - x - 1;
  }
}

static inline float yuv_y(int r, int g, int b) {
  float rf = r/255.0f;
  float gf = g/255.0f;
  float bf = b/255.0f;
  return 0.299f * r + 0.587f * g + 0.114f * b;
}
static inline float yuv_u(int r, int g, int b) {
  float rf = r/255.0f;
  float gf = g/255.0f;
  float bf = b/255.0f;
  return -0.147f * r - 0.289f * g + 0.436f * b;
}
static inline float yuv_v(int r, int g, int b) {
  float rf = r/255.0f;
  float gf = g/255.0f;
  float bf = b/255.0f;
  return 0.615f * r - 0.515f * g - 0.100f * b;
}

static int l_set_palette (lua_State *L) {
  int i = lua_tonumber(L, 1);
  int pal = lua_tonumber(L, 2);
  if(i >= 0 && i < 256) {
    // calculate yuv
    int r = (pal >> 16) & 0xFF;
    int g = (pal >> 8) & 0xFF;
    int b = pal & 0xFF;
    pal_yuv[i*3] = yuv_y(r, g, b);
    pal_yuv[i*3+1] = yuv_u(r, g, b);
    pal_yuv[i*3+2] = yuv_v(r, g, b);
    // set palette color
    if (fb_bpp == 16) {
      palette[i] =
        ((r & 0xF8) << 8) |
        ((g & 0xFC) << 3) |
        ((b & 0xF8) >> 3);
    } else {
      palette[i] = pal;
    }
  }
  return 0;
}

static int l_get_nearest (lua_State *L) {
  int nck = 0;
  float ncv = 1000000;
  int i;
  int col = lua_tonumber(L, 1);
  int r = (col >> 16) & 0xFF;
  int g = (col >> 8) & 0xFF;
  int b = (col) & 0xFF;
  float coly = yuv_y(r, g, b);
  float colu = yuv_u(r, g, b);
  float colv = yuv_v(r, g, b);
  float dist,dy,du,dv;
  for (i = 0; i < 256; i++) {
    if (palette[i] == col) {
      lua_pushnumber(L, i);
      return 1;
    }
    dy = coly - pal_yuv[i*3];
    du = colu - pal_yuv[i*3+1];
    dv = colv - pal_yuv[i*3+2];
    dist = dy*dy + du*du + dv*dv;
    if (dist < ncv) {
      nck = i;
      ncv = dist;
    }
  }
  lua_pushnumber(L, nck);
  return 1;
}

static int fb_copy(int x, int y, int w, int h, int x2, int y2) {
  int i, j;
  char* tmp = (char*) malloc(w*h*fb_bypp);

  for (j = 0; j < h; j++) {
    char* ptr = &fb_ptr[XY_TO_FB((x), ((y) + (j)))];
    memcpy(&tmp[w*j*fb_bypp], ptr, w*fb_bypp);
  }
  for (j = 0; j < h; j++) {
    char* ptr = &fb_ptr[XY_TO_FB((x2), (y2 + (j)))];
    memcpy(ptr, &tmp[w*j*fb_bypp], w*fb_bypp);
  }

  free(tmp);
}

static inline int fb_draw_16(int x, int y, ushort bg, ushort fg, int chr, int cwd) {
  int table[4];
  int px, py;
  int c = 0;

  if (fb_rot > 0) {
    short* ptr = (short*) &fb_ptr;
    for (py = 0; py < 16; py++) {
      if (cwd == 2) {
        c = (res_unifont[chr * 33 + 2 + (py * 2)] << 8) | res_unifont[chr * 33 + 1 + (py * 2)];
      } else if (cwd == 1) {
        c = res_unifont[chr * 33 + 1 + py];
      }
      for (px = (cwd == 2 ? 15 : 7); px >= 0; px--) {
        *((short*) &fb_ptr[XY_TO_FB(
          fb_xrot((x * 8) + px, (y * 16) + py),
          fb_yrot((x * 8) + px, (y * 16) + py)
        )]) = (c & 1) ? fg : bg;
        c >>= 1;
      }
    }
  } else {
    table[0] = bg << 16 | bg;
    table[1] = fg << 16 | bg;
    table[2] = bg << 16 | fg;
    table[3] = fg << 16 | fg;
/*    for (py = 0; py < 16; py++) {
      if (cwd == 2) {
        c = (res_unifont[chr * 33 + 2 + (py * 2)] << 8) | res_unifont[chr * 33 + 1 + (py * 2)];
      } else if (cwd == 1) {
        c = res_unifont[chr * 33 + 1 + py];
      }
      ptr = (short*) (&fb_ptr[XY_TO_FB((x * 8), ((y * 16) + py))]);
      for (px = (cwd == 2 ? 15 : 7); px >= 0; px--) {
        ptr[px] = (c & 1) ? fg : bg;
        c >>= 1;
      }
    } */
    int* ptr = (int*) (&fb_ptr[XY_TO_FB((x * 8), ((y * 16)))]);
    for (py = 0; py < 16; py++) {
      if (cwd == 2) {
        c = (res_unifont[chr * 33 + 2 + (py * 2)] << 8) | res_unifont[chr * 33 + 1 + (py * 2)];
        ptr[7] = table[(c & 3)];
        c >>= 2;
        ptr[6] = table[(c & 3)];
        c >>= 2;
        ptr[5] = table[(c & 3)];
        c >>= 2;
        ptr[4] = table[(c & 3)];
        c >>= 2;
        ptr[3] = table[(c & 3)];
        c >>= 2;
        ptr[2] = table[(c & 3)];
        c >>= 2;
        ptr[1] = table[(c & 3)];
        c >>= 2;
        ptr[0] = table[(c & 3)];
        c >>= 2;
      } else if (cwd == 1) {
        c = res_unifont[chr * 33 + 1 + py];
        ptr[3] = table[(c & 3)];
        c >>= 2;
        ptr[2] = table[(c & 3)];
        c >>= 2;
        ptr[1] = table[(c & 3)];
        c >>= 2;
        ptr[0] = table[(c & 3)];
        c >>= 2;
      }
      ptr += fb_pitch >> 2;
    }
  }
}

static inline int fb_draw_32(int x, int y, int bg, int fg, int chr, int cwd) {
  int px, py;
  int c = 0;
  int* ptr;
  if (fb_rot > 0) {
    for (py = 0; py < 16; py++) {
      if (cwd == 2) {
        c = (res_unifont[chr * 33 + 2 + (py * 2)] << 8) | res_unifont[chr * 33 + 1 + (py * 2)];
      } else if (cwd == 1) {
        c = res_unifont[chr * 33 + 1 + py];
      }
      for (px = (cwd == 2 ? 15 : 7); px >= 0; px--) {
        *((int*) &fb_ptr[XY_TO_FB(
          fb_xrot((x * 8) + px, (y * 16) + py),
          fb_yrot((x * 8) + px, (y * 16) + py)
        )]) = (c & 1) ? fg : bg;
        c >>= 1;
      }
    }
  } else {
    ptr = (int*) (&fb_ptr[XY_TO_FB((x * 8), ((y * 16) + py))]);
    for (py = 0; py < 16; py++) {
      if (cwd == 2) {
        c = (res_unifont[chr * 33 + 2 + (py * 2)] << 8) | res_unifont[chr * 33 + 1 + (py * 2)];
      } else if (cwd == 1) {
        c = res_unifont[chr * 33 + 1 + py];
      }
      for (px = (cwd == 2 ? 15 : 7); px >= 0; px--) {
        ptr[px] = (c & 1) ? fg : bg;
        c >>= 1;
      }
      ptr += fb_pitch >> 2;
    }
  }
}

static int fb_draw(int x, int y, int bg, int fg, int chr) {
  if (x < 0 || x >= fb_cw || y < 0 || y >= fb_ch || bg < 0 || bg >= 256 || fg < 0 || fg >= 256
     || chr < 0 || chr >= 65536) {
    return 0;
  }

  colbuf[XY_TO_COLBUF(x, y, 0)] = (char) bg;
  colbuf[XY_TO_COLBUF(x, y, 1)] = (char) fg;
  chrbuf[XY_TO_CHRBUF(x, y)] = (ushort) chr;

  int cwd = res_unifont[chr * 33];
  if (cwd == 2 && x < (fb_cw - 1)) {
    chrbuf[XY_TO_CHRBUF(x + 1, y)] = (ushort) 0;
  }
  if (fb_bpp == 32) {
    fb_draw_32(x,y,palette[bg],palette[fg],chr,cwd);
  } else if (fb_bpp == 16) {
    fb_draw_16(x,y,(ushort) palette[bg],(ushort) palette[fg],chr,cwd);
  }
  return 0;
}

static int l_fbput (lua_State *L) {
  int x = lua_tonumber(L, 1);
  int y = lua_tonumber(L, 2);
  int bg = lua_tonumber(L, 3);
  int fg = lua_tonumber(L, 4);
  int chr = lua_tonumber(L, 5);
  return fb_draw(x, y, bg, fg, chr);
}

static int l_fbcopy (lua_State *L) {
  int x = lua_tonumber(L, 1);
  int y = lua_tonumber(L, 2);
  int w = lua_tonumber(L, 3);
  int h = lua_tonumber(L, 4);
  int tx = x+lua_tonumber(L, 5);
  int ty = y+lua_tonumber(L, 6);
  int j, px = x<<3, py = y<<4, pw = w<<3, ph = h<<4, ptx = tx<<3, pty = ty<<4;

  char* tmpcol = (char*) malloc(w*h*2);
  char* tmpchr = (char*) malloc(w*h*2);

  if (fb_rot == 1 || fb_rot == 3) {
    j = pw;
    pw = ph;
    ph = j;
  }
  j = fb_xrot(px, py);
  py = fb_yrot(px, py);
  px = j;
  j = fb_xrot(ptx, pty);
  pty = fb_yrot(ptx, pty);
  ptx = j;

  if (fb_rot == 1 || fb_rot == 2) {
    px -= pw-1;
    ptx -= pw-1;
  }
  if (fb_rot == 3 || fb_rot == 2) {
    py -= ph-1;
    pty -= ph-1;
  }

  for (j = 0; j < h; j++) {
    memcpy(&tmpcol[j*w*2], &colbuf[XY_TO_COLBUF(x, y+j, 0)], w * 2);
    memcpy(&tmpchr[j*w*2], &chrbuf[XY_TO_CHRBUF(x, y+j)], w * 2);
  }

  fb_copy(px, py, pw, ph, ptx, pty);

  for (j = 0; j < h; j++) {
    memcpy(&colbuf[XY_TO_COLBUF(tx, ty+j, 0)], &tmpcol[j*w*2], w * 2);
    memcpy(&chrbuf[XY_TO_CHRBUF(tx, ty+j)], &tmpchr[j*w*2], w * 2);
  }

  free(tmpcol);
  free(tmpchr);
}

static int l_fbfill (lua_State *L) {
  int x1 = lua_tonumber(L, 1);
  int y1 = lua_tonumber(L, 2);
  int x2 = lua_tonumber(L, 3);
  int y2 = lua_tonumber(L, 4);
  int bg = lua_tonumber(L, 5);
  int fg = lua_tonumber(L, 6);
  int chr = lua_tonumber(L, 7);
  int i, j;
  for (i = y1; i <= y2; i++) {
    for (j = x1; j <= x2; j++) {
      fb_draw(j, i, bg, fg, chr);
    }
  }
  return 0;
}

static int l_get_width (lua_State *L) {
  lua_pushnumber(L, fb_cw);
  return 1;
}

static int l_get_height (lua_State *L) {
  lua_pushnumber(L, fb_ch);
  return 1;
}

static int l_fb_getbg (lua_State *L) {
  int x = lua_tonumber(L, 1);
  int y = lua_tonumber(L, 2);
  if (x >= 0 && y >= 0 && x < fb_cw && y < fb_ch) {
    lua_pushnumber(L, colbuf[XY_TO_COLBUF(x, y, 0)]);
  } else {
    lua_pushnumber(L, 0);
  }
  return 1;
}

static int l_fb_getfg (lua_State *L) {
  int x = lua_tonumber(L, 1);
  int y = lua_tonumber(L, 2);
  if (x >= 0 && y >= 0 && x < fb_cw && y < fb_ch) {
    lua_pushnumber(L, colbuf[XY_TO_COLBUF(x, y, 1)]);
  } else {
    lua_pushnumber(L, 0);
  }
  return 1;
}

static int l_fb_get (lua_State *L) {
  int x = lua_tonumber(L, 1);
  int y = lua_tonumber(L, 2);
  if (x >= 0 && y >= 0 && x < fb_cw && y < fb_ch) {
    lua_pushnumber(L, chrbuf[XY_TO_CHRBUF(x, y)]);
  } else {
    lua_pushnumber(L, 0);
  }
  return 1;
}

#endif

static int l_fb_ready (lua_State *L) {
#ifndef _WIN32
  lua_pushboolean(L, fb_ready);
#else
  lua_pushboolean(L, 0);
#endif
  return 1;
}

void fb_start(lua_State *L) {
#ifndef _WIN32
   fb_file = open("/dev/fb0", O_RDWR);
   if (fb_file == -1) {
     printf("Error: cannot open framebuffer device");
     exit(1);
     return;
   }

  if (ioctl(fb_file, FBIOGET_FSCREENINFO, &fb_finfo) == -1) {
     printf("Error reading fixed information");
     exit(1);
     return;
  }

  if (ioctl(fb_file, FBIOGET_VSCREENINFO, &fb_vinfo) == -1) {
    printf("Error reading variable information");
    exit(1);
    return;
  }

  fb_vinfo.bits_per_pixel = 16;
  if (fb_rot == 1 || fb_rot == 3) {
    fb_cw = fb_vinfo.yres / 8;
    fb_ch = fb_vinfo.xres / 16;
  } else {
    fb_cw = fb_vinfo.xres / 8;
    fb_ch = fb_vinfo.yres / 16;
  }
  if (ioctl(fb_file, FBIOPUT_VSCREENINFO, &fb_vinfo) == -1) {
    fb_vinfo.bits_per_pixel = 32;
    if (ioctl(fb_file, FBIOPUT_VSCREENINFO, &fb_vinfo) == -1) {
      printf("Error setting 32 or 16BPP mode");
      exit(1);
      return;
    }
  }

  fb_bpp = fb_vinfo.bits_per_pixel;
  fb_bypp = fb_bpp >> 3;
  fb_pitch = fb_vinfo.xres_virtual * fb_bypp;
  fb_xo = fb_vinfo.xoffset;
  fb_yo = fb_vinfo.yoffset;

  fb_ptr = (char *)mmap(0, fb_vinfo.xres * fb_vinfo.yres * fb_bypp, PROT_READ | PROT_WRITE, MAP_SHARED, fb_file, 0);
  if ((intptr_t)fb_ptr == -1) {
    printf("Failed to map framebuffer device to memory");
    exit(1);
    return;
  }

  colbuf = (char *)malloc(2 * fb_cw * fb_ch);
  chrbuf = (ushort *)malloc(2 * fb_cw * fb_ch);

  fb_ready = 1;

#endif

  struct luaL_Reg fblib[] = {
#ifndef _WIN32
    {"setPalette", l_set_palette},
    {"getWidth", l_get_width},
    {"getHeight", l_get_height},
    {"put", l_fbput},
    {"copy", l_fbcopy},
    {"fill", l_fbfill},
    {"getBackground", l_fb_getbg},
    {"getForeground", l_fb_getfg},
    {"get", l_fb_get},
    {"getNearest", l_get_nearest},
#endif
    {"isReady", l_fb_ready},
    {NULL, NULL}
  };

  luaL_openlib(L, "framebuffer", fblib, 0);
}
