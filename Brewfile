# Command-line tools managed by Homebrew instead of Nix: standalone tools
# with no shell or system integration, where upstream moves fast. Everything
# else stays in the Nix config (see "Homebrew" in README.md).
#
# modules/homebrew.nix applies this file daily (and ~5 minutes after login):
# missing formulas are installed, outdated ones upgraded, and formulas not
# listed here are uninstalled. Edit, commit, and it takes effect on the next
# run (or `systemctl --user start brew-bundle`).

brew "yt-dlp"      # breaks when sites change; needs fast updates
brew "gh"          # GitHub CLI
brew "glab"        # GitLab CLI
brew "ripgrep"     # rg
brew "fd"
brew "bat"
brew "jq"
brew "yq"
brew "television"  # tv, fuzzy finder
brew "dysk"        # disk usage overview
brew "trash-cli"
brew "tealdeer"    # tldr
brew "shellcheck"
brew "stress-ng"
