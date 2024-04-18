#!/bin/bash

supported_programs="$(cd ../lib/programs/ && find . -type f -regex './[^/]+/[^/]+\.vmh' -printf "%P ")"
IFs=' ' read -ra supported_programs <<< "$supported_programs"
unset directories
declare -A directories

for file in "${supported_programs[@]}"; do
    dir="${file%%/*}"
    test_name="${file%.vmh}"
    test_name="${test_name##*/}"
    if [ -z "${directories[$dir]}" ]; then
        directories[$dir]="$test_name"
    else
        directories[$dir]="${directories[$dir]} $test_name"
    fi
done

function show_help_and_exit() {
    echo "Usage:"
    echo "    $0 [test_category] test_name"
    echo
    echo "Examples:"
    echo "    $0 program-test array_sum_ji"
    echo "    $0 array_sum_ji"
    echo
    echo "Supported test_category:"
    for dir in "${!directories[@]}"; do
        echo "    $dir"
    done
    echo
    echo "Supported test_name:"
    for dir in "${!directories[@]}"; do
        echo "    test_category: $dir"
        IFS=' ' read -ra cur_dir <<<"${directories[$dir]}"

        test_names="${cur_dir[@]##*/}"
        IFS=' ' read -ra test_names <<<"$test_names" 

        for ((i = 0; i < ${#test_names[@]}; i++)); do

            echo -en "        ${test_names[i]}" 

            if (( (i+1) % 3 == 0 || (i+1) == ${#test_names[@]} )); then
                echo
            fi
        done
        echo
    done
    # echo "program list = [array_sum_1d, array_sum_ij, array_sum_ji]"
    # echo "               [hanoi_tower, bubble_sort, fibonacci]"
    exit 1
}

test_type="$1"
test_name="$2"

if [[ -z "$test_name" ]]; then
    test_name="$test_type"
    test_type=""

    for dir in "${!directories[@]}"; do
        IFS=' ' read -ra cur_dir <<<"${directories[$dir]}"
        for cur_name in "${cur_dir[@]}"; do
            if [ "$test_name" = "$cur_name" ]; then
                test_type="$dir"
                break 2
            fi
        done
    done

    if [[ -z "$test_type" ]]; then
        show_help_and_exit        
    fi
fi

echo "Running $test_type -- $test_name"

cd ../src
rm -f gdb/unix_socket/*

case "$test_type" in 
    "decode") 
        ./risc-v -rd
        ;;

    "instruction-test")
        ./risc-v -i "$test_name"
        ;;

    "hazard-test")
        ./risc-v -z "$test_name"
        ;;

    "program-test")
        ./risc-v -p "$test_name"
        ;;

    *)
        ./risc-v -e "$test_type" "$test_name"
        ;;
esac
