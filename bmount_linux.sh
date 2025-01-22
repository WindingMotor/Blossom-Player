#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Configuration
MOUNT_DIR="$HOME/Music/BlossomMount"
BLOSSOM_ID="com.wmstudios.blossom"
DEBUG=true

# Logging functions
log() {
    local level=$1
    shift
    echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] ${level}: $*"
}

info() { log "${BLUE}INFO${NC}" "$*"; }
success() { log "${GREEN}SUCCESS${NC}" "$*"; }
warning() { log "${YELLOW}WARNING${NC}" "$*"; }
error() { log "${RED}ERROR${NC}" "$*" >&2; }
debug() { if [ "$DEBUG" = true ]; then log "${CYAN}DEBUG${NC}" "$*"; fi; }

# Create mount directory
create_mount_dir() {
    debug "Checking mount directory: $MOUNT_DIR"
    if [ ! -d "$MOUNT_DIR" ]; then
        info "Creating mount directory: $MOUNT_DIR"
        mkdir -p "$MOUNT_DIR"
        if [ $? -ne 0 ]; then
            error "Failed to create mount directory"
            exit 1
        fi
    fi
}

# Unmount if already mounted
unmount_if_needed() {
    debug "Checking existing mounts"
    if mountpoint -q "$MOUNT_DIR" 2>/dev/null; then
        info "Unmounting existing mount"
        fusermount -u "$MOUNT_DIR" 2>/dev/null || \
        fusermount -uz "$MOUNT_DIR" 2>/dev/null || \
        sudo umount -l "$MOUNT_DIR" 2>/dev/null
        sleep 1
    fi
}

# Mount the Blossom app
mount_blossom() {
    info "Mounting Blossom app..."
    debug "Command: ifuse --documents $BLOSSOM_ID $MOUNT_DIR"

    # Direct mount command
    if ifuse --documents "$BLOSSOM_ID" "$MOUNT_DIR"; then
        success "Successfully mounted Blossom app"
        return 0
    else
        error "Failed to mount Blossom app"
        return 1
    fi
}

# Open file explorer
open_explorer() {
    if [ -d "$MOUNT_DIR" ] && mountpoint -q "$MOUNT_DIR"; then
        if command -v dolphin >/dev/null 2>&1; then
            dolphin "$MOUNT_DIR" &>/dev/null &
        elif command -v nautilus >/dev/null 2>&1; then
            nautilus "$MOUNT_DIR" &>/dev/null &
        else
            xdg-open "$MOUNT_DIR" &>/dev/null &
        fi
        success "Opened file explorer at $MOUNT_DIR"
    fi
}

# Cleanup function
cleanup() {
    debug "Running cleanup"
    if [ "$?" -ne 0 ]; then
        unmount_if_needed
    fi
}

trap cleanup EXIT

# Main execution
main() {
    info "Starting Blossom mount script"

    # Restart usbmuxd service
    debug "Restarting usbmuxd service"
    sudo systemctl restart usbmuxd
    sleep 2

    create_mount_dir
    unmount_if_needed

    if mount_blossom; then
        open_explorer
        success "Script completed successfully"
    else
        error "Script failed"
        exit 1
    fi
}

main
