{ inputs }:
let
  inherit (inputs.self) default-ghc;
  mylib = { pkgs, compiler-nix-name }: rec {
    mkPackageSpec = src:
      with pkgs.lib;
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

    mkPackageTarballFor = { pname, version, src }:
      pkgs.runCommand "${pname}-${version}.tar.gz" { } ''
        cd ${src}/..
        tar --sort=name --owner=Hackage:0 --group=Hackage:0 --mtime='UTC 2009-01-01' -czvf $out $(basename ${src})
      '';

    mkHackageDirFor = { pname, version, src }@spec:
      pkgs.runCommand "${pname}-${version}-hackage"
        {
          tarball = mkPackageTarballFor spec;
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

    mkHackageTarballFromDirsFor = hackageDirs:
      pkgs.runCommand "01-index.tar.gz" { } ''
        mkdir hackage
        ${builtins.concatStringsSep "" (map (dir: ''
          echo ${dir}
          ln -s ${dir}/* hackage/
        '') hackageDirs)}
        cd hackage
        tar --sort=name --owner=root:0 --group=root:0 --mtime='UTC 2009-01-01' -hczvf $out */*/*
      '';

    mkHackageTarballFor = pkg-specs:
      mkHackageTarballFromDirsFor (map mkHackageDirFor pkg-specs);

    mkHackageNixFor = hackageTarball:
      pkgs.runCommand "hackage-nix" { } ''
        set -e
        export LC_CTYPE=C.UTF-8
        export LC_ALL=C.UTF-8
        export LANG=C.UTF-8
        cp ${hackageTarball} 01-index.tar.gz
        ${pkgs.gzip}/bin/gunzip 01-index.tar.gz
        ${pkgs.haskell-nix.nix-tools.${compiler-nix-name}}/bin/hackage-to-nix $out 01-index.tar "https://mkHackageNix/"
      '';

    mkModuleFor = pkg-specs: {
      # Prevent nix-build from trying to download the packages
      packages = pkgs.lib.listToAttrs (map
        (spec: {
          name = spec.pname;
          value = { src = mkPackageTarballFor spec; };
        })
        pkg-specs);
    };

    mkHackageFromSpecFor = pkg-specs: rec {
      extra-hackage-tarball = mkHackageTarballFor pkg-specs;
      extra-hackage = mkHackageNixFor extra-hackage-tarball;
      module = mkModuleFor pkg-specs;
    };

    mkHackageFor = srcs: mkHackageFromSpecFor (map mkPackageSpec srcs);
  };
in

{ lib, config, pkgs, haskellLib, ... }:
let
  theHackages = builtins.map ((mylib { inherit pkgs; compiler-nix-name = default-ghc; }).mkHackageFor) config.extraHackages;
  ifd-parallel = pkgs.runCommandNoCC "ifd-parallel" { myInputs = builtins.foldl' (b: a: b ++ [a.extra-hackage a.extra-hackage-tarball]) [] theHackages; } "echo $myInputs > $out";
  ifdseq = x: builtins.seq (builtins.readFile ifd-parallel.outPath) x;
  nlib = inputs.nixpkgs.lib;
in {
  _file = "mlabs-tooling.nix/mk-hackage.nix";
  options = {
    extraHackages = lib.mkOption {
      type = lib.types.listOf (lib.types.listOf lib.types.str);
      default = [];
      description = "List of paths to cabal projects to include as extra hackages";
    };
  };
  config = {
    modules = ifdseq (builtins.map (x: x.module) theHackages);
    extra-hackage-tarballs = ifdseq (
      nlib.listToAttrs (nlib.imap0
        (i: x: {
          name = "_" + builtins.toString i;
          value = x.extra-hackage-tarball;
        })
        theHackages));
    extra-hackages = ifdseq (builtins.map (x: import x.extra-hackage) theHackages);
  };
}
