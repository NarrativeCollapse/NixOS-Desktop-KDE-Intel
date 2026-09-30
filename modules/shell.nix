{ pkgs, ... }:

{
  ################################
  # Users & shell
  ################################

  users.users.austin = {
    isNormalUser = true;
    description = "Austin";
    # No "audio"/"video" groups: logind already grants the logged-in user
    # access to sound and GPU devices, and "audio" would let apps open sound
    # devices directly, around PipeWire. (No "podman" group either; rootless
    # podman doesn't use one.)
    extraGroups = [
      "wheel"
      "networkmanager"
    ];
    shell = pkgs.zsh;
  };

  # Remember the sudo password for 15 minutes instead of 5.
  security.sudo.extraConfig = ''
    Defaults timestamp_timeout=15
  '';
  # If you'd like the Rust reimplementation instead, swap the line above for:
  #   security.sudo.enable = false;
  #   security.sudo-rs.enable = true;

  ################################
  # Containers: Podman
  ################################

  virtualisation.podman = {
    enable = true;
    dockerCompat = true;
    defaultNetwork.settings.dns_enabled = true;
  };

  ################################
  # System packages (CLI + desktop apps)
  ################################

  # Kept lean: only what's genuinely system-wide. Per-user tools and editor
  # config live in Home Manager (home/austin/), fast-moving CLI tools in the
  # Brewfile, and apps that come with a module (podman, mullvad) aren't
  # repeated here.
  environment.systemPackages = with pkgs; [
    # Browser
    librewolf

    # KDE apps on top of Plasma's own. Nix packages rather than Flatpaks:
    # they use the Qt and Breeze already installed for Plasma (a Flatpak
    # would download a separate KDE runtime of several hundred MB) and
    # update with the system.
    kdePackages.kcalc # calculator
    kdePackages.isoimagewriter # writes ISO images to USB sticks

    # Containers
    podman-compose
    distrobox

    # Essentials (git system-wide so root can rebuild from the flake). Other
    # command-line tools are in Home Manager and the Brewfile.
    git
    curl
  ];

  ################################
  # System shell: zsh
  ################################

  # Needed so pkgs.zsh is a valid login shell for austin. The interactive
  # configuration (aliases, prompt, plugins) is in Home Manager. root keeps
  # the default bash, which has no Home Manager config to miss and is the
  # safer shell for recovery.
  programs.zsh.enable = true;
}
