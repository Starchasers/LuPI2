#ifdef _WIN32
#include "res.h"
#include "lupi.h"
#include <lua.h>
#include <lualib.h>
#include <lauxlib.h>
#include <windows.h>

#define WINDOW_CLASS "LuPi2 GPU"
#define WINDOW_TITLE "LuPi2"

LRESULT CALLBACK WndProc(HWND hwnd, UINT msg, WPARAM wParam, LPARAM lParam) {
  switch(msg) {
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

static int l_open(lua_State *L) {
  WNDCLASSEX wc;
  HWND hwnd;

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
    lua_pushboolean(L, 0);
    lua_pushstring(L, "Window registration failed");
    return 2;
  }

  hwnd = CreateWindowEx(
    WS_EX_CLIENTEDGE,
    WINDOW_CLASS,
    WINDOW_TITLE,
    WS_OVERLAPPEDWINDOW,
    CW_USEDEFAULT, CW_USEDEFAULT, 800, 600,
    NULL, NULL, GetModuleHandle(NULL), NULL);

  if(hwnd == NULL) {
    lua_pushboolean(L, 0);
    lua_pushstring(L, "Window creation failed");
    return 2;
  }

  ShowWindow(hwnd, SW_SHOW);
  UpdateWindow(hwnd);

  lua_pushboolean(L, 1);
  return 1;
}

void winapigpu_init(lua_State* L) {
  struct luaL_Reg winlib[] = {
    {"open", l_open},
    {NULL, NULL}
  };

  luaL_openlib(L, "winapigpu", winlib, 0);
}

int winapigpu_events() {
  MSG Msg;
  while(GetMessage(&Msg, NULL, 0, 0) > 0) {
    TranslateMessage(&Msg);
    DispatchMessage(&Msg);
  }
  return 0;
}

#endif
