#!/usr/bin/env bash
set -euo pipefail

mkdir -p "$HOME/.config/fish"

move_to_legacy() {
  local src="$1"
  local dst="$2"
  [ -e "$src" ] || return 0
  [ -e "$dst" ] && rm -f "$dst"
  mv "$src" "$dst"
}

move_to_legacy "$HOME/.bashrc" "$HOME/.bashrc.legacy"
move_to_legacy "$HOME/.bash_profile" "$HOME/.bash_profile.legacy"
move_to_legacy "$HOME/.zshrc" "$HOME/.zshrc.legacy"
move_to_legacy "$HOME/.zprofile" "$HOME/.zprofile.legacy"
move_to_legacy "$HOME/.config/fish/config.fish" "$HOME/.config/fish/config.fish.legacy"

printf 'Soft reset completed. Existing configs renamed to *.legacy\n'
