#!/usr/bin/env bash
# sync-all-remotes.sh
# Propagates latest chezmoi dotfile changes to all configured remote hosts via SSH.
# Requires passwordless SSH key-based authentication for all target hosts.
#
# Usage:
#   ./sync-all-remotes.sh
#
# Configuration:
#   Edit the HOSTS array below to define target servers.
#   Each entry must be in the standard SSH format: user@hostname.

set -euo pipefail

# --- Configuration: Define target remote hosts here ---
HOSTS=(
  # "user@server1.example.com"
  # "user@server2.example.com"
)

# --- Banner ---
printf '\n'
printf '  ====================================================\n'
printf '  🌍 Drifter — Remote Sync\n'
printf '  Running: chezmoi update on all configured hosts\n'
printf '  Hosts   : %d configured\n' "${#HOSTS[@]}"
printf '  ====================================================\n'
printf '\n'

# --- Validation ---
if [ "${#HOSTS[@]}" -eq 0 ]; then
  echo "[sync-all-remotes] No hosts configured. Edit the HOSTS array in this script."
  exit 1
fi

# --- Sync ---
FAILED=()
SUCCESS=()

for HOST in "${HOSTS[@]}"; do
  echo "[sync-all-remotes] → Syncing $HOST ..."
  if ssh -o ConnectTimeout=10 "$HOST" 'chezmoi update'; then
    SUCCESS+=("$HOST")
    echo "[sync-all-remotes] ✔ $HOST synced successfully."
  else
    FAILED+=("$HOST")
    echo "[sync-all-remotes] ✘ $HOST failed to sync." >&2
  fi
done

# --- Summary ---
echo ""
echo "=== Sync Summary ==="
echo "Success (${#SUCCESS[@]}): ${SUCCESS[*]:-none}"
echo "Failed  (${#FAILED[@]}): ${FAILED[*]:-none}"

if [ "${#FAILED[@]}" -gt 0 ]; then
  exit 1
fi
