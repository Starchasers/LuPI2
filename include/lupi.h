#include <lua.h>
#include <lualib.h>
#include <lauxlib.h>
#ifndef LUPI_H
#define LUPI_H

//TODO: move to utils
#define pushstuple(state, name, value) lua_pushstring((state), (name)); lua_pushstring((state), (value));    lua_settable((state), -3)
#define pushctuple(state, name, value) lua_pushstring((state), (name)); lua_pushcfunction((state), (value)); lua_settable((state), -3)

void run_init();
void luanative_start(lua_State *L);
void setup_modules(lua_State *L);
void termutils_start(lua_State *L);
#endif
