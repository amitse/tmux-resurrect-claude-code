# Claude Code resurrect plugin - Claude-specific helpers

CLAUDE_DIR="$HOME/.claude"
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

	# Check if the pane process itself is claude
	local cmd
	cmd=$(ps -p "$pane_pid" -o comm= 2>/dev/null)
	if [ "$cmd" = "claude" ]; then
		echo "$pane_pid"
		return 0
	fi

	# Walk direct children
	local child child_cmd
	for child in $(ps --ppid "$pane_pid" -o pid= 2>/dev/null); do
		child_cmd=$(ps -p "$child" -o comm= 2>/dev/null)
		if [ "$child_cmd" = "claude" ]; then
			echo "$child"
			return 0
		fi
	done

	# Walk grandchildren (shell → node → claude, or shell → wrapper → claude)
	for child in $(ps --ppid "$pane_pid" -o pid= 2>/dev/null); do
		local grandchild grandchild_cmd
		for grandchild in $(ps --ppid "$child" -o pid= 2>/dev/null); do
			grandchild_cmd=$(ps -p "$grandchild" -o comm= 2>/dev/null)
			if [ "$grandchild_cmd" = "claude" ]; then
				echo "$grandchild"
				return 0
			fi
		done
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
		local recent_file
		recent_file=$(ls -t "$project_path"/*.jsonl 2>/dev/null | head -1)
		if [ -n "$recent_file" ] && [ -f "$recent_file" ]; then
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
	local found
	found=$(find "$CLAUDE_PROJECTS_DIR" -name "${session_id}.jsonl" -type f 2>/dev/null | head -1)
	[ -n "$found" ] && [ -f "$found" ]
}
