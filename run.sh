#!/usr/bin/env bash
#
# run.sh - run the SIMPL tests against your own checker.
#
#   ./test/run.sh                 every test that has a recorded result, one per line
#   ./test/run.sh type scope      only those groups
#   ./test/run.sh -c              remove test/build/
#
# It looks for your grammars and Java in src/ beside this test directory, for
# an antlr*.jar in the usual places, and builds into test/build/. Nothing
# outside test/ is written. The driver class is "simpl"; if yours has another
# name, say MAIN=yourclass ./test/run.sh.

set -euo pipefail

SELF="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT="$(dirname "$SELF")"
SRC="${SRC:-$PROJECT/src}"
BUILD="$SELF/build"
MAIN="${MAIN:-simpl}"
SUITES=(valid scope type syntax corners)

die() { echo "run.sh: $*" >&2; exit 2; }

# The jar: wherever you already keep it. First antlr*.jar beside your grammars,
# in here, at the top of the project, in ~/antlr or in ~; ANTLR_JAR=path wins
find_jar() {
    local where found
    for where in "$SRC" "$SELF" "$PROJECT" "$HOME/antlr" "$HOME"; do
        [ -d "$where" ] || continue
        found="$(find "$where" -maxdepth 1 -name 'antlr*.jar' -print -quit 2>/dev/null)"
        [ -n "$found" ] && { echo "$found"; return 0; }
    done
    return 0   # not found is not an error here; the check below says so
}
ANTLR_JAR="${ANTLR_JAR:-$(find_jar)}"

# Colour for a terminal, plain text for a pipe or when NO_COLOR is set.
if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
    GREEN=$'\033[32m'; RED=$'\033[31m'; YELLOW=$'\033[33m'; OFF=$'\033[0m'
else
    GREEN=''; RED=''; YELLOW=''; OFF=''
fi

if [ "${1:-}" = "-c" ]; then
    rm -rf "$BUILD"
    echo "cleaned ${BUILD#"$PROJECT"/}"
    exit 0
fi

[ -n "$ANTLR_JAR" ] && [ -f "$ANTLR_JAR" ] || \
    die "no antlr*.jar found; drop one beside your grammars in ${SRC#"$PROJECT"/}, or say ANTLR_JAR=path"
[ -d "$SRC" ] || die "no directory at $SRC; put your grammars and Java there, or say SRC=..."

# --- build ------------------------------------------------------------
mkdir -p "$BUILD"
echo "building with ${ANTLR_JAR##*/}..." >&2

# A split grammar needs the lexer generated first, for its token vocabulary.
lexer="$(find "$SRC" -maxdepth 1 -name '*[Ll]exer.g4' -print -quit)"
if [ -n "$lexer" ]; then
    java -jar "$ANTLR_JAR" -o "$BUILD" "$lexer"
    for grammar in "$SRC"/*.g4; do
        [ "$grammar" = "$lexer" ] && continue
        java -jar "$ANTLR_JAR" -o "$BUILD" -lib "$BUILD" -visitor -listener "$grammar"
    done
else
    for grammar in "$SRC"/*.g4; do
        java -jar "$ANTLR_JAR" -o "$BUILD" -visitor -listener "$grammar"
    done
fi

javac -cp "$ANTLR_JAR" -d "$BUILD" "$BUILD"/*.java "$SRC"/*.java

CP="$ANTLR_JAR:$BUILD"

# Say so once, rather than once per test.
javap -cp "$CP" "$MAIN" >/dev/null 2>&1 || die "built, but there is no class '$MAIN' (set MAIN=...)"

# --- run --------------------------------------------------------------
wanted=("$@")
[ ${#wanted[@]} -gt 0 ] || wanted=("${SUITES[@]}")

same=0
differ=0
reordered=0
printed=0

for group in "${wanted[@]}"; do
    group="${group%/}"
    [ -d "$SELF/$group" ] || die "no such group: $group"
    compgen -G "$SELF/$group/*.simpl" >/dev/null || die "no test programs in $group"

    for source in "$SELF/$group"/*.simpl; do
        yours="$(java -cp "$CP" "$MAIN" "$source" 2>&1 >/dev/null || true)"
        expected="${source%.simpl}.expected"
        name="${source#"$PROJECT"/}"

        if [ ! -f "$expected" ]; then
            echo "  ----  $name"
            echo "${yours:-(nothing)}" | sed 's/^/          /'
            printed=$((printed + 1))
            continue
        fi

        mine="$(cat "$expected")"
        if [ "$yours" = "$mine" ]; then
            same=$((same + 1))
            echo "  ${GREEN}PASS${OFF}  $name"
            continue
        fi

        # Same messages in another order is not a failure: note 6 reads either
        # as one merged source order or as each checker in its own
        if [ "$(printf '%s\n' "$yours" | sort)" = "$(printf '%s\n' "$mine" | sort)" ]; then
            reordered=$((reordered + 1))
            echo "  ${YELLOW}ORDER${OFF} $name  same messages, another order"
            continue
        fi

        differ=$((differ + 1))
        echo "  ${RED}FAIL${OFF}  $name"
        echo "          mine:"
        echo "${mine:-(nothing)}" | sed 's/^/            /'
        echo "          yours:"
        echo "${yours:-(nothing)}" | sed 's/^/            /'
    done
done

echo
total=$((same + reordered + differ))
if [ "$total" -gt 0 ]; then
    line="$total compared: ${GREEN}$same the same${OFF}"
    [ "$reordered" -eq 0 ] || line="$line, ${YELLOW}$reordered in another order${OFF}"
    if [ "$differ" -eq 0 ]; then
        echo "  $line, 0 different"
    else
        echo "  $line, ${RED}$differ different${OFF}"
    fi
fi
if [ $printed -gt 0 ]; then
    echo "  $printed printed, with nothing to compare against"
fi
echo
