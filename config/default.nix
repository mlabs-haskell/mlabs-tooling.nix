{ lib }: {
  config = with lib; {
    # defaults for offchain projects
    offchain = {
      inherit (lib.mkGhcVersion "8107") ghcVersion compiler-nix-name;
    };

    # defaults for onchain projects
    onchain = {
      inherit (lib.mkGhcVersion "923") ghcVersion compiler-nix-name;
    };

    # general default used for certain attributes
    general = {

      shell = {
        withHoogle = mkDefault false;
        exactDeps = mkDefault true;
      };

      pre-commit-hooks = {
        enable = mkEnableOption "pre-commit-hooks formatter and shellHook";
        hooks = {
          cabal-fmt.enable = mkDefault true;
          fourmolu.enable = mkDefault true;
          hlint.enable = mkDefault true;
          markdownlint.enable = mkDefault true;
          nixpkgs-fmt.enable = mkDefault true;
          shellcheck.enable = mkDefault true;
          statix.enable = mkDefault true;
        };
      };
    };
  };
}
