#!/bin/bash

MYDIR="`dirname \"$0\"`"
MYDIR="`cd \"$MYDIR\" ; pwd`"

# Report error or basic script usage
Usage() {
	echo "USAGE: $0 [-h] [-C] [-a] [-f] [-D] [-V] [-R] [-e email] -d domain [-c]"
	if [ "$1" = "" ] ; then
		echo "WHERE:"
		echo "       -h         Show this help output."
		echo "       -C         Check only expiry date and exit."
		echo "       -a         Enable full automation and no prompts for license or IP address recording."
		echo "       -f         Force update even if expiry is not soon enough."
		echo "       -n         Number of days to consider for renewal (default 10)."
		echo "       -D         Enable debug output."
		echo "       -V         Enable verbose output."
		echo "       -R         Just do a dry run."
		echo "       -e email   Send email to this address when done (requires sendmail be installed)."
		echo "       -d domain  The domain to create a *.domain certificate using ZoneEdit and LetsEncrypt."
		echo "       -c         Use certbot instead of certbot-auto."
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
CHECKONLY=""
DEBUG=""
VERBOSE=""
DRYRUN=""
EMAIL=""
DAYS_BEFORE_AUTO_RENEW=10
CERTBOT_EXE=certbot-auto
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
	elif [ "$1" = "-C" ] ; then
		export CHECKONLY=1
	elif [ "$1" = "-D" ] ; then
		export DEBUG=1
	elif [ "$1" = "-V" ] ; then
		export VERBOSE=1
	elif [ "$1" = "-R" ] ; then
		export DRYRUN=1
	elif [ "$1" = "-h" ] ; then
		Usage
	elif [ "$1" = "-c" ] ; then
		CERTBOT_EXE=certbot
	elif [ "$1" = "-d" ] ; then
		shift
		BOTDOMAIN=$1
	fi
	shift
done

# Figure out where the $CERTBOT_EXE script is installed
CERTBOT=""
# If we didn't specify the directory, then try to find it
if [ "$CERTBOTDIR" = "" ] ; then
	CERTBOT=`which $CERTBOT_EXE 2>/dev/null`
	if [ "$CERTBOT" = "" ] ; then
		CERTBOT=`ls ~/certbot/$CERTBOT_EXE 2> /dev/null`
	fi
else
	CERTBOT=$CERTBOTDIR/$CERTBOT_EXE
fi

# Do not go any further if we can't find the $CERTBOT_EXE binary
if [ "$CERTBOT" = "" -o ! -x "$CERTBOT" ] ; then
	Usage "Please set CERTBOTDIR before running this script or add $CERTBOT_EXE to PATH"
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
if [ ! -w /etc/passwd ] ; then
	Usage "Must run as root"
	exit 1
fi


CERTBOTDIR=`dirname $CERTBOT`
cd $CERTBOTDIR

OLDCONFIG=/etc/sysconfig/zoneedit.cfg
# We don't use this anymore but if it's there use it to set default
# user for domain based config file below
if [ -f $OLDCONFIG ] ; then
       . $OLDCONFIG
else
       ZONEEDIT_USER=username
fi

# Path to config file
CONFIG=/etc/sysconfig/zoneedit/$BOTDOMAIN.cfg

# Create dummy config file if there is none yet
if [ ! -f $CONFIG ] ; then
	if [ ! -d `dirname $CONFIG` ] ; then
		mkdir -p `dirname $CONFIG`
	fi
	echo "# Zoneedit config for domain $BOTDOMAIN" > $CONFIG
	echo "# get your token, by:" >> $CONFIG
	echo "#   1- Go to your DNS settings for your domain" >> $CONFIG
	echo "#   2- Click on Domaines top level menu" >> $CONFIG
	echo "#   3- Select the DNS Settings meny entry" >> $CONFIG
	echo "#   4- Click on the wrench by the DYN records secion" >> $CONFIG
	echo "#   5- Scroll to bottom and click the view on the DYN Authention token" >> $CONFIG
	echo "" >> $CONFIG
	echo "ZONEEDIT_USERNAME=$ZONEEDIT_USER" >> $CONFIG
	echo "ZONEEDIT_DYN_TOKEN=token" >> $CONFIG
	chmod 600 $CONFIG
fi

# Source the config file
. $CONFIG

if [ "$ZONEEDIT_DYN_TOKEN" = "token" ] ; then
	cat $CONFIG
	echo "ERROR: Edit the file $CONFIG and set your username and token."
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

if [ $CHECKONLY ] ; then
	exit
fi

if [ $HOURS_TO_EXPIRE -gt $[24*$DAYS_BEFORE_AUTO_RENEW] -a "$FORCE" = "no" -a $HOURS_TO_EXPIRE -ne 0 ] ; then
	echo "`date`: Not renewing yet. Use -f to force renewal even if cert is not expiring soon"
	exit 0
fi

# Prepare a clean workdir - this is needed so that the called script can know both TXT records as
# zoneedit might toggle them in the DNS records form data list
WORKDIR=/tmp/certbot/$$
rm -fr $WORKDIR
mkdir -p $WORKDIR
trap "rm -fr $WORKDIR" EXIT

# delete old TXT records
DIR=/var/run/zoneedit/$BOTDOMAIN
# If this file exists, then old update was run before
SAVEFILE=$DIR/txt1
if [ -f $SAVEFILE ] ; then
	for FILE in $DIR/txt* ; do
		txtval=`cat $FILE`
		OUT=$WORKDIR/`basename $FILE`.out
		if [ $VERBOSE ] ; then
			echo "`date`: Deleting old TXT _acme-challenge.$BOTDOMAIN $txtval"
		fi
		if [ $DEBUG ] ; then
			echo "`date`: curl -s -u$ZONEEDIT_USERNAME:$ZONEEDIT_DYN_TOKEN 'https://dynamic.zoneedit.com/txt-delete.php?host=_acme-challenge.$BOTDOMAIN&rdata=$txtval'"
		fi
		curl -s -u$ZONEEDIT_USERNAME:$ZONEEDIT_DYN_TOKEN "https://dynamic.zoneedit.com/txt-delete.php?host=_acme-challenge.$BOTDOMAIN&rdata=$txtval" > $OUT 2>&1
		#<SUCCESS CODE="200" TEXT="_acme-challenge.jsgagnon.com TXT with rdata 8dBAg83rWjrwn3fRnPkLCoFJQrOlQL_1QREpYP4A62E deleted" ZONE="jsgagnon.com">
		echo "`date`: Wait 15 seconds - zoneedit minium wait is 10 seconds"
		sleep 15
		if [ $DEBUG ] ; then
			echo "`date`: $OUT" 
		fi
		SUCCESS=""
		if [ `grep -c SUCCESS $OUT` -gt 0 ] ; then
			SUCCESS=1
		fi
		if [ $SUCCESS ] ; then
			# remove it so we don't try to delete again
			rm $FILE
		else
			cat $OUT
			exit 1
		fi
	done
fi

# Run the $CERTBOT_EXE command to get DNS-01 wildcard domain cert
OUT=/tmp/certbot.out.$$
echo "`date`: WORKDIR=$WORKDIR DEBUG=$DEBUG VERBOSE=$VERBOSE DRYRUN=$DRYRUN ./$CERTBOT_EXE certonly $ARGS -d *.$BOTDOMAIN -d $BOTDOMAIN" | tee $OUT
WORKDIR=$WORKDIR DEBUG=$DEBUG VERBOSE=$VERBOSE DRYRUN=$DRYRUN ./$CERTBOT_EXE certonly $ARGS -d *.$BOTDOMAIN -d $BOTDOMAIN 2>&1 | tee -a $OUT
echo "`date`: Completed call to $CERTBOT_EXE" | tee -a $OUT

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

