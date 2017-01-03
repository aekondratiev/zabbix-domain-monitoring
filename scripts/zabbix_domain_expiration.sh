#!/bin/bash

# set -x

PROGPATH=`echo $0 | /bin/sed -e 's,[\\/][^\\/][^\\/]*$,,'`

#. $PROGPATH/utils.sh

# Default values (days):
critical=30
warning=60
whois="/usr/bin/whois"
host=""

usage() {
	echo "check_domain - v1.01p1"
	echo "Copyright (c) 2005 Tom〓s N〓〓ez Lirola <tnunez@criptos.com> under GPL License"
	echo "Modified by MATSUU Takuto <matsuu@gentoo.org>"
	echo "Modified by Tateoka Mamoru <qphoney@gmail.com>"
	echo ""
	echo "This plugin checks the expiration date of a domain name." 
	echo ""
	echo "Usage: $0 -h | -d <domain> [-W <command>] [-H <host>] [-c <critical>] [-w <warning>]"
	echo "NOTE: -d must be specified"
	echo ""
	echo "Options:"
	echo "-h"
	echo "	Print detailed help"
	echo "-d DOMAIN"
	echo "	Domain name to check"
	echo "-H HOST"
	echo "	Connect to server HOST"
	echo "-W COMMAND"
	echo "	Use COMMAND instead of whois"
	echo "-w"
	echo "	Response time to result in warning status (days)"
	echo "-c"
	echo "	Response time to result in critical status (days)"
	echo ""
	echo "This plugin will use whois service to get the expiration date for the domain name. "
	echo "Example:"
	echo "	$0 -d example.org -w 30 -c 10"
	echo "	$0 -d example.jp/e -H whois.jprs.jp -w 30 -c 10"
	echo "	$0 -d example.jp -W /usr/bin/jwhois -w 30 -c 10"
	echo ""
}

# Parse arguments
args=`getopt -o hd:w:c:W:H: --long help,domain:,warning:,critical:,whois:,host: -u -n $0 -- "$@"`
[ $? != 0 ] && echo "$0: Could not parse arguments" && echo "Usage: $0 -h | -d <domain> [-W <comman>] [-c <critical>] [-w <warning>]" && exit
set -- $args

while true ; do
	case "$1" in
		-h|--help)	usage;exit;;
		-d|--domain)	domain=$2;shift 2;;
		-w|--warning)	warning=$2;shift 2;;
		-c|--critical)	critical=$2;shift 2;;
		-W|--whois)	whois=$2;shift 2;;
		-H|--host)	host="-h $2";shift 2;;
		--)		shift; break;;
		*)		echo "Internal error!" ; exit 1 ;;
	esac
done

[ -z $domain ] && echo "UNKNOWN - There is no domain name to check" && exit $STATE_UNKNOWN

# Looking for whois binary
if [ ! -x $whois ]; then
	echo "UNKNOWN - Unable to find whois binary in your path. Is it installed? Please specify path."
	exit $STATE_UNKNOWN
fi

TRYCOUNT=10
TRY=0
RET=1
WHOISTEMP=$(mktemp /tmp/whoistmp.XXXXXXXXXX) || { echo "Failed to create temp file"; exit 1; }
# Calculate days until expiration
TLDTYPE=`echo ${domain##*.} | tr '[A-Z]' '[a-z]'`
#echo "host:$domain"
if [ "${TLDTYPE}" == "in" -o "${TLDTYPE}" == "info" ]; then
	expiration=`$whois $host $domain | awk '/Expiration Date:/ { print $2 }' |cut -d':' -f2`
elif [ "${TLDTYPE}" == "net" ]; then
	expiration=`$whois $host $domain | awk '/Expiration Date/ {print $5,$6}'`
elif [ "${TLDTYPE}" == "cc" ]; then
	expiration=`$whois $host $domain | awk '/Expiration Date:/ {print $5}' |cut -d'T' -f1`
elif [ "${TLDTYPE}" == "edu" ]; then
	expiration=`$whois $host $domain | awk '/Domain expires:/ {print $3}'`
elif [ "${TLDTYPE}" == "org" -o "${TLDTYPE}" == "xxx" ]; then
	expiration=`$whois $host $domain | awk '/Registry Expiry Date:/ {print $4}'`
elif [ "${TLDTYPE}" == "us" -o "${TLDTYPE}" == "co" ]; then
	expiration=`$whois $host $domain | awk '/Domain Expiration Date:/ {print $4,$5,$6,$7,$8,$9}'`
elif [ "${TLDTYPE}" == "ru" ]; then
        expiration=`$whois $host $domain | awk '/paid-till:/ {print $2}'|sed 's/\./\-/g'`
elif [ "${TLDTYPE}" == "com" ]; then
	until [ "${RET}" -eq 0 -o "${TRY}" -ge "${TRYCOUNT}" ]; do
		$whois $host $domain > $WHOISTEMP 2>&1
		RET=$?
		let TRY+=1
		sleep 1
	done
	expiration=`cat $WHOISTEMP | awk '/Expiration Date:/ {print $5}'`
elif [ "${TLDTYPE}" == "net" ]; then
	expiration=`$whois $host $domain | awk '/Domain Expiration Date:/ { print $6"-"$5"-"$9 }'`
elif [ "${TLDTYPE}" == "sc" ]; then
	expiration=`$whois -h whois2.afilias-grs.net $host $domain | awk '/Expiration Date:/ { print $2 }' | awk -F : '{ print $2 }'`
elif [ "${TLDTYPE}" == "jp" -o "${TLDTYPE}" == "jp/e" -o "${TLDTYPE}" == "am"  ]; then
	expiration=`$whois $host $domain | awk '/Expires/ { print $NF }'`
    if [ -z $expiration ]; then
	    expiration=`$whois $host $domain | awk '/State/ { print $NF }' | tr -d \(\)`
    fi
else
	expiration=`$whois $host $domain | awk '/Expiration/ { print $NF }'`
fi

rm $WHOISTEMP

#echo $expiration
expseconds=`date +%s --date="$expiration" 2>&1`
if [ $? -ne 0 ]; then
    expseconds=`date +%s`
fi
nowseconds=`date +%s`
((diffseconds=expseconds-nowseconds))
expdays=$((diffseconds/86400))

# Trigger alarms if applicable
#[ -z "$expiration" ] && echo "UNKNOWN - Domain doesn't exist or no WHOIS server available." && exit
#[ $expdays -lt 0 ] && echo "CRITICAL - Domain expired on $expiration" && exit $STATE_CRITICAL
#[ $expdays -lt $critical ] && echo "CRITICAL - Domain will expire in $expdays days" && exit $STATE_CRITICAL
#[ $expdays -lt $warning ]&& echo "WARNING - Domain will expire in $expdays days" && exit $STATE_WARNING

# No alarms? Ok, everything is right.
#echo "OK - Domain will expire in $expdays days"
#exit $STATE_OK

echo $expdays
#echo 30
exit $STATE_OK

