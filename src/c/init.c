#include "lupi.h"

#ifndef _WIN32
#include <sys/mount.h>
#include <sys/types.h>
#include <unistd.h>
#include <sys/statvfs.h>
#include <sys/mount.h>

void lupi_init() {
  if(getpid() == 1) {
    mount(NULL, "/sys", "sysfs", 0, NULL);
    mount(NULL, "/proc", "procfs", 0, NULL);
  }
  struct statvfs fsstat;

  statvfs("/", &fsstat);
  printf("Filesystem / RO status: %X\n",fsstat.f_flag & MS_RDONLY);
}
#else
void lupi_init() {
  
}
#endif