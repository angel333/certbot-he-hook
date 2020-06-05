#!/bin/bash


## Help ################################################################

if [ -z "$CERTBOT_DOMAIN" ] || [ -z "$CERTBOT_VALIDATION" ]; then
  cat <<HELP

 == Certbot hook for Hurricane Electric DNS service ===========================

 !! This script is intended to be used as a hook script for certbot !!

 With this script, domains that have DNS hosted at Hurricane Electric are
 verified automatically, i.e. without the need for a webroot verification or
 manually adding TXT records.

 - You need to provide either a session ID, or login credentials through
   environment variables (see examples below). Session ID should be faster.

 Example usage:

  1) Create a new certificate for a domain:
  
     HE_USER=<username> HE_PASS=<password> certbot certonly \\
       --preferred-challenges dns \\
       --email your@email.com \\
       --manual \\
       --manual-auth-hook /path/to/certbot-he-hook.sh  \\
       --manual-cleanup-hook /path/to/certbot-he-hook.sh  \\
       --manual-public-ip-logging-ok \\
       --domain <requested.domain.com>
  
  2) Renew certificates for all domains:
          
     HE_USER=<username> HE_PASS=<password> certbot renew \\
       --preferred-challenges dns \\
       --manual-auth-hook /path/to/certbot-he-hook.sh  \\
       --manual-cleanup-hook /path/to/certbot-he-hook.sh  \\
       --manual-public-ip-logging-ok

 --

   Author: Ondrej Simek <me@ondrejsimek.com>
   Updates: https://github.com/angel333/certbot-he-hook

 ==============================================================================

HELP
  exit 1
fi


## Auth parameters for curl ############################################

if [ -n "$HE_USER" ] && [ -n "$HE_PASS" ]; then
  HE_COOKIE=$( \
    curl -L --silent --show-error -I "https://dns.he.net/" \
      | grep '^Set-Cookie:' \
      | cut -c 13- \
      | cut -d\; -f 1)
  # Attempt login
  curl -L --silent --show-error --cookie "$HE_COOKIE" \
    --form "email=${HE_USER}" \
    --form "pass=${HE_PASS}" \
    "https://dns.he.net/" \
    > /dev/null
elif [ -n "$HE_SESSID" ]; then
  HE_COOKIE="CGISESSID=${HE_SESSID}"
else
  echo
    'No auth details provided. Please provide either session id (' \
    'through the $HE_SESSID environment variable) or user credentials' \
    '(through $HE_USER and $HE_PASS environement variables).' \
    1>&2
  exit 1
fi


## Finding the zone id #################################################

MATCHES=$(
  curl -L --silent --show-error --cookie "$HE_COOKIE" \
    "https://dns.he.net/" \
  | grep -Eo "delete_dom.*name=\"[^\"]+\" value=\"[0-9]+"
)

# Zone names and zone IDs are in same order
ZONE_IDS=$(echo "$MATCHES" | cut -d '"' -f 5)
ZONE_NAMES=$(echo "$MATCHES" | cut -d '"' -f 3)

STRIP_COUNTER=1

# Walk through all possible zone names
while true; do
  ATTEMPTED_ZONE=$(echo "$CERTBOT_DOMAIN" | cut -d . -f ${STRIP_COUNTER}-)

  # All possible zone names have been tried
  if [ -z "$ATTEMPTED_ZONE" ]; then
    echo "No zone for domain \"$CERTBOT_DOMAIN\" found." 1>&2
    return 1
  fi

  # Take care of "." and only match whole lines. Note that grep -F
  # cannot be used because there's no way to make it match whole
  # lines.
  REGEX="^$(echo "$ATTEMPTED_ZONE" | sed 's/\./\\./g')$"
  LINE_NUM=$(echo "$ZONE_NAMES" \
    | grep -n "$REGEX" \
    | cut -d : -f 1
  )

  if [ -n "$LINE_NUM" ]; then
    HE_ZONEID=$(echo "$ZONE_IDS" | sed "${LINE_NUM}q;d")
    # $ATTEMPTED_ZONE has zone $ZONE_ID and will be used for $CERTBOT_DOMAIN.
    break
  fi

  STRIP_COUNTER=$(expr $STRIP_COUNTER + 1)

done


## Add the validation record ###########################################

# $CERTBOT_AUTH_OUTPUT is only passed to the cleanup script
if [ -z "$CERTBOT_AUTH_OUTPUT" ]; then
  RECORD_NAME="_acme-challenge.$CERTBOT_DOMAIN"
  curl -L --silent --show-error --cookie "$HE_COOKIE" \
    --form "account=" \
    --form "menu=edit_zone" \
    --form "Type=TXT" \
    --form "hosted_dns_zoneid=$HE_ZONEID" \
    --form "hosted_dns_recordid=" \
    --form "hosted_dns_editzone=1" \
    --form "Priority=" \
    --form "Name=$RECORD_NAME" \
    --form "Content=$CERTBOT_VALIDATION" \
    --form "TTL=300" \
    --form "hosted_dns_editrecord=Submit" \
    "https://dns.he.net/" \
    | grep -E --only-matching \
      "deleteRecord\('.*','$RECORD_NAME','TXT'\)" \
    | grep -E --only-matching "\('[0-9]+" | cut -c 3- \
    | sort -n | tail -n1
  # All the greps, sorts, tails and cuts above do this:
  #
  #  1. find all records with the same name as we have just added
  #  2. strip everything but the ids
  #  3. take biggest number (the newest one)
  #
  # This ID is just printed out and picked up by the cleanup script.
fi


## Remove the validation record (cleanup) ##############################

# $CERTBOT_AUTH_OUTPUT is only passed to the cleanup script
# - it's the record ID
if [ ! -z "$CERTBOT_AUTH_OUTPUT" ]; then
  curl -L --silent --show-error --cookie "$HE_COOKIE" \
    --form "menu=edit_zone" \
    --form "hosted_dns_zoneid=$HE_ZONEID" \
    --form "hosted_dns_recordid=$CERTBOT_AUTH_OUTPUT" \
    --form "hosted_dns_editzone=1" \
    --form "hosted_dns_delrecord=1" \
    --form "hosted_dns_delconfirm=delete" \
    --form "hosted_dns_editzone=1" \
    "https://dns.he.net/" \
    | grep '<div id="dns_status" onClick="hideThis(this);">Successfully removed record.</div>' \
    > /dev/null
  DELETE_OK=$?
  if [ $DELETE_OK -ne 0 ]; then
    echo \
      "Could not clean (remove) up the record. Please go to HE" \
      "administration interface and clean it by hand." \
      1>&2
  fi
fi

# vim: et:ts=2:sw=2:
