{
  description = "plutarch";

  nixConfig = {
    # We don't use Recursive Nix yet.
    extra-experimental-features = [ "nix-command" "flakes" "ca-derivations" "recursive-nix" ];
    extra-substituters = ["https://cache.iog.io" "https://public-plutonomicon.cachix.org" "https://mlabs.cachix.org"];
    extra-trusted-public-keys = ["hydra.iohk.io:f/Ea+s+dFdN+3Y/G+FDgSq+a5NEWhJGzdjvKNGv0/EQ=" "public-plutonomicon.cachix.org-1:3AKJMhCLn32gri1drGuaZmFrmnue+KkKrhhubQk/CWc="];
    allow-import-from-derivation = "true";
    bash-prompt = "\\[\\e[0m\\][\\[\\e[0;2m\\]nix \\[\\e[0;1m\\]mlabs \\[\\e[0;93m\\]\\w\\[\\e[0m\\]]\\[\\e[0m\\]$ \\[\\e[0m\\]";
    cores = "1";
    max-jobs = "auto";
    auto-optimise-store = "true";
  };

  inputs = {
    haskell-nix.url = "github:input-output-hk/haskell.nix";
    nixpkgs.url = "github:NixOS/nixpkgs?ref=nixos-unstable";
    ghc-next-packages.url = "github:input-output-hk/ghc-next-packages?ref=repo";
    ghc-next-packages.flake = false;
    iohk-nix.url = "github:input-output-hk/iohk-nix";
    iohk-nix.flake = false;
  };

  outputs = inputs@{ self, nixpkgs, iohk-nix, haskell-nix,  ... }: rec {
    supportedSystems = [ "x86_64-linux" "x86_64-darwin" "aarch64-linux" "aarch64-darwin" ];

    perSystem = nixpkgs.lib.genAttrs supportedSystems;

    hnFor = system: (import haskell-nix.inputs.nixpkgs {
      inherit system;
      overlays = [ haskell-nix.overlay (import "${iohk-nix}/overlays/crypto") ];
    }).haskell-nix;
    pkgsFor = system: import nixpkgs { inherit system; };

    default-ghc = "ghc924";

    /*
    hlsFor' = compiler-nix-name: pkgs:
      pkgs.haskell-nix.cabalProject' {
        modules = [{
          inherit nonReinstallablePkgs;
          reinstallableLibGhc = false;
        }];
        inherit compiler-nix-name;
        src = "${inputs.haskell-language-server}";
        sha256map."https://github.com/pepeiborra/ekg-json"."7a0af7a8fd38045fd15fb13445bdcc7085325460" = "fVwKxGgM0S4Kv/4egVAAiAjV7QB5PBqMVMCfsv7otIQ=";
      };
    hlsFor = compiler-nix-name: system:
      let
        pkgs = pkgsFor system;
        oldGhc = "8107";
      in
      if (compiler-nix-name == "ghc${oldGhc}") then
        pkgs.haskell-language-server.override
          {
            supportedGhcVersions = [ oldGhc ];
          }
      else
        (hlsFor' compiler-nix-name pkgs).hsPkgs.haskell-language-server.components.exes.haskell-language-server;
    */

    modules = [
      (import ./module.nix { inherit inputs; })
      (import ./mk-hackage.nix { inherit inputs; })
    ];

    mkHaskellProject = system: project: (hnFor system).cabalProject' (modules ++ [project]);

    formatter = system: with (pkgsFor system); writeShellApplication {
      name = ",format";
      runtimeInputs = [
        alejandra
        haskellPackages.cabal-fmt
        (haskell.lib.compose.dontCheck haskell.packages.ghc924.fourmolu_0_8_1_0)
      ];
      text = builtins.readFile ./format.sh;
    };

    # versioned
    mkHaskellFlake1 =
      { project
      }:
      let
        prjFor = system: mkHaskellProject system project;
        flkFor = system: (prjFor system).flake {};
        mk = attr: perSystem (system:
          let a = (flkFor system).${attr}; in
          { default = builtins.head (builtins.attrValues a); } // a
        );
        formatting = system: (pkgsFor system).runCommandNoCC "formatting-check"
          {
            nativeBuildInputs = [ (formatter system) ];
          }
          ''
            cd ${project.src}
            ,format check
            touch $out
          '';
        self = {
          packages = mk "packages";
          checks = mk "checks" // perSystem (system: { formatting = formatting system; });
          apps = mk "apps" // perSystem (system: { format.type = "app"; format.program = "${formatter system}/bin/,format"; });
          devShells = perSystem (system: { default = (flkFor system).devShell; });
          herculesCI.ciSystems = [ "x86_64-linux" ];
          project = perSystem prjFor;
          hydraJobs = {
            packages = self.packages.x86_64-linux;
            checks = self.checks.x86_64-linux;
            devShells = self.devShells.x86_64-linux;
            apps = builtins.mapAttrs (_: a: a.program) self.apps.x86_64-linux;
          };
        };
      in self;

    templates.default = {
      path = ./templates/haskell;
      description = "A haskell.nix project";
    };
  };
}
