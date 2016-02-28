#include <stdio.h>
#include "lupi.h"

int main (int argc, char **argv) {
    puts("LuPI L0 INIT");
    lupi_init();
    run_init(argc, argv);
    return 0;
}
