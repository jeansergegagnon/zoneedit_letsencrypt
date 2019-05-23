#!/bin/bash

MYDIR="`dirname \"$0\"`"
MYDIR="`cd \"$MYDIR\" ; pwd`"

# Report error or basic script usage
Usage() {
	echo "USAGE: $0 [-h] [-a] [-D] [-V] [-R] -d domain"
	if [ "$1" = "" ] ; then
		echo "WHERE:"
		echo "       -h         Show this help output."
		echo "       -a         Enable full automation and no prompts for license or IP address recording."
		echo "       -D         Enable debug output."
		echo "       -V         Enable verbose output."
		echo "       -R         Just do a dry run"
		echo "       -d domain  The domain to create a *.domain certificate using ZoneEdit and LetsEncrypt."
	else
		echo "ERROR: $@"
		exit 1
	fi
	exit
}

# Default values
BOTDOMAIN=""
FULL_AUTO=""
DEBUG=""
VERBOSE=""
DRYRUN=""
while [ $# -gt 0 ] ; do
	if [ "$1" = "-a" ] ; then
		FULL_AUTO=1
	elif [ "$1" = "-D" ] ; then
		export DEBUG=1
	elif [ "$1" = "-V" ] ; then
		export VERBOSE=1
	elif [ "$1" = "-R" ] ; then
		export DRYRUN=1
	elif [ "$1" = "-h" ] ; then
		Usage
	elif [ "$1" = "-d" ] ; then
		shift
		BOTDOMAIN=$1
	fi
	shift
done

# Figure out where the certbot-auto script is installed
CERTBOT=""
# If we didn't specify the directory, then try to find it
if [ "$CERTBOTDIR" = "" ] ; then
	CERTBOT=`which certbot-auto 2>/dev/null`
	if [ "$CERTBOT" = "" ] ; then
		CERTBOT=`ls ~/certbot/certbot-auto 2> /dev/null`
	fi
else
	CERTBOT=$CERTBOTDIR/certbot-auto
fi

# Do not go any further if we can't find the certbot-auto binary
if [ "$CERTBOT" = "" -o ! -x "$CERTBOT" ] ; then
	Usage "Please set CERTBOTDIR before running this script or add certbot-auto to PATH"
fi

# Abort if the domain (-d) wasn't specified
if [ "$BOTDOMAIN" = "" ] ; then
	Usage "Missing domain to renew"
fi

CERTBOTDIR=`dirname $CERTBOT`
cd $CERTBOTDIR

# Path to config file
CONFIG=/etc/sysconfig/zoneedit.cfg

# Create dummy config file if there is none yet
if [ ! -f $CONFIG ] ; then
	echo "# Zoneedit config" > $CONFIG
	echo "ZONEEDIT_USER=username" >> $CONFIG
	echo "ZONEEDIT_PASS=password" >> $CONFIG
	chmod 600 $CONFIG
	sudo chown root.root $CONFIG
	echo "ERROR: Please edit $CONFIG"
	exit 1
fi

# Create initial work dir for this domain update
DIR=/tmp/certbot-zoneedit/$BOTDOMAIN
rm -fr $DIR
mkdir -p $DIR || exit $?
# We start with ID 0 on zoneedit TXT records
echo 0 > $DIR/id || exit $?

# Arguments to get DNS-01 cert only - no installing in apache
# If this is the first time you run this script, you will need to configure apache and restart it
# if this is a renewal, you just need to restart apache
ARGS="--manual --manual-auth-hook $MYDIR/certbot-dns-updater-with-zoneedit.sh --preferred-challenges dns-01"
if [ $FULL_AUTO ] ; then
	# If running from cron, add -a arument and this will prevent any prompts to allow full automation
	ARGS="--agree-tos --manual-public-ip-logging-ok --non-interactive $ARGS"
fi
if [ $DRYRUN ] ; then
	ARGS="$ARGS --dry-run"
fi
if [ $DEBUG ] ; then
	ARGS="$ARGS --debug"
fi

# Run the certbot-auto command to get DNS-01 wildcard domain cert
echo "sudo DEBUG=$DEBUG VERBOSE=$VERBOSE DRYRUN=$DRYRUN ./certbot-auto certonly $ARGS -d *.$BOTDOMAIN -d $BOTDOMAIN"
sudo DEBUG=$DEBUG VERBOSE=$VERBOSE DRYRUN=$DRYRUN ./certbot-auto certonly $ARGS -d *.$BOTDOMAIN -d $BOTDOMAIN

