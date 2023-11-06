#!/bin/bash

# Update System
echo "Updating System..."
sudo apt update && sudo apt upgrade -y

# Install Nginx
echo "Installing Nginx..."
sudo apt install -y nginx

# Install MySQL
echo "Installing MySQL Server..."
sudo apt install -y default-mysql-server

# Run MySQL Secure Installation
echo "Running MySQL Secure Installation..."
sudo mysql_secure_installation

# Install PHP
echo "Installing PHP and PHP Extensions..."
sudo apt install -y php-fpm php-mysql php-xml php-curl php-gd php-imagick php-cli php-dev php-imap php-mbstring php-opcache php-soap php-zip unzip

# Download WordPress
echo "Downloading WordPress..."
cd /tmp
curl -LO https://wordpress.org/latest.tar.gz
tar xzvf latest.tar.gz

# Creating a new MySQL database and user
DB_ROOT_PASSWORD=$(whiptail --passwordbox "Enter MySQL root password:" 8 78 --title "Database setup" 3>&1 1>&2 2>&3)
DB_NAME=$(whiptail --inputbox "Enter Database Name:" 8 78 "dbTest" --title "Database setup" 3>&1 1>&2 2>&3)
DB_USER=$(whiptail --inputbox "Enter Database User:" 8 78 "dbUser" --title "Database setup" 3>&1 1>&2 2>&3)
DB_PASSWORD=$(whiptail --passwordbox "Enter Database Password:" 8 78 --title "Database setup" 3>&1 1>&2 2>&3)

sudo mysql -u root -p$DB_ROOT_PASSWORD <<EOF
CREATE DATABASE $DB_NAME;
CREATE USER '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASSWORD';
GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_USER'@'localhost';
FLUSH PRIVILEGES;
EOF

# Configuring WordPress
echo "Configuring WordPress..."
cp /tmp/wordpress/wp-config-sample.php /tmp/wordpress/wp-config.php
sed -i "s/database_name_here/$DB_NAME/g" /tmp/wordpress/wp-config.php
sed -i "s/username_here/$DB_USER/g" /tmp/wordpress/wp-config.php
sed -i "s/password_here/$DB_PASSWORD/g" /tmp/wordpress/wp-config.php

# Moving WordPress files
echo "Moving WordPress Files..."
sudo cp -a /tmp/wordpress/. /var/www/html
sudo chown -R www-data:www-data /var/www/html

# Setting up Nginx Server Block
SERVER_NAME=$(whiptail --inputbox "Enter Server Name (Domain or IP):" 8 78 --title "Nginx setup" 3>&1 1>&2 2>&3)

sudo tee /etc/nginx/sites-available/wordpress <<EOF
server {
    listen 80;
    listen [::]:80;
    root /var/www/html;
    index  index.php index.html index.htm;
    server_name  $SERVER_NAME;

    client_max_body_size 100M;

    location / {
        try_files \$uri \$uri/ /index.php?\$args;        
    }

    location ~ \.php\$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/var/run/php/php7.4-fpm.sock;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        include fastcgi_params;
    }
}
EOF

# Enabling Nginx Server Block
echo "Enabling Nginx Server Block..."
sudo ln -s /etc/nginx/sites-available/wordpress /etc/nginx/sites-enabled/

# Test Nginx configuration
echo "Testing Nginx Configuration..."
sudo nginx -t

# Restart Nginx
echo "Restarting Nginx..."
sudo systemctl restart nginx

# Remove default Nginx config
cd /etc/nginx/sites-enabled
sudo unlink default
sudo nginx -t
sudo systemctl restart nginx

echo "Installation Complete: Please open http://$SERVER_NAME in your browser to set up WordPress"
