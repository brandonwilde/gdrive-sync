#!/bin/bash
# install.sh - Install dependencies and configure services

set -e

# Update package lists and install required packages
echo "Installing dependencies..."
sudo apt update
sudo apt install -y rclone inotify-tools

# Optionally, copy a preconfigured rclone.conf (if available)
# echo "Copying rclone configuration..."
# cp ./rclone.conf ~/.config/rclone/rclone.conf

# Install systemd unit files
echo "Installing systemd unit files..."
sudo cp systemd_units/sync_remote.service /etc/systemd/system/
sudo cp systemd_units/sync_remote.timer /etc/systemd/system/
sudo cp systemd_units/sync_local.service /etc/systemd/system/

# Reload systemd to pick up new units
sudo systemctl daemon-reload

# Enable and start the remote sync timer and local sync service
echo "Enabling and starting systemd services..."
sudo systemctl enable --now sync_remote.timer
sudo systemctl enable --now sync_local.service

# Install logrotate configuration
echo "Installing logrotate configuration..."
sudo cp logrotate/gdrive_sync /etc/logrotate.d/gdrive_sync

echo "Installation complete!"
