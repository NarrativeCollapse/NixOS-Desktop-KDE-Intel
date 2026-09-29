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

  # Breeze Dark: dark color scheme for apps and windows, and the dark Plasma
  # style for the panel and widgets. (Wallpapers are set in
  # modules/desktop.nix, next to the wallpaper files.)
  programs.plasma.workspace = {
    colorScheme = "BreezeDark";
    theme = "breeze-dark";
  };

  # Taskbar tweaks, made by a small Plasma script on the existing panel
  # (declaring the panel in plasma-manager would replace your whole layout):
  # - pin Google Chrome (the Flatpak, see modules/desktop.nix);
  # - unpin the "default web browser" launcher (LibreWolf; still installed
  #   and in the app menu) and System Settings (still in the app menu);
  # - give the app launcher (start menu) the white NixOS snowflake, from the
  #   nixos-icons package NixOS installs on graphical systems;
  # - the taskbar clock always uses 24-hour time (the system does too; see
  #   LC_TIME in modules/base.nix).
  # It runs at the first login after a rebuild that changes it, so changes
  # you make by hand afterwards stay.
  programs.plasma.startup.desktopScript.taskbar.text = ''
    const pin = "applications:com.google.Chrome.desktop";
    const unpin = [
      "preferred://browser",
      "applications:systemsettings.desktop",
      "applications:org.kde.systemsettings.desktop",
    ];
    for (const panel of panels()) {
      for (const widget of panel.widgets()) {
        if (widget.type === "org.kde.plasma.icontasks" || widget.type === "org.kde.plasma.taskmanager") {
          widget.currentConfigGroup = ["General"];
          let launchers = widget.readConfig("launchers", []);
          if (typeof launchers === "string") {
            launchers = launchers ? launchers.split(",") : [];
          }
          launchers = launchers.filter((l) => !unpin.includes(l));
          if (!launchers.includes(pin)) {
            launchers.push(pin);
          }
          widget.writeConfig("launchers", launchers);
        } else if (widget.type === "org.kde.plasma.kickoff" || widget.type === "org.kde.plasma.kicker") {
          widget.currentConfigGroup = ["General"];
          widget.writeConfig("icon", "nix-snowflake-white");
        } else if (widget.type === "org.kde.plasma.digitalclock") {
          widget.currentConfigGroup = ["Appearance"];
          widget.writeConfig("use24hFormat", 2);
        }
      }
    }
  '';

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
