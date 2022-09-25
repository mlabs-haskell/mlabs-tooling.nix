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
  };

  outputs = inputs@{ self, emanote, nixpkgs, iohk-nix, haskell-nix,  ... }: rec {
    supportedSystems = [ "x86_64-linux" "x86_64-darwin" "aarch64-linux" "aarch64-darwin" ];

    perSystem = nixpkgs.lib.genAttrs supportedSystems;

    hnFor = perSystem (system: (import haskell-nix.inputs.nixpkgs {
      inherit system;
      overlays = [
        haskell-nix.overlay
        (import "${iohk-nix}/overlays/crypto")
      ];
    }).haskell-nix);

    pkgsFor = perSystem (system: import nixpkgs { inherit system; });

    default-ghc = "ghc924";

    modules = [
      (import ./module.nix { inherit inputs; })
      (import ./mk-hackage.nix { inherit inputs; })
    ];

    mkDocumentation = path: system:
      let
        pkgs = pkgsFor.${system};
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

    mkHaskellProject = system: project: hnFor.${system}.cabalProject' (modules ++ [project]);

    formatter = system: with pkgsFor.${system}; writeShellApplication {
      name = ",format";
      runtimeInputs = [
        nixpkgs-fmt
        haskellPackages.cabal-fmt
        (haskell.lib.compose.dontCheck haskell.packages.ghc924.fourmolu_0_8_2_0)
      ];
      text = builtins.readFile ./format.sh;
    };

    linter = system: with pkgsFor.${system}; writeShellApplication {
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

    brokenHaddock = [ "pretty-show" ];

    # versioned
    mkHaskellFlake1 =
      { project
      , docsPath ? null
      , toHaddock ? []
      }:
      let
        projectFor = perSystem (system: mkHaskellProject system project);
        flkFor = perSystem (system: projectFor.${system}.flake {});
        mk = attr: system:
          let a = flkFor.${system}.${attr}; in
          { default = builtins.head (builtins.attrValues a); } // a
        ;
        formatting = system: pkgsFor.${system}.runCommandNoCC "formatting-check"
          {
            nativeBuildInputs = [ (formatter system) ];
          }
          ''
            cd ${projectFor.src}
            ,format check
            touch $out
          '';
        linting = system: pkgsFor.${system}.runCommandNoCC "linting-check"
          {
            nativeBuildInputs = [ (linter system) ];
          }
          ''
            cd ${projectFor.src}
            ,lint
            touch $out
          '';
        self = {
          packages = perSystem (system: mk "packages" system // (if docsPath == null then {} else {
            docs = mkDocumentation docsPath system;
          }) // {
            haddock = inputs.plutus.${system}.toolchain.library.combine-haddock {
              ghc = inputs.plutus.${system}.plutus.packages.ghc;
              hspkgs = builtins.map (x: projectFor.${system}.hsPkgs.${x}.components.library) toHaddock;
              # This doesn't work for some reason, everything breaks, probably because of CA
              # builtins.map (x: x.components.library) (
              #   builtins.filter (x: x ? components.library) (
              #     builtins.attrValues (projectFor system).hsPkgs
              #   )
              # );
              prologue = pkgsFor.${system}.writeTextFile {
                name = "prologue";
                text = ''
                  == Haddock documentation made through mlabs-tooling.nix
                '';
              };
            };
          });
          checks = perSystem (system: mk "checks" system // {
            formatting = formatting system;
            linting = linting system;
          });
          apps = perSystem (system: mk "apps" // {
            format.type = "app"; format.program = "${formatter system}/bin/,format";
            lint.type = "app"; lint.program = "${linter system}/bin/,lint";
          });
          devShells = perSystem (system: { default = flkFor.${system}.devShell; });
          herculesCI.ciSystems = [ "x86_64-linux" ];
          project = projectFor;
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

    inherit (mkHaskellFlake1 { project.src = ./templates/haskell; }) hydraJobs;
  };
}
