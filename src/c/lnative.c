#include "lupi.h"
#include <lua.h>
#include <lualib.h>
#include <lauxlib.h>
#include <string.h>
#include <unistd.h>

static int l_sleep (lua_State *L) {
  int t = lua_tonumber(L, 1);
  usleep(t);
  return 0;
}

void luanative_start(lua_State *L) {
  lua_createtable (L, 0, 1);
  pushctuple(L, "sleep", l_sleep);
  
  lua_setglobal(L, "native");
}