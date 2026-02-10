#!/usr/bin/env bash

# Claude Code resurrect plugin - variable definitions

# Option names
claude_enabled_option="@resurrect-claude-enabled"
claude_auto_resume_option="@resurrect-claude-auto-resume"
claude_restore_mode_option="@resurrect-claude-restore-mode"
claude_save_file_option="@resurrect-claude-save-file"
claude_notify_option="@resurrect-claude-notify"
claude_dir_option="@resurrect-claude-dir"

# Defaults
default_claude_enabled="on"
default_claude_auto_resume="on"
# "prompt" = pre-type command, user hits Enter to confirm
# "auto"   = execute immediately (same as tmux-resurrect default for processes)
default_claude_restore_mode="prompt"
default_claude_save_file="claude_sessions.txt"
default_claude_notify="on"

# Resurrect integration
resurrect_dir_option="@resurrect-dir"
default_resurrect_dir="${XDG_DATA_HOME:-$HOME/.local/share}/tmux/resurrect"
# Fallback for older setups
fallback_resurrect_dir="$HOME/.tmux/resurrect"
