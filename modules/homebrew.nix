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

  # `brew-update` (also [b] in the `update` menu): installs Homebrew the first
  # time, then shows how the installed formulas differ from /Brewfile
  # (missing, outdated, or not listed) and applies that only if you say yes.
  # Nothing runs on a timer; tools change only when you run it.
  environment.systemPackages = [
    (pkgs.writeShellApplication {
      name = "brew-update";
      runtimeInputs = with pkgs; [
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
      text = ''
        brew=${prefix}/bin/brew
        brewfile=${brewfile}
        confirm() {
          local reply
          read -r -p "$1 [y/N] " reply
          [[ $reply == [yY]* ]]
        }

        if ! curl -fsSI --max-time 15 -o /dev/null https://github.com; then
          echo "No network connection; can't check Homebrew for updates."
          exit 1
        fi

        if [ ! -d ${prefix}/Homebrew ]; then
          echo "Homebrew isn't installed yet."
          confirm "Install it into ${prefix} now?" || exit 0
          # Clone beside the final path so an interrupted clone isn't
          # mistaken for an installed Homebrew next time.
          rm -rf ${prefix}/Homebrew.partial
          git clone https://github.com/Homebrew/brew ${prefix}/Homebrew.partial
          mv ${prefix}/Homebrew.partial ${prefix}/Homebrew
        fi
        mkdir -p ${prefix}/bin
        ln -sfn ../Homebrew/bin/brew ${prefix}/bin/brew

        echo "Checking Homebrew for updates..."
        "$brew" update --quiet
        pending=$("$brew" bundle check --verbose --file="$brewfile" 2>&1 || true)
        # Formulas not in the Brewfile (the dry run also lists download
        # caches brew would clear; those aren't worth asking about).
        extra=$("$brew" bundle cleanup --file="$brewfile" 2>/dev/null \
          | sed -n '/^Would uninstall/,/^Would .brew cleanup/p' \
          | grep -v '^Would .brew cleanup' || true)
        if "$brew" bundle check --quiet --file="$brewfile" >/dev/null 2>&1 && [ -z "$extra" ]; then
          echo "Homebrew tools are up to date."
          exit 0
        fi

        echo
        echo "$pending"
        if [ -n "$extra" ]; then echo "$extra"; fi
        echo
        if ! confirm "Apply these Homebrew changes?"; then
          echo "Nothing changed."
          exit 0
        fi
        "$brew" bundle install --file="$brewfile"
        "$brew" bundle cleanup --force --file="$brewfile"
        echo "Homebrew tools updated."
      '';
    })
  ];
}
