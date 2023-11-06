#!/bin/bash

# Prompt for username and sitename
USER=$(whiptail --inputbox "Enter your username" 8 78 "ghostuser" --title "User input" 3>&1 1>&2 2>&3)
SITENAME=$(whiptail --inputbox "Create a name for your installation directory" 8 78 "ghost" --title "Directory Name" 3>&1 1>&2 2>&3)

# Exit status handling
exitstatus=$?
if [ $exitstatus = 0 ]; then
    echo "User: " $USER
    echo "Site: " $SITENAME
else
    echo "You chose Cancel, exiting."
    exit 1
fi

# Update system packages
echo "Updating system packages..."
sudo apt-get update -y
sudo apt-get upgrade -y

# Create new user
echo "Creating new user..."
sudo adduser $USER
sudo usermod -aG sudo $USER
su - $USER

# Install Nginx
echo "Installing Nginx, UFW, NodeJS, and MySQL..."
sudo apt-get install nginx mariadb-server nodejs ufw -y
sudo ufw allow 'Nginx Full'

# Install Node.js
echo "Installing Node.js..."
curl -sL https://deb.nodesource.com/setup_16.x | sudo -E bash -
sudo apt-get install -y nodejs

# Install Ghost CLI
echo "Installing Ghost CLI..."
sudo npm install ghost-cli@latest -g

# Create directory for Ghost install
echo "Creating Ghost install directory..."
sudo mkdir -p /var/www/$SITENAME
sudo chown $USER:$USER /var/www/$SITENAME
sudo chmod 775 /var/www/$SITENAME

# Navigate into the directory
cd /var/www/$SITENAME

# Install Ghost
echo "Installing Ghost..."
ghost install

# You will be prompted to enter details for Ghost during the install
# After installation, you can start Ghost with 'ghost start'
