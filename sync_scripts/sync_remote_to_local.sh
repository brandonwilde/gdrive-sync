#!/bin/bash
#
# sync_remote_to_local.sh - Sync changes from Google Drive to local directory
#
# This script is triggered periodically by a systemd timer (every minute) to pull
# changes from Google Drive to the local directory.
#
# Safety features:
# - No delete restrictions (Google Drive is the source of truth)
# - Skips sync if local changes occurred in last 10 seconds (prevents conflicts)
# - Uses lock file to prevent concurrent syncs
# - Retries on MD5 hash mismatches

# Source configuration
source "$(dirname "$(dirname "$0")")/config.sh"

generate_prefix() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') | REMOTE |"
}

cleanup() {
    rm -f "$LOCKFILE"
}

sync_from_drive_to_local() {
    # Get precise timestamp (seconds + nanoseconds)
    get_timestamp() {
        date +%s%N
    }

    # Check if there are pending local changes
    if [ -f "$LAST_CHANGE_FILE" ]; then
        last_change=$(cat "$LAST_CHANGE_FILE")
        current_time=$(get_timestamp)
        time_since_change=$(( (current_time - last_change) / 1000000000 )) # Convert nanoseconds to seconds
        
        # If there was a local change in the last 10 seconds, skip this sync
        if [ $time_since_change -lt 10 ]; then
            echo "$(generate_prefix) Skipping remote sync due to recent local changes ($time_since_change seconds ago)" >> "$LOGFILE"
            return 0
        fi
    fi

    # Acquire lock
    if ! flock -n "$LOCKFILE" -c :; then
        echo "$(generate_prefix) WARNING: Another instance is already running, skipping sync" >> "$LOGFILE"
        return
    fi

    # Log the start of the sync
    echo "$(generate_prefix) INFO: Starting sync from Google Drive to local" >> "$LOGFILE"

    local retry_count=0
    while [ $retry_count -lt $MAX_RETRIES ]; do
        # Perform the sync
        OUTPUT=$(rclone sync --track-renames "$REMOTE_DIR" "$LOCAL_DIR" 2>&1)
        
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

    # Release lock
    flock -u "$LOCKFILE"
}

sync_from_drive_to_local
