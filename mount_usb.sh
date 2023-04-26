#!/bin/bash

# Welcome message and ASCII art
cat << "EOF"

███    ███  ██████  ██    ██ ███    ██ ████████     ██    ██ ███████ ██████  
████  ████ ██    ██ ██    ██ ████   ██    ██        ██    ██ ██      ██   ██ 
██ ████ ██ ██    ██ ██    ██ ██ ██  ██    ██        ██    ██ ███████ ██████  
██  ██  ██ ██    ██ ██    ██ ██  ██ ██    ██        ██    ██      ██ ██   ██ 
██      ██  ██████   ██████  ██   ████    ██         ██████  ███████ ██████  
                                                                                                                                                                                                                               
EOF
sleep3

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root" 
   exit 1
fi

# Update and install required packages
echo "Updating package list and installing usbmount..."
apt update && apt -y dist-upgrade
apt install -y usbmount
apt -y autoremove

# Edit usbmount configuration
echo "Updating usbmount configuration..."
sed -i 's/^FS_MOUNTOPTIONS=.*/FS_MOUNTOPTIONS="-fstype=vfat,ntfs,ext4 :utf8,uid=pi,gid=pi"/' /etc/usbmount/usbmount.conf

# Enable mounting of filesystems
echo "Enabling automount in systemd configuration..."
sed -i 's/PrivateMounts=yes/PrivateMounts=no/' /lib/systemd/system/systemd-udevd.service

# Restart systemd-udevd
echo "Restarting systemd-udevd service..."
systemctl daemon-reload
systemctl restart systemd-udevd

echo "USB automount setup complete!"
