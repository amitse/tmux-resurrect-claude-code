# Claude Code resurrect plugin - common helpers

get_tmux_option() {
	local option="$1"
	local default_value="$2"
	local option_value
	option_value=$(tmux show-option -gqv "$option")
	if [ -z "$option_value" ]; then
		echo "$default_value"
	else
		echo "$option_value"
	fi
}

# Get the resurrect directory (where save files live)
get_resurrect_dir() {
	local dir
	dir=$(get_tmux_option "$resurrect_dir_option" "")
	if [ -z "$dir" ]; then
		# Try XDG default first, then fallback
		if [ -d "$default_resurrect_dir" ]; then
			dir="$default_resurrect_dir"
		elif [ -d "$fallback_resurrect_dir" ]; then
			dir="$fallback_resurrect_dir"
		else
			dir="$default_resurrect_dir"
		fi
	fi
	# Expand ~ and env vars
	dir="${dir/#\~/$HOME}"
	echo "$dir"
}

# Get the sidecar file path for Claude session data
get_claude_save_file() {
	local resurrect_dir
	resurrect_dir=$(get_resurrect_dir)
	local filename
	filename=$(get_tmux_option "$claude_save_file_option" "$default_claude_save_file")
	echo "${resurrect_dir}/${filename}"
}

display_message() {
	local message="$1"
	local notify
	notify=$(get_tmux_option "$claude_notify_option" "$default_claude_notify")
	if [ "$notify" = "on" ]; then
		tmux display-message "$message"
	fi
}

plugin_enabled() {
	local enabled
	enabled=$(get_tmux_option "$claude_enabled_option" "$default_claude_enabled")
	[ "$enabled" = "on" ]
}

auto_resume_enabled() {
	local enabled
	enabled=$(get_tmux_option "$claude_auto_resume_option" "$default_claude_auto_resume")
	[ "$enabled" = "on" ]
}

# Returns "prompt" or "auto"
get_restore_mode() {
	get_tmux_option "$claude_restore_mode_option" "$default_claude_restore_mode"
}
