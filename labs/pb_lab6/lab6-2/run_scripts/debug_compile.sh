#!/bin/bash

cd ..

cp src/Proc.bsv src/gdb/Proc.bsv.copy
python3.9 "$TYPES_HELPER"/main.py \
    --filenames lib/common-lib/Types.bsv,lib/common-lib/ProcTypes.bsv,src/Proc.bsv \
    --debug_vars src/gdb/debug_vars.xml \
    --proc src/Proc.bsv \
    --reg_order src/gdb/regs_bits.txt \
    --base_xml src/gdb/base.xml \
    --output_xml src/gdb/custom.xml \

cd src

./risc-v -c -g
