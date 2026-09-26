{ lib, ... }:

{
  ################################
  # Nix settings
  ################################

  nix = {
    settings = {
      experimental-features = [
        "nix-command"
        "flakes"
      ];
      # Deduplicate the store automatically on every build.
      auto-optimise-store = true;
    };

    # Extra store optimisation pass on a schedule (complements
    # auto-optimise-store, which only runs at build time).
    optimise = {
      automatic = true;
      dates = [ "weekly" ];
    };

    # Optional QoL, off by default:
    # settings.trusted-users = [ "austin" ];  # sudo-less cache/builder ops
    # settings.warn-dirty = false;            # silence "Git tree is dirty"
  };

  ################################
  # nh: rebuild helper + GC
  ################################

  # `nh os switch` rebuilds from NH_FLAKE; `nh clean` replaces nix.gc (the nh
  # module warns if both are enabled).
  programs.nh = {
    enable = true;
    flake = "/home/austin/nixos-config";
    # Two weeks (and never fewer than 5 generations) leaves room to roll back
    # an update whose breakage isn't noticed for a few days.
    clean = {
      enable = true;
      dates = "weekly";
      extraArgs = "--keep-since 14d --keep 5";
    };
  };

  ################################
  # Locale / time
  ################################

  time.timeZone = "America/Chicago";

  i18n = {
    defaultLocale = "en_US.UTF-8";
    # US conventions for the individual LC_* categories.
    extraLocaleSettings = {
      LC_ADDRESS = "en_US.UTF-8";
      LC_MEASUREMENT = "en_US.UTF-8";
      LC_MONETARY = "en_US.UTF-8";
      LC_NUMERIC = "en_US.UTF-8";
      LC_PAPER = "en_US.UTF-8";
      LC_TIME = "en_US.UTF-8";
    };
  };

  console.keyMap = "us";

  ################################
  # nixpkgs config
  ################################

  nixpkgs.config = {
    # IMPORTANT:
    #  Whenever you add a new unfree package (e.g. proprietary app),
    #  you must add its name here or builds will fail with an
    #  "unfree license" error.
    allowUnfreePredicate =
      pkg:
      builtins.elem (lib.getName pkg) [
        "steam"
        "steam-original"
        "steam-runtime"
        "steam-unwrapped"
        "discord"
        "vscode"
        "google-chrome"
        "mullvad-vpn"
      ];
  };

  ################################
  # Logging / misc
  ################################

  services.journald.extraConfig = ''
    SystemMaxUse=500M
    RuntimeMaxUse=200M
  '';

  # NOTE: programs.command-not-found was removed. It relies on a
  # channel-populated SQLite index that flake-based systems do not generate,
  # so it was dead weight. If you want the feature back, use nix-index +
  # `comma` instead:
  #
  #   programs.nix-index.enable = true;
  #   programs.nix-index.enableZshIntegration = true;
}
