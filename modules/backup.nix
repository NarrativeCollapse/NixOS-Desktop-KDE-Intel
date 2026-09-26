{ config, lib, pkgs, ... }:

{
  ################################
  # Backups: restic for /home
  ################################
  #
  # The system is reproducible from this flake; /home/austin is not. This job
  # backs it up daily to a restic repository.
  #
  # ONE-TIME SETUP (the job silently skips until both are done):
  #
  #   1. Create the repository password and KEEP A COPY OFF THIS MACHINE
  #      (password manager, printed sheet, anywhere). Losing it means the
  #      backups are unreadable forever:
  #
  #        sudo mkdir -p /etc/secrets && sudo chmod 700 /etc/secrets
  #        head -c 32 /dev/urandom | base64 | sudo tee /etc/secrets/restic-password
  #        sudo chmod 600 /etc/secrets/restic-password
  #
  #   2. Provide the target. Default assumes an external drive mounted at
  #      /mnt/backup — label a partition "BACKUP" and uncomment the
  #      fileSystems block below. For a remote target instead, change
  #      `repository` to e.g. "sftp:austin@myserver:/srv/restic-shitbox"
  #      and remove the ConditionPathIsMountPoint line.
  #
  # First run + verify:
  #        sudo systemctl start restic-backups-home
  #        restic-home snapshots        # wrapper installed by the module
  #
  # Restore example:
  #        restic-home restore latest --target /tmp/restore \
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
    exclude = [
      "/home/austin/.cache"
      "/home/austin/.local/share/Steam"
      "/home/austin/.steam"
      "/home/austin/.local/share/Trash"
      "/home/austin/.local/share/containers" # podman images/layers
      "/home/austin/.local/share/baloo"      # KDE file indexer
      "/home/austin/.var/app/*/cache"        # flatpak app caches
      "/home/austin/.npm"
      "/home/austin/.cargo"
      "/home/austin/**/node_modules"
      "/home/austin/**/.direnv"
    ];

    timerConfig = {
      OnCalendar = "daily";
      Persistent = true;          # run a missed backup at next boot
      RandomizedDelaySec = "15m";
    };

    # Retention, applied via `restic forget --prune` after each backup.
    pruneOpts = [
      "--keep-daily 7"
      "--keep-weekly 4"
      "--keep-monthly 6"
    ];
  };

  # Skip quietly (no failed unit) when the drive isn't attached or setup
  # hasn't been done yet. Run `restic check` by hand occasionally to verify
  # repository integrity.
  systemd.services."restic-backups-home".unitConfig = {
    ConditionPathIsMountPoint = "/mnt/backup";
    ConditionPathExists = "/etc/secrets/restic-password";
  };

  # Plain restic CLI available regardless of the module's wrapper.
  environment.systemPackages = [ pkgs.restic ];

  # External backup drive. `nofail` means boot proceeds normally when the
  # drive is absent (it mounts at boot only if plugged in; plug in later and
  # run `sudo mount /mnt/backup`). Deliberately NOT using x-systemd.automount:
  # an autofs mountpoint would satisfy ConditionPathIsMountPoint even with no
  # drive present, turning the safe skip into a failure.
  #
  # fileSystems."/mnt/backup" = {
  #   device = "/dev/disk/by-label/BACKUP";
  #   fsType = "ext4";
  #   options = [ "nofail" ];
  # };
}
