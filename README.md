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
Made for self hosting on a Raspberry Pi.
```
curl -sSL https://raw.githubusercontent.com/scidsg/tools/main/mount_usb.sh | bash
```

## Onionizer
Run it on a new install of your favorite OS, get an nginx servre with a Tor onion service. 
```
curl -sSL https://raw.githubusercontent.com/scidsg/tools/main/onionizer.sh | bash
```

## Two-Factor Authentication Setup
Easily set up two-factor authentication on your server.
```
wget https://raw.githubusercontent.com/scidsg/tools/main/two-factor-setup.sh
chmod +x two-factor-setup.sh
./two-factor-setup.sh
```
