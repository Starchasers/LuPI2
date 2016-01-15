#include "lupi.h"
#include <lua.h>
#include <lualib.h>
#include <lauxlib.h>
#include <sys/epoll.h>
#include <stdlib.h>
#include <unistd.h>

static int epollfd;

static int handleStdin(int fd, void* data) {
  char buf;
  int r = read(fd, &buf, 1); //TODO: Wide chars?
  if(r > 0) {
    //if(buf == 10) buf = 13;
    lua_State* L = getL();

    lua_getglobal(L, "pushEvent");
    lua_pushstring(L, "key_down");
    lua_pushstring(L, "TODO:SetThisUuid");//Also in textgpu.lua
    lua_pushnumber(L, buf);
    lua_pushnumber(L, -1);
    lua_pushstring(L, "user");
    lua_call(L, 5, 0);

    lua_getglobal(L, "pushEvent");
    lua_pushstring(L, "key_up");
    lua_pushstring(L, "TODO:SetThisUuid");
    lua_pushnumber(L, buf);
    lua_pushnumber(L, -1);
    lua_pushstring(L, "user");
    lua_call(L, 5, 0);

    return 2;
  }
  return 0;
}

void epoll_prepare() {
  if ((epollfd = epoll_create1(0)) < 0) {
    perror("epoll_create");
    exit(EXIT_FAILURE);
  }

  struct lupi_event_handler* stdin_handler = malloc(sizeof(struct lupi_event_handler)); 
  stdin_handler->data = NULL;
  stdin_handler->handler = handleStdin;
  stdin_handler->fd = STDIN_FILENO;

  struct epoll_event stdinEvent;
  stdinEvent.events = EPOLLIN | EPOLLPRI;
  stdinEvent.data.ptr = stdin_handler;

  if ((epoll_ctl(epollfd, EPOLL_CTL_ADD, STDIN_FILENO, &stdinEvent) < 0)) {
    perror("epoll_ctl");
    exit(EXIT_FAILURE);
  }
}

int epoll_pull(int timeout) {
  struct epoll_event evBuffer;
  int pushed = 0;

  int eres = epoll_wait(epollfd, &evBuffer, 1, timeout);
  if(eres > 0) {
    struct lupi_event_handler* handler = (struct lupi_event_handler*)evBuffer.data.ptr;
    pushed = handler->handler(handler->fd, handler->data);
  }
  return pushed;
}
