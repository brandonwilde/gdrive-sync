#!/bin/bash

# This script syncs the Obsidian notes from Google Drive to the local machine.
# It uses a lock file to avoid race conditions with another sync.
# The script will retry the sync operation if the lock is held by another process.
# The script is intended to be run periodically using a cron job.

LOCAL_DIR="/home/brandon/ObsidianNotes"
REMOTE_DIR="gdrive_obsidian:Obsidian"
LOCKFILE="/tmp/obsidian_sync.lock"
LOGFILE="/home/brandon/obsidian_sync.log"
RETRY_DELAY=5  # in seconds
MAX_RETRIES=5

generate_prefix() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') | REMOTE |"
}

cleanup() {
    rm -f "$LOCKFILE"
}

sync_from_drive_to_local() {
    echo "$(generate_prefix) Syncing Google Drive to local" >> "$LOGFILE"
    local retries=0
    while [ -e "$LOCKFILE" ]; do
        retries=$((retries + 1))
        if [[ $retries -ge $MAX_RETRIES ]]; then
            echo "$(generate_prefix) Max retries reached, skipping sync." >> "$LOGFILE"
            return 1
        fi
        echo "$(generate_prefix) Lock held by another process, retrying in $RETRY_DELAY seconds..." >> "$LOGFILE"
        sleep $RETRY_DELAY
    done

    trap cleanup EXIT

    touch "$LOCKFILE"            

    OUTPUT=$(rclone sync --checksum --track-renames "$REMOTE_DIR" "$LOCAL_DIR" 2>&1)
    
    while IFS= read -r line; do {
        if [[ $line == *"ERROR"* ]]; then
            echo "$(generate_prefix) ERROR | $line" >> "$LOGFILE"
        else
            echo "$(generate_prefix) SUCCESS | $line" >> "$LOGFILE"
        fi
    }
    done <<< "$OUTPUT"
}

sync_from_drive_to_local
