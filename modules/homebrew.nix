{ lib, pkgs, ... }:

let
  prefix = "/home/linuxbrew/.linuxbrew";
  brewfile = ../Brewfile;
in
{
  ################################
  # Homebrew for fast-moving standalone CLI tools
  ################################

  # The formulas are listed in /Brewfile; everything else stays in Nix. See
  # "Homebrew" in README.md for why the split is where it is.

  # Homebrew's Linux bottles and its bundled Ruby are ordinary prebuilt
  # binaries that expect /lib64/ld-linux-x86-64.so.2; nix-ld provides it.
  programs.nix-ld.enable = true;

  # Homebrew's default Linux prefix, owned by the user so brew never needs
  # sudo.
  systemd.tmpfiles.rules = [ "d /home/linuxbrew 0755 austin users -" ];

  # Appended, not prepended: if a brew dependency shares a name with a Nix
  # tool (python3, git, curl, ...), the Nix one keeps winning.
  environment.extraInit = ''
    export PATH="$PATH:${prefix}/bin:${prefix}/sbin"
  '';
  # Tab completion for brew and its formulas (gh, rg, fd, ...): add brew's
  # zsh completion directory before Home Manager's zsh runs compinit.
  home-manager.users.austin.programs.zsh.initContent = lib.mkOrder 550 ''
    fpath+=(${prefix}/share/zsh/site-functions)
  '';

  environment.variables = {
    HOMEBREW_PREFIX = prefix;
    HOMEBREW_CELLAR = "${prefix}/Cellar";
    HOMEBREW_REPOSITORY = "${prefix}/Homebrew";
    HOMEBREW_NO_ANALYTICS = "1";
    HOMEBREW_NO_ENV_HINTS = "1";
  };

  # Installs Homebrew on first run, then makes the installed formulas match
  # /Brewfile: installs missing ones, upgrades outdated ones, and removes
  # ones that aren't listed (so the Brewfile stays the source of truth).
  systemd.user.services.brew-bundle = {
    description = "Apply the Brewfile from the NixOS config";
    unitConfig.ConditionUser = "austin";
    serviceConfig.Type = "oneshot";
    # Offline runs are skipped (see the script), so a failure here is real:
    # raise a desktop notification (modules/notify-failure.nix).
    onFailure = [ "notify-failure@%n.service" ];
    environment = {
      HOMEBREW_NO_ANALYTICS = "1";
      HOMEBREW_NO_ENV_HINTS = "1";
    };
    path = with pkgs; [
      bash
      coreutils
      curl
      file
      findutils
      gawk
      git
      glibc.bin # ldd, which brew uses to read the glibc version
      gnugrep
      gnused
      gnutar
      gzip
      procps
      which
      xz
    ];
    script = ''
      if ! curl -fsSI --max-time 15 -o /dev/null https://github.com; then
        echo "No network; skipping until the next run."
        exit 0
      fi
      if [ ! -d ${prefix}/Homebrew ]; then
        echo "Installing Homebrew into ${prefix}"
        # Clone beside the final path so an interrupted clone isn't mistaken
        # for an installed Homebrew on the next run.
        rm -rf ${prefix}/Homebrew.partial
        git clone https://github.com/Homebrew/brew ${prefix}/Homebrew.partial
        mv ${prefix}/Homebrew.partial ${prefix}/Homebrew
      fi
      mkdir -p ${prefix}/bin
      ln -sfn ../Homebrew/bin/brew ${prefix}/bin/brew
      brew=${prefix}/bin/brew
      "$brew" bundle install --file=${brewfile}
      "$brew" bundle cleanup --force --file=${brewfile}
    '';
  };
  systemd.user.timers.brew-bundle = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnStartupSec = "5min";
      OnCalendar = "daily";
      Persistent = true;
      RandomizedDelaySec = "30min";
    };
  };
}
