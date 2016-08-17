#include <lua.h>
#include <lualib.h>
#include <lauxlib.h>
#ifndef LUPI_H
#define LUPI_H

#ifdef LOGGING
void logn(const char *message);
void logi(int message);
void logm(const char *message);
void logt(const char *message);
#else
  #define logn(m)
  #define logi(m)
  #define logm(m)
  #define logt(m)
#endif

#define pushstuple(state, name, value) lua_pushstring((state), (name)); lua_pushstring((state), (value)); lua_settable((state), -3)

typedef unsigned short ushort;

lua_State* getL();

void run_init(int argc, char **argv);
void lupi_init();
void luanative_start(lua_State *L);
void fb_start(lua_State *L);
void setup_modules(lua_State *L);
void termutils_start(lua_State *L);
void internet_start(lua_State *L);
void event_prepare();
int event_pull(int timeout);

#ifdef _WIN32
void winapigpu_init(lua_State* L);
#define WIN32
#include <event2/event.h>
#include <event2/event_struct.h>
void handleWinevent(evutil_socket_t fd, short what, void *eventc);
#undef WIN32
#endif

#endif
