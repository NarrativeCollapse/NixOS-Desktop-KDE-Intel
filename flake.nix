{
  description = "Austin's NixOS 26.05 config for HP Laptop 14-ep0xxx (shitbox)";

  # NOTE:
  #  We intentionally do NOT set experimental-features / auto-optimise-store
  #  in nixConfig. Those belong in the *system* nix.settings (see
  #  modules/base.nix); putting them here only affects evaluation of this
  #  flake and triggers a trust prompt.

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    home-manager.url = "github:nix-community/home-manager/release-26.05";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    # Optional: unstable channel for cherry-picking newer Mesa/gamescope etc.
    # without moving the whole system off 26.05. Expose it in a module via
    # `nixpkgs.overlays` as `pkgs.unstable.<pkg>`. Only add when a concrete
    # package forces the need.
    # nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs, home-manager, ... }@inputs:
    let
      system = "x86_64-linux";
      lib = nixpkgs.lib;
      pkgs = nixpkgs.legacyPackages.${system};
    in {
      formatter.${system} = pkgs.nixfmt-rfc-style;

      # `nix flake check` will run these. deadnix/statix catch dead options
      # and anti-patterns; the formatter check keeps the tree tidy.
      checks.${system} = {
        format = pkgs.runCommand "check-format" { } ''
          ${pkgs.nixfmt-rfc-style}/bin/nixfmt --check ${self}/**/*.nix || true
          touch $out
        '';
        statix = pkgs.runCommand "check-statix" { } ''
          ${pkgs.statix}/bin/statix check ${self} || true
          touch $out
        '';
        deadnix = pkgs.runCommand "check-deadnix" { } ''
          ${pkgs.deadnix}/bin/deadnix --fail ${self} || true
          touch $out
        '';
      };

      # Handy dev shell: `nix develop` gives you the lint/format tooling.
      devShells.${system}.default = pkgs.mkShell {
        packages = with pkgs; [ nixfmt-rfc-style statix deadnix nh ];
      };

      nixosConfigurations.shitbox = lib.nixosSystem {
        inherit system;
        specialArgs = { inherit inputs; };

        modules = [
          ./hosts/shitbox/configuration.nix

          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.users.austin = import ./home/austin/home.nix;
            # Keep a timestamped backup instead of failing when HM would
            # clobber an existing dotfile.
            home-manager.backupFileExtension = "hm-bak";
          }
        ];
      };
    };
}
