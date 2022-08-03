{
  description = "A very basic flake";

  inputs = {
    # TODO: reduce transitive inputs
    # Haskell.nix, Nixpkgs
    haskell-nix.url = "github:input-output-hk/haskell.nix/master";
    haskell-nix-extra-hackage.url = "github:mlabs-haskell/haskell-nix-extra-hackage/main";

    nixpkgs.follows = "haskell-nix/nixpkgs-unstable";
    nixpkgs-pure.url = "github:nixos/nixpkgs/nixpkgs-unstable";

    # Libraries
    plutarch.url = "github:Plutonomicon/plutarch-plutus";
    plutarch-latest.url = "github:Plutonomicon/plutarch-plutus/staging";

    iohk-nix = {
      url = "github:input-output-hk/iohk-nix";
      flake = false;
    };

    # FIXME: proper release cycle for plutip available?
    plutip.url = "github:mlabs-haskell/plutip/master";
    plutip-latest.url = "github:mlabs-haskell/plutip/gergely/vasil";

    # FIXME: we need https://github.com/mlabs-haskell/bot-plutus-interface/pull/97
    # NOTE: we assume that most of the users rely on the bpi that plutip uses
    bpi.follows = "plutip/bot-plutus-interface";
    bpi-latest.follows = "plutip-latest/bot-plutus-interface";
    bpi-standalone.url = "github:mlabs-haskell/bot-plutus-interface/master";

    ply.url = "github:mlabs-haskell/ply/master";
    ply-latest.url = "github:mlabs-haskell/ply/staging";

    ctl.url = "github:Plutonomicon/cardano-transaction-lib/master";
    ctl-latest.url = "github:Plutonomicon/cardano-transaction-lib/develop";

    lucid = {
      url = "github:Berry-Pool/lucid/main";
      flake = false;
    };

    # Tooling: 
    pre-commit-hooks.url = "github:cachix/pre-commit-hooks.nix";
  };
  outputs = 
    inputs@
    { self
    , nixpkgs 
    , nixpkgs-pure
    , haskell-nix
    , iohk-nix
    , haskell-nix-extra-hackage
    , pre-commit-hooks
    , ...
    }: {

    };
}
