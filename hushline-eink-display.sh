#!/bin/bash

# Install required packages for e-ink display
apt update
apt-get -y dist-upgrade
apt-get install -y python3-pip whiptail

# Welcome Prompt
whiptail --title "E-Ink Display Setup" --msgbox "The e-paper hat communicates with the Raspberry Pi using the SPI interface, so you need to enable it.\n\nNavigate to \"Interface Options\" > \"SPI\" and select \"Yes\" to enable the SPI interface." 12 64
sudo raspi-config

# Install Waveshare e-Paper library
git clone https://github.com/waveshare/e-Paper.git
pip3 install ./e-Paper/RaspberryPi_JetsonNano/python/
pip3 install qrcode[pil]
pip3 install requests python-gnupg


# Install other Python packages
pip3 install RPi.GPIO spidev
apt-get -y autoremove

# Enable SPI interface
if ! grep -q "dtparam=spi=on" /boot/config.txt; then
    echo "dtparam=spi=on" | sudo tee -a /boot/config.txt
    echo "SPI interface enabled."
else
    echo "SPI interface is already enabled."
fi

# Create a new script to display status on the e-ink display
cat > /home/pi/hush-line/display_status.py << EOL
import os
import sys
import time
import textwrap
import qrcode
import requests
import gnupg
from waveshare_epd import epd2in7
from PIL import Image, ImageDraw, ImageFont

def get_onion_address():
    with open('/var/lib/tor/hidden_service/hostname', 'r') as f:
        return f.read().strip()

def get_service_status():
    status = os.popen('systemctl is-active hush-line.service').read().strip()
    if status == 'active':
        return '✔ Hush Line is running'
    else:
        return '⛌ Hush Line is not running'

def display_status(epd, status, onion_address, name, email, key_id, expires):
    print(f'Displaying status: {status}, Onion address: {onion_address}')
    image = Image.new('1', (epd.height, epd.width), 255)
    draw = ImageDraw.Draw(image)

    font_status = ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf', 14)
    font_onion = ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf', 12)

    x_pos_status = 10
    y_pos_status = 15
    draw.text((x_pos_status, y_pos_status), status, font=font_status, fill=0)

    # Generate QR code
    qr = qrcode.QRCode(
        version=1,
        error_correction=qrcode.constants.ERROR_CORRECT_L,
        box_size=3,
        border=2,
    )
    qr.add_data(f'http://{onion_address}')
    qr.make(fit=True)

    qr_img = qr.make_image(fill_color="black", back_color="white")

    desired_size = 90  # Set the desired size for both width and height
    width_scale_factor = desired_size / qr_img.width
    height_scale_factor = desired_size / qr_img.height

    new_size = (int(qr_img.width * width_scale_factor), int(qr_img.height * height_scale_factor))
    resized_qr_img = qr_img.resize(new_size, Image.NEAREST)

    x_pos = 5
    y_pos = 80
    image.paste(resized_qr_img, (x_pos, y_pos))

    # Calculate the starting position for the PGP information text
    x_pos_info = x_pos + resized_qr_img.width + 10
    y_pos_info = y_pos + 6

    # Display the PGP owner information
    font_info = ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf', 11)
    max_width = epd.height - x_pos_info
    chars_per_line = max_width // font_info.getsize('A')[0]

    pgp_info = f'{name} <{email}>\nKey ID: {key_id[-8:]}\nExp: {time.strftime("%Y-%m-%d", time.gmtime(int(expires)))}'
    wrapped_pgp_info = []

    for line in pgp_info.split('\n'):
        wrapped_pgp_info.extend(textwrap.wrap(line, width=chars_per_line))

    line_spacing = 3
    empty_line_spacing = 0
    for i, line in enumerate(wrapped_pgp_info):
        draw.text((x_pos_info, y_pos_info), line, font=font_info, fill=0)
        if i < len(wrapped_pgp_info) - 1 and wrapped_pgp_info[i + 1] == '':
            y_pos_info += font_info.getsize(line)[1] + empty_line_spacing
        else:
            y_pos_info += font_info.getsize(line)[1] + line_spacing

    # Wrap the onion address to fit the display width
    max_width = epd.height
    chars_per_line = max_width // font_onion.getsize('A')[0]
    wrapped_onion = textwrap.wrap(onion_address, width=chars_per_line)

    y_text = 40
    x_pos_onion = 10
    for line in wrapped_onion:
        draw.text((x_pos_onion, y_text), line, font=font_onion, fill=0)
        y_text += font_onion.getsize(line)[1]

    # Rotate the image by 90 degrees for landscape mode
    image_rotated = image.rotate(90, expand=True)

    epd.display(epd.getbuffer(image_rotated))

def get_pgp_owner_info(file_path):
    with open(file_path, 'r') as f:
        key_data = f.read()

    gpg = gnupg.GPG()
    imported_key = gpg.import_keys(key_data)
    fingerprint = imported_key.fingerprints[0]
    key = gpg.list_keys(keys=fingerprint)[0]

    uids = key['uids'][0].split()
    name = ' '.join(uids[:-1])
    email = uids[-1].strip('<>')
    key_id = key['keyid']
    expires = key['expires']

    return name, email, key_id, expires

def main():
    print("Starting main function")
    epd = epd2in7.EPD()
    epd.init()
    print("EPD initialized")

    pgp_owner_info_url = "/home/pi/hush-line/public_key.asc"

    while True:
        status = get_service_status()
        print(f'Service status: {status}')
        onion_address = get_onion_address()
        print(f'Onion address: {onion_address}')
        name, email, key_id, expires = get_pgp_owner_info(pgp_owner_info_url)
        display_status(epd, status, onion_address, name, email, key_id, expires)
        time.sleep(60)

if __name__ == '__main__':
    print("Starting display_status script")
    try:
            main()
    except KeyboardInterrupt:
        print('Exiting...')
        sys.exit(0)
EOL

# Add a line to the .bashrc to run the display_status.py script on boot
if ! grep -q "sudo python3 /home/pi/hush-line/display_status.py" /home/pi/.bashrc; then
    echo "sudo python3 /home/pi/hush-line/display_status.py &" >> /home/pi/.bashrc
fi

echo "E-ink display configuration complete. Rebooting your Raspberry Pi..."
sleep 3

sudo reboot
