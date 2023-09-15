#!/bin/bash

# Function to display and update a KDE progress bar
display_progress_bar() {
    local title="Loading Windows 10 VM..."
    local progress=1
    local sleep_duration=5  # Adjust this to control the speed of the progress
    local total_duration=30    # Total duration in seconds
    local increment=$((99 / (total_duration / sleep_duration)))

    # Create the initial progress bar dialog
    kdialog --progressbar "$title" $progress

    while [ $progress -lt 100 ]; do
        # Update the progress value
        progress=$((progress + increment))
        if [ $progress -gt 100 ]; then
            progress=100
        fi

        # Update the progress bar dialog
        qdbus org.kde.kdialog-$(pidof kdialog) Set "" value $progress
        sleep $sleep_duration
    done

    # Close the progress bar dialog
    qdbus org.kde.kdialog-$(pidof kdialog) org.freedesktop.DBus.Introspectable.Introspect /org/kde/kdialog/$(pidof kdialog) org.freedesktop.DBus.Introspectable.Introspect
}

# Check if the VM 'win10' is running
vm_name="win10"

# Define the connection URI
uri="qemu:///system"
# Check if the VM 'win10' is running

vm_status=$(virsh --connect "$uri" domstate "$vm_name" | grep -q "running")
if [[ -n "$vm_status" ]]; then
    echo "Windows 10 VM is already running."
     looking-glass-client -a
else
    echo "Starting Windows 10 VM..."
    virsh --connect qemu:///system start "$vm_name"
    if [[ $? -eq 0 ]]; then
        echo "Windows 10 VM started successfully."
        display_progress_bar
        looking-glass-client -a
    else
        echo "Failed to start Windows 10 VM."
    fi
fi
