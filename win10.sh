#!/bin/bash

# Function to close the terminal window
function close_terminal() {
  sleep 2 # Wait for looking-glass-client process to exit properly
  #xdotool set_desktop 0 # Switch to workspace 0 (index starts from 0)
  wmctrl -c "Terminal" # Close the terminal window  
}

# Define the connection URI
uri="qemu:///system"

# Define the name of the virtual machine
vm_name="win10"

# Check if the virtual machine is running
if virsh --connect "$uri" domstate "$vm_name" | grep -q "running"; then
    echo "The $vm_name virtual machine is running."
    xdotool search --name "Terminal" windowsize 40 20
    looking-glass-client -a
    close_terminal

else
    echo "The $vm_name virtual machine is not running."
    # Start the VM using virsh
    virsh --connect qemu:///system start "$vm_name"
    # Win10 VM is not running, display progress bar with a 30-second delay
    clear
    xdotool search --name "Terminal" windowsize 40 20
    echo "Win10 VM is not running. Starting..."
    sleep 5
    echo -ne '#####                     (20%)\r'
    sleep 5
    echo -ne '##########                (40%)\r'
    sleep 5
    echo -ne '###############           (60%)\r'
    sleep 5
    echo -ne '####################      (80%)\r'
    sleep 5
    echo -ne '######################### (100%)\r'
    echo -ne '\n'
    sleep 5

  # Launch looking-glass-client
    looking-glass-client -a
    close_terminal
fi
