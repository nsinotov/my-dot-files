# ===========================================
# Git Aliases
# ===========================================

# Delete all local branches except protected ones (master, main, develop)
alias branches-delete='git branch | grep -v "master" | grep -v "main" | grep -v "develop" | xargs git branch -D'

# Show compact log with graph
alias gl='git log --oneline --graph --decorate -20'

# Amend last commit without editing message
alias gamend='git commit --amend --no-edit'

# Show short status
alias gs='git status --short --branch'
