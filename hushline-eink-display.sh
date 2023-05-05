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

def display_status(epd, status, onion_address):
    print(f'Displaying status: {status}, Onion address: {onion_address}')
    image = Image.new('1', (epd.height, epd.width), 255)
    draw = ImageDraw.Draw(image)

    font_status = ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf', 14)
    font_onion = ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf', 12)

    x_pos_status = 10
    y_pos_status = 15
    draw.text((x_pos_status, y_pos_status), status, font=font_status, fill=0)

    # Wrap the onion address to fit the display width
    max_width = epd.height
    chars_per_line = max_width // font_onion.getsize('A')[0]
    wrapped_onion = textwrap.wrap(onion_address, width=chars_per_line)

    y_text = 40
    x_pos_onion = 10
    for line in wrapped_onion:
        draw.text((x_pos_onion, y_text), line, font=font_onion, fill=0)
        y_text += font_onion.getsize(line)[1]

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

    desired_size = 80  # Set the desired size for both width and height
    width_scale_factor = desired_size / qr_img.width
    height_scale_factor = desired_size / qr_img.height

    new_size = (int(qr_img.width * width_scale_factor), int(qr_img.height * height_scale_factor))
    resized_qr_img = qr_img.resize(new_size, Image.NEAREST)

    x_pos = 5
    y_pos = 80
    image.paste(resized_qr_img, (x_pos, y_pos))

    # Rotate the image by 90 degrees for landscape mode
    image_rotated = image.rotate(90, expand=True)

    epd.display(epd.getbuffer(image_rotated))

def main():
    print("Starting main function")
    epd = epd2in7.EPD()
    epd.init()
    print("EPD initialized")

    while True:
        status = get_service_status()
        print(f'Service status: {status}')
        onion_address = get_onion_address()
        print(f'Onion address: {onion_address}')
        display_status(epd, status, onion_address)
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
