{ pkgs, ... }:

{
  ################################
  # Desktop: Plasma 6 on SDDM
  ################################

  services.xserver.enable = true;

  services.displayManager.sddm = {
    enable = true;
    wayland.enable = true;
  };

  # NOTE: defaultSession is intentionally NOT pinned. With Plasma 6 Wayland +
  # the gamescope session both registered, letting SDDM remember the last
  # choice avoids silently falling back when a session name is wrong. If you
  # ever want to force one, check the exact name first with:
  #   ls /run/current-system/sw/share/wayland-sessions/
  #   ls /run/current-system/sw/share/xsessions/

  services.desktopManager.plasma6.enable = true;

  ################################
  # Audio: PipeWire
  ################################

  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    jack.enable = true;
  };

  ################################
  # XDG portals & settings
  ################################

  xdg.portal = {
    enable = true;
    xdgOpenUsePortal = true;
  };

  programs.dconf.enable = true;

  ################################
  # Flatpak + Flathub
  ################################

  # Managed by nix-flatpak (flake input): the Flathub remote and the apps
  # listed below are installed by flatpak-managed-install.service at boot and
  # after each rebuild, retried with backoff while offline.
  services.flatpak = {
    enable = true;
    # Flathub is the default remote. Add apps by ID, e.g.
    #   "com.discordapp.Discord"
    #   { appId = "org.mozilla.firefox"; origin = "flathub"; }
    packages = [ ];
    # Leave apps installed by hand (Discover, `flatpak install`) alone. Set to
    # true once everything you want is listed above to make this list the
    # source of truth, like the Brewfile.
    uninstallUnmanaged = false;
    update.auto = {
      enable = true;
      onCalendar = "weekly";
    };
    restartOnFailure.exponentialBackoff.enable = true;
  };

  ################################
  # Mullvad VPN (official module)
  ################################

  # Replaces the old hand-rolled systemd unit. The module wires up the daemon,
  # correct socket ownership, split routing, resolved integration, and ships
  # the CLI + GUI. Because it adds the package, do NOT also list mullvad-vpn in
  # environment.systemPackages.
  services.mullvad-vpn = {
    enable = true;
    package = pkgs.mullvad-vpn; # GUI build (use pkgs.mullvad for CLI-only)
  };

  # Mullvad & modern DNS setups work best with systemd-resolved.
  services.resolved.enable = true;

  ################################
  # KDE / Plasma exclusions
  ################################

  environment.plasma6.excludePackages = with pkgs; [
    kdePackages.elisa
  ];

  ################################
  # Environment variables
  ################################

  # Prefer Wayland-native behavior for Electron/Chromium apps.
  environment.sessionVariables.NIXOS_OZONE_WL = "1";

  ################################
  # Fonts
  ################################

  fonts = {
    packages = with pkgs; [
      noto-fonts
      noto-fonts-color-emoji
      dejavu_fonts
      # Monospace with glyphs for Starship / terminal (namespaced attr on
      # 25.11; the old `nerdfonts` package was split per-family).
      nerd-fonts.jetbrains-mono
    ];

    fontconfig = {
      antialias = true;
      subpixel = {
        rgba = "rgb";
        lcdfilter = "default";
      };
    };
  };

  ################################
  # Bluetooth
  ################################

  hardware.bluetooth = {
    enable = true;
    # Default flipped to false upstream; turn on so the Xbox controller is
    # discoverable at login without a manual toggle.
    powerOnBoot = true;
  };
  # No blueman: Plasma already ships BlueDevil when Bluetooth is enabled, and
  # blueman would add a second tray applet.

  ################################
  # NetworkManager
  ################################

  networking.networkmanager = {
    enable = true;
    dns = "systemd-resolved";
  };

  ################################
  # Laptop: lid / power behavior
  ################################

  services.logind.settings.Login = {
    HandleLidSwitch = "suspend";
    # Don't suspend just because the lid closes while on AC (e.g. docked or
    # downloading). Change to "suspend" if you always want it to sleep.
    HandleLidSwitchExternalPower = "ignore";
    HandlePowerKey = "poweroff";
  };

  ################################
  # Printing
  ################################

  services.printing.enable = true;

  # mDNS/DNS-SD so network printers (and other .local devices) are found
  # automatically. openFirewall allows mDNS (UDP 5353) in, which discovery
  # needs.
  services.avahi = {
    enable = true;
    nssmdns4 = true;
    openFirewall = true;
  };
}
