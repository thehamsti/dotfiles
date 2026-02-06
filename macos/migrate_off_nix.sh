#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DOTFILES_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

timestamp() { date +"%Y%m%d-%H%M%S"; }

log() { printf "%s\n" "$*"; }
die() { printf "error: %s\n" "$*" >&2; exit 1; }

AUTO_YES=0
NONINTERACTIVE=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    -y|--yes)
      AUTO_YES=1
      shift
      ;;
    --noninteractive)
      NONINTERACTIVE=1
      shift
      ;;
    -h|--help)
      cat <<'EOF'
Usage: migrate_off_nix.sh [--yes] [--noninteractive]

--yes            Skip the initial confirmation prompt.
--noninteractive Fail fast if sudo prompts for a password and use noninteractive
                 modes where available (Homebrew installer, nix-installer).
EOF
      exit 0
      ;;
    *)
      die "unknown argument: $1"
      ;;
  esac
done

confirm() {
  local prompt="$1"
  if [[ "$AUTO_YES" == "1" ]]; then
    return 0
  fi
  read -r -p "$prompt [y/N] " answer
  [[ "${answer:-}" == "y" || "${answer:-}" == "Y" ]]
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "missing required command: $1"
}

if [[ "$(uname -s)" != "Darwin" ]]; then
  die "this script is for macOS only"
fi

if [[ "$(uname -m)" != "arm64" ]]; then
  die "this script currently supports Apple Silicon only (arm64)"
fi

require_cmd sudo
require_cmd curl

BACKUP_DIR="$DOTFILES_DIR/logs/migrate_off_nix_$(timestamp)"
mkdir -p "$BACKUP_DIR"

have_cmd() { command -v "$1" >/dev/null 2>&1; }

find_nix_bin() {
  local candidates=()

  if have_cmd nix; then
    candidates+=("$(command -v nix)")
  fi

  # Common Nix locations (best-effort; depends on installer / nix-darwin).
  candidates+=(
    "/nix/var/nix/profiles/default/bin/nix"
    "/run/current-system/sw/bin/nix"
    "/nix/var/nix/profiles/system/sw/bin/nix"
  )

  local c
  for c in "${candidates[@]}"; do
    if [[ -x "$c" ]]; then
      printf "%s\n" "$c"
      return 0
    fi
  done

  return 1
}

uninstall_nix_darwin_if_present() {
  # Determinate nix-installer refuses to uninstall Nix while nix-darwin is installed.
  # See: https://github.com/LnL7/nix-darwin#uninstalling
  if [[ ! -d "/etc/nix-darwin" && ! -x "/run/current-system/sw/bin/darwin-uninstaller" ]] && ! have_cmd darwin-uninstaller; then
    return 0
  fi

  log ""
  log "== Uninstall nix-darwin (required before uninstalling Nix) =="
  log "nix-darwin installation detected."

  local -a cmd=()
  if [[ -x "/run/current-system/sw/bin/darwin-uninstaller" ]]; then
    cmd=(sudo /run/current-system/sw/bin/darwin-uninstaller)
  elif have_cmd darwin-uninstaller; then
    cmd=(sudo "$(command -v darwin-uninstaller)")
  else
    local nix_bin
    if ! nix_bin="$(find_nix_bin)"; then
      die "nix-darwin detected, but 'nix' was not found. Uninstall nix-darwin manually per https://github.com/LnL7/nix-darwin#uninstalling, then re-run."
    fi

    cmd=(sudo "$nix_bin" --extra-experimental-features "nix-command flakes" run nix-darwin#darwin-uninstaller)
  fi

  log "Running: ${cmd[*]}"
  local status=0
  if [[ "$AUTO_YES" == "1" ]]; then
    # Ensure sudo has a cached credential before piping to avoid feeding "y" as a password.
    sudo -v
    yes | "${cmd[@]}" || status=$?
  else
    "${cmd[@]}" || status=$?
  fi

  if [[ "$status" != "0" ]]; then
    # darwin-uninstaller may exit non-zero even when it successfully removes nix-darwin.
    # The nix-installer check is effectively satisfied once /etc/nix-darwin is gone.
    if [[ ! -d "/etc/nix-darwin" ]]; then
      log "Warning: nix-darwin uninstaller exited with status $status, but /etc/nix-darwin is gone; continuing."
      return 0
    fi

    die "failed to uninstall nix-darwin. Follow https://github.com/LnL7/nix-darwin#uninstalling, then re-run."
  fi
}

log "== Migrate Off Nix (macOS) =="
log ""
log "This will:"
log "1) Back up current (Nix-managed) Homebrew state to:"
log "   $BACKUP_DIR"
log "2) Move aside Nix-managed Homebrew prefixes (/opt/homebrew and /usr/local/Homebrew if present)"
log "3) Install official Homebrew to /opt/homebrew"
log "4) Reinstall packages from:"
log "   $DOTFILES_DIR/macos/Brewfile"
log "5) Uninstall nix-darwin (if installed)"
log "6) Uninstall Nix via /nix/nix-installer uninstall"
log ""

if ! confirm "Proceed?"; then
  log "Aborted."
  exit 0
fi

if [[ "$NONINTERACTIVE" == "1" ]]; then
  # Fail early rather than hanging on a password prompt in non-interactive contexts.
  if ! sudo -n true 2>/dev/null; then
    die "sudo requires a password. Re-run this script in an interactive terminal (without --noninteractive)."
  fi
fi

log ""
log "== Backup =="
{
  log "Date: $(date)"
  log "User: $(id -un)"
  log "Arch: $(uname -m)"
  log "macOS: $(sw_vers | tr '\n' ' ' | sed 's/[[:space:]]\\+/ /g')"
  log ""
  log "brew locations:"
  type -a brew || true
} >"$BACKUP_DIR/system.txt" 2>&1

if command -v brew >/dev/null 2>&1; then
  {
    brew --prefix
    brew config
  } >"$BACKUP_DIR/brew_config.txt" 2>&1 || true

  brew list --formula >"$BACKUP_DIR/brew_formula.txt" 2>/dev/null || true
  brew list --cask >"$BACKUP_DIR/brew_cask.txt" 2>/dev/null || true
  brew tap >"$BACKUP_DIR/brew_taps.txt" 2>/dev/null || true

  # Best-effort: capture an exact Brewfile of what's currently installed.
  if brew bundle dump --help >/dev/null 2>&1; then
    brew bundle dump --file="$BACKUP_DIR/Brewfile.dump" --force >/dev/null 2>&1 || true
  fi
fi

log "Backed up state to $BACKUP_DIR"

log ""
log "== Remove Nix-Managed Homebrew Prefixes =="
if [[ -d "/opt/homebrew/Library/.homebrew-is-managed-by-nix" ]]; then
  dest="/opt/homebrew.nix-homebrew.bak.$(timestamp)"
  log "Moving /opt/homebrew -> $dest"
  sudo mv /opt/homebrew "$dest"
fi

if [[ -d "/usr/local/Homebrew/Library/.homebrew-is-managed-by-nix" ]]; then
  dest="/usr/local/Homebrew.nix-homebrew.bak.$(timestamp)"
  log "Moving /usr/local/Homebrew -> $dest"
  sudo mv /usr/local/Homebrew "$dest"
fi

# Remove any brew shim that points into the Nix store to avoid picking the wrong brew later.
if [[ -L "/usr/local/bin/brew" ]] && readlink /usr/local/bin/brew | grep -qE "^/nix/store/"; then
  log "Removing /usr/local/bin/brew (Nix shim)"
  sudo rm -f /usr/local/bin/brew
fi

log ""
log "== Install Official Homebrew =="
if [[ -x "/opt/homebrew/bin/brew" ]]; then
  log "Homebrew already present at /opt/homebrew/bin/brew"
else
  if [[ "$NONINTERACTIVE" == "1" ]]; then
    NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  else
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  fi
fi

eval "$(/opt/homebrew/bin/brew shellenv)"

# Ensure future shells pick up Homebrew.
if [[ -f "$HOME/.zprofile" ]]; then
  if ! grep -qF "/opt/homebrew/bin/brew shellenv" "$HOME/.zprofile"; then
    {
      printf "\n# Homebrew (Apple Silicon)\n"
      printf "eval \"$(/opt/homebrew/bin/brew shellenv)\"\n"
    } >>"$HOME/.zprofile"
  fi
else
  {
    printf "# Homebrew (Apple Silicon)\n"
    printf "eval \"$(/opt/homebrew/bin/brew shellenv)\"\n"
  } >"$HOME/.zprofile"
fi

log ""
log "== Install Packages (Brewfile) =="
brew bundle --file="$DOTFILES_DIR/macos/Brewfile"

log ""
uninstall_nix_darwin_if_present

log ""
log "== Optional Cleanup (nix-darwin activate-system) =="
if [[ -f "/Library/LaunchDaemons/org.nixos.activate-system.plist" ]]; then
  log "Disabling org.nixos.activate-system LaunchDaemon"
  sudo launchctl bootout system /Library/LaunchDaemons/org.nixos.activate-system.plist 2>/dev/null || true
  sudo rm -f /Library/LaunchDaemons/org.nixos.activate-system.plist
fi

log ""
log "== Uninstall Nix =="
if [[ -x "/nix/nix-installer" ]]; then
  log "Running: sudo /nix/nix-installer uninstall"
  if [[ "$NONINTERACTIVE" == "1" ]]; then
    sudo /nix/nix-installer uninstall --no-confirm
  else
    sudo /nix/nix-installer uninstall
  fi
else
  log "Nix installer not found at /nix/nix-installer; skipping uninstall step"
fi

log ""
log "Done."
log "If anything looks odd, your pre-migration backup is at:"
log "  $BACKUP_DIR"
