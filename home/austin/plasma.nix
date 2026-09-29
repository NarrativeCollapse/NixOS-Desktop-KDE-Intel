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

  # Pin Google Chrome (the Flatpak, see modules/desktop.nix) to the taskbar.
  # Declaring the panel in plasma-manager would replace your whole panel
  # layout, so instead this small Plasma script finds the existing taskbar
  # and adds the Chrome launcher to it, leaving everything else alone. It
  # runs at the first login after a rebuild that changes it, so if you unpin
  # Chrome by hand later, it stays unpinned.
  programs.plasma.startup.desktopScript.pin-chrome.text = ''
    const launcher = "applications:com.google.Chrome.desktop";
    for (const panel of panels()) {
      for (const widget of panel.widgets()) {
        if (widget.type !== "org.kde.plasma.icontasks" && widget.type !== "org.kde.plasma.taskmanager") {
          continue;
        }
        widget.currentConfigGroup = ["General"];
        let launchers = widget.readConfig("launchers", []);
        if (typeof launchers === "string") {
          launchers = launchers ? launchers.split(",") : [];
        }
        if (!launchers.includes(launcher)) {
          launchers.push(launcher);
          widget.writeConfig("launchers", launchers);
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
