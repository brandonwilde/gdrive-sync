#!/bin/bash

# WARNING: This file is read by the sync scripts while they are running.
# Changes to this file will take effect immediately.
# Be careful when modifying paths while syncing is active as it could
# lead to unexpected behavior. It's safer to stop the services first:
#   sudo systemctl stop sync_local.service sync_remote.timer

# Directory paths
LOCAL_DIR="/home/brandon/ObsidianNotes"
REMOTE_DIR="gdrive_obsidian:Obsidian"

# Sync settings
RETRY_DELAY=5  # in seconds
MAX_RETRIES=5
DEBOUNCE_DELAY=4  # in seconds, for local-to-remote sync

# Lock and log files
LOCKFILE="/tmp/gdrive_sync.lock"
LAST_CHANGE_FILE="/tmp/gdrive_last_change"
LOGFILE="/var/log/gdrive-sync/gdrive_sync.log"
