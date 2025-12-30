#!/usr/bin/env bash

# Git Repository Batch Updater
# Automatically discovers and updates all git repositories in the current directory

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Print functions
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[✓]${NC} $1"
}

print_error() {
    echo -e "${RED}[✗]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[!]${NC} $1"
}

# Check if directory is a git repository
is_git_repo() {
    local dir="$1"
    if [ -d "$dir/.git" ]; then
        return 0
    fi
    return 1
}

# Get current branch name
get_current_branch() {
    git branch --show-current 2>/dev/null || echo "unknown"
}

# Update a single repository
update_repo() {
    local repo_path="$1"
    local repo_name=$(basename "$repo_path")

    echo ""
    print_info "Updating: $repo_name"

    cd "$repo_path"

    # Check for uncommitted changes
    if ! git diff-index --quiet HEAD -- 2>/dev/null; then
        print_warning "$repo_name has uncommitted changes. Skipping..."
        return 1
    fi

    # Check for untracked files (optional warning)
    if [ -n "$(git ls-files --others --exclude-standard)" ]; then
        print_warning "$repo_name has untracked files."
    fi

    # Get current branch
    local branch=$(get_current_branch)

    # Fetch updates
    if git fetch --all --prune 2>/dev/null; then
        # Check if we're behind remote
        local local_commit=$(git rev-parse HEAD 2>/dev/null)
        local remote_commit=$(git rev-parse @{u} 2>/dev/null || echo "")

        if [ -z "$remote_commit" ]; then
            print_warning "$repo_name: No upstream branch set for '$branch'"
            return 1
        fi

        if [ "$local_commit" = "$remote_commit" ]; then
            print_success "$repo_name is already up to date (branch: $branch)"
            return 0
        fi

        # Pull changes
        if git pull 2>/dev/null; then
            print_success "$repo_name updated successfully (branch: $branch)"
            return 0
        else
            print_error "$repo_name: Failed to pull changes"
            return 1
        fi
    else
        print_error "$repo_name: Failed to fetch from remote"
        return 1
    fi
}

# Main function
main() {
    local start_dir="$PWD"
    local repos_found=0
    local repos_updated=0
    local repos_skipped=0
    local repos_failed=0

    echo "╔════════════════════════════════════════════════════════════════╗"
    echo "║          Git Repository Batch Updater                          ║"
    echo "╚════════════════════════════════════════════════════════════════╝"
    echo ""
    print_info "Scanning for git repositories in: $start_dir"
    echo ""

    # Find all git repositories in current directory (non-recursive by default)
    # Use maxdepth 2 to check immediate subdirectories only
    while IFS= read -r -d '' repo_dir; do
        repo_dir=$(dirname "$repo_dir")
        repos_found=$((repos_found + 1))

        if update_repo "$repo_dir"; then
            repos_updated=$((repos_updated + 1))
        else
            # Check if it was skipped or failed
            if git -C "$repo_dir" diff-index --quiet HEAD -- 2>/dev/null; then
                repos_failed=$((repos_failed + 1))
            else
                repos_skipped=$((repos_skipped + 1))
            fi
        fi

        cd "$start_dir"
    done < <(find . -maxdepth 2 -name ".git" -type d -print0 2>/dev/null)

    # Print summary
    echo ""
    echo "════════════════════════════════════════════════════════════════"
    echo "                           SUMMARY"
    echo "════════════════════════════════════════════════════════════════"
    echo -e "Total repositories found:    ${BLUE}$repos_found${NC}"
    echo -e "Successfully updated:        ${GREEN}$repos_updated${NC}"

    if [ $repos_skipped -gt 0 ]; then
        echo -e "Skipped (uncommitted):       ${YELLOW}$repos_skipped${NC}"
    fi

    if [ $repos_failed -gt 0 ]; then
        echo -e "Failed:                      ${RED}$repos_failed${NC}"
    fi

    echo "════════════════════════════════════════════════════════════════"

    if [ $repos_found -eq 0 ]; then
        echo ""
        print_warning "No git repositories found in current directory."
        print_info "Make sure you're running this script from a directory containing git repositories."
        exit 0
    fi
}

# Run main function
main
