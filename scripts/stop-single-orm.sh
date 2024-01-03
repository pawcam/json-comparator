#!/bin/bash

# Check if the correct number of arguments are provided
if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <router>"
    exit 1
fi

router=$1

# Get the PID of the router process
pid=$(ps -ef | grep "order-router-monitor -mode poll -OR $router" | grep -v grep | awk '{print $2}')

# Check if the PID exists
if [ -z "$pid" ]; then
    echo "Error: No process found for order-router-monitor: $router"
    exit 1
fi

# Stop the router process
kill -9 $pid
echo "Stopped order-router-monitor process for $router"