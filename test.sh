#!/bin/bash

# Function to display a KDE progress bar
display_progress_bar() {
    local title="Loading Windows 10 VM..."
    local progress=0
    local sleep_duration=0.3
    kdialog --progressbar "$title" $progress
    while [ $progress -lt 100 ]; do
        sleep $sleep_duration
        progress=$((progress + 5))  # Adjust the increment as needed
        kdialog --progressbar "$title" $progress
    done
    kdialog --progressbar "$title" 100
}
# Check if the VM 'win10' is running
vm_name="win10"

# Define the connection URI
uri="qemu:///system"

# Define the name of the virtual machine
vm_name="win10"

# Check if the virtual machine is running
if virsh --connect "$uri" domstate "$vm_name" | grep -q "running"; then
    looking-glass-client -a
#    close_terminal

else
    echo "The $vm_name virtual machine is not running."
    # Start the VM using virsh
    virsh --connect qemu:///system start "$vm_name"
    # Win10 VM is not running, display progress bar with a 30-second delay
    display_progress_bar

  # Launch looking-glass-client
    looking-glass-client -a
fi
