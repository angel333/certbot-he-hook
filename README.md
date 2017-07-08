# Certbot (Let's Encrypt) auth hook script for the Hurricane Electric DNS service (certbot-he-hook)

With this script, domains that are hosted at Hurricane Electric are verified automatically, i.e. without the need for a webroot
 verification or manually adding TXT records.
 
## Example usage:

1. Renew certificates for all domains:
        
       HE_USER=<username> HE_PASS=<password> certbot renew \
         --preferred-challenges dns \
         --manual-auth-hook /path/to/certbot-he-hook.sh  \
         --manual-public-ip-logging-ok
      
      
2. Create a new certificate for a domain:

       HE_SESSID=<session_id> certbot certonly \
         --preferred-challenges dns \
         --email your@email.com \
         --manual \
         --manual-auth-hook /path/to/certbot-he-hook.sh  \
         --manual-public-ip-logging-ok \
         --domain <requested.domain.com>

## License

MIT
