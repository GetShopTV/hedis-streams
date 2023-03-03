{
  description = "hedis-streams";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, flake-utils, nixpkgs, ... }:
    let
      overlay = final: prev: {
        haskell = prev.haskell // {
          packageOverrides = hfinal: hprev:
            prev.haskell.packageOverrides hfinal hprev // {
              hedis-streams-core = hfinal.callCabal2nix "hedis-streams-core" ./lib/hedis-streams-core/. { };
              hedis-streams-streamly = hfinal.callCabal2nix "hedis-streams-streamly" ./lib/hedis-streams-streamly/. { };
              hedis-streams-streamly-aeson = hfinal.callCabal2nix "hedis-streams-streamly-aeson" ./lib/hedis-streams-streamly-aeson/. { };
              hedis-streams-streamly-store = hfinal.callCabal2nix "hedis-streams-streamly-store" ./lib/hedis-streams-streamly-store/. { };
            };
        };
      };

      perSystem = system:
        let
          pkgs = import nixpkgs { inherit system; overlays = [ overlay ]; };
          hspkgs = pkgs.haskell.packages.ghc926;
        in
        {
          devShell = hspkgs.shellFor {
            withHoogle = true;
            packages = p: [
              p.hedis-streams-core
              p.hedis-streams-streamly
              p.hedis-streams-streamly-aeson
              p.hedis-streams-streamly-store
            ];
            buildInputs = [
              hspkgs.cabal-install
              hspkgs.haskell-language-server
              hspkgs.fourmolu
              pkgs.bashInteractive
            ];
          };
          packages = {
            core = hspkgs.hedis-streams-core;
            streamly = hspkgs.hedis-streams-streamly;
            streamly-aeson = hspkgs.hedis-streams-streamly-aeson;
            streamly-store = hspkgs.hedis-streams-streamly-store;
          };
        };
    in
    { inherit overlay; } // flake-utils.lib.eachDefaultSystem perSystem;
}
