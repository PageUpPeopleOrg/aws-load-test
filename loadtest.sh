#!/bin/bash

# Exit if any command errors and echo commands to console
set -xe

# Create a temporary file to store the statuses
tmp=$(mktemp -t loadtest_results.XXXXXXXXXX)
echo "Using temp file $tmp"

# Wait for background jobs and if any error codes returned then exit
function wait_for_background_jobs() {
  # Wait for all jobs to complete
  wait

  # Get the highest result code.
  result_max=$(sort -nr $tmp | head -1)
  result_min=$(sort -n $tmp | head -1)
  if [ "$result_max" -ne 0 ] || [ "$result_min" -ne 0 ] ; then 
    # Remove the temporary file
    rm -f "$tmp"
    echo "An error occurred, bailing out now..."
    exit -1
  fi
}

# Get the current project directory
PROJECT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
# Load the shared properties file
. $PROJECT_DIR/loadtest.properties
# Split the list of servers into an array
hosts=(`echo $SERVERS | tr "," "\n" | tr -d ' '`)
local_log_path=$PROJECT_DIR/$LOCAL_LOG_DIR/$LOCAL_LOG_FILE

# Make the logs dir if needed
if [ ! -d $LOCAL_LOG_DIR ]; then mkdir $LOCAL_LOG_DIR; fi
rm -f $local_log_path

# For each server copy this project directory
for host in ${hosts[@]} ; do
  {
    rsync -acP -e "ssh -o StrictHostKeyChecking=no -i '$PRIVATE_KEY'" $PROJECT_DIR/server.sh $PROJECT_DIR/loadtest.properties $PROJECT_DIR/$JMETER_PROPERTIES $PROJECT_DIR/$JMETER_TEST $USER@$host:$SERVER_DIR ;
    echo "$?" >> "$tmp" ; 
  } &
done

wait_for_background_jobs

# For each server execute the server.sh file
for host in ${hosts[@]} ; do
  {
    ssh -nq -o StrictHostKeyChecking=no -tt -i "$PRIVATE_KEY" $USER@$host "cd '$SERVER_DIR'; server_name=$host sh server.sh" ;
    echo "$?" >> "$tmp" ; 
  } &
done

wait_for_background_jobs

# Now retrieve all the log files
for host in ${hosts[@]} ; do
  rm -f $PROJECT_DIR/$LOCAL_LOG_DIR/${host}.jtl
  {
    rsync -acP -e "ssh -o StrictHostKeyChecking=no -i '$PRIVATE_KEY'" $USER@$host:$SERVER_DIR/$SERVER_LOG_DIR/$SERVER_LOG_FILE $PROJECT_DIR/$LOCAL_LOG_DIR/${host}.jtl ;
    echo "$?" >> "$tmp" ; 
  } &
done

wait_for_background_jobs

# Concatenate the log files
printf "%s\n" "${hosts[@]}" | sed s_^.*\$_$PROJECT_DIR/$LOCAL_LOG_DIR/\&.jtl_g | xargs -I {} cat {} > $local_log_path
# Zip the log files (but keep orig)
gzip -c $local_log_path > ${local_log_path}.gz
# Send the log file to Loadosophia
curl -v https://loadosophia.org/api/file/upload/ -F "token=`cat $PROJECT_DIR/$LOADOSOPHIA_KEY`" -F "projectKey=$LOADOSOPHIA_PROJECT" -F "jtl_file=@${local_log_path}.gz"

rm -f "$tmp"
exit
