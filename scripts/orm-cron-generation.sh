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
  
      # Look for an existing crontab entry with the pattern "start $(ROUTER)-mq-producer.service"
      cron_start_schedule=$(crontab -l | grep "start $ROUTER-mq-producer.service" | awk '{print $1, $2, $3, $4, $5}')

      # Add a new cron job with the extracted schedule
      (crontab -l; echo "$cron_start_schedule /home/deployer/order-router-monitor -mode poll -OR $ROUTER &") | crontab -

      # Look for an existing crontab entry with the pattern "stop $ROUTER-mq-producer.service"
      stop_cron_schedule=$(crontab -l | grep "stop $ROUTER-mq-producer.service" | awk '{print $1, $2, $3, $4, $5}')

      # Add a new cron job with the extracted schedule to stop the process
      (crontab -l; echo "$stop_cron_schedule /usr/bin/pkill -f '/home/deployer/order-router-monitor -mode poll -OR $ROUTER'") | crontab -

      # Add a new cron job with the same schedule to run the ruby script
      (crontab -l; echo "$stop_cron_schedule /usr/local/rvm/bin/rvm 2.7.6 do ruby /home/deployer/scripts/mqp_json_comparison.rb $ROUTER") | crontab -
    fi
  fi
done
