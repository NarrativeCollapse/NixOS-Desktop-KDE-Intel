{ pkgs, ... }:

let
  # Touched after every successful backup; read by backup-reminder below.
  stamp = "/var/lib/restic-home-last-success";
  staleDays = 7;
in
{
  ################################
  # Backups: restic for /home
  ################################
  #
  # The system is reproducible from this flake; /home/austin is not. This job
  # backs it up daily to a restic repository.
  #
  # ONE-TIME SETUP: run `backup-setup` (defined below). It creates the
  # repository password in /etc/secrets/restic-password (keep a copy OFF this
  # machine; losing it makes the backups unreadable forever), formats a USB
  # drive partition as ext4 labelled BACKUP, mounts it at /mnt/backup, and
  # runs the first backup. Until then the job skips silently.
  #
  # For a remote target instead, change `repository` to e.g.
  # "sftp:austin@myserver:/srv/restic-shitbox" and remove the
  # ConditionPathIsMountPoint line.
  #
  # Check and restore (as root; the password file is root-only):
  #        sudo restic-home snapshots
  #        sudo restic-home restore latest --target /tmp/restore \
  #          --include /home/austin/Documents
  #
  # (For proper secret management later, look at sops-nix or agenix; a
  # root-only file outside the store is the simplest sound approach for a
  # single machine.)

  services.restic.backups.home = {
    initialize = true; # create the repo on first run if it doesn't exist
    repository = "/mnt/backup/restic-shitbox";
    passwordFile = "/etc/secrets/restic-password";

    paths = [ "/home/austin" ];

    # Excludes tuned for this machine: everything below is either a cache or
    # re-downloadable. The Steam library alone would dwarf the real data.
    # Steam's userdata/, config/ and steamapps/compatdata/ (Proton prefixes,
    # where games without Steam Cloud keep their saves) are still backed up;
    # restic dedups the near-identical Wine files across prefixes.
    exclude = [
      "/home/austin/.cache"
      "/home/austin/.local/share/Steam/steamapps/common" # installed games
      "/home/austin/.local/share/Steam/steamapps/shadercache"
      "/home/austin/.local/share/Steam/steamapps/downloading"
      "/home/austin/.local/share/Steam/steamapps/temp"
      "/home/austin/.local/share/Steam/appcache"
      "/home/austin/.local/share/Steam/depotcache"
      "/home/austin/.local/share/Steam/logs"
      "/home/austin/.local/share/Steam/package" # Steam client updates
      "/home/austin/.local/share/Steam/ubuntu12_32" # Steam client runtime
      "/home/austin/.local/share/Steam/ubuntu12_64"
      "/home/austin/.steam"
      "/home/austin/.local/share/Trash"
      "/home/austin/.local/share/containers" # podman images/layers
      "/home/austin/.local/share/baloo" # KDE file indexer
      "/home/austin/.var/app/*/cache" # flatpak app caches
      "/home/austin/.npm"
      "/home/austin/.cargo"
      "/home/austin/**/node_modules"
      "/home/austin/**/.direnv"
    ];

    timerConfig = {
      OnCalendar = "daily";
      Persistent = true; # run a missed backup at next boot
      RandomizedDelaySec = "15m";
    };

    # Retention, applied via `restic forget --prune` after each backup.
    pruneOpts = [
      "--keep-daily 7"
      "--keep-weekly 4"
      "--keep-monthly 6"
    ];

    # `restic check` (repository structure/metadata) after every run, so
    # corruption surfaces as a failed unit instead of at restore time.
    runCheck = true;
  };

  systemd.services."restic-backups-home" = {
    # Skip quietly (no failed unit) when the drive isn't attached or setup
    # hasn't been done yet.
    unitConfig = {
      ConditionPathIsMountPoint = "/mnt/backup";
      ConditionPathExists = "/etc/secrets/restic-password";
    };
    # Runs only when backup, prune and check all succeeded.
    serviceConfig.ExecStartPost = [ "${pkgs.coreutils}/bin/touch ${stamp}" ];
    # A run that starts and fails (full drive, wrong password, corrupt repo)
    # raises a desktop notification; see modules/notify-failure.nix.
    onFailure = [ "notify-failure@%n.service" ];
  };

  # Because the job skips silently, it could stop running for months unseen.
  # Once a day (and shortly after login) warn on the desktop when the last
  # successful backup is missing or older than `staleDays`.
  systemd.user.services.backup-reminder = {
    description = "Warn when the last /home backup is too old";
    serviceConfig.Type = "oneshot";
    path = [
      pkgs.coreutils
      pkgs.libnotify
    ];
    script = ''
      if [ -e ${stamp} ]; then
        age_days=$(( ($(date +%s) - $(stat -c %Y ${stamp})) / 86400 ))
        [ "$age_days" -lt ${toString staleDays} ] && exit 0
        msg="The last successful backup of /home was $age_days days ago. Plug in the backup drive and run: sudo mount /mnt/backup"
      else
        msg="/home has never been backed up. Open a terminal and run: backup-setup"
      fi
      notify-send --urgency=critical --app-name=Backups --icon=drive-harddisk "Backups are out of date" "$msg"
    '';
  };
  systemd.user.timers.backup-reminder = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnStartupSec = "10min";
      OnCalendar = "daily";
      Persistent = true;
    };
  };

  # Plain restic CLI available regardless of the module's wrapper, and
  # `backup-setup`, which walks through the one-time setup: the repository
  # password, the backup drive, and the first backup.
  environment.systemPackages = [
    pkgs.restic
    (pkgs.writeShellApplication {
      name = "backup-setup";
      runtimeInputs = with pkgs; [
        coreutils
        e2fsprogs
        gawk
        systemd
        util-linux
      ];
      text = ''
        password=/etc/secrets/restic-password
        confirm() {
          local reply
          read -r -p "$1 [y/N] " reply
          [[ $reply == [yY]* ]]
        }

        echo "Backup setup: daily encrypted backups of /home/austin to an external drive."
        echo

        # 1. The repository password.
        if sudo test -s "$password"; then
          echo "OK  Backup password: already set ($password)."
        else
          echo "Step 1 of 3: the backup password."
          echo "Every backup is encrypted with it. If it's lost, the backups can never be read."
          pw=$(head -c 32 /dev/urandom | base64)
          echo
          echo "    $pw"
          echo
          echo "Save it now somewhere OFF this laptop (password manager, printed sheet)."
          read -r -p "Type 'saved' once it's stored: " reply
          if [ "$reply" != saved ]; then
            echo "Stopped; nothing was changed."
            exit 1
          fi
          sudo install -d -m 700 /etc/secrets
          sudo install -m 600 /dev/stdin "$password" <<< "$pw"
          echo "OK  Password saved to $password (readable by root only)."
        fi
        echo

        # 2. The drive: a partition labelled BACKUP (mounted at /mnt/backup).
        if [ -e /dev/disk/by-label/BACKUP ]; then
          echo "OK  Backup drive: found a partition labelled BACKUP ($(readlink -f /dev/disk/by-label/BACKUP))."
        else
          echo "Step 2 of 3: the backup drive."
          read -r -p "Plug in the external drive to use, then press Enter. " _
          sleep 2
          mapfile -t usb < <(lsblk -dnro NAME,TRAN | awk '$2 == "usb" { print $1 }')
          if [ "''${#usb[@]}" -eq 0 ]; then
            echo "No USB drive found. Plug one in and run backup-setup again."
            exit 1
          fi
          echo
          for disk in "''${usb[@]}"; do
            lsblk -o NAME,SIZE,FSTYPE,LABEL,MODEL "/dev/$disk"
            echo
          done
          read -r -p "Partition to use (e.g. sdb1). EVERYTHING on it will be erased: " part
          disk=$(lsblk -dno PKNAME "/dev/$part" 2>/dev/null || true)
          [ -n "$disk" ] || disk=$part
          if [[ ! -b /dev/$part || " ''${usb[*]} " != *" $disk "* ]]; then
            echo "'$part' isn't one of the USB drives listed above. Nothing was changed."
            exit 1
          fi
          read -r -p "Type '$part' again to erase it and format it for backups: " again
          if [ "$again" != "$part" ]; then
            echo "Stopped; nothing was changed."
            exit 1
          fi
          # Unmount it if the desktop mounted it when it was plugged in.
          if [ -n "$(lsblk -no MOUNTPOINTS "/dev/$part" | tr -d '[:space:]')" ]; then
            sudo umount "/dev/$part"
          fi
          sudo mkfs.ext4 -F -L BACKUP "/dev/$part"
          sudo udevadm settle
          echo "OK  /dev/$part is formatted and labelled BACKUP."
        fi
        echo

        # 3. Mount it and run the first backup.
        echo "Step 3 of 3: the first backup."
        if ! mountpoint -q /mnt/backup; then
          sudo mount /mnt/backup
        fi
        if ! confirm "Run the first backup now? It can take a while."; then
          echo "Setup is done. The daily backup runs whenever the drive is mounted."
          exit 0
        fi
        if ! sudo systemctl start restic-backups-home; then
          echo "The backup failed. See what happened: journalctl -u restic-backups-home"
          exit 1
        fi
        sudo restic-home snapshots
        echo
        echo "Backups are set up. They run daily while the drive is mounted at /mnt/backup;"
        echo "after plugging it in later, mount it with: sudo mount /mnt/backup"
      '';
    })
  ];

  # External backup drive: the partition labelled BACKUP (backup-setup
  # formats and labels one). `nofail` means boot proceeds normally when the
  # drive is absent (it mounts at boot only if plugged in; plug in later and
  # run `sudo mount /mnt/backup`). Deliberately NOT using x-systemd.automount:
  # an autofs mountpoint would satisfy ConditionPathIsMountPoint even with no
  # drive present, turning the safe skip into a failure.
  fileSystems."/mnt/backup" = {
    device = "/dev/disk/by-label/BACKUP";
    fsType = "ext4";
    options = [ "nofail" ];
  };
}
