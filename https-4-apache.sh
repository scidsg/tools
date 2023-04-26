#!/bin/bash

# Welcome message and ASCII art
cat << "EOF"
 _      _    _                   ___                              _           
| |    | |  | |                 /   |                            | |          
| |__  | |_ | |_  _ __   ___   / /| |   __ _  _ __    __ _   ___ | |__    ___ 
| '_ \ | __|| __|| '_ \ / __| / /_| |  / _` || '_ \  / _` | / __|| '_ \  / _ \
| | | || |_ | |_ | |_) |\__ \ \___  | | (_| || |_) || (_| || (__ | | | ||  __/
|_| |_| \__| \__|| .__/ |___/     |_/  \__,_|| .__/  \__,_| \___||_| |_| \___|
                 | |                         | |                              
                 |_|                         |_|                              
A free tool by Science & Design - https://scidsg.org
                                                              
Easily request SSL certificates from Let's Encrypt

EOF
sleep 3

# Make sure your DNS settings are pointing to this server before requesting a Let's Encrypt certificate.

# Update system and install required packages
apt update && apt -y dist-upgrade
apt -y install apache2 certbot python3-certbot-apache

# Collect domain, subdomain, and website path using whiptail
email=$(whiptail --inputbox "Enter your email address:" 8 78 --title "Email Address" 3>&1 1>&2 2>&3)
domain=$(whiptail --inputbox "Enter your domain name:" 8 78 --title "Domain Name" 3>&1 1>&2 2>&3)
subdomain=$(whiptail --inputbox "Enter your subdomain name (leave empty if not needed):" 8 78 --title "Subdomain Name" 3>&1 1>&2 2>&3)
website_path=$(whiptail --inputbox "Enter your website's path:" 8 78 --title "Website Path" 3>&1 1>&2 2>&3)

# Create Apache configuration file
config_file="/etc/apache2/sites-available/${domain}.conf"

if [ -z "$subdomain" ]; then
    cat > "$config_file" <<EOL
<VirtualHost *:80>
    ServerAdmin ${email}
    ServerName ${domain}
    DocumentRoot ${website_path}
    ErrorLog \${APACHE_LOG_DIR}/${domain}-error.log
    CustomLog \${APACHE_LOG_DIR}/${domain}-access.log combined
</VirtualHost>
EOL
else
    cat > "$config_file" <<EOL
<VirtualHost *:80>
    ServerAdmin ${email}
    ServerName ${domain}
    ServerAlias ${subdomain}
    DocumentRoot ${website_path}
    ErrorLog \${APACHE_LOG_DIR}/${domain}-error.log
    CustomLog \${APACHE_LOG_DIR}/${domain}-access.log combined
</VirtualHost>
EOL
fi

# Enable the new site configuration and reload Apache
a2ensite "${domain}"
systemctl reload apache2

# Generate certificates with the Apache plug-in
if [ -z "$subdomain" ]; then
    sudo certbot --apache --agree-tos --non-interactive --email ${email} -d "${domain}"
else
    sudo certbot --apache --agree-tos --non-interactive --email ${email} -d "${domain}" -d "${subdomain}"
fi

# Set up automatic renewal of Let's Encrypt certificates
(crontab -l 2>/dev/null; echo "0 12 * * * /usr/bin/certbot renew --quiet") | crontab -

echo "✅ Setup complete! You can now securely access your website at https://${domain}"

