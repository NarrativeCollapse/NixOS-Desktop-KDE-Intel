{ pkgs, ... }:

# Desktop notifications when a background job fails, so failures don't sit
# unseen in the journal. Attach to a unit with
#   onFailure = [ "notify-failure@%n.service" ];
# (system units and user units each have their own template below).
let
  notify = unitsFlag: ''
    unit="$1"
    notify-send --urgency=critical --app-name=systemd --icon=dialog-error \
      "$unit failed" "See what happened: journalctl ${unitsFlag}-u $unit"
  '';
in
{
  # System units run as root with no desktop session, so this one sends the
  # notification into austin's session bus (and skips if austin isn't
  # logged in).
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
        sh -c ${pkgs.lib.escapeShellArg (notify "")} sh "$1"
    '';
  };

  systemd.user.services."notify-failure@" = {
    description = "Desktop notification that %i failed";
    serviceConfig.Type = "oneshot";
    scriptArgs = "%i";
    path = [ pkgs.libnotify ];
    script = notify "--user ";
  };
}
