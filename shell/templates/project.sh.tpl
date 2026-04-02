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
#
# Generated output (~/.aliases.d/project-myapp.sh):
#
#   alias myapp-app='nx serve app'
#   alias myapp-api='nx serve api'
#   alias myapp-test='yarn nx affected --target=test --maxParallel=2'
#   alias myapp-e2e='yarn nx e2e app-e2e --watch'
#   alias myapp-reinstall='find . -name node_modules -type d -prune -exec rm -rf {} + && yarn'
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
