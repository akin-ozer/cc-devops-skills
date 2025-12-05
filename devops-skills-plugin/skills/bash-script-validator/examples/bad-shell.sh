#!/bin/sh
#
# Example of a poorly-written shell script with bashisms and other mistakes
#

# Bad: using bash-specific [[ ]]
if [[ -f /etc/passwd ]]; then
    echo "File exists"
fi

# Bad: using bash arrays in sh script
array=(one two three)
echo ${array[0]}

# Bad: using bash-specific function keyword
function process_data {
    # Bad: using bash-specific 'local'
    local data=$1

    # Bad: unquoted variable
    echo $data
}

# Bad: using 'source' instead of '.'
source /etc/profile

# Bad: using == instead of =
if [ "$var" == "value" ]; then
    echo "match"
fi

# Bad: process substitution (bash-specific)
diff <(ls dir1) <(ls dir2)

# Bad: brace expansion (bash-specific)
echo {1..10}

# Bad: $RANDOM (bash-specific)
random_num=$RANDOM

# Bad: using [[ with regex (bash-specific)
if [[ "$string" =~ pattern ]]; then
    echo "matches"
fi

# Bad: not quoting variables
file=/path/with spaces/file.txt
cat $file

# Bad: useless use of cat
cat file.txt | grep pattern

# Bad: using eval without sanitization
eval $user_input