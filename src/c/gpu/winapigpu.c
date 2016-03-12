#ifdef _WIN32
#include "res.h"
#include "lupi.h"
#include <lua.h>
#include <lualib.h>
#include <lauxlib.h>
#include <windows.h>
#include <pthread.h>
#include <time.h>

#define BYPP 4
#define RES_X 800
#define RES_Y 600
#define CHARSW (RES_X / 8)
#define CHARSH (RES_Y / 16)

#define XY_TO_WIN(x, y) (((y) * RES_X * BYPP) + ((x) * BYPP))
#define XY_TO_COLBUF(x, y, z) (((((y) * CHARSW) + (x)) * 2) + (z))
#define XY_TO_CHRBUF(x, y) (((y) * CHARSW) + (x))

#define WINDOW_CLASS "LuPi2 GPU"
#define WINDOW_TITLE "LuPi2"

#define uchar unsigned char

HWND hwnd;
uchar *screenbb = NULL;
HBITMAP screenbmap = NULL;
char *colbuf = 0;
ushort *chrbuf = 0;
int palette[256];
float pal_yuv[768];

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

/**************************************/

static inline int win_draw_32(int x, int y, int bg, int fg, int chr, int cwd) {
  int px, py;
  int c = 0;
  int* ptr;

  ptr = (int*) (&screenbb[XY_TO_WIN((x * 8), ((y * 16) + py))]);
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
    ptr += (RES_X * BYPP) >> 2;
  }
}

void pokeWinEvt(char ch);

LRESULT CALLBACK WndProc(HWND hwnd, UINT msg, WPARAM wParam, LPARAM lParam) {
  switch(msg) {
    case WM_PAINT: {
        PAINTSTRUCT ps;
        HDC hdc = BeginPaint(hwnd, &ps);
        screenbmap = CreateBitmap(RES_X, RES_Y, 1, BYPP * 8, (void*) screenbb);

        HDC src = CreateCompatibleDC(hdc);
        SelectObject(src, screenbmap);
        BitBlt(hdc, 0, 0, RES_X, RES_Y, src, 0, 0, SRCCOPY);
        DeleteDC(src);
        EndPaint(hwnd, &ps);
      }
      break;
    case WM_CHAR:
    //case WM_UNICHAR:
    //case WM_KEYUP:
    //case WM_KEYDOWN:
      pokeWinEvt(wParam);
      break;
    case WM_CREATE:
      logn("win: Create");
      screenbb = (uchar*) calloc(RES_X * RES_Y, BYPP);

      colbuf = (char*) malloc(2 * CHARSW * CHARSH);
      chrbuf = (ushort*) malloc(2 * CHARSW * CHARSH);

      break;
    case WM_CLOSE:
      DestroyWindow(hwnd);
      exit(0); /* TODO: Push exit event? Or just remove gpu component?? */
      break;
    case WM_DESTROY:
      PostQuitMessage(0);
      break;
    default:
      return DefWindowProc(hwnd, msg, wParam, lParam);
  }
  return 0;
}

static int win_draw(int x, int y, int bg, int fg, int chr);

void* winapigpu_events(void* ign) {
  logn("win: INIT");
  WNDCLASSEX wc;

  wc.cbSize        = sizeof(WNDCLASSEX);
  wc.style         = 0;
  wc.lpfnWndProc   = WndProc;
  wc.cbClsExtra    = 0;
  wc.cbWndExtra    = 0;
  wc.hInstance     = GetModuleHandle(NULL);
  wc.hIcon         = LoadIcon(NULL, IDI_APPLICATION);
  wc.hCursor       = LoadCursor(NULL, IDC_ARROW);
  wc.hbrBackground = (HBRUSH)(COLOR_WINDOW+1);
  wc.lpszMenuName  = NULL;
  wc.lpszClassName = WINDOW_CLASS;
  wc.hIconSm       = LoadIcon(NULL, IDI_APPLICATION);

  if(!RegisterClassEx(&wc)) {
    return 0;
  }

  hwnd = CreateWindowEx(
    WS_EX_CLIENTEDGE,
    WINDOW_CLASS,
    WINDOW_TITLE,
    WS_OVERLAPPEDWINDOW,
    CW_USEDEFAULT, CW_USEDEFAULT, RES_X, RES_Y,
    NULL, NULL, GetModuleHandle(NULL), NULL);

  if(hwnd == NULL) {
    return 0;
  }

  ShowWindow(hwnd, SW_SHOW);
  UpdateWindow(hwnd);

  InvalidateRect(hwnd, NULL, TRUE); 

  win_draw(0,0,0,0xFFFFFF,'H');

  MSG Msg;
  while(GetMessage(&Msg, NULL, 0, 0) > 0) {
    TranslateMessage(&Msg);
    DispatchMessage(&Msg);
  }
  logn("winapi quit!!");
  return NULL;
}

static int l_open(lua_State *L) {
  pthread_t eventThread;
  pthread_attr_t attr;
  pthread_attr_init(&attr);
  pthread_attr_setstacksize(&attr, 0x800000);
  pthread_create(&eventThread, &attr, winapigpu_events, NULL);
  pthread_attr_destroy(&attr);

  struct timespec st = {.tv_sec = 0, .tv_nsec = 1000000};
  while(!screenbb) nanosleep(&st, NULL);
  lua_pushboolean(L, 1);
  return 1;
}

/**************************************/

static int win_draw(int x, int y, int bg, int fg, int chr) {
  if (x < 0 || x >= CHARSW || y < 0 || y >= CHARSH || bg < 0 || bg >= 256 || fg < 0 || fg >= 256
     || chr < 0 || chr >= 65536) {
    return 0;
  }

  colbuf[XY_TO_COLBUF(x, y, 0)] = (char) bg;
  colbuf[XY_TO_COLBUF(x, y, 1)] = (char) fg;
  chrbuf[XY_TO_CHRBUF(x, y)] = (ushort) chr;

  int cwd = res_unifont[chr * 33];
  if (cwd == 2 && x < (CHARSW - 1)) {
    chrbuf[XY_TO_CHRBUF(x + 1, y)] = (ushort) 0;
  }
  win_draw_32(x,y,palette[bg],palette[fg],chr,cwd);
  return 0;
}

static int win_copy(int x, int y, int w, int h, int x2, int y2) {
  int i, j;
  char* tmp = (char*) malloc(w*h*BYPP);

  for (j = 0; j < h; j++) {
    char* ptr = &screenbb[XY_TO_WIN((x), ((y) + (j)))];
    memcpy(&tmp[w*j*BYPP], ptr, w*BYPP);
  }
  for (j = 0; j < h; j++) {
    char* ptr = &screenbb[XY_TO_WIN((x2), (y2 + (j)))];
    memcpy(ptr, &tmp[w*j*BYPP], w*BYPP);
  }

  free(tmp);
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

    palette[i] = pal;
  }
  return 0;
}

static int l_put (lua_State *L) {
  int x = lua_tonumber(L, 1);
  int y = lua_tonumber(L, 2);
  int bg = lua_tonumber(L, 3);
  int fg = lua_tonumber(L, 4);
  int chr = lua_tonumber(L, 5);
  win_draw(x, y, bg, fg, chr);
  InvalidateRect(hwnd, NULL, FALSE);
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

static int l_copy (lua_State *L) {
  int x = lua_tonumber(L, 1);
  int y = lua_tonumber(L, 2);
  int w = lua_tonumber(L, 3);
  int h = lua_tonumber(L, 4);
  int tx = x+lua_tonumber(L, 5);
  int ty = y+lua_tonumber(L, 6);
  int j, px = x<<3, py = y<<4, pw = w<<3, ph = h<<4, ptx = tx<<3, pty = ty<<4;

  char* tmpcol = (char*) malloc(w*h*2);
  char* tmpchr = (char*) malloc(w*h*2);

  for (j = 0; j < h; j++) {
    memcpy(&tmpcol[j*w*2], &colbuf[XY_TO_COLBUF(x, y+j, 0)], w * 2);
    memcpy(&tmpchr[j*w*2], &chrbuf[XY_TO_CHRBUF(x, y+j)], w * 2);
  }

  win_copy(px, py, pw, ph, ptx, pty);

  for (j = 0; j < h; j++) {
    memcpy(&colbuf[XY_TO_COLBUF(tx, ty+j, 0)], &tmpcol[j*w*2], w * 2);
    memcpy(&chrbuf[XY_TO_CHRBUF(tx, ty+j)], &tmpchr[j*w*2], w * 2);
  }

  free(tmpcol);
  free(tmpchr);
  InvalidateRect(hwnd, NULL, FALSE);
}

static int l_fill (lua_State *L) {
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
      win_draw(j, i, bg, fg, chr);
    }
  }
  InvalidateRect(hwnd, NULL, FALSE);
  return 0;
}

static int l_winfill (lua_State *L) {
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
      win_draw(j, i, bg, fg, chr);
    }
  }
  InvalidateRect(hwnd, NULL, FALSE);
  return 0;
}

static int l_get_width (lua_State *L) {
  lua_pushnumber(L, CHARSW);
  return 1;
}

static int l_get_height (lua_State *L) {
  lua_pushnumber(L, CHARSH);
  return 1;
}

static int l_getbg (lua_State *L) {
  int x = lua_tonumber(L, 1);
  int y = lua_tonumber(L, 2);
  if (x >= 0 && y >= 0 && x < CHARSW && y < CHARSH) {
    lua_pushnumber(L, colbuf[XY_TO_COLBUF(x, y, 0)]);
  } else {
    lua_pushnumber(L, 0);
  }
  return 1;
}

static int l_getfg (lua_State *L) {
  int x = lua_tonumber(L, 1);
  int y = lua_tonumber(L, 2);
  if (x >= 0 && y >= 0 && x < CHARSW && y < CHARSH) {
    lua_pushnumber(L, colbuf[XY_TO_COLBUF(x, y, 1)]);
  } else {
    lua_pushnumber(L, 0);
  }
  return 1;
}

static int l_get (lua_State *L) {
  int x = lua_tonumber(L, 1);
  int y = lua_tonumber(L, 2);
  if (x >= 0 && y >= 0 && x < CHARSW && y < CHARSH) {
    lua_pushnumber(L, chrbuf[XY_TO_CHRBUF(x, y)]);
  } else {
    lua_pushnumber(L, 0);
  }
  return 1;
}

void winapigpu_init(lua_State* L) {
  struct luaL_Reg winlib[] = {
    {"open", l_open},

    {"setPalette", l_set_palette},
    {"getWidth", l_get_width},
    {"getHeight", l_get_height},
    {"put", l_put},
    {"copy", l_copy},
    {"fill", l_fill},
    {"getBackground", l_getbg},
    {"getForeground", l_getfg},
    {"get", l_get},
    {"getNearest", l_get_nearest},

    {NULL, NULL}
  };

  luaL_openlib(L, "winapigpu", winlib, 0);
}

#endif
