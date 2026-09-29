{ pkgs, ... }:

# Updates happen only when you ask for them. `update` opens a menu (or takes
# system / flatpak / brew / all as an argument); each part shows what would
# change and asks before applying anything. Nothing here runs on a timer.
let
  flake = "/home/austin/nixos-config";

  confirm = ''
    confirm() {
      local reply
      read -r -p "$1 [y/N] " reply
      [[ $reply == [yY]* ]]
    }
  '';

  # [s] System: update flake.lock on this laptop, build the result, show
  # which packages change, and switch to it only after a yes. On yes the
  # new config version is committed, tagged and pushed; on no (or a failed
  # build) the repo is put back exactly as it was.
  updateSystem = pkgs.writeShellApplication {
    name = "update-system";
    runtimeInputs = with pkgs; [
      coreutils
      git
      nvd
      python3
    ];
    text = ''
      ${confirm}
      cd ${flake}
      files=(flake.lock flake.nix README.md)

      if [ -n "$(git status --porcelain -- "''${files[@]}")" ]; then
        echo "flake.lock, flake.nix or README.md has uncommitted changes in ${flake}."
        echo "Commit or discard them first."
        exit 1
      fi

      echo "Fetching config changes from GitHub..."
      if ! git pull --ff-only --quiet; then
        echo "git pull failed (offline, or local commits that need merging first)."
        exit 1
      fi

      log=$(mktemp)
      trap 'rm -f "$log"' EXIT
      echo "Checking for updates..."
      nix flake update 2>&1 | tee "$log"
      if git diff --quiet -- flake.lock; then
        echo "No updates: every input is already at its newest version."
        if [ "$(nixos-version --configuration-revision 2>/dev/null || true)" != "$(git rev-parse HEAD)" ]; then
          echo "(The running system isn't built from the latest config commit; \`rebuild\` applies it.)"
        fi
        exit 0
      fi

      # Bump the config version (flake.nix, README "Current version" and a
      # Versions row naming the updated inputs), and commit, so the build
      # carries a clean configuration revision.
      version=$(python3 .github/workflows/bump-version.py "$log")
      git commit --quiet -m "chore: update flake.lock ($version)" -- "''${files[@]}"
      undo() {
        git reset --quiet --soft HEAD~1
        git restore --staged --worktree -- "''${files[@]}"
      }

      echo "Building $version (nothing on the system changes yet)..."
      if ! new=$(nix build --no-link --print-out-paths "${flake}#nixosConfigurations.shitbox.config.system.build.toplevel"); then
        undo
        echo "The build failed, so nothing was applied. flake.lock is back where it was."
        exit 1
      fi

      echo
      echo "What $version changes compared to the running system:"
      nvd diff /run/current-system "$new"
      echo
      if ! confirm "Apply $version now?"; then
        undo
        echo "Not applied. flake.lock is back where it was."
        exit 0
      fi

      if ! sudo nixos-rebuild switch --flake "${flake}#shitbox"; then
        echo "Switching failed. The $version commit is kept locally (not pushed)."
        exit 1
      fi
      git tag -a "$version" -m "Config $version"
      if git push --quiet && git push --quiet origin "$version"; then
        echo "$version is applied, and pushed to GitHub with its tag."
      else
        echo "$version is applied, but pushing failed. Later, run:"
        echo "  cd ${flake} && git push && git push origin $version"
      fi
    '';
  };

  # [f] Flatpak: `flatpak update` lists pending updates and asks before
  # installing them. System-wide apps may show a password prompt.
  updateFlatpak = pkgs.writeShellApplication {
    name = "update-flatpak";
    runtimeInputs = [ pkgs.flatpak ];
    text = ''
      echo "Checking Flatpak apps for updates..."
      flatpak update
    '';
  };

  update = pkgs.writeShellApplication {
    name = "update";
    runtimeInputs = [
      updateSystem
      updateFlatpak
    ];
    text = ''
      # brew-update comes from modules/homebrew.nix. A failure in one part
      # is reported but doesn't stop the menu or the other parts.
      run() {
        "$@" || echo "($1 stopped with an error; see above.)"
        echo
      }
      all() {
        run update-system
        run update-flatpak
        run brew-update
      }

      case "''${1:-}" in
        system) run update-system; exit ;;
        flatpak) run update-flatpak; exit ;;
        brew) run brew-update; exit ;;
        all) all; exit ;;
        "") ;;
        *)
          echo "Usage: update [system|flatpak|brew|all]"
          exit 1
          ;;
      esac

      while true; do
        cat <<'MENU'
        Updates
        ───────
        [s] System (NixOS)   check, show changes, ask to apply
        [f] Flatpak apps
        [b] Homebrew tools
        [a] All of the above
        [q] Quit

      MENU
        read -r -n 1 -p "  Choose: " key
        echo
        echo
        case $key in
          s | S) run update-system ;;
          f | F) run update-flatpak ;;
          b | B) run brew-update ;;
          a | A) all ;;
          q | Q | "") exit 0 ;;
          *) echo "No option '$key'." && echo ;;
        esac
      done
    '';
  };
in
{
  environment.systemPackages = [
    update
    updateSystem
    updateFlatpak
  ];
}
