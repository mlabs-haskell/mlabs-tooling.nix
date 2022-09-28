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
    emanote.url = "github:srid/emanote/master";
    emanote.inputs.nixpkgs.follows = "nixpkgs";
    plutus.url = "github:input-output-hk/plutus?dir=__std__";
    flake-parts.url = "github:mlabs-haskell/flake-parts?ref=fix-for-ifd";
    flake-parts.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = inputs@{ self, flake-parts, emanote, nixpkgs, iohk-nix, haskell-nix, ... }:
  let
    modules = [
      (import ./module.nix { inherit inputs; })
      (import ./mk-hackage.nix { inherit inputs; })
    ];

    templateFlake = import ./templates/haskell/flake.nix {
      self = templateFlake;
      tooling = self;
    };

    nlib = nixpkgs.lib;
  in {
    lib = {
      mkFormatter = pkgs: with pkgs; writeShellApplication {
        name = ",format";
        runtimeInputs = [
          nixpkgs-fmt
          haskellPackages.cabal-fmt
          (haskell.lib.compose.dontCheck haskell.packages.ghc924.fourmolu_0_8_2_0)
        ];
        text = builtins.readFile ./format.sh;
      };

      mkLinter = pkgs: with pkgs; writeShellApplication {
        name = ",lint";
        runtimeInputs = [
          (haskell.lib.compose.dontCheck haskell.packages.ghc924.hlint_3_4_1)
        ];
        # stupid unnecessary IFD
        text = builtins.readFile (pkgs.substituteAll {
          name = "substituted-lint.sh";
          src = ./lint.sh;
          hlint_config = ./hlint.yaml;
        }).outPath;
      };

      # needed to avoid IFD
      mkOpaque = x: nlib.mkOverride 100 (nlib.mkOrder 1000 x);

      default-ghc = "ghc924";

      inherit (flake-parts.lib) mkFlake;
      # versioned
      mkHaskellFlakeModule1 =
        { project
        , docsPath ? null
        , toHaddock ? []
        }: escapeHatch@{ config, lib, flake-parts-lib, ... }: {
          _file = "mlabs-tooling.nix:mkHaskellFlakeModule1";
          options = {
            perSystem = flake-parts-lib.mkPerSystemOption ({ config, system, ... }: {
              options.project = lib.mkOption {
                type = lib.types.unspecified;
              };
            });
            udmmdm = lib.mkOption {
              type = lib.types.attrsOf lib.types.unspecified;
            };
          };
          config = {
            systems = lib.mkDefault [ "x86_64-linux" "x86_64-darwin" "aarch64-linux" "aarch64-darwin" ];
            perSystem = { system, ... }:
            let
              hn = (import haskell-nix.inputs.nixpkgs {
                inherit system;
                overlays = [
                  haskell-nix.overlay
                  (import "${iohk-nix}/overlays/crypto")
                ];
              }).haskell-nix;

              prj = hn.cabalProject' (modules ++ [project]);
              flk = prj.flake {};

              mk = attr:
                let a = flk.${attr}; in
                { default = lib.mkDefault (builtins.head (builtins.attrValues a)); } // a;

              pkgs = nixpkgs.legacyPackages.${system};

              formatter = self.lib.mkFormatter pkgs;
              linter = self.lib.mkLinter pkgs;

              formatting = pkgs.runCommandNoCC "formatting-check"
                {
                  nativeBuildInputs = [ formatter ];
                }
                ''
                  cd ${project.src}
                  ,format check
                  touch $out
                '';

              linting = pkgs.runCommandNoCC "linting-check"
                {
                  nativeBuildInputs = [ linter ];
                }
                ''
                  cd ${project.src}
                  ,lint
                  touch $out
                '';

              mkDocumentation = path:
                let
                  configFile = (pkgs.formats.yaml { }).generate "emanote-configFile" {
                    template.baseUrl = "/documentation";
                  };
                  configDir = pkgs.runCommand "emanote-configDir" { } ''
                    mkdir -p $out
                    cp ${configFile} $out/index.yaml
                  '';
                in
                pkgs.runCommand "emanote-docs" { }
                  ''
                    mkdir $out
                    ${inputs.emanote.defaultPackage.${system}}/bin/emanote \
                      --layers "${path};${configDir}" \
                      gen $out
                  '';

            in {
              _module.args.pkgs = inputs.nixpkgs.legacyPackages.${system};

              packages = self.lib.mkOpaque (mk "packages" // (if docsPath == null then {} else {
                docs = mkDocumentation docsPath;
              }) // {
                haddock = inputs.plutus.${system}.toolchain.library.combine-haddock {
                  ghc = inputs.plutus.${system}.plutus.packages.ghc;
                  hspkgs = builtins.map (x: prj.hsPkgs.${x}.components.library) toHaddock;
                  # This doesn't work for some reason, everything breaks, probably because of CA
                  # builtins.map (x: x.components.library) (
                  #   builtins.filter (x: x ? components.library) (
                  #     builtins.attrValues (projectFor system).hsPkgs
                  #   )
                  # );
                  prologue = pkgs.writeTextFile {
                    name = "prologue";
                    text = ''
                      == Haddock documentation made through mlabs-tooling.nix
                    '';
                  };
                };
              });
              checks = self.lib.mkOpaque (mk "checks" // {
                inherit formatting linting;
              });
              apps = self.lib.mkOpaque (mk "apps" // {
                format.type = "app"; format.program = "${formatter}/bin/,format";
                lint.type = "app"; lint.program = "${linter}/bin/,lint";
              });
              devShells.default = lib.mkDefault flk.devShell;
              project = prj;
            };
            flake.config.hydraJobs = {
              packages = config.packages.x86_64-linux;
              checks = config.checks.x86_64-linux;
              devShells = config.devShells.x86_64-linux;
              apps = builtins.mapAttrs (_: a: a.program) config.apps.x86_64-linux;
            };
            flake.config.herculesCI.ciSystems = lib.mkDefault [ "x86_64-linux" ];
            flake.config.escapeHatch = escapeHatch;
          };
        };
    };

    templates.default = {
      path = ./templates/haskell;
      description = "A haskell.nix project";
    };

    inherit (templateFlake) hydraJobs;
  };
}
