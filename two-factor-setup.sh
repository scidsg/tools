#!/bin/bash

# Welcome message and ASCII art
cat << "EOF"
   _____      _                 ___  ______      
  / ____|    | |               |__ \|  ____/\    
 | (___   ___| |_ _   _ _ __      ) | |__ /  \   
  \___ \ / _ \ __| | | | '_ \    / /|  __/ /\ \  
  ____) |  __/ |_| |_| | |_) |  / /_| | / ____ \ 
 |_____/ \___|\__|\__,_| .__/  |____|_|/_/    \_\
                       | |                       
                       |_|                        
A free tool by Science & Design - https://scidsg.org
                                                              
Quickly configure two-factor authentication for your server.

EOF

sleep 3

# Update System
echo "Updating system..."
sudo apt update
sudo apt -y dist-upgrade 

# Enable SSH
echo "Enabling SSH..."
sudo systemctl enable ssh
sudo systemctl start ssh

# Enable challenge-response authentication
echo "Enabling challenge-response authentication..."
sudo sed -i 's/ChallengeResponseAuthentication no/ChallengeResponseAuthentication yes/g' /etc/ssh/sshd_config
sudo systemctl restart ssh

# Install Google Authenticator 
echo "Installing Google Authenticator..."
sudo apt -y install libpam-google-authenticator

# Configure two-factor authentication
echo "Configuring two-factor authentication..."
google-authenticator

# Enable two-factor authentication
echo "Enabling two-factor authentication..."
sudo bash -c 'echo "auth required pam_google_authenticator.so" >> /etc/pam.d/sshd'

# Restart SSH daemon
echo "Restarting SSH daemon..."
sudo systemctl restart ssh

echo "🎉 You've successfully configured two-factor authentication!"
