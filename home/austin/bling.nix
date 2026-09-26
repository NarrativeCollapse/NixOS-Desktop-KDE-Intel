# Bazzite-style terminal, done the Nix way: a greeting (MOTD) on every new
# shell, a branded fastfetch, and the bazzite-cli tool set with its aliases.
# Adapted from ublue-os/bazzite (Apache-2.0), which installs the same tools
# with Homebrew (`ujust bazzite-cli`) and appends source lines to ~/.bashrc.
# Remove the import in home.nix to drop all of it.
{ lib, pkgs, ... }:

let
  # "v20 · generation 42 · config 1a2b3c4", shown by the MOTD and fastfetch.
  # The version comes from system.nixos.tags, which ends up in the name of
  # the running system (nixos-system-shitbox-v20-26.05...).
  sysinfo = pkgs.writeShellApplication {
    name = "nixos-system-info";
    text = ''
      ver=$(readlink /run/current-system 2>/dev/null | grep -o -- '-v[0-9]\+-' | tr -d - || true)
      gen=$(readlink /nix/var/nix/profiles/system 2>/dev/null | sed -n 's/^system-\([0-9]*\)-link$/\1/p' || true)
      rev=$(nixos-version --configuration-revision 2>/dev/null || true)
      out="generation ''${gen:-?}"
      if [ -n "$ver" ]; then out="$ver · $out"; fi
      if [ -n "$rev" ]; then
        short=''${rev:0:7}
        if [[ $rev == *-dirty ]]; then short="$short-dirty"; fi
        out="$out · config $short"
      fi
      echo "$out"
    '';
  };

  tips = pkgs.writeText "motd-tips" (
    lib.concatLines [
      "Roll back a bad rebuild with `sudo nixos-rebuild switch --rollback`, or pick an older generation in the boot menu."
      "`nix shell nixpkgs#cowsay` gives you a package for this shell only; nothing is installed permanently."
      "Put `use flake` in a project's `.envrc` and run `direnv allow`: its dev shell loads whenever you `cd` in."
      "`nh os switch` shows which packages changed before it activates the new generation."
      "Ctrl+R searches your shell history (atuin); `z <dir>` jumps to directories you visit often (zoxide)."
      "Need software that isn't in nixpkgs? `distrobox create --image fedora:latest` gives you a Fedora container that shares your home."
      "Everything on this machine is defined in ~/nixos-config, so `git log` there is your changelog."
      "`tldr <command>` shows short, practical examples of a command."
    ]
  );

  motdTemplate = pkgs.writeText "motd.md" ''
    # Welcome to NixOS 

     `$OS_NAME`

    󱋩 `$SYSINFO`

    | Command | Description |
    | ------- | ----------- |
    | `rebuild` | Apply changes from ~/nixos-config |
    | `nix flake update` | Update nixpkgs and Home Manager (run in ~/nixos-config) |
    | `nix search nixpkgs <name>` | Find a package |
    | `nix shell nixpkgs#<name>` | Try a package without installing it |
    | `fastfetch` | View system information |
    | `toggle-motd` | Turn this banner off (or back on) |

    **Tip:** $TIP

    - **󰈙** [NixOS manual](https://nixos.org/manual/nixos/stable/)
    - **󰈙** [Package search](https://search.nixos.org/packages)
    - **󰈙** [Home Manager options](https://nix-community.github.io/home-manager/options.xhtml)
    - **** [This config](https://github.com/NarrativeCollapse/NixOS-Desktop-KDE-Intel)
  '';

  motd = pkgs.writeShellApplication {
    name = "nixos-motd";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.gettext
      pkgs.glow
      pkgs.ncurses
      sysinfo
    ];
    text = ''
      if [ -e "''${XDG_CONFIG_HOME:-$HOME/.config}/no-show-user-motd" ]; then
        exit 0
      fi
      # shellcheck source=/dev/null
      OS_NAME=$(. /etc/os-release && echo "$PRETTY_NAME")
      SYSINFO=$(nixos-system-info)
      TIP=$(shuf -n 1 ${tips})
      export OS_NAME SYSINFO TIP
      # shellcheck disable=SC2016
      rendered=$(envsubst '$OS_NAME $SYSINFO $TIP' < ${motdTemplate})
      if [ -t 1 ]; then
        # When it can see the terminal, glow asks it for its colors and waits
        # up to 20s for replies some terminals (e.g. the Linux console) never
        # send. A fixed style, forced color, silenced stderr and piped stdout
        # keep it from asking.
        CLICOLOR_FORCE=1 glow -s dark -w "$(tput cols 2>/dev/null || echo 80)" - <<< "$rendered" 2>/dev/null | cat
      else
        glow -s notty - <<< "$rendered"
      fi
    '';
  };

  # Same on/off switch file as Bazzite's `ujust toggle-user-motd`.
  toggleMotd = pkgs.writeShellApplication {
    name = "toggle-motd";
    text = ''
      flag="''${XDG_CONFIG_HOME:-$HOME/.config}/no-show-user-motd"
      if [ -e "$flag" ]; then
        rm -f "$flag"
        echo "MOTD on: it will show in new shells."
      else
        mkdir -p "$(dirname "$flag")"
        touch "$flag"
        echo "MOTD off. Run toggle-motd again to bring it back."
      fi
    '';
  };
in
{
  # bazzite-cli.Brewfile, minus chezmoi/brew/bbrew (Home Manager covers them)
  # and bash-preexec (atuin's zsh integration doesn't need it).
  home.packages = [
    motd
    toggleMotd
    sysinfo
  ]
  ++ (with pkgs; [
    dysk
    glab
    glow
    shellcheck
    stress-ng
    trash-cli
    ugrep
    yq-go
  ]);

  # bling.sh's aliases that the Home Manager modules below don't provide.
  home.shellAliases = {
    grep = "ug";
    egrep = "ug -E";
    fgrep = "ug -F";
    xzgrep = "ug -z";
    xzegrep = "ug -zE";
    xzfgrep = "ug -zF";
    "l." = "eza -d .*";
    l1 = "eza -1";
    open = "xdg-open &>/dev/null";
    neofetch = "fastfetch";
  };

  programs = {
    # ls/ll/la/lt/lla -> eza, with bling.sh's flags.
    eza = {
      enable = true;
      icons = "auto";
      extraOptions = [ "--group-directories-first" ];
    };
    atuin.enable = true;
    zoxide.enable = true;
    bat.enable = true;
    fd.enable = true;
    ripgrep.enable = true;
    television.enable = true;
    gh.enable = true;
    tealdeer = {
      enable = true;
      settings.updates.auto_update = true;
    };
    # Not in Bazzite's default set, but the natural Nix addition: per-project
    # `nix develop` shells that load on `cd`.
    direnv = {
      enable = true;
      nix-direnv.enable = true;
    };

    # Bazzite's fish prompt shows a box inside containers; starship's
    # container module does the same (`$container` is in home.nix's format).
    # Distrobox boxes don't see /nix/store, so this config won't load there.
    starship.settings.container.symbol = "📦";

    zsh.initContent = lib.mkAfter "nixos-motd";

    # Bazzite's fastfetch layout with the NixOS logo; the image line shows
    # the system generation and config revision instead.
    fastfetch = {
      enable = true;
      settings = {
        logo.source = "nixos";
        display = {
          separator = "  ";
          color.keys = "light_blue";
        };
        modules = [
          {
            type = "title";
            key = " ";
            color = {
              user = "light_blue";
              at = "white";
              host = "blue";
            };
          }
          "break"
          {
            type = "command";
            key = " 󱋩";
            text = "${sysinfo}/bin/nixos-system-info";
          }
          {
            type = "os";
            key = " ";
            format = "{pretty-name}";
          }
          {
            type = "kernel";
            key = " ";
            format = "{1} {2}";
          }
          {
            type = "uptime";
            key = " 󰅐";
          }
          "break"
          {
            type = "host";
            key = " 󰾰";
          }
          {
            type = "cpu";
            key = " 󰻠";
          }
          {
            type = "gpu";
            key = " 󰍛";
          }
          {
            type = "memory";
            key = " ";
          }
          {
            type = "disk";
            key = " ";
            hideFS = "overlay";
            # /nix/store is a read-only bind mount of /; don't list it twice.
            hideFolders = "/efi:/boot:/boot/*:/nix/store";
          }
          {
            type = "display";
            key = " 󰍹";
          }
          {
            type = "battery";
            key = " ";
          }
          {
            type = "gamepad";
            key = " 󰖺";
          }
          "break"
          {
            type = "de";
            key = " 󰕮";
          }
          {
            type = "wm";
            key = " ";
          }
          {
            type = "shell";
            key = " ";
          }
          {
            type = "terminal";
            key = " ";
          }
          {
            type = "packages";
            key = " 󰏖";
          }
          "break"
          {
            type = "colors";
            paddingLeft = 2;
            symbol = "circle";
          }
        ];
      };
    };
  };
}
