#!/bin/bash
#
# sync_local_to_remote.sh - Monitor local directory and sync changes to Google Drive
#
# This script runs continuously as a systemd service, monitoring the local directory
# for file changes using inotifywait. When changes are detected, it syncs them to
# Google Drive after a debounce delay.
#
# Safety features:
# - Counts files that would be deleted before syncing
# - Prompts user via zenity dialog if >5 files would be deleted
# - Disables sync if user cancels the deletion
# - Uses lock file to prevent concurrent syncs
# - Retries on MD5 hash mismatches

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

    # Check if sync has been disabled by user
    if [ -f "$SYNC_DISABLED_FILE" ]; then
        echo "$(generate_prefix) WARNING: Local-to-remote sync is disabled. Remove $SYNC_DISABLED_FILE to re-enable." >> "$LOGFILE"
        return
    fi

    # Create lockfile if it doesn't exist
    touch "$LOCKFILE"
    exec 9>"$LOCKFILE"  # Assign file descriptor 9 to the lockfile

    # Acquire lock with timeout
    if ! flock -n 9; then
        echo "$(generate_prefix) WARNING: Another instance is already running, skipping sync" >> "$LOGFILE"
        exec 9>&-  # Release file descriptor
        return
    fi

    # Count current files
    local_file_count=$(find "$LOCAL_DIR" -type f 2>/dev/null | wc -l)
    
    # Safety check: count how many files would be deleted
    # Use rclone lsf to list files in both locations, then compare
    # This is more robust than parsing text output
    TEMP_LOCAL_LIST=$(mktemp)
    TEMP_REMOTE_LIST=$(mktemp)
    
    # Get list of files (relative paths only)
    find "$LOCAL_DIR" -type f -printf '%P\n' 2>/dev/null | sort > "$TEMP_LOCAL_LIST"
    rclone lsf --recursive --files-only "$REMOTE_DIR" 2>/dev/null | sort > "$TEMP_REMOTE_LIST"
    
    # Count files in remote that are NOT in local (these would be deleted)
    deletes=$(comm -13 "$TEMP_LOCAL_LIST" "$TEMP_REMOTE_LIST" | wc -l)
    
    # Clean up temp files
    rm -f "$TEMP_LOCAL_LIST" "$TEMP_REMOTE_LIST"
    
    # If deletes exceed threshold, prompt user
    if [ "$deletes" -gt "$MAX_DELETE_COUNT" ]; then
        echo "$(generate_prefix) WARNING: Sync would delete $deletes files (threshold: $MAX_DELETE_COUNT). Prompting user." >> "$LOGFILE"
        
        # Try to show dialog to user (requires X session)
        if command -v zenity &> /dev/null && [ -n "$DISPLAY" ]; then
            if ! zenity --question --title="Confirm File Deletion" \
                --text="Local-to-remote sync will delete $deletes files from Google Drive.\n\nProceed with sync?" \
                --width=400 2>/dev/null; then
                echo "$(generate_prefix) INFO: User cancelled sync with $deletes deletes. Disabling local-to-remote sync." >> "$LOGFILE"
                touch "$SYNC_DISABLED_FILE"
                flock -u 9
                exec 9>&-
                return
            fi
            echo "$(generate_prefix) INFO: User approved sync with $deletes deletes." >> "$LOGFILE"
        else
            # No GUI available, block the sync
            echo "$(generate_prefix) ERROR: Cannot prompt user (no GUI). Refusing to sync. Remove $SYNC_DISABLED_FILE to override." >> "$LOGFILE"
            touch "$SYNC_DISABLED_FILE"
            flock -u 9
            exec 9>&-
            return
        fi
    fi

    # Log the start of the sync
    echo "$(generate_prefix) INFO: Starting sync triggered by \"$filename\" (local files: $local_file_count)" >> "$LOGFILE"

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