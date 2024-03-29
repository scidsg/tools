#!/bin/bash

#Update and upgrade
sudo apt update && sudo apt -y dist-upgrade && sudo apt -y autoremove

# Install required packages
sudo apt-get -y install git certbot python3-certbot-nginx nginx whiptail tor libnginx-mod-http-geoip geoip-database unattended-upgrades libssl-dev

# Function to display error message and exit
error_exit() {
    echo "An error occurred during installation. Please check the output above for more details."
    exit 1
}

# Trap any errors and call the error_exit function
trap error_exit ERR

DOMAIN=$(whiptail --inputbox "Enter your domain name:" 8 60 3>&1 1>&2 2>&3)
EMAIL=$(whiptail --inputbox "Enter your email:" 8 60 3>&1 1>&2 2>&3)
GIT=$(whiptail --inputbox "Enter your git repo:" 8 60 3>&1 1>&2 2>&3)

# Check for valid domain name format
until [[ $DOMAIN =~ ^[a-zA-Z0-9][a-zA-Z0-9\.-]*\.[a-zA-Z]{2,}$ ]]; do
    DOMAIN=$(whiptail --inputbox "Invalid domain name format. Please enter a valid domain name:" 8 60 3>&1 1>&2 2>&3)
done
export DOMAIN
export EMAIL
export GIT

# Debug: Print the value of the DOMAIN variable
echo "Domain: $DOMAIN"

# Create Tor configuration file
sudo tee /etc/tor/torrc << EOL
RunAsDaemon 1
HiddenServiceDir /var/lib/tor/$DOMAIN/
HiddenServicePort 80 127.0.0.1:80
EOL

# Restart Tor service
sudo systemctl restart tor.service
sleep 10

# Get the Onion address
ONION_ADDRESS=$(sudo cat /var/lib/tor/$DOMAIN/hostname)
SAUTEED_ONION_ADDRESS=$(echo $ONION_ADDRESS | tr -d '.')

# Configure Nginx
cat > /etc/nginx/sites-available/$DOMAIN.nginx << EOL
server {
        root /var/www/html/$DOMAIN;
        server_name $DOMAIN www.$DOMAIN;
        location / {
            proxy_pass http://127.0.0.1:5000;
            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto \$scheme;
            proxy_connect_timeout 300s;
            proxy_send_timeout 300s;
            proxy_read_timeout 300s;
        }
                
        add_header Strict-Transport-Security "max-age=63072000; includeSubdomains";
        add_header X-Frame-Options DENY;
        add_header X-Content-Type-Options nosniff;
        add_header Onion-Location http://$ONION_ADDRESS\$request_uri;
        add_header Content-Security-Policy "default-src 'self'; script-src 'self'; img-src 'self' https:; style-src 'self'; frame-ancestors 'none';";
        add_header Permissions-Policy "geolocation=(), midi=(), notifications=(), push=(), sync-xhr=(), microphone=(), camera=(), magnetometer=(), gyroscope=(), speaker=(), vibrate=(), fullscreen=(), payment=(), interest-cohort=()";
        add_header Referrer-Policy "no-referrer";
        add_header X-XSS-Protection "1; mode=block";
}
server {
        server_name $ONION_ADDRESS;
        access_log /var/log/nginx/hs-my-website.log;
        index index.html;
        root /var/www/html/$DOMAIN;
                
        add_header X-Frame-Options DENY;
        add_header X-Content-Type-Options nosniff;
        add_header Content-Security-Policy "default-src 'self'; script-src 'self'; img-src 'self' https:; style-src 'self'; frame-ancestors 'none';";
        add_header Permissions-Policy "geolocation=(), midi=(), notifications=(), push=(), sync-xhr=(), microphone=(), camera=(), magnetometer=(), gyroscope=(), speaker=(), vibrate=(), fullscreen=(), payment=(), interest-cohort=()";
        add_header Referrer-Policy "no-referrer";
        add_header X-XSS-Protection "1; mode=block";
}
server {
        listen 80;
        server_name $DOMAIN www.$DOMAIN; # YOUR URLS
        return 301 https://$DOMAIN\$request_uri;
}
server {
    listen 80;
    server_name $SAUTEED_ONION_ADDRESS.$DOMAIN;

    location / {
        root /var/www/html/$DOMAIN;
    }
}
EOL

# Configure Nginx with privacy-preserving logging
cat > /etc/nginx/nginx.conf << EOL
user www-data;
worker_processes auto;
pid /run/nginx.pid;
include /etc/nginx/modules-enabled/*.conf;
events {
        worker_connections 768;
        # multi_accept on;
}
http {
        ##
        # Basic Settings
        ##
        sendfile on;
        tcp_nopush on;
        types_hash_max_size 2048;
        # server_tokens off;
        server_names_hash_bucket_size 128;
        # server_name_in_redirect off;
        include /etc/nginx/mime.types;
        default_type application/octet-stream;
        ##
        # SSL Settings
        ##
        ssl_protocols TLSv1 TLSv1.1 TLSv1.2 TLSv1.3; # Dropping SSLv3, ref: POODLE
        ssl_prefer_server_ciphers on;
        ##
        # Logging Settings
        ##
        # access_log /var/log/nginx/access.log;
        error_log /var/log/nginx/error.log;
        ##
        # Gzip Settings
        ##
        gzip on;
        # gzip_vary on;
        # gzip_proxied any;
        # gzip_comp_level 6;
        # gzip_buffers 16 8k;
        # gzip_http_version 1.1;
        # gzip_types text/plain text/css application/json application/javascript text/xml application/xml application/xml+rss text/javascript;
        ##
        # Virtual Host Configs
        ##
        include /etc/nginx/conf.d/*.conf;
        include /etc/nginx/sites-enabled/*;
        ##
        # Enable privacy preserving logging
        ##
        geoip_country /usr/share/GeoIP/GeoIP.dat;
        log_format privacy '0.0.0.0 - \$remote_user [\$time_local] "\$request" \$status \$body_bytes_sent "\$http_referer" "-" \$geoip_country_code';

        access_log /var/log/nginx/access.log privacy;
}
EOL

sudo ln -sf /etc/nginx/sites-available/$DOMAIN.nginx /etc/nginx/sites-enabled/
sudo nginx -t && sudo systemctl restart nginx

if [ -e "/etc/nginx/sites-enabled/default" ]; then
    rm /etc/nginx/sites-enabled/default
fi
ln -sf /etc/nginx/sites-available/$DOMAIN.nginx /etc/nginx/sites-enabled/
nginx -t && systemctl restart nginx || error_exit

cd /var/www/html
git clone $GIT
REPO_NAME=$(basename $GIT .git)
mv $REPO_NAME $DOMAIN

SERVER_IP=$(curl -s ifconfig.me)
WIDTH=$(tput cols)
whiptail --msgbox --title "Instructions" "\nPlease ensure that your DNS records are correctly set up before proceeding:\n\nAdd an A record with the name: @ and content: $SERVER_IP\n* Add a CNAME record with the name $SAUTEED_ONION_ADDRESS.$DOMAIN and content: $DOMAIN\n* Add a CAA record with the name: @ and content: 0 issue \"letsencrypt.org\"\n" 14 $WIDTH
# Request the certificates
certbot --nginx -d $DOMAIN,$SAUTEED_ONION_ADDRESS.$DOMAIN --agree-tos --non-interactive --no-eff-email --email ${EMAIL}

# Set up cron job to renew SSL certificate
(crontab -l 2>/dev/null; echo "30 2 * * 1 /usr/bin/certbot renew --quiet") | crontab -

echo "
✅ Installation complete!
                                               
https://$DOMAIN
https://$SAUTEED_ONION_ADDRESS.$DOMAIN;
http://$ONION_ADDRESS
"

# Disable the trap before exiting
trap - ERR
