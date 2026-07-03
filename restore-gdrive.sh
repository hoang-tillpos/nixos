#!/usr/bin/env bash
# Restore machine state from Google Drive AFTER a fresh NixOS reinstall,
# and seed the recurring ~/dev <-> gdrive sync.
# Pairs with backup-gdrive.sh. See REINSTALL.md §8. Run as user 'hle'.
set -euo pipefail

REMOTE="hoang"
# Backup lives inside the dev folder (same remote you already use for the ~/dev sync).
BACKUP="${REMOTE}:dev/_reinstall-backup"
# Force overwrite: --ignore-times re-transfers every file even if size/modtime match.
FORCE="--ignore-times"
info() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m!!\033[0m  %s\n' "$*"; }

command -v rclone >/dev/null || { warn "rclone not found (run nixos-rebuild first?)"; exit 1; }

# 1. Ensure the gdrive remote exists. It's the SAME 'hoang' remote used for the ~/dev sync,
#    but a fresh system has no rclone.conf yet, so it must be re-authed once.
if ! rclone listremotes | grep -qx "${REMOTE}:"; then
  warn "rclone remote '${REMOTE}:' not configured on this fresh system."
  warn "Run:  rclone config   -> n (new) -> name it '${REMOTE}' -> 'drive' -> browser OAuth"
  warn "Then re-run this script."
  exit 1
fi
info "Verifying access to ${BACKUP} ..."
rclone lsd "${BACKUP}" >/dev/null

# 2. Claude Code state -> restores your named sessions (home unchanged at /home/hle).
#    --links recreates the skills/* symlinks from their .rclonelink placeholders.
info "Restoring ~/.claude ..."
rclone copy "${BACKUP}/claude" "${HOME}/.claude" -P ${FORCE} --links

# 3. SSH keys (fix perms after copy)
if rclone lsd "${BACKUP}/ssh" >/dev/null 2>&1; then
  info "Restoring ~/.ssh ..."
  rclone copy "${BACKUP}/ssh" "${HOME}/.ssh" -P ${FORCE}
  chmod 700 "${HOME}/.ssh"
  chmod 600 "${HOME}"/.ssh/id_* 2>/dev/null || true
fi

# 4. GPG secret key
if rclone lsf "${BACKUP}" 2>/dev/null | grep -qx "gpg-secret.asc"; then
  info "Importing GPG secret key ..."
  tmp="$(mktemp -d)"
  rclone copy "${BACKUP}/gpg-secret.asc" "${tmp}" -P ${FORCE}
  gpg --import "${tmp}/gpg-secret.asc" || warn "gpg import failed (continuing)"
  shred -u "${tmp}/gpg-secret.asc"; rmdir "${tmp}"
fi

# 5. Git identity (commented out in home.nix)
info "Setting git identity ..."
git config --global user.name  "Hoang Le"
git config --global user.email "hoang.l@oolio.com"

# 6. Seed the ~/dev <-> gdrive bisync. FIRST run needs --resync to build the baseline
#    (a normal bisync errors with "cannot find prior listing" on a fresh machine).
info "Seeding ~/dev sync from gdrive (initial --resync) ..."
mkdir -p "${HOME}/dev"
rclone bisync "${REMOTE}:dev" "${HOME}/dev" --resync --create-empty-src-dirs --resilient -MvP \
  --drive-skip-gdocs --max-lock 2m \
  --exclude 'node_modules/**' --exclude '.git/**' --exclude '.venv/**'

# 7. Enable the recurring sync timer (unit is defined in home.nix)
info "Enabling rclone-gdrive-sync timer ..."
systemctl --user enable --now rclone-gdrive-sync.timer 2>/dev/null \
  || warn "Couldn't enable timer now; it starts on next login (WantedBy default.target)."

info "Done. Re-run '/login' in Claude Code if restored credentials don't authenticate."
