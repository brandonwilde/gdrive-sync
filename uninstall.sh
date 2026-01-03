#!/bin/bash

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "Please run with sudo"
    exit 1
fi

# Source our configuration to get paths
source "$(dirname "$0")/config.sh"

echo "Stopping and disabling services..."
# Stop and disable services
systemctl stop sync_remote.timer
systemctl stop sync_local.service
systemctl disable sync_remote.timer
systemctl disable sync_local.service

echo "Removing systemd unit files..."
# Remove systemd unit files
rm -f /etc/systemd/system/sync_remote.service
rm -f /etc/systemd/system/sync_remote.timer
rm -f /etc/systemd/system/sync_local.service

# Reload systemd to recognize removed units
systemctl daemon-reload

echo "Removing logrotate configuration..."
# Remove logrotate config
rm -f /etc/logrotate.d/gdrive_sync

echo "Cleaning up log file..."
# Optionally remove the log file (ask user first)
read -p "Do you want to remove the log file (${LOGFILE})? [y/N] " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    rm -f "${LOGFILE}"
    echo "Log file removed."
fi

echo "Uninstallation complete!"
echo "Note: rclone, inotify-tools, and zenity packages were not removed."
echo "If you want to remove them, run: apt remove rclone inotify-tools zenity"
