# Ghostty terminal, configured after Samuel Lawrentz's "A Minimal Ghostty
# Config" (https://samuellawrentz.com/blog/minimal-ghostty-config/): large
# type with a little extra line spacing, on a translucent, blurred black
# background.
#
# Left out from that config: the macOS-only settings (font-thicken,
# font-thicken-strength and the hidden titlebar) and the cmd+s / cmd+b
# keybinds, which send tmux's Ctrl-a prefix and do nothing without tmux.
#
# Ghostty bundles JetBrains Mono and the Nerd Font icons, so the welcome
# banner, fastfetch, eza and Starship icons need no font setting here.
_:

{
  programs.ghostty = {
    enable = true;
    settings = {
      font-size = 16;
      adjust-cell-height = 1;

      background = "#000000";
      background-opacity = 0.85;
      # Blur behind the window; KDE Plasma supports it on Wayland.
      background-blur = 16;
    };
  };
}
