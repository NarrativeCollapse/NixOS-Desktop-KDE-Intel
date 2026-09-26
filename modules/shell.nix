{ pkgs, ... }:

{
  ################################
  # Users & shell
  ################################

  users.users.austin = {
    isNormalUser = true;
    description = "Austin";
    # Removed the "podman" supplementary group: rootless podman doesn't use a
    # named group like that and it would error if the group doesn't exist.
    extraGroups = [
      "wheel"
      "networkmanager"
      "video"
      "audio"
    ];
    shell = pkgs.zsh;
  };

  users.defaultUserShell = pkgs.zsh;

  security.sudo = {
    wheelNeedsPassword = true;
    extraConfig = ''
      Defaults timestamp_timeout=15
    '';
  };
  # If you'd like the Rust reimplementation instead, swap the block above for:
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

  # Kept lean: things that are genuinely system-wide. Per-user CLI tooling and
  # editor config live in home/austin/home.nix. Removed:
  #   - podman        (installed by virtualisation.podman.enable)
  #   - mullvad-vpn   (installed by services.mullvad-vpn)
  #   - neovim        (configured via Home Manager now; see home.nix)
  #   - htop          (moved to Home Manager)
  environment.systemPackages = with pkgs; [
    # Browser
    librewolf

    # Containers
    podman-compose
    distrobox

    # Terminal tools
    vifm
    yt-dlp

    # Essentials
    git
    curl
    wget

    # NixOS icon set for KDE launcher
    nixos-icons
  ];

  ################################
  # System shell: zsh
  ################################

  # Needed so pkgs.zsh is a valid login shell for the accounts above. The
  # interactive configuration (aliases, prompt, plugins) is defined per-user in
  # Home Manager.
  programs.zsh.enable = true;
}
