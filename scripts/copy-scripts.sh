#!/bin/bash

# Get a list of .sh and .rb files in the current directory
files=$(ls *.sh *.rb)

# Copy all files to /home/deployer/scripts
sudo cp $files /home/deployer/scripts/

# Iterate over the list of files
for file in $files
do
    # Change ownership of the copied file to deployer:deployer
    sudo chown deployer:deployer /home/deployer/scripts/$file

    # Change permissions of the copied file to make it executable
    sudo chmod +x /home/deployer/scripts/$file
done