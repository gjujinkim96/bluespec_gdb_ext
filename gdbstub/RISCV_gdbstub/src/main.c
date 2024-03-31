#include <stdio.h>
#include <stdbool.h>

#include "gdbstub_fe.h"

int main (int argc, char **argv)
{
    init_reg_orders();
    Gdbstub_FE_Params params;

    // TODO: listen on socket/PTY/... for GDB connection
    // params.gdb_fd = file descriptor for socket/PTY/...

    // TODO: open logfile to record gdbstub communications w. GDB and Debug Module
    // params.logfile = ...

    main_gdbstub (& params);
}
