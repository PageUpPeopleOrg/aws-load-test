#!/bin/bash

# Get the current project directory
PROJECT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
# Load the shared properties file
. $PROJECT_DIR/loadtest.properties
# Split the list of servers into an array
hosts=(`echo $SERVERS | tr "," "\n" | tr -d ' '`)

# For each server kill the java process
for host in ${hosts[@]} ; do
  ssh -nq -o StrictHostKeyChecking=no -tt -i "$PRIVATE_KEY" $USER@$host "pkill java"
done
