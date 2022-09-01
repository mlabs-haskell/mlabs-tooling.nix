set -xe

export LC_CTYPE=C.UTF-8
export LC_ALL=C.UTF-8
export LANG=C.UTF-8

if test "x$1" = "xcheck"
then
	fourmolu_mode="check"
	cabalfmt_mode="-c"
	nixpkgsfmt_mode="--check"
	echo check
else
	fourmolu_mode="inplace"
	cabalfmt_mode="-i"
	nixpkgsfmt_mode=""
	echo nocheck
fi

find -type f -name '*.hs' ! -path '*/dist-newstyle/*' ! -path '*/tmp/*' | xargs \
	fourmolu \
		-o-XTypeApplications \
		-o-XQualifiedDo \
		-o-XOverloadedRecordDot \
		-o-XNondecreasingIndentation \
		-o-XPatternSynonyms \
		-m "$fourmolu_mode" \
		--indentation 2 \
		--comma-style leading \
		--record-brace-space true  \
		--indent-wheres true \
		--diff-friendly-import-export true  \
		--respectful true  \
		--haddock-style multi-line  \
		--newlines-between-decls 1
find -type f -name '*.hs' ! -path '*/dist-newstyle/*' ! -path '*/tmp/*'
find -type f -name '*.cabal' | xargs cabal-fmt "$cabalfmt_mode"
nixpkgs-fmt $nixpkgsfmt_mode *.nix
