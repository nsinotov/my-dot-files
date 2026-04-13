# ===========================================
# Project Aliases Template
# ===========================================
# This template shows how install.sh generates per-project aliases.
# For each project defined in ~/.config/dotfiles/.secrets, the following aliases are created:
#
#   <name>-app         Run the application service
#   <name>-api         Run the API service
#   <name>-test        Run the test suite
#   <name>-e2e         Run end-to-end tests
#   <name>-reinstall   Clean dependencies and reinstall
#
# Required variables in ~/.config/dotfiles/.secrets (per project):
#
#   PROJECT_<N>_NAME        Short name used as alias prefix
#   PROJECT_<N>_APP         Command to start the app
#   PROJECT_<N>_API         Command to start the API
#   PROJECT_<N>_TEST        Command to run tests
#   PROJECT_<N>_E2E         Command to run e2e tests
#   PROJECT_<N>_REINSTALL   Command to clean and reinstall deps
#
# Optional (per-project git identity):
#
#   PROJECT_<N>_DIR         Directory containing project repos
#   PROJECT_<N>_GIT_EMAIL   Git email override for repos in that directory
#
# Optional (git worktree management):
#
#   PROJECT_<N>_WT_REPO       Path to the git repository (may differ from DIR)
#   PROJECT_<N>_WT_BRANCH     Base branch for new worktrees (default: main)
#   PROJECT_<N>_WT_ENV_FILES  Space-separated list of env files to copy from main repo
#   PROJECT_<N>_WT_INSTALL    Command to install dependencies in new worktree
#
# Optional (tmux session per worktree):
#
#   PROJECT_<N>_TMUX_WINDOWS  Space-separated window specs: "name:panes[:layout]"
#                             Each entry creates a tmux window with that many panes.
#                             Layout is optional (e.g. tiled, even-horizontal, even-vertical).
#                             All panes start in the worktree directory.
#                             Example: "main:4:tiled claude:1 ide:1"
#
# Worktrees are placed as siblings to the repo: <name>-<sanitized-branch>
# Branch slashes are replaced with dashes in the directory name.
# e.g. ~/projects/myapp-hotfix-DEV-1234 (branch: hotfix/DEV-1234)
#
# When WT_REPO is set, three functions are generated:
#
#   <name>-wt-new <branch>    Create worktree (uses remote branch if exists, otherwise
#                             creates from base branch), copy env files, install deps,
#                             create tmux session (if configured), cd into it
#   <name>-wt-done <branch>   Kill tmux session (if any), clean up worktree directory
#                             and local branch, report what was removed
#   <name>-wt-ls              List all worktrees for the project
#
# Example ~/.config/dotfiles/.secrets entry:
#
#   PROJECT_1_NAME=myapp
#   PROJECT_1_DIR="$HOME/projects/myapp"
#   PROJECT_1_GIT_EMAIL="work@company.com"
#   PROJECT_1_APP="nx serve app"
#   PROJECT_1_API="nx serve api"
#   PROJECT_1_TEST="yarn nx affected --target=test --maxParallel=2"
#   PROJECT_1_E2E="yarn nx e2e app-e2e --watch"
#   PROJECT_1_REINSTALL="find . -name node_modules -type d -prune -exec rm -rf {} + && yarn"
#   PROJECT_1_WT_REPO="$HOME/projects/myapp"
#   PROJECT_1_WT_ENV_FILES=".env apps/app/.env apps/api/.env"
#   PROJECT_1_WT_INSTALL="pnpm install"
#   PROJECT_1_TMUX_WINDOWS="main:4:tiled claude:1 ide:1"
#
# Generated output (~/.aliases.d/project-myapp.sh):
#
#   alias myapp-app='nx serve app'
#   alias myapp-api='nx serve api'
#   alias myapp-test='yarn nx affected --target=test --maxParallel=2'
#   alias myapp-e2e='yarn nx e2e app-e2e --watch'
#   alias myapp-reinstall='find . -name node_modules -type d -prune -exec rm -rf {} + && yarn'
#
#   myapp-wt-new()  { ... }   # Create worktree (pulls remote branch if exists)
#   myapp-wt-done() { ... }   # Clean up worktree and local branch
#   myapp-wt-ls()   { ... }   # List all worktrees
#
# Generated git identity (~/.gitconfig-myapp):
#
#   [user]
#       email = work@company.com
#
# And in ~/.gitconfig:
#
#   [includeIf "gitdir:~/projects/myapp/"]
#       path = ~/.gitconfig-myapp
