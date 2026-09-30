# Boot test: starts shitbox's configuration in a QEMU VM and checks that it
# boots, its services start, Plasma logs in and the config's own commands
# run. Catches changes that build but don't work. Runs as the `boot` check
# (`nix flake check`, and CI on every push); on its own:
#   nix build .#checks.x86_64-linux.boot -L
# Interactively, with a window onto the VM:
#   nix run .#checks.x86_64-linux.boot.driverInteractive
{ modules, version }:

{
  name = "shitbox-boot";

  nodes.machine =
    { lib, ... }:
    {
      imports = modules;

      # Only what the VM can't do like the laptop:
      # - No encrypted disk: the test supplies its own virtual disks (the
      #   VM also ignores the laptop's file systems and boot loader).
      boot.initrd.luks.devices = lib.mkForce { };
      # - Log straight into Plasma instead of waiting at the login screen.
      #   (The real config leaves the session to SDDM's memory; see
      #   desktop.nix. Here it has to be named.)
      services.displayManager = {
        autoLogin = {
          enable = true;
          user = "austin";
        };
        defaultSession = "plasma";
      };
      # - The test framework reads the kernel's console messages, so it
      #   needs the full log level instead of the quiet boot (hardware.nix).
      boot.consoleLogLevel = lib.mkForce 7;
      # - Enough memory and CPU for Plasma.
      virtualisation = {
        memorySize = 4096;
        cores = 2;
      };
    };

  # Not checked, because a VM can't have them: smartd (virtual disks report
  # no SMART data), Bluetooth, Wi-Fi, thermald, firmware updates, Flatpak
  # downloads and anything else that needs the internet.
  testScript = ''
    start_all()

    with subtest("Boots to the graphical target"):
        machine.wait_for_unit("graphical.target")

    with subtest("Core services are running"):
        for unit in [
            "display-manager.service",
            "NetworkManager.service",
            "systemd-resolved.service",
            "mullvad-daemon.service",
            "avahi-daemon.service",
            "systemd-oomd.service",
            "restic-backups-home.timer",
            "home-manager-austin.service",
        ]:
            machine.wait_for_unit(unit)

    with subtest("Plasma starts for austin"):
        machine.wait_until_succeeds("pgrep -u austin plasmashell", timeout=300)

    with subtest("The taskbar script ran (plasma-manager)"):
        machine.wait_until_succeeds(
            "grep -q nix-snowflake-white /home/austin/.config/plasma-org.kde.plasma.desktop-appletsrc",
            timeout=300,
        )

    with subtest("The config's commands are installed and run"):
        machine.succeed(
            "su - austin -c 'command -v update update-system update-rollback"
            " backup-setup backup-test brew-update disk-health nixos-motd'"
        )
        # An unknown option prints the usage and exits 1 (the test shell uses
        # pipefail, so check the output rather than piping it to grep).
        usage = machine.fail("su - austin -c 'update bogus' 2>&1")
        assert "Usage: update" in usage, usage
        motd = machine.succeed("su - austin -c nixos-motd")
        assert "Welcome to NixOS" in motd, motd
        # The config version (${version}) is in the running system's name, which
        # the MOTD and fastfetch show through nixos-system-info.
        info = machine.succeed("su - austin -c nixos-system-info")
        system = machine.succeed("readlink /run/current-system")
        assert "${version}" in info, f"nixos-system-info: {info!r}, system: {system!r}"

    # Anything else that failed in the VM, for the log (not a test failure:
    # see the list above).
    print(machine.execute("systemctl --failed --no-pager")[1])
  '';
}
