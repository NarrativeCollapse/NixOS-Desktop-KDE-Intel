# Plasma and KDE app settings via plasma-manager (flake input).
#
# Only the settings written here are managed; everything else you change in
# System Settings is left alone (programs.plasma.overrideConfig = false, the
# default). To bring more of your current desktop under the config, run
#   nix run github:nix-community/plasma-manager
# which prints your current Plasma settings as Nix, and copy the parts you
# want to keep here.
{ lib, ... }:

{
  programs.plasma.enable = true;

  # plasma-manager's web-search-keywords module always writes KRunner's web
  # shortcut settings, including an empty "preferred shortcuts" list that
  # would reset your choices in System Settings. Write nothing there instead.
  programs.plasma.configFile.kuriikwsfilterrc.General = lib.mkForce { };

  # A Konsole profile using the Nerd Font, so the welcome banner, fastfetch,
  # eza and Starship icons fit the terminal grid (see bling.nix).
  programs.konsole = {
    enable = true;
    defaultProfile = "NixOS";
    profiles.NixOS = {
      name = "NixOS";
      colorScheme = "Breeze";
      font = {
        name = "JetBrainsMono Nerd Font Mono";
        size = 11;
      };
    };
  };
}
