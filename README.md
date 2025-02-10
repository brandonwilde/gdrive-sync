# gdrive-sync
Keep a local folder in sync with a folder in Google Drive

## Installation

1. **Clone this repository:**
   ```bash
   git clone https://github.com/brandonwilde/gdrive-sync.git
   cd gdrive-sync

2. **Run the installation script:**
   ```bash
   chmod +x install.sh
   sudo ./install.sh
   ```
   This script installs required packages, copies systemd and logrotate configuration files, and reloads systemd.

3. **Configure rclone:**
   If you haven’t already set up rclone for Google Drive, run:
   ```bash
   rclone config
   ```
   Then edit sync_remote_to_local.sh and sync_local_to_drive.sh as needed to match your rclone remote name and directories.

## Usage

- The remote-to-local sync is run as a systemd timer (see systemd_units/sync_remote.timer), triggering sync_remote_to_local.sh every minute.
- The local-to-remote sync is managed by a systemd service (see systemd_units/sync-local.service) that runs the inotify-based script continuously.
- Log output is written to /home/brandon/gdrive_sync.log and rotated automatically by logrotate (see logrotate/gdrive_sync).

## Customization:

Edit the scripts to adjust variables such as LOCAL_DIR, REMOTE_DIR, and LOCKFILE as needed.