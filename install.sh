#!/bin/bash
# install.sh - Install dependencies and configure services

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "Please run with sudo"
    exit 1
fi

# Update package lists and install required packages
echo "Installing dependencies..."
apt update
apt install -y rclone inotify-tools

# Generate systemd and logrotate files
echo "Generating systemd and logrotate files..."
./create_service_files.sh

# Optionally, copy a preconfigured rclone.conf (if available)
# echo "Copying rclone configuration..."
# cp ./rclone.conf ~/.config/rclone/rclone.conf

# Install systemd unit files
echo "Installing systemd unit files..."
cp systemd_units/sync_remote.service /etc/systemd/system/
cp systemd_units/sync_remote.timer /etc/systemd/system/
cp systemd_units/sync_local.service /etc/systemd/system/

# Reload systemd to pick up new units
systemctl daemon-reload

# Enable and start the remote sync timer and local sync service
echo "Enabling and starting systemd services..."
systemctl enable --now sync_remote.timer
systemctl enable --now sync_local.service

# Install logrotate configuration
echo "Installing logrotate configuration..."
cp logrotate/gdrive_sync /etc/logrotate.d/gdrive_sync

echo "Installation complete!"
