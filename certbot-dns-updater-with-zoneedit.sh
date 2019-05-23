#!/bin/bash

# This script is meant to be called from the certbot-auto binary

# Check if any of the expected variables are missing
if [ "$CERTBOT_DOMAIN" = "" -o "$CERTBOT_VALIDATION" = "" ] ; then
	echo "ERROR: Missing variables expected from certbot-auto binary!"
	exit 1
fi

cd `dirname $0`

DIR=/tmp/certbot-zoneedit/$CERTBOT_DOMAIN
# This gets created by our initial script ./renew-wilddns.sh
# If it's missing, we can't continue
if [ ! -f $DIR/id ] ; then
	echo "ERROR: Failed to find $DIR/id file!"
	exit 1
fi

# Get the ID (initial will be 0)
ID=`cat $DIR/id`

# Set the arguments based on if DEBUG, VERBOSE or DRYRUN is set from calling script (in environment)
ARGS="-d $CERTBOT_DOMAIN -n _acme-challenge -v $CERTBOT_VALIDATION -i $ID"
if [ $DEBUG ] ; then
	ARGS="$ARGS -D"
elif [ $VERBOSE ] ; then
	ARGS="$ARGS -V"
fi

# Time to sleep after calling DNS update
WAIT_SECONDS=60
if [ $DRYRUN ] ; then
	ARGS="$ARGS -R"
	# No need to wait for dry runs
	WAIT_SECONDS=1
fi

# Run the zoneedit TXT record update script - if config not set, this will fail
echo "./zoneedit.sh $ARGS"
./zoneedit.sh $ARGS || exit $?

# Update the ID for next call (if more than one from certbot-auto)
ID=$[$ID+1]
echo $ID > $DIR/id

# Wait a bit to make sure DNS cache is cleared and update completes
sleep $WAIT_SECONDS

