#!/bin/bash

# Default number of lines to display after the match
lines=40

# Check if an argument is provided
if [ "$#" -eq 1 ]; then
    lines=$1
fi

# Run the grep command with the specified number of lines after the match
grep --color=always "JSON Message Index" /home/deployer/scripts/logs/*mqp-json-comparator* -A"$lines"