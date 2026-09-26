{ pkgs, lib, ... }:

{
  home.username = "austin";
  home.homeDirectory = "/home/austin";

  # Must match the release you first installed with (NOT the current release).
  # Kept in sync with system.stateVersion in hosts/shitbox/configuration.nix
  # (both 25.11). If you change one, change the other.
  home.stateVersion = "25.11";

  xdg.enable = true;

  ###############################
  # Zsh + Starship integration
  ###############################

  programs.zsh = {
    enable = true;
    enableCompletion = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;

    # `history` is managed declaratively rather than via raw initContent.
    history = {
      size = 10000;
      save = 10000;
      ignoreDups = true;
      ignoreSpace = true;
      extended = true;
    };

    shellAliases = {
      ll = "ls -alF";
      la = "ls -A";
      l = "ls -CF";

      # Gaming helper: MangoHud overlay + GameMode wrapping Steam.
      steam-hud = "MANGOHUD=1 gamemoderun steam";

      # Rebuild shortcuts (uses nh from the flake dev shell / system).
      rebuild = "sudo nixos-rebuild switch --flake ~/nixos-config#shitbox";
      rebuild-nh = "nh os switch ~/nixos-config";
    };
  };

  programs.starship = {
    enable = true;
    enableZshIntegration = true;

    settings = {
      add_newline = false;
      command_timeout = 1000;

      format = lib.concatStrings [
        "$directory"
        "$git_branch"
        "$git_status"
        "$nix_shell"
        "$cmd_duration"
        "$line_break"
        "$character"
      ];

      directory = {
        truncation_length = 3;
        truncate_to_repo = true;
      };

      nix_shell = {
        symbol = " ";
        format = "[$symbol$state]($style) ";
      };
    };
  };

  ###############################
  # Git
  ###############################

  programs.git = {
    enable = true;
    # TODO: set these to your real identity.
    userName = "Austin";
    userEmail = "austin@example.com";

    extraConfig = {
      init.defaultBranch = "main";
      pull.rebase = true;
      push.autoSetupRemote = true;
    };
  };

  ###############################
  # Neovim (single source of truth)
  ###############################

  # Previously neovim was "installed but empty" in three places (system
  # programs.neovim, system environment.systemPackages, and an EDITOR var).
  # It now lives only here, with actual configuration.
  programs.neovim = {
    enable = true;
    defaultEditor = true;
    viAlias = true;
    vimAlias = true;

    extraConfig = ''
      set number relativenumber
      set expandtab shiftwidth=2 tabstop=2
      set smartindent
      set ignorecase smartcase
      set undofile
      set termguicolors
      set scrolloff=5
      set clipboard=unnamedplus
    '';

    plugins = with pkgs.vimPlugins; [
      vim-nix
      nvim-treesitter.withAllGrammars
      telescope-nvim
      plenary-nvim
      gitsigns-nvim
    ];
  };

  ###############################
  # CLI tools & env
  ###############################

  programs.htop.enable = true;

  home.packages = with pkgs; [
    jq
    fastfetch
    btop
    mangohud
  ];

  # MangoHud overlay config (per-user, pairs with the steam-hud alias).
  xdg.configFile."MangoHud/MangoHud.conf".text = ''
    fps
    frametime
    cpu_temp
    gpu_temp
    ram
    vram
    position=top-left
    font_size=20
    background_alpha=0.4
    toggle_hud=Shift_R+F12
  '';

  home.sessionVariables = {
    EDITOR = "nvim";
    PAGER = "less";
  };
}
