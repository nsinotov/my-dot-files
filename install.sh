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
OPTIONAL_DEPS=(nvim tmux starship fzf fd lazygit gh)

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
    if ! grep -q "# Generated by my-dot-files" "$GITCONFIG_DST" 2>/dev/null; then
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
# Generated by my-dot-files/install.sh — do not edit directly
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
# Generated by my-dot-files/install.sh — do not edit directly
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
    cat >> "$outfile" <<WTEOF

${name}-wt-new() {
  local branch="\$1"
  local base_branch="\${2:-${wt_branch}}"
  if [ -z "\$branch" ]; then
    echo "Usage: ${name}-wt-new <branch-name> [base-branch]"
    return 1
  fi
  local project_dir="${wt_repo}"
  local sanitized="\${branch//\//-}"
  local wt_path="\$(dirname "\$project_dir")/${name}-\$sanitized"
  git -C "\$project_dir" fetch origin
  if git -C "\$project_dir" rev-parse --verify "origin/\$branch" >/dev/null 2>&1; then
    git -C "\$project_dir" worktree add "\$wt_path" -b "\$branch" "origin/\$branch"
  else
    git -C "\$project_dir" worktree add "\$wt_path" -b "\$branch" "origin/\$base_branch"
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

    cat >> "$outfile" <<WTEOF2
  cd "\$wt_path"
  echo "Worktree ready: \$wt_path"
}

${name}-wt-done() {
  local branch="\$1"
  if [ -z "\$branch" ]; then
    echo "Usage: ${name}-wt-done <branch-name>"
    return 1
  fi
  local project_dir="${wt_repo}"
  local sanitized="\${branch//\//-}"
  local wt_path="\$(dirname "\$project_dir")/${name}-\$sanitized"
  local removed=()
  cd "\$project_dir"
  if git worktree remove "\$wt_path" 2>/dev/null; then
    removed+=("worktree \$wt_path")
  elif [ -d "\$wt_path" ]; then
    rm -rf "\$wt_path"
    removed+=("directory \$wt_path")
  fi
  if git branch -d "\$branch" 2>/dev/null; then
    removed+=("branch \$branch")
  fi
  if [ \${#removed[@]} -eq 0 ]; then
    echo "Nothing to clean up for \$branch"
  else
    echo "Removed: \${removed[*]}"
  fi
}

${name}-wt-ls() {
  git -C "${wt_repo}" worktree list
}
WTEOF2
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
