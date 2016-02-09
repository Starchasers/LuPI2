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

struct termios old, new;

static void handle_winch(int sig){
  signal(SIGWINCH, SIG_IGN);

  /* FIXME: Prerelease: Implement */
  signal(SIGWINCH, handle_winch);
}

static int l_get_term_sz (lua_State *L) {
  struct winsize w;
  ioctl(STDOUT_FILENO, TIOCGWINSZ, &w);
  lua_pushnumber(L, w.ws_col);
  lua_pushnumber(L, w.ws_row);
  return 2;
}

static int l_term_restore (lua_State *L) {
  tcsetattr (STDOUT_FILENO, TCSAFLUSH, &old);
  return 0;
}

static int l_term_init (lua_State *L) {
  tcsetattr (STDOUT_FILENO, TCSAFLUSH, &new);
  return 0;
}

void termutils_start(lua_State *L) {
  signal(SIGWINCH, handle_winch);

  if (tcgetattr (STDOUT_FILENO, &old) != 0)
     return;
  new = old;

  new.c_iflag &= ~(IGNBRK | BRKINT | PARMRK | ISTRIP
    | INLCR | IGNCR | ICRNL | IXON);
  new.c_oflag &= ~OPOST;
  new.c_lflag &= ~(ECHO | ECHONL | ICANON | ISIG | IEXTEN);
  new.c_cflag &= ~(CSIZE | PARENB);
  new.c_cflag |= CS8;

  lua_createtable (L, 0, 1);
  pushctuple(L, "getSize", l_get_term_sz);
  pushctuple(L, "init", l_term_init);
  pushctuple(L, "restore", l_term_restore);
  
  lua_setglobal(L, "termutils");
}