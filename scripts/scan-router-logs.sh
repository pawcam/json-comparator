#!/bin/bash

# Check if the correct number of arguments are provided
if [ "$#" -ne 3 ]; then
    echo "Usage: $0 <order-router> <number> <search-strings>"
    exit 1
fi

order_router=$1
number=$2
search_strings=$3

# Check if the number is a positive integer
if ! [[ "$number" =~ ^[0-9]+$ ]]; then
    echo "Error: The second argument must be a positive integer."
    exit 1
fi

# Get the log files
log_files=$(ls -t /home/deployer/"$order_router"/order-router/logs/"$order_router"-order-router_*.log 2> /dev/null)

# Check if any log files were found
if [ -z "$log_files" ]; then
    echo "No log files found for order-router: $order_router"
    exit 1
fi

# Get the last number of log files
log_files=$(echo "$log_files" | head -n "$number")

# Search for the strings in the log files
IFS='|' read -ra STRINGS <<< "$search_strings"
for i in "${STRINGS[@]}"; do
    echo "Searching for $i in the log files..."
    egrep --color=always "$i" $log_files
done