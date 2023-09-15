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

# Function to display a Plasma dialog with a progress bar
show_progress_dialog() {
    # Create a temporary directory to store PID file
    temp_dir=$(mktemp -d)
    
    # Create a named pipe to communicate with yad
    pipe="$temp_dir/yad_progress_pipe"
    mkfifo "$pipe"

    # Initialize a counter
    counter=0

    # Start yad in the background
    yad --title="Launching Windows 10" --text="Please wait while Windows 10 is loading..." --center --progress --percentage=0 --auto-close --width=300 --height=100 < "$pipe" &
    yad_pid=$!
    
    # Store yad PID in a file
    echo "$yad_pid" > "$temp_dir/yad_pid"

    # Update the progress bar in the background
    while [ $counter -le 100 ]; do
        echo "$counter"
        counter=$((counter + 1))
        sleep 0.5
    done > "$pipe"

    ## Wait for the progress to complete (30 seconds)
    #sleep 30

    # Close the progress dialog
    #kill "$(cat "$temp_dir/yad_pid")"
    
    # Remove the temporary directory
    rm -r "$temp_dir"
}

# Show the progress dialog
#show_progress_dialog

# Launch virt-manager
# Check if the virtual machine is running
if virsh --connect "$uri" domstate "$vm_name" | grep -q "running"; then
    
    looking-glass-client
    

else
    # Show the progress dialog
    show_progress_dialog

    # Start the VM using virsh
    virsh --connect qemu:///system start "$vm_name"
    
  # Launch looking-glass-client
    looking-glass-client

    
fi

