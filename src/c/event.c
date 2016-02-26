#include "lupi.h"
#include <lua.h>
#include <lualib.h>
#include <lauxlib.h>
#include <stdlib.h>
#include <unistd.h>

#include <event2/event.h>
#include <event2/event_struct.h>

struct event_base *base;
struct event stdinEvent;

int nevt = 0;

static void handleStdin(evutil_socket_t fd, short what, void *ptr) {
  char buf;
  int r = read(fd, &buf, 1); /* TODO: Wide chars? */
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

    nevt += 2;
  }
}

void event_prepare() {
  base = event_base_new();
  event_assign(&stdinEvent, base, STDIN_FILENO, EV_READ, handleStdin, NULL);
}

static void add_events(struct timeval* timeout) {
  event_add(&stdinEvent, timeout);
}

int event_pull(int _timeout) {
  if(_timeout > 0) { /* wait max this much time for event */
    struct timeval timeout = {_timeout / 1000, (_timeout % 1000) * 1000000};
    add_events(&timeout);
    /* event_base_loopexit(base, &timeout); */
    event_base_loop(base, EVLOOP_ONCE);
  } else if(_timeout == 0) { /* Get event without blocking */
    add_events(NULL);
    event_base_loop(base, EVLOOP_ONCE | EVLOOP_NONBLOCK);
  } else { /* wait for event to appear */
    add_events(NULL);
    event_base_loopexit(base, NULL);
    event_base_loop(base, EVLOOP_ONCE);
  }

  int n = nevt;
  nevt = 0;
  return n;
}
