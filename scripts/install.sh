#!/usr/bin/env bash
set -Eeuo pipefail

log() { printf '\n[%s] %s\n' "INFO" "$*"; }
die() { printf '\n[%s] %s\n' "ERROR" "$*" >&2; exit 1; }

REPO_USER="Ephraimus"
REPO_NAME="chezmoi"
REPO_BRANCH="main"

BOOTSTRAP_URL="https://raw.githubusercontent.com/${REPO_USER}/${REPO_NAME}/${REPO_BRANCH}/scripts/bootstrap-remote.sh"
DEFAULT_HTTPS_URL="https://github.com/${REPO_USER}/${REPO_NAME}.git"

command -v curl >/dev/null 2>&1 || {
  log "curl not found, attempting to install..."
  if command -v apt-get >/dev/null 2>&1; then
    sudo apt-get update -y && sudo apt-get install -y curl
  elif command -v dnf >/dev/null 2>&1; then
    sudo dnf install -y curl
  elif command -v pacman >/dev/null 2>&1; then
    sudo pacman -Sy --noconfirm curl
  else
    die "Please install curl manually and try again."
  fi
}

log "Fetching bootstrap-remote.sh from $BOOTSTRAP_URL..."

curl -fsSL "$BOOTSTRAP_URL" | bash -s -- --repo-url "$DEFAULT_HTTPS_URL" --repo-branch "$REPO_BRANCH" "$@"
