#include "lupi.h"
#include <lua.h>
#include <lualib.h>
#include <lauxlib.h>
#include <string.h>
#include <signal.h>
#include <sys/ioctl.h>
#include <termios.h>
#include <stdio.h>
#include <unistd.h>

static void handle_winch(int sig){
  signal(SIGWINCH, SIG_IGN);

  //FIXME: Prerelease: Implement
  signal(SIGWINCH, handle_winch);
}

static int l_get_term_sz (lua_State *L) {
  struct winsize w;
  ioctl(STDOUT_FILENO, TIOCGWINSZ, &w);
  lua_pushnumber(L, w.ws_col);
  lua_pushnumber(L, w.ws_row);
  return 2;
}


void termutils_start(lua_State *L) {
  signal(SIGWINCH, handle_winch);

  struct termios old, new;
  if (tcgetattr (STDOUT_FILENO, &old) != 0)
     return;
   new = old;
   new.c_lflag &= ~ECHO;
   if (tcsetattr (STDOUT_FILENO, TCSAFLUSH, &new) != 0)
     return;

  lua_createtable (L, 0, 1);
  pushctuple(L, "getSize", l_get_term_sz);
  
  lua_setglobal(L, "termutils");
}