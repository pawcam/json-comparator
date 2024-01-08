#!/bin/bash

# Check if the correct number of arguments are provided
if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <router>"
    exit 1
fi

router=$1

# Save the current directory
original_dir=$(pwd)

# Change to the home directory
cd ~

# Get the command from the crontab
command=$(crontab -l | grep "/home/deployer/order-router-monitor -mode poll -OR $router &")

# Check if the command exists
if [ -z "$command" ]; then
    echo "Error: No crontab entry found for order-router-monitor: $router"
    exit 1
fi

# Remove the cron schedule from the command
command=$(echo "$command" | cut -d' ' -f6-)

# Run the command
eval "$command"
echo "Started order-router-monitor process for $router"

# Return to the original directory
cd "$original_dir"