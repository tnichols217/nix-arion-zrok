{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils, spigot, mavenix, bungeecord, ... }: 
  let
    sysOut = (flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
      in
      {
        apps = rec {
          runArion = {
            type = "app";
            program = pkgs.callPackage ./nix/scripts/runArion.nix { };
          };
          default = runArion;
        };
      }
    ));
  in
    sysOut // {
      arion-module = import ./arion-config.nix { flake = sysOut.packages.x86_64-linux; };
    };
}