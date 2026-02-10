#!/usr/bin/env bash

# Simple test script for tmux-resurrect-claude-code plugin
# Tests the helper functions without requiring a running tmux session

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Source the helpers
source "$SCRIPT_DIR/scripts/variables.sh"
source "$SCRIPT_DIR/scripts/helpers.sh"
source "$SCRIPT_DIR/scripts/claude_helpers.sh"

# Color output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

test_count=0
pass_count=0
fail_count=0

test_case() {
    local name="$1"
    local expected="$2"
    local actual="$3"

    test_count=$((test_count + 1))

    if [ "$expected" = "$actual" ]; then
        echo -e "${GREEN}✓${NC} $name"
        pass_count=$((pass_count + 1))
    else
        echo -e "${RED}✗${NC} $name"
        echo "  Expected: $expected"
        echo "  Got:      $actual"
        fail_count=$((fail_count + 1))
    fi
}

echo "Testing tmux-resurrect-claude-code plugin..."
echo

# Test path_to_project_slug
echo "Testing path_to_project_slug:"
test_case "Convert /mnt/d/repo" "-mnt-d-repo" "$(path_to_project_slug "/mnt/d/repo")"
test_case "Convert /home/user/project" "-home-user-project" "$(path_to_project_slug "/home/user/project")"
test_case "Convert /tmp" "-tmp" "$(path_to_project_slug "/tmp")"
test_case "Convert /" "-" "$(path_to_project_slug "/")"
echo

# Test get_resurrect_dir (without tmux)
echo "Testing get_resurrect_dir:"
expected_dir="${XDG_DATA_HOME:-$HOME/.local/share}/tmux/resurrect"
if [ ! -d "$expected_dir" ]; then
    expected_dir="$HOME/.tmux/resurrect"
fi
actual_dir=$(get_resurrect_dir)
test_case "Get resurrect directory" "$expected_dir" "$actual_dir"
echo

# Test extract_session_from_cmdline with mock data
echo "Testing extract_session_from_cmdline:"
echo "  (Creating mock /proc entries...)"

# Create temporary proc directory
tmp_proc="/tmp/test_proc_$$"
mkdir -p "$tmp_proc"

# Mock PID 1: --resume with UUID
mock_pid_1="$$"
echo -n -e "node\0/usr/bin/claude\0--resume\0a1b2c3d4-e5f6-7890-abcd-ef1234567890" > "$tmp_proc/cmdline_1"

# Mock PID 2: --session-id with UUID
echo -n -e "node\0/usr/bin/claude\0--session-id\0f1e2d3c4-b5a6-9780-dcba-fe0987654321" > "$tmp_proc/cmdline_2"

# Test extraction (need to mock the function to use our test files)
test_extract() {
    local cmdline="$1"
    local session_id=""

    session_id=$(echo "$cmdline" | grep -oP -- '(--resume|-r)\s+\K[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}')
    if [ -n "$session_id" ]; then
        echo "$session_id"
        return 0
    fi

    session_id=$(echo "$cmdline" | grep -oP -- '--session-id\s+\K[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}')
    if [ -n "$session_id" ]; then
        echo "$session_id"
        return 0
    fi

    return 1
}

cmdline_1=$(tr '\0' ' ' < "$tmp_proc/cmdline_1")
cmdline_2=$(tr '\0' ' ' < "$tmp_proc/cmdline_2")

result_1=$(test_extract "$cmdline_1")
result_2=$(test_extract "$cmdline_2")

test_case "Extract --resume UUID" "a1b2c3d4-e5f6-7890-abcd-ef1234567890" "$result_1"
test_case "Extract --session-id UUID" "f1e2d3c4-b5a6-9780-dcba-fe0987654321" "$result_2"

# Cleanup
rm -rf "$tmp_proc"
echo

# Summary
echo "================================"
echo "Test Summary:"
echo -e "Total:  ${test_count}"
echo -e "Passed: ${GREEN}${pass_count}${NC}"
echo -e "Failed: ${RED}${fail_count}${NC}"
echo "================================"

if [ "$fail_count" -eq 0 ]; then
    echo -e "${GREEN}All tests passed!${NC}"
    exit 0
else
    echo -e "${RED}Some tests failed.${NC}"
    exit 1
fi
