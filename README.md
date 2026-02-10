# tmux-resurrect-claude-code

A [TPM](https://github.com/tmux-plugins/tpm) plugin that saves and restores Claude Code CLI sessions alongside [tmux-resurrect](https://github.com/tmux-plugins/tmux-resurrect).

## Overview

This plugin hooks into tmux-resurrect's save/restore system to automatically capture and resume Claude Code sessions. When you save your tmux environment, it detects which panes are running Claude Code and saves their session IDs. When you restore, it automatically resumes those sessions in the correct panes.

## Requirements

- [tmux](https://github.com/tmux/tmux) 2.1 or higher
- [tmux-resurrect](https://github.com/tmux-plugins/tmux-resurrect)
- [Claude Code CLI](https://claude.com/claude-code) installed and configured

## Installation

Add to your `~/.tmux.conf`:

```tmux
# Add tmux-resurrect first (required dependency)
set -g @plugin 'tmux-plugins/tmux-resurrect'

# Then add this plugin
set -g @plugin 'your-username/tmux-resurrect-claude-code'
```

Reload tmux configuration:
```bash
tmux source-file ~/.tmux.conf
```

Install plugins with TPM (prefix + I, default: `Ctrl-b I`)

## Usage

The plugin works automatically with tmux-resurrect:

- **Save**: `prefix + Ctrl-s` (tmux-resurrect default) — saves tmux layout AND Claude sessions
- **Restore**: `prefix + Ctrl-r` (tmux-resurrect default) — restores tmux layout AND Claude sessions

When you save, the plugin:
1. Detects all panes running `claude`
2. Extracts the session ID from the command line or finds the most recent session for that directory
3. Saves the mapping to `<resurrect-dir>/claude_sessions.txt`

When you restore (default `prompt` mode), the plugin:
1. Waits for tmux-resurrect to restore the layout
2. Pre-types `claude --resume <session-id>` in each pane that had a Claude session
3. You press **Enter** in each pane to confirm the resume

This default is intentionally safe — if Claude was running at save time but you exited it before shutdown, the command is ready but won't execute until you confirm.

### With tmux-continuum

This plugin works seamlessly with [tmux-continuum](https://github.com/tmux-plugins/tmux-continuum). Continuum calls tmux-resurrect's save/restore scripts which trigger our hooks automatically.

```tmux
# .tmux.conf — full setup with continuum
set -g @plugin 'tmux-plugins/tpm'
set -g @plugin 'tmux-plugins/tmux-resurrect'
set -g @plugin 'tmux-plugins/tmux-continuum'
set -g @plugin 'your-username/tmux-resurrect-claude-code'

# Continuum auto-save every 15 minutes (default)
set -g @continuum-save-interval '15'

# Continuum auto-restore on tmux server start
set -g @continuum-restore 'on'

# Suppress notifications during continuum auto-saves (optional)
set -g @resurrect-claude-notify 'off'
```

**How it works with continuum:**

| Event | What happens |
|-------|-------------|
| Continuum auto-save (every 15 min) | Claude session IDs are captured silently alongside the tmux layout |
| Continuum auto-restore (tmux server start) | Claude resume commands are pre-typed in the correct panes, waiting for Enter |
| Manual save (`prefix + Ctrl-s`) | Same as auto-save, with optional notification |
| Manual restore (`prefix + Ctrl-r`) | Same as auto-restore, with optional notification |

**Tip:** If you want fully automatic restore (no Enter required), set:
```tmux
set -g @resurrect-claude-restore-mode 'auto'
```

## Configuration

All configuration options have sensible defaults and are optional.

### Enable/Disable Plugin

```tmux
# Default: on
set -g @resurrect-claude-enabled "on"
```

### Auto-Resume Sessions

```tmux
# Automatically resume Claude sessions on restore
# Default: on
set -g @resurrect-claude-auto-resume "on"
```

Set to `"off"` to save sessions but not automatically resume them (you can manually resume later).

### Restore Mode

```tmux
# How to restore Claude sessions
# Default: "prompt"
set -g @resurrect-claude-restore-mode "prompt"
```

Options:
- `"prompt"` (default) — Pre-types the resume command in each pane. You press Enter to confirm. Safe if Claude was exited between the last save and shutdown.
- `"auto"` — Executes `claude --resume` immediately in each pane. Same behavior as tmux-resurrect's default process restoration.

### Save File Location

```tmux
# Filename for Claude session data (inside resurrect directory)
# Default: "claude_sessions.txt"
set -g @resurrect-claude-save-file "claude_sessions.txt"
```

### Disable Notifications

```tmux
# Show tmux messages when saving/restoring
# Default: on
set -g @resurrect-claude-notify "on"
```

## How It Works

### Session Detection

The plugin detects Claude Code sessions by:

1. **Process Detection**: Walks the process tree to find `claude` processes (handles shell → claude and shell → node → claude cases)
2. **Session ID Extraction**:
   - First tries to extract from command line arguments (`--resume <uuid>`, `--session-id <uuid>`, `-r <uuid>`)
   - Falls back to finding the most recent `.jsonl` file in `~/.claude/projects/<slug>/`
3. **Path Slugification**: Converts `/mnt/d/repo` to `-mnt-d-repo` (Claude's path sanitization format)

### Hook Integration

The plugin chains onto tmux-resurrect's hooks:
- `@resurrect-hook-post-save-all` - Called after tmux-resurrect saves the layout
- `@resurrect-hook-post-restore-all` - Called after tmux-resurrect restores the layout

Multiple plugins can chain onto these hooks; the plugin preserves existing hooks.

### Save Format

Session data is saved in `<resurrect-dir>/claude_sessions.txt` with format:
```
session_name:window_index.pane_index|/working/directory|session-uuid
```

Example:
```
main:0.0|/mnt/d/repo/my-project|a1b2c3d4-e5f6-7890-abcd-ef1234567890
main:1.2|/home/user/another-project|f1e2d3c4-b5a6-9780-dcba-fe0987654321
```

## Troubleshooting

### Sessions not saving

1. Check the plugin is enabled: `tmux show-options -g | grep resurrect-claude`
2. Verify `claude` is in PATH: `which claude`
3. Check the save file exists: `ls ~/.local/share/tmux/resurrect/claude_sessions.txt`

### Sessions not restoring

1. Check auto-resume is enabled: `tmux show-option -gv @resurrect-claude-auto-resume`
2. Verify session files still exist in `~/.claude/projects/`
3. Check tmux messages for errors: `tmux show-messages`

### Wrong session resumes

The plugin uses the session ID from the command line. If you started Claude without `--resume`, it will use the most recent session for that directory. To ensure correct session mapping, always start Claude with an explicit session ID:

```bash
claude --resume <uuid>
```

## License

MIT

## Contributing

Contributions welcome! Please open an issue or pull request.

## Credits

Inspired by [tmux-resurrect](https://github.com/tmux-plugins/tmux-resurrect) and designed for the [Claude Code CLI](https://claude.com/claude-code).
