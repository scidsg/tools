# Tools

Helpful tools to make developing software a little easier.

## Automatic Updates
Set up automatic updates so your server doesn't miss important bug fixes and security patches.
```
curl -sSL https://raw.githubusercontent.com/scidsg/tools/main/auto-updates.sh | bash
```

## Configure Let's Encrypt certificates
**Nginx**
```
curl -sSL https://raw.githubusercontent.com/scidsg/tools/main/https-4-nginx.sh | bash
```
**Apache**
```
curl -sSL https://raw.githubusercontent.com/scidsg/tools/main/https-4-apache.sh | bash
```

## Encrypted MySQL Backups
Made with The Pretty Wiki in mind, this script creates backups encrypted to your PGP key.
```
curl -sSL https://raw.githubusercontent.com/scidsg/tools/main/encrypted-mysql-backups.sh | bash
```

## Mount a local USB
Made for self hosting on a Raspberry Pi. Automatically mounts a USB drive when plugged in.
```
curl -sSL https://raw.githubusercontent.com/scidsg/tools/main/mount_usb.sh | bash
```

## New Site
Easily launch your site to public and onion domains, and a new censorship resistant onion-bound domain. Automatically sets up renewing HTTPS certificates. Complete with instructions for DNS config.
```
curl -sSL https://raw.githubusercontent.com/scidsg/tools/main/auto-updates.sh | bash
```

## Onionizer
Run it on a new install of your favorite OS, get an nginx servre with a Tor onion service. 
```
curl -sSL https://raw.githubusercontent.com/scidsg/tools/main/onionizer.sh | bash
```


## Pibound
Automatically install Pi-hole and Unbound for network-wide ad-blocking and upstream recursive DNS. 
```
curl -sSL https://raw.githubusercontent.com/scidsg/tools/main/pibound.sh | bash
```

## Sauteed Onions for Nginx
Domain owners can prove ownership of an onion address, and increase their website's resilience to censorship.  
Learn more at https://sauteed-onions.org
```
curl -sSL https://raw.githubusercontent.com/scidsg/tools/main/sauteed-onions-nginx.sh | bash
```

## Two-Factor Authentication Setup
Easily set up two-factor authentication on your server.
```
wget https://raw.githubusercontent.com/scidsg/tools/main/two-factor-setup.sh
chmod +x two-factor-setup.sh
./two-factor-setup.sh
```

## Wifi Loader
When you have a list of SSIDs and passwords to load on to a new OS. The Wifi Loader hashes the passwords and adds them to your wifi configuration file so your device's connection isn't dependent on a single network.

First, download the script and make it executable:
```
wget https://raw.githubusercontent.com/scidsg/tools/main/wifi-loader.sh
chmod +x wifi-loader.sh
```

Next, to create a list on the device you're loading networks onto:
```
sudo nano input.txt
```

Make sure your wifi networks follow this format:
```
SSID1 password1
SSID2 password2
SSID3 password3
```

Finally, load them on your device:
```
./wifi-loader.sh input.txt
```

