#!/bin/bash

# NVIDIA Headless Setup Script for Fedora
# Version: 2.0 - Fixed for GNOME/Wayland
# Description: Configure NVIDIA GPUs for headless operation

set -e

SCRIPT_NAME="nvidia-headless-setup"
SCRIPT_VERSION="2.0"
UDEV_RULES_FILE="/etc/udev/rules.d/99-nvidia-headless.rules"
MODPROBE_FILE="/etc/modprobe.d/nvidia-headless.conf"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Display help
show_help() {
    cat << EOF
${SCRIPT_NAME} v${SCRIPT_VERSION} - NVIDIA Headless Setup for Fedora

Usage: $0 [OPTIONS]

OPTIONS:
    -s, --setup          Setup NVIDIA headless configuration
    -a, --advanced       Interactive setup with prompts
    -v, --verify         Verify current configuration
    -r, --remove         Remove headless configuration
    -d, --detect         Detect NVIDIA GPUs and their PCI IDs
    --pci-id=VID:DID     Specify custom PCI ID (format: 10de:2786)
    -f, --force          Force reload NVIDIA drivers (requires reboot)
    -h, --help           Show this help message
    --version            Show version information

EXAMPLES:
    # Basic automated setup
    sudo $0 --setup
    
    # Interactive setup
    sudo $0 --advanced
    
    # Setup with specific PCI ID
    sudo $0 --setup --pci-id=10de:2786
    
    # Force reload NVIDIA drivers
    sudo $0 --setup --force
    
    # Verify configuration
    $0 --verify
    
    # Remove configuration
    sudo $0 --remove

CONFIGURATION FILES:
    ${UDEV_RULES_FILE}    - Udev rules to disable display
    ${MODPROBE_FILE}      - Kernel module parameters
EOF
}

# Detect NVIDIA GPUs
detect_gpus() {
    log_info "Detecting NVIDIA GPUs..."
    
    if ! command -v lspci &> /dev/null; then
        log_error "lspci not found. Please install pciutils: sudo dnf install pciutils"
        return 1
    fi
    
    local gpu_count
    gpu_count=$(lspci -d 10de: 2>/dev/null | grep -c "NVIDIA\|3D controller" || true)
    
    if [[ $gpu_count -eq 0 ]]; then
        log_warning "No NVIDIA GPUs detected via lspci"
        return 1
    fi
    
    log_info "Found $gpu_count NVIDIA GPU(s):"
    echo
    
    lspci -d 10de: | while IFS= read -r line; do
        echo "  - $line"
    done
    
    echo
    log_info "PCI IDs detected:"
    lspci -d 10de: -n | while IFS= read -r line; do
        local pci_addr device_id
        pci_addr=$(echo "$line" | awk '{print $1}')
        device_id=$(echo "$line" | awk '{print $3}')
        echo "  - PCI Address: $pci_addr, Device ID: $device_id"
    done
    
    return 0
}

# Get PCI IDs from first detected NVIDIA GPU
get_pci_ids() {
    local pci_info
    pci_info=$(lspci -d 10de: -n | head -1 2>/dev/null || true)
    
    if [[ -z "$pci_info" ]]; then
        log_error "Could not detect NVIDIA GPU PCI IDs"
        return 1
    fi
    
    local full_id
    full_id=$(echo "$pci_info" | awk '{print $3}')
    VENDOR_ID="0x${full_id%:*}"
    DEVICE_ID="0x${full_id#*:}"
    
    log_info "Detected GPU: Vendor=$VENDOR_ID, Device=$DEVICE_ID"
}

# Verify current configuration
verify_setup() {
    log_info "Verifying NVIDIA headless setup..."
    
    echo
    echo "=== Configuration Files ==="
    if [[ -f "$UDEV_RULES_FILE" ]]; then
        log_success "Udev rules file exists: $UDEV_RULES_FILE"
        echo "Content:"
        cat "$UDEV_RULES_FILE" | sed 's/^/  /'
    else
        log_warning "Udev rules file missing: $UDEV_RULES_FILE"
    fi
    
    echo
    if [[ -f "$MODPROBE_FILE" ]]; then
        log_success "Modprobe config exists: $MODPROBE_FILE"
        echo "Content:"
        cat "$MODPROBE_FILE" | sed 's/^/  /'
    else
        log_warning "Modprobe config missing: $MODPROBE_FILE"
    fi
    
    echo
    echo "=== NVIDIA Driver Status ==="
    if command -v nvidia-smi &> /dev/null; then
        log_success "nvidia-smi is available"
        echo "GPU Information:"
        nvidia-smi --query-gpu=name,driver_version,persistence_mode --format=csv,noheader | sed 's/^/  /'
    else
        log_warning "nvidia-smi not found or NVIDIA driver not installed"
    fi
    
    echo
    echo "=== Display Status ==="
    # Check if NVIDIA GPU is being used for display
    if command -v xrandr &> /dev/null; then
        if xrandr --listproviders 2>/dev/null | grep -q NVIDIA; then
            log_warning "NVIDIA GPU is still being used for display"
        else
            log_success "NVIDIA GPU not used for display"
        fi
    fi
    
    # Check nvidia-drm modeset
    if [[ -f "/sys/module/nvidia_drm/parameters/modeset" ]]; then
        local modeset_status
        modeset_status=$(cat /sys/module/nvidia_drm/parameters/modeset)
        if [[ "$modeset_status" == "N" ]]; then
            log_success "nvidia-drm modeset is disabled"
        else
            log_warning "nvidia-drm modeset is enabled (should be disabled)"
        fi
    fi
    
    echo
    echo "=== GPU Processes ==="
    if nvidia-smi 2>/dev/null | grep -q "No running processes found"; then
        log_success "No display processes using GPU"
    else
        log_warning "Processes detected using GPU"
        nvidia-smi | grep -A 10 "Processes" | head -10
    fi
    
    echo
    echo "=== Verification Complete ==="
}

# Force reload NVIDIA drivers
force_reload_nvidia() {
    log_info "Force reloading NVIDIA drivers..."
    
    # Check if we're in a display session
    if [[ -n "$DISPLAY" ]] || [[ -n "$WAYLAND_DISPLAY" ]]; then
        log_warning "You are currently in a graphical session."
        log_warning "This operation will restart the display manager and log you out."
        read -p "Continue? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info "Operation cancelled."
            return 1
        fi
    fi
    
    # Stop display manager
    if systemctl is-active --quiet gdm; then
        log_info "Stopping GDM..."
        sudo systemctl stop gdm
    fi
    
    # Remove NVIDIA modules
    log_info "Unloading NVIDIA modules..."
    sudo modprobe -r nvidia_drm nvidia_modeset nvidia_uvm nvidia 2>/dev/null || true
    
    # Reload with correct settings
    log_info "Reloading NVIDIA modules with headless configuration..."
    sudo modprobe nvidia
    sudo modprobe nvidia_modeset
    sudo modprobe nvidia_drm modeset=0
    sudo modprobe nvidia_uvm
    
    # Restart display manager
    log_info "Starting GDM..."
    sudo systemctl start gdm
    
    log_success "NVIDIA drivers reloaded with headless configuration"
}

# Setup NVIDIA headless configuration
setup_headless() {
    local interactive=false
    local force_reload=false
    
    if [[ "$1" == "true" ]]; then
        interactive=true
    fi
    
    if [[ "$2" == "true" ]]; then
        force_reload=true
    fi
    
    log_info "Starting NVIDIA headless setup..."
    
    # Check root privileges
    if [[ $EUID -ne 0 ]]; then
        log_error "This operation requires root privileges. Please run with sudo."
        exit 1
    fi
    
    # Detect GPUs if PCI IDs not provided
    if [[ -z "$CUSTOM_PCI_ID" ]]; then
        if ! get_pci_ids; then
            log_error "Failed to detect NVIDIA GPU PCI IDs"
            if [[ "$interactive" == "true" ]]; then
                read -p "Enter PCI ID manually (format 10de:2786): " custom_id
                if [[ -n "$custom_id" ]]; then
                    CUSTOM_PCI_ID="$custom_id"
                else
                    log_error "No PCI ID provided. Exiting."
                    exit 1
                fi
            else
                exit 1
            fi
        fi
    fi
    
    # Parse custom PCI ID if provided
    if [[ -n "$CUSTOM_PCI_ID" ]]; then
        if [[ "$CUSTOM_PCI_ID" =~ ^[0-9a-fA-F]{4}:[0-9a-fA-F]{4}$ ]]; then
            VENDOR_ID="0x${CUSTOM_PCI_ID%:*}"
            DEVICE_ID="0x${CUSTOM_PCI_ID#*:}"
            log_info "Using custom PCI ID: Vendor=$VENDOR_ID, Device=$DEVICE_ID"
        else
            log_error "Invalid PCI ID format: $CUSTOM_PCI_ID. Use format: 10de:2786"
            exit 1
        fi
    fi
    
    if [[ "$interactive" == "true" ]]; then
        echo
        log_info "Setup Summary:"
        echo "  Vendor ID: $VENDOR_ID"
        echo "  Device ID: $DEVICE_ID"
        echo "  Udev Rules: $UDEV_RULES_FILE"
        echo "  Modprobe Config: $MODPROBE_FILE"
        echo
        
        read -p "Proceed with setup? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info "Setup cancelled."
            exit 0
        fi
    fi
    
    # Create comprehensive udev rules file (FIXED VERSION)
    log_info "Creating udev rules file: $UDEV_RULES_FILE"
    cat > /tmp/nvidia-headless-udev.tmp << EOF
# NVIDIA Headless Configuration - Fixed for GNOME/Wayland
# Disable display for NVIDIA GPU in headless mode
SUBSYSTEM=="drm", KERNEL=="card*", ATTRS{vendor}=="$VENDOR_ID", ATTRS{device}=="$DEVICE_ID", ATTR{status}="disabled", RUN+="/bin/systemctl restart gdm"

# Prevent NVIDIA driver from loading display interfaces
SUBSYSTEM=="pci", ENV{ID_VENDOR_ID}=="$VENDOR_ID", ENV{ID_MODEL_ID}=="$DEVICE_ID", ENV{nvidia.headless}="1"

# Force disable GPU enable flag (nuclear option)
KERNEL=="nvidia*", RUN+="/bin/bash -c 'echo 0 > /sys/class/drm/card*/device/enable 2>/dev/null || true'"
EOF
    
    sudo mv /tmp/nvidia-headless-udev.tmp "$UDEV_RULES_FILE"
    sudo chmod 644 "$UDEV_RULES_FILE"
    
    # Create modprobe configuration file
    log_info "Creating modprobe configuration: $MODPROBE_FILE"
    cat > /tmp/nvidia-headless-modprobe.tmp << EOF
# NVIDIA Headless Mode Configuration
# Disable display mode setting for headless operation
options nvidia-drm modeset=0

# Performance optimizations for headless operation
options nvidia NVreg_EnablePCIeGen3=1
options nvidia NVreg_UsePageAttributeTable=1
options nvidia NVreg_InitializeSystemMemoryAllocations=0
EOF
    
    sudo mv /tmp/nvidia-headless-modprobe.tmp "$MODPROBE_FILE"
    sudo chmod 644 "$MODPROBE_FILE"
    
    # Reload udev rules
    log_info "Reloading udev rules..."
    sudo udevadm control --reload-rules
    sudo udevadm trigger
    
    # Update dracut for Fedora
    log_info "Updating initramfs (dracut)..."
    if command -v dracut &> /dev/null; then
        sudo dracut -f
    else
        log_warning "dracut not found, initramfs may not be updated"
    fi
    
    # Force reload if requested
    if [[ "$force_reload" == "true" ]]; then
        force_reload_nvidia
    fi
    
    log_success "NVIDIA headless setup completed successfully!"
    echo
    log_info "Files created:"
    echo "  - $UDEV_RULES_FILE"
    echo "  - $MODPROBE_FILE"
    echo
    
    if [[ "$force_reload" != "true" ]]; then
        log_warning "Please reboot for changes to take effect: sudo reboot"
        echo
        log_info "If display doesn't switch to integrated graphics after reboot, run:"
        log_info "  sudo $0 --setup --force"
    fi
}

# Remove headless configuration
remove_setup() {
    log_info "Removing NVIDIA headless configuration..."
    
    # Check root privileges
    if [[ $EUID -ne 0 ]]; then
        log_error "This operation requires root privileges. Please run with sudo."
        exit 1
    fi
    
    local removed=false
    
    if [[ -f "$UDEV_RULES_FILE" ]]; then
        sudo rm -v "$UDEV_RULES_FILE"
        removed=true
    else
        log_warning "Udev rules file not found: $UDEV_RULES_FILE"
    fi
    
    if [[ -f "$MODPROBE_FILE" ]]; then
        sudo rm -v "$MODPROBE_FILE"
        removed=true
    else
        log_warning "Modprobe config file not found: $MODPROBE_FILE"
    fi
    
    # Reload udev
    if [[ "$removed" == "true" ]]; then
        log_info "Reloading udev rules..."
        sudo udevadm control --reload-rules
        sudo udevadm trigger
        
        # Update dracut
        log_info "Updating initramfs (dracut)..."
        if command -v dracut &> /dev/null; then
            sudo dracut -f
        fi
        
        log_success "Headless configuration removed successfully!"
        log_warning "Please reboot to restore normal GPU operation: sudo reboot"
    else
        log_info "No headless configuration files found to remove."
    fi
}

# Main script execution
main() {
    local action=""
    local custom_pci_id=""
    local force_reload=false
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -s|--setup)
                action="setup"
                shift
                ;;
            -a|--advanced)
                action="advanced"
                shift
                ;;
            -v|--verify)
                action="verify"
                shift
                ;;
            -r|--remove)
                action="remove"
                shift
                ;;
            -d|--detect)
                action="detect"
                shift
                ;;
            -f|--force)
                force_reload=true
                shift
                ;;
            --pci-id=*)
                custom_pci_id="${1#*=}"
                shift
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            --version)
                echo "$SCRIPT_NAME v$SCRIPT_VERSION"
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                echo
                show_help
                exit 1
                ;;
        esac
    done
    
    # Default action if none specified
    if [[ -z "$action" ]]; then
        log_error "No action specified."
        echo
        show_help
        exit 1
    fi
    
    # Execute the requested action
    case $action in
        setup)
            CUSTOM_PCI_ID="$custom_pci_id"
            setup_headless false "$force_reload"
            ;;
        advanced)
            CUSTOM_PCI_ID="$custom_pci_id"
            setup_headless true "$force_reload"
            ;;
        verify)
            verify_setup
            ;;
        remove)
            remove_setup
            ;;
        detect)
            detect_gpus
            ;;
        *)
            log_error "Invalid action: $action"
            exit 1
            ;;
    esac
}

# Run main function with all arguments
main "$@"
