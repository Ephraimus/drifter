#!/usr/bin/env bash
set -euo pipefail

printf 'WARNING: this removes current shell config files after you already created a backup.\n'
printf 'Type YES to continue: '
read -r reply
[ "$reply" = "YES" ] || { printf 'Cancelled.\n'; exit 1; }

rm -f "$HOME/.bashrc" "$HOME/.bash_profile" "$HOME/.zshrc" "$HOME/.zprofile" "$HOME/.config/fish/config.fish" "$HOME/.config/starship.toml"
rm -rf "$HOME/.config/shell"

printf 'Hard reset completed.\n'
