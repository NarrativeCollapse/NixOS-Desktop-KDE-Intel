# The installer ISO: a live Plasma desktop that can install shitbox.
#
# Build it on any machine with Nix (the laptop itself works):
#   nix build ~/nixos-config#installer-iso
# The ISO lands in ./result/iso/. Write it to a USB stick with ISO Image
# Writer (a Flatpak on shitbox) or any "DD mode" USB writer.
#
# Booting it gives a live Plasma session (no password). Connect to Wi-Fi
# from the panel, then double-click "Install shitbox" on the desktop, or run
# `sudo install-shitbox` in Konsole.
{
  lib,
  pkgs,
  modulesPath,
  self,
  version,
  ...
}:

let
  repoUrl = "https://github.com/NarrativeCollapse/NixOS-Desktop-KDE-Intel.git";

  # The config this ISO was built from, copied into the ISO. The GitHub repo
  # is private, so the installer can't count on cloning it.
  snapshot = "/etc/shitbox-config";
  snapshotRev = self.shortRev or self.dirtyShortRev or "unknown";

  installShitbox = pkgs.writeShellApplication {
    name = "install-shitbox";
    runtimeInputs = with pkgs; [
      coreutils
      cryptsetup
      curl
      dosfstools
      e2fsprogs
      gawk
      git
      gptfdisk
      networkmanager
      parted
      util-linux
    ];
    text = ''
      if [ "$(id -u)" -ne 0 ]; then
        exec sudo "$0" "$@"
      fi

      confirm() {
        local reply
        read -r -p "$1 [y/N] " reply
        [[ $reply == [yY]* ]]
      }
      step() {
        echo
        echo "== $1"
      }

      cat <<'INTRO'
      Install shitbox

      This erases one disk completely, encrypts it (you'll choose the
      password asked at every boot), and installs this NixOS config on it.
      INTRO
      echo "Config snapshot on this USB stick: ${version} (commit ${snapshotRev})."

      step "1. Internet"
      until curl -fsS --max-time 10 -o /dev/null https://cache.nixos.org/nix-cache-info; do
        echo "No internet connection. Packages are downloaded during the install."
        read -r -p "Press Enter to open the Wi-Fi setup (nmtui), or Ctrl+C to stop. " _
        nmtui || true
      done
      echo "Connected."

      step "2. Choose the disk to erase"
      iso_disk=$(lsblk -no PKNAME "$(findmnt -no SOURCE /iso 2>/dev/null)" 2>/dev/null || true)
      mapfile -t disks < <(lsblk -dnpo NAME,TYPE | awk '$2 == "disk" && $1 !~ /zram|loop/ { print $1 }' | grep -v -x "/dev/''${iso_disk:-none}" || true)
      if [ "''${#disks[@]}" -eq 0 ]; then
        echo "No disks found (other than this USB stick)."
        exit 1
      fi
      lsblk -dpo NAME,SIZE,MODEL,TRAN "''${disks[@]}"
      echo
      read -r -p "Disk to install on (e.g. /dev/nvme0n1): " disk
      [[ $disk == /dev/* ]] || disk="/dev/$disk"
      if [[ " ''${disks[*]} " != *" $disk "* ]]; then
        echo "'$disk' isn't one of the disks listed above. Nothing was changed."
        exit 1
      fi
      echo
      echo "EVERYTHING on $disk will be erased:"
      lsblk -po NAME,SIZE,FSTYPE,LABEL "$disk"
      read -r -p "Type the disk name ($disk) again to erase it: " again
      if [ "$again" != "$disk" ]; then
        echo "Stopped; nothing was changed."
        exit 1
      fi

      step "3. Disk encryption password"
      echo "Asked at every boot. If it's lost, the data can't be recovered."
      while true; do
        read -r -s -p "Password: " pw1
        echo
        read -r -s -p "Again: " pw2
        echo
        if [ -z "$pw1" ]; then
          echo "The password can't be empty."
        elif [ "$pw1" != "$pw2" ]; then
          echo "They don't match; try again."
        else
          break
        fi
      done

      step "4. Partitioning and encrypting $disk"
      umount -R /mnt 2>/dev/null || true
      wipefs -af "$disk"
      sgdisk --zap-all "$disk"
      sgdisk -n1:1MiB:+1GiB -t1:ef00 -c1:BOOT -n2:0:0 -t2:8309 -c2:cryptroot "$disk"
      partprobe "$disk" || true
      udevadm settle
      mapfile -t parts < <(lsblk -lnpo NAME,TYPE "$disk" | awk '$2 == "part" { print $1 }')
      boot=''${parts[0]}
      root=''${parts[1]}
      mkfs.fat -F 32 -n BOOT "$boot"
      printf '%s' "$pw1" | cryptsetup luksFormat --type luks2 --batch-mode --key-file=- "$root"
      luks="luks-$(cryptsetup luksUUID "$root")"
      printf '%s' "$pw1" | cryptsetup open --key-file=- "$root" "$luks"
      unset pw1 pw2
      mkfs.ext4 -F -L nixos "/dev/mapper/$luks"
      mount "/dev/mapper/$luks" /mnt
      mkdir -p /mnt/boot
      mount -o umask=077 "$boot" /mnt/boot

      step "5. The config"
      nixos-generate-config --root /mnt
      dest=/mnt/home/austin/nixos-config
      mkdir -p /mnt/home/austin
      cloned=0
      if confirm "Clone the config from GitHub? (The repo is private: needs your username and a personal access token. No uses the copy on this USB stick.)"; then
        if git clone "${repoUrl}" "$dest"; then
          cloned=1
        else
          echo "Cloning failed; using the copy on this USB stick instead."
          rm -rf "$dest"
        fi
      fi
      if [ "$cloned" -eq 0 ]; then
        cp -rL --no-preserve=mode "${snapshot}" "$dest"
        git -C "$dest" init --quiet --initial-branch=main
        git -C "$dest" remote add origin "${repoUrl}"
      fi
      cp /mnt/etc/nixos/hardware-configuration.nix "$dest/hosts/shitbox/hardware-configuration.nix"
      git -C "$dest" add -A
      git -C "$dest" -c user.name="install-shitbox" -c user.email="install-shitbox@localhost" \
        commit --quiet -m "hosts/shitbox: hardware configuration for this install"

      step "6. Installing (downloads the system; this takes a while)"
      nixos-install --no-root-passwd --flake "$dest#shitbox"

      step "7. Your login password"
      until nixos-enter --root /mnt -c "passwd austin"; do
        echo "Try again."
      done
      nixos-enter --root /mnt -c "chown -R austin:users /home/austin"

      echo
      echo "Done. shitbox is installed on $disk."
      if [ "$cloned" -eq 0 ]; then
        cat <<'NEXT'

      The config in ~/nixos-config is the copy from this USB stick, not yet
      connected to GitHub. After the first login, see "Reinstalling" in its
      README.md to connect it (and push the new hardware configuration).
      NEXT
      fi
      if confirm "Reboot now? (Remove the USB stick when the screen goes dark.)"; then
        systemctl reboot
      fi
    '';
  };
in
{
  imports = [ "${modulesPath}/installer/cd-dvd/installation-cd-graphical-base.nix" ];

  image.baseName = lib.mkForce "shitbox-installer-${version}";
  networking.hostName = "shitbox-installer";

  # The ISO's own Nix needs flakes for `nixos-install --flake`.
  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  # Live Plasma session, logged in automatically as "nixos" (as on the
  # official Plasma ISO, minus the Calamares installer, which installs a
  # generic NixOS rather than this config).
  services.desktopManager.plasma6 = {
    enable = true;
    enableQt5Integration = false;
  };
  services.displayManager = {
    plasma-login-manager.enable = true;
    autoLogin = {
      enable = true;
      user = "nixos";
    };
  };
  environment.plasma6.excludePackages = [ pkgs.kdePackages.plasma-workspace-wallpapers ];
  programs.kde-pim.enable = false;

  ################################
  # Wi-Fi that works out of the box
  ################################

  # All firmware, so Wi-Fi works on other laptops too (some of it is unfree).
  hardware.enableAllFirmware = true;
  nixpkgs.config.allowUnfree = true;

  # The panel's network applet stores Wi-Fi passwords in KWallet, which
  # can't unlock in a password-less live session, so connecting there
  # failed and only nmtui worked. With KWallet off, the password goes
  # straight to NetworkManager. (Admin prompts are already skipped: the
  # installer lets the wheel group do anything.)
  environment.etc."xdg/kwalletrc".text = ''
    [Wallet]
    Enabled=false
    First Use=false
  '';

  # Some laptops (HP among them) start with Wi-Fi soft-blocked.
  systemd.services.rfkill-unblock-wifi = {
    description = "Unblock Wi-Fi";
    wantedBy = [ "multi-user.target" ];
    serviceConfig.Type = "oneshot";
    script = "${pkgs.util-linux}/bin/rfkill unblock wifi";
  };

  ################################
  # The installer
  ################################

  environment.etc."shitbox-config".source = "${self}";
  environment.systemPackages = [ installShitbox ];

  # "Install shitbox" on the live desktop, opening Konsole.
  system.activationScripts.installShitboxDesktop = ''
    mkdir -p /home/nixos/Desktop
    cat > /home/nixos/Desktop/install-shitbox.desktop <<'EOF'
    [Desktop Entry]
    Type=Application
    Name=Install shitbox
    Comment=Erase a disk and install this NixOS config
    Icon=nix-snowflake
    Exec=konsole --hold -e sudo install-shitbox
    Terminal=false
    EOF
    chmod +x /home/nixos/Desktop/install-shitbox.desktop
    chown -R nixos /home/nixos/Desktop
  '';
}
