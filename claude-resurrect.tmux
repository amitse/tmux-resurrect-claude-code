#!/usr/bin/env bash

# tmux-resurrect-claude-code
# TPM plugin that saves and restores Claude Code sessions alongside tmux-resurrect.

CURRENT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

source "$CURRENT_DIR/scripts/variables.sh"
source "$CURRENT_DIR/scripts/helpers.sh"

# Register our save script as a post-save hook for tmux-resurrect
set_save_hook() {
	local save_script="$CURRENT_DIR/scripts/save.sh"
	local existing_hook
	existing_hook=$(get_tmux_option "@resurrect-hook-post-save-all" "")

	# Don't add if already present (idempotent)
	if [[ "$existing_hook" == *"$save_script"* ]]; then
		return 0
	fi

	if [ -n "$existing_hook" ]; then
		# Chain with existing hook
		tmux set-option -g "@resurrect-hook-post-save-all" "${existing_hook} ; ${save_script}"
	else
		tmux set-option -g "@resurrect-hook-post-save-all" "$save_script"
	fi
}

# Register our restore script as a post-restore hook for tmux-resurrect
set_restore_hook() {
	local restore_script="$CURRENT_DIR/scripts/restore.sh"
	local existing_hook
	existing_hook=$(get_tmux_option "@resurrect-hook-post-restore-all" "")

	# Don't add if already present (idempotent)
	if [[ "$existing_hook" == *"$restore_script"* ]]; then
		return 0
	fi

	if [ -n "$existing_hook" ]; then
		# Chain with existing hook
		tmux set-option -g "@resurrect-hook-post-restore-all" "${existing_hook} ; ${restore_script}"
	else
		tmux set-option -g "@resurrect-hook-post-restore-all" "$restore_script"
	fi
}

# Expose our script paths so other plugins can invoke them
set_script_paths() {
	tmux set-option -gq "@resurrect-claude-save-script-path" "$CURRENT_DIR/scripts/save.sh"
	tmux set-option -gq "@resurrect-claude-restore-script-path" "$CURRENT_DIR/scripts/restore.sh"
}

main() {
	if ! plugin_enabled; then
		return 0
	fi

	set_save_hook
	set_restore_hook
	set_script_paths
}

main
