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

      mkPackageSpec = src: with lib;
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

      mkPackageTarballFor = system: { pname, version, src }: (pkgsFor system).runCommand "${pname}-${version}.tar.gz" { } ''
        cd ${src}/..
        tar --sort=name --owner=Hackage:0 --group=Hackage:0 --mtime='UTC 2009-01-01' -czvf $out $(basename ${src})
      '';

      mkHackageDirFor = system: { pname, version, src }@args: (pkgsFor system).runCommand "${pname}-${version}-hackage"
        {
          tarball = mkPackageTarballFor system args;
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

      mkHackageTarballFromDirsFor = system: hackageDirs: (pkgsFor system).runCommand "01-index.tar.gz" { } ''
        mkdir hackage
        ${builtins.concatStringsSep "" (map (dir: ''
          echo ${dir}
          ln -s ${dir}/* hackage/
        '') hackageDirs)}
        cd hackage
        tar --sort=name --owner=root:0 --group=root:0 --mtime='UTC 2009-01-01' -hczvf $out */*/*
      '';

      mkHackageTarballFor = system: pkg-specs: mkHackageTarballFromDirsFor system (map (mkHackageDirFor system) pkg-specs);

      mkHackageNixFor = system: compiler-nix-name: hackageTarball: (pkgsFor system).runCommand "hackage-nix" { } ''
        set -e
        export LC_CTYPE=C.UTF-8
        export LC_ALL=C.UTF-8
        export LANG=C.UTF-8
        cp ${hackageTarball} 01-index.tar.gz
        ${(pkgsFor system).gzip}/bin/gunzip 01-index.tar.gz
        ${(pkgsFor system).haskell-nix.nix-tools.${compiler-nix-name}}/bin/hackage-to-nix $out 01-index.tar "https://mkHackageNix/"
      '';

      mkHackageFromSpecFor = system: compiler-nix-name: extraHackagePackages: rec {
        tarballs = lib.listToAttrs (map (def: { name = def.pname; value = mkPackageTarballFor system def; }) extraHackagePackages);
        hackageTarball = mkHackageTarballFor system extraHackagePackages;
        hackageNix = mkHackageNixFor system compiler-nix-name hackageTarball;
        # Prevent nix-build from trying to download the package
        module = { packages = lib.mapAttrs (pname: tarball: { src = tarball; }) tarballs; };
      };

      mkHackageFor = system: compiler-nix-name: srcs: mkHackageFromSpecFor system compiler-nix-name (map mkPackageSpec srcs);

      overlayFor = system: final: prev:
        let compiler-nix-name = "ghc8107"; in
        rec {
          # # equivalent extraSources:
          # extraSources = [{
          #   mydep.src = ./mydep;
          #   mydep.subdirs = [ "." ];
          # }];

          # Usage:
          myhackage = mkHackageFor system compiler-nix-name [ ./mydep ];
          myapp = final.haskell-nix.cabalProject' {
            src = ./myapp;
            inherit compiler-nix-name;
            index-state = "2022-05-04T00:00:00Z";

            extra-hackages = [ (import myhackage.hackageNix) ];
            extra-hackage-tarballs = { myhackage = myhackage.hackageTarball; };
            modules = [ myhackage.module ];

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

      devShells = perSystem (system: {
        default = ((pkgsFor system).myapp.flake { }).devShell;
      });

      # export
      inherit mkPackageSpec mkPackageTarballFor mkHackageDirFor mkHackageTarballFromDirsFor mkHackageTarballFor mkHackageNixFor mkHackageFromSpecFor mkHackageFor;

      # for debugging
      myapp = perSystem (system: (pkgsFor system).myapp);
      haskell-nix = perSystem (system: (pkgsFor system).haskell-nix);
      myhackage = perSystem (system: (pkgsFor system).myhackage);

      overlay = perSystem overlayFor;
    };
}
