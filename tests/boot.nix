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
      # - The test framework names the system "test" instead of the usual
      #   label ("${version}-26.05..."); keep the version in it so the check
      #   of the banner's version line below still means something. (The
      #   framework sets "test" with mkForce, so this needs a stronger
      #   priority: lower numbers win, mkForce is 50.)
      system.nixos.label = lib.mkOverride 40 "${version}-test";
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
        # The panel is docked, not floating (saved in plasmashellrc).
        machine.wait_until_succeeds(
            "grep -Eq '^floating=(0|false)$' /home/austin/.config/plasmashellrc",
            timeout=120,
        )

    with subtest("The config's commands are installed and run"):
        machine.succeed(
            "su - austin -c 'command -v update update-system update-rollback"
            " update-neovim backup-setup backup-test brew-update disk-health"
            " nixos-motd boxbuddy-rs'"
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

    with subtest("Firewall: only mDNS is open"):
        # Read the live rules (the NixOS firewall uses iptables here): mDNS
        # (5353) must be there, Steam Remote Play's ports must not.
        rules = machine.succeed("iptables-save; ip6tables-save")
        assert "5353" in rules, rules
        for port in ["27036", "10400"]:
            assert port not in rules, rules

    with subtest("sudo is sudo-rs"):
        sudo_version = machine.succeed("sudo --version")
        assert "sudo-rs" in sudo_version, sudo_version

    with subtest("Neovim is set up for LazyVim"):
        # ~/.config/nvim points into the config checkout (the VM has none,
        # so the link dangles here; on the laptop it's ~/nixos-config).
        machine.succeed(
            "test \"$(readlink -m /home/austin/.config/nvim)\""
            " = /home/austin/nixos-config/home/austin/nvim"
        )
        # Home Manager didn't write its own init.lua there (sideloadInitLua).
        machine.fail("test -e /home/austin/.config/nvim/init.lua")
        # nvim runs, and its wrapper carries the tools LazyVim needs.
        machine.succeed("su - austin -c 'nvim --version'")
        wrapper = machine.succeed("su - austin -c 'cat \"$(command -v nvim)\"'")
        for tool in ["tree-sitter", "gcc", "nil", "lazygit"]:
            assert tool in wrapper, f"{tool} missing from nvim's PATH: {wrapper}"

    # Anything else that failed in the VM, for the log (not a test failure:
    # see the list above).
    print(machine.execute("systemctl --failed --no-pager")[1])
  '';
}
