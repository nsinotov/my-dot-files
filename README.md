# my-dot-files

Developer environment configuration files for macOS/Linux.

## What's Inside

| Directory | Tool | Description |
|-----------|------|-------------|
| `shell/` | Zsh + Oh My Zsh | Shell config, topic-based aliases, key bindings |
| `shell/aliases/` | — | Static aliases grouped by topic (git, media, navigation) |
| `shell/templates/` | — | Documentation for generated project and account aliases |
| `terminal/` | Ghostty | Terminal emulator (Catppuccin Mocha, Monaspice font) |
| `editor/` | Neovim (LazyVim) | Editor with Catppuccin theme, LSP support |
| `git/` | Git | Config template, global gitignore, modern defaults |
| `tmux/` | Tmux | Multiplexer with TPM, vim-tmux-navigator, session persistence |
| `prompt/` | Starship | Cross-shell prompt (clean, icons only) |
| `tools/` | AeroSpace, VPN | Tiling window manager (macOS), OpenVPN connection manager |

## Architecture

```
┌─────────────────────────────────────────────────────┐
│  ~/.config/dotfiles/.secrets (secrets, project definitions, identity)    │  ← never committed
├─────────────────────────────────────────────────────┤
│  install.sh reads .secrets and:                         │
│    1. Symlinks static configs to system paths       │
│    2. Generates .gitconfig with identity             │
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
git clone <repo-url> ~/my-dot-files
cd ~/my-dot-files

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
PROJECT_1_API="nx serve api"
PROJECT_1_TEST="yarn test"
PROJECT_1_E2E="yarn e2e"
PROJECT_1_REINSTALL="rm -rf node_modules && yarn"
PROJECT_1_ENV="NODE_OPTIONS=--max-old-space-size=8192"
```

This generates aliases: `myapp-app`, `myapp-api`, `myapp-test`, `myapp-e2e`, `myapp-reinstall`.

See `shell/templates/` for full documentation on the template system.

## Key Design Decisions

- **Symlinks for static configs.** Edits on the system are edits in the repo — no manual sync needed.
- **Generated files for anything with secrets.** `.gitconfig`, project aliases, and Claude account functions are built from `~/.config/dotfiles/.secrets` by `install.sh`. They are never committed.
- **Topic-based alias files.** Aliases are split by concern (git, media, navigation), not dumped in one file.
- **Catppuccin Mocha everywhere.** Consistent theme across Ghostty, Neovim, and Tmux.
