# zoneedit_letsencrypt
Scripts to enable automated ssl certificate update dns-01 challenge with Linux, Zoneedit and Letsencrypt

This is a very basic script for my needs.

Enhancements are welcome via pull-requests but please understand that all I need it for
is to generate wildcard domain ssl certificates using ZoneEdit dns provider.

There are 3 scripts:
1. renew-wilddns-with-zoneedit.sh
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
./renew-wilddns-with-zoneedit.sh -d yourdomain.com
```

On first execution, this will fail and you will need to edit the /etc/sysconfig/zoneedit.cfg file
and you can re-run the command which will complete

```
./renew-wilddns-with-zoneedit.sh -d yourdomain.com
```

To automate this in cron, you can add the -a flag, for example:

```
0 0,12 * * * /home/user/code/zoneedit_letsencrypt/renew-wilddns-with-zoneedit.sh -d yourdomain.com -a
```


