#!/bin/bash

# This script is meant to be called from the certbot-auto binary

# Check if any of the expected variables are missing
if [ "$CERTBOT_DOMAIN" = "" -o "$CERTBOT_VALIDATION" = "" ] ; then
	echo "ERROR: Missing variables expected from certbot-auto binary!"
	exit 1
fi

cd `dirname $0`

DIR=/tmp/certbot-zoneedit/$CERTBOT_DOMAIN

# Set the arguments based on if DEBUG, VERBOSE or DRYRUN is set from calling script (in environment)
ARGS="-d $CERTBOT_DOMAIN -n _acme-challenge -v $CERTBOT_VALIDATION"
if [ $DEBUG ] ; then
	ARGS="$ARGS -D"
elif [ $VERBOSE ] ; then
	ARGS="$ARGS -V"
fi

# Time to sleep after calling DNS update - tried 5, 30 and 60 but it's not enough
WAIT_SECONDS=90
if [ $DRYRUN ] ; then
	ARGS="$ARGS -R"
	# No need to wait for dry runs
	WAIT_SECONDS=1
fi

# Run the zoneedit TXT record update script - if config not set, this will fail
echo "./zoneedit.sh $ARGS"
./zoneedit.sh $ARGS || exit $?

# Wait a bit to make sure DNS cache is cleared and update completes
echo "Sleeping $WAIT_SECONDS seconds..."
sleep $WAIT_SECONDS

