#include <lua.h>
#include <lualib.h>
#include <lauxlib.h>
#ifndef LUPI_H
#define LUPI_H

//#define LOGGING
#ifdef LOGGING
void logn(const char *message);
void logi(int message);
void logm(const char *message);
#else
  #define logn(m)
  #define logi(m)
  #define logm(m)
#endif

//TODO: move to utils
#define pushstuple(state, name, value) lua_pushstring((state), (name)); lua_pushstring((state), (value));    lua_settable((state), -3)
#define pushctuple(state, name, value) lua_pushstring((state), (name)); lua_pushcfunction((state), (value)); lua_settable((state), -3)

lua_State* getL();

void run_init();
void luanative_start(lua_State *L);
void setup_modules(lua_State *L);
void termutils_start(lua_State *L);
void epoll_prepare();
int epoll_pull(int timeout);

struct lupi_event_handler {
  int (*handler)(int, void*); //FD, data, return number of pushed events
  //TODO: doc?
  int fd;
  void* data;
};

#endif
