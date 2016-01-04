#include <lua.h>
#include <lualib.h>
#include <lauxlib.h>
#ifndef LUPI_H
#define LUPI_H

void run_init();
void setup_modules(lua_State *L);
#endif
