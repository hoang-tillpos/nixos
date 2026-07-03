# Fresh NixOS Reinstall

End-to-end guide to wipe and reinstall this machine from this flake.
Repo: `github.com/hoang-tillpos/nixos` · Flake target: `.#hle-nixos` · Disk: single NVMe, GPT/UEFI, ext4 root.

> Read this on your phone/another machine during the wipe — the first steps run from memory.

---

## 0. Before you wipe — backup checklist

These live *outside* the repo and are gone after a wipe. Copy to an external drive or gdrive.

```bash
# Secrets & identity (NOT in the repo)
cp ~/.config/rclone/rclone.conf   /path/to/backup/   # gdrive OAuth token (rclone sync needs it)
cp -r ~/.ssh                      /path/to/backup/   # SSH keys
gpg --export-secret-keys --armor  > /path/to/backup/gpg-secret.asc   # if you use GPG

# Anything not synced to gdrive already:
#   ~/dev is bisync'd to gdrive (recoverable) — but push latest first:
rclone bisync hoang:dev ~/dev --resilient
#   Obsidian vault, browser profiles (~/.config/google-chrome), etc. — copy if not synced.
```

Verify the git repo is pushed: `cd ~/nixos && git status && git push`.

---

## 1. Download NixOS & flash the USB

**Download** the minimal ISO (x86_64) from <https://nixos.org/download/#nixos-iso>:

```bash
cd ~/Downloads
# grab the "Minimal ISO image" — 64-bit. Direct link pattern:
wget https://channels.nixos.org/nixos-unstable/latest-nixos-minimal-x86_64-linux.iso
```

**Identify the USB drive** (be certain — the next step erases it):

```bash
lsblk -o NAME,SIZE,MODEL,TRAN         # find your USB, e.g. sdb (TRAN=usb)
```

**Wipe & flash the USB** (`sdX` = your USB device, NOT a partition like `sdX1`):

```bash
USB=/dev/sdb                          # <-- set to YOUR usb device
sudo umount ${USB}?* 2>/dev/null      # unmount any mounted partitions
sudo wipefs -a $USB                   # wipe existing filesystem signatures
sudo dd if=nixos-minimal-*.iso of=$USB bs=4M conv=fsync status=progress
sync
```

> `wipefs -a` clears old partition/FS signatures so the drive boots cleanly.
> `conv=fsync` guarantees the write is flushed before `dd` returns.

**Boot it:** plug into the target machine, enter the boot menu (usually `F12`/`F11`/`Esc`), and select the USB in **UEFI mode**.

## 2. Network

```bash
# Ethernet: usually automatic. Wi-Fi:
sudo systemctl start wpa_supplicant
wpa_cli            # > add_network / set_network 0 ssid "..." / set_network 0 psk "..." / enable_network 0 / quit
ping -c1 github.com
```

## 3. Partition (replicates current layout + zram, no encryption)

⚠️ `nvme0n1` **erases the whole disk**. Confirm the device with `lsblk`.

```bash
DISK=/dev/nvme0n1
sudo parted $DISK -- mklabel gpt
sudo parted $DISK -- mkpart ESP fat32 1MiB 512MiB
sudo parted $DISK -- set 1 esp on
sudo parted $DISK -- mkpart primary 512MiB 100%
```

> No swap partition — swap is provided by **zram** (RAM-compressed), enabled in `configuration.nix`.

## 4. Format & mount

```bash
sudo mkfs.fat -F 32 -n boot /dev/nvme0n1p1
sudo mkfs.ext4 -L nixos     /dev/nvme0n1p2

sudo mount /dev/disk/by-label/nixos /mnt
sudo mkdir -p /mnt/boot
sudo mount /dev/disk/by-label/boot /mnt/boot
```

## 5. Generate hardware config & clone the repo

```bash
sudo nixos-generate-config --root /mnt        # writes /mnt/etc/nixos/hardware-configuration.nix

# Clone your config into the new system
sudo mkdir -p /mnt/home/hle
sudo git clone https://github.com/hoang-tillpos/nixos.git /mnt/home/hle/nixos

# Make the flake self-contained: copy the freshly-generated hardware config INTO the repo.
# (configuration.nix imports ./hardware-configuration.nix — see note below.)
sudo cp /mnt/etc/nixos/hardware-configuration.nix /mnt/home/hle/nixos/hardware-configuration.nix
```

> **Self-contained flake:** `configuration.nix` imports `./hardware-configuration.nix` (relative),
> so no `--impure` flag is needed. If `hardware-configuration.nix` is missing from the repo on the
> new machine, this copy step provides it.

## 6. Install

```bash
sudo nixos-install --flake /mnt/home/hle/nixos#hle-nixos --no-root-passwd
```

> First build downloads/compiles a lot (fenix Rust toolchain, etc.) — expect a long run.
> `--no-root-passwd` leaves root locked; you set the user password below.

## 7. First boot

```bash
sudo reboot                     # remove the USB
```

After boot, log in on TTY (Ctrl+Alt+F2 if the greeter misbehaves) and set your password:

```bash
sudo passwd hle
```

---

## 8. Post-install (as user `hle`)

```bash
# The cloned repo is owned by root — take ownership
sudo chown -R hle:users ~/nixos
cd ~/nixos

# Restore secrets from your backup drive
mkdir -p ~/.config/rclone ~/.ssh
cp /path/to/backup/rclone.conf ~/.config/rclone/
cp -r /path/to/backup/.ssh/*   ~/.ssh/ && chmod 600 ~/.ssh/id_*
gpg --import /path/to/backup/gpg-secret.asc      # if used

# Set git identity (commented out in home.nix, so set it manually)
git config --global user.name  "Hoang Le"
git config --global user.email "hoang.l@oolio.com"

# Wire up dotfiles (hypr, waybar, fish, nvim, swaync, wlogout, alacritty)
# NOTE: linkconfig.sh rm -rf's ~/.config/<name> then symlinks it to the repo.
bash linkconfig.sh

# Re-pull your dev workspace from gdrive
rclone bisync hoang:dev ~/dev --resilient --create-empty-src-dirs
# (the systemd user timer 'rclone-gdrive-sync' takes over from here — check with:)
systemctl --user status rclone-gdrive-sync.timer
```

---

## 9. Day-to-day rebuild (post-reinstall)

```bash
cd ~/nixos
sudo nixos-rebuild switch --flake .#hle-nixos     # no --impure needed anymore
```

---

## Notes / gotchas

- **Hostname** is `hle-nixos` — matches the flake attribute `.#hle-nixos` (previously `nixos`, now aligned).
- **Unfree/insecure packages** are already allowed in `configuration.nix` — no extra env vars needed.
- **home-manager** runs as a NixOS module, so it's applied automatically by `nixos-rebuild`/`nixos-install`. No separate `home-manager switch`.
- **`--impure` is no longer required** because the hardware config is imported relatively from the repo.
- If the graphical greeter (LightDM) fails to start, check `journalctl -b -u display-manager`. See `nixos_boot_failure_analysis.md` for a past display-manager incident.
