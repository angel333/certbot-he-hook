# Certbot (Let's Encrypt) auth hook script for the Hurricane Electric DNS service (certbot-he-hook)

With this script, domains that are hosted at the Hurricane Electric DNS service are verified automatically using the DNS-01 validation, (as opposed to e.g. webroot validation). It adds a special TXT DNS record for the domain and then removes it when the verification is finished.
 
## Example usage:

1. Renew certificates for all domains:
        
       HE_USER=<username> HE_PASS=<password> certbot renew \
         --preferred-challenges dns \
         --manual-auth-hook /path/to/certbot-he-hook.sh  \
         --manual-cleanup-hook /path/to/certbot-he-hook.sh  \
         --manual-public-ip-logging-ok
      
      
2. Create a new certificate for a domain:

       HE_SESSID=<session_id> certbot certonly \
         --preferred-challenges dns \
         --email your@email.com \
         --manual \
         --manual-auth-hook /path/to/certbot-he-hook.sh  \
         --manual-cleanup-hook /path/to/certbot-he-hook.sh  \
         --manual-public-ip-logging-ok \
         --domain <requested.domain.com>

## Bugs

Feel free to submit bugs on the Github page or to <me@ondrejsimek.com>.

## License

MIT
