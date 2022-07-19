{
  inputs = {
    haskell-nix.url = "github:input-output-hk/haskell.nix";
    nixpkgs.follows = "haskell-nix/nixpkgs-unstable";
  };
  outputs = { self, nixpkgs, haskell-nix, ... }:
    let
      defaultSystems = [ "x86_64-linux" "x86_64-darwin" ];
      perSystem = nixpkgs.lib.genAttrs defaultSystems;

      lib = import (nixpkgs + "/lib");

      pkgsFor = system: import nixpkgs {
        inherit system;
        inherit (haskell-nix) config;
        overlays = overlaysFor system;
      };

      mkPackageSpec = src:
        with lib;
        let
          cabalFiles = concatLists (mapAttrsToList
            (name: type: if type == "regular" && hasSuffix ".cabal" name then [ name ] else [ ])
            (builtins.readDir src));

          cabalPath =
            if length cabalFiles == 1
            then src + "/${builtins.head cabalFiles}"
            else builtins.abort "Could not find unique file with .cabal suffix in source: ${src}";
          cabalFile = builtins.readFile cabalPath;
          parse = field:
            let
              lines = filter (s: if builtins.match "^${field} *:.*$" (toLower s) != null then true else false) (splitString "\n" cabalFile);
              line =
                if lines != [ ]
                then head lines
                else builtins.abort "Could not find line with prefix ''${field}:' in ${cabalPath}";
            in
            replaceStrings [ " " ] [ "" ] (head (tail (splitString ":" line)));
          pname = parse "name";
          version = parse "version";
        in
        { inherit src pname version; };

      mkPackageTarballFor = system: { pname, version, src }:
        (pkgsFor system).runCommand "${pname}-${version}.tar.gz" { } ''
          cd ${src}/..
          tar --sort=name --owner=Hackage:0 --group=Hackage:0 --mtime='UTC 2009-01-01' -czvf $out $(basename ${src})
        '';

      mkHackageDirFor = system: { pname, version, src }@spec:
        (pkgsFor system).runCommand "${pname}-${version}-hackage"
          {
            tarball = mkPackageTarballFor system spec;
          } ''
          set -e
          mkdir -p $out/${pname}/${version}
          md5=$(md5sum "$tarball"  | cut -f 1 -d ' ')
          sha256=$(sha256sum "$tarball" | cut -f 1 -d ' ')
          length=$(stat -c%s "$tarball")
          cat <<EOF > $out/"${pname}"/"${version}"/package.json
          {
            "signatures" : [],
            "signed" : {
                "_type" : "Targets",
                "expires" : null,
                "targets" : {
                  "<repo>/package/${pname}-${version}.tar.gz" : {
                      "hashes" : {
                        "md5" : "$md5",
                        "sha256" : "$sha256"
                      },
                      "length" : $length
                  }
                },
                "version" : 0
            }
          }
          EOF
          cp ${src}/*.cabal $out/"${pname}"/"${version}"/
        '';

      mkHackageTarballFromDirsFor = system: hackageDirs:
        (pkgsFor system).runCommand "01-index.tar.gz" { } ''
          mkdir hackage
          ${builtins.concatStringsSep "" (map (dir: ''
            echo ${dir}
            ln -s ${dir}/* hackage/
          '') hackageDirs)}
          cd hackage
          tar --sort=name --owner=root:0 --group=root:0 --mtime='UTC 2009-01-01' -hczvf $out */*/*
        '';

      mkHackageTarballFor = system: pkg-specs:
        mkHackageTarballFromDirsFor system (map (mkHackageDirFor system) pkg-specs);

      mkHackageTarballsFor = system: pkg-specs:
        lib.listToAttrs (map
          (spec: {
            name = "_" + spec.pname;
            value = mkHackageTarballFromDirsFor system [ (mkHackageDirFor system spec) ];
          })
          pkg-specs);

      mkHackageNixFor = system: compiler-nix-name: hackageTarball:
        (pkgsFor system).runCommand "hackage-nix" { } ''
          set -e
          export LC_CTYPE=C.UTF-8
          export LC_ALL=C.UTF-8
          export LANG=C.UTF-8
          cp ${hackageTarball} 01-index.tar.gz
          ${(pkgsFor system).gzip}/bin/gunzip 01-index.tar.gz
          ${(pkgsFor system).haskell-nix.nix-tools.${compiler-nix-name}}/bin/hackage-to-nix $out 01-index.tar "https://mkHackageNix/"
        '';

      mkExtraHackagesFor = system: compiler-nix-name: extra-hackage-tarballs: map
        (tarball: import (mkHackageNixFor system compiler-nix-name tarball))
        (lib.attrValues extra-hackage-tarballs);

      mkModuleFor = system: extraHackagePackages: {
        # Prevent nix-build from trying to download the packages
        packages = lib.listToAttrs (map
          (spec: {
            name = spec.pname;
            value = { src = mkPackageTarballFor system spec; };
          })
          extraHackagePackages);
      };

      mkHackageFromSpecFor = system: compiler-nix-name: extraHackagePackages: rec {
        extra-hackage-tarball = mkHackageTarballFor system extraHackagePackages;
        extra-hackage = mkHackageNixFor system compiler-nix-name extra-hackage-tarball;
        module = mkModuleFor system extraHackagePackages;
      };

      mkHackagesFromSpecFor = system: compiler-nix-name: extraHackagePackages: rec {
        extra-hackage-tarballs = mkHackageTarballsFor system extraHackagePackages;
        extra-hackages = mkExtraHackagesFor system compiler-nix-name extra-hackage-tarballs;
        modules = [ (mkModuleFor system extraHackagePackages) ];
      };

      mkHackageFor = system: compiler-nix-name: srcs: mkHackageFromSpecFor system compiler-nix-name (map mkPackageSpec srcs);

      mkHackagesFor = system: compiler-nix-name: srcs: mkHackagesFromSpecFor system compiler-nix-name (map mkPackageSpec srcs);

      overlayFor = system: final: prev:
        let compiler-nix-name = "ghc8107"; in
        rec {
          # # equivalent extraSources:
          # extraSources = [{
          #   mydep.src = ./mydep;
          #   mydep.subdirs = [ "." ];
          # } {
          #   mydepdep.src = ./mydepdep;
          #   mydepdep.subdirs = [ "." ];
          # }];

          # Usage:
          myHackages = mkHackagesFor system compiler-nix-name [ ./mydepdep ./mydep ];
          myapp = final.haskell-nix.cabalProject' {
            src = ./myapp;
            inherit compiler-nix-name;
            index-state = "2022-05-04T00:00:00Z";

            inherit (myHackages) extra-hackages extra-hackage-tarballs modules;

            shell.exactDeps = true;
            shell.tools = { cabal-install = { }; };
          };
        };
      overlaysFor = system: [ haskell-nix.overlay (overlayFor system) ];

    in
    rec {
      packages = perSystem (system: {
        default = ((pkgsFor system).myapp.flake { }).packages."myapp:exe:myapp";
      });

      apps = perSystem
        (system: {
          default = {
            type = "app";
            program = "${packages.${system}.default}/bin/myapp";
          };
        });

      devShells = perSystem (system: {
        default = ((pkgsFor system).myapp.flake { }).devShell;
      });

      # export
      inherit mkPackageSpec mkPackageTarballFor mkHackageDirFor mkHackageTarballFromDirsFor mkHackageTarballFor mkHackageNixFor mkHackageFromSpecFor mkHackagesFromSpecFor mkHackageFor mkHackagesFor;

      # for debugging
      myapp = perSystem (system: (pkgsFor system).myapp);
      haskell-nix = perSystem (system: (pkgsFor system).haskell-nix);
      myHackages = perSystem (system: (pkgsFor system).myHackages);

      overlay = perSystem overlayFor;
    };
}
