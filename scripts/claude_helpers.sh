#!/usr/bin/env bash

# Claude Code resurrect plugin - Claude-specific helpers

# Resolve Claude Code's data directory (XDG compliant)
# Priority: @resurrect-claude-dir option > XDG_CONFIG_HOME > ~/.claude
resolve_claude_dir() {
	# 1. User override via tmux option
	local custom_dir
	custom_dir=$(get_tmux_option "$claude_dir_option" "")
	if [ -n "$custom_dir" ]; then
		custom_dir="${custom_dir/#\~/$HOME}"
		echo "$custom_dir"
		return
	fi

	# 2. XDG_CONFIG_HOME/claude (XDG standard)
	local xdg_dir="${XDG_CONFIG_HOME:-$HOME/.config}/claude"
	if [ -d "$xdg_dir/projects" ]; then
		echo "$xdg_dir"
		return
	fi

	# 3. ~/.claude (legacy, may be symlink to XDG location)
	if [ -d "$HOME/.claude/projects" ]; then
		echo "$HOME/.claude"
		return
	fi

	# 4. Default to XDG path even if it doesn't exist yet
	echo "$xdg_dir"
}

CLAUDE_DIR="$(resolve_claude_dir)"
CLAUDE_PROJECTS_DIR="$CLAUDE_DIR/projects"

# Convert a working directory path to Claude's project directory name
# /mnt/d/repo/foo → -mnt-d-repo-foo
path_to_project_slug() {
	local path="$1"
	echo "$path" | sed 's|/|-|g'
}

# Find the Claude process PID for a given tmux pane PID
# The pane PID is usually the shell; claude runs as a child process
get_claude_pid_from_pane() {
	local pane_pid="$1"
	local max_depth=4
	local pids_at_level=("$pane_pid")

	for (( depth=0; depth<=max_depth; depth++ )); do
		for pid in "${pids_at_level[@]}"; do
			local cmd
			cmd=$(ps -p "$pid" -o comm= 2>/dev/null) || continue
			if [ "$cmd" = "claude" ]; then
				echo "$pid"
				return 0
			fi
		done
		local next_level=()
		for pid in "${pids_at_level[@]}"; do
			while read -r child; do
				[ -n "$child" ] && next_level+=("$child")
			done < <(ps --ppid "$pid" -o pid= 2>/dev/null)
		done
		[ ${#next_level[@]} -eq 0 ] && break
		pids_at_level=("${next_level[@]}")
	done
	return 1
}

# Extract session UUID from a claude process's command line
# Looks for --resume <uuid> or --session-id <uuid> or -r <uuid>
extract_session_from_cmdline() {
	local pid="$1"
	local cmdline

	# Read from /proc for accuracy (ps truncates)
	if [ -f "/proc/$pid/cmdline" ]; then
		cmdline=$(tr '\0' ' ' < "/proc/$pid/cmdline")
	else
		cmdline=$(ps -p "$pid" -o args= 2>/dev/null)
	fi

	[ -z "$cmdline" ] && return 1

	local session_id=""

	# Try --resume <uuid>
	session_id=$(echo "$cmdline" | grep -oP -- '(--resume|-r)\s+\K[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}')
	if [ -n "$session_id" ]; then
		echo "$session_id"
		return 0
	fi

	# Try --session-id <uuid>
	session_id=$(echo "$cmdline" | grep -oP -- '--session-id\s+\K[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}')
	if [ -n "$session_id" ]; then
		echo "$session_id"
		return 0
	fi

	return 1
}

# Get the most recently modified session file for a working directory
get_recent_session_for_dir() {
	local dir="$1"
	local slug
	slug=$(path_to_project_slug "$dir")
	local project_path="$CLAUDE_PROJECTS_DIR/${slug}"

	if [ -d "$project_path" ]; then
		local recent_file=""
		local recent_time=0
		for f in "$project_path"/*.jsonl; do
			[ -f "$f" ] || continue
			local mtime
			mtime=$(stat -c %Y "$f" 2>/dev/null) || continue
			if [ "$mtime" -gt "$recent_time" ]; then
				recent_time="$mtime"
				recent_file="$f"
			fi
		done
		if [ -n "$recent_file" ]; then
			basename "$recent_file" .jsonl
			return 0
		fi
	fi
	return 1
}

# Get Claude session info for a tmux pane
# Output: <cwd>|<session_uuid>  (or empty if not a claude pane)
get_claude_session_for_pane() {
	local pane_pid="$1"
	local pane_cwd="$2"

	# Find the claude process
	local claude_pid
	claude_pid=$(get_claude_pid_from_pane "$pane_pid")
	if [ -z "$claude_pid" ]; then
		return 1
	fi

	# Try to extract session ID from command line
	local session_id
	session_id=$(extract_session_from_cmdline "$claude_pid")

	# Fallback: find most recent session for the pane's working directory
	if [ -z "$session_id" ]; then
		session_id=$(get_recent_session_for_dir "$pane_cwd")
	fi

	if [ -n "$session_id" ]; then
		echo "${pane_cwd}|${session_id}"
		return 0
	fi

	return 1
}

# Verify a Claude session file exists
verify_session_exists() {
	local session_id="$1"
	local cwd="${2:-}"

	if [ -n "$cwd" ]; then
		local slug
		slug=$(path_to_project_slug "$cwd")
		local expected_path="$CLAUDE_PROJECTS_DIR/${slug}/${session_id}.jsonl"
		[ -f "$expected_path" ] && return 0
	fi

	# Fallback to find if cwd not provided or direct check failed
	local found
	found=$(find "$CLAUDE_PROJECTS_DIR" -name "${session_id}.jsonl" -type f 2>/dev/null | head -1)
	[ -n "$found" ] && [ -f "$found" ]
}
