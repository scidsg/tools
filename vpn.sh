#!/bin/bash

# Check if the script is run as root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root"
   exit 1
fi

# Update repositories and install required packages
apt update
apt install -y openvpn iptables-persistent wget

# Enable IP forwarding
sed -i 's/#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/' /etc/sysctl.conf
sysctl -p

# Configure static IP for eth0 (Optional: This is just an example, adjust as needed)
cat <<EOL >> /etc/dhcpcd.conf
interface eth0
static ip_address=192.168.1.1/24
EOL

# Set up NAT for VPN
iptables -t nat -A POSTROUTING -o tun0 -j MASQUERADE
iptables -A FORWARD -i tun0 -o eth0 -m state --state RELATED,ESTABLISHED -j ACCEPT
iptables -A FORWARD -i usb0 -o tun0 -j ACCEPT

# Save iptables rules
sh -c "iptables-save > /etc/iptables/rules.v4"

# Download OpenVPN config
read -p "Please enter the URL for the OpenVPN config file: " OVPN_URL
mkdir -p /etc/openvpn/client/
wget $OVPN_URL -O /etc/openvpn/client/myvpn.ovpn

# Enable OpenVPN service for automatic start on boot
systemctl enable openvpn-client@myvpn

echo "Setup complete. Start the VPN using 'sudo systemctl start openvpn-client@myvpn'!"