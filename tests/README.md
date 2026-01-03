# Tests

This directory contains test scripts for the gdrive-sync tool.

## test_safety.sh

Tests the safety mechanisms that prevent accidental data loss.

**What it tests:**
- Normal syncs (no deletes)
- Small deletes (under threshold)
- Large deletes (should trigger confirmation dialog)
- Catastrophic deletes (empty local folder)
- Rename detection (renames shouldn't count as deletes)
- Zenity dialog functionality

**How to run:**
```bash
cd /path/to/gdrive-sync
./tests/test_safety.sh
```

The test uses temporary directories in `/tmp/gdrive_sync_test` and will not touch your actual files.
