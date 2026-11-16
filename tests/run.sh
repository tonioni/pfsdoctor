#!/bin/bash
# Live-source tests: each *_live.c lifts the REAL function(s) named in its
# "@src file @func name" header out of the source in this checkout, compiles
# them with the mocks in the test and runs them on the host.
#
#   bash tests/run.sh
#
# Binaries and lifted functions go to build/tests.
set -u
DIR=$(cd "$(dirname "$0")" && pwd -P)
SRC=$(cd "$DIR/.." && pwd -P)
OUT=$SRC/build/tests
CC=${CC:-cc}
mkdir -p $OUT/gen
pass=0; fail=0

extract() {  # $1=file $2=func: the definition starting at column zero
  awk -v fn="$2" '
    !ins && $0 ~ /^[A-Za-z_]/ && $0 ~ ("(^|[^A-Za-z0-9_])" fn "[[:space:]]*[(]") && $0 !~ /;/ { ins=1; buf=""; n=0; seen=0 }
    ins { buf = buf $0 "\n"; o=gsub(/{/,"{"); c=gsub(/}/,"}"); n+=o-c; if(n>0) seen=1; if(seen && n==0) { last=buf; ins=0 } }
    END { printf "%s", last }
  ' "$1"
}

cd $DIR
for t in *_live.c; do
  src=; ok=1
  for tok in $(grep -oE '@(src|func) [^ ]+' $t | tr ' ' ':'); do
    case $tok in @src:*) src=${tok#@src:}; continue ;; esac
    fn=${tok#@func:}
    extract $SRC/$src $fn > $OUT/gen/$fn.c
    [ -s $OUT/gen/$fn.c ] || { echo "  MISS  $t: $fn not in $src"; ok=0; break; }
  done
  [ $ok = 1 ] || { fail=$((fail+1)); continue; }
  if ! $CC -w -I$OUT -o $OUT/${t%.c} $t 2>$OUT/gen/${t%.c}.build.log; then
    echo "  BUILD $t (see $OUT/gen/${t%.c}.build.log)"; fail=$((fail+1)); continue
  fi
  if $OUT/${t%.c}; then pass=$((pass+1)); else fail=$((fail+1)); fi
done
echo "== live: $pass passed, $fail failed =="
[ $fail -eq 0 ]
