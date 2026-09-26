{ config, lib, pkgs, ... }:

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

  ################################
  # Swap: zram
  ################################

  # No disk swap is configured (see hardware-configuration.nix). zram gives us
  # compressed in-RAM swap so large builds / games don't hit the OOM killer,
  # without writing anything to the encrypted disk.
  zramSwap = {
    enable = true;
    memoryPercent = 50;
  };

  ################################
  # Power / thermal / firmware
  ################################

  services.power-profiles-daemon.enable = true;

  # Intel thermal management. Separate concern from power-profiles-daemon
  # (which handles the CPU governor/EPP, not thermal trip points).
  services.thermald.enable = true;

  services.fwupd.enable = true;
  hardware.enableRedistributableFirmware = true;

  ################################
  # Graphics
  ################################

  # NixOS 25.11 renamed the whole `hardware.opengl` namespace to
  # `hardware.graphics`. `hardware.opengl.enable` is now invalid.
  #   - `enable`        replaces the old opengl.enable
  #   - `enable32Bit`   replaces the old driSupport32Bit and IS needed for
  #                     32-bit Steam/Proton titles.
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };

  ################################
  # Firewall
  ################################

  # NOTE: Mullvad manages its own killswitch/routing. Keep this strict and do
  # NOT add manual VPN firewall rules that fight the daemon.
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [ ];
    allowedUDPPorts = [ ];
  };

  ################################
  # Network hardening sysctls
  ################################

  # Standard laptop-on-untrusted-wifi settings. Deliberately NOT setting
  # rp_filter here: reverse-path checking is managed by the NixOS firewall
  # (networking.firewall.checkReversePath) and strict values can interfere
  # with Mullvad/WireGuard routing.
  boot.kernel.sysctl = {
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

  # If you want SSH later:
  #
  # services.openssh = {
  #   enable = true;
  #   settings.PasswordAuthentication = false;
  # };
  # networking.firewall.allowedTCPPorts = [ 22 ];
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
