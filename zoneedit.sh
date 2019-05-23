#!/bin/bash

# Temp dir where we store our files as we execute
TMPDIR=/tmp/zoneedit

# Path to config file
CONFIG=/etc/sysconfig/zoneedit.cfg

# File to store cookies and read them back between each curl call
COOKIES=$TMPDIR/cookies.txt

# No debug by default - -D enables this
DEBUG=""

# No verbose by default - -V enabled this
VERBOSE=""

# Output enabled by default (disable with -Q switch)
ENABLE_OUTPUT=1

# We start new session unless -k specified
ZAP=1

# No dry run by default
DRYRUN=""

# Run a curl command
# Usage:
#   CURL url output [data]
# Where:
#      url     is the URL to connect to
#      output  is the prefix of the file to save output to in $TMPDIR
#              this will create 3 files: $output.html - stdout - or html source
#                                        $output.stderr - stderr - or curl status output
#                                        $outut.header - the headers returned from the request

CURL() {
	local URL=$1
	local OUT=$2
	shift 2
	local DATA=$@
	local CMD="curl -b $COOKIES -c $COOKIES -D $TMPDIR/$OUT.header $DATA $URL"
	if [ -f $TMPDIR/$OUT.html ] ; then
		if [ $DEBUG ] ; then
			echo "Found $OUT.htnl. Not running '$CMD' > $TMPDIR/$OUT.html 2> $TMPDIR/$OUT.stderr"
		fi
	else
		if [ $DEBUG ] ; then
			echo "Running '$CMD' > $TMPDIR/$OUT.html 2> $TMPDIR/$OUT.stderr"
		elif [ $VERBOSE ] ; then
			echo "$URL"
		fi
		$CMD 2> $TMPDIR/$OUT.stderr | sed -e "s/>/>\\n/g" > $TMPDIR/$OUT.html
	fi
}

# Usage of script
# This is called on error or as part of a "-h" (help) argument
Usage() {
	echo "USAGE: $0 [-h] [-k] [-D] [-V] [-Q] -d domain -n name -v value [-t ttl] [-i id]"
	if [ "$1" = "" ] ; then
		echo "WHERE:"
		echo "      -h         Show this help output."
		echo "      -k         Do not Zap the contents of tmpdir before starting to start new session. Instead re-use existing session files."
		echo "      -D         Enable debug output (WARNING: Password output to stdout)."
		echo "      -V         Enable verbose output."
		echo "      -Q         Disable all output (quiet mode)."
		echo "      -R         Do just a dry run and do not change anything on Zoneedit domain."
		echo "      -d domain  Specify the domain to manage (required)."
		echo "      -n name    Specify the name of the TXT record to edit (required)."
		echo "      -v value   Specify the value of the TXT record to edit (require)."
		echo "      -t ttl     Specify time to live in seconds (optional - default 60)."
		echo "      -i id      Specify ID of TXT record to edit (optional - default 0)."
	else
		echo "ERROR: $@"
		exit 1
	fi
	exit
}

# Output message to console with timestamp
output() {
	if [ $ENABLE_OUTPUT ] ; then
		echo "`date`: $@"
	fi
}

# Default time to live is 60 seconds
txt_ttl=60
# Default record ID is the first one (#0) - should be 0, 1, 2, 3, 4.. etc
txt_id=0

# Extract any passed in arguments
while [ $# -gt 0 ] ; do
	if [ "$1" = "-h" -o "$1" = "-?" -o "$1" = "--help" ] ; then
		Usage
	elif [ "$1" = "-D" ] ; then
		DEBUG=1
		VERBOSE=1
	elif [ "$1" = "-V" ] ; then
		VERBOSE=1
	elif [ "$1" = "-Q" ] ; then
		ENABLE_OUTPUT=
	elif [ "$1" = "-R" ] ; then
		DRYRUN=1
	elif [ "$1" = "-d" ] ; then
		shift
		txt_domain=$1
	elif [ "$1" = "-n" ] ; then
		shift
		txt_name=$1
	elif [ "$1" = "-v" ] ; then
		shift
		txt_value=$1
	elif [ "$1" = "-t" ] ; then
		shift
		txt_ttl=$1
	elif [ "$1" = "-i" ] ; then
		shift
		txt_id=$1
	elif [ "$1" = "-k" ] ; then
		ZAP=
	fi
	shift
done

# Report errors on missing arguments
if [ "$txt_domain" = "" ] ; then
	Usage "Missing -d domain option"
fi
if [ "$txt_name" = "" ] ; then
	Usage "Missing -n name option"
fi
if [ "$txt_value" = "" ] ; then
	Usage "Missing -v value option"
fi

# Simple check to ensure we are running as root - since we setup certs as root and need to secure password in Zoneedit config file
if [ ! -w /etc/passwd ] ; then
	echo "ERROR: Must run as root"
	exit
fi

# Create dummy config file if there is none yet
if [ ! -f $CONFIG ] ; then
	echo "# Zoneedit config" > $CONFIG
	echo "ZONEEDIT_USER=username" >> $CONFIG
	echo "ZONEEDIT_PASS=password" >> $CONFIG
	chmod 600 $CONFIG
fi

# Source the config file
. $CONFIG

# Check if the config contains dummy values and abort if so
if [ "$ZONEEDIT_USER" = "" -a "$ZONEEDIT_PASS" = "" -o "$ZONEEDIT_USER" = "username" -o "$ZONEEDIT_PASS" = "password" ] ; then
	echo "ERROR: Please edit $CONFIG"
	exit 1
fi

# If we want new session, we clear all work files in temp dir
if [ $ZAP ] ; then
	rm -fr $TMPDIR
fi

# Create tmp dir if it doesn't exist yet
if [ ! -d $TMPDIR ] ; then
	mkdir -p $TMPDIR
fi

# Check if the quiet mode switch was enabled (should not be used with -D or -V)
if [ "$ENABLE_OUTPUT" = "" ] ; then
	if [ $DEBUG ] ; then
		echo "WARNING: Disabling debug mode with -Q option"
	elif [ $VERBOSE] ; then
		echo "WARNING: Disabling verbose mode with -Q option"
	fi
	VERBOSE=
	DEBUG=
fi

# ------------------------------------------------------------------------------
# All initialization is done
# ------------------------------------------------------------------------------

# Start the process
# First, we need to access the main login page to initialize cookies and session info
output "Getting initial login cookies"
CURL https://cp.zoneedit.com/login.php 01login

# Get the initial token
token=`grep csrf_token $TMPDIR/01login.html | sed -e "s/.*value=//" | cut -d'"' -f2`
if [ $DEBUG ] ; then
	echo "csrf_token = '$token'"
fi

# Create the required hashes for login
login_chal=`grep login_chal.*VALUE $TMPDIR/01login.html  | sed -e "s/.*login_chal//" | cut -d'"' -f3`
if [ $DEBUG ] ; then
	echo "login_chal = '$login_chal'"
fi
MD5_pass=`echo "$ZONEEDIT_PASS" | md5sum | cut -d' ' -f1`
if [ $DEBUG ] ; then
	echo "MD5_pass = '$MD5_pass'"
fi
login_hash=`echo "$ZONEEDIT_USER$MD5_pass$login_chal" | md5sum | cut -d' ' -f1`
if [ $DEBUG ] ; then
	echo "login_hash = '$login_hash'"
fi

# Send the login POST request
output "Logging in"
CURL https://cp.zoneedit.com/home/ 02home -d login_chal=$login_chal -d login_hash=$hash -d login_user=$ZONEEDIT_USER -d login_pass=$ZONEEDIT_PASS -d csrf_token=$token -d login=

# Check that login was successful
# when successfull, we get this in the header
#    Location: https://cp.zoneedit.com/manage/domains/
# on failure, we get this in the header
#    Location: https://cp.zoneedit.com/login.php

LOCATION=`grep ^Location: $TMPDIR/02home.header | cut -d' ' -f2`
if [ $DEBUG ] ; then
	echo "LOCATION = '$LOCATION'"
fi
if [ `echo $LOCATION | grep -c manage/domains` -eq 0 ] ; then
	echo "ERROR: Invalid user of password!"
	exit 1
fi

# Get our domain list
output "Validating domain"
CURL https://cp.zoneedit.com/manage/domains/ 03domains

# Check that the requested domain exists in our domain list
if [ `grep -c "index.php?LOGIN=$txt_domain\"" $TMPDIR/03domains.html` -eq 0 ] ; then
	echo "ERROR: Invalid domain '$txt_domain'!"
	exit 1
fi

# Access the domain we are wanting to edit
CURL https://cp.zoneedit.com/manage/domains/zone/index.php?LOGIN=$txt_domain 04domain

# Check we successfully switched to domain
if [ `grep -c "^$txt_domain</" $TMPDIR/04domain.html` -eq 0 ] ; then
	echo "ERROR: Unable to access domain '$txt_domain'!"
	exit 1
fi

# Switch to the TXT records edit page
output "Loading TXT edit page"
CURL https://cp.zoneedit.com/manage/domains/txt/ 05txt

# Click the edit button
CURL https://cp.zoneedit.com/manage/domains/txt/edit.php 06edit

# Get the token and other generated values
FILE=$TMPDIR/06edit.html
token=`grep csrf_token $FILE | sed -e "s/.*value=//" | cut -d'"' -f2`
if [ $DEBUG ] ; then
	echo "csrf_token = '$token'"
fi
multipleTabFix=`grep multipleTabFix $FILE | sed -e "s/.*multipleTabFix//" | cut -d'"' -f3`
if [ $DEBUG ] ; then
	echo "multipleTabFix = '$multipleTabFix'"
fi

# Figure out which id to use in the TXT records based on our name and id we asked for
i=0
found_ids=0
our_id=-1
while [ `grep -c TXT::$i::host $FILE` -gt 0 ] ; do
	name=`grep "TXT::$i::host.*value=" $FILE | sed -e "s/.*value=//" | cut -d\" -f2`
	# If the TXT record has no name or the same as ours...
	if [ "$name" = "" -o "$name" = "$txt_name" ] ; then
		if [ $DEBUG ] ; then
			echo "Checking id $i with name='$name'"
		fi
		# If the found id count is same as our, then use it
		if [ $found_ids -eq $txt_id ] ; then
			if [ $VERBOSE ] ; then
				echo "Using id $i with name='$name'"
			fi
			our_id=$i
			break
		fi
		# If not, just increase found count for next loop
		found_ids=$[$found_ids+1]
	else
		if [ $DEBUG ] ; then
			echo "Skipping id $i with name='$name'"
		fi
	fi
	i=$[$i+1]
done

# If we didn't set the id, then we need to abort
if [ $our_id -eq -1 ] ; then
	echo "ERROR: Failed to find a TXT record to use! Please cleanup some TXT records in ZoneEdit and try again."
	exit 1
fi

# Build the full data set based on what is already configured in the domain
DATA="-d MODE=edit -d csrf_token=$token -d multipleTabFix=$multipleTabFix"
i=0
while [ `grep -c TXT::$i::host $FILE` -gt 0 ] ; do
	name=`grep "TXT::$i::host.*value=" $FILE | sed -e "s/.*value=//" | cut -d\" -f2`
	if [ $DEBUG ] ; then
		echo "TXT::$i::host = '$name'"
	fi
	val=`grep "TXT::$i::txt.*value=" $FILE | sed -e "s/.*value=//" | cut -d\" -f2`
	if [ $DEBUG ] ; then
		echo "TXT::$i::txt = '$val'"
	fi
	ttl=`grep "TXT::$i::ttl.*value=" $FILE | sed -e "s/.*value=//" | cut -d\" -f2`
	if [ $DEBUG ] ; then
		echo "TXT::$i::ttl = '$ttl'"
	fi
	if [ $i -eq $our_id ] ; then
		# If it's the record we are asking to edit, the set values based on what we passed in
		if [ $DEBUG ] ; then
			echo "Using our values for TXT::$i::...."
		fi
		DATA="$DATA -d TXT::$our_id::host=$txt_name -d TXT::$our_id::txt=$txt_value -d TXT::$our_id::ttl=$txt_ttl"
	elif [ ! "$name" = "" ] ; then
		# Otherwise, get existing data to pass back in
		if [ $DEBUG ] ; then
			echo "Using values already set for TXT::$i::...."
		fi
		DATA="$DATA -d TXT::$i::host=$name -d TXT::$i::txt=$val -d TXT::$i::ttl=$ttl"
	fi
	i=$[$i+1]
done

if [ $DRYRUN ] ; then

	output "OK: Succcessfully completed Dry-run."
	exit 0

else

	# Send the new values (click on the save button)
	output "Sending new TXT record values"
	CURL https://cp.zoneedit.com/manage/domains/txt/edit.php 07save $DATA

	# Get token and other values
	FILE=$TMPDIR/07save.html
	token=`grep csrf_token $FILE | sed -e "s/.*value=//" | cut -d'"' -f2`
	if [ $DEBUG ] ; then
		echo "csrf_token = '$token'"
	fi
	multipleTabFix=`grep multipleTabFix $FILE | sed -e "s/.*multipleTabFix//" | cut -d'"' -f3`
	if [ $DEBUG ] ; then
		echo "multipleTabFix = '$multipleTabFix'"
	fi
	NEW_TXT=`grep hidden.*NEW_TXT $FILE  | sed -e "s/.*NEW_TXT//" | cut -d'"' -f3`
	if [ $DEBUG ] ; then
		echo "NEW_TXT = '$NEW_TXT'"
	fi

	# Save the new values (click the confirm button)
	CURL https://cp.zoneedit.com/manage/domains/txt/confirm.php 08confirm -d csrf_token=$token -d confirm= -d multipleTabFix=$multipleTabFix -d NEW_TXT=$NEW_TXT

	# Finally, get the table back to confirm settings saves properly
	output "Confirming change succeeded"
	CURL https://cp.zoneedit.com/manage/domains/txt/edit.php 09edit

	# Check that new values are what we expect
	FILE=$TMPDIR/09edit.html
	name=`grep "TXT::$our_id::host.*value=" $FILE | sed -e "s/.*value=//" | cut -d\" -f2`
	if [ $DEBUG ] ; then
		echo "name = '$name'"
	fi
	val=`grep "TXT::$our_id::txt.*value=" $FILE | sed -e "s/.*value=//" | cut -d\" -f2`
	if [ $DEBUG ] ; then
		echo "val = '$val'"
	fi
	ttl=`grep "TXT::$our_id::ttl.*value=" $FILE | sed -e "s/.*value=//" | cut -d\" -f2`
	if [ $DEBUG ] ; then
		echo "ttl = '$ttl'"
	fi
	if [ "$name" = "$txt_name" -a "$val" = "$txt_value" -a "$ttl" = "$txt_ttl" ] ; then
		echo "OK: Successfully set TXT record $txt_name.$txt_domain=$txt_value"
	else
		echo "ERROR: TXT record #$our_id is $name.$txt_domain=$val instead of expected $txt_name.$txt_domain=$txt_value"
		exit 1
	fi
fi

