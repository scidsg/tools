#!/bin/bash

# Welcome message and ASCII art
cat << "EOF"
  _     _   _               _  _                 _            
 | |   | | | |             | || |               (_)           
 | |__ | |_| |_ _ __  ___  | || |_   _ __   __ _ _ _ __ __  __
 | '_ \| __| __| '_ \/ __| |__   _| | '_ \ / _` | | '_ \\ \/ /
 | | | | |_| |_| |_) \__ \    | |   | | | | (_| | | | | |>  < 
 |_| |_|\__|\__| .__/|___/    |_|   |_| |_|\__, |_|_| |_/_/\_\
               | |                          __/ |             
               |_|                         |___/  
A free tool by Science & Design - https://scidsg.org
                                                              
Easily request SSL certificates from Let's Encrypt

EOF
sleep 3

# Make sure your DNS settings are pointing to this server before requesting a Let's Encrypt certificate.

# Update system and install required packages
apt update && apt -y dist-upgrade
apt -y install nginx certbot python3-certbot-nginx

# Collect domain, subdomain, and website path using whiptail
email=$(whiptail --inputbox "Enter your email address:" 8 78 --title "Email Address" 3>&1 1>&2 2>&3)
domain=$(whiptail --inputbox "Enter your domain name:" 8 78 --title "Domain Name" 3>&1 1>&2 2>&3)
subdomain=$(whiptail --inputbox "Enter your subdomain name (leave empty if not needed):" 8 78 --title "Subdomain Name" 3>&1 1>&2 2>&3)
website_path=$(whiptail --inputbox "Enter your website's path:" 8 78 --title "Website Path" 3>&1 1>&2 2>&3)

# Backup default NGINX config
cp /etc/nginx/sites-enabled/default /etc/nginx/sites-enabled/default-backup
rm /etc/nginx/sites-enabled/default
mv /etc/nginx/sites-enabled/default-backup /etc/nginx/sites-available/

# Create NGINX configuration file
config_file="/etc/nginx/conf.d/${domain}.conf"

if [ -z "$subdomain" ]; then
    cat > "$config_file" <<EOL
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    root ${website_path};
    server_name ${domain};
}
EOL
else
    cat > "$config_file" <<EOL
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    root ${website_path};
    server_name ${domain} ${subdomain};
}
EOL
fi

# Verify the syntax of your configuration and restart NGINX
nginx -t && nginx -s reload

# Generate certificates with the NGINX plug-in
if [ -z "$subdomain" ]; then
    sudo certbot --nginx --agree-tos --non-interactive --email ${email} -d "${domain}"
else
    sudo certbot --nginx --agree-tos --non-interactive --email ${email} -d "${domain}" -d "${subdomain}"
fi

# Set up automatic renewal of Let's Encrypt certificates
(crontab -l 2>/dev/null; echo "0 12 * * * /usr/bin/certbot renew --quiet") | crontab -

echo "✅ Setup complete! You can now securely access your website at https://${domain}".
