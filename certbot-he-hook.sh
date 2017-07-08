#!/bin/bash


## Help ################################################################

if [ -z "$CERTBOT_DOMAIN" ] || [ -z "$CERTBOT_VALIDATION" ]; then
  cat <<END

 == Certbot hook for Hurricane Electric DNS service ====================

 !! This script is intended to be used as a hook script for certbot !!

 With this script, domains that have DNS hosted at Hurricane Electric
 are verified automatically, i.e. without the need for a webroot
 verification or manually adding TXT records.

 - You need to provide either a session ID, or login credentials through
   environment variables (see examples below). Session ID should be
   faster.

 Example usage:

  1) Renew certificates for all domains:

    HE_USER=<username> HE_PASS=<password> certbot renew \\
      --preferred-challenges dns \\
      --manual-auth-hook /path/to/certbot-he-hook.sh  \\
      --manual-public-ip-logging-ok

  2) Create a new certificate for a domain:

    HE_SESSID=<session_id> certbot certonly \\
      --preferred-challenges dns \\
      --email your@email.com \\
      --manual \\
      --manual-auth-hook /path/to/certbot-he-hook.sh  \\
      --manual-public-ip-logging-ok \\
      --domain <requested.domain.com>

 --

   Author: Ondrej Simek <me@ondrejsimek.com>
   Updates: https://github.com/angel333/certbot-he-hook

 =======================================================================

END
  exit 1
fi


## Auth parameters for curl ############################################

if [ -n "$HE_USER" ] && [ -n "$HE_PASS" ]; then
  HE_COOKIE=$(curl --stderr - -I \
      https://dns.he.net/index.cgi \
    | grep '^Set-Cookie:' | grep -Eo 'CGISESSID=[a-z0-9]*')
  # attempt login
  curl --stderr - -o /dev/null \
    --cookie $HE_COOKIE \
    --data "email=${HE_USER}&pass=${HE_PASS}" \
    https://dns.he.net/index.cgi
elif [ -n "$HE_SESSID" ]; then
  HE_COOKIE="--cookie CGISESSID=${HE_SESSID}"
else
  echo 'No auth details provided. Please provide either session' \
    '($HE_SESSID) or user credentials ($HE_USER and $HE_PASS) via' \
    'environment variables.' 1>&2
  exit 1
fi


## Finding the zone id #################################################

ZONENAME_REGEX=$(echo $CERTBOT_DOMAIN | awk -F '.' '{ print $(NF-1) "\\." $NF }')
HE_ZONEID=$(curl --stderr - --cookie $HE_COOKIE https://dns.he.net/index.cgi \
  | grep -Eo "delete_dom.*name=\"$ZONENAME_REGEX\" value=\"[0-9]+" | grep -Eo "[0-9]+$")


## Adding the validation record ########################################

curl --stderr - -o /dev/null --cookie $HE_COOKIE https://dns.he.net/index.cgi \
  -d "account=&menu=edit_zone&Type=TXT&hosted_dns_zoneid=$HE_ZONEID&hosted_dns_recordid=&hosted_dns_editzone=1&Priority=&Name=_acme-challenge.$CERTBOT_DOMAIN&Content=$CERTBOT_VALIDATION&TTL=300&hosted_dns_editrecord=Submit"
