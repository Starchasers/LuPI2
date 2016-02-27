#include "lupi.h"

#ifndef _WIN32
#include <sys/mount.h>
#include <sys/types.h>
#include <unistd.h>

void lupi_init() {
  if(getpid() == 1) {
    mount(NULL, "/sys", "sysfs", 0, NULL);
    mount(NULL, "/proc", "procfs", 0, NULL);
  }
}
#else
void lupi_init() {
  
}
#endif