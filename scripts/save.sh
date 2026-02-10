#!/usr/bin/env bash

# Claude Code resurrect plugin - save hook
# Called by tmux-resurrect via @resurrect-hook-post-save-all
# Detects Claude Code sessions in all panes and writes a sidecar file.

CURRENT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

source "$CURRENT_DIR/variables.sh"
source "$CURRENT_DIR/helpers.sh"
source "$CURRENT_DIR/claude_helpers.sh"

save_claude_sessions() {
	local save_file
	save_file=$(get_claude_save_file)
	local save_dir
	save_dir=$(dirname "$save_file")

	# Ensure the directory exists
	mkdir -p "$save_dir"

	# Temp file for atomic write
	local tmp_file="${save_file}.tmp.$$"
	trap 'rm -f "$tmp_file"' EXIT INT TERM
	: > "$tmp_file"

	local count=0

	# Iterate all panes across all sessions
	# Format: session_name:window_index:pane_index pane_pid pane_current_path
	while IFS=$'\t' read -r pane_target pane_pid pane_cwd; do
		[ -z "$pane_pid" ] && continue

		local session_info
		session_info=$(get_claude_session_for_pane "$pane_pid" "$pane_cwd")
		if [ $? -eq 0 ] && [ -n "$session_info" ]; then
			# Write: pane_target|cwd|session_uuid
			echo "${pane_target}|${session_info}" >> "$tmp_file"
			count=$((count + 1))
		fi
	done < <(tmux list-panes -a -F "#{session_name}:#{window_index}:#{pane_index}	#{pane_pid}	#{pane_current_path}")

	# Atomic replace
	mv "$tmp_file" "$save_file"

	if [ "$count" -gt 0 ]; then
		display_message "Claude: saved $count session(s)"
	fi
}

main() {
	if ! plugin_enabled; then
		return 0
	fi

	# Check if claude CLI exists on the system
	if ! command -v claude >/dev/null 2>&1; then
		return 0
	fi

	save_claude_sessions
}

main
