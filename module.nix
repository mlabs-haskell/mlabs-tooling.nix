{ inputs }:
{ lib, config, pkgs, haskellLib, ... }:
let
  pkgs' = inputs.nixpkgs.legacyPackages.${pkgs.system};
  # https://github.com/input-output-hk/haskell.nix/issues/1177
  nonReinstallablePkgs = [
    "array"
    "array"
    "base"
    "binary"
    "bytestring"
    "Cabal"
    "containers"
    "deepseq"
    "directory"
    "exceptions"
    "filepath"
    "ghc"
    "ghc-bignum"
    "ghc-boot"
    "ghc-boot"
    "ghc-boot-th"
    "ghc-compact"
    "ghc-heap"
    # "ghci"
    # "haskeline"
    "ghcjs-prim"
    "ghcjs-th"
    "ghc-prim"
    "ghc-prim"
    "hpc"
    "integer-gmp"
    "integer-simple"
    "mtl"
    "parsec"
    "pretty"
    "process"
    "rts"
    "stm"
    "template-haskell"
    "terminfo"
    "text"
    "time"
    "transformers"
    "unix"
    "Win32"
    "xhtml"
  ];
  module = { config, pkgs, hsPkgs, ... }: {
    inherit nonReinstallablePkgs; # Needed for a lot of different things
    packages = {
      cardano-binary.components.library.setupHaddockFlags = [ "--optghc=-fplugin-opt PlutusTx.Plugin:defer-errors" ];
      cardano-binary.ghcOptions = [ "-Wwarn" ];
      cardano-crypto-class.components.library.pkgconfig = pkgs.lib.mkForce [ [ pkgs.libsodium-vrf ] ];
      cardano-crypto-class.components.library.setupHaddockFlags = [ "--optghc=-fplugin-opt PlutusTx.Plugin:defer-errors" ];
      cardano-crypto-class.ghcOptions = [ "-Wwarn" ];
      cardano-crypto-praos.components.library.pkgconfig = pkgs.lib.mkForce [ [ pkgs.libsodium-vrf ] ];
      plutus-simple-model.components.library.setupHaddockFlags = [ "--optghc=-fplugin-opt PlutusTx.Plugin:defer-errors" ];
      cardano-prelude.components.library.setupHaddockFlags = [ "--optghc=-fplugin-opt PlutusTx.Plugin:defer-errors" ];
      cardano-prelude.ghcOptions = [ "-Wwarn" ];
    };
  };
in
{
  _file = "mlabs-tooling.nix/module.nix";
  config = {
    extraHackages = [[
      "${inputs.cardano-base}/base-deriving-via"
      "${inputs.cardano-base}/binary"
      "${inputs.cardano-base}/cardano-crypto-class"
      "${inputs.cardano-base}/cardano-crypto-praos"
      "${inputs.cardano-base}/heapwords"
      "${inputs.cardano-base}/measures"
      "${inputs.cardano-base}/slotting"
      "${inputs.cardano-base}/strict-containers"
      "${inputs.cardano-crypto}"
      "${inputs.cardano-ledger}/eras/alonzo/impl"
      "${inputs.cardano-ledger}/eras/alonzo/test-suite"
      "${inputs.cardano-ledger}/eras/babbage/impl"
      "${inputs.cardano-ledger}/eras/babbage/test-suite"
      "${inputs.cardano-ledger}/eras/byron/chain/executable-spec"
      "${inputs.cardano-ledger}/eras/byron/crypto"
      "${inputs.cardano-ledger}/eras/byron/crypto/test"
      "${inputs.cardano-ledger}/eras/byron/ledger/executable-spec"
      "${inputs.cardano-ledger}/eras/byron/ledger/impl"
      "${inputs.cardano-ledger}/eras/byron/ledger/impl/test"
      "${inputs.cardano-ledger}/eras/shelley/impl"
      "${inputs.cardano-ledger}/eras/shelley-ma/impl"
      "${inputs.cardano-ledger}/eras/shelley-ma/test-suite"
      "${inputs.cardano-ledger}/eras/shelley/test-suite"
      "${inputs.cardano-ledger}/libs/cardano-data"
      "${inputs.cardano-ledger}/libs/cardano-ledger-core"
      "${inputs.cardano-ledger}/libs/cardano-ledger-pretty"
      "${inputs.cardano-ledger}/libs/cardano-ledger-test"
      "${inputs.cardano-ledger}/libs/cardano-protocol-tpraos"
      "${inputs.cardano-ledger}/libs/ledger-state"
      "${inputs.cardano-ledger}/libs/non-integral"
      "${inputs.cardano-ledger}/libs/plutus-preprocessor"
      "${inputs.cardano-ledger}/libs/set-algebra"
      "${inputs.cardano-ledger}/libs/small-steps"
      "${inputs.cardano-ledger}/libs/small-steps-test"
      "${inputs.cardano-ledger}/libs/vector-map"
      "${inputs.cardano-prelude}/cardano-prelude"
      "${inputs.flat}"
      "${inputs.plutus}/plutus-core"
      "${inputs.plutus}/plutus-ledger-api"
      "${inputs.plutus}/plutus-tx"
      "${inputs.plutus}/prettyprinter-configurable"
      "${inputs.plutus}/word-array"
    ]];
    # FIXME: Remove once https://github.com/input-output-hk/haskell.nix/pull/1588 is merged
    cabalProject = lib.mkOverride 1100 ''
      packages: .
    '';
    cabalProjectLocal = ''
      allow-newer:
        *:base
        , canonical-json:bytestring
        , plutus-core:ral
        , plutus-core:some
        , inline-r:singletons
    '';
    compiler-nix-name = lib.mkDefault inputs.self.default-ghc;
    modules = [ module ];
    shell = {
      withHoogle = lib.mkOverride 999 true;
      exactDeps = lib.mkOverride 999 true;
      tools.haskell-language-server = {};
      # We use the ones from Nixpkgs, since they are cached reliably.
      # Eventually we will probably want to build these with haskell.nix.
      nativeBuildInputs = [
        pkgs'.cabal-install
        pkgs'.hlint
        pkgs'.haskellPackages.cabal-fmt
        pkgs'.haskell.packages.ghc924.fourmolu_0_8_0_0
        pkgs'.nixpkgs-fmt
        (inputs.self.formatter pkgs.system)
      ];
    };
  };
}
