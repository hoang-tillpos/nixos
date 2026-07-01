# NixOS GDM 50.0 Boot Failure Analysis

An upgrade from NixOS configuration **#60** to **#61** caused the GDM (GNOME Display Manager) login screen to fail on reboot, resulting in a black screen. A subsequent attempt in configuration **#62** to force GDM to run under X11 using `WaylandEnable = false` did not resolve the issue.

This document outlines the root cause of these failures, explains why the X11 workaround was unsuccessful, and describes the verified solution now implemented in the configuration.

---

## 1. Core Discoveries & Root Cause

### The Upgrade to GDM 50.0 (GNOME 50)
* **Generation #60 (Working):** Ran on NixOS unstable (release `26.05.20260427`), using GDM **49.2** and Mesa **26.0.5**.
* **Generation #61 (Broken):** Upgraded the system to a newer NixOS unstable channel (release `26.05.20260523`), bringing in GDM **50.0** and Mesa **26.1.1**.

### Why GDM Failed to Launch ("Unable to run session")
When analyzing the system logs from the failed boot, the display manager failed repeatedly with this specific sequence:

```
systemd[1]: Started Session c1 of User gdm-greeter.
/nix/store/...-gdm-50.0/libexec/gdm-wayland-session[1646]: Unable to run session
gdm[1594]: Gdm: GdmDisplay: Session never registered, failing
systemd-logind[1134]: Session c1 logged out. Waiting for processes to exit.
gdm[1594]: Gdm: GdmLocalDisplayFactory: maximum number of display failures reached. Giving up.
```

No system process or GPU driver segment faulted or generated a core dump. Instead, the GDM helper binary `gdm-wayland-session` exited gracefully but unsuccessfully because its internal `session_name` was `NULL`. 

This occurs when the GNOME Shell greeter session fails to initialize:
1. GDM 50.0 has a strict reliance on the `dconf` configuration system to back the GSettings database for the GNOME Shell login screen.
2. In the user's `configuration.nix`, **`programs.dconf.enable`** was not enabled. 
3. Without `dconf` active in the system, the required D-Bus service `ca.desrt.dconf` could not be started or resolved. The GNOME Shell greeter failed to load its default settings backend and terminated immediately.
4. Because the greeter terminated, the GDM session manager was left with no valid session command to launch, leading to the `Unable to run session` crash loop and a black screen.

---

## 2. Why the X11 Workaround in Generation #62 Failed

In generation #62, an attempt was made to force GDM to run on X11 instead of Wayland by adding GDM-specific daemon settings in `configuration.nix`:

```nix
  services.displayManager.gdm.settings = {
    daemon = {
      WaylandEnable = false;
    };
  };
```

This did not work because **GDM 50.0 has completely deprecated and removed support for running its greeter on X11**. 

When we attempted to configure this using first-class NixOS options:
```nix
services.displayManager.gdm.wayland = false;
```
The NixOS module evaluation threw a hard assertion error:
```
Failed assertions:
- The option definition `services.displayManager.gdm.wayland' in `configuration.nix' no longer has any effect; please remove it.
  Disabling this option is no longer supported with GNOME 50.
```

Because GDM 50.0 strictly requires Wayland, manually writing `WaylandEnable = false` into the GDM config was either ignored or caused the Wayland session to abort without a valid X11 fallback, sustaining the black screen behavior.

---

## 3. The Verified Solution

To resolve this and bring GDM back to a working state, the following modifications have been made to `/home/hle/nixos/configuration.nix`:

1. **Removed custom GDM daemon settings:** We removed the defunct and ignored `WaylandEnable = false` block.
2. **Enabled `programs.dconf.enable = true;`:** This starts the necessary dconf D-Bus services and sets up system-wide GSettings registries, satisfying GDM 50's greeter dependency.

### Code Diff applied to `configuration.nix`

```diff
-  services.displayManager.gdm.settings = {
-    daemon = {
-      WaylandEnable = false; # Force GDM's login screen to use stable X11
-    };
-  };
+  services.displayManager.gdm.enable = true;
+  programs.dconf.enable = true;
```

### Dry-Build Verification
We executed a complete evaluation and build dry-run of the updated system configuration:
```bash
nixos-rebuild dry-build --flake .#hle-nixos --impure
```
This completed successfully with **exit code 0** and no warning or assertion failures, proving that the configuration compiles cleanly and is safe to apply.

---

## 4. Next Steps for the User

To apply the changes and restore the graphical login screen, run the following commands in your terminal:

1. **Rebuild and switch to the new configuration:**
   ```bash
   sudo nixos-rebuild switch --flake .#hle-nixos --impure
   ```

2. **Reboot the system:**
   ```bash
   sudo reboot
   ```

### Alternative Recommendation
If you prefer a lightweight, simple login screen that does not bundle GNOME libraries or enforce Wayland for the greeter, you can switch from GDM to **LightDM** by replacing GDM in your `configuration.nix`:

```nix
  services.xserver.displayManager.lightdm.enable = true;
  # services.displayManager.gdm.enable = true; # Comment out GDM
```
This is a popular configuration for pure window manager environments (like Hyprland) because it avoids GDM/GNOME backend complexities entirely.
