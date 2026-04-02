# ===========================================
# Navigation Aliases
# ===========================================
# Paths are configured via environment variables in ~/.config/dotfiles/.secrets

# Jump to Obsidian vault
if [ -n "$OBSIDIAN_VAULT_PATH" ]; then
  alias cd-to-obsidian="cd \"$OBSIDIAN_VAULT_PATH\""
fi
