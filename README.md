# Austin's NixOS config (shitbox, NixOS 26.05) — v17

Flake-based config for an HP Laptop 14-ep0xxx with Plasma 6, a gaming stack,
Mullvad VPN, Home Manager, and now daily restic backups of `/home`.

## Changelog vs v16

### Active changes

- **Restic backups of `/home/austin`** (`modules/backup.nix`): daily, with
  retention (7d/4w/6m), gaming-aware excludes (Steam library, caches, podman
  images), and safe-skip conditions — the job silently no-ops until you finish
  the one-time setup below, so a fresh build never has a failed unit.
- **`boot.loader.systemd-boot.editor = false`** — boot-menu kernel-cmdline
  editing disabled (easy local-tampering vector on a laptop).
- **Network hardening sysctls** — ICMP-redirect, source-route, and syncookie
  settings. `rp_filter` deliberately untouched (Mullvad/WireGuard interaction;
  the NixOS firewall owns reverse-path checking).
- `.gitignore` / `.editorconfig` added.

### Documented-but-commented options (off by default)

- TPM-backed LUKS unlock (`modules/hardware.nix`)
- `kernel.dmesg_restrict` / `kptr_restrict` (`modules/hardware.nix`)
- SSH + fail2ban pairing (`modules/hardware.nix`)
- `hardware.xone`, `gamescope.capSysNice` (with FHS caveat), Proton-GE routes
  (`modules/gaming.nix`)
- `nixpkgs-unstable` input for cherry-picking newer packages (`flake.nix`)
- `trusted-users`, `warn-dirty` (`modules/base.nix`)
- `sudo-rs`, `nix-index`+`comma` (carried over from v16)

## Changelog vs v15 (carried in v16)

- `hardware.opengl` → `hardware.graphics` (+ `enable32Bit` for Proton); v15
  did not evaluate on 25.11.
- Mullvad via the official `services.mullvad-vpn` module instead of a
  hand-rolled unit.
- `stateVersion` aligned (25.11 everywhere), `defaultSession` unpinned, dead
  `command-not-found` removed, redundant packages/groups cleaned up.
- Laptop basics: zram, thermald, `bluetooth.powerOnBoot`, logind lid rules.
- Neovim/git/starship/MangoHud actually configured in Home Manager; flake
  `checks` (nixfmt/statix/deadnix) + devShell.

## Layout

```
flake.nix                        inputs, HM wiring, checks, devShell
statix.toml                      statix lint config
hosts/shitbox/configuration.nix  host: hostname + stateVersion + imports
hardware-configuration.nix       generated; LUKS + ext4 root + EFI boot
modules/
  base.nix                       nix settings, nh + GC, locale, unfree allowlist
  hardware.nix                   boot, graphics, zram, thermal, sysctls, firewall
  desktop.nix                    Plasma 6/SDDM, PipeWire, Flatpak, Mullvad, fonts
  gaming.nix                     Steam, gamescope, GameMode, xpadneo
  shell.nix                      user, sudo, podman, system packages, zsh
  backup.nix                     restic job for /home (needs one-time setup)
home/austin/home.nix             zsh, starship, git, neovim, mangohud
```

## How to use

```bash
# The rebuild aliases and nh (NH_FLAKE) expect the checkout at ~/nixos-config.
git clone https://github.com/NarrativeCollapse/NixOS-Desktop-KDE-Intel.git ~/nixos-config
cd ~/nixos-config

# Format, lint, and evaluate the whole system.
nix flake check

sudo nixos-rebuild switch --flake .#shitbox
# Afterwards: `rebuild` or `nh os switch` from anywhere.
```

`nix fmt` formats the tree; `nix flake check` fails on unformatted files,
statix/deadnix findings, or a configuration that doesn't evaluate.
`nix flake update` moves nixpkgs and home-manager to the latest 26.05 commits.

## Before first build — personalize

1. **`home/austin/home.nix`** → real `programs.git.settings.user`.
2. **`hosts/shitbox/configuration.nix`** → confirm `system.stateVersion`
   matches your original install release (mirror it in `home.nix`).
3. **`hardware-configuration.nix`** → this is shitbox's real one. Only
   regenerate it (`sudo nixos-generate-config --show-hardware-config >
   hardware-configuration.nix`) on a different machine or disk layout.
4. Unfree allowlist in `modules/base.nix` if you add proprietary apps.

## Backups — one-time setup

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

   Run `restic-home check` occasionally to verify repository integrity.

## Optional extras (left commented in-tree)

See the "documented-but-commented" list in the changelog above; each lives
next to the config it would modify, with the reasoning in comments.
