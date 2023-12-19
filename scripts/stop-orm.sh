#!/bin/bash

# The directory to search
search_dir="/home/deployer"

# The subdirectories to look for
subdirs=("order-router" "new-order-service" "cancel-order-service" "mq-producer")

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

    # If the directory contains all subdirs, print its name
    if [ "$contains_all_subdirs" = true ]; then
      ROUTER="$(basename "$dir")"
      echo "$ROUTER"

      /usr/bin/pkill -f "/home/deployer/order-router-monitor -mode poll -OR $ROUTER"
    fi
  fi
done