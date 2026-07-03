#!/usr/bin/env bash
# Back up machine state to Google Drive BEFORE a fresh NixOS reinstall.
# Pairs with restore-gdrive.sh. See REINSTALL.md §0.
set -euo pipefail

REMOTE="hoang"
# Store the backup inside the already-synced dev folder (rides along with the ~/dev bisync).
BACKUP="${REMOTE}:dev/_reinstall-backup"
info() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m!!\033[0m  %s\n' "$*"; }

command -v rclone >/dev/null || { warn "rclone not found"; exit 1; }
if ! rclone listremotes | grep -qx "${REMOTE}:"; then
  warn "rclone remote '${REMOTE}:' not configured — run 'rclone config' first."; exit 1
fi

# 1. Push latest ~/dev (bisync'd already; sync newest first)
info "Syncing ~/dev to gdrive ..."
rclone bisync "${REMOTE}:dev" "${HOME}/dev" --resilient || warn "dev bisync skipped/failed (continuing)"

# 2. Claude Code state — named sessions, history, settings, MCP, plugins
info "Backing up ~/.claude ..."
rclone copy "${HOME}/.claude" "${BACKUP}/claude" -P \
  --exclude "cache/**" --exclude "shell-snapshots/**" \
  --exclude "paste-cache/**" --exclude "telemetry/**"

# 3. SSH keys
info "Backing up ~/.ssh ..."
rclone copy "${HOME}/.ssh" "${BACKUP}/ssh" -P

# 4. GPG secret keys (only if any exist)
if command -v gpg >/dev/null && gpg --list-secret-keys >/dev/null 2>&1; then
  info "Exporting + backing up GPG secret keys ..."
  tmp="$(mktemp -d)"
  gpg --export-secret-keys --armor > "${tmp}/gpg-secret.asc"
  rclone copy "${tmp}/gpg-secret.asc" "${BACKUP}/" -P
  shred -u "${tmp}/gpg-secret.asc"; rmdir "${tmp}"
fi

# 5. Chrome profile (optional)
if [ -d "${HOME}/.config/google-chrome" ]; then
  info "Backing up Chrome profile ..."
  rclone copy "${HOME}/.config/google-chrome" "${BACKUP}/chrome" -P
fi

info "Done. Also push your config repo:  cd ~/nixos && git push"
warn "Note: this uploads SSH/GPG keys + Claude credentials to Drive in the clear."
