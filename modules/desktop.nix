{ pkgs, ... }:

let
  # Default wallpaper for the desktop, the lock screen and the login screen
  # (one of the images in wallpapers/).
  wallpaper = ../wallpapers/gas-masks.jpg;
in
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

  # Use the stock Xwayland from cache.nixos.org instead of compiling it.
  # NixOS otherwise sets Xwayland's built-in X11 font path, which changes
  # the package so that every nixpkgs update recompiles it (minutes on a
  # laptop). Only old X11 apps that use core X fonts (not fontconfig) are
  # affected, and nothing here uses them.
  programs.xwayland.defaultFontPath = "";

  # Extra wallpapers: the images in wallpapers/ at the repo root, installed
  # where Plasma's wallpaper picker lists them next to the stock ones. Add
  # or remove an image there and rebuild.
  environment.systemPackages = [
    (pkgs.runCommand "extra-wallpapers" { } ''
      install -Dm644 -t $out/share/wallpapers ${../wallpapers}/*
    '')
    # Login screen (SDDM's Breeze theme) background.
    (pkgs.writeTextDir "share/sddm/themes/breeze/theme.conf.user" ''
      [General]
      background=${wallpaper}
    '')
  ];
  environment.pathsToLink = [ "/share/wallpapers" ];

  # Desktop and lock screen wallpaper (plasma-manager; see
  # home/austin/plasma.nix). Applied at the first login after a rebuild that
  # changes it; one picked by hand in System Settings stays until then.
  home-manager.users.austin.programs.plasma = {
    workspace.wallpaper = wallpaper;
    kscreenlocker.appearance.wallpaper = wallpaper;
  };

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
  # XDG portals
  ################################

  # Plasma enables the portals (and dconf); this routes xdg-open through
  # them too, so sandboxed and Flatpak apps open links in the default app.
  xdg.portal.xdgOpenUsePortal = true;

  ################################
  # Flatpak + Flathub
  ################################

  # Managed by nix-flatpak (flake input): the Flathub remote and the apps
  # listed below are installed by flatpak-managed-install.service at boot and
  # after each rebuild, retried with backoff while offline. Apps are never
  # updated automatically; `update` ([f]) does that when you choose.
  services.flatpak = {
    enable = true;
    # Flathub is the default remote. Add apps by their Flathub ID (the part
    # after /apps/ in the app's flathub.org address).
    packages = [
      "com.google.Chrome"
      "org.videolan.VLC"
      "com.github.tchx84.Flatseal" # manage Flatpak app permissions
      "org.qbittorrent.qBittorrent"
    ];
    # Leave apps installed by hand (Discover, `flatpak install`) alone. Set to
    # true once everything you want is listed above to make this list the
    # source of truth, like the Brewfile.
    uninstallUnmanaged = false;
    restartOnFailure.exponentialBackoff.enable = true;
  };

  ################################
  # Mullvad VPN (official module)
  ################################

  # The module runs the daemon and installs the app itself, so don't also
  # list mullvad-vpn in environment.systemPackages.
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

  # Plasma turns these on by default. Off here, since nothing on this
  # machine uses them:
  # - Orca screen reader and the speech-dispatcher text-to-speech service
  #   (~770 MB). Turn both back on if you need a screen reader.
  services.orca.enable = false;
  services.speechd.enable = false;
  # - The KDE PIM backend (Akonadi, ~380 MB), which only KDE's mail, contact
  #   and calendar apps (none installed) and the clock's calendar-events
  #   plugin use.
  programs.kde-pim.enable = false;

  ################################
  # Environment variables
  ################################

  # Prefer Wayland-native behavior for Electron/Chromium apps.
  environment.sessionVariables.NIXOS_OZONE_WL = "1";

  ################################
  # Fonts
  ################################

  # Plasma adds Noto and Hack, and the NixOS defaults add DejaVu, Liberation
  # and more. Listed here: what the config relies on directly.
  fonts = {
    packages = with pkgs; [
      noto-fonts-color-emoji # color emoji everywhere
      nerd-fonts.jetbrains-mono # icons for the terminal (see bling.nix)
    ];
    # Subpixel antialiasing for the laptop's RGB LCD panel.
    fontconfig.subpixel.rgba = "rgb";
  };

  ################################
  # Bluetooth
  ################################

  # Powered on at boot by default, so the Xbox controller connects at login.
  # No blueman: Plasma already ships BlueDevil when Bluetooth is enabled, and
  # blueman would add a second tray applet.
  hardware.bluetooth.enable = true;

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

  # Closing the lid suspends on battery (the default), but not on AC (e.g.
  # docked or downloading). Remove this to always suspend.
  services.logind.settings.Login.HandleLidSwitchExternalPower = "ignore";

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
