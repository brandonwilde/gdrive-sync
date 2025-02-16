#!/bin/bash

# This script syncs the Obsidian notes from the local machine to Google Drive.
# The script uses inotifywait to monitor the local folder for changes
# It uses a lock file to avoid race conditions with another sync.
# The script will retry the sync operation if the lock is held by another process.

# Source configuration
source "$(dirname "$(dirname "$0")")/config.sh"

generate_prefix() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') | LOCAL |"
}

cleanup() {
    rm -f "$LOCKFILE"
}

sync_from_local_to_drive() {
    local filename="$1"
    local retry_count=0

    # Create lockfile if it doesn't exist
    touch "$LOCKFILE"
    exec 9>"$LOCKFILE"  # Assign file descriptor 9 to the lockfile

    # Acquire lock with timeout
    if ! flock -n 9; then
        echo "$(generate_prefix) WARNING: Another instance is already running, skipping sync" >> "$LOGFILE"
        exec 9>&-  # Release file descriptor
        return
    fi

    # Log the start of the sync
    echo "$(generate_prefix) INFO: Starting sync triggered by \"$filename\"" >> "$LOGFILE"

    while [ $retry_count -lt $MAX_RETRIES ]; do
        # Perform the sync
        OUTPUT=$(rclone sync --track-renames "$LOCAL_DIR" "$REMOTE_DIR" 2>&1)
        
        # Check for specific error conditions
        if [[ $OUTPUT == *"corrupted on transfer"* ]] || [[ $OUTPUT == *"md5 hashes differ"* ]]; then
            retry_count=$((retry_count + 1))
            echo "$(generate_prefix) WARNING: MD5 mismatch detected (attempt $retry_count/$MAX_RETRIES)" >> "$LOGFILE"
            
            if [ $retry_count -lt $MAX_RETRIES ]; then
                echo "$(generate_prefix) INFO: Waiting $RETRY_DELAY seconds before retry..." >> "$LOGFILE"
                sleep $RETRY_DELAY
                continue
            fi
        fi

        # Log the output based on success/failure
        if [[ $OUTPUT == *"ERROR"* ]]; then
            echo "$(generate_prefix) ERROR: Sync failed after $retry_count retries" >> "$LOGFILE"
            echo "$(generate_prefix) ERROR | $OUTPUT" >> "$LOGFILE"
        else
            echo "$(generate_prefix) SUCCESS: Sync completed" >> "$LOGFILE"
            if [ "$OUTPUT" != "" ]; then
                echo "$(generate_prefix) INFO | $OUTPUT" >> "$LOGFILE"
            fi
            break
        fi
    done

    # Release lock and close descriptor
    flock -u 9
    exec 9>&-
}

# Initialize the last change file
touch "$LAST_CHANGE_FILE"

# Monitor the local folder for changes
inotifywait -m -r -e modify,create,delete,move "$LOCAL_DIR" |
while read -r directory events filename; do
    # if filename doesn't end with .partial
    if [[ "$filename" != *.partial ]]; then
        # Update the last change time
        date +%s%N > "$LAST_CHANGE_FILE"
        
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