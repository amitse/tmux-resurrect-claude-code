# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Is

A TPM (Tmux Plugin Manager) plugin that saves and restores Claude Code CLI sessions alongside tmux-resurrect. When tmux-resurrect saves/restores a tmux environment, this plugin captures which panes are running `claude` and their session UUIDs, then resumes them on restore.

## Commands

```bash
# Run unit tests
./test_plugin.sh

# Static analysis (if shellcheck installed)
shellcheck scripts/*.sh claude-resurrect.tmux

# Syntax check all scripts
for f in scripts/*.sh claude-resurrect.tmux; do bash -n "$f"; done

# Test helper functions manually (outside tmux is fine)
source scripts/variables.sh && source scripts/helpers.sh && source scripts/claude_helpers.sh
path_to_project_slug "/mnt/d/repo/foo"   # → -mnt-d-repo-foo
```

No build step — pure bash scripts interpreted at runtime by tmux/TPM.

## Architecture

### Plugin Lifecycle

```
TPM loads plugin
  → claude-resurrect.tmux (entry point)
    → Chains save.sh onto @resurrect-hook-post-save-all
    → Chains restore.sh onto @resurrect-hook-post-restore-all

User saves (prefix + Ctrl-s)
  → tmux-resurrect saves layout
  → Fires post-save-all hook
    → save.sh iterates all panes, detects claude processes, writes sidecar

User restores (prefix + Ctrl-r)
  → tmux-resurrect restores layout
  → Fires post-restore-all hook
    → restore.sh reads sidecar, sends resume commands to matching panes
```

### Script Dependency Chain

```
claude-resurrect.tmux ─┬─ variables.sh (option names, defaults)
                       └─ helpers.sh (get_tmux_option, state dir, display)

save.sh ───┬─ variables.sh
           ├─ helpers.sh
           └─ claude_helpers.sh (process detection, session extraction)

restore.sh ┬─ variables.sh
           ├─ helpers.sh
           └─ claude_helpers.sh
```

`claude_helpers.sh` contains the core logic: BFS process tree walk (depth 4) to find `claude` PIDs, `/proc/cmdline` parsing for session UUIDs, and fallback to most-recent `.jsonl` file lookup.

### XDG Paths

| Purpose | XDG Variable | Default |
|---------|-------------|---------|
| Claude session data (read) | `$XDG_CONFIG_HOME` | `~/.config/claude/projects/` |
| Plugin state file (write) | `$XDG_STATE_HOME` | `~/.local/state/tmux/resurrect-claude-code/claude_sessions.txt` |
| Resurrect data (read) | `$XDG_DATA_HOME` | `~/.local/share/tmux/resurrect/` |

Resolution order for Claude dir: `@resurrect-claude-dir` option → `$XDG_CONFIG_HOME/claude` → `~/.claude` (legacy).

### Sidecar File Format

Written to `$XDG_STATE_HOME/tmux/resurrect-claude-code/claude_sessions.txt`:

```
session_name:window_index:pane_index|/working/directory|session-uuid
```

### Key Design Decisions

- **Hook chaining is idempotent** — checks if script path already present before appending, preventing duplicates on tmux config reload.
- **Default restore mode is "prompt"** — pre-types the resume command without pressing Enter. Safer than auto-execute when Claude may have been exited between last save and shutdown.
- **Atomic writes** — save.sh uses temp file + trap cleanup + `mv` to prevent corrupted state.
- **Session ID priority** — command-line `--resume <uuid>` extraction first, fallback to most-recent `.jsonl` by mtime. Important because `--continue` only resumes the latest session per directory, which fails with multiple Claude panes in the same project.
- **`printf %q`** used to escape `cwd` in restore commands, preventing shell injection from paths with special characters.

### Claude Code Session Mechanics

- Sessions stored as `~/.config/claude/projects/<slug>/<uuid>.jsonl`
- Path slug: `/mnt/d/repo` → `-mnt-d-repo` (all `/` become `-`)
- Resume: `claude --resume <uuid>` (exact session) or `claude --continue` (most recent in cwd)
- Process tree: tmux pane shell → claude (may be 1-4 levels deep)
