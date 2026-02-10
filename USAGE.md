# Usage Guide

This guide provides detailed usage examples for the `tmux-resurrect-claude-code` plugin.

## Basic Workflow

### 1. Start Claude Code in tmux

Open tmux and start Claude Code in one or more panes:

```bash
# In tmux pane 1
cd /path/to/project1
claude

# In tmux pane 2
cd /path/to/project2
claude --resume a1b2c3d4-e5f6-7890-abcd-ef1234567890
```

### 2. Save Your Session

Use tmux-resurrect's save command:
```
prefix + Ctrl-s
```

You should see messages:
```
Tmux environment saved!
Claude Code: saved 2 session(s)
```

The plugin saves:
- Tmux layout to `~/.local/share/tmux/resurrect/last`
- Claude sessions to `~/.local/share/tmux/resurrect/claude_sessions.txt`

### 3. Exit Everything

Close tmux entirely:
```bash
tmux kill-server
```

### 4. Restore Your Session

Start tmux and restore:
```bash
tmux
# Then: prefix + Ctrl-r
```

You should see:
```
Tmux restore complete!
Claude Code: restored 2 session(s)
```

Claude Code will automatically resume in each pane where it was running.

## Advanced Configuration

### Conditional Auto-Resume

You might want to save sessions but not always auto-resume them. This is useful for:
- Reviewing sessions before resuming
- Selectively resuming only certain projects
- Saving state without immediately loading it

```tmux
# Save sessions but don't auto-resume
set -g @resurrect-claude-auto-resume "off"
```

To manually resume a saved session:
1. Restore tmux layout: `prefix + Ctrl-r`
2. Check saved sessions: `cat ~/.local/share/tmux/resurrect/claude_sessions.txt`
3. Manually run: `claude --resume <session-id>` in the appropriate panes

### Strategy Selection

#### Session-ID Strategy (Default)

Uses exact session UUIDs:

```tmux
set -g @resurrect-claude-strategy "session-id"
```

**How it works:**
1. Detects Claude running with `--resume <uuid>` or `--session-id <uuid>`
2. Falls back to most recent `.jsonl` in project directory
3. On restore: `claude --resume <uuid>`

**Best for:**
- Precise session tracking
- Multiple concurrent projects
- Long-term session preservation

#### Continue Strategy

Uses Claude's `--continue` flag:

```tmux
set -g @resurrect-claude-strategy "continue"
```

**How it works:**
1. Saves the working directory only
2. On restore: changes to directory and runs `claude --continue`
3. Claude automatically picks the most recent session

**Best for:**
- Simpler session management
- Single project per directory
- Always wanting the latest session

### Custom Save Location

Store Claude session data in a custom location:

```tmux
# Custom resurrect directory
set -g @resurrect-dir "$HOME/my-tmux-backups"

# Custom Claude sessions filename
set -g @resurrect-claude-save-file "my_claude_sessions.txt"
```

The full path will be: `$HOME/my-tmux-backups/my_claude_sessions.txt`

### Silent Mode

Disable all notifications:

```tmux
set -g @resurrect-claude-notify "off"
```

Useful for:
- Automated scripts
- Minimal UI preferences
- Background saves/restores

## Session File Format

The `claude_sessions.txt` file uses this format:

```
<pane-address>|<working-directory>|<session-uuid>
```

Example:
```
main:0.0|/mnt/d/repo/my-project|a1b2c3d4-e5f6-7890-abcd-ef1234567890
main:1.2|/home/user/another-project|f1e2d3c4-b5a6-9780-dcba-fe0987654321
work:0.1|/home/user/work/api|3c4d5e6f-7a8b-9c0d-1e2f-3a4b5c6d7e8f
```

Fields:
- `main:0.0` - Session name, window index, pane index
- `/mnt/d/repo/my-project` - Working directory
- `a1b2c3d4-...` - Claude session UUID

## Integration with Other Plugins

### tmux-continuum

For automatic saves, combine with [tmux-continuum](https://github.com/tmux-plugins/tmux-continuum):

```tmux
set -g @plugin 'tmux-plugins/tmux-resurrect'
set -g @plugin 'tmux-plugins/tmux-continuum'
set -g @plugin 'your-username/tmux-resurrect-claude-code'

# Auto-save every 15 minutes
set -g @continuum-save-interval '15'

# Auto-restore on tmux start
set -g @continuum-restore 'on'
```

This will automatically:
1. Save tmux + Claude sessions every 15 minutes
2. Restore everything when tmux starts

### Custom Hooks

If you have other plugins using the same hooks, they will chain properly:

```tmux
# Your custom save hook
set -g @resurrect-hook-post-save-all "/path/to/my-script.sh"

# Load the Claude plugin - it will chain after your hook
set -g @plugin 'your-username/tmux-resurrect-claude-code'

# Final hook chain: your-script.sh ; claude-save.sh
```

## Troubleshooting

### Check Plugin Status

```bash
# Is plugin enabled?
tmux show-option -gv @resurrect-claude-enabled

# Is auto-resume enabled?
tmux show-option -gv @resurrect-claude-auto-resume

# What strategy is used?
tmux show-option -gv @resurrect-claude-strategy

# Where are sessions saved?
tmux show-option -gv @resurrect-dir
```

### View Saved Sessions

```bash
# Default location
cat ~/.local/share/tmux/resurrect/claude_sessions.txt

# Or check configured location
resurrect_dir=$(tmux show-option -gv @resurrect-dir)
cat "$resurrect_dir/claude_sessions.txt"
```

### Debug Session Detection

Check if Claude is running and detectable:

```bash
# Get your pane PID
tmux display-message -p "#{pane_pid}"

# Check process tree
ps --ppid <pane-pid> -o pid,comm

# Check if claude is there
pgrep -P <pane-pid> -l
```

### Verify Session Files Exist

```bash
# List all Claude projects
ls -la ~/.claude/projects/

# Check specific project (e.g., /mnt/d/repo)
ls -la ~/.claude/projects/-mnt-d-repo/

# View session file
cat ~/.claude/projects/-mnt-d-repo/<uuid>.jsonl | jq
```

### Manual Session Mapping

If automatic detection fails, manually create the mapping:

```bash
# Get pane address
tmux display-message -p "#{session_name}:#{window_index}.#{pane_index}"

# Find your session UUID
ls -t ~/.claude/projects/-mnt-d-repo/*.jsonl | head -1

# Manually add to save file
echo "main:0.0|/mnt/d/repo|<uuid>" >> ~/.local/share/tmux/resurrect/claude_sessions.txt
```

## Best Practices

### 1. Use Explicit Session IDs

Always start Claude with an explicit session when you want reliable restoration:

```bash
# Good - explicit session
claude --resume a1b2c3d4-e5f6-7890-abcd-ef1234567890

# Okay - will use most recent session
claude
claude --continue
```

### 2. Consistent Working Directories

Keep your tmux panes in the correct working directories:

```bash
# Set the pane's working directory
cd /path/to/project

# Then start Claude
claude
```

This ensures fallback session detection works correctly.

### 3. Regular Saves

Save your session regularly, especially before:
- System updates
- Long-running operations
- Switching between projects

```bash
# Quick save
prefix + Ctrl-s
```

### 4. Test Restore Before Relying On It

Test the restore process with non-critical sessions first:

```bash
# 1. Start test session
cd /tmp/test-project
claude

# 2. Save
prefix + Ctrl-s

# 3. Exit tmux
exit

# 4. Restore
tmux
prefix + Ctrl-r

# 5. Verify Claude resumed correctly
```

### 5. Backup Session Files

The session files in `~/.claude/projects/` contain your chat history. Back them up:

```bash
# Backup all Claude sessions
tar -czf claude-sessions-backup.tar.gz ~/.claude/projects/

# Restore from backup
tar -xzf claude-sessions-backup.tar.gz -C ~/
```

## Examples

### Example 1: Multi-Project Development

Setup:
```bash
# Window 1: Backend API
cd ~/projects/backend
claude

# Window 2: Frontend
cd ~/projects/frontend
claude

# Window 3: Documentation
cd ~/projects/docs
claude
```

Save and restore:
```
prefix + Ctrl-s  # Save all three Claude sessions
prefix + Ctrl-r  # Restore all three Claude sessions
```

### Example 2: Selective Resume

Setup:
```tmux
# Disable auto-resume
set -g @resurrect-claude-auto-resume "off"
```

Workflow:
```bash
# 1. Save sessions
prefix + Ctrl-s

# 2. Restore layout only
prefix + Ctrl-r

# 3. Check what was saved
cat ~/.local/share/tmux/resurrect/claude_sessions.txt

# 4. Manually resume the sessions you want
claude --resume <uuid-for-backend>
claude --resume <uuid-for-frontend>
# (skip documentation pane)
```

### Example 3: Automated Backups

Combine with tmux-continuum for hands-free operation:

```tmux
# .tmux.conf
set -g @plugin 'tmux-plugins/tmux-resurrect'
set -g @plugin 'tmux-plugins/tmux-continuum'
set -g @plugin 'your-username/tmux-resurrect-claude-code'

set -g @continuum-save-interval '10'
set -g @continuum-restore 'on'
set -g @resurrect-capture-pane-contents 'on'
```

Now your Claude sessions save every 10 minutes and restore automatically on tmux startup.

## Additional Resources

- [tmux-resurrect documentation](https://github.com/tmux-plugins/tmux-resurrect)
- [tmux-continuum documentation](https://github.com/tmux-plugins/tmux-continuum)
- [Claude Code CLI documentation](https://claude.com/claude-code)
- [TPM documentation](https://github.com/tmux-plugins/tpm)
