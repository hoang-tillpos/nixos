#!/usr/bin/env bash
# Back up machine state to Google Drive BEFORE a fresh NixOS reinstall.
# Pairs with restore-gdrive.sh. See REINSTALL.md §0.
set -euo pipefail

REMOTE="hoang"
# Store the backup inside the already-synced dev folder (rides along with the ~/dev bisync).
BACKUP="${REMOTE}:dev/_reinstall-backup"
# Force overwrite: --ignore-times re-transfers every file even if size/modtime match.
FORCE="--ignore-times"
info() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m!!\033[0m  %s\n' "$*"; }

command -v rclone >/dev/null || { warn "rclone not found"; exit 1; }
if ! rclone listremotes | grep -qx "${REMOTE}:"; then
  warn "rclone remote '${REMOTE}:' not configured — run 'rclone config' first."; exit 1
fi

# 1. Push latest ~/dev to the remote (one-way copy: uploads local, never deletes remote,
#    no bisync baseline needed). Restore re-seeds the two-way bisync with --resync.
info "Pushing ~/dev to gdrive ..."
rclone copy "${HOME}/dev" "${REMOTE}:dev" -P ${FORCE} \
  --exclude "node_modules/**" --exclude ".git/**" --exclude ".venv/**" \
  --exclude "_reinstall-backup/**" \
  || warn "dev push skipped/failed (continuing)"

# 2. Claude Code state — named sessions, history, settings, MCP, plugins.
#    --links stores symlinks (e.g. skills/*) as .rclonelink so they round-trip on restore.
info "Backing up ~/.claude ..."
rclone copy "${HOME}/.claude" "${BACKUP}/claude" -P ${FORCE} --links \
  --exclude "cache/**" --exclude "shell-snapshots/**" \
  --exclude "paste-cache/**" --exclude "telemetry/**"

# 3. SSH keys
info "Backing up ~/.ssh ..."
rclone copy "${HOME}/.ssh" "${BACKUP}/ssh" -P ${FORCE}

# 4. GPG secret keys (only if any exist)
if command -v gpg >/dev/null && gpg --list-secret-keys >/dev/null 2>&1; then
  info "Exporting + backing up GPG secret keys ..."
  tmp="$(mktemp -d)"
  gpg --export-secret-keys --armor > "${tmp}/gpg-secret.asc"
  rclone copy "${tmp}/gpg-secret.asc" "${BACKUP}/" -P ${FORCE}
  shred -u "${tmp}/gpg-secret.asc"; rmdir "${tmp}"
fi

# 5. Chrome profile (optional)
if [ -d "${HOME}/.config/google-chrome" ]; then
  info "Backing up Chrome profile ..."
  rclone copy "${HOME}/.config/google-chrome" "${BACKUP}/chrome" -P ${FORCE}
fi

info "Done. Also push your config repo:  cd ~/nixos && git push"
warn "Note: this uploads SSH/GPG keys + Claude credentials to Drive in the clear."
