#include "luares.h"
#include "lupi.h"
#include <lua.h>
#include <lualib.h>
#include <lauxlib.h>
#include <stdlib.h>


#include <sys/types.h>
#include <sys/stat.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>
#include <stdlib.h>

static lua_State* L = NULL;

lua_State* getL() {
  return L;
}

void run_init(int argc, char **argv) {
  L = luaL_newstate();

  luaL_openlibs   (L);
  setup_modules   (L);
  luanative_start (L);
  internet_start  (L);
#ifdef _WIN32
  winapigpu_init  (L);
#endif
  fb_start        (L);
  termutils_start (L);
  event_prepare();

  int status = luaL_loadbuffer(L, lua_init, strlen(lua_init), "=INIT");
  if (status) {
    fprintf(stderr, "Couldn't load init: %s\n", lua_tostring(L, -1));
    exit(1);
  }
  for(int i = 0; i < argc; i++) {
    lua_pushstring(L, argv[i]);
  }
  lua_call(L, argc, 0);
  lua_close(L);
}
