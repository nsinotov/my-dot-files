# ===========================================
# Claude Code Account Template
# ===========================================
# This template shows how install.sh generates Claude Code account functions.
# For each account defined in ~/.config/dotfiles/.secrets, a shell function is created that
# sets the correct environment variables and launches Claude Code.
#
# Required variables in ~/.config/dotfiles/.secrets (per account):
#
#   CLAUDE_ACCOUNT_<N>_NAME          Function name suffix (e.g., "work" → claude-work)
#   CLAUDE_ACCOUNT_<N>_USE_VERTEX    (optional) Set to "true" for Vertex AI
#   CLAUDE_ACCOUNT_<N>_REGION        (optional) Cloud region
#   CLAUDE_ACCOUNT_<N>_PROJECT_ID    (optional) GCP project ID
#   CLAUDE_ACCOUNT_<N>_CONFIG_DIR    (optional) Config directory override
#   CLAUDE_ACCOUNT_<N>_EXTRA_VARS    (optional) Space-separated KEY=VALUE pairs
#
# Example ~/.config/dotfiles/.secrets entry:
#
#   CLAUDE_ACCOUNT_1_NAME=work
#   CLAUDE_ACCOUNT_1_USE_VERTEX=true
#   CLAUDE_ACCOUNT_1_REGION=global
#   CLAUDE_ACCOUNT_1_PROJECT_ID=my-gcp-project
#   CLAUDE_ACCOUNT_1_CONFIG_DIR=$HOME/.claude-work
#   CLAUDE_ACCOUNT_1_EXTRA_VARS="MY_TOKEN=$MY_SECRET OTHER_VAR=value"
#
# Generated output (~/.aliases.d/claude-accounts.sh):
#
#   claude-work() {
#     printf "\e]0;claude - work\a"
#     CLAUDE_CODE_USE_VERTEX=true \
#     CLOUD_ML_REGION=global \
#     ANTHROPIC_VERTEX_PROJECT_ID=my-gcp-project \
#     CLAUDE_CONFIG_DIR=$HOME/.claude-work \
#     MY_TOKEN=$MY_SECRET \
#     OTHER_VAR=value \
#     "$_CLAUDE_BIN" "$@"
#   }
