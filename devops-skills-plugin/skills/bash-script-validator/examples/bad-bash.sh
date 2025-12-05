#!/usr/bin/env bash
#
# Example of a poorly-written bash script with common mistakes
#

# Missing: set -euo pipefail

LOG_FILE=/tmp/example.log

# Function defined after use (will fail)
main

log_info() {
    # Bad: unquoted variable
    echo [INFO] $*
}

# Bad: using backticks instead of $()
result=`date`

process_file() {
    file=$1  # Not local

    # Bad: not quoting variable
    if [ ! -f $file ]; then
        echo "File not found"
        return 1
    fi

    # Bad: useless use of cat
    cat $file | grep pattern

    # Bad: eval with variable (security risk)
    eval $user_command
}

main() {
    # Bad: not checking if arguments provided
    # Bad: unquoted $@
    for file in $@; do
        # Bad: not checking return value
        cd /some/directory
        rm -rf *  # DANGEROUS!

        process_file $file
    done

    # Bad: checking $? after multiple commands
    if [ $? -eq 0 ]; then
        echo "Success"
    fi
}

# Bad: calling main without "$@"
main $*