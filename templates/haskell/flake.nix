{
  description = "My project";
  nixConfig = {
    # We don't use Recursive Nix yet.
    extra-substituters = ["https://cache.iog.io" "https://public-plutonomicon.cachix.org" "https://mlabs.cachix.org"];
    extra-trusted-public-keys = ["hydra.iohk.io:f/Ea+s+dFdN+3Y/G+FDgSq+a5NEWhJGzdjvKNGv0/EQ=" "public-plutonomicon.cachix.org-1:3AKJMhCLn32gri1drGuaZmFrmnue+KkKrhhubQk/CWc="];
    allow-import-from-derivation = "true";
  };

  inputs = {
    tooling.url = "github:mlabs-haskell/mlabs-tooling.nix";
  };

  outputs = inputs@{ self, tooling, ... }: tooling.lib.mkFlake { inherit self; }
    {
      imports = [
        (tooling.lib.mkHaskellFlakeModule1 {
          project.src = ./.;
          # project.extraHackage = [
          #  "${inputs.foo}" # foo is a flake input
          # ];
        })
      ];
    };
}
