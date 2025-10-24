#!/bin/bash

# VM Configuration
VM_NAME="win11"
URI="qemu:///system"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to check if VM is running
check_vm_status() {
    virsh --connect "$URI" domstate "$VM_NAME" 2>/dev/null | grep -q "running"
}

# Function to get VM status text
get_vm_status() {
    if check_vm_status; then
        echo "running"
    else
        echo "stopped"
    fi
}

# Function to wait for VM to start with timeout
wait_for_vm_start() {
    local timeout=60
    local counter=0
    
    echo "Waiting for VM to start..."
    while [ $counter -lt $timeout ]; do
        if check_vm_status; then
            echo -e "${GREEN}✓ VM is now running${NC}"
            return 0
        fi
        sleep 2
        ((counter+=2))
        echo "Waiting... ${counter}s"
    done
    echo -e "${RED}✗ VM startup timeout${NC}"
    return 1
}

# Function to wait for VM to shutdown with timeout
wait_for_vm_shutdown() {
    local timeout=30
    local counter=0
    
    echo "Waiting for VM to shutdown..."
    while [ $counter -lt $timeout ]; do
        if ! check_vm_status; then
            echo -e "${GREEN}✓ VM has shutdown${NC}"
            return 0
        fi
        sleep 2
        ((counter+=2))
        echo "Waiting... ${counter}s"
    done
    echo -e "${YELLOW}⚠ VM shutdown timeout - VM may still be shutting down${NC}"
    return 1
}

# Function to start VM with progress indication (GUI mode)
start_vm_gui() {
    echo "Starting Windows 11 VM..."
    
    # Start VM
    if ! virsh --connect "$URI" start "$VM_NAME" >/dev/null 2>&1; then
        zenity --error \
            --title="Startup Error" \
            --text="Failed to execute start command for Windows 11 VM." \
            --width=350
        return 1
    fi
    
    # Show progress dialog
    (
        echo "10" ; sleep 3
        echo "# Initializing VM hardware..." 
        
        echo "25" ; sleep 4
        echo "# Loading firmware..." 
        
        echo "40" ; sleep 5
        echo "# Booting Windows..." 
        
        echo "60" ; sleep 6
        echo "# Preparing system..." 
        
        echo "80" ; sleep 5
        echo "# Starting services..." 
        
        # Wait for VM to reach running state
        if wait_for_vm_start; then
            echo "100"
            echo "# VM started successfully! Launching Looking Glass..."
        else
            echo "# VM taking longer than expected to start..."
        fi
    ) | zenity --progress \
        --title="Starting Windows 11 VM" \
        --text="Please wait while the virtual machine starts..." \
        --percentage=0 \
        --auto-close \
        --width=400 \
        --height=150
    
    return 0
}

# Function to start VM (CLI mode)
start_vm_cli() {
    echo -e "${YELLOW}Starting Windows 11 VM...${NC}"
    
    if ! virsh --connect "$URI" start "$VM_NAME" >/dev/null 2>&1; then
        echo -e "${RED}✗ Failed to execute start command for Windows 11 VM${NC}"
        return 1
    fi
    
    echo -e "${GREEN}✓ VM start command sent${NC}"
    
    if wait_for_vm_start; then
        echo -e "${GREEN}✓ VM started successfully${NC}"
        return 0
    else
        echo -e "${YELLOW}⚠ VM is taking longer than expected to start${NC}"
        return 2
    fi
}

# Function to shutdown VM (graceful)
shutdown_vm() {
    local mode="${1:-cli}" # cli or gui
    
    if ! check_vm_status; then
        if [ "$mode" = "gui" ]; then
            zenity --info \
                --title="VM Not Running" \
                --text="Windows 11 VM is already stopped." \
                --width=300
        else
            echo -e "${YELLOW}⚠ Windows 11 VM is already stopped${NC}"
        fi
        return 0
    fi
    
    if [ "$mode" = "gui" ]; then
        # Show confirmation dialog for GUI mode
        zenity --question \
            --title="Shutdown VM" \
            --text="Are you sure you want to shutdown Windows 11 VM?\n\nThis will perform a graceful shutdown." \
            --width=400
        
        if [ $? -ne 0 ]; then
            echo "Shutdown cancelled."
            return 0
        fi
        
        # Show progress dialog
        (
            echo "25"
            echo "# Sending shutdown signal..."
            virsh --connect "$URI" shutdown "$VM_NAME" >/dev/null 2>&1
            
            echo "50"
            echo "# Waiting for VM to shutdown gracefully..."
            
            if wait_for_vm_shutdown; then
                echo "100"
                echo "# VM shutdown completed"
            else
                echo "# VM is taking longer to shutdown..."
            fi
        ) | zenity --progress \
            --title="Shutting Down Windows 11 VM" \
            --text="Please wait while the VM shuts down..." \
            --percentage=0 \
            --auto-close \
            --width=400 \
            --height=150
        
        # Check final status
        if check_vm_status; then
            zenity --warning \
                --title="Shutdown Warning" \
                --text="VM is still running. You may need to force shutdown or wait longer." \
                --width=400
            return 1
        else
            zenity --info \
                --title="Shutdown Complete" \
                --text="Windows 11 VM has been shut down." \
                --width=300
            return 0
        fi
        
    else
        # CLI mode
        echo -e "${YELLOW}Shutting down Windows 11 VM...${NC}"
        
        if ! virsh --connect "$URI" shutdown "$VM_NAME" >/dev/null 2>&1; then
            echo -e "${RED}✗ Failed to send shutdown command${NC}"
            return 1
        fi
        
        echo -e "${GREEN}✓ Shutdown command sent${NC}"
        
        if wait_for_vm_shutdown; then
            echo -e "${GREEN}✓ VM shutdown completed${NC}"
            return 0
        else
            echo -e "${YELLOW}⚠ VM is taking longer to shutdown${NC}"
            return 2
        fi
    fi
}

# Function to force shutdown VM
force_shutdown_vm() {
    local mode="${1:-cli}" # cli or gui
    
    if ! check_vm_status; then
        if [ "$mode" = "gui" ]; then
            zenity --info \
                --title="VM Not Running" \
                --text="Windows 11 VM is already stopped." \
                --width=300
        else
            echo -e "${YELLOW}⚠ Windows 11 VM is already stopped${NC}"
        fi
        return 0
    fi
    
    if [ "$mode" = "gui" ]; then
        # Show warning dialog for force shutdown
        zenity --question \
            --title="Force Shutdown VM" \
            --text="WARNING: Force shutdown may cause data loss!\n\nAre you sure you want to force shutdown Windows 11 VM?" \
            --width=450 \
            --ok-label="Force Shutdown" \
            --cancel-label="Cancel"
        
        if [ $? -ne 0 ]; then
            echo "Force shutdown cancelled."
            return 0
        fi
        
        if virsh --connect "$URI" destroy "$VM_NAME" >/dev/null 2>&1; then
            zenity --info \
                --title="Force Shutdown Complete" \
                --text="Windows 11 VM has been force shut down." \
                --width=300
            return 0
        else
            zenity --error \
                --title="Force Shutdown Error" \
                --text="Failed to force shutdown VM." \
                --width=350
            return 1
        fi
        
    else
        # CLI mode
        echo -e "${YELLOW}Force shutting down Windows 11 VM...${NC}"
        echo -e "${RED}WARNING: This may cause data loss!${NC}"
        
        read -p "Are you sure? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "Force shutdown cancelled."
            return 0
        fi
        
        if virsh --connect "$URI" destroy "$VM_NAME" >/dev/null 2>&1; then
            echo -e "${GREEN}✓ VM force shutdown completed${NC}"
            return 0
        else
            echo -e "${RED}✗ Failed to force shutdown VM${NC}"
            return 1
        fi
    fi
}

# Function to connect to VM automatically
connect_to_vm() {
    echo "Connecting to Windows 11 VM..."
    
    # Additional wait for VM to be fully ready
    echo "Waiting for VM to be ready..."
    sleep 5
    
    # Launch Looking Glass client
    if command -v looking-glass-client >/dev/null 2>&1; then
        echo -e "${GREEN}✓ Launching Looking Glass client...${NC}"
        looking-glass-client -F -a
        
        # If Looking Glass exits, we can close the terminal
        echo -e "${GREEN}✓ Looking Glass session ended${NC}"
    else
        echo -e "${RED}✗ Looking Glass client not found${NC}"
        return 1
    fi
}

# Function to show main menu
show_main_menu() {
    local choice=$(zenity --list \
        --title="Windows 11 VM Manager" \
        --text="Select an option:" \
        --radiolist \
        --column="Select" \
        --column="Option" \
        --column="Description" \
        TRUE "Start & Connect" "Start VM and auto-connect with Looking Glass" \
        FALSE "Connect Only" "Connect to already running VM" \
        FALSE "Shutdown" "Graceful shutdown" \
        FALSE "Force Shutdown" "Force stop VM (unsafe)" \
        FALSE "Status" "Check VM status only" \
        --width=700 \
        --height=400)
    
    echo "$choice"
}

# Function to show usage
show_usage() {
    echo "Windows 11 VM Manager"
    echo "====================="
    echo ""
    echo "Usage: $0 [OPTION]"
    echo ""
    echo "Options:"
    echo "  -s, --start        Start the VM (CLI mode)"
    echo "  -c, --connect      Connect to running VM with Looking Glass"
    echo "  -a, --auto         Start VM and auto-connect (CLI mode)"
    echo "  -t, --status       Check VM status (CLI mode)"
    echo "  -d, --shutdown     Graceful shutdown (CLI mode)"
    echo "  -f, --force        Force shutdown (unsafe, CLI mode)"
    echo "  -h, --help         Show this help message"
    echo ""
    echo "If no arguments are provided, the GUI mode will be started."
    echo ""
}

# CLI mode functions
cli_start() {
    if check_vm_status; then
        echo -e "${YELLOW}⚠ Windows 11 VM is already running${NC}"
        return 0
    else
        start_vm_cli
        return $?
    fi
}

cli_connect() {
    if check_vm_status; then
        echo -e "${GREEN}✓ Windows 11 VM is running, connecting...${NC}"
        connect_to_vm
    else
        echo -e "${RED}✗ Windows 11 VM is not running${NC}"
        echo "Use '$0 --start' to start the VM first"
        return 1
    fi
}

cli_auto() {
    if check_vm_status; then
        echo -e "${YELLOW}⚠ Windows 11 VM is already running${NC}"
        echo -e "${GREEN}✓ Connecting to VM...${NC}"
        connect_to_vm
    else
        if start_vm_cli; then
            echo -e "${GREEN}✓ VM started successfully, connecting...${NC}"
            connect_to_vm
        else
            echo -e "${RED}✗ Failed to start VM${NC}"
            return 1
        fi
    fi
}

cli_status() {
    local status=$(get_vm_status)
    if [ "$status" = "running" ]; then
        echo -e "${GREEN}✓ Windows 11 VM is RUNNING${NC}"
        return 0
    else
        echo -e "${YELLOW}⚠ Windows 11 VM is STOPPED${NC}"
        return 1
    fi
}

cli_shutdown() {
    shutdown_vm "cli"
}

cli_force_shutdown() {
    force_shutdown_vm "cli"
}

# GUI mode
gui_mode() {
    echo -e "${YELLOW}Windows 11 VM Manager (GUI Mode)${NC}"
    echo "================================"
    
    # Check if virsh is available
    if ! command -v virsh >/dev/null 2>&1; then
        zenity --error \
            --title="Dependency Missing" \
            --text="virsh command not found. Please install libvirt-clients." \
            --width=350
        exit 1
    fi
    
    # Check if zenity is available
    if ! command -v zenity >/dev/null 2>&1; then
        echo -e "${RED}Error: zenity not found. Please install zenity.${NC}"
        exit 1
    fi
    
    # Check if Looking Glass is available
    if ! command -v looking-glass-client >/dev/null 2>&1; then
        zenity --error \
            --title="Dependency Missing" \
            --text="Looking Glass client not found. Please install looking-glass-client." \
            --width=400
        exit 1
    fi
    
    # Show main menu
    local choice=$(show_main_menu)
    
    case "$choice" in
        "Start & Connect")
            if check_vm_status; then
                echo -e "${GREEN}✓ Windows 11 VM is already running${NC}"
                zenity --info \
                    --title="VM Already Running" \
                    --text="Windows 11 VM is already running.\n\nAuto-connecting with Looking Glass..." \
                    --width=400
                connect_to_vm
            else
                if start_vm_gui; then
                    # Auto-connect after successful start
                    echo -e "${GREEN}✓ VM started successfully, auto-connecting...${NC}"
                    connect_to_vm
                else
                    zenity --error \
                        --title="Startup Failed" \
                        --text="Failed to start Windows 11 VM." \
                        --width=350
                fi
            fi
            ;;
        "Connect Only")
            if check_vm_status; then
                echo -e "${GREEN}✓ Windows 11 VM is running${NC}"
                echo "Auto-connecting with Looking Glass..."
                connect_to_vm
            else
                zenity --error \
                    --title="VM Not Running" \
                    --text="Windows 11 VM is not running.\nPlease start the VM first." \
                    --width=350
            fi
            ;;
        "Shutdown")
            shutdown_vm "gui"
            ;;
        "Force Shutdown")
            force_shutdown_vm "gui"
            ;;
        "Status")
            if check_vm_status; then
                zenity --info \
                    --title="VM Status" \
                    --text="Windows 11 VM is currently RUNNING." \
                    --width=300
            else
                zenity --warning \
                    --title="VM Status" \
                    --text="Windows 11 VM is currently STOPPED." \
                    --width=300
            fi
            ;;
        *)
            echo "Operation cancelled."
            ;;
    esac
}

# Main script execution
main() {
    # Parse command line arguments
    case "${1:-}" in
        -s|--start)
            cli_start
            ;;
        -c|--connect)
            cli_connect
            ;;
        -a|--auto)
            cli_auto
            ;;
        -t|--status)
            cli_status
            ;;
        -d|--shutdown)
            cli_shutdown
            ;;
        -f|--force)
            cli_force_shutdown
            ;;
        -h|--help)
            show_usage
            ;;
        "")
            # No arguments, start GUI mode
            gui_mode
            ;;
        *)
            echo -e "${RED}✗ Unknown option: $1${NC}"
            echo ""
            show_usage
            return 1
            ;;
    esac
    
    echo -e "${GREEN}Script completed.${NC}"
}

# Run main function
main "$@"
