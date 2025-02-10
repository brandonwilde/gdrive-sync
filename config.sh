#!/bin/bash

# Directory paths
LOCAL_DIR="/home/brandon/ObsidianNotes"
REMOTE_DIR="gdrive_obsidian:Obsidian"

# Lock and log files
LOCKFILE="/tmp/obsidian_sync.lock"
LOGFILE="/home/brandon/obsidian_sync.log"

# Sync settings
RETRY_DELAY=5  # in seconds
MAX_RETRIES=5

# Additional settings specific to local-to-remote sync
DEBOUNCE_DELAY=4  # in seconds
LAST_CHANGE_FILE="/tmp/obsidian_last_change"
