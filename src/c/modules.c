#include "luares.h"
#include "res.h"
#include "lupi.h"
#include <lua.h>
#include <lualib.h>
#include <lauxlib.h>
#include <stdlib.h>

void setup_modules(lua_State *L) {
  lua_createtable (L, 0, 32);

  pushstuple(L, "boot",         lua_boot);
  pushstuple(L, "color",        lua_util_color);
  pushstuple(L, "component",    lua_component);
  pushstuple(L, "computer",     lua_computer);
  pushstuple(L, "debug",        lua_debug);
  pushstuple(L, "eeprom",       lua_eeprom);
  pushstuple(L, "filesystem",   lua_filesystem);
  pushstuple(L, "gpio",         lua_gpio);
  pushstuple(L, "gpudetect",    lua_gpudetect);
  pushstuple(L, "internet",     lua_internet);
  pushstuple(L, "sandbox",      lua_sandbox);
  pushstuple(L, "textgpu",      lua_textgpu);
  pushstuple(L, "fbgpu",        lua_fbgpu);
  pushstuple(L, "color",        lua_util_color);
  pushstuple(L, "random",       lua_util_random);
  pushstuple(L, "buffer",       lua_util_buffer);

  pushstuple(L, "eepromDefault",  res_eepromDefault);
  pushstuple(L, "help",           res_help);

  lua_setglobal(L, "moduleCode");
}
