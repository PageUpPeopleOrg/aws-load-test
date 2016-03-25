#!/bin/bash
# Use amzn-ami-hvm-2015.09.1.x86_64-ebs (ami-97d58af4)

# Echo commands to console
set -x

if [ -z "$server_name" ] ; then server_name="-" ; fi

PROJECT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

. $PROJECT_DIR/loadtest.properties

# Install java
sudo yum install -y java-1.8.0-openjdk.x86_64

# Install jmeter and copy properties file
JMETER_DIR=apache-jmeter-$JMETER_VERSION
if [ ! -d $JMETER_DIR ]; then
  curl http://apache.mirror.serversaustralia.com.au//jmeter/binaries/apache-jmeter-${JMETER_VERSION}.tgz -o $PROJECT_DIR/$JMETER_DIR.tgz
  tar zxf $PROJECT_DIR/$JMETER_DIR.tgz
  cp -f $JMETER_PROPERTIES $PROJECT_DIR/$JMETER_DIR/bin/
fi

# Start the test
rm -rf $PROJECT_DIR/$SERVER_LOG_DIR
mkdir $PROJECT_DIR/$SERVER_LOG_DIR
sh $PROJECT_DIR/$JMETER_DIR/bin/jmeter -n -t $JMETER_TEST -l $SERVER_LOG_DIR/$SERVER_LOG_FILE -JUsers=$TEST_USERS -JDuration=$TEST_DURATION -JRampUp=$TEST_RAMP_UP -JThreadGroupName=$server_name -JHitsPerMin=$TEST_HITS_PER_MIN
