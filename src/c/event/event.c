#include "lupi.h"
#include <lua.h>
#include <lualib.h>
#include <lauxlib.h>
#include <stdlib.h>
#include <unistd.h>

#ifdef _WIN32
  #include <io.h>
  #include <fcntl.h>
  #define WIN32
#endif

#ifdef WIN32
#define LOCAL_SOCKETPAIR_AF AF_INET
#else
#define LOCAL_SOCKETPAIR_AF AF_UNIX
#endif

#include <event2/event.h>
#include <event2/event_struct.h>

struct event_base *base;
struct event stdinEvent;
int nevt = 0;

static void handleStdin(evutil_socket_t fd, short what, void *eventc) {
  char buf;

  if(what != EV_READ) return;

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

    *((int*) eventc) += 2;
  }
}

#ifdef _WIN32
extern evutil_socket_t winInputPipe[2]; //TODO: make it nicer
struct event winEvent;
#endif

void event_prepare() {
  struct event_config* cfg = event_config_new();
  event_config_set_flag(cfg, EVENT_BASE_FLAG_NO_CACHE_TIME);
  base = event_base_new_with_config(cfg);

  evutil_make_socket_nonblocking(STDIN_FILENO);
  event_assign(&stdinEvent, base, STDIN_FILENO, EV_READ, handleStdin, &nevt);
  
#ifdef _WIN32
  evutil_socketpair(LOCAL_SOCKETPAIR_AF, SOCK_STREAM, 0, winInputPipe);
  evutil_make_socket_nonblocking(winInputPipe[0]);
  event_assign(&winEvent, base, winInputPipe[0], EV_READ, handleWinevent, &nevt);
#endif
}

static void add_events(struct timeval* timeout) {
#ifndef _WIN32
  event_add(&stdinEvent, timeout);
#endif
#ifdef _WIN32
  event_add(&winEvent, timeout);
#endif
}


int event_pull(int _timeout) {
  int n = 0;

  if(_timeout > 0) { /* wait max this much time for event */
    struct timeval timeout = {_timeout / 1000, (_timeout % 1000) * 1000};
    add_events(&timeout);
    event_base_loop(base, EVLOOP_ONCE);
  } else if(_timeout == 0) { /* Get event without blocking */
    add_events(NULL);
    event_base_loop(base, EVLOOP_ONCE | EVLOOP_NONBLOCK);
  } else { /* wait for event to appear */
    add_events(NULL);
    event_base_loop(base, EVLOOP_ONCE);
  }

  n = nevt;
  nevt = 0;
  return n;
}
