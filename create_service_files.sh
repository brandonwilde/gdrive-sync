#!/bin/bash

# Source our configuration
source "$(dirname "$0")/config.sh"

# Generate sync_remote.service
cat > "$(dirname "$0")/systemd_units/sync_remote.service" << EOL
[Unit]
Description=Sync from Google Drive to local directory
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=${LOCAL_DIR%/}/sync_remote_to_local.sh
User=${USER}

[Install]
WantedBy=multi-user.target
EOL

# Generate sync_remote.timer
cat > "$(dirname "$0")/systemd_units/sync_remote.timer" << EOL
[Unit]
Description=Run Google Drive to local sync every minute

[Timer]
OnBootSec=1min
OnUnitActiveSec=1min

[Install]
WantedBy=timers.target
EOL

# Generate sync_local.service
cat > "$(dirname "$0")/systemd_units/sync_local.service" << EOL
[Unit]
Description=Monitor and sync local directory to Google Drive
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=${LOCAL_DIR%/}/sync_local_to_remote.sh
User=${USER}
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOL

# Generate logrotate config
cat > "$(dirname "$0")/logrotate/gdrive_sync" << EOL
${LOGFILE} {
    daily
    rotate 7
    compress
    delaycompress
    missingok
    notifempty
    create 640 ${USER} ${USER}
}
EOL

echo "Configuration files generated successfully!"
