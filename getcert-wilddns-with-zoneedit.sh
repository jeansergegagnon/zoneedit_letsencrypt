#!/bin/bash

MYDIR="`dirname \"$0\"`"
MYDIR="`cd \"$MYDIR\" ; pwd`"

# Report error or basic script usage
Usage() {
	echo "USAGE: $0 [-h] [-a] [-f] [-D] [-V] [-R] [-e email] -d domain"
	if [ "$1" = "" ] ; then
		echo "WHERE:"
		echo "       -h         Show this help output."
		echo "       -a         Enable full automation and no prompts for license or IP address recording."
		echo "       -f         Force update even if expiry is not soon enough."
		echo "       -n         Number of days to consider for renewal (default 10)."
		echo "       -D         Enable debug output."
		echo "       -V         Enable verbose output."
		echo "       -R         Just do a dry run."
		echo "       -e email   Send email to this address when done (requires sendmail be installed)."
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
FORCE=no
DEBUG=""
VERBOSE=""
DRYRUN=""
EMAIL=""
DAYS_BEFORE_AUTO_RENEW=10
while [ $# -gt 0 ] ; do
	if [ "$1" = "-a" ] ; then
		FULL_AUTO=1
	elif [ "$1" = "-n" ] ; then
		shift
		export DAYS_BEFORE_AUTO_RENEW=$1
	elif [ "$1" = "-e" ] ; then
		shift
		export EMAIL=$1
	elif [ "$1" = "-f" ] ; then
		export FORCE=yes
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

if [ ! "$EMAIL" = "" -a "$SENDMAIL" = "" ] ; then
	SENDMAIL=`which sendmail 2>/dev/null`
	if [ "$SENDMAIL" = "" ] ; then
		if [ -x /usr/sbin/sendmail ] ; then
			SENDMAIL=/usr/sbin/sendmail
		fi
	fi
	if [ "$SENDMAIL" = "" ] ; then
		Usage "Can't find sendmail. Please install it or set environment variable SENDMAIL to point to binary"
	fi
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
	# If running from cron, add -a argument and this will prevent any prompts to allow full automation
	ARGS="--agree-tos --manual-public-ip-logging-ok --non-interactive $ARGS"
fi
if [ $DRYRUN ] ; then
	ARGS="$ARGS --dry-run"
fi
if [ $DEBUG ] ; then
	ARGS="$ARGS --debug"
fi

# Check the cert's expiry date
HOURS_TO_EXPIRE=0
if [ -e /etc/letsencrypt/live/$BOTDOMAIN/cert.pem ] ; then
	OPENSSL=`which openssl 2>/dev/null`
	if [ $OPENSSL ] ; then
		EXPIRE_DATE=`$OPENSSL x509 -in /etc/letsencrypt/live/$BOTDOMAIN/cert.pem -noout -dates | grep notAfter | cut -d= -f2`
		EXPIRE_TS=`date -d "$EXPIRE_DATE" +%s`
		NOW_TS=`date +%s`
		SECS_TO_EXPIRE=$[$EXPIRE_TS-$NOW_TS]
		HOURS_TO_EXPIRE=$[$SECS_TO_EXPIRE/60/60]
		DAYS_TO_EXPIRE=$[$SECS_TO_EXPIRE/60/60/24]
		echo "`date`: Certificate for $BOTDOMAIN expires on $EXPIRE_DATE (or $DAYS_TO_EXPIRE days or $HOURS_TO_EXPIRE hours or $SECS_TO_EXPIRE seconds)"
	else
		echo "WARNING: Can't find openssl to check cert expiry - will let letsencrypt check for us"
	fi
fi

if [ $HOURS_TO_EXPIRE -lt $[24*$DAYS_BEFORE_AUTO_RENEW] -o "$FORCE" = "yes" -o $HOURS_TO_EXPIRE -eq 0 ] ; then
	
	# Prepare a clean workdir - this is needed so that the called script can know both TXT records as
	# zoneedit might toggle them in the DNS records form data list
	WORKDIR=/tmp/certbot/$$
	rm -fr $WORKDIR
	mkdir -p $WORKDIR

	# Run the certbot-auto command to get DNS-01 wildcard domain cert
	OUT=/tmp/certbot.out.$$
	echo "`date`: sudo WORKDIR=$WORKDIR DEBUG=$DEBUG VERBOSE=$VERBOSE DRYRUN=$DRYRUN ./certbot-auto certonly $ARGS -d *.$BOTDOMAIN -d $BOTDOMAIN" | tee $OUT
	sudo WORKDIR=$WORKDIR DEBUG=$DEBUG VERBOSE=$VERBOSE DRYRUN=$DRYRUN ./certbot-auto certonly $ARGS -d *.$BOTDOMAIN -d $BOTDOMAIN 2>&1 | tee -a $OUT
	echo "`date`: Completed call to certbot-auto" | tee -a $OUT

	if [ ! "$EMAIL" = "" ] ; then
		if [ `grep -c "error" $OUT` -gt 0 ] ; then
			SUBJECT="Failed to update $BOTDOMAIN"
		elif [ `grep -c "Cert not yet due for renewal" $OUT` -gt 0 ] ; then
			SUBJECT="Domain $BOTDOMAIN not due for renewal"
		else
			SUBJECT="Renewed certificate for $BOTDOMAIN"
		fi
		(
			echo "Subject: certbot: $SUBJECT"
			echo "To: $EMAIL"
			echo "From: Certbot <certbot@$BOTDOMAIN>"
			echo "Content-type: text/html"
			echo ""
			echo "Log output:"
			echo "<pre>"
			cat $OUT
			echo "</pre>"
		) | $SENDMAIL -t -i -fcertbot@$BOTDOMAIN -FCertbot
	fi
	rm $OUT
else
	echo "`date`: Not renewing yet. Use -f to force renewal even if cert is not expiring soon"
fi

