#!/bin/bash

echo "Starting Penpot installation..."

# Update and upgrade the system
echo "Updating the system..."
apt update && apt -y dist-upgrade && apt -y autoremove

# Install necessary packages
echo "Installing necessary packages..."
apt install -y docker.io git python3-pip
pip3 install docker-compose

mkdir penpot
cd penpot

wget https://raw.githubusercontent.com/penpot/penpot/main/docker/images/docker-compose.yaml
wget https://raw.githubusercontent.com/penpot/penpot/main/docker/images/build.sh

sudo systemctl start docker
sleep 10
sudo systemctl enable docker

# Start Penpot services with Docker
echo "Starting Penpot services with Docker..."
docker-compose -p penpot -f docker-compose.yaml up -d

# Ask user if they want to make Penpot available over public domain
read -p "Do you want to make Penpot available over a public domain? (y/n): " answer
if [ "$answer" == "y" ]
then
    # Install certbot and setup SSL for the domain
    echo "Setting up SSL for the domain..."
    apt -y install apache2 certbot python3-certbot-apache

    # Collect domain, subdomain, and website path using whiptail
    email=$(whiptail --inputbox "Enter your email address:" 8 78 --title "Email Address" 3>&1 1>&2 2>&3)
    domain=$(whiptail --inputbox "Enter your domain name:" 8 78 --title "Domain Name" 3>&1 1>&2 2>&3)

    # Create Apache configuration file
    config_file="/etc/apache2/sites-available/${domain}.conf"
    config_file_1="/etc/apache2/sites-available/${domain}-le-ssl.conf"

    cat > "$config_file" <<EOL
<VirtualHost *:80>
    ServerAdmin ${email}
    ServerName ${domain}

    ErrorLog ${APACHE_LOG_DIR}/${domain}-error.log
    CustomLog ${APACHE_LOG_DIR}/${domain}-access.log combined

    RewriteEngine on
    RewriteCond %{SERVER_NAME} =${domain}
    RewriteRule ^ https://%{SERVER_NAME}%{REQUEST_URI} [END,NE,R=permanent]
</VirtualHost>
EOL

    cat > "$config_file_1" <<EOL
<IfModule mod_ssl.c>
    <VirtualHost *:443>
        ServerAdmin ${email}
        ServerName ${domain}

        ErrorLog ${APACHE_LOG_DIR}/${domain}-error.log
        CustomLog ${APACHE_LOG_DIR}/${domain}-access.log combined

        SSLCertificateFile /etc/letsencrypt/live/${domain}/fullchain.pem
        SSLCertificateKeyFile /etc/letsencrypt/live/${domain}/privkey.pem
        Include /etc/letsencrypt/options-ssl-apache.conf

        ProxyPass / http://localhost:9001/
        ProxyPassReverse / http://localhost:9001/
    </VirtualHost>
</IfModule>
EOL

    # Enable the new site configuration and reload Apache
    a2ensite "${domain}"
    systemctl reload apache2

    # Generate certificates with the Apache plug-in
    certbot --apache --agree-tos --non-interactive --email ${email} -d "${domain}"

    # Set up automatic renewal of Let's Encrypt certificates
    (crontab -l 2>/dev/null; echo "0 12 * * * /usr/bin/certbot renew --quiet") | crontab -

    echo "✅ Setup complete! You can now securely access your website at https://${domain}"

    a2ensite "${domain}"
    a2ensite "${domain}-le-ssl"
    a2enmod proxy
    a2enmod proxy_http

    systemctl restart apache2
fi

echo "Penpot installation complete!"
