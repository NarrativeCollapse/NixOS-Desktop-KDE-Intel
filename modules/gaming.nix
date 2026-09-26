{ config, lib, pkgs, ... }:

{
  ################################
  # Gaming: Steam + Proton
  ################################

  programs.steam = {
    enable = true;
    remotePlay.openFirewall = true;
    dedicatedServer.openFirewall = true;
    gamescopeSession.enable = true;
  };

  hardware.steam-hardware.enable = true;

  ################################
  # Xbox wireless controller (Bluetooth)
  ################################

  hardware.xpadneo.enable = true;

  ################################
  # Game optimization helpers
  ################################

  programs.gamemode.enable = true;

  # NOTE: MangoHud is installed per-user in home/austin/home.nix so the overlay
  # config lives with the user. The `steam-hud` alias there wires it together.
  # 32-bit vulkan/GL for Proton comes from hardware.graphics.enable32Bit
  # (modules/hardware.nix) + pipewire alsa.support32Bit (modules/desktop.nix).

  ################################
  # Optional extras (off by default)
  ################################

  # Wired Xbox pads / the Xbox Wireless USB dongle (xpadneo above only covers
  # Bluetooth). Builds an out-of-tree module and fetches controller firmware:
  # hardware.xone.enable = true;

  # Lets gamescope renice itself for smoother frame pacing. Known to break
  # gamescope launches inside Steam's FHS env for some setups — test before
  # keeping:
  # programs.gamescope.capSysNice = true;

  # Proton-GE for better game compatibility: simplest is adding `protonup-qt`
  # to home.packages and installing GE builds through it. The nix-gaming flake
  # (github:fufexan/nix-gaming) is the heavier, fully-declarative route.
}
