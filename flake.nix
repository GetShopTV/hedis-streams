{
  description = "hedis-streams";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs";
    flake-parts.url = "github:hercules-ci/flake-parts";
    haskell-flake.url = "github:srid/haskell-flake";
  };

  outputs = inputs@{ self, flake-parts, nixpkgs, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = nixpkgs.lib.systems.flakeExposed;
      imports = [
        inputs.haskell-flake.flakeModule
      ];
      perSystem = { self', config, inputs', pkgs, lib, ... }: {
        haskellProjects.default = {
          basePackages = pkgs.haskell.packages.ghc926;
          packages = {
            hedis-streams-core.root = ./lib/hedis-streams-core/.;
            hedis-streams-streamly.root = ./lib/hedis-streams-streamly/.;
            hedis-streams-streamly-aeson.root = ./lib/hedis-streams-streamly-aeson/.;
            hedis-streams-streamly-store.root = ./lib/hedis-streams-streamly-store/.;
          };
        };
        packages.default = config.packages.hedis-streams-core;
      };
    };
}
