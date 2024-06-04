#!/bin/bash

# Function to list all drives and their UUIDs
list_drives() {
    ls -l /dev/disk/by-uuid/ | awk '{print $9, $11}' | sed 's#../../##' | while read -r uuid dev; do
        if [ -n "$dev" ] && [ -n "$uuid" ]; then
            echo "$dev $uuid"
        fi
    done
}

# Function to display menu and get user's choice
get_user_choice() {
    drives=()
    mapfile -t drives < <(list_drives)

    if [ ${#drives[@]} -eq 0 ]; then
        echo "No drives with UUIDs found."
        exit 1
    fi

    echo "Available drives:"
    for i in "${!drives[@]}"; do
        drive=$(echo "${drives[$i]}" | awk '{print $1}')
        echo "$((i+1))) $drive"
    done

    read -p "Enter the number of the drive you want to select: " choice

    if ! [[ "$choice" =~ ^[0-9]+$ ]] || [ "$choice" -lt 1 ] || [ "$choice" -gt ${#drives[@]} ]; then
        echo "Invalid choice."
        exit 1
    fi

    selected_drive="${drives[$((choice-1))]}"
}

# Main script
get_user_choice

# Extracting the UUID of the selected drive
selected_uuid=$(echo "$selected_drive" | awk '{print $2}')

echo "The UUID for the selected drive is: $selected_uuid"
