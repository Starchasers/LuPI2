#include "lupi.h"
#include <lua.h>
#include <lualib.h>
#include <lauxlib.h>

#ifdef _WIN32
#define WIN32

#include <event2/event.h>
#include <event2/event_struct.h>

evutil_socket_t winInputPipe[2] = {0,0};

void pokeWinEvt(char ch) {
  send(winInputPipe[1], &ch, 1, 0);
}

void handleWinevent(evutil_socket_t fd, short what, void *eventc) {
  if(what != EV_READ) return;

  char buf;
  int r = recv(fd, &buf, 1, 0); /* TODO: Wide chars? */
  if(r > 0) {
    lua_State* L = getL();

    lua_getglobal(L, "pushEvent");
    lua_pushstring(L, "key_down");
    lua_pushstring(L, "TODO:SetThisUuid");/* Also in textgpu.lua */
    lua_pushnumber(L, buf);
    lua_pushnumber(L, -1);
    lua_pushstring(L, "root");
    lua_call(L, 5, 0);

    lua_getglobal(L, "pushEvent");
    lua_pushstring(L, "key_up");
    lua_pushstring(L, "TODO:SetThisUuid");
    lua_pushnumber(L, buf);
    lua_pushnumber(L, -1);
    lua_pushstring(L, "root");
    lua_call(L, 5, 0);

    *((int*) eventc) += 2;
  }
}
#endif