# ===========================================
# Tmux Aliases
# ===========================================

# ----
# Trigger a tmux-resurrect snapshot silently.
# Called after commands that create or remove sessions so the saved state
# (restored with prefix+R) stays in sync without a manual prefix+S.
_tmux_resurrect_save() {
  local save_script="$HOME/.tmux/plugins/tmux-resurrect/scripts/save.sh"
  # No-op when tmux isn't running or the plugin isn't installed.
  [ -x "$save_script" ] || return 0
  tmux has-session 2>/dev/null || return 0
  "$save_script" quiet >/dev/null 2>&1 || true
}

# ----
# Create (or attach to) a tmux session for a directory.
# Usage: tmux-session <directory> [windows-spec]
#
# Session name = basename of the directory.
# On collision, name becomes "<parent>-<basename>" (path separators become dashes).
#
# Windows-spec format (same as PROJECT_<N>_TMUX_WINDOWS):
#   Space-separated entries "name:panes[:layout]"
#   Default: "main:4:tiled claude:1 ide:1"
tmux-session() {
  local dir="${1:-}"
  local windows="${2:-${TMUX_SESSION_WINDOWS:-main:4:tiled claude:1 ide:1}}"

  if [ -z "$dir" ]; then
    echo "Usage: tmux-session <directory> [windows-spec]" >&2
    return 1
  fi
  if [ ! -d "$dir" ]; then
    echo "Directory not found: $dir" >&2
    return 1
  fi

  local abs_dir
  abs_dir="$(cd "$dir" && pwd)"
  local name
  name="$(basename "$abs_dir")"

  # Collision: prepend parent folder, replacing any "/" with "-".
  if tmux has-session -t="$name" 2>/dev/null; then
    local parent
    parent="$(basename "$(dirname "$abs_dir")")"
    name="${parent}-${name}"
    name="${name//\//-}"
  fi

  if ! tmux has-session -t="$name" 2>/dev/null; then
    local first=true
    local win_spec win_name win_panes win_layout p
    # Split on whitespace in both zsh (no auto-split) and bash.
    local -a win_array
    if [ -n "${ZSH_VERSION:-}" ]; then
      win_array=(${=windows})
    else
      # shellcheck disable=SC2206
      win_array=($windows)
    fi
    for win_spec in "${win_array[@]}"; do
      IFS=':' read -r win_name win_panes win_layout <<< "$win_spec"
      win_panes="${win_panes:-1}"
      if [ "$first" = true ]; then
        tmux new-session -d -s "$name" -n "$win_name" -c "$abs_dir"
        first=false
      else
        tmux new-window -t "$name" -n "$win_name" -c "$abs_dir"
      fi
      for ((p=2; p<=win_panes; p++)); do
        tmux split-window -t "$name:$win_name" -c "$abs_dir"
      done
      if [ -n "${win_layout:-}" ]; then
        tmux select-layout -t "$name:$win_name" "$win_layout"
      fi
    done
    tmux select-window -t "$name:1"
    tmux select-pane -t "$name:1.1"
  fi

  _tmux_resurrect_save

  if [ -n "$TMUX" ]; then
    tmux switch-client -t "$name"
  else
    tmux attach -t "$name"
  fi
}
