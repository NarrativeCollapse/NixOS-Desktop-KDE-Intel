{ pkgs, ... }:

let
  # smartd's alert: a desktop notification in austin's session (the same
  # route as notify-failure.nix; skipped if austin isn't logged in, but the
  # warning repeats daily and is in `journalctl -u smartd`).
  smartdNotify = pkgs.writeShellScript "smartd-notify" ''
    bus=/run/user/$(${pkgs.coreutils}/bin/id -u austin)/bus
    [ -S "$bus" ] || exit 0
    ${pkgs.util-linux}/bin/runuser -u austin -- \
      ${pkgs.coreutils}/bin/env DBUS_SESSION_BUS_ADDRESS="unix:path=$bus" \
      ${pkgs.libnotify}/bin/notify-send --urgency=critical --app-name=smartd \
      --icon=drive-harddisk "Disk problem: $SMARTD_DEVICESTRING" \
      "$SMARTD_MESSAGE. Check your backups; details: disk-health"
  '';
in
{
  ################################
  # Boot loader
  ################################

  boot.loader = {
    systemd-boot = {
      enable = true;
      configurationLimit = 10;
      # Without this, anyone at the boot menu can press `e` and edit the
      # kernel command line (e.g. add init=/bin/sh). The disk is still LUKS-
      # encrypted either way, but locking the editor closes an easy local
      # tampering vector on a laptop that leaves the house.
      editor = false;
    };
    efi.canTouchEfiVariables = true;
    grub.enable = false;
    # Shorter menu wait on a laptop you boot often.
    timeout = 3;
  };

  boot.initrd.systemd.enable = true;

  # TRIM through dm-crypt (allowDiscards) is set per host, next to the
  # encrypted disk it applies to: see hosts/shitbox/configuration.nix.

  ################################
  # Graphical boot: Plymouth
  ################################

  # A Breeze-themed splash that also draws the disk-unlock password prompt,
  # instead of scrolling kernel text. Press Esc during boot to see the
  # messages behind it.
  boot.plymouth = {
    enable = true;
    theme = "breeze";
    themePackages = [ pkgs.kdePackages.breeze-plymouth ];
  };
  # Load the Intel GPU driver in the initrd so the splash and password prompt
  # appear at native resolution from the start (early KMS).
  boot.initrd.kernelModules = [ "i915" ];
  # Keep kernel and systemd status text off the screen on a normal boot
  # (the Plymouth module adds "splash" itself).
  boot.consoleLogLevel = 3;
  boot.initrd.verbose = false;
  boot.kernelParams = [
    "quiet"
    "udev.log_level=3"
    "rd.systemd.show_status=auto"
  ];

  ################################
  # Swap: zram
  ################################

  # No disk swap is configured (see hosts/shitbox/hardware-configuration.nix).
  # zram gives us compressed in-RAM swap so large builds / games don't hit the
  # OOM killer, without writing anything to the encrypted disk.
  zramSwap = {
    enable = true;
    memoryPercent = 50;
  };
  # Its VM tuning is in the sysctl block below.

  # When memory really runs out, systemd-oomd closes the app using the most
  # (its whole process group) after sustained memory pressure, instead of
  # the desktop freezing until the kernel's last-resort OOM killer acts.
  # Fedora does the same. `journalctl -u systemd-oomd` shows what it closed.
  systemd.oomd.enableUserSlices = true;

  ################################
  # Power / thermal / firmware
  ################################

  services.power-profiles-daemon.enable = true;

  # Intel thermal management. Separate concern from power-profiles-daemon
  # (which handles the CPU governor/EPP, not thermal trip points).
  services.thermald.enable = true;

  services.fwupd.enable = true;
  hardware.enableRedistributableFirmware = true;

  # Disk health: smartd reads the SSD's own health counters (spare blocks,
  # wear, media errors, temperature) every 30 minutes and warns on the
  # desktop when one crosses its limit, again each day until it's fixed.
  # A drive usually reports trouble like this weeks before it fails.
  # `disk-health` shows the full report.
  services.smartd = {
    enable = true;
    # The module's own alerts are terminal `wall` messages and X11 pop-ups;
    # smartdNotify (top of this file) sends a desktop notification instead.
    notifications.wall.enable = false;
    defaults.monitored = "-a -m <nomailer> -M daily -M exec ${smartdNotify}";
  };
  environment.systemPackages = [
    (pkgs.writeShellApplication {
      name = "disk-health";
      text = ''
        # Every disk smartctl finds: overall verdict plus the health counters.
        # (smartctl's exit code flags even minor log entries; keep going.)
        sudo ${pkgs.smartmontools}/sbin/smartctl --scan | while read -r dev _ type _; do
          sudo ${pkgs.smartmontools}/sbin/smartctl -H -A -d "$type" "$dev" || true
        done
      '';
    })
  ];

  ################################
  # Graphics
  ################################

  hardware.graphics = {
    enable = true;
    # 32-bit drivers, needed by 32-bit Steam/Proton titles.
    enable32Bit = true;
    # VA-API (iHD) and oneVPL drivers for Gen12+ Intel graphics, so browsers
    # and video players decode video on the GPU instead of the CPU.
    extraPackages = with pkgs; [
      intel-media-driver
      vpl-gpu-rt
    ];
  };

  # The NixOS firewall is on by default with nothing open; the only ports
  # opened are by Steam Remote Play (gaming.nix) and Avahi (desktop.nix).
  # Mullvad manages its own killswitch and routing, so don't add VPN rules
  # here that would fight the daemon.

  ################################
  # Kernel sysctls: zram tuning + network hardening
  ################################

  boot.kernel.sysctl = {
    # zram (the values Fedora and Pop!_OS use): swapping to RAM is cheap, so
    # prefer it over dropping file cache (swappiness above 100); skip
    # swap read-ahead, which only helps real disks (page-cluster 0); and keep
    # kswapd from reclaiming in bursts.
    "vm.swappiness" = 180;
    "vm.page-cluster" = 0;
    "vm.watermark_boost_factor" = 0;
    "vm.watermark_scale_factor" = 125;

    # Network hardening for untrusted Wi-Fi. rp_filter is deliberately not
    # set: the NixOS firewall handles reverse-path checking, and strict
    # values can interfere with Mullvad/WireGuard routing.
    # Ignore ICMP redirects (MITM vector on hostile networks).
    "net.ipv4.conf.all.accept_redirects" = 0;
    "net.ipv4.conf.default.accept_redirects" = 0;
    "net.ipv6.conf.all.accept_redirects" = 0;
    "net.ipv6.conf.default.accept_redirects" = 0;
    # This machine is not a router; don't emit redirects either.
    "net.ipv4.conf.all.send_redirects" = 0;
    "net.ipv4.conf.default.send_redirects" = 0;
    # Drop source-routed packets.
    "net.ipv4.conf.all.accept_source_route" = 0;
    "net.ipv6.conf.all.accept_source_route" = 0;
    # SYN-flood protection (kernel default, made explicit).
    "net.ipv4.tcp_syncookies" = 1;

    # Kernel-info hardening — enable if you're security-motivated; can
    # inconvenience debugging/profiling tools:
    # "kernel.dmesg_restrict" = 1;
    # "kernel.kptr_restrict" = 2;
  };

  # If you want SSH later (openFirewall opens port 22):
  #
  # services.openssh = {
  #   enable = true;
  #   openFirewall = true;
  #   settings.PasswordAuthentication = false;
  # };
  # services.fail2ban.enable = true;  # only worth it once SSH is exposed

  ################################
  # Optional: TPM-backed LUKS unlock
  ################################

  # This machine already uses systemd in initrd, so you *can* enroll the LUKS
  # key into the TPM for passwordless (but still encrypted) boot:
  #
  #   1. Add tpm2 tooling:
  #        environment.systemPackages = [ pkgs.tpm2-tools ];
  #   2. Enroll once, imperatively:
  #        sudo systemd-cryptenroll --tpm2-device=auto /dev/<luks-partition>
  #   3. Tell initrd to try the TPM:
  #        boot.initrd.luks.devices."luks-...".crypttabExtraOpts =
  #          [ "tpm2-device=auto" ];
  #
  # Left commented because it requires the one-time enroll step and a decision
  # about your threat model (TPM unlock trades a passphrase for physical-theft
  # resistance only).
}
