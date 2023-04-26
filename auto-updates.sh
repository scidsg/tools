#!/bin/bash

# Welcome message and ASCII art
cat << "EOF"
                _          _    _           _       _            
     /\        | |        | |  | |         | |     | |           
    /  \  _   _| |_ ___   | |  | |_ __   __| | __ _| |_ ___  ___ 
   / /\ \| | | | __/ _ \  | |  | | '_ \ / _` |/ _` | __/ _ \/ __|
  / ____ \ |_| | || (_) | | |__| | |_) | (_| | (_| | ||  __/\__ \
 /_/    \_\__,_|\__\___/   \____/| .__/ \__,_|\__,_|\__\___||___/
                                 | |                             
                                 |_|                             
A free tool by Science & Design - https://scidsg.org
                                                              
Never miss an important update.
EOF

sleep 3

#Update and upgrade
sudo apt update && sudo apt -y dist-upgrade && sudo apt -y autoremove

# Install required packages
sudo apt-get -y install unattended-upgrades

# Enable the "security" and "updates" repositories
sudo sed -i 's/\/\/\s\+"\${distro_id}:\${distro_codename}-security";/"\${distro_id}:\${distro_codename}-security";/g' /etc/apt/apt.conf.d/50unattended-upgrades
sudo sed -i 's/\/\/\s\+"\${distro_id}:\${distro_codename}-updates";/"\${distro_id}:\${distro_codename}-updates";/g' /etc/apt/apt.conf.d/50unattended-upgrades
sudo sed -i 's|//\s*Unattended-Upgrade::Remove-Unused-Kernel-Packages "true";|Unattended-Upgrade::Remove-Unused-Kernel-Packages "true";|' /etc/apt/apt.conf.d/50unattended-upgrades
sudo sed -i 's|//\s*Unattended-Upgrade::Remove-Unused-Dependencies "true";|Unattended-Upgrade::Remove-Unused-Dependencies "true";|' /etc/apt/apt.conf.d/50unattended-upgrades

sudo dpkg-reconfigure --priority=low unattended-upgrades

# Configure unattended-upgrades
echo 'Unattended-Upgrade::Automatic-Reboot "true";' | sudo tee -a /etc/apt/apt.conf.d/50unattended-upgrades
echo 'Unattended-Upgrade::Automatic-Reboot-Time "02:00";' | sudo tee -a /etc/apt/apt.conf.d/50unattended-upgrades

sudo systemctl restart unattended-upgrades

echo "Automatic updates have been installed and configured."
