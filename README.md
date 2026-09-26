# NixOS-Desktop-KDE-Intel

Austin's flake-based NixOS 26.05 + Home Manager config for **shitbox**, an
HP Laptop 14-ep0xxx (Intel Gen12 graphics, LUKS-encrypted NVMe) running
Plasma 6.

**Current version: v21** (git tag `v21`). See [Versions](#versions).

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
- **Shell & tools:** zsh + Starship with a Bazzite-style terminal (welcome
  banner, branded fastfetch, eza/atuin/zoxide/direnv and friends; see
  [Terminal](#terminal-bazzite-style)), Neovim (treesitter, telescope,
  gitsigns), git, Podman (Docker-compatible) + distrobox, LibreWolf.
- **Maintenance:** nh for rebuilds and weekly cleanup (keeps 14 days and at
  least 5 generations), weekly store deduplication, daily restic backups of
  `/home` (needs the one-time setup below) with a desktop warning when they
  go stale, and GitHub Actions that build every push and propose weekly
  updates (see [CI](#ci)).

## Layout

```
flake.nix                        inputs, config version, HM wiring, checks, devShell
Brewfile                         CLI tools managed by Homebrew (see Homebrew below)
statix.toml                      statix lint config
CLAUDE.md                        rules for AI-assisted changes (checks, versioning)
.github/workflows/
  check.yml                      CI: nix flake check + full system build
  update-flake-lock.yml          weekly flake.lock update pull request
hosts/shitbox/configuration.nix  host: hostname + stateVersion + imports
hardware-configuration.nix       generated; LUKS + ext4 root + EFI boot
modules/
  base.nix                       nix settings, nh + GC, locale, unfree allowlist
  hardware.nix                   boot, TRIM, graphics, zram, thermal, sysctls, firewall
  desktop.nix                    Plasma 6/SDDM, PipeWire, Flatpak, Mullvad, fonts, lid
  gaming.nix                     Steam, gamescope, GameMode, xpadneo
  shell.nix                      user, sudo, podman, system packages, zsh
  backup.nix                     restic job for /home (needs one-time setup)
  homebrew.nix                   Homebrew install, PATH, daily `brew bundle` of /Brewfile
home/austin/home.nix             zsh, starship, git, neovim, mangohud
home/austin/bling.nix            Bazzite-style MOTD, fastfetch, CLI tools + aliases
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
| Which commit is running? | `nixos-version --configuration-revision` |
| Which config version is running? | Shown in the welcome banner, `fastfetch`, and the boot menu entry (e.g. `v20-26.05…`) |

`nix flake check` fails on unformatted files, statix/deadnix findings, a
README whose "Current version" doesn't match `version` in `flake.nix`, or a
configuration that doesn't evaluate. `hardware-configuration.nix` is exempt
from formatting and linting because regenerating it would undo any changes.

In Neovim the leader key is Space: `<Space>ff` finds files, `<Space>fg`
searches text, `<Space>fb` lists open buffers.

## Terminal (Bazzite-style)

`home/austin/bling.nix` recreates [Bazzite](https://github.com/ublue-os/bazzite)'s
terminal the Nix way. Bazzite installs these tools with Homebrew
(`ujust bazzite-cli`) and appends lines to your shell's rc file; here Home
Manager declares all of it. Adapted from Bazzite (Apache-2.0).

- **Welcome banner:** every new terminal shows the NixOS version, the system
  generation and config commit, a table of common commands, a random Nix
  tip, and links. `toggle-motd` turns it off or back on (same switch file as
  Bazzite's `~/.config/no-show-user-motd`).
- **fastfetch:** Bazzite's layout and icons with the NixOS logo; the first
  line shows the generation and config commit. `neofetch` runs it too.
- **Tools:** `ls`/`ll`/`la`/`lt` use eza (icons, folders first), `grep`
  uses ugrep, Ctrl+R searches history with atuin, `z <dir>` jumps to
  frequent directories (zoxide), `open <file>` opens it in the default app.
  The standalone tools (`tldr`, `tv`, bat, fd, ripgrep, gh, glab, jq, yq,
  dysk, trash-cli, shellcheck, stress-ng) come from
  [Homebrew](#homebrew).
- **direnv + nix-direnv:** add `use flake` to a project's `.envrc`, run
  `direnv allow`, and its `nix develop` shell loads whenever you `cd` in.
- **Container badge:** when this prompt runs inside a container, Starship
  starts it with 📦 and the container's name, like Bazzite's prompt.
  Distrobox doesn't share `/nix/store` with its boxes, so your Home Manager
  shell config (and the badge) won't load inside them unless you share it.

The icons come from JetBrains Mono Nerd Font, which is installed. Konsole
finds them through font fallback even with its default Hack font; for icons
sized to the terminal grid, pick JetBrainsMono Nerd Font Mono under
Settings → Edit Current Profile → Appearance. To drop the whole setup,
remove the `./bling.nix` import at the top of `home/austin/home.nix`.

### Emoji and icons

Color emoji come from Noto Color Emoji. With this config they render in
GTK apps, KDE/Qt apps, Konsole, and LibreWolf, and the Flatpak module
exposes the system fonts (emoji included) to Flatpak apps. If emoji look
wrong somewhere:

- **Text console** (Ctrl+Alt+F3 or before login): the Linux console can't
  draw emoji or Nerd Font icons at all.
- **Black-and-white emoji in one app:** apps that don't handle emoji
  themselves (xterm, some older or Java/Electron apps) get monochrome emoji
  from DejaVu Sans or Noto Sans Symbols 2 first. Appending Noto Color Emoji
  to the default fonts in `modules/desktop.nix` fixes that, at the cost of a
  few symbols such as ♥ and ✔ also turning into color emoji:

  ```nix
  fonts.fontconfig.defaultFonts = {
    serif = lib.mkAfter [ "Noto Color Emoji" ];
    sansSerif = lib.mkAfter [ "Noto Color Emoji" ];
    monospace = lib.mkAfter [ "Noto Color Emoji" ];
  };
  ```

  `mkAfter` matters: Plasma sets these lists too, and the emoji font must
  come after the text fonts or it would take over digits and `#`.
- **Missing in the banner, prompt, or fastfetch:** rebuild (`rebuild`) and
  open a new terminal.

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

### Stale-backup warning

Because the job skips silently whenever the drive isn't mounted, a desktop
notification warns you instead: shortly after login and once a day, if the
last successful backup is more than 7 days old, or if there has never been
one (so it also reminds you to finish the setup above). Each fully
successful run (backup, prune, and check) touches
`/var/lib/restic-home-last-success`, which is what the warning reads.

- Change the threshold with `staleDays` at the top of `modules/backup.nix`.
- Test it: `systemctl --user start backup-reminder`.
- Silence it until the next login: `systemctl --user stop backup-reminder.timer`.

## Homebrew

A few command-line tools come from Homebrew instead of Nix, so they update
as soon as upstream releases rather than when NixOS catches up. yt-dlp is
the main reason: it breaks whenever video sites change.

**What's where:**

- **Homebrew (`/Brewfile`):** standalone tools with no shell or system
  integration: yt-dlp, gh, glab, ripgrep, fd, bat, jq, yq, television,
  dysk, trash-cli, tealdeer, shellcheck, stress-ng.
- **Nix (everything else):** anything wired into the shell or system:
  atuin, zoxide, direnv, starship, eza, Neovim (it keeps its own ripgrep),
  git, Podman/distrobox, gaming tools, nh, restic, the banner and fastfetch,
  GUI apps, and rarely-changing basics like curl and htop.

**How it works** (`modules/homebrew.nix`):

- `/home/linuxbrew` is created for you, owned by you, so brew never needs
  sudo.
- A user timer (`brew-bundle`, ~5 minutes after login and daily) installs
  Homebrew on its first run, then makes the installed formulas match
  `/Brewfile`: installs missing ones, upgrades outdated ones, and
  **uninstalls anything not listed**. The Brewfile is the source of truth,
  like the rest of the config, so add tools there rather than with
  `brew install`, which the next run would undo.
- brew's `bin` goes at the end of `PATH`, so if a brew dependency has the
  same name as a Nix tool (python3, git, curl…), the Nix one wins.
- `programs.nix-ld` is enabled because brew's prebuilt binaries expect the
  standard Linux loader at `/lib64`, which NixOS doesn't have otherwise.
- Analytics are off (`HOMEBREW_NO_ANALYTICS=1`).

**Using it:**

| Task | Command |
| --- | --- |
| Add or remove a tool | Edit `/Brewfile`, commit, `rebuild`, then `systemctl --user start brew-bundle` (or wait for the daily run) |
| See what the last run did | `journalctl --user -u brew-bundle` |
| Update brew tools now | `systemctl --user start brew-bundle` |
| Check brew's health | `brew doctor` |

**Trade-offs to know:** brew-installed tools aren't covered by NixOS
rollbacks or CI, and a bad upstream release reaches you the next day. To
move a tool back to Nix, delete it from the Brewfile and add it to
`home.packages` in `home/austin/bling.nix`. Shell tab completions for brew
tools aren't wired up.

## CI

Two GitHub Actions workflows live in `.github/workflows/`:

- **Check** (every push to `main` and every pull request): runs
  `nix flake check` and builds the whole system, so a package that fails to
  build shows up on GitHub before you rebuild the laptop. Results are on the
  repository's Actions tab.
- **Update flake.lock** (Mondays, or run it by hand from the Actions tab):
  runs `nix flake update`, checks and builds the result, and only then opens
  a pull request listing what changed. Merging it counts as a config change,
  so bump the version first (the PR description reminds you).

One-time GitHub setting for the update workflow: Settings → Actions →
General → Workflow permissions → tick **Allow GitHub Actions to create and
approve pull requests**. Without it the workflow runs but can't open the
pull request.

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

## Versions

The version goes up by one whenever a change affects the built system
(packages, services, Home Manager config, flake inputs). Changes to docs,
lint config or comments alone don't bump it. Each version has a matching
git tag (`git checkout v18` to see it), and git history has the detail.

The version is set once, as `version` in `flake.nix`. It's added to the
system label, so it appears in the boot menu, the welcome banner and
fastfetch, and `nix flake check` fails if the "Current version" line at the
top of this README doesn't match it.

| Version | Highlights |
| --- | --- |
| **v21** | Homebrew for fast-moving standalone CLI tools (yt-dlp, gh, glab, ripgrep, fd, bat, jq, yq, television, dysk, trash-cli, tealdeer, shellcheck, stress-ng), listed in `/Brewfile` and applied daily by a user timer; those tools were removed from the Nix config. Adds nix-ld so brew's prebuilt binaries run. |
| v20 | Desktop warning when backups are more than 7 days old or never ran; GitHub Actions that check and build every push and open a tested weekly `flake.lock` update PR; the config version shows in the boot menu, welcome banner and fastfetch, and a check keeps the README in sync. |
| v19 | Bazzite-style terminal (`home/austin/bling.nix`): welcome banner with `toggle-motd`, branded fastfetch, eza/atuin/zoxide/direnv and the rest of Bazzite's CLI tools; the system records the git commit it was built from. |
| v18 | Review fixes: flake actually locked to NixOS 26.05 (it was building 25.11), real lint/format checks, all 26.05 deprecation warnings fixed, nh for rebuilds and 14-day cleanup, Intel hardware video decode, SSD TRIM through LUKS, working Neovim plugins, Steam dedicated-server port closed, Proton saves included in backups with a check after each run. |
| v17 | Last pre-git release, imported as-is. Its changelog (and v15–v16's) is in the README of that commit. |
