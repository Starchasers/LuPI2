#define _XOPEN_SOURCE 600

#include "lupi.h"
#include <lua.h>
#include <lualib.h>
#include <lauxlib.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <string.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <netdb.h> 
#include <strings.h>
#include <fcntl.h>
#include <errno.h>
#include <signal.h>
#include <openssl/ssl.h>
#include <openssl/conf.h>

static int l_open(lua_State *L) { //TODO: Any mem leaks?
  const char* hostaddr = lua_tostring(L, 1);
  int port = lua_tonumber(L, 2);

  struct addrinfo hints, *servinfo, *p;
  int status;

  memset(&hints, 0, sizeof(hints));  
  hints.ai_family = AF_UNSPEC;
  hints.ai_socktype = SOCK_STREAM;

  if ((status = getaddrinfo(hostaddr, NULL, &hints, &servinfo)) != 0) {
    lua_pushnil(L);
    lua_pushstring(L, gai_strerror(status));
    return 2;
  }

  int sockfd;
  for(p = servinfo; p != NULL; p = p->ai_next) {
    if(p->ai_family == AF_INET) {
        ((struct sockaddr_in*)p->ai_addr)->sin_port = htons(port);
    } else {
      ((struct sockaddr_in6*)p->ai_addr)->sin6_port = htons(port);
    }

    if ((sockfd = socket(p->ai_family, p->ai_socktype, p->ai_protocol)) == -1) {
      continue;
    }

    if (connect(sockfd, p->ai_addr, p->ai_addrlen) == -1) {
      close(sockfd);
      continue;
    }

    fcntl(sockfd, F_SETFL, O_NONBLOCK);
    break;
  }

  if (p == NULL) {
    lua_pushnil(L);
    lua_pushstring(L, "client: failed to connect");
    return 2;
  }

  freeaddrinfo(servinfo);
  lua_pushnumber(L, sockfd);
  return 1;
}

static int l_write(lua_State *L) {
  size_t len = 0;
  int fd = lua_tonumber(L, 1);
  const char* data = lua_tolstring(L, 2, &len);

  int total = 0;
  int n;

  while(total < len) {
    n = send(fd, data+total, len, 0);
    if (n == -1) {
      if(errno == EPIPE)
        return 0;
    }
    total += n;
    len -= n;
  }

  lua_pushnumber(L, total);
  return 1;
}

static int l_read(lua_State *L) {
  int fd = lua_tonumber(L, 1);
  int sz = lua_tonumber(L, 2);

  char *buf = malloc(sz);

  if ((sz = recv(fd, buf, sz, 0)) == -1) {
    if(errno == EAGAIN || errno == EWOULDBLOCK) {
      lua_pushstring(L, "");
      return 1;
    }
    lua_pushnil(L);
    lua_pushstring(L, strerror(errno));
    return 2;
  }

  lua_pushlstring(L, buf, sz);
  free(buf);
  return 1;
}

static void ssl_init() {
  (void)SSL_library_init();
  SSL_load_error_strings();
  OPENSSL_config(NULL);
}

void internet_start(lua_State *L) {
  ssl_init();
  signal(SIGPIPE, SIG_IGN);

  lua_createtable (L, 0, 1);

  pushctuple(L, "open", l_open);
  pushctuple(L, "write", l_write);
  pushctuple(L, "read", l_read);

  lua_setglobal(L, "net");
}
