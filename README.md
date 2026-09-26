# NixOS-Desktop-KDE-Intel

Austin's flake-based NixOS 26.05 + Home Manager config for **shitbox**, an
HP Laptop 14-ep0xxx (Intel Gen12 graphics, LUKS-encrypted NVMe) running
Plasma 6.

Changes are tracked in git history. The pre-git v15–v17 changelog is in the
README of the first commit.

## What's in it

- **Desktop:** Plasma 6 on SDDM (Wayland), PipeWire, Flatpak with Flathub,
  Bluetooth via Plasma's BlueDevil, printing, Noto + JetBrains Mono Nerd Font.
- **Hardware:** systemd-boot with the boot-menu editor locked, systemd
  initrd, LUKS with TRIM passed through to the SSD, zram swap,
  power-profiles-daemon + thermald, fwupd, and Intel VA-API/QSV drivers so
  video decodes on the GPU. Closing the lid suspends on battery and does
  nothing on AC.
- **Network & security:** NetworkManager with systemd-resolved, Mullvad VPN
  (official module), firewall on with only Steam Remote Play's ports open,
  and hardening sysctls for untrusted Wi-Fi.
- **Gaming:** Steam with a gamescope session, GameMode, MangoHud, and
  xpadneo for Xbox controllers over Bluetooth.
- **Shell & tools:** zsh + Starship, Neovim (treesitter, telescope,
  gitsigns), git, Podman (Docker-compatible) + distrobox, LibreWolf.
- **Maintenance:** nh for rebuilds and weekly cleanup (keeps 14 days and at
  least 5 generations), weekly store deduplication, and daily restic backups
  of `/home` (needs the one-time setup below).

## Layout

```
flake.nix                        inputs, HM wiring, checks, devShell
statix.toml                      statix lint config
hosts/shitbox/configuration.nix  host: hostname + stateVersion + imports
hardware-configuration.nix       generated; LUKS + ext4 root + EFI boot
modules/
  base.nix                       nix settings, nh + GC, locale, unfree allowlist
  hardware.nix                   boot, TRIM, graphics, zram, thermal, sysctls, firewall
  desktop.nix                    Plasma 6/SDDM, PipeWire, Flatpak, Mullvad, fonts, lid
  gaming.nix                     Steam, gamescope, GameMode, xpadneo
  shell.nix                      user, sudo, podman, system packages, zsh
  backup.nix                     restic job for /home (needs one-time setup)
home/austin/home.nix             zsh, starship, git, neovim, mangohud
```

## Install

```bash
# The rebuild aliases and nh (NH_FLAKE) expect the checkout at ~/nixos-config.
git clone https://github.com/NarrativeCollapse/NixOS-Desktop-KDE-Intel.git ~/nixos-config
cd ~/nixos-config

# Format, lint, and evaluate the whole system.
nix flake check

sudo nixos-rebuild switch --flake .#shitbox
```

## Everyday use

| Task | Command |
| --- | --- |
| Rebuild after editing | `rebuild` or `nh os switch` (works from any directory) |
| Update nixpkgs + Home Manager | `nix flake update` in `~/nixos-config`, then rebuild |
| Roll back a bad rebuild | `sudo nixos-rebuild switch --rollback`, or pick an older entry in the boot menu |
| Format the tree | `nix fmt` |
| Lint + evaluate | `nix flake check` |
| Steam with MangoHud + GameMode | `steam-hud` (toggle the overlay with Right Shift + F12) |

`nix flake check` fails on unformatted files, statix/deadnix findings, or a
configuration that doesn't evaluate. `hardware-configuration.nix` is exempt
from formatting and linting because regenerating it would undo any changes.

In Neovim the leader key is Space: `<Space>ff` finds files, `<Space>fg`
searches text, `<Space>fb` lists open buffers.

## Personalize

1. **`home/austin/home.nix`**: `programs.git.settings.user` uses the GitHub
   no-reply address; swap in another email if you prefer.
2. **`hosts/shitbox/configuration.nix`**: confirm `system.stateVersion`
   matches your original install release (mirror it in `home.nix`).
3. **`hardware-configuration.nix`**: this is shitbox's real one. Only
   regenerate it (`sudo nixos-generate-config --show-hardware-config >
   hardware-configuration.nix`) on a different machine or disk layout, and
   then update the LUKS UUID that `modules/hardware.nix` reuses for
   `allowDiscards`.
4. **Unfree allowlist** in `modules/base.nix`: add a package's name there
   before installing anything proprietary.
5. **Steam Remote Play** opens firewall ports on every network. Set
   `remotePlay.openFirewall = false` in `modules/gaming.nix` if you don't
   stream games.

## Backups

**What's covered:** all of `/home/austin` except caches and anything
re-downloadable: installed Steam games, shader caches, the Steam client
runtime, Podman images, `node_modules`, and similar. Steam `userdata`,
config, and Proton prefixes (where games without Steam Cloud keep their
saves) are kept. Retention is 7 daily, 4 weekly, and 6 monthly snapshots.

### One-time setup

The restic job skips silently until both steps are done (by design):

1. **Create the repo password — and store a copy OFF this machine.** Losing
   it makes every backup unreadable, permanently:

   ```bash
   sudo mkdir -p /etc/secrets && sudo chmod 700 /etc/secrets
   head -c 32 /dev/urandom | base64 | sudo tee /etc/secrets/restic-password
   sudo chmod 600 /etc/secrets/restic-password
   ```

2. **Provide the target.** Default expects an external drive at `/mnt/backup`:
   label a partition `BACKUP` and uncomment the `fileSystems."/mnt/backup"`
   block in `modules/backup.nix` (uses `nofail`, so boot is unaffected when
   the drive is absent; plug in later → `sudo mount /mnt/backup`). For a
   remote target, set `repository = "sftp:user@host:/path"` and drop the
   `ConditionPathIsMountPoint` line.

3. **First run + verify:**

   ```bash
   sudo systemctl start restic-backups-home
   restic-home snapshots
   ```

   Restore example:

   ```bash
   restic-home restore latest --target /tmp/restore --include /home/austin/Documents
   ```

   Each run ends with `restic check`, so repository corruption shows up as a
   failed `restic-backups-home` unit. For a deeper check that re-reads a
   sample of the data: `restic-home check --read-data-subset=5%`.

## Optional extras (commented out in-tree)

Each lives next to the config it would change, with the reasoning in
comments:

- TPM-backed LUKS unlock, `kernel.dmesg_restrict` / `kptr_restrict`, and
  SSH + fail2ban (`modules/hardware.nix`)
- `hardware.xone` for wired/dongle Xbox pads, `gamescope.capSysNice`, and
  Proton-GE options (`modules/gaming.nix`)
- A `nixpkgs-unstable` input for cherry-picking newer packages (`flake.nix`)
- `trusted-users`, `warn-dirty`, and nix-index + comma (`modules/base.nix`)
- `sudo-rs` in place of sudo (`modules/shell.nix`)
