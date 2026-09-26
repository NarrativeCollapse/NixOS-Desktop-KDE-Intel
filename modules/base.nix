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

    # Weekly GC. "shitbox" implies a small disk, so keep retention short.
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 3d";
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

  # Alternative GC frontend: `programs.nh.enable = true` with
  # `programs.nh.clean.enable = true` would replace the nix.gc block above
  # with nh's nicer interface. Pick one, not both.

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
