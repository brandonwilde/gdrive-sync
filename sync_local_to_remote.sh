#!/bin/bash

# This script syncs the Obsidian notes from the local machine to Google Drive.
# The script uses inotifywait to monitor the local folder for changes
# It uses a lock file to avoid race conditions with another sync.
# The script will retry the sync operation if the lock is held by another process.

LOCAL_DIR="/home/brandon/ObsidianNotes"
REMOTE_DIR="gdrive_obsidian:Obsidian"
LOCKFILE="/tmp/obsidian_sync.lock"
LOGFILE="/home/brandon/obsidian_sync.log"
RETRY_DELAY=5  # in seconds
MAX_RETRIES=5
DEBOUNCE_DELAY=4  # in seconds
LAST_CHANGE_FILE="/tmp/obsidian_last_change"

generate_prefix() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') | LOCAL |"
}

cleanup() {
    rm -f "$LOCKFILE"
}

sync_from_local_to_drive() {
    local filename="$1"
    echo "$(generate_prefix) Syncing local ('$filename') to Google Drive" >> "$LOGFILE"
    retries=0
    while [ -e "$LOCKFILE" ]; do
        retries=$((retries + 1))
        if [[ $retries -ge $MAX_RETRIES ]]; then
            echo "$(generate_prefix) Max retries reached, skipping sync of ('$filename')." >> "$LOGFILE"
            return 1
        fi
        echo "$(generate_prefix) Lock held by another process, retrying in $RETRY_DELAY seconds..." >> "$LOGFILE"
        sleep $RETRY_DELAY
    done

    trap cleanup EXIT INT TERM HUP

    touch "$LOCKFILE"

    OUTPUT=$(rclone sync --checksum --track-renames "$LOCAL_DIR" "$REMOTE_DIR" 2>&1)
    
    while IFS= read -r line; do {
        if [[ $line == *"ERROR"* ]]; then
            echo "$(generate_prefix) ERROR | $line" >> "$LOGFILE"
        else
            echo "$(generate_prefix) SUCCESS | $line" >> "$LOGFILE"
        fi
    }
    done <<< "$OUTPUT"

    cleanup
}

# Initialize the last change file
touch "$LAST_CHANGE_FILE"

# Monitor the local folder for changes
inotifywait -m -r -e modify,create,delete,move "$LOCAL_DIR" |
while read -r directory events filename; do
    # if filename doesn't end with .partial
    if [[ "$filename" != *.partial ]]; then
        # Update the last change time
        date +%s > "$LAST_CHANGE_FILE"
        
        # Start a background process to handle the debounced sync
        (
            # Get the change time
            change_time=$(cat "$LAST_CHANGE_FILE")
            
            # Wait for the debounce delay
            sleep "$DEBOUNCE_DELAY"
            
            # Check if there have been any new changes during the delay
            current_time=$(cat "$LAST_CHANGE_FILE")
            if [ "$change_time" = "$current_time" ]; then
                sync_from_local_to_drive "$filename"
            fi
        ) &
    fi
done