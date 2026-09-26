_:

{
  imports = [
    ../../hardware-configuration.nix

    ../../modules/base.nix
    ../../modules/hardware.nix
    ../../modules/desktop.nix
    ../../modules/gaming.nix
    ../../modules/shell.nix
    ../../modules/backup.nix
    ../../modules/homebrew.nix
    ../../modules/notify-failure.nix
  ];

  networking.hostName = "shitbox";

  # NOTE: Do not change this once the system is installed. This must match the
  # NixOS release you FIRST installed with, NOT the release you're currently
  # running. This tree now tracks 26.05, but stateVersion stays at the original
  # install release. For a fresh 26.05 install, set this to "26.05"; if you
  # installed under an earlier release and upgraded, leave it at that release
  # and match home.stateVersion in home/austin/home.nix to it as well.
  system.stateVersion = "25.11";
}
