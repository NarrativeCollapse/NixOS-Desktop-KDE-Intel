{
  config,
  osConfig,
  pkgs,
  lib,
  ...
}:

{
  # Bazzite-style MOTD, fastfetch, and CLI tools (eza, atuin, zoxide, ...).
  imports = [
    ./bling.nix
    ./plasma.nix
  ];

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
    # Keep .zshrc and .zsh_history in ~ rather than moving to ~/.config/zsh.
    dotDir = config.home.homeDirectory;
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

    # ls/ll/la come from programs.eza in bling.nix; steam-hud from
    # modules/gaming.nix.
    shellAliases = {
      # Rebuild from the config checkout (nh's flake path, modules/base.nix).
      # `nh os switch` does the same with a package diff.
      rebuild = "sudo nixos-rebuild switch --flake ${osConfig.programs.nh.flake}#${osConfig.networking.hostName}";
    };
  };

  programs.starship = {
    enable = true;

    settings = {
      add_newline = false;
      command_timeout = 1000;

      format = lib.concatStrings [
        "$container"
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
    settings = {
      # GitHub no-reply address: links commits to the NarrativeCollapse
      # account without publishing a personal email.
      user.name = "Austin";
      user.email = "333098847+NarrativeCollapse@users.noreply.github.com";
      init.defaultBranch = "main";
      pull.rebase = true;
      push.autoSetupRemote = true;
    };
  };

  ###############################
  # Neovim
  ###############################

  programs.neovim = {
    enable = true;
    # Sets EDITOR and VISUAL to nvim.
    defaultEditor = true;
    viAlias = true;
    vimAlias = true;
    # No Ruby or Python plugins are used; skip their providers.
    withRuby = false;
    withPython3 = false;

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

    initLua = ''
      vim.g.mapleader = " "

      -- Treesitter highlighting wherever a parser is available (Neovim
      -- bundles lua/vim/vimdoc/markdown/query; the rest come from below).
      vim.api.nvim_create_autocmd("FileType", {
        callback = function(args)
          pcall(vim.treesitter.start, args.buf)
        end,
      })

      require("gitsigns").setup()

      local telescope = require("telescope.builtin")
      vim.keymap.set("n", "<leader>ff", telescope.find_files, { desc = "Find files" })
      vim.keymap.set("n", "<leader>fg", telescope.live_grep, { desc = "Grep" })
      vim.keymap.set("n", "<leader>fb", telescope.buffers, { desc = "Buffers" })
    '';

    # live_grep needs ripgrep; kept on nvim's PATH only.
    extraPackages = [ pkgs.ripgrep ];

    plugins = with pkgs.vimPlugins; [
      vim-nix
      # A short list instead of withAllGrammars (~300 parsers).
      (nvim-treesitter.withPlugins (p: [
        p.nix
        p.bash
        p.json
        p.yaml
        p.toml
        p.python
        p.diff
        p.gitcommit
      ]))
      telescope-nvim
      plenary-nvim
      gitsigns-nvim
    ];
  };

  ###############################
  # CLI tools & env
  ###############################

  # jq comes from Homebrew (see /Brewfile). For a process monitor, Plasma's
  # System Monitor (Ctrl+Esc for its process list) is built in.
  # MangoHud and its config are in modules/gaming.nix, with Steam.
  home.packages = with pkgs; [
    wl-clipboard # Wayland clipboard backend for nvim's clipboard=unnamedplus
  ];

  home.sessionVariables.PAGER = "less";
}
