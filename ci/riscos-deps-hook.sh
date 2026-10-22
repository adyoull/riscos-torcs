#!/bin/sh
# Run by .github/workflows/riscos-deps-update.yml as
#   ci/riscos-deps-hook.sh NAME OLD_TAG NEW_TAG
# from the top of the repository when NAME (a line of .riscos-deps) has a
# newer release, to move the pins kept outside .riscos-deps:
#   riscos-mesa      the devkit's sha256 line in build/SHA256SUMS (env.sh
#                    and fetch.sh read the version from .riscos-deps)
#   riscos-crossdev  nothing (the workflows' image follows .riscos-deps)
set -eu
name=$1 old=${2#v} new=${3#v}
case $name in
riscos-mesa|adyoull/riscos-mesa)
  tmp=$(mktemp -d)
  trap 'rm -rf "$tmp"' EXIT
  f_old=riscos-mesa-devkit-$old.tgz f_new=riscos-mesa-devkit-$new.tgz
  curl -fsSL --retry 3 -o "$tmp/$f_new" \
    "https://github.com/adyoull/riscos-mesa/releases/download/v$new/$f_new"
  sum=$(sha256sum "$tmp/$f_new" | cut -d' ' -f1)
  grep -q "  $f_old\$" build/SHA256SUMS ||
    { echo "riscos-deps-hook: no $f_old line in build/SHA256SUMS" >&2; exit 1; }
  awk -v o="$f_old" -v n="$f_new" -v s="$sum" '$2 == o {print s "  " n; next} {print}' \
    build/SHA256SUMS > "$tmp/sums"
  cat "$tmp/sums" > build/SHA256SUMS
  ;;
esac
