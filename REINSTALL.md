# Fresh NixOS Reinstall

End-to-end guide to wipe and reinstall this machine from this flake.
Repo: `github.com/hoang-tillpos/nixos` · Flake target: `.#hle-nixos` · Disk: single NVMe, GPT/UEFI, ext4 root.

> Read this on your phone/another machine during the wipe — the first steps run from memory.

---

## 0. Before you wipe — back up to Google Drive

State that lives *outside* the repo (Claude sessions, SSH/GPG keys, browser profile) is gone
after a wipe. Push it to your existing `hoang` remote, inside the already-synced dev folder
at `hoang:dev/_reinstall-backup/`, by running:

```bash
cd ~/nixos && ./backup-gdrive.sh      # backs up ~/.claude, ~/.ssh, GPG, Chrome profile
git status && git push                # and make sure the config repo is pushed
```

What it captures (see `backup-gdrive.sh`):
- **`~/.claude`** — sessions, history, settings, MCP, plugins → restores your NAMED sessions
  (e.g. `reinstall-nixos`); they resolve because home stays `/home/hle`.
- **`~/.ssh`** + **GPG secret keys**, and the **Chrome profile** if present.
- Latest **`~/dev`** is pushed first (bisync).

> **Security note:** this uploads SSH/GPG private keys and Claude credentials to Drive in the
> clear (your personal account). If that's not acceptable, encrypt them first, e.g.
> `tar czf - ~/.ssh ~/.claude/.credentials.json | gpg -c > secrets.tgz.gpg` and upload that.

> **rclone bootstrap:** you can't read Drive until rclone is authed, so don't rely on a
> backed-up `rclone.conf` (chicken-and-egg). On the fresh system you re-create the `hoang`
> remote once with `rclone config` (browser OAuth) — see §8.

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
USB=/dev/sda                          # <-- set to YOUR usb device (verify with lsblk above!)
sudo umount ${USB}?* 2>/dev/null      # unmount any mounted partitions
sudo wipefs -a $USB                   # wipe existing filesystem signatures
sudo dd if=latest-nixos-minimal-x86_64-linux.iso of=$USB bs=4M conv=fsync status=progress
sync
```

> `wipefs -a` clears old partition/FS signatures so the drive boots cleanly.
> `conv=fsync` guarantees the write is flushed before `dd` returns.

**Validate the flash** (do at least the first two):

> If you opened a **new shell** since flashing, re-set the variables — they don't persist:
> `USB=/dev/sda` and `ISO=latest-nixos-minimal-x86_64-linux.iso`

```bash
USB=/dev/sda                                   # <-- your usb device
ISO=latest-nixos-minimal-x86_64-linux.iso

# 0. Desktops auto-mount the new partitions; detach them before checking
sudo umount ${USB}?* 2>/dev/null

# 1. Confirm the ISO's partitions landed on the USB
lsblk $USB                     # expect 2 partitions (main ~1.6G + small EFI ~3M)
sudo blkid ${USB}*             # expect sda1 TYPE="iso9660" and sda2 vfat/EFI

# 2. Byte-for-byte compare against the ISO (strongest correctness check)
sudo cmp -n "$(stat -c%s $ISO)" "$ISO" "$USB" && echo "USB matches ISO OK"
#    -n limits the compare to the ISO's size (the USB is larger); silence + exit 0 = match.

# 3. (Optional) prove it actually BOOTS in a UEFI VM — no reboot needed.
#    Boot the ISO *file* (user-readable, no root). Since step 2 proved USB == ISO
#    byte-for-byte, booting the file is equivalent proof the USB boots.
nix-shell -p qemu_kvm OVMF --run "qemu-system-x86_64 \
  -machine q35 -m 2048 \
  -drive if=pflash,format=raw,readonly=on,file=$(nix-build '<nixpkgs>' -A OVMF.fd --no-out-link)/FV/OVMF.fd \
  -drive format=raw,file=$ISO"
#    A NixOS boot menu appearing in the QEMU window = it's bootable.
#    To boot the raw USB device instead, use file=$USB and prefix with `sudo -E`
#    (QEMU needs root to open /dev/sda).
```

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

# 1. Re-auth rclone to gdrive ONCE (no rclone.conf yet on a fresh system).
#    In `rclone config`: n (new) -> name it EXACTLY "hoang" -> "drive" -> browser OAuth.
rclone config

# 2. Restore everything + seed the ~/dev sync (Claude state, SSH, GPG, git identity, timer)
./restore-gdrive.sh

# 3. Wire up dotfiles (hypr, waybar, fish, nvim, swaync, wlogout, alacritty)
#    NOTE: linkconfig.sh rm -rf's ~/.config/<name> then symlinks it to the repo.
bash linkconfig.sh
```

`restore-gdrive.sh` pulls `~/.claude`, `~/.ssh` (fixes perms), GPG keys, sets git identity,
seeds the `~/dev` bisync with `--resync` (required on first run), and enables the sync timer.

> **Named sessions:** with `~/.claude` restored and home unchanged at `/home/hle`, Claude Code
> resolves the same project paths — `reinstall-nixos` and your other named sessions reappear.
> Re-run `/login` in Claude Code if the restored credentials don't authenticate.

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
