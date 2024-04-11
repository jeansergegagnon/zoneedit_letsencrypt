# zoneedit_letsencrypt

![alt text](https://raw.githubusercontent.com/jeansergegagnon/zoneedit_letsencrypt/master/images/automated-zoneedit-letsencrypt.JPG)

# Summary

Scripts to enable automated ssl certificate update dns-01 challenge with Linux, Zoneedit and Letsencrypt

# Overview

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
3. Your ZoneEdit user and DYN token for EACH domain you want to update.
   (see below on where to get it)
4. These scripts

# Getting your DYN token:

1. Go to main domain listing page
2. Click the *dns* link for the domain
![alt text](https://raw.githubusercontent.com/jeansergegagnon/zoneedit_letsencrypt/master/images/dnslink.JPG)
3. Click the top level menu *Domains* link
4. In domains pull down, click the *DNS settings* menu entry.
![alt text](https://raw.githubusercontent.com/jeansergegagnon/zoneedit_letsencrypt/master/images/menudnssettings.JPG)
5. In that page, find the *DYN records* section and click the wrench on top right.
![alt text](https://raw.githubusercontent.com/jeansergegagnon/zoneedit_letsencrypt/master/images/dynrench.JPG)
6. Scroll to bottom of page and find the *dynamic authentication* section and click te *enable* link.
![alt text](https://raw.githubusercontent.com/jeansergegagnon/zoneedit_letsencrypt/master/images/dynenable.JPG)
   - if you already enabled it, you can click the *view* instead.
![alt text](https://raw.githubusercontent.com/jeansergegagnon/zoneedit_letsencrypt/master/images/dynview.JPG)
7. Copy the token value and put it in the /etc/sysconfig/zoneedit/YOURDOMAIN.cfg file (see below).
![alt text](https://raw.githubusercontent.com/jeansergegagnon/zoneedit_letsencrypt/master/images/dyntoken.JPG)


# Installing and using this script

You just install this in a directory, as simple as this:

```
cd /path/to/dir/to/save/files
git clone git@github.com:jeansergegagnon/zoneedit_letsencrypt.git
cd zoneedit_letsencrypt
sudo ./getcert-wilddns-with-zoneedit.sh -d yourdomain.com
```

On first execution, this will fail and you will need to edit the /etc/sysconfig/zoneedit/YOURDOMAIN.cfg file
and you can re-run the command which will complete

```
sudo ./getcert-wilddns-with-zoneedit.sh -d yourdomain.com
```

To automate this in cron, you can add the -a flag and the -e email value, for example this will check yourdomain.com cert every 10th and 20th of the month and update it if it is expiring soon:

```
CERTBOTDIR=/home/user/certbot
0 0 10,20 * * /home/user/code/zoneedit_letsencrypt/getcert-wilddns-with-zoneedit.sh -d yourdomain.com -a -e youremail@yourdomain.com
```

# Examples

For example, when running this command:

```
sudo ./getcert-wilddns-with-zoneedit.sh -a -d sampledomain.com
```

you will see output similar to this:

```
[jsg@www zoneedit_letsencrypt]$ sudo ./getcert-wilddns-with-zoneedit.sh -a -d sampledomain.com
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


# SRF update:

> If you get an error about SPF validation failure and you know for a fact your SPF record is valid,
you'll need to go disable the SPF validation check.

For example:

```
You must update your SPF record or attempts to send mail will result in a <b>
PERMERROR</b>
. For assistance building a SPF record use our <a href="http://www.spfwizard.com/" target="_blank">
easySPF Wizard</a>
. To disable checking of your SPF record visit your preferences page and disable SPF checking for your account.<br />
ERROR: No IPs detected in SPF!
```

First, go to your account Preferences:

![alt text](https://raw.githubusercontent.com/jeansergegagnon/zoneedit_letsencrypt/master/images/usermenu.JPG)

Next, scroll down until you find the *Editing Preferences* section and turn off the SPF validation:

![alt text](https://raw.githubusercontent.com/jeansergegagnon/zoneedit_letsencrypt/master/images/disableSPFcheck.JPG)

Then save and retry the certificate renewal.

> Feel free to email me at jeanserge.gagnon@gmail.com for any questions or comments and fork this project to submit any pull requests. I will be happy to review and approve any changes that make this code even more useful to others.


