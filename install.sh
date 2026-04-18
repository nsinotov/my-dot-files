#!/usr/bin/env bash
# ===========================================
# install.sh — Link dotfiles & generate configs
# ===========================================
# Idempotent: safe to run multiple times.
# Backs up existing configs before overwriting.
#
# Usage:
#   ./install.sh           Install to system (symlinks + generated files)
#   ./install.sh --test    Generate to build/ directory for review

set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "$0")" && pwd)"
BACKUP_SUFFIX=".bak.$(date +%Y%m%d%H%M%S)"

# ------------------------------------
# Test mode
# ------------------------------------

TEST_MODE=false
if [ "${1:-}" = "--test" ]; then
  TEST_MODE=true
  BUILD_DIR="$DOTFILES_DIR/build"
  rm -rf "$BUILD_DIR"
  mkdir -p "$BUILD_DIR"
fi

# ------------------------------------
# Helpers
# ------------------------------------

info()    { printf "  \033[1;34m%-50s\033[0m %s\n" "$1" "$2"; }
success() { printf "  \033[1;32m%-50s\033[0m %s\n" "$1" "OK"; }
fail()    { printf "  \033[1;31m%-50s\033[0m %s\n" "$1" "$2"; }

# Resolve target path: real system path or build/ in test mode
target_path() {
  local path="$1"
  if [ "$TEST_MODE" = true ]; then
    # Strip $HOME prefix and place under build/
    echo "$BUILD_DIR${path#"$HOME"}"
  else
    echo "$path"
  fi
}

link_file() {
  local src="$1" dst
  dst="$(target_path "$2")"

  if [ "$TEST_MODE" = true ]; then
    mkdir -p "$(dirname "$dst")"
    # In test mode, copy instead of symlink
    if [ -d "$src" ]; then
      cp -R "$src" "$dst"
    else
      cp "$src" "$dst"
    fi
    success "$dst" "(copied)"
    return
  fi

  if [ -L "$dst" ] && [ "$(readlink "$dst")" = "$src" ]; then
    success "$dst" ""
    return
  fi

  if [ -e "$dst" ] || [ -L "$dst" ]; then
    mv "$dst" "${dst}${BACKUP_SUFFIX}"
    info "$dst" "backed up"
  fi

  mkdir -p "$(dirname "$dst")"
  ln -s "$src" "$dst"
  success "$dst" ""
}

write_file() {
  local dst
  dst="$(target_path "$1")"
  mkdir -p "$(dirname "$dst")"
  cat > "$dst"
  success "$dst" ""
}

# ------------------------------------
# Detect OS
# ------------------------------------

OS="$(uname -s)"
info "Detected OS" "$OS"

if [ "$TEST_MODE" = true ]; then
  info "Mode" "TEST — output to $BUILD_DIR"
fi
echo ""

# ------------------------------------
# Load secrets
# ------------------------------------

SECRETS_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles/.secrets"
if [ -f "$SECRETS_FILE" ]; then
  set -a
  # shellcheck disable=SC1091
  source "$SECRETS_FILE"
  set +a
  success "Loaded $SECRETS_FILE" ""
else
  fail "No secrets file found" "copy .secrets.example to $SECRETS_FILE and fill in values"
  exit 1
fi

# ===========================================
# Phase 1: Check dependencies
# ===========================================

echo ""
echo "Checking dependencies..."
echo ""

# Required tools (install will not proceed without these)
REQUIRED_DEPS=(git zsh)

# Optional tools (offer to install if missing)
OPTIONAL_DEPS=(nvim tmux starship fzf fd lazygit gh sesh zoxide)

# macOS-only optional tools (cask)
MACOS_CASK_DEPS=(ghostty)

missing_required=()
for dep in "${REQUIRED_DEPS[@]}"; do
  if command -v "$dep" > /dev/null 2>&1; then
    success "$dep" ""
  else
    fail "$dep" "REQUIRED — not found"
    missing_required+=("$dep")
  fi
done

if [ ${#missing_required[@]} -gt 0 ]; then
  echo ""
  fail "Missing required dependencies" "${missing_required[*]}"
  echo "  Install them before running this script."
  exit 1
fi

missing_optional=()
for dep in "${OPTIONAL_DEPS[@]}"; do
  if command -v "$dep" > /dev/null 2>&1; then
    success "$dep" ""
  else
    info "$dep" "not found"
    missing_optional+=("$dep")
  fi
done

if [ "$OS" = "Darwin" ]; then
  for dep in "${MACOS_CASK_DEPS[@]}"; do
    if brew list --cask "$dep" > /dev/null 2>&1; then
      success "$dep" ""
    else
      info "$dep" "not found (cask)"
      missing_optional+=("cask:$dep")
    fi
  done
fi

if [ ${#missing_optional[@]} -gt 0 ] && [ "$TEST_MODE" = false ]; then
  echo ""
  info "Missing optional tools" "${missing_optional[*]}"
  printf "\n  Install missing tools? [y/N] "
  read -r answer
  if [[ "$answer" =~ ^[Yy]$ ]]; then
    if [ "$OS" = "Darwin" ] && command -v brew > /dev/null 2>&1; then
      for dep in "${missing_optional[@]}"; do
        if [[ "$dep" == cask:* ]]; then
          cask_name="${dep#cask:}"
          printf "  Install %s (cask)? [y/N] " "$cask_name"
          read -r dep_answer
          if [[ "$dep_answer" =~ ^[Yy]$ ]]; then
            brew install --cask "$cask_name"
            success "$cask_name" "installed"
          fi
        else
          printf "  Install %s? [y/N] " "$dep"
          read -r dep_answer
          if [[ "$dep_answer" =~ ^[Yy]$ ]]; then
            brew install "$dep"
            success "$dep" "installed"
          fi
        fi
      done
    elif command -v apt > /dev/null 2>&1; then
      for dep in "${missing_optional[@]}"; do
        [[ "$dep" == cask:* ]] && continue
        printf "  Install %s? [y/N] " "$dep"
        read -r dep_answer
        if [[ "$dep_answer" =~ ^[Yy]$ ]]; then
          sudo apt install -y "$dep"
          success "$dep" "installed"
        fi
      done
    else
      fail "No package manager found" "install missing tools manually"
    fi
  fi
fi

# ===========================================
# Phase 2: Symlink static configs
# ===========================================

echo ""
echo "Linking static configs..."
echo ""

link_file "$DOTFILES_DIR/shell/.zshrc"              "$HOME/.zshrc"
link_file "$DOTFILES_DIR/tmux/.tmux.conf"           "$HOME/.tmux.conf"
link_file "$DOTFILES_DIR/terminal/ghostty/config"   "$HOME/.config/ghostty/config"
link_file "$DOTFILES_DIR/editor/nvim"               "$HOME/.config/nvim"
link_file "$DOTFILES_DIR/prompt/starship.toml"      "$HOME/.config/starship.toml"
link_file "$DOTFILES_DIR/git/.gitignore"            "$HOME/.gitignore"
link_file "$DOTFILES_DIR/tools/sesh.toml"           "$HOME/.config/sesh/sesh.toml"

if [ "$OS" = "Darwin" ]; then
  link_file "$DOTFILES_DIR/tools/aerospace.toml"    "$HOME/.aerospace.toml"
fi

# Custom scripts (~/bin/)
if [ "$TEST_MODE" = false ]; then
  mkdir -p "$HOME/bin"
fi
link_file "$DOTFILES_DIR/tools/vpn"                 "$HOME/bin/vpn"

# ===========================================
# Phase 3: Generate .gitconfig
# ===========================================

echo ""
echo "Generating .gitconfig..."
echo ""

GITCONFIG_DST="$HOME/.gitconfig"

if [ "$TEST_MODE" = false ]; then
  if [ -e "$GITCONFIG_DST" ] && [ ! -L "$GITCONFIG_DST" ]; then
    if ! grep -q "# Generated by dotfiles" "$GITCONFIG_DST" 2>/dev/null; then
      mv "$GITCONFIG_DST" "${GITCONFIG_DST}${BACKUP_SUFFIX}"
      info "$GITCONFIG_DST" "backed up"
    fi
  fi
fi

# Build includeIf entries for per-project git identity
git_includes=""
for i in $(seq 1 99); do
  name_var="PROJECT_${i}_NAME"
  name="${!name_var:-}"
  [ -z "$name" ] && break

  dir_var="PROJECT_${i}_DIR";         dir="${!dir_var:-}"
  email_var="PROJECT_${i}_GIT_EMAIL"; email="${!email_var:-}"

  if [ -n "$dir" ] && [ -n "$email" ]; then
    # Ensure trailing slash for gitdir matching
    [[ "$dir" != */ ]] && dir="${dir}/"

    # Write per-project gitconfig fragment
    project_gitconfig="$(target_path "$HOME/.gitconfig-${name}")"
    mkdir -p "$(dirname "$project_gitconfig")"
    cat > "$project_gitconfig" <<PGEOF
# Generated by dotfiles/install.sh — do not edit directly
[user]
	email = ${email}
PGEOF
    success "$project_gitconfig" ""

    git_includes+="
[includeIf \"gitdir:${dir}\"]
	path = ~/.gitconfig-${name}"
  fi
done

write_file "$GITCONFIG_DST" <<GITEOF
# Generated by dotfiles/install.sh — do not edit directly
# To change: update ~/.config/dotfiles/.secrets and re-run install.sh

[user]
	name = ${GIT_USER_NAME}
	email = ${GIT_USER_EMAIL}

$(cat "$DOTFILES_DIR/git/.gitconfig")
${git_includes}
GITEOF

# ===========================================
# Phase 4: Generate project aliases
# ===========================================

echo ""
echo "Generating project aliases..."
echo ""

ALIASES_DIR="$(target_path "$HOME/.aliases.d")"
mkdir -p "$ALIASES_DIR"

# Clean previous generated project files
rm -f "$ALIASES_DIR"/project-*.sh
rm -f "$ALIASES_DIR"/claude-accounts.sh

for i in $(seq 1 99); do
  name_var="PROJECT_${i}_NAME"
  name="${!name_var:-}"
  [ -z "$name" ] && break

  app_var="PROJECT_${i}_APP";             app="${!app_var:-}"
  api_var="PROJECT_${i}_API";             api="${!api_var:-}"
  test_var="PROJECT_${i}_TEST";           test_cmd="${!test_var:-}"
  e2e_var="PROJECT_${i}_E2E";             e2e="${!e2e_var:-}"
  reinstall_var="PROJECT_${i}_REINSTALL"; reinstall="${!reinstall_var:-}"
  wt_repo_var="PROJECT_${i}_WT_REPO";     wt_repo="${!wt_repo_var:-}"
  wt_branch_var="PROJECT_${i}_WT_BRANCH"; wt_branch="${!wt_branch_var:-main}"
  wt_env_var="PROJECT_${i}_WT_ENV_FILES"; wt_env="${!wt_env_var:-}"
  wt_install_var="PROJECT_${i}_WT_INSTALL"; wt_install="${!wt_install_var:-}"
  wt_tmux_var="PROJECT_${i}_TMUX_WINDOWS"; wt_tmux="${!wt_tmux_var:-}"
  dir_var="PROJECT_${i}_DIR";             dir="${!dir_var:-}"

  outfile="$ALIASES_DIR/project-${name}.sh"
  cat > "$outfile" <<PROJEOF
# Auto-generated by install.sh — do not edit
# Project: ${name}

PROJEOF

  [ -n "$app" ]       && echo "alias ${name}-app='${app}'"           >> "$outfile"
  [ -n "$api" ]       && echo "alias ${name}-api='${api}'"           >> "$outfile"
  [ -n "$test_cmd" ]  && echo "alias ${name}-test='${test_cmd}'"     >> "$outfile"
  [ -n "$e2e" ]       && echo "alias ${name}-e2e='${e2e}'"           >> "$outfile"
  [ -n "$reinstall" ] && echo "alias ${name}-reinstall='${reinstall}'" >> "$outfile"

  if [ -n "$wt_repo" ]; then

    # Log helpers for bordered output
    cat >> "$outfile" <<'WTHELPEOF'

_wt_log_green() {
  local width=50
  local border="\033[1;32m"
  local reset="\033[0m"
  printf "\n${border}%s${reset}\n" "$(printf '─%.0s' $(seq 1 $width))"
  for line in "$@"; do
    printf "${border}│${reset} %-$((width - 2))s\n" "$line"
  done
  printf "${border}%s${reset}\n" "$(printf '─%.0s' $(seq 1 $width))"
}

_wt_log_red() {
  local width=50
  local border="\033[1;31m"
  local reset="\033[0m"
  printf "\n${border}%s${reset}\n" "$(printf '─%.0s' $(seq 1 $width))"
  for line in "$@"; do
    printf "${border}│${reset} %-$((width - 2))s\n" "$line"
  done
  printf "${border}%s${reset}\n" "$(printf '─%.0s' $(seq 1 $width))"
}
WTHELPEOF

    cat >> "$outfile" <<WTEOF

${name}-wt-new() {
  if [ "\${1:-}" = "-h" ] || [ "\${1:-}" = "--help" ]; then
    echo "Usage: ${name}-wt-new <branch> [base-branch]"
    echo "Create a git worktree for ${name} (base defaults to ${wt_branch})."
    return 0
  fi
  local branch="\$1"
  local base_branch="\${2:-${wt_branch}}"
  if [ -z "\$branch" ]; then
    _wt_log_red "Usage: ${name}-wt-new <branch> [base-branch]"
    return 1
  fi
  local project_dir="${wt_repo}"
  local sanitized="\${branch//\//-}"
  local wt_name="${name}-\$sanitized"
  local wt_path="\$(dirname "\$project_dir")/${name}-\$sanitized"
  local actual_base="\$base_branch"
  git -C "\$project_dir" fetch origin
  if git -C "\$project_dir" rev-parse --verify "origin/\$branch" >/dev/null 2>&1; then
    actual_base="\$branch (remote)"
    if ! git -C "\$project_dir" worktree add "\$wt_path" -b "\$branch" "origin/\$branch"; then
      _wt_log_red "Failed to create worktree" "branch: \$branch"
      return 1
    fi
  else
    if ! git -C "\$project_dir" worktree add "\$wt_path" -b "\$branch" "origin/\$base_branch"; then
      _wt_log_red "Failed to create worktree" "branch: \$branch" "base: \$base_branch"
      return 1
    fi
  fi
WTEOF

    if [ -n "$wt_env" ]; then
      for env_file in $wt_env; do
        cat >> "$outfile" <<ENVEOF
  if [ -f "\$project_dir/${env_file}" ]; then
    mkdir -p "\$(dirname "\$wt_path/${env_file}")"
    cp "\$project_dir/${env_file}" "\$wt_path/${env_file}"
  fi
ENVEOF
      done
    fi

    if [ -n "$wt_install" ]; then
      cat >> "$outfile" <<INSTEOF
  (cd "\$wt_path" && ${wt_install})
INSTEOF
    fi

    # Tmux session creation (optional, from TMUX_WINDOWS config)
    if [ -n "$wt_tmux" ]; then
      first_tmux_window=true
      for win_spec in $wt_tmux; do
        IFS=':' read -r win_name win_panes win_layout <<< "$win_spec"
        win_panes="${win_panes:-1}"
        if [ "$first_tmux_window" = true ]; then
          cat >> "$outfile" <<TMUXEOF
  local session_name="${name}-\$sanitized"
  tmux new-session -d -s "\$session_name" -n "${win_name}" -c "\$wt_path"
TMUXEOF
          first_tmux_window=false
        else
          cat >> "$outfile" <<TMUXEOF
  tmux new-window -t "\$session_name" -n "${win_name}" -c "\$wt_path"
TMUXEOF
        fi
        for ((p=2; p<=win_panes; p++)); do
          cat >> "$outfile" <<TMUXEOF
  tmux split-window -t "\$session_name:${win_name}" -c "\$wt_path"
TMUXEOF
        done
        if [ -n "${win_layout:-}" ]; then
          cat >> "$outfile" <<TMUXEOF
  tmux select-layout -t "\$session_name:${win_name}" "${win_layout}"
TMUXEOF
        fi
      done
      cat >> "$outfile" <<TMUXEOF
  tmux select-window -t "\$session_name:1"
  tmux select-pane -t "\$session_name:1.1"
  _tmux_resurrect_save
TMUXEOF
    fi

    # Summary log (with or without tmux)
    if [ -n "$wt_tmux" ]; then
      cat >> "$outfile" <<WTEOF2
  _wt_log_green "Worktree created" "worktree: \$wt_name" "directory: \$wt_name" "branch: \$branch" "base: \$actual_base" "tmux: \$session_name"
}

WTEOF2
    else
      cat >> "$outfile" <<WTEOF2
  _wt_log_green "Worktree created" "worktree: \$wt_name" "directory: \$wt_name" "branch: \$branch" "base: \$actual_base"
}

WTEOF2
    fi

    # wt-done function
    cat >> "$outfile" <<WTDONE_HDR

${name}-wt-done() {
  if [ "\${1:-}" = "-h" ] || [ "\${1:-}" = "--help" ]; then
    echo "Usage: ${name}-wt-done <branch>"
    echo "Remove the ${name} worktree, its branch, and any tmux session."
    return 0
  fi
  local branch="\$1"
  if [ -z "\$branch" ]; then
    _wt_log_red "Usage: ${name}-wt-done <branch>"
    return 1
  fi
  local project_dir="${wt_repo}"
  local sanitized="\${branch//\//-}"
  local wt_path="\$(dirname "\$project_dir")/${name}-\$sanitized"
  local wt_name="${name}-\$sanitized"
  local removed=()
WTDONE_HDR

    cat >> "$outfile" <<WTDONE_GUARD
  cd "\$project_dir"
  # Guard: never remove the main project directory or primary worktree
  local main_wt
  main_wt="\$(git -C "\$project_dir" worktree list --porcelain 2>/dev/null | head -1)"
  main_wt="\${main_wt#worktree }"
  if [ "\$wt_path" = "\$project_dir" ] || [ "\$wt_path" = "\$main_wt" ]; then
    _wt_log_red "Refusing to remove main project directory"
    return 1
  fi
WTDONE_GUARD

    # Kill tmux session BEFORE removing worktree (processes block directory removal)
    if [ -n "$wt_tmux" ]; then
      cat >> "$outfile" <<WTDONE_TMUX
  local session_name="${name}-\$sanitized"
  if [ -n "\$TMUX" ] && [ "\$(tmux display-message -p '#S')" = "\$session_name" ]; then
    _wt_log_red "Cannot remove from inside its own tmux session" "Run from another session or terminal"
    return 1
  fi
  if tmux has-session -t "\$session_name" 2>/dev/null; then
    tmux kill-session -t "\$session_name"
    removed+=("tmux: \$session_name")
    _tmux_resurrect_save
  fi
WTDONE_TMUX
    fi

    cat >> "$outfile" <<WTDONE_REMOVE
  if git worktree remove --force "\$wt_path" 2>/dev/null; then
    removed+=("worktree: \$wt_name")
    removed+=("directory: \$wt_name")
  elif [ -d "\$wt_path" ]; then
    rm -rf "\$wt_path"
    removed+=("directory: \$wt_name")
  fi
  # Force-delete: wt-done is explicit cleanup, so unmerged branches should still be removed
  if git branch -D "\$branch" 2>/dev/null; then
    removed+=("branch: \$branch")
  fi
WTDONE_REMOVE

    cat >> "$outfile" <<'WTDONE_REPORT'
  if [ ${#removed[@]} -eq 0 ]; then
    _wt_log_red "Nothing to clean up"
  else
    _wt_log_green "Removed" "${removed[@]}"
  fi
WTDONE_REPORT

    cat >> "$outfile" <<WTDONE_END
}

${name}-wt-ls() {
  if [ "\${1:-}" = "-h" ] || [ "\${1:-}" = "--help" ]; then
    echo "Usage: ${name}-wt-ls"
    echo "List ${name} git worktrees."
    return 0
  fi
  git -C "${wt_repo}" worktree list
}
WTDONE_END
  fi

  success "Project: ${name}" "→ $outfile"
done

# ===========================================
# Phase 5: Generate Claude Code work accounts
# ===========================================

echo ""
echo "Generating Claude Code accounts..."
echo ""

claude_outfile="$ALIASES_DIR/claude-accounts.sh"
cat > "$claude_outfile" <<'CLHDR'
# Auto-generated by install.sh — do not edit
# Claude Code work account functions

_CLAUDE_BIN="$HOME/.local/bin/claude"
CLHDR

account_count=0
for i in $(seq 1 99); do
  name_var="CLAUDE_ACCOUNT_${i}_NAME"
  name="${!name_var:-}"
  [ -z "$name" ] && break

  vertex_var="CLAUDE_ACCOUNT_${i}_USE_VERTEX";   vertex="${!vertex_var:-}"
  region_var="CLAUDE_ACCOUNT_${i}_REGION";        region="${!region_var:-}"
  project_var="CLAUDE_ACCOUNT_${i}_PROJECT_ID";   project="${!project_var:-}"
  config_var="CLAUDE_ACCOUNT_${i}_CONFIG_DIR";    config_dir="${!config_var:-}"
  extra_var="CLAUDE_ACCOUNT_${i}_EXTRA_VARS";     extra="${!extra_var:-}"

  cat >> "$claude_outfile" <<FNEOF

claude-${name}() {
  if [ "\${1:-}" = "-h" ] || [ "\${1:-}" = "--help" ]; then
    echo "Usage: claude-${name} [claude-args...]"
    echo "Launch Claude Code with the '${name}' account environment."
    return 0
  fi
  printf "\e]0;claude - ${name}\a"
FNEOF

  [ -n "$vertex" ]     && echo "  CLAUDE_CODE_USE_VERTEX=${vertex} \\"              >> "$claude_outfile"
  [ -n "$region" ]     && echo "  CLOUD_ML_REGION=${region} \\"                     >> "$claude_outfile"
  [ -n "$project" ]    && echo "  ANTHROPIC_VERTEX_PROJECT_ID=${project} \\"        >> "$claude_outfile"
  [ -n "$config_dir" ] && echo "  CLAUDE_CONFIG_DIR=${config_dir} \\"               >> "$claude_outfile"

  if [ -n "$extra" ]; then
    for pair in $extra; do
      echo "  ${pair} \\" >> "$claude_outfile"
    done
  fi

  cat >> "$claude_outfile" <<'FNEND'
  "$_CLAUDE_BIN" "$@"
}
FNEND

  account_count=$((account_count + 1))
  success "Account: claude-${name}" ""
done

if [ "$account_count" -eq 0 ]; then
  info "No Claude work accounts defined" "see .secrets.example"
fi

# ===========================================
# Phase 6: Generate `dotfiles` listing command
# ===========================================
# Parses `# desc:` and `# help` markers in static alias files, combines them
# with manual entries (scripts) and generated entries (projects, claude
# accounts), and writes a static `dotfiles` function. No parsing at runtime.

echo ""
echo "Generating dotfiles command..."
echo ""

dotfiles_outfile="$ALIASES_DIR/dotfiles.sh"

# Emit "<name>|<has_help 0/1>|<description>" for each documented item in a file.
# A definition is picked up when preceded (anywhere in the contiguous comment
# block above it) by "# desc: TEXT" and optionally "# help".
_parse_descs() {
  awk '
    function emit(name) {
      if (desc != "") {
        printf "%s|%d|%s\n", name, help, desc
        desc=""; help=0
      }
    }
    /^[[:space:]]*#[[:space:]]*desc:[[:space:]]*/ {
      line=$0
      sub(/^[[:space:]]*#[[:space:]]*desc:[[:space:]]*/, "", line)
      desc=line; next
    }
    /^[[:space:]]*#[[:space:]]*help[[:space:]]*$/ { help=1; next }
    /^[[:space:]]*#/ { next }
    /^[[:space:]]*$/ { next }
    /^[[:space:]]*alias[[:space:]]+[A-Za-z0-9_-]+=/ {
      n=$0
      sub(/^[[:space:]]*alias[[:space:]]+/, "", n)
      sub(/=.*/, "", n)
      emit(n); next
    }
    /^[[:space:]]*[A-Za-z0-9_-]+\(\)/ {
      n=$0
      sub(/^[[:space:]]+/, "", n)
      sub(/\(.*/, "", n)
      emit(n); next
    }
    { desc=""; help=0 }
  ' "$1"
}

# Format one line: indented name, help marker, description.
_fmt_line() {
  local name="$1" has_help="$2" desc="$3" marker=" "
  [ "$has_help" = "1" ] && marker="*"
  printf "  %-24s %s  %s\n" "$name" "$marker" "$desc"
}

# Print a section header + parsed entries from a source file.
_emit_section() {
  local title="$1" file="$2" n h d
  local lines
  lines="$(_parse_descs "$file")"
  [ -z "$lines" ] && return 0
  echo "$title"
  printf '%s\n' "$lines" | while IFS='|' read -r n h d; do
    _fmt_line "$n" "$h" "$d"
  done
  echo ""
}

{
  cat <<'DOTFILES_HDR'
# Auto-generated by install.sh — do not edit.
# Run `dotfiles` to list all custom commands from dotfiles.

dotfiles() {
  if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
    cat <<'HELP'
Usage: dotfiles [-h|--help]

List all custom commands provided by dotfiles, grouped by category.
Commands marked with * support --help / -h.
HELP
    return 0
  fi
  cat <<'__DOTFILES_LIST__'
Custom commands from dotfiles  (* = supports --help)

DOTFILES_HDR

  _emit_section "Git aliases"        "$DOTFILES_DIR/shell/aliases/git.sh"
  _emit_section "Media aliases"      "$DOTFILES_DIR/shell/aliases/media.sh"
  _emit_section "Navigation aliases" "$DOTFILES_DIR/shell/aliases/navigation.sh"
  _emit_section "Tmux"               "$DOTFILES_DIR/shell/aliases/tmux.sh"

  echo "Scripts"
  _fmt_line "vpn" "1" "OpenVPN connection manager (up/down/status/fix/menu)"
  echo ""

  # Per-project generated commands
  for i in $(seq 1 99); do
    name_var="PROJECT_${i}_NAME";           name="${!name_var:-}"
    [ -z "$name" ] && break
    app_var="PROJECT_${i}_APP";             app="${!app_var:-}"
    api_var="PROJECT_${i}_API";             api="${!api_var:-}"
    test_var="PROJECT_${i}_TEST";           test_cmd="${!test_var:-}"
    e2e_var="PROJECT_${i}_E2E";             e2e="${!e2e_var:-}"
    reinstall_var="PROJECT_${i}_REINSTALL"; reinstall="${!reinstall_var:-}"
    wt_repo_var="PROJECT_${i}_WT_REPO";     wt_repo="${!wt_repo_var:-}"

    # Skip projects with no defined commands
    if [ -z "$app$api$test_cmd$e2e$reinstall$wt_repo" ]; then
      continue
    fi
    echo "Project: ${name}"
    [ -n "$app" ]       && _fmt_line "${name}-app"       "0" "Run the project app"
    [ -n "$api" ]       && _fmt_line "${name}-api"       "0" "Run the project API"
    [ -n "$test_cmd" ]  && _fmt_line "${name}-test"      "0" "Run unit tests"
    [ -n "$e2e" ]       && _fmt_line "${name}-e2e"       "0" "Run e2e tests"
    [ -n "$reinstall" ] && _fmt_line "${name}-reinstall" "0" "Reinstall dependencies"
    if [ -n "$wt_repo" ]; then
      _fmt_line "${name}-wt-new"  "1" "Create a git worktree for a branch"
      _fmt_line "${name}-wt-done" "1" "Remove worktree, branch, and tmux session"
      _fmt_line "${name}-wt-ls"   "1" "List git worktrees"
    fi
    echo ""
  done

  # Claude accounts
  first_claude=true
  for i in $(seq 1 99); do
    name_var="CLAUDE_ACCOUNT_${i}_NAME"; name="${!name_var:-}"
    [ -z "$name" ] && break
    if [ "$first_claude" = true ]; then
      echo "Claude accounts"
      first_claude=false
    fi
    _fmt_line "claude-${name}" "1" "Launch Claude Code with the '${name}' account"
  done
  [ "$first_claude" = false ] && echo ""

  cat <<'DOTFILES_FTR'
__DOTFILES_LIST__
}
DOTFILES_FTR
} > "$dotfiles_outfile"

success "dotfiles command" "→ $dotfiles_outfile"

# ===========================================
# Done
# ===========================================

echo ""
if [ "$TEST_MODE" = true ]; then
  echo "Test complete. Review generated files in: $BUILD_DIR"
  echo ""
  find "$BUILD_DIR" -type f | sort | while read -r f; do
    echo "  $f"
  done
else
  echo "Installation complete. Restart your shell or run: source ~/.zshrc"
fi
