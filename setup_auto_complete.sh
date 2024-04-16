#!/bin/bash


supported_programs="$(cd $PROGRAMS_DIR && find . -type f -regex './[^/]+/[^/]+\.vmh' -printf "%P ")"
IFs=' ' read -ra supported_programs <<< "$supported_programs"
unset directories
declare -A directories

all_test_names=""
for file in "${supported_programs[@]}"; do
    dir="${file%%/*}"
    test_name="${file%.vmh}"
    test_name="${test_name##*/}"
    if [ -z "${directories[$dir]}" ]; then
        directories[$dir]="$test_name"
    else
        directories[$dir]="${directories[$dir]} $test_name"
    fi

    all_test_names="$all_test_names $test_name"
done

function list_args() {
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"

    case "$COMP_CWORD" in
        0)
            COMPREPLY=()
            ;;
        
        1)
            dir_name="${!directories[@]}"
            COMPREPLY=($(compgen -W "$dir_name $all_test_names" "$cur"))
            ;;

        2)
            if [[ -v directories["$prev"] ]]; then
                cur_dir="${directories[$prev]}"
                COMPREPLY=($(compgen -W "${cur_dir[@]}" "$cur"))
            else
                COMPREPLY=()
            fi
            ;;

        *)
            COMPREPLY=()
            ;;
    esac
}

complete -F list_args process_run.sh
