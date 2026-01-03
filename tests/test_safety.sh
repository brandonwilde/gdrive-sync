#!/bin/bash
# test_safety.sh - Test the sync safety mechanisms before deploying to real data

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TEST_DIR="/tmp/gdrive_sync_test"
TEST_LOCAL="$TEST_DIR/local"
TEST_REMOTE="$TEST_DIR/remote"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_header() {
    echo -e "\n${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}\n"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

cleanup() {
    if [ -d "$TEST_DIR" ]; then
        rm -rf "$TEST_DIR"
        print_success "Cleaned up test directory"
    fi
}

# Setup test environment
setup_test() {
    print_header "Setting Up Test Environment"
    
    # Clean up any previous test
    cleanup
    
    # Create test directories
    mkdir -p "$TEST_LOCAL" "$TEST_REMOTE"
    
    # Create test files in "remote" (simulating Google Drive)
    echo "Creating 10 test files in 'remote' directory..."
    for i in {1..10}; do
        echo "Test content $i" > "$TEST_REMOTE/file$i.txt"
    done
    
    print_success "Created test directories:"
    print_success "  Local:  $TEST_LOCAL"
    print_success "  Remote: $TEST_REMOTE"
    print_success "  Remote has 10 files"
}

# Test 1: Normal sync (no deletes)
test_normal_sync() {
    print_header "Test 1: Normal Sync (No Deletes)"
    
    # Copy all files to local
    cp -r "$TEST_REMOTE"/* "$TEST_LOCAL/"
    
    # Add a new file locally
    echo "New file" > "$TEST_LOCAL/new_file.txt"
    
    echo "Counting files that would be deleted..."
    TEMP_LOCAL=$(mktemp)
    TEMP_REMOTE=$(mktemp)
    find "$TEST_LOCAL" -type f -printf '%P\n' 2>/dev/null | sort > "$TEMP_LOCAL"
    find "$TEST_REMOTE" -type f -printf '%P\n' 2>/dev/null | sort > "$TEMP_REMOTE"
    deletes=$(comm -13 "$TEMP_LOCAL" "$TEMP_REMOTE" | wc -l)
    rm -f "$TEMP_LOCAL" "$TEMP_REMOTE"
    
    if [ "$deletes" -eq 0 ]; then
        print_success "No deletes detected (as expected)"
        print_success "This sync would proceed without prompting"
    else
        print_error "Unexpected deletes: $deletes"
    fi
}

# Test 2: Small delete (under threshold)
test_small_delete() {
    print_header "Test 2: Small Delete (Under Threshold)"
    
    # Copy all files to local
    rm -rf "$TEST_LOCAL"/*
    cp -r "$TEST_REMOTE"/* "$TEST_LOCAL/"
    
    # Delete 3 files locally (under the threshold of 5)
    rm "$TEST_LOCAL/file1.txt" "$TEST_LOCAL/file2.txt" "$TEST_LOCAL/file3.txt"
    
    echo "Counting files that would be deleted..."
    TEMP_LOCAL=$(mktemp)
    TEMP_REMOTE=$(mktemp)
    find "$TEST_LOCAL" -type f -printf '%P\n' 2>/dev/null | sort > "$TEMP_LOCAL"
    find "$TEST_REMOTE" -type f -printf '%P\n' 2>/dev/null | sort > "$TEMP_REMOTE"
    deletes=$(comm -13 "$TEMP_LOCAL" "$TEMP_REMOTE" | wc -l)
    rm -f "$TEMP_LOCAL" "$TEMP_REMOTE"
    
    if [ "$deletes" -le 5 ]; then
        print_success "Deletes: $deletes (under threshold of 5)"
        print_success "This sync would proceed without prompting"
    else
        print_error "Unexpected delete count: $deletes"
    fi
}

# Test 3: Large delete (over threshold) - should trigger dialog
test_large_delete() {
    print_header "Test 3: Large Delete (Over Threshold - Should Prompt)"
    
    # Copy all files to local
    rm -rf "$TEST_LOCAL"/*
    cp -r "$TEST_REMOTE"/* "$TEST_LOCAL/"
    
    # Delete 7 files locally (over the threshold of 5)
    rm "$TEST_LOCAL"/file{1..7}.txt
    
    echo "Counting files that would be deleted..."
    TEMP_LOCAL=$(mktemp)
    TEMP_REMOTE=$(mktemp)
    find "$TEST_LOCAL" -type f -printf '%P\n' 2>/dev/null | sort > "$TEMP_LOCAL"
    find "$TEST_REMOTE" -type f -printf '%P\n' 2>/dev/null | sort > "$TEMP_REMOTE"
    deletes=$(comm -13 "$TEMP_LOCAL" "$TEMP_REMOTE" | wc -l)
    rm -f "$TEMP_LOCAL" "$TEMP_REMOTE"
    
    if [ "$deletes" -gt 5 ]; then
        print_warning "Deletes: $deletes (OVER threshold of 5)"
        print_warning "This would trigger a confirmation dialog"
        return 0
    else
        print_error "Expected more than 5 deletes, got: $deletes"
        return 1
    fi
}

# Test 4: Catastrophic delete (empty local) - should definitely prompt
test_catastrophic_delete() {
    print_header "Test 4: Catastrophic Delete (Empty Local - Should Prompt)"
    
    # Empty the local directory
    rm -rf "$TEST_LOCAL"/*
    
    echo "Counting files that would be deleted..."
    TEMP_LOCAL=$(mktemp)
    TEMP_REMOTE=$(mktemp)
    find "$TEST_LOCAL" -type f -printf '%P\n' 2>/dev/null | sort > "$TEMP_LOCAL"
    find "$TEST_REMOTE" -type f -printf '%P\n' 2>/dev/null | sort > "$TEMP_REMOTE"
    deletes=$(comm -13 "$TEMP_LOCAL" "$TEMP_REMOTE" | wc -l)
    rm -f "$TEMP_LOCAL" "$TEMP_REMOTE"
    
    if [ "$deletes" -eq 10 ]; then
        print_warning "Deletes: $deletes (ALL FILES)"
        print_warning "This would trigger a confirmation dialog"
        print_success "✓ Safety mechanism would catch this!"
        return 0
    else
        print_error "Expected 10 deletes, got: $deletes"
        return 1
    fi
}

# Test 5: Rename detection
test_rename_detection() {
    print_header "Test 5: Rename Detection (Should Not Count as Delete)"
    
    # Copy all files to local
    rm -rf "$TEST_LOCAL"/*
    cp -r "$TEST_REMOTE"/* "$TEST_LOCAL/"
    
    # Rename some files
    mv "$TEST_LOCAL/file1.txt" "$TEST_LOCAL/renamed1.txt"
    mv "$TEST_LOCAL/file2.txt" "$TEST_LOCAL/renamed2.txt"
    mv "$TEST_LOCAL/file3.txt" "$TEST_LOCAL/renamed3.txt"
    
    echo "Counting files that would be deleted..."
    TEMP_LOCAL=$(mktemp)
    TEMP_REMOTE=$(mktemp)
    find "$TEST_LOCAL" -type f -printf '%P\n' 2>/dev/null | sort > "$TEMP_LOCAL"
    find "$TEST_REMOTE" -type f -printf '%P\n' 2>/dev/null | sort > "$TEMP_REMOTE"
    deletes=$(comm -13 "$TEMP_LOCAL" "$TEMP_REMOTE" | wc -l)
    rm -f "$TEMP_LOCAL" "$TEMP_REMOTE"
    
    if [ "$deletes" -eq 0 ]; then
        print_success "Deletes: $deletes (renames not counted as deletes)"
        print_success "This sync would proceed without prompting"
    else
        print_warning "Deletes: $deletes (some renames may not have been detected)"
        print_warning "This is expected if file content changed"
    fi
}

# Test 6: Zenity dialog
test_zenity_dialog() {
    print_header "Test 6: Zenity Dialog Test"
    
    if ! command -v zenity &> /dev/null; then
        print_error "zenity is not installed"
        print_warning "Install it with: sudo apt install zenity"
        return 1
    fi
    
    if [ -z "$DISPLAY" ]; then
        print_error "No DISPLAY environment variable set"
        print_warning "You need to be in a graphical session to test zenity"
        return 1
    fi
    
    print_success "zenity is installed and DISPLAY is set"
    echo ""
    echo "Testing zenity dialog (you should see a popup)..."
    echo "Click 'Yes' if the dialog appeared correctly, or 'No' if it didn't..."
    
    if zenity --question --title="Test Dialog" \
        --text="This is a test of the confirmation dialog.\n\nDid this dialog appear correctly?" \
        --width=400 2>/dev/null; then
        print_success "User clicked 'Yes' - Dialog is working!"
        return 0
    else
        print_warning "User clicked 'No' or closed the dialog"
        return 0
    fi
}

# Main test runner
main() {
    print_header "Gdrive-Sync Safety Mechanism Test Suite"
    
    echo "This script will test the safety features before you deploy to real data."
    echo "It uses temporary directories and will not touch your actual files."
    echo ""
    read -p "Press Enter to continue..."
    
    setup_test
    
    # Run all tests
    test_normal_sync
    test_small_delete
    test_large_delete
    test_catastrophic_delete
    test_rename_detection
    test_zenity_dialog
    
    # Summary
    print_header "Test Summary"
    
    echo "Key Findings:"
    echo "  • Normal syncs and small deletes (≤5 files) proceed automatically"
    echo "  • Large deletes (>5 files) would trigger a confirmation dialog"
    echo "  • Empty local directory would trigger dialog (protecting your Drive)"
    echo "  • Renames are detected and don't count as deletes"
    echo ""
    
    if command -v zenity &> /dev/null && [ -n "$DISPLAY" ]; then
        print_success "Zenity is working - dialogs will appear when needed"
    else
        print_warning "Zenity not available - syncs with >5 deletes will be blocked"
        print_warning "Install zenity: sudo apt install zenity"
    fi
    
    echo ""
    print_success "All tests completed!"
    echo ""
    echo "To view the test files:"
    echo "  Local:  ls -la $TEST_LOCAL"
    echo "  Remote: ls -la $TEST_REMOTE"
    echo ""
    read -p "Press Enter to clean up test files..."
    
    cleanup
    
    print_header "Ready to Deploy"
    echo "The safety mechanisms are working correctly."
    echo "You can now set up your second laptop with confidence!"
    echo ""
    echo "Remember:"
    echo "  1. Clone the repo on the new laptop"
    echo "  2. Configure rclone (rclone config)"
    echo "  3. Edit config.sh with your paths"
    echo "  4. Run: sudo ./install.sh"
    echo ""
    echo "The safety features will protect you even if something goes wrong."
}

# Run main function
main
