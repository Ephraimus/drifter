#!/usr/bin/env bash
set -euo pipefail

backup_dir="$HOME/.shell-migration-backup/$(date +%Y%m%d-%H%M%S)"
mkdir -p "$backup_dir"

copy_if_exists() {
  [ -e "$1" ] && cp -a "$1" "$backup_dir/" || true
}

copy_if_exists "$HOME/.bashrc"
copy_if_exists "$HOME/.bash_profile"
copy_if_exists "$HOME/.profile"
copy_if_exists "$HOME/.zshrc"
copy_if_exists "$HOME/.zprofile"
copy_if_exists "$HOME/.config/fish/config.fish"
copy_if_exists "$HOME/.config/starship.toml"
copy_if_exists "$HOME/.p10k.zsh"

printf 'Backup saved to %s\n' "$backup_dir"
