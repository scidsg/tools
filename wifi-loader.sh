#!/bin/bash

# Path to wpa_supplicant.conf
WPA_SUPPLICANT_CONF="/etc/wpa_supplicant/wpa_supplicant.conf"

# Function to get network information
get_network_info() {
    SSID=$(whiptail --inputbox "Enter the SSID" 8 78 --title "Network Information" 3>&1 1>&2 2>&3)
    while true; do
        PASSWORD=$(whiptail --passwordbox "Enter the Wi-Fi Password" 8 78 --title "Network Information" 3>&1 1>&2 2>&3)
        if [ ${#PASSWORD} -ge 8 ]; then
            break
        else
            whiptail --title "Invalid Password" --msgbox "Password should be at least 8 characters long!" 8 45
        fi
    done
}

# Function to check if network already exists
check_network_exists() {
    grep -q "id_str=\"$(echo -n "$SSID" | sha256sum | cut -d " " -f 1)\"" $WPA_SUPPLICANT_CONF
}

# Function to add network to wpa_supplicant.conf
add_network() {
    # Get hashed password
    HASHED_PSK=$(wpa_passphrase "$SSID" "$PASSWORD" | grep 'psk=' | tail -n 1)

    # Prepare network block
    NETWORK_BLOCK="\nnetwork={
        ssid=\"$(printf '%q' "$SSID")\"
$HASHED_PSK
        id_str=\"$(echo -n "$SSID" | sha256sum | cut -d " " -f 1)\"
        key_mgmt=WPA-PSK
}\n"

    # Append network block to wpa_supplicant.conf
    echo -e "$NETWORK_BLOCK" >> $WPA_SUPPLICANT_CONF
}

# Function to overwrite network in wpa_supplicant.conf
overwrite_network() {
    # Remove the existing network block
    sed -i "/id_str=\"$(echo -n "$SSID" | sha256sum | cut -d " " -f 1)\"/,/}/d" $WPA_SUPPLICANT_CONF

    # Add the new network
    add_network
}

while true; do
    if (whiptail --title "Add Wi-Fi Network" --yes-button "Add" --no-button "Quit" --yesno "Do you want to add a Wi-Fi network?" 10 60) then
        get_network_info
        if check_network_exists; then
            if (whiptail --title "Network Exists" --yes-button "Overwrite" --no-button "Skip" --yesno "Network already exists. Do you want to overwrite it?" 10 60) then
                overwrite_network
                whiptail --title "Add Wi-Fi Network" --msgbox "Network overwritten successfully!" 8 45
            else
                whiptail --title "Add Wi-Fi Network" --msgbox "Skipped network!" 8 45
            fi
        else
            add_network
            whiptail --title "Add Wi-Fi Network" --msgbox "Network added successfully!" 8 45
        fi
    else
        break
    fi
done
