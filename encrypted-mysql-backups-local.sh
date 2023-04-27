#!/bin/bash

# Welcome message and ASCII art
cat << "EOF"

███████ ███    ██  ██████ ██████  ██    ██ ██████  ████████ ███████ ██████  
██      ████   ██ ██      ██   ██  ██  ██  ██   ██    ██    ██      ██   ██ 
█████   ██ ██  ██ ██      ██████    ████   ██████     ██    █████   ██   ██ 
██      ██  ██ ██ ██      ██   ██    ██    ██         ██    ██      ██   ██ 
███████ ██   ████  ██████ ██   ██    ██    ██         ██    ███████ ██████  

██████   █████   ██████ ██   ██ ██    ██ ██████  ███████ 
██   ██ ██   ██ ██      ██  ██  ██    ██ ██   ██ ██      
██████  ███████ ██      █████   ██    ██ ██████  ███████ 
██   ██ ██   ██ ██      ██  ██  ██    ██ ██           ██ 
██████  ██   ██  ██████ ██   ██  ██████  ██      ███████ 

A free tool made with ✊ by Science & Design - https://scidsg.org

🔒 Easy encrypted database backups                                                                                                                  
EOF
sleep 5

whiptail --title "Encrypted Database Backups" --msgbox "We're about to set up encrypted daily backups of your MySQL database. You'll need:

• Your DB name
• Your DB username
• Your DB password
• The email address assoicated with your PGP key
• The keyserver address
• The location you'd like your backups stored

Ensure you're running this on the same server as the database you intend to back up.

" 18 64

apt update && apt -y dist-upgrade
apt install -y rsync whiptail gnupg gnupg2
apt -y autoremove 

# Collect database credentials
DB_NAME=$(whiptail --inputbox "Enter your database name:" 8 78 "wikidb" --title "Database Name" 3>&1 1>&2 2>&3)
DB_USER=$(whiptail --inputbox "Enter your database user:" 8 78 "wikiuser" --title "Database User" 3>&1 1>&2 2>&3)
DB_PASS=$(whiptail --passwordbox "Enter your database password:" 8 78 --title "Database Password" 3>&1 1>&2 2>&3)

# Collect backup directory
BACKUP_DIR=$(whiptail --inputbox "Enter the local backup directory:" 8 78 "" --title "Backup Directory" 3>&1 1>&2 2>&3)

# Create backup directory if it doesn't exist
mkdir -p "${BACKUP_DIR}"

# Collect PGP key details
PGP_KEY_ID=$(whiptail --inputbox "Enter the email address for your PGP key:" 8 78 "" --title "PGP Email" 3>&1 1>&2 2>&3)
PGP_KEY_SERVER=$(whiptail --inputbox "Enter your PGP key server:" 8 78 "hkps://keys.openpgp.org" --title "PGP Key Server" 3>&1 1>&2 2>&3)

# Configure GnuPG to use keys.openpgp.org as the keyserver
echo "keyserver $PGP_KEY_SERVER" >> ~/.gnupg/gpg.conf

# Import the PGP key
gpg --keyserver "${PGP_KEY_SERVER}" --recv-keys "${PGP_KEY_ID}"

# Import and refresh the public PGP key
gpg --auto-key-locate keyserver --locate-keys "$PGP_KEY_ID"
gpg --refresh-keys

# Backup function
perform_backup() {
    TIMESTAMP=$(date +"%Y%m%d%H%M")
    BACKUP_FILE="${BACKUP_DIR}/mediawiki_db_backup_${TIMESTAMP}.sql.gz"
    ENCRYPTED_BACKUP_FILE="${BACKUP_FILE}.gpg"

    mysqldump --user="${DB_USER}" --password="${DB_PASS}" "${DB_NAME}" | gzip > "${BACKUP_FILE}"

    if [ $? -eq 0 ]; then
        echo "Backup created: ${BACKUP_FILE}"
        # Encrypt the backup file
        gpg --encrypt --trust-model always --recipient "$PGP_KEY_ID" --output "${ENCRYPTED_BACKUP_FILE}" "${BACKUP_FILE}"
        if [ $? -eq 0 ]; then
            echo "Encrypted backup created: ${ENCRYPTED_BACKUP_FILE}"
            # Remove the unencrypted backup file
            rm "${BACKUP_FILE}"
            if [ $? -eq 0 ]; then
                echo "Unencrypted backup file deleted: ${BACKUP_FILE}"
            else
                echo "Failed to delete unencrypted backup file. Error code: $?"
            fi
        else
            echo "Backup encryption failed. Error code: $?"
        fi
    else
        echo "Backup failed. Error code: $?"
    fi
}

# Perform the first backup
echo "Creating backup..."
perform_backup

echo "
Your backup directory is located at ${BACKUP_DIR}
"

# Create a new script with the backup function and necessary variables
BACKUP_SCRIPT="${BACKUP_DIR}/daily_backup.sh"
cat > "${BACKUP_SCRIPT}" << EOF
#!/bin/bash
DB_NAME="${DB_NAME}"
DB_USER="${DB_USER}"
DB_PASS="${DB_PASS}"
BACKUP_DIR="${BACKUP_DIR}"
PGP_KEY_ID="${PGP_KEY_ID}"
PGP_KEY_SERVER="${PGP_KEY_SERVER}"

$(declare -f perform_backup)

echo "Creating backup..."
perform_backup
EOF

# Make the new script executable
chmod +x "${BACKUP_SCRIPT}"

# Schedule the new script to run daily at midnight using cron
(crontab -l 2>/dev/null; echo "0 0 * * * ${BACKUP_SCRIPT} >> ${BACKUP_DIR}/logfile.log 2>&1") | crontab -
