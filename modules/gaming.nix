{ pkgs, ... }:

{
  ################################
  # Gaming: Steam + Proton
  ################################

  programs.steam = {
    enable = true;
    # Opens TCP 27036-27037 and UDP 10400-10401/27031-27036 on every network,
    # public Wi-Fi included. Set to false if you don't use Remote Play.
    remotePlay.openFirewall = true;
    # dedicatedServer.openFirewall (27015) is deliberately off: it is only
    # for hosting Source dedicated servers.
    gamescopeSession.enable = true;
    # Proton-GE shows up in each game's Properties → Compatibility list next
    # to Valve's Proton builds. It updates with the rest of the system (via
    # flake.lock updates) instead of through ProtonUp-Qt.
    extraCompatPackages = [ pkgs.proton-ge-bin ];
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
}
