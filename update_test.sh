#!/bin/bash

# Test suite for GTNH Prism Client Update Script

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_UNDER_TEST="$SCRIPT_DIR/update.sh"

# Test directory setup
TEST_DIR=$(mktemp -d)
trap "rm -rf $TEST_DIR" EXIT

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

TESTS_PASSED=0
TESTS_FAILED=0

#######################################
# TEST HELPERS
#######################################
setup_mock_instance() {
    local instance_dir="$1"
    mkdir -p "$instance_dir/.minecraft/config"
    mkdir -p "$instance_dir/.minecraft/mods"
    mkdir -p "$instance_dir/.minecraft/serverutilities"
    mkdir -p "$instance_dir/.minecraft/scripts"
    mkdir -p "$instance_dir/.minecraft/resources"
    mkdir -p "$instance_dir/libraries"
    mkdir -p "$instance_dir/patches"
    echo "test config" > "$instance_dir/.minecraft/config/test.cfg"
    echo "test mod" > "$instance_dir/.minecraft/mods/test-mod.jar"
    echo "name=OldGTNH" > "$instance_dir/instance.cfg"
    echo '{"components":[]}' > "$instance_dir/mmc-pack.json"
}

setup_mock_client_archive() {
    local archive_dir="$1"
    local archive_file="$2"

    mkdir -p "$archive_dir/GTNH/.minecraft/config"
    mkdir -p "$archive_dir/GTNH/.minecraft/mods"
    mkdir -p "$archive_dir/GTNH/.minecraft/serverutilities"
    mkdir -p "$archive_dir/GTNH/libraries"
    mkdir -p "$archive_dir/GTNH/patches"
    echo "new config" > "$archive_dir/GTNH/.minecraft/config/new.cfg"
    echo "new mod" > "$archive_dir/GTNH/.minecraft/mods/new-mod.jar"
    echo "new serverutil" > "$archive_dir/GTNH/.minecraft/serverutilities/data.json"
    echo '{"components":["new"]}' > "$archive_dir/GTNH/mmc-pack.json"

    (cd "$archive_dir" && tar -czf "$archive_file" GTNH)
}

assert_equals() {
    local expected="$1"
    local actual="$2"
    local message="$3"

    if [[ "$expected" == "$actual" ]]; then
        echo -e "${GREEN}✓${NC} $message"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}✗${NC} $message"
        echo "  Expected: $expected"
        echo "  Actual:   $actual"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

assert_file_exists() {
    local file="$1"
    local message="$2"

    if [[ -e "$file" ]]; then
        echo -e "${GREEN}✓${NC} $message"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}✗${NC} $message (file not found: $file)"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

assert_file_not_exists() {
    local file="$1"
    local message="$2"

    if [[ ! -e "$file" ]]; then
        echo -e "${GREEN}✓${NC} $message"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}✗${NC} $message (file exists: $file)"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

assert_file_contains() {
    local file="$1"
    local pattern="$2"
    local message="$3"

    if grep -q "$pattern" "$file" 2>/dev/null; then
        echo -e "${GREEN}✓${NC} $message"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}✗${NC} $message (pattern '$pattern' not found in $file)"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

#######################################
# UNIT TESTS
#######################################
echo "========================================"
echo "Running Unit Tests"
echo "========================================"
echo ""

# Source the script to access functions directly
source "$SCRIPT_UNDER_TEST"

reset_globals

# Test: detect_archive_type
echo "Testing detect_archive_type()..."
assert_equals "zip" "$(detect_archive_type 'client.zip')" "Detects .zip"
assert_equals "tar.gz" "$(detect_archive_type 'client.tar.gz')" "Detects .tar.gz"
assert_equals "tar.gz" "$(detect_archive_type 'client.tgz')" "Detects .tgz"
assert_equals "tar" "$(detect_archive_type 'client.tar')" "Detects .tar"
assert_equals "unknown" "$(detect_archive_type 'client.rar')" "Returns unknown for unsupported"
echo ""

# Test: validate_args (missing instance dir)
echo "Testing validate_args() - missing instance dir..."
reset_globals
INSTANCE_DIR=""
NEW_INSTANCE_NAME="Test"
SKIP_DOWNLOAD=true
NEW_CLIENT_ARCHIVE="/tmp/test.zip"
if validate_args 2>/dev/null; then
    echo -e "${RED}✗${NC} Should fail when instance dir is missing"
    TESTS_FAILED=$((TESTS_FAILED + 1))
else
    echo -e "${GREEN}✓${NC} Correctly fails when instance dir is missing"
    TESTS_PASSED=$((TESTS_PASSED + 1))
fi
echo ""

# Test: validate_args (missing name)
echo "Testing validate_args() - missing instance name..."
reset_globals
INSTANCE_DIR="$TEST_DIR/mock-instance"
mkdir -p "$INSTANCE_DIR/.minecraft"
NEW_INSTANCE_NAME=""
SKIP_DOWNLOAD=true
NEW_CLIENT_ARCHIVE="/tmp/test.zip"
if validate_args 2>/dev/null; then
    echo -e "${RED}✗${NC} Should fail when instance name is missing"
    TESTS_FAILED=$((TESTS_FAILED + 1))
else
    echo -e "${GREEN}✓${NC} Correctly fails when instance name is missing"
    TESTS_PASSED=$((TESTS_PASSED + 1))
fi
echo ""

# Test: validate_args (invalid instance - no .minecraft)
echo "Testing validate_args() - invalid instance..."
reset_globals
INSTANCE_DIR="$TEST_DIR/invalid-instance"
mkdir -p "$INSTANCE_DIR"  # No .minecraft folder
NEW_INSTANCE_NAME="Test"
SKIP_DOWNLOAD=true
NEW_CLIENT_ARCHIVE="/tmp/test.zip"
if validate_args 2>/dev/null; then
    echo -e "${RED}✗${NC} Should fail for invalid instance"
    TESTS_FAILED=$((TESTS_FAILED + 1))
else
    echo -e "${GREEN}✓${NC} Correctly fails for invalid instance (no .minecraft)"
    TESTS_PASSED=$((TESTS_PASSED + 1))
fi
echo ""

#######################################
# INTEGRATION TESTS
#######################################
echo "========================================"
echo "Running Integration Tests"
echo "========================================"
echo ""

# Test: Dry-run mode doesn't modify filesystem
echo "Testing dry-run mode..."
DRY_RUN_INSTANCE="$TEST_DIR/dry-run-instance"
DRY_RUN_NEW="$TEST_DIR/dry-run-new"
DRY_RUN_ARCHIVE="$TEST_DIR/dry-run-archive.tar.gz"

setup_mock_instance "$DRY_RUN_INSTANCE"
setup_mock_client_archive "$TEST_DIR/dry-run-archive-content" "$DRY_RUN_ARCHIVE"

"$SCRIPT_UNDER_TEST" \
    --instance "$DRY_RUN_INSTANCE" \
    --name "dry-run-new" \
    --file "$DRY_RUN_ARCHIVE" \
    --prism-dir "$TEST_DIR" \
    --dry-run \
    --yes > /dev/null 2>&1

assert_file_exists "$DRY_RUN_INSTANCE/.minecraft/config/test.cfg" "Dry-run preserves original config"
assert_file_exists "$DRY_RUN_INSTANCE/.minecraft/mods/test-mod.jar" "Dry-run preserves original mods"
assert_file_not_exists "$DRY_RUN_NEW" "Dry-run doesn't create new instance"
echo ""

# Test: Full update
echo "Testing full update..."
FULL_INSTANCE="$TEST_DIR/full-instance"
FULL_NEW="$TEST_DIR/full-new"
FULL_ARCHIVE="$TEST_DIR/full-archive.tar.gz"

setup_mock_instance "$FULL_INSTANCE"
setup_mock_client_archive "$TEST_DIR/full-archive-content" "$FULL_ARCHIVE"

"$SCRIPT_UNDER_TEST" \
    --instance "$FULL_INSTANCE" \
    --name "full-new" \
    --file "$FULL_ARCHIVE" \
    --prism-dir "$TEST_DIR" \
    --yes > /dev/null 2>&1

assert_file_exists "$FULL_NEW/.minecraft/config/new.cfg" "New config installed"
assert_file_exists "$FULL_NEW/.minecraft/mods/new-mod.jar" "New mods installed"
assert_file_exists "$FULL_NEW/.minecraft/serverutilities/data.json" "New serverutilities installed"
assert_file_not_exists "$FULL_NEW/.minecraft/config/test.cfg" "Old config removed"
assert_file_not_exists "$FULL_NEW/.minecraft/scripts" "Old scripts removed"
echo ""

# Test: Java 17 mode
echo "Testing Java 17 mode..."
JAVA17_INSTANCE="$TEST_DIR/java17-instance"
JAVA17_NEW="$TEST_DIR/java17-new"
JAVA17_ARCHIVE="$TEST_DIR/java17-archive.tar.gz"

setup_mock_instance "$JAVA17_INSTANCE"
setup_mock_client_archive "$TEST_DIR/java17-archive-content" "$JAVA17_ARCHIVE"

"$SCRIPT_UNDER_TEST" \
    --instance "$JAVA17_INSTANCE" \
    --name "java17-new" \
    --file "$JAVA17_ARCHIVE" \
    --prism-dir "$TEST_DIR" \
    --java17 \
    --yes > /dev/null 2>&1

assert_file_exists "$JAVA17_NEW/mmc-pack.json" "mmc-pack.json installed"
assert_file_contains "$JAVA17_NEW/mmc-pack.json" "new" "mmc-pack.json has new content"
echo ""

# Test: Instance name updated
echo "Testing instance name update..."
assert_file_contains "$FULL_NEW/instance.cfg" "name=full-new" "Instance name updated in config"
echo ""

#######################################
# SUMMARY
#######################################
echo "========================================"
echo "Test Summary"
echo "========================================"
echo -e "${GREEN}Passed: $TESTS_PASSED${NC}"
echo -e "${RED}Failed: $TESTS_FAILED${NC}"
echo ""

if [[ $TESTS_FAILED -gt 0 ]]; then
    exit 1
fi
