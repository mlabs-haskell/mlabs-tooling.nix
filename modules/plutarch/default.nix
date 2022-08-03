{ lib, pkgs, plainPkgs, config, system, inputs }: with lib; 
let  
  inherit (config.onchain) compiler-nix-name;
  plutarch = inputs.plutarch;
  plutarchDep = plutarch.applyPlutarchDep pkgs { };
in {
  inherit (plutarchDep) extra-hackages extra-hackage-tarballs modules;

  projectTools = {
    fourmolu = plainPkgs.haskell.packages.ghc923.fourmolu;
    hspec-discover = plutarch.project.${system}.hsPkgs.hspec-discover.components.hspec-discover;
    haskell-language-server = plutarch.hlsFor compiler-nix-name system;
  };
}
