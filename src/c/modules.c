#include "luares.h"
#include "lupi.h"
#include <lua.h>
#include <lualib.h>
#include <lauxlib.h>
#include <stdlib.h>

void setup_modules(lua_State *L) {
  lua_createtable (L, 0, 1);

  pushstuple(L, "boot", lua_boot);
  pushstuple(L, "component", lua_component);
  pushstuple(L, "computer", lua_computer);
  pushstuple(L, "eeprom", lua_eeprom);
  pushstuple(L, "eepromDefault", lua_eepromDefault);
  pushstuple(L, "filesystem", lua_filesystem);
  pushstuple(L, "sandbox", lua_sandbox);
  pushstuple(L, "textgpu", lua_textgpu);
  pushstuple(L, "color", lua_util_color);
  pushstuple(L, "random", lua_util_random);

  lua_setglobal(L, "moduleCode");
}