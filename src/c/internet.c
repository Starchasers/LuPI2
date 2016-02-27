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
#include <strings.h>
#include <fcntl.h>
#include <errno.h>
#include <signal.h>
#include <openssl/ssl.h>
#include <openssl/conf.h>

#ifdef _WIN32
  #include <winsock2.h>
  #include <ws2tcpip.h>
#else
  #include <sys/socket.h>
  #include <netinet/in.h>
  #include <netdb.h>
#endif

SSL_CTX* ctx = NULL;

static int l_open(lua_State *L) { /* TODO: Any mem leaks? */
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
#ifdef _WIN32
    u_long blockmode = 1;
    ioctlsocket(sockfd,FIONBIO,&blockmode);
#else
    fcntl(sockfd, F_SETFL, O_NONBLOCK);
#endif
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

/* NOTE THAT AT THIS STAGE THIS IS DEVELOPED IS A WAY THAT WILL /JUST WORK/ AND WON'T BE NECESSARILY SECURE */

struct sslInfo {
  BIO *web;
  BIO *out;
  SSL *ssl;
};

static int l_sslOpen(lua_State *L) {
  const char* hostaddr = lua_tostring(L, 1);
  const char* hostname = lua_tostring(L, 2);
  struct sslInfo* info;
  BIO *web = NULL, *out = NULL;
  SSL *ssl = NULL;
  int res = 0;

  web = BIO_new_ssl_connect(ctx);
  if(web == NULL) goto fail;

  res = BIO_set_conn_hostname(web, hostaddr);
  if(res != 1) goto fail;

  BIO_get_ssl(web, &ssl);
  if(ssl == NULL) goto fail;

  const char* const PREFERRED_CIPHERS = "HIGH:!aNULL:!kRSA:!PSK:!SRP:!MD5:!RC4";
  res = SSL_set_cipher_list(ssl, PREFERRED_CIPHERS);
  if(res != 1) goto fail;

  res = SSL_set_tlsext_host_name(ssl, hostname);
  if(res != 1) goto fail;

  out = BIO_new_fp(stdout, BIO_NOCLOSE);
  if(NULL == out) goto fail;

  res = BIO_do_connect(web);
  if(res != 1) goto fail;

  res = BIO_do_handshake(web);
  if(res != 1) goto fail;

  X509* cert = SSL_get_peer_certificate(ssl);
  if(cert) { X509_free(cert); }
  if(NULL == cert) goto fail;

  res = SSL_get_verify_result(ssl);
  if(res != X509_V_OK) goto fail;

  goto nofail;

fail:
  lua_pushnil(L);
  lua_pushstring(L, "Couldn't setup new SSL connection");
  if(web) BIO_free_all(web);
  return 2;

nofail:
  info = lua_newuserdata(L, sizeof(struct sslInfo));
  info->web = web;
  info->out = out;
  info->ssl = ssl;
  return 1;
}

static int ssl_verify(int depth, X509_STORE_CTX *sctx) {
  return 1;
}

static void ssl_init() {
  /* https://wiki.openssl.org/index.php/SSL/TLS_Client */

  (void)SSL_library_init();
  SSL_load_error_strings();

  const SSL_METHOD* method = SSLv23_method();
  ctx = SSL_CTX_new(method);
  SSL_CTX_set_verify(ctx, SSL_VERIFY_PEER, ssl_verify);
  SSL_CTX_set_verify_depth(ctx, 4);
  const long flags = SSL_OP_NO_SSLv2 | SSL_OP_NO_SSLv3 | SSL_OP_NO_COMPRESSION;
  SSL_CTX_set_options(ctx, flags);
}

void internet_start(lua_State *L) {
  ssl_init();
#ifndef _WIN32
  signal(SIGPIPE, SIG_IGN);
#else
  WSADATA wd;
  if(WSAStartup(MAKEWORD(2,2), &wd)!=0) {
    WSACleanup();
    exit(1);
  }
#endif
  struct luaL_Reg netlib[] = {
    {"open", l_open},
    {"write", l_write},
    {"read", l_read},
    {NULL, NULL}
  };
  luaL_openlib(L, "net", netlib, 0);
}
