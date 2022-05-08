{
  inputs = {
    haskell-nix.url = "github:input-output-hk/haskell.nix";
    nixpkgs.follows = "haskell-nix/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };
  outputs = { self, flake-utils, nixpkgs, haskell-nix, ... }:
    flake-utils.lib.eachSystem [ "x86_64-linux" "x86_64-darwin" ] (system:
      let
        compiler-nix-name = "ghc922";
        index-state = "2022-05-04T00:00:00Z";

        pkgs = import nixpkgs { inherit system overlays; inherit (haskell-nix) config; };

        overlay = final: prev: rec {

          mkPackageSpec = src: with pkgs.lib;
            let
              cabalFiles = concatLists (mapAttrsToList
                (name: type: if type == "regular" && hasSuffix ".cabal" name then [ name ] else [ ])
                (builtins.readDir src));

              cabalFile = if length cabalFiles == 1 then builtins.readFile (src + "/${head cabalFiles}") else buitins.abort "Could not find unique file with .cabal suffix in source: ${src}";
              parse = field:
                let
                  lines = (filter (s: hasPrefix "${field}:" s) (splitString "\n" cabalFile));
                  line = if lines != [ ] then head lines else builtins.abort "Could not find line with prefix '${field}:'";
                in
                replaceStrings [ " " ] [ "" ] (head (tail (splitString ":" line)));
              pname = parse "name";
              version = parse "version";
            in
            { inherit src pname version; };

          mkPackageTarball = { pname, version, src }: pkgs.runCommand "${pname}-${version}.tar.gz" { } ''
            cd ${src}/..
            tar --sort=name --owner=Hackage:0 --group=Hackage:0 --mtime='UTC 2009-01-01' -czvf $out $(basename ${src})
          '';

          mkHackageDir = { pname, version, src }@args: pkgs.runCommand "${pname}-${version}-hackage"
            {
              tarball = mkPackageTarball args;
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

          mkHackageTarballFromDirs = hackageDirs: pkgs.runCommand "01-index.tar.gz" { } ''
            mkdir hackage
            ${pkgs.lib.concatStrings (map (dir: ''
              echo ${dir}
              ln -s ${dir}/* hackage/
            '') hackageDirs)}
            cd hackage
            tar --sort=name --owner=root:0 --group=root:0 --mtime='UTC 2009-01-01' -hczvf $out */*/*
          '';

          mkHackageTarball = pkg-defs: mkHackageTarballFromDirs (map mkHackageDir pkg-defs);

          mkHackageNix = hackageTarball: pkgs.runCommand "hackage-nix" { } ''
            set -e
            cp ${hackageTarball} 01-index.tar.gz
            ${pkgs.gzip}/bin/gunzip 01-index.tar.gz
            ${pkgs.haskell-nix.nix-tools.${compiler-nix-name}}/bin/hackage-to-nix $out 01-index.tar "https://not-there/"
          '';

          mkHackageFromSpec = extraHackagePackages: rec {
            tarballs = pkgs.lib.listToAttrs (map (def: { name = def.pname; value = mkPackageTarball def; }) extraHackagePackages);
            hackageTarball = mkHackageTarball extraHackagePackages;
            hackageNix = mkHackageNix hackageTarball;
            # Prevent nix-build from trying to download the package
            module = { packages = (pkgs.lib.mapAttrs (pname: tarball: { src = tarball; }) tarballs); };
          };

          mkHackage = srcs: mkHackageFromSpec (map mkPackageSpec srcs);

          # # equivalent extraPackages:
          # extraPackages = {
          #   mydep.src = ./mydep;
          #   mydep.subdirs = [ "." ];
          # };

          # Usage:
          myhackage = mkHackage [ ./mydep ];
          myapp = final.haskell-nix.project {
            src = ./myapp;
            inherit compiler-nix-name index-state;

            extra-hackages = [ (import myhackage.hackageNix) ];
            extra-hackage-tarballs = { myhackage = myhackage.hackageTarball; };
            modules = [ myhackage.module ];
          };
        };
        overlays = [ haskell-nix.overlay overlay ];
      in
      {
        packages.default = (pkgs.myapp.flake { }).packages."myapp:exe:myapp";

        # export
        inherit (pkgs) mkPackageSpec mkPackageTarball mkHackageDir mkHackageTarballFromDirs mkHackageTarball mkHackageNix mkHackageFromSpec mkHackage;

        # for debugging
        inherit (pkgs) myapp haskell-nix myhackage;
      }
    );
}
