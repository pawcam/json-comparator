#!/bin/bash

# The directory to search
search_dir="/home/deployer"

# The subdirectories to look for
subdirs=("order-router" "new-order-service" "cancel-order-service" "mq-producer")
holiday_aware_routers=("CBOE_DIGITAL" "CFE" "CME" "CRYPTOCURRENCY")

# Save the current directory
original_dir=$(pwd)

# Change to the home directory
cd ~

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

      # Initialize a variable to check if the router is holiday aware
      is_holiday_aware=false

      # Check if the router string includes any of the strings in holiday aware routers
      for holiday_router in "${holiday_aware_routers[@]}"; do
        if [[ $ROUTER == *"$holiday_router"* ]]; then
          is_holiday_aware=true
          break
        fi
      done

      if [ "$is_holiday_aware" = true ]; then
        # Use the new command for holiday aware routers
        TRADE_DATE=$(/usr/local/rvm/bin/rvm 2.5.1 do ruby /home/deployer/scripts/trade_date_shim.rb $ROUTER | tail -n 1); /home/deployer/order-router-monitor -mode poll -OR $ROUTER -trade_date $TRADE_DATE &
      else
        # Use the existing command for other routers
        /home/deployer/order-router-monitor -mode poll -OR $ROUTER &
      fi
    fi
  fi
done

# Return to the original directory
cd "$original_dir"