#!/bin/bash
# install.sh - Install dependencies and configure services

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "Please run with sudo"
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Check for required files and commands
check_requirements() {
    local missing_requirements=0
    
    # Check for required files
    local required_files=(
        "config.sh"
        "sync_scripts/sync_remote_to_local.sh"
        "sync_scripts/sync_local_to_remote.sh"
    )
    
    echo "Checking for required files..."
    for file in "${required_files[@]}"; do
        if [[ ! -f "${SCRIPT_DIR}/${file}" ]]; then
            echo "Error: ${file} not found"
            missing_requirements=1
        fi
    done

    # Check for rclone
    if ! command -v rclone >/dev/null 2>&1; then
        echo "Error: rclone is not installed. Please install and configure rclone before running this script."
        echo "See the README for instructions."
        missing_requirements=1
    fi
    
    if [[ $missing_requirements -eq 1 ]]; then
        echo "Required files or commands are missing. Please ensure all requirements are met before running this script."
        exit 1
    fi
}

# Run requirement checks
check_requirements

# Get the actual user who ran sudo
ACTUAL_USER=$(who am i | awk '{print $1}')
if [ -z "$ACTUAL_USER" ]; then
    ACTUAL_USER=$(logname)
fi

# Source our configuration to get paths
source "${SCRIPT_DIR}/config.sh"

# Create log directory and file with proper permissions
install -d -m 755 -o ${ACTUAL_USER} -g ${ACTUAL_USER} "$(dirname "$LOGFILE")"
install -m 640 -o ${ACTUAL_USER} -g ${ACTUAL_USER} /dev/null "$LOGFILE"

# Install required packages
echo "Installing dependencies..."
apt update
apt install -y inotify-tools zenity

# Optionally, copy a preconfigured rclone.conf (if available)
# echo "Copying rclone configuration..."
# cp ./rclone.conf ~/.config/rclone/rclone.conf

# Create necessary directories
echo "Creating directories..."
mkdir -p "${LOCAL_DIR}"
chown "${ACTUAL_USER}:${ACTUAL_USER}" "${LOCAL_DIR}"
mkdir -p "${SCRIPT_DIR}/systemd_units"
mkdir -p "${SCRIPT_DIR}/logrotate"

# Generate systemd and logrotate files
echo "Generating service files..."
cat > "${SCRIPT_DIR}/systemd_units/sync_remote.service" << EOL
[Unit]
Description=Sync from Google Drive to local directory
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
Environment="RCLONE_CONFIG=/home/${ACTUAL_USER}/.config/rclone/rclone.conf"
ExecStart=${SCRIPT_DIR}/sync_scripts/sync_remote_to_local.sh
User=${ACTUAL_USER}
Group=${ACTUAL_USER}

[Install]
WantedBy=multi-user.target
EOL

cat > "${SCRIPT_DIR}/systemd_units/sync_remote.timer" << EOL
[Unit]
Description=Sync from Google Drive to local directory every minute

[Timer]
OnBootSec=1min
OnUnitActiveSec=1min

[Install]
WantedBy=timers.target
EOL

cat > "${SCRIPT_DIR}/systemd_units/sync_local.service" << EOL
[Unit]
Description=Monitor and sync local directory to Google Drive
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
Environment="RCLONE_CONFIG=/home/${ACTUAL_USER}/.config/rclone/rclone.conf"
ExecStart=${SCRIPT_DIR}/sync_scripts/sync_local_to_remote.sh
User=${ACTUAL_USER}
Group=${ACTUAL_USER}
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOL

cat > "${SCRIPT_DIR}/logrotate/gdrive_sync" << EOL
${LOGFILE} {
    daily
    rotate 7
    compress
    delaycompress
    missingok
    notifempty
    create 640 ${ACTUAL_USER} ${ACTUAL_USER}
}
EOL

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
