{ inputs }:
{ lib, config, pkgs, haskellLib, ... }:
let
  pkgs' = inputs.nixpkgs.legacyPackages.${pkgs.system};
  # https://github.com/input-output-hk/haskell.nix/issues/1177
  nonReinstallablePkgs = [
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
  brokenLibsModule =
    let
      responseFile = builtins.toFile "response-file" ''
        --optghc=-XFlexibleContexts
        --optghc=-Wwarn
        --optghc=-fplugin-opt=PlutusTx.Plugin:defer-errors
      '';
      l = [
        "cardano-binary"
        "cardano-crypto-class"
        "cardano-crypto-praos"
        "cardano-prelude"
        "heapwords"
        "measures"
        "strict-containers"
        "cardano-ledger-byron"
        "cardano-slotting"
      ];
    in {
      _file = "mlabs-tooling.nix/module.nix:brokenLibsModule";
      packages = builtins.listToAttrs (builtins.map (name: {
        inherit name;
        value.components.library.setupHaddockFlags = [ "--haddock-options=@${responseFile}" ];
        value.components.library.ghcOptions = [ "-XFlexibleContexts" "-Wwarn" "-fplugin-opt=PlutusTx.Plugin:defer-errors" ];
        value.components.library.extraSrcFiles = [ responseFile ];
      }) l);
    };
  module = { config, pkgs, hsPkgs, ... }: {
    _file = "mlabs-tooling.nix/module.nix:module";
    contentAddressed = true;
    inherit nonReinstallablePkgs; # Needed for a lot of different things
    packages = {
      cardano-crypto-class.components.library.pkgconfig = pkgs.lib.mkForce [[ pkgs.libsodium-vrf pkgs.secp256k1 ]];
      cardano-crypto-praos.components.library.pkgconfig = pkgs.lib.mkForce [[ pkgs.libsodium-vrf ]];
      plutus-simple-model.components.library.setupHaddockFlags = [ "--optghc=-fplugin-opt PlutusTx.Plugin:defer-errors" ];
    };
  };
in
{
  _file = "mlabs-tooling.nix/module.nix";
  config = {
    # FIXME: Remove once https://github.com/input-output-hk/haskell.nix/pull/1588 is merged
    cabalProject = lib.mkOverride 1100 ''
      packages: .
    '';
    cabalProjectLocal = ''
      repository ghc-next-packages
        url: https://input-output-hk.github.io/ghc-next-packages
        secure: True
        root-keys:
        key-threshold: 0

      allow-newer:
        *:base,
        *:containers,
        *:directory,
        *:time,
        *:bytestring,
        *:aeson,
        *:protolude,
        *:template-haskell,
        *:ghc-prim,
        *:ghc,
        *:cryptonite,
        *:formatting,
        monoidal-containers:aeson,
        size-based:template-haskell,
        snap-server:attoparsec,
      --  tasty-hedgehog:hedgehog,
        *:hashable,
        *:text

      constraints:
        text >= 2
        , aeson >= 2
        , dependent-sum >= 0.7
        , protolude >= 0.3.2
    '';
    compiler-nix-name = lib.mkDefault inputs.self.default-ghc;
    modules = [ module brokenLibsModule ];
    inputMap."https://input-output-hk.github.io/ghc-next-packages" = "${inputs.ghc-next-packages}";
    shell = {
      withHoogle = lib.mkOverride 999 false; # FIXME set to true
      exactDeps = lib.mkOverride 999 true;
      tools.haskell-language-server = {};
      # We use the ones from Nixpkgs, since they are cached reliably.
      # Eventually we will probably want to build these with haskell.nix.
      nativeBuildInputs = [
        pkgs'.cabal-install
        # (inputs.self.formatter pkgs.system)
      ];
    };
  };
}
