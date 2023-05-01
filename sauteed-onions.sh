#!/bin/bash

# Welcome message and ASCII art
cat << "EOF"

 _____                _                    _ 
/  ___|              | |                  | |
\ `--.   __ _  _   _ | |_   ___   ___   __| |
 `--. \ / _` || | | || __| / _ \ / _ \ / _` |
/\__/ /| (_| || |_| || |_ |  __/|  __/| (_| |
\____/  \__,_| \__,_| \__| \___| \___| \__,_|                                             
 _____         _                    
|  _  |       (_)                   
| | | | _ __   _   ___   _ __   ___ 
| | | || '_ \ | | / _ \ | '_ \ / __|
\ \_/ /| | | || || (_) || | | |\__ \
 \___/ |_| |_||_| \___/ |_| |_||___/
                                                                                                                                                               
Onion address authenticity
https://sauteed-onions.org

EOF

# Prompt for domain and onion address
domain=$(whiptail --inputbox "Enter your domain" 8 78 --title "Domain Input" 3>&1 1>&2 2>&3)
onion=$(whiptail --inputbox "Enter your onion address" 8 78 --title "Onion Address Input" 3>&1 1>&2 2>&3)
email=$(whiptail --inputbox "Enter your email address" 8 78 --title "Email Address" 3>&1 1>&2 2>&3)
conf_file=$(whiptail --inputbox "Enter your server config path" 8 78 "/etc/nginx/sites-enabled" --title "Configuration Path" 3>&1 1>&2 2>&3)

# Ask if the user is deploying a web app or a static website
DEPLOY_TYPE=$(whiptail --title "Deployment Type" --menu "Choose your deployment type" 15 60 4 \
"1" "Web app" \
"2" "Static website"  3>&1 1>&2 2>&3)

# Depending on the choice, ask for the appropriate information and set the server block
case $DEPLOY_TYPE in
1)
    app_address=$(whiptail --inputbox "Enter your app's address" 8 78 "localhost" --title "App Address Input" 3>&1 1>&2 2>&3)
    app_port=$(whiptail --inputbox "Enter your app's port" 8 78 --title "App Port Input" 3>&1 1>&2 2>&3)
    server_block="
    server {
        listen 80;
        server_name $onion.$domain;

        location / {
            proxy_pass http://$app_address:$app_port;
        }
    }"
    ;;
2)
    static_files_path=$(whiptail --inputbox "Enter the path to your static files" 8 78 "/var/www/html/glennsorrentino" --title "Static Files Path Input" 3>&1 1>&2 2>&3)
    server_block="
    server {
        listen 80;
        server_name $onion.$domain;

        location / {
            root $static_files_path;
        }
    }"
    ;;
esac

# Inform the user to set DNS records
whiptail --msgbox --title "Instructions" "\nPlease ensure that your DNS records are correctly set up before proceeding:\n\n* Add a CNAME record for $onion.$domain that points to $domain\n* Add a CAA record for @ with the content: 0 issue \"letsencrypt.org\"\n* Make sure that you have an A record pointing $domain to your server." 14 78

# Find the config file that matches the domain
config_file=/etc/nginx/sites-enabled/*.nginx

# Check if the file exists
if [ -n "$config_file" ]; then
    echo "$server_block" >> "$config_file"
else
    echo "Could not find a config file for $domain"
    exit 1
fi

sudo sed -i 's/# server_names_hash_bucket_size 64;/server_names_hash_bucket_size 128;/' /etc/nginx/nginx.conf

# Test the configuration and restart nginx
nginx -t && systemctl restart nginx

# Request the certificates
certbot --nginx -d $domain,$onion.$domain --agree-tos --no-eff-email --email $email

# Configure automatic renewals
echo "0 12 * * * root certbot renew --post-hook 'systemctl reload nginx'" >> /etc/crontab

echo "
✅ Sauteed Onions setup complete!
Your app is now available at $onion.$domain
"                                            

