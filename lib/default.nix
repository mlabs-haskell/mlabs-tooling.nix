{ lib }: with lib; {
  # Make defaults for the ghcVersion and compiler-nix-name attributes
  mkGhcVersion = (ghcVersion: {
    ghcVersion = mkDefault ghcVersion;
    compiler-nix-name = mkDefault ("ghc" + ghcVersion);
  });
}
