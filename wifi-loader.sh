#!/bin/bash

# Welcome message and ASCII art
cat << "EOF"
 __      __  _    __   _     _                      _             
 \ \    / / (_)  / _| (_)   | |     ___   __ _   __| |  ___   _ _ 
  \ \/\/ /  | | |  _| | |   | |__  / _ \ / _` | / _` | / -_) | '_|
   \_/\_/   |_| |_|   |_|   |____| \___/ \__,_| \__,_| \___| |_|  

A free tool by Science & Design - https://scidsg.org
Bulk-add trusted wifi networks to your device. 

EOF

# Path to wpa_supplicant.conf
WPA_SUPPLICANT_CONF="/etc/wpa_supplicant/wpa_supplicant.conf"

# Check if wpa_supplicant.conf exists
if [[ ! -f $WPA_SUPPLICANT_CONF ]]; then
    whiptail --title "File Not Found" --msgbox "The wpa_supplicant.conf file was not found. This could be because the system does not require Wi-Fi connectivity, is networked virtually, or is connected via an Ethernet cable. If Wi-Fi is needed, please ensure the necessary Wi-Fi software is installed." 10 80
    exit 1
fi

# Function to check if network already exists
check_network_exists() {
    grep -qP 'ssid="'$(echo "$SSID" | sed 's/[^a-zA-Z0-9]/\\&/g')'"' $WPA_SUPPLICANT_CONF
}

# Function to add network to wpa_supplicant.conf
add_network() {
    # Get hashed password
    HASHED_PSK=$(wpa_passphrase "$SSID" "$PASSWORD" | grep 'psk=' | tail -n 1)

    # Prepare network block
    NETWORK_BLOCK="
network={
    ssid=\"$(printf '%q' "$SSID")\"
$HASHED_PSK
    key_mgmt=WPA-PSK
}"

    # Append network block to wpa_supplicant.conf
    echo "$NETWORK_BLOCK" >> $WPA_SUPPLICANT_CONF
}

# Function to overwrite network in wpa_supplicant.conf
overwrite_network() {
    # Remove the existing network block
    sed -i "/ssid=\"$(printf '%q' "$SSID")\"/,/}/d" $WPA_SUPPLICANT_CONF

    # Add the new network
    add_network
}

# Function to process a line (network) from the input file
process_network() {
    SSID=$1
    PASSWORD=$2

    if check_network_exists; then
        echo "Network $SSID already exists. Overwriting."
        overwrite_network
    else
        add_network
        echo "Network $SSID added successfully!"
    fi
}

# Check if a file was provided
if [[ ! -f $1 ]]; then
    echo "Please provide a valid file as input."
    exit 1
fi

# Process each line in the input file
while read -r line; do
    process_network $line
done < "$1"

echo "All networks processed successfully!"
