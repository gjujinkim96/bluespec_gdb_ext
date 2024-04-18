#!/bin/bash

function help() {
    echo "Usage: $0 [-a] <assembly_file> [output_file]"
    echo "Turn `assembly_file` to vmh format."
    echo "Options:"
    echo "  -a    Add extra nop instructions to the input file"
    exit 1
}

add_nop=false
while getopts ":a" opt; do
    case "$opt" in
        a)
            add_nop=true
        ;;
        ?)
            echo "Invalid option -$OPTARG" >&2
            help
        ;;
    esac
done

shift $((OPTIND - 1))


if [ -z "$1" ]; then
    help
fi

if [ -z "$2" ]; then
    output="${1%%.*}.vmh"
else
    output="$2"
fi

using_file="$1"
if [ "$add_nop" = true ]; then
    using_file="$1.appended"
    for _ in {1..5}; do printf 'nop\n'; done | cat "$1" - > "$using_file"
fi

if riscv64-unknown-elf-as "$using_file" -o "$1.out"; then
    riscv64-unknown-elf-objdump -d -j .text "$1.out" | grep -E '^[[:space:]]+[0-9a-f]+:' | awk '{print $2}' > "$output"
    rm "$1.out"
else
    echo riscv64-unknown-elf-as failed! >&2
fi

if [ "$add_nop" = true ]; then
    rm "$using_file"
fi
