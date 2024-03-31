#!/bin/bash

# start gdbstub
(cd ../src/gdb && "$GDBSTUB"/exe_gdbstub_tcp_tcp_RV32 > /dev/null 2>&1) &
STUB_PID=$!

# start gdb
if ! [ -f .running_program.txt ]; then
  echo "run process_run.sh first!"
  exit 1
fi

program=$(cat .running_program.txt)
rm .running_program.txt

cd ../src/gdb

rm -f start.gdb

sed -e "s/{SED_PROGRAM}/$program/g" -e "s#{GDBSTUB}#$GDBSTUB#g" base_start.gdb > start.gdb

riscv64-unknown-elf-gdb -x start.gdb

# cleanup
pkill -P $STUB_PID
pkill -P $$

