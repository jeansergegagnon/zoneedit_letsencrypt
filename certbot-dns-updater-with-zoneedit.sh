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

# Run the zoneedit TXT record update script - if config not set, this will fail
echo "./zoneedit.sh -V -d $CERTBOT_DOMAIN -n _acme-challenge -v $CERTBOT_VALIDATION -i $ID"
./zoneedit.sh -V -d $CERTBOT_DOMAIN -n _acme-challenge -v $CERTBOT_VALIDATION -i $ID || exit $?

# Update the ID for next call (if more than one from certbot-auto)
ID=($ID+1)
echo $ID > $DIR/id

# Wait a bit to make sure DNS cache is cleared and update completes
sleep 30

