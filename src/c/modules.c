#include "luares.h"
#include "lupi.h"
#include <lua.h>
#include <lualib.h>
#include <lauxlib.h>
#include <stdlib.h>

//TODO: move to utils
#define pushtuple(state, name, value) lua_pushstring((state), (name)); lua_pushstring((state), (value)); lua_settable((state), -3)


void setup_modules(lua_State *L) {
  lua_createtable (L, 0, 1);

  pushtuple(L, "boot", lua_boot);
  pushtuple(L, "component", lua_component);
  pushtuple(L, "computer", lua_computer);
  pushtuple(L, "sandbox", lua_sandbox);
  pushtuple(L, "random", lua_util_random);

  lua_setglobal(L, "moduleCode");
}