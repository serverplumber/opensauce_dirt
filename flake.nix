{
  description = "OpenSauce Dirt — nix dev container & build pipeline";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
  };

  outputs =
    inputs@{
      self,
      nixpkgs,
      flake-parts,
    }:
    let
      projectName = "opensauce_dirt";
    in
    flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [
        ./krump/shells.nix
        ./krump/containers.nix
      ];
      _module.args = { inherit projectName; };
      flake.templates.default = {
        path = ./.;
        description = "opensauce_dirt: nix dev container & build pipeline";
      };
    };
}
