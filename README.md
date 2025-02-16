# gdrive-sync
Keep a local folder in sync with a folder in Google Drive

## Installation

1. **Clone this repository:**
   ```bash
   git clone https://github.com/brandonwilde/gdrive-sync.git
   cd gdrive-sync
   ```

2. **Install and configure rclone:**
   The sync scripts use rclone to communicate with Google Drive. Install and configure it:
   ```bash
   sudo apt install rclone
   rclone config
   ```
   Follow the prompts to:
   - Create a new remote drive. Take note of the name you assign it.
   - Select "Google Drive" as the storage type
   - Configure access to your Google Drive account

   The configuration will be saved to `~/.config/rclone/rclone.conf`. This location is important as the sync services are configured to use your user's rclone configuration file.

3. **Review configuration:**
   Edit `config.sh` to customize:
   - `LOCAL_DIR`: Your local directory to sync
   - `REMOTE_DIR`: Your rclone-assigned remote name, plus the folder name, in the format "remote:folder"
   - Other settings like sync delays and log locations

4. **Make scripts executable:**
   ```bash
   chmod +x install.sh uninstall.sh
   ```

5. **Run the installation:**
   ```bash
   sudo ./install.sh
   ```
   This will:
   - Install other required packages (inotify-tools)
   - Create necessary directories
   - Set up systemd services and timer
   - Configure log rotation

## How it Works

- **Local to Remote Sync**: A systemd service runs continuously, monitoring your local directory for changes using inotify. When changes are detected, they are synced to Google Drive.
- **Remote to Local Sync**: A systemd timer triggers every minute to check for changes in Google Drive and sync them to your local directory.
- **Logging**: All sync operations are logged to the path configured in `config.sh`. Logs are automatically rotated daily.

## Service Management

Check service status:
```bash
systemctl status sync_local.service
systemctl status sync_remote.timer
```

Stop/start services:
```bash
sudo systemctl stop sync_local.service
sudo systemctl start sync_local.service
sudo systemctl restart sync_remote.timer
```

View logs:
```bash
# View current log
tail -f /var/log/gdrive-sync/gdrive_sync.log

# List all logs (including rotated ones)
ls -l /var/log/gdrive-sync/gdrive_sync.log*

# View a compressed rotated log (this example views the log from 3 days ago)
zcat /var/log/gdrive-sync/gdrive_sync.log.3.gz
```

## Uninstallation

To remove the sync setup:
```bash
sudo ./uninstall.sh
```

This will stop and remove all services, timers, and configurations. Your files in both local and remote locations will remain untouched.