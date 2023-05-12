#!/bin/bash

# Welcome Prompt
whiptail --title "E-Ink Display Setup" --msgbox "The e-paper hat communicates with the Raspberry Pi using the SPI interface, so you need to enable it.\n\nNavigate to \"Interface Options\" > \"SPI\" and select \"Yes\" to enable the SPI interface." 12 64
sudo raspi-config

# Install the necessary dependencies
sudo apt-get install python3-pip fonts-dejavu python3-pillow -y

# Install the Adafruit EPD library
sudo pip3 install adafruit-circuitpython-epd qrcode pgpy requests python-gnupg

# Ask the user for the Hush Line address and PGP key address
HUSH_LINE_ADDRESS=$(whiptail --inputbox "What's the Hush Line address?" 8 78 --title "Hush Line address" 3>&1 1>&2 2>&3)
PGP_KEY_ADDRESS=$(whiptail --inputbox "What's the address for your PGP key?" 8 78 --title "PGP key address" 3>&1 1>&2 2>&3)

# Download the key and rename to public_key.asc
wget $PGP_KEY_ADDRESS -O public_key.asc

# Write the Hush Line address and PGP key address to a config file
mkdir -p /home/pi/hush-line/
echo "HUSH_LINE_ADDRESS=$HUSH_LINE_ADDRESS" > /home/pi/hush-line/config.txt
echo "PGP_KEY_ADDRESS=$PGP_KEY_ADDRESS" >> /home/pi/hush-line/config.txt

# Create a new script to display status on the e-ink display
# Create the hush-line directory if it does not exist
cat > /home/pi/hush-line/app_status.py << EOL
import digitalio
import busio
import board
import qrcode
from adafruit_epd.ssd1680 import Adafruit_SSD1680
from PIL import Image, ImageDraw, ImageFont
import time
import textwrap
import pgpy
import requests
import gnupg

def get_key_info(file_path):
    # Load the PGP key from the file
    with open(file_path, "r") as f:
        key_data = f.read()

    # Parse the key
    key, _ = pgpy.PGPKey.from_blob(key_data)

    # Extract the user ID (name and email) and key ID
    user_name = str(key.userids[0].name)
    user_email = str(key.userids[0].email)
    user_id = f"{user_name} <{user_email}>"
    key_id = key.fingerprint[-8:]  # Last 8 characters of the fingerprint are the key ID

    # Extract the expiration date
    exp_date = "No expiration"
    if key.expires_at is not None:
        exp_date = key.expires_at.strftime("%Y-%m-%d")

    return user_id, key_id, exp_date

user_id, key_id, exp_date = get_key_info("/home/pi/hush-line/public_key.asc")
print(f"{user_id}\nKey ID: {key_id}\nExp: {exp_date}")

# Read the Hush Line and PGP key addresses from the config file
with open("/home/pi/hush-line/config.txt") as f:
    lines = f.readlines()

hush_line_address = lines[0].split("=")[1].strip()
pgp_key_address = lines[1].split("=")[1].strip()

# Configure the e-ink display pins
spi = busio.SPI(board.SCK, MOSI=board.MOSI, MISO=board.MISO)
ecs = digitalio.DigitalInOut(board.CE0)
dc = digitalio.DigitalInOut(board.D22)
rst = digitalio.DigitalInOut(board.D27)
busy = digitalio.DigitalInOut(board.D17)

# Initialize the Display
display = Adafruit_SSD1680(
    122, 250, spi, cs_pin=ecs, dc_pin=dc, sramcs_pin=None, rst_pin=rst, busy_pin=busy
)

# Load default font.
font = ImageFont.load_default()

while True:
    # Clear the display
    display.fill(0xFF)
    display.display()

    # Create a white filled image to draw on in 'L' mode (greyscale)
    image = Image.new("L", (display.height, display.width), color=255)  # Notice the swap of width and height here

    # Get drawing object to draw on image.
    draw = ImageDraw.Draw(image)

    # Generate QR code
    qr = qrcode.QRCode(
        version=1,
        error_correction=qrcode.constants.ERROR_CORRECT_L,
        box_size=4,
        border=1,
    )
    qr.add_data(hush_line_address)
    qr.make(fit=True)

    # Convert QR code to image
    qr_img = qr.make_image(fill="black", back_color="white").convert("L")

    # Resize the image
    desired_height = 120  # Set the desired height here
    aspect_ratio = qr_img.width / qr_img.height
    new_width = int(desired_height * aspect_ratio)
    qr_img = qr_img.resize((new_width, desired_height))

    # Paste the QR code onto our image
    qr_x = 0
    qr_y = 0
    image.paste(qr_img, (qr_x, qr_y))

    # Draw the PGP key information
    info_text = f"{user_id}\nKey ID: {key_id}\nExp: {exp_date}"
    text = info_text  # Removed the PGP key address line

    # Wrap the text
    wrapped_text = textwrap.wrap(text, width=18)  # Adjust width as needed

    # Create a new image for the text
    text_image = Image.new("L", (display.height - qr_img.height, display.width), color=255)
    text_draw = ImageDraw.Draw(text_image)

    current_height = 0
    for line in wrapped_text:
        text_draw.text((0, current_height), line, font=font, fill=0)
        current_height += font.getsize(line)[1]

    # Add a gap after the QR code
    gap = 10  # Adjust the gap size as you wish

    # Paste the text image onto our main image
    text_x = qr_img.width + gap  # Start where the QR code ends and add the gap
    text_y = 5  # Top of the screen
    image.paste(text_image, (text_x, text_y))  # Use text_image here, not rotated_text_image

    # Rotate the whole image
    image = image.rotate(-90, expand=True)

    # Display image
    display.image(image)
    display.display()

    time.sleep(60)

EOL

# Clear display before shutdown
cat > /etc/systemd/system/app-status.service << EOL
[Unit]
Description=Hush Line Display Service
After=network.target

[Service]
ExecStart=/usr/bin/python3 /home/pi/hush-line/app_status.py
WorkingDirectory=/home/pi/hush-line
StandardOutput=inherit
StandardError=inherit
Restart=always
User=pi

[Install]
WantedBy=multi-user.target
EOL

sudo systemctl start app-status
sudo systemctl enable app-status

apt-get -y autoremove

echo "✅ E-ink display configuration complete. Rebooting your Raspberry Pi..."
sleep 3

sudo reboot