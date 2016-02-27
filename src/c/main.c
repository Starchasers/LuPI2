#include <stdio.h>
#include "lupi.h"

int main (void) {
    puts("LuPI L0 INIT");
    lupi_init();
    run_init();
    return 0;
}
