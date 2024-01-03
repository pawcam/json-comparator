#!/bin/bash

# Check if the correct number of arguments are provided
if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <number> <search-strings>"
    exit 1
fi

number=$1
search_strings=$2

# Check if the number is a positive integer
if ! [[ "$number" =~ ^[0-9]+$ ]]; then
    echo "Error: The first argument must be a positive integer."
    exit 1
fi

# The directory to search
search_dir="/home/deployer"

# The subdirectories to look for
subdirs=("order-router" "cancel-order-service" "new-order-service" "mq-producer")

# Iterate over all directories in the search directory
for dir in "$search_dir"/*; do
  # Check if the item is a directory
  if [ -d "$dir" ]; then
    # Assume the directory contains all subdirectories until proven otherwise
    contains_all_subdirs=true

    # Check each subdir
    for subdir in "${subdirs[@]}"; do
      # If the subdir does not exist in the current directory, mark it as not containing all subdirs
      if [ ! -d "$dir/$subdir" ]; then
        contains_all_subdirs=false
        break
      fi
    done

    # If the directory contains all subdirs, get the log files and perform the search operation
    if [ "$contains_all_subdirs" = true ]; then
      order_router="$(basename "$dir")"

      # Get the log files
      log_files=$(ls -tr /home/deployer/logs/"$order_router"-order-router-monitor_*_*.log 2> /dev/null)

      # Check if any log files were found
      if [ -z "$log_files" ]; then
        echo "No log files found for order-router: $order_router"
        continue
      fi

      # Get the last number of log files
      log_files=$(echo "$log_files" | head -n "$number")

      # Search for the strings in the log files
      IFS='|' read -ra STRINGS <<< "$search_strings"
      for i in "${STRINGS[@]}"; do
        echo "Searching for $i in the log files of $order_router..."
        egrep --color=always "$i" $log_files
      done
    fi
  fi
done