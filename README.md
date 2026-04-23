# dotfiles

Developer environment configuration files for macOS/Linux.

## What's Inside

| Directory          | Tool             | Description                                                   |
| ------------------ | ---------------- | ------------------------------------------------------------- |
| `shell/`           | Zsh + Oh My Zsh  | Shell config, topic-based aliases, key bindings               |
| `shell/aliases/`   | —                | Static aliases grouped by topic (git, media, navigation, tmux) |
| `shell/templates/` | —                | Documentation for generated project and account aliases       |
| `terminal/`        | Ghostty          | Terminal emulator (Catppuccin Mocha, Monaspice font)          |
| `editor/`          | Neovim (LazyVim) | Editor with Catppuccin theme, LSP support                     |
| `git/`             | Git              | Config template, global gitignore, modern defaults            |
| `tmux/`            | Tmux             | Multiplexer with TPM, vim-tmux-navigator, session persistence, `prefix+T` sesh picker |
| `prompt/`          | Starship         | Cross-shell prompt (clean, icons only)                        |
| `tools/`           | AeroSpace, VPN, sesh | Tiling window manager (macOS), OpenVPN connection manager, tmux session picker config |

## Architecture

```
┌─────────────────────────────────────────────────────┐
│  ~/.config/dotfiles/.secrets (secrets, project definitions, identity)    │  ← never committed
├─────────────────────────────────────────────────────┤
│  install.sh reads .secrets and:                     │
│    1. Symlinks static configs to system paths       │
│    2. Generates .gitconfig with identity            │
│    3. Generates project aliases → ~/.aliases.d/     │
│    4. Generates Claude account functions            │
│    5. Links custom scripts to ~/bin/                │
├─────────────────────────────────────────────────────┤
│  .zshrc sources:                                    │
│    • shell/aliases/*.sh   (static, from repo)       │
│    • ~/.aliases.d/*.sh    (generated, not tracked)  │
└─────────────────────────────────────────────────────┘
```

## Quick Start

```bash
# 1. Clone the repo
git clone <repo-url> ~/dotfiles
cd ~/dotfiles

# 2. Set up secrets
cp .secrets.example ~/.config/dotfiles/.secrets
# Edit ~/.config/dotfiles/.secrets with real values (git identity, project definitions, tokens)

# 3. Install (symlinks configs, generates project aliases)
chmod +x install.sh && ./install.sh

# 4. Verify everything is set up correctly
./check.sh

# 5. Install tmux plugins (inside tmux)
# Press Ctrl+S, then I
```

## Adding a Project

Define project variables in `~/.config/dotfiles/.secrets` and re-run `install.sh`:

```bash
# In ~/.config/dotfiles/.secrets
PROJECT_1_NAME=myapp
PROJECT_1_APP="nx serve app"
PROJECT_1_APP_PORT=3000
PROJECT_1_API="nx serve api"
PROJECT_1_API_PORT=8081
PROJECT_1_TEST="yarn test"
PROJECT_1_E2E="yarn e2e"
PROJECT_1_REINSTALL="rm -rf node_modules && yarn"
```

This generates aliases: `myapp-app`, `myapp-api`, `myapp-test`, `myapp-e2e`, `myapp-reinstall`.

When `APP_PORT` or `API_PORT` is set, running `myapp-app` / `myapp-api` will automatically kill any process already listening on that port before starting the server. This lets you switch between worktrees without manually finding and stopping the old instance — just run the command and it takes over.

### Worktree management

Add worktree variables to enable `wt-new`, `wt-done`, and `wt-ls` functions:

```bash
PROJECT_1_WT_REPO="$HOME/projects/myapp"
PROJECT_1_WT_BRANCH=main                              # base branch for new worktrees (default: main)
PROJECT_1_WT_ENV_FILES=".env apps/app/.env"            # env files copied from main repo
PROJECT_1_WT_INSTALL="pnpm install"                    # run after worktree creation
PROJECT_1_TMUX_WINDOWS="main:4:tiled agent:1 ide:1"   # optional tmux session layout
```

Generated functions:

| Function | Description |
| --- | --- |
| `myapp-wt-new <branch>` | Create worktree, copy env files, install deps, start tmux session (if configured). Stays in current directory. |
| `myapp-wt-done <branch>` | Remove worktree + directory, delete local branch, kill tmux session |
| `myapp-wt-ls` | List all worktrees for the project |

`TMUX_WINDOWS` format is `"name:panes[:layout]"` — each entry creates a tmux window with the given number of panes. Layout is optional (e.g. `tiled`, `even-horizontal`).

Standalone equivalent: `tmux-session <dir> [windows-spec]` creates (or attaches to) a session for any directory using the same spec format. Session name = basename of the directory; on collision it becomes `<parent>-<basename>`. Default spec is `"main:4:tiled agent:1 ide:1"`, overridable via `TMUX_SESSION_WINDOWS`.

`wt-done` has a safety guard that refuses to remove the main project directory or primary worktree.

See `shell/templates/` for full documentation on the template system.

## Discovering Commands

Run `dotfiles` in any shell to list every custom command this repo provides, grouped by category (git, media, navigation, tmux, scripts, per-project, Claude accounts). Commands marked with `*` support `-h`/`--help` for detailed usage:

```bash
dotfiles            # list everything
tmux-session --help # show usage for one command
vpn --help
myapp-wt-new -h
```

The listing is generated by `install.sh` from `# desc:` / `# help` markers in `shell/aliases/*.sh` plus the per-project and Claude-account definitions in `~/.config/dotfiles/.secrets` — no parsing happens at shell startup.

## Key Design Decisions

- **Symlinks for static configs.** Edits on the system are edits in the repo — no manual sync needed.
- **Generated files for anything with secrets.** `.gitconfig`, project aliases, and Claude account functions are built from `~/.config/dotfiles/.secrets` by `install.sh`. They are never committed.
- **Topic-based alias files.** Aliases are split by concern (git, media, navigation, tmux), not dumped in one file.
- **Catppuccin Mocha everywhere.** Consistent theme across Ghostty, Neovim, and Tmux.
