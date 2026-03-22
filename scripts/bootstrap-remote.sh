#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_PATH="${BASH_SOURCE[0]:-}"
SCRIPT_DIR=""
CANDIDATE_SOURCE=""
if [ -n "$SCRIPT_PATH" ] && [ -f "$SCRIPT_PATH" ]; then
  SCRIPT_DIR="$(cd -- "$(dirname -- "$SCRIPT_PATH")" && pwd)"
  CANDIDATE_SOURCE="$(cd -- "$SCRIPT_DIR/.." && pwd)"
fi

CHEZMOI_SOURCE_DIR="${CANDIDATE_SOURCE:-}"
CHEZMOI_DEST_DIR="${HOME}/.local/share/chezmoi"
LOCAL_BIN_DIR="${HOME}/.local/bin"
LOCAL_DATA_DIR="${HOME}/.local/share"
LOCAL_CONFIG_DIR="${HOME}/.config/chezmoi"
USE_FISH=false
SKIP_PACKAGES=false
SKIP_BACKUP=false
SKIP_RESET=false
RESET_MODE="soft"
ASSUME_YES=false
SET_LOGIN_SHELL="skip"
REPO_URL="https://github.com/Ephraimus/drifter.git"
REPO_BRANCH="main"
MODE=""

log() { printf '\n[%s] %s\n' "INFO" "$*"; }
warn() { printf '\n[%s] %s\n' "WARN" "$*" >&2; }
die() { printf '\n[%s] %s\n' "ERROR" "$*" >&2; exit 1; }

usage() {
  cat <<USAGE
Usage:
  bootstrap-remote.sh [options]

How to use:
  1) From a copied starter-kit on the remote host:
     bash bootstrap-remote.sh --starter-kit-dir /tmp/chezmoi-starter-kit

  2) Through SSH stdin with your git repo:
     cat bootstrap-remote.sh | ssh user@host 'bash -s -- --repo-url git@github.com:Ephraimus/dotfiles.git --repo-branch main'

Modes:
  --starter-kit-dir DIR    Use a local starter-kit directory already present on the remote host
  --repo-url URL           Use a chezmoi git repository directly
  --repo-branch BRANCH     Optional branch for --repo-url

Behavior:
  --use-fish               Install fish and enable fish config in chezmoi data
  --reset-mode MODE        soft|hard (default: soft)
  --set-login-shell SHELL  bash|fish|zsh|skip (default: skip)
  --skip-packages          Do not install system packages
  --skip-backup            Do not backup current shell configs
  --skip-reset             Do not rename/remove current shell configs
  -y, --yes                Non-interactive mode; required for hard reset without prompt
  -h, --help               Show this help
USAGE
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --starter-kit-dir|--source-dir)
      [ "$#" -ge 2 ] || die "Missing value for $1"
      CHEZMOI_SOURCE_DIR="$2"
      MODE="local"
      shift 2
      ;;
    --repo-url)
      [ "$#" -ge 2 ] || die "Missing value for --repo-url"
      REPO_URL="$2"
      MODE="repo"
      shift 2
      ;;
    --repo-branch)
      [ "$#" -ge 2 ] || die "Missing value for --repo-branch"
      REPO_BRANCH="$2"
      shift 2
      ;;
    --use-fish)
      USE_FISH=true
      shift
      ;;
    --reset-mode)
      [ "$#" -ge 2 ] || die "Missing value for --reset-mode"
      RESET_MODE="$2"
      shift 2
      ;;
    --set-login-shell)
      [ "$#" -ge 2 ] || die "Missing value for --set-login-shell"
      SET_LOGIN_SHELL="$2"
      shift 2
      ;;
    --skip-packages)
      SKIP_PACKAGES=true
      shift
      ;;
    --skip-backup)
      SKIP_BACKUP=true
      shift
      ;;
    --skip-reset)
      SKIP_RESET=true
      shift
      ;;
    -y|--yes)
      ASSUME_YES=true
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      die "Unknown argument: $1"
      ;;
  esac
done

case "$RESET_MODE" in
  soft|hard) ;;
  *) die "--reset-mode must be soft or hard" ;;
esac

case "$SET_LOGIN_SHELL" in
  bash|fish|zsh|skip) ;;
  *) die "--set-login-shell must be bash, fish, zsh, or skip" ;;
esac

command_exists() { command -v "$1" >/dev/null 2>&1; }

has_starter_kit() {
  [ -n "${CHEZMOI_SOURCE_DIR:-}" ] && [ -d "$CHEZMOI_SOURCE_DIR" ] && [ -f "$CHEZMOI_SOURCE_DIR/dot_bashrc.tmpl" ]
}

if [ -z "$MODE" ]; then
  if has_starter_kit; then
    MODE="local"
  elif [ -n "$REPO_URL" ]; then
    MODE="repo"
  else
    usage >&2
    die "Choose either --starter-kit-dir DIR or --repo-url URL"
  fi
fi

run_as_root() {
  if [ "$(id -u)" -eq 0 ]; then
    "$@"
  elif command_exists sudo; then
    sudo "$@"
  else
    die "Need root privileges for package installation, but sudo is not available"
  fi
}

ensure_local_bin_on_path() {
  mkdir -p "$LOCAL_BIN_DIR"
  case ":$PATH:" in
    *":$LOCAL_BIN_DIR:"*) ;;
    *) export PATH="$LOCAL_BIN_DIR:$PATH" ;;
  esac
}

is_wsl() {
  grep -qiE '(microsoft|wsl)' /proc/version 2>/dev/null || [ -n "${WSL_DISTRO_NAME:-}" ]
}

detect_pm() {
  if command_exists apt-get; then
    printf 'apt'
  elif command_exists dnf; then
    printf 'dnf'
  elif command_exists yum; then
    printf 'yum'
  elif command_exists pacman; then
    printf 'pacman'
  elif command_exists zypper; then
    printf 'zypper'
  elif command_exists apk; then
    printf 'apk'
  else
    printf 'unknown'
  fi
}

install_packages() {
  local pm packages common_packages shell_packages
  pm="$(detect_pm)"
  common_packages=(git curl unzip ca-certificates fzf bat eza zoxide ripgrep fd-find)
  shell_packages=(bash-completion zsh)
  $USE_FISH && shell_packages+=(fish)
  packages=("${common_packages[@]}" "${shell_packages[@]}")

  case "$pm" in
    apt)
      log "Installing packages via apt"
      run_as_root apt-get update -y
      run_as_root env DEBIAN_FRONTEND=noninteractive apt-get install -y "${packages[@]}"
      ;;
    dnf)
      log "Installing packages via dnf"
      run_as_root dnf install -y "${packages[@]}"
      ;;
    yum)
      log "Installing packages via yum"
      run_as_root yum install -y "${packages[@]}"
      ;;
    pacman)
      log "Installing packages via pacman"
      run_as_root pacman -Sy --noconfirm --needed "${packages[@]}"
      ;;
    zypper)
      log "Installing packages via zypper"
      run_as_root zypper --non-interactive install "${packages[@]}"
      ;;
    apk)
      log "Installing packages via apk"
      run_as_root apk add --no-cache "${packages[@]}"
      ;;
    *)
      warn "Unsupported package manager. Install manually: git curl unzip ca-certificates fzf bash-completion zsh$( $USE_FISH && printf ' fish' )"
      ;;
  esac
}

install_chezmoi() {
  if command_exists chezmoi; then
    log "chezmoi already installed: $(command -v chezmoi)"
    return 0
  fi
  command_exists curl || die "curl is required to install chezmoi"
  ensure_local_bin_on_path
  log "Installing chezmoi into $LOCAL_BIN_DIR"
  sh -c "$(curl -fsLS https://get.chezmoi.io)" -- -b "$LOCAL_BIN_DIR"
}

install_starship() {
  if command_exists starship; then
    log "starship already installed: $(command -v starship)"
    return 0
  fi
  command_exists curl || die "curl is required to install starship"
  ensure_local_bin_on_path
  log "Installing starship into $LOCAL_BIN_DIR"
  curl -fsSL https://starship.rs/install.sh | sh -s -- -y -b "$LOCAL_BIN_DIR"
}

install_blesh() {
  local target_dir
  target_dir="$LOCAL_DATA_DIR/blesh"
  if [ -f "$target_dir/ble.sh" ] || [ -f "$target_dir/out/ble.sh" ]; then
    log "ble.sh already present: $target_dir"
    return 0
  fi
  command_exists git || die "git is required to install ble.sh"
  mkdir -p "$LOCAL_DATA_DIR"
  log "Installing ble.sh into $target_dir"
  rm -rf "$target_dir"
  git clone --depth 1 https://github.com/akinomyoga/ble.sh.git "$target_dir"
}

move_to_legacy() {
  local src="$1" dst="$2"
  [ -e "$src" ] || return 0
  [ -e "$dst" ] && rm -rf "$dst"
  mv "$src" "$dst"
}

backup_current_configs() {
  if [ "$MODE" = "local" ] && [ -x "$CHEZMOI_SOURCE_DIR/scripts/backup-shell-configs.sh" ]; then
    log "Running packaged backup script"
    "$CHEZMOI_SOURCE_DIR/scripts/backup-shell-configs.sh"
    return 0
  fi

  local backup_dir
  backup_dir="$HOME/.shell-migration-backup/$(date +%Y%m%d-%H%M%S)"
  mkdir -p "$backup_dir"
  for path in \
    "$HOME/.bashrc" \
    "$HOME/.bash_profile" \
    "$HOME/.profile" \
    "$HOME/.zshrc" \
    "$HOME/.zprofile" \
    "$HOME/.config/fish/config.fish" \
    "$HOME/.config/starship.toml" \
    "$HOME/.p10k.zsh"
  do
    [ -e "$path" ] && cp -a "$path" "$backup_dir/"
  done
  printf 'Backup saved to %s\n' "$backup_dir"
}

run_reset() {
  if [ "$SKIP_RESET" = true ]; then
    log "Skipping reset step"
    return 0
  fi

  if [ "$RESET_MODE" = "hard" ] && [ "$ASSUME_YES" != true ]; then
    die "Hard reset requires -y/--yes"
  fi

  if [ "$MODE" = "local" ]; then
    case "$RESET_MODE" in
      soft)
        if [ -x "$CHEZMOI_SOURCE_DIR/scripts/soft-reset-shell-configs.sh" ]; then
          log "Running packaged soft reset"
          "$CHEZMOI_SOURCE_DIR/scripts/soft-reset-shell-configs.sh"
          return 0
        fi
        ;;
      hard)
        if [ -x "$CHEZMOI_SOURCE_DIR/scripts/hard-reset-shell-configs.sh" ]; then
          log "Running packaged hard reset"
          printf 'YES\n' | "$CHEZMOI_SOURCE_DIR/scripts/hard-reset-shell-configs.sh"
          return 0
        fi
        ;;
    esac
  fi

  mkdir -p "$HOME/.config/fish"
  if [ "$RESET_MODE" = "soft" ]; then
    move_to_legacy "$HOME/.bashrc" "$HOME/.bashrc.legacy"
    move_to_legacy "$HOME/.bash_profile" "$HOME/.bash_profile.legacy"
    move_to_legacy "$HOME/.zshrc" "$HOME/.zshrc.legacy"
    move_to_legacy "$HOME/.zprofile" "$HOME/.zprofile.legacy"
    move_to_legacy "$HOME/.config/fish/config.fish" "$HOME/.config/fish/config.fish.legacy"
    log "Soft reset completed"
  else
    rm -f "$HOME/.bashrc" "$HOME/.bash_profile" "$HOME/.zshrc" "$HOME/.zprofile" "$HOME/.config/fish/config.fish" "$HOME/.config/starship.toml"
    rm -rf "$HOME/.config/shell"
    log "Hard reset completed"
  fi
}

write_local_chezmoi_data() {
  mkdir -p "$LOCAL_CONFIG_DIR"
  cat > "$LOCAL_CONFIG_DIR/chezmoi.toml" <<EOF_DATA
[data]
use_fish = $USE_FISH
legacy_bash = true
legacy_zsh = true
use_blesh = true
machine_role = "$(hostname -s 2>/dev/null || hostname)"
EOF_DATA
  log "Wrote local chezmoi data: $LOCAL_CONFIG_DIR/chezmoi.toml"
}

apply_local_starter_kit() {
  has_starter_kit || die "Starter-kit directory not found or incomplete: $CHEZMOI_SOURCE_DIR"
  mkdir -p "$CHEZMOI_DEST_DIR"
  rm -rf "$CHEZMOI_DEST_DIR"
  mkdir -p "$CHEZMOI_DEST_DIR"
  cp -a "$CHEZMOI_SOURCE_DIR"/. "$CHEZMOI_DEST_DIR"/
  log "Copied starter-kit to $CHEZMOI_DEST_DIR"
  chezmoi apply --force --source "$CHEZMOI_DEST_DIR"
}

apply_repo() {
  [ -n "$REPO_URL" ] || die "--repo-url is empty"
  if [ -n "$REPO_BRANCH" ]; then
    chezmoi init --apply --branch "$REPO_BRANCH" "$REPO_URL"
  else
    chezmoi init --apply "$REPO_URL"
  fi
}

set_default_shell_if_requested() {
  [ "$SET_LOGIN_SHELL" != "skip" ] || return 0

  local shell_path
  shell_path="$(command -v "$SET_LOGIN_SHELL" || true)"
  [ -n "$shell_path" ] || die "Requested shell is not installed: $SET_LOGIN_SHELL"

  if [ ! -r /etc/shells ] || ! grep -qx "$shell_path" /etc/shells; then
    warn "$shell_path is not present in /etc/shells. Skipping chsh."
    return 0
  fi

  if command_exists chsh; then
    log "Changing login shell to $shell_path"
    chsh -s "$shell_path" || warn "chsh failed; keep current login shell"
  else
    warn "chsh not available; keep current login shell"
  fi
}

post_install_report() {
  cat <<REPORT

Done.

What was performed:
  - package install: $([ "$SKIP_PACKAGES" = true ] && printf 'skipped' || printf 'attempted')
  - backup: $([ "$SKIP_BACKUP" = true ] && printf 'skipped' || printf 'created')
  - reset mode: $([ "$SKIP_RESET" = true ] && printf 'skipped' || printf '%s' "$RESET_MODE")
  - source mode: $MODE
  - source dir: ${CHEZMOI_SOURCE_DIR:-<repo>}
  - use_fish: $USE_FISH
  - login shell: $SET_LOGIN_SHELL

Next steps:
  1. Start a new shell session or reconnect over SSH.
  2. Verify prompt and completion in bash.
  3. If using Windows Terminal, make sure your profile uses a Nerd Font.
  4. If anything looks wrong, restore files from ~/.shell-migration-backup.
REPORT
}

main() {
  ensure_local_bin_on_path

  # Print source info banner so the user always knows the exact origin of the config being applied
  printf '\n'
  printf '  ====================================================\n'
  printf '  🌍 Drifter — Unified Terminal Starter Kit\n'
  printf '  Source mode : %s\n' "$MODE"
  if [ "$MODE" = "repo" ]; then
    printf '  Repo URL    : %s\n' "$REPO_URL"
    printf '  Branch      : %s\n' "$REPO_BRANCH"
  else
    printf '  Source dir  : %s\n' "${CHEZMOI_SOURCE_DIR:-local}"
  fi
  printf '  ====================================================\n'
  printf '\n'

  if is_wsl; then
    log "WSL detected"
  else
    log "Running on regular Linux"
  fi

  if [ "$SKIP_PACKAGES" != true ]; then
    log "[Step 1/6] Installing system packages ..."
    install_packages
  else
    log "[Step 1/6] Skipping package installation (--skip-packages)"
  fi

  log "[Step 2/6] Installing chezmoi ..."
  install_chezmoi
  log "[Step 3/6] Installing Starship prompt ..."
  install_starship
  log "[Step 4/6] Installing ble.sh (Bash Line Editor) ..."
  install_blesh
  log "[Step 4/6] Writing local chezmoi machine data ..."
  write_local_chezmoi_data

  if [ "$SKIP_BACKUP" != true ]; then
    log "[Step 5/6] Backing up current shell configs ..."
    backup_current_configs
  else
    log "[Step 5/6] Skipping backup (--skip-backup)"
  fi

  log "[Step 6/6] Applying shell reset (mode: $RESET_MODE) ..."
  run_reset

  log "Applying chezmoi source to home directory ..."
  case "$MODE" in
    local) apply_local_starter_kit ;;
    repo) apply_repo ;;
    *) die "Unsupported mode: $MODE" ;;
  esac

  set_default_shell_if_requested
  post_install_report
}

main "$@"
