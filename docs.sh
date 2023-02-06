set -xe

export LC_CTYPE=C.UTF-8
export LC_ALL=C.UTF-8
export LANG=C.UTF-8

echo generating docs
# I assume this is bad
nix build .#haddock
echo serving docs
python3 -m http.server --directory ./result/share/doc 8080
