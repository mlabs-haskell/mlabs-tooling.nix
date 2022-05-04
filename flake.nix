{
  inputs = {
    haskell-nix.url = "github:input-output-hk/haskellnix";
    nixpkgs.follows = "haskell-nix/nixpkgs-unstable";
  };
  outputs = { self, nixpkgs, haskell-nix, ... }:
    let
      mydep = haskell-nix.project' {
        src = ./mydep;
      };
      myapp = haskell-nix.project' {
        src = ./myapp;
      };
    in
    mydep.flake // myapp.flake;
}
