# zoneedit_letsencrypt
Scripts to enable automated ssl certificate update dns-01 challenge with Linux, Zoneedit and Letsencrypt

This is a very basic script for my needs.

Enhancements are welcome via pull-requests but please understand that all I need it for
is to generate wildcard domain ssl certificates using ZoneEdit dns provider.

There are 3 scripts:
1. getcert-wilddns-with-zoneedit.sh
2. certbot-dns-updater-with-zoneedit.sh
3. zoneedit.sh


To use this, you need the following:

1. A ZoneEdit hosted Domain
2. the certbot-auto binary in the path or ~/certbot dir (or specify with CERTBOTDIR environment variable)
3. Your ZoneEdit user and password (you will need to save them in /etc/sysconfig/zoneedit.cfg file)
4. These scripts


You just install this in a directory, as simple as this:

```
cd /path/to/dir/to/save/files
git clone git@github.com:jeansergegagnon/zoneedit_letsencrypt.git
cd zoneedit_letsencrypt
./getcert-wilddns-with-zoneedit.sh -d yourdomain.com
```

On first execution, this will fail and you will need to edit the /etc/sysconfig/zoneedit.cfg file
and you can re-run the command which will complete

```
./getcert-wilddns-with-zoneedit.sh -d yourdomain.com
```

To automate this in cron, you can add the -a flag, for example:

```
0 0,12 * * * /home/user/code/zoneedit_letsencrypt/getcert-wilddns-with-zoneedit.sh -d yourdomain.com -a
```

For example, when running this command:

```
./getcert-wilddns-with-zoneedit.sh -a -d sampledomain.com
```

you will see output similar to this:

```
[jsg@www zoneedit_letsencrypt]$ ./getcert-wilddns-with-zoneedit.sh -a -d sampledomain.com
sudo ./certbot-auto certonly --agree-tos --manual-public-ip-logging-ok --non-interactive --manual --manual-auth-hook /home/jsg/code/zoneedit_letsencrypt/certbot-dns-updater-with-zoneedit.sh --preferred-challenges dns-01 -d *.sampledomain.com -d sampledomain.com
Saving debug log to /var/log/letsencrypt/letsencrypt.log
Plugins selected: Authenticator manual, Installer None
Obtaining a new certificate
Performing the following challenges:
dns-01 challenge for sampledomain.com
Running manual-auth-hook command: /home/jsg/code/zoneedit_letsencrypt/certbot-dns-updater-with-zoneedit.sh
Output from manual-auth-hook command certbot-dns-updater-with-zoneedit.sh:
./zoneedit.sh -V -d sampledomain.com -n _acme-challenge -v 5FG4knUFW8eTOHGrPHexRZFFh5WtzM1kj-lQ-pR_Mn8 -i 0
Thu May 23 11:45:34 EDT 2019: Getting initial login cookies
https://cp.zoneedit.com/login.php
Thu May 23 11:45:34 EDT 2019: Logging in
https://cp.zoneedit.com/home/
Thu May 23 11:45:34 EDT 2019: Validating domain
https://cp.zoneedit.com/manage/domains/
https://cp.zoneedit.com/manage/domains/zone/index.php?LOGIN=sampledomain.com
Thu May 23 11:45:35 EDT 2019: Loading TXT edit page
https://cp.zoneedit.com/manage/domains/txt/
https://cp.zoneedit.com/manage/domains/txt/edit.php
Thu May 23 11:45:36 EDT 2019: Sending new TXT record values
https://cp.zoneedit.com/manage/domains/txt/edit.php
https://cp.zoneedit.com/manage/domains/txt/confirm.php
Thu May 23 11:45:38 EDT 2019: Confirming change succeeded
https://cp.zoneedit.com/manage/domains/txt/edit.php
OK: Successfully set TXT record _acme-challenge.sampledomain.com=5FG4knUFW8eTOHGrPHexRZFFh5WtzM1kj-lQ-pR_Mn8

Waiting for verification...
Cleaning up challenges
IMPORTANT NOTES:
 - Congratulations! Your certificate and chain have been saved at:
   /etc/letsencrypt/live/sampledomain.com/fullchain.pem
   Your key file has been saved at:
   /etc/letsencrypt/live/sampledomain.com/privkey.pem
   Your cert will expire on 2019-08-21. To obtain a new or tweaked
   version of this certificate in the future, simply run certbot-auto
   again. To non-interactively renew *all* of your certificates, run
   "certbot-auto renew"
 - If you like Certbot, please consider supporting our work by:

   Donating to ISRG / Let's Encrypt:   https://letsencrypt.org/donate
   Donating to EFF:                    https://eff.org/donate-le
```

Obviously, change the *sampledomain.com* to your domain in above exmaple command.

Feel free to email me at jeanserge.gagnon@gmail.com for any questions or comments and fork this project to submit any pull requests. I will be happy to review and approve any changes that make this code even more useful to others.


