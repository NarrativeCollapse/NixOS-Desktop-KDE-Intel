{ pkgs, ... }:

# Desktop notifications when a background job fails, so failures don't sit
# unseen in the journal. Attach to a unit with
#   onFailure = [ "notify-failure@%n.service" ];
# (system units only; no user units use it at the moment).
let
  # The notify-send call; $1 is the failed unit's name (scriptArgs = "%i").
  notify = ''
    notify-send --urgency=critical --app-name=systemd --icon=dialog-error \
      "$1 failed" "See what happened: journalctl -u $1"
  '';
in
{
  # System units run as root with no desktop session, so this one sends the
  # notification into austin's session bus (and skips if austin isn't
  # logged in). runuser keeps this unit's PATH, so notify-send is found
  # directly; there is no `sh` on a NixOS service's PATH to wrap it in.
  systemd.services."notify-failure@" = {
    description = "Desktop notification that %i failed";
    serviceConfig.Type = "oneshot";
    scriptArgs = "%i";
    path = [
      pkgs.coreutils
      pkgs.libnotify
      pkgs.util-linux
    ];
    script = ''
      uid=$(id -u austin)
      bus=/run/user/$uid/bus
      [ -S "$bus" ] || exit 0
      runuser -u austin -- env DBUS_SESSION_BUS_ADDRESS="unix:path=$bus" \
        ${notify}
    '';
  };
}
