{
  description = "Template project";
  nixConfig = {
    extra-substituters = [ "https://cache.iog.io" ];
    extra-trusted-public-keys = [ "hydra.iohk.io:f/Ea+s+dFdN+3Y/G+FDgSq+a5NEWhJGzdjvKNGv0/EQ=" ];
    allow-import-from-derivation = "true";
  };

  inputs = {
    tooling.url = "github:mlabs-haskell/mlabs-tooling.nix";
    styleguide.url = "github:mlabs-haskell/styleguide";
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

      perSystem = { system, ... }: {
        checks = {
          # Check that files are formatted according to styleguide.
          format = inputs.styleguide.lib.${system}.mkCheck self;
        };

        # Format files according to styleguide. Run with `nix fmt`.
        formatter = inputs.styleguide.lib.${system}.mkFormatter self;
      };
    };
}
