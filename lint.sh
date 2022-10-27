set -xe

export LC_CTYPE=C.UTF-8
export LC_ALL=C.UTF-8
export LANG=C.UTF-8

find . -type f -name '*.hs' ! -path '*/dist-newstyle/*' ! -path '*/tmp/*' -exec \
	hlint -XTypeApplications -XNondecreasingIndentation \
	-XPatternSynonyms -XQualifiedDo -XOverloadedRecordDot --hint=@hlint_config@ {} +
