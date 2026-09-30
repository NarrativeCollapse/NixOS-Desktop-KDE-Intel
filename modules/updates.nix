{ config, pkgs, ... }:

# Updates happen only when you ask for them. `update` opens a menu (or takes
# system / flatpak / brew / neovim / firmware / all / rollback as an argument); each
# part shows what would change and asks before applying anything. Nothing
# here runs on a timer. The longer scripts are in scripts/ (update.sh,
# update-system.sh, update-neovim.sh); the short ones are inline below.
let
  # The config checkout, defined once as nh's flake path (base.nix).
  inherit (config.programs.nh) flake;

  # [s] System: update flake.lock on this laptop, build the result, show
  # which packages change, then apply it now, at the next restart, or not at
  # all. Once applied (or set for the restart) the new config version is
  # committed, tagged and pushed; on skip (or a failed build) the repo is put
  # back exactly as it was.
  updateSystem = pkgs.writeShellApplication {
    name = "update-system";
    runtimeInputs = with pkgs; [
      coreutils
      git
      nvd
      python3
    ];
    runtimeEnv = {
      CONFIG_FLAKE = flake;
      CONFIG_HOST = config.networking.hostName;
    };
    text = builtins.readFile ../scripts/update-system.sh;
  };

  # [f] Flatpak: `flatpak update` lists pending updates and asks before
  # installing them. System-wide apps may show a password prompt.
  updateFlatpak = pkgs.writeShellApplication {
    name = "update-flatpak";
    runtimeInputs = [ pkgs.flatpak ];
    text = ''
      echo "Checking Flatpak apps for updates..."
      flatpak update
    '';
  };

  # [w] Firmware: fwupd lists BIOS and device firmware updates from the
  # LVFS; `fwupdmgr update` asks before installing and before any reboot.
  # Many HP consumer models get none; then it just says so.
  updateFirmware = pkgs.writeShellApplication {
    name = "update-firmware";
    runtimeInputs = [ config.services.fwupd.package ];
    text = ''
      echo "Checking for firmware updates..."
      fwupdmgr refresh >/dev/null 2>&1 || true
      status=0
      fwupdmgr get-updates || status=$?
      case $status in
        0)
          echo
          fwupdmgr update
          ;;
        2) echo "No firmware updates available." ;;
        *)
          echo "fwupd couldn't check for firmware updates (exit code $status)."
          exit 1
          ;;
      esac
    '';
  };

  # [r] Roll back: switch to the system version before the current one (the
  # same as picking it in the boot menu, but it stays the default).
  updateRollback = pkgs.writeShellApplication {
    name = "update-rollback";
    text = builtins.readFile ../scripts/lib/confirm.sh + ''
      echo "Recent system versions (the running one is marked current):"
      nix-env --list-generations --profile /nix/var/nix/profiles/system | tail -n 5
      echo
      if ! confirm "Switch back to the version before the current one?"; then
        echo "Nothing changed."
        exit 0
      fi
      sudo nixos-rebuild switch --rollback
      echo
      echo "Rolled back. ~/nixos-config still has the newer version, so the next"
      echo "\`rebuild\` or \`update\` would return to it. To stay on this one, undo the"
      echo "change there (e.g. git revert HEAD) and push."
    '';
  };

  # [n] Neovim: LazyVim and its plugins (home/austin/neovim.nix). Runs
  # `:Lazy sync` headless, then commits and pushes the new pins in
  # lazy-lock.json. nvim comes from the user's PATH: the Home Manager build,
  # which carries the compiler and tools the plugins need.
  updateNeovim = pkgs.writeShellApplication {
    name = "update-neovim";
    runtimeInputs = with pkgs; [
      coreutils
      git
      gnused
    ];
    runtimeEnv.CONFIG_FLAKE = flake;
    text = builtins.readFile ../scripts/lib/confirm.sh + builtins.readFile ../scripts/update-neovim.sh;
  };

  update = pkgs.writeShellApplication {
    name = "update";
    runtimeInputs = [
      updateSystem
      updateFlatpak
      updateNeovim
      updateFirmware
      updateRollback
    ];
    text = builtins.readFile ../scripts/update.sh;
  };
in
{
  environment.systemPackages = [
    update
    updateSystem
    updateFlatpak
    updateNeovim
    updateFirmware
    updateRollback
  ];
}
