#!/bin/bash

# start gdbstub
(cd ../src/gdb && "$GDBSTUB"/exe_gdbstub_tcp_tcp_RV32 > /dev/null 2>&1) &
STUB_PID=$!

cd ../src/gdb

riscv64-unknown-elf-gdb -x start.gdb

# cleanup
pkill -P $STUB_PID
pkill -P $$

