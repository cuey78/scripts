#!/bin/bash

# Define the backup file name
BACKUP_FILE="jellyfin_backup_$(date +"%Y-%m-%d").tar.gz"

# Define the directories to backup
DIRS_TO_BACKUP="/etc/jellyfin"
DIRS_TO_BACKUP+=" /var/lib/jellyfin"

# Check for root permissions
if [ "$EUID" -ne 0 ]; then
    echo "Please run as root or with sudo"
    exit
fi

# Function to create the backup
backup() {
    echo "Creating backup..."
    sudo tar -czvf "$BACKUP_FILE" $DIRS_TO_BACKUP
    echo "Backup created successfully: $BACKUP_FILE"
}

# Function to restore the backup
restore() {
    if [ ! -f "$BACKUP_FILE" ]; then
        echo "Backup file '$BACKUP_FILE' not found!"
        exit 1
    fi
    echo "Restoring from backup..."
    sudo tar -xzvf "$BACKUP_FILE" --overwrite -C /
    echo "Restored successfully."
}

# Function to finalize restoration
finalize() {
    echo "Fixing file permissions..."
    sudo chown -R jellyfin:jellyfin /var/lib/jellyfin
    sudo chown -R jellyfin:jellyfin /etc/jellyfin
    echo "Finalization complete. You can now start Jellyfin."
}

# Main script logic
case "$1" in
    backup)
        backup
        ;;
    restore)
        restore
        finalize
        ;;
    *)
        echo "Usage: $0 {backup|restore}"
        exit 1
        ;;
esac

