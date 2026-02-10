#!/usr/bin/env bash

# Claude Code resurrect plugin - restore hook
# Called by tmux-resurrect via @resurrect-hook-post-restore-all
# Reads the sidecar file and resumes Claude sessions in the correct panes.

CURRENT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

source "$CURRENT_DIR/variables.sh"
source "$CURRENT_DIR/helpers.sh"
source "$CURRENT_DIR/claude_helpers.sh"

restore_claude_sessions() {
	local save_file
	save_file=$(get_claude_save_file)

	if [ ! -f "$save_file" ]; then
		return 0
	fi

	local count=0
	local mode
	mode=$(get_restore_mode)

	# Read each saved session
	# Format: session_name:window_index:pane_index|cwd|session_uuid
	while IFS='|' read -r pane_target cwd session_id; do
		[ -z "$pane_target" ] && continue
		[ -z "$session_id" ] && continue

		# Verify the session file still exists
		if ! verify_session_exists "$session_id"; then
			continue
		fi

		# Check if the target pane exists
		if ! tmux has-session -t "${pane_target%%:*}" 2>/dev/null; then
			continue
		fi

		# Verify the pane exists
		if ! tmux display-message -t "$pane_target" -p "#{pane_id}" >/dev/null 2>&1; then
			continue
		fi

		# Check that the pane is not already running claude
		local current_pid
		current_pid=$(tmux display-message -t "$pane_target" -p "#{pane_pid}")
		if [ -n "$current_pid" ]; then
			local existing_claude
			existing_claude=$(get_claude_pid_from_pane "$current_pid")
			if [ -n "$existing_claude" ]; then
				# Claude already running in this pane, skip
				continue
			fi
		fi

		# Build the resume command
		local resume_cmd="cd '${cwd}' && claude --resume '${session_id}'"

		if [ "$mode" = "auto" ]; then
			# Execute immediately
			tmux send-keys -t "$pane_target" "$resume_cmd" C-m
		else
			# "prompt" mode (default): pre-type the command, user hits Enter to confirm
			tmux send-keys -t "$pane_target" "$resume_cmd"
		fi
		count=$((count + 1))

	done < "$save_file"

	if [ "$count" -gt 0 ]; then
		if [ "$mode" = "auto" ]; then
			display_message "Claude: resumed $count session(s)"
		else
			display_message "Claude: $count session(s) ready — press Enter in each pane to resume"
		fi
	fi
}

main() {
	if ! plugin_enabled; then
		return 0
	fi

	if ! auto_resume_enabled; then
		return 0
	fi

	# Check if claude CLI exists
	if ! command -v claude >/dev/null 2>&1; then
		display_message "Claude: 'claude' command not found, skipping restore"
		return 0
	fi

	restore_claude_sessions
}

main
