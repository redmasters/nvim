#!/bin/sh
set -eu

CONFIG_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
WRAPPER="$CONFIG_ROOT/scripts/jetbrains-sql-format.sh"
TMP_ROOT=$(mktemp -d /tmp/hermes-verify-jetbrains-sql-wrapper-XXXXXX)
cleanup() {
  rm -rf "$TMP_ROOT"
}
trap cleanup EXIT HUP INT TERM

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

[ -x "$WRAPPER" ] || fail "wrapper is missing or not executable: $WRAPPER"

SCHEME="$TMP_ROOT/style.xml"
SQL_FILE="$TMP_ROOT/input.sql"
FAKE_FORMATTER="$TMP_ROOT/fake-format.sh"
ARGS_FILE="$TMP_ROOT/args.txt"
ENV_FILE="$TMP_ROOT/env.txt"

printf '%s\n' '<code_scheme name="test" />' > "$SCHEME"
printf '%s\n' 'select 1;' > "$SQL_FILE"

cat > "$FAKE_FORMATTER" <<'FAKE'
#!/bin/sh
set -eu
: "${DATAGRIP_PROPERTIES:?DATAGRIP_PROPERTIES was not set}"
printf '%s\n' "$DATAGRIP_PROPERTIES" > "$TEST_ENV_FILE"
printf '%s\n' "$@" > "$TEST_ARGS_FILE"
printf '%s\n' 'SELECT 1;' > "$3"
FAKE
chmod +x "$FAKE_FORMATTER"

TEST_ARGS_FILE="$ARGS_FILE" \
TEST_ENV_FILE="$ENV_FILE" \
JETBRAINS_DATAGRIP_FORMATTER="$FAKE_FORMATTER" \
XDG_CACHE_HOME="$TMP_ROOT/cache" \
  "$WRAPPER" "$SCHEME" "$SQL_FILE"

[ "$(cat "$SQL_FILE")" = 'SELECT 1;' ] || fail "formatted SQL was not written back"
[ "$(sed -n '1p' "$ARGS_FILE")" = '-s' ] || fail "first formatter argument must be -s"
[ "$(sed -n '2p' "$ARGS_FILE")" = "$SCHEME" ] || fail "scheme path was not forwarded"
[ "$(sed -n '3p' "$ARGS_FILE")" = "$SQL_FILE" ] || fail "SQL path was not forwarded"

PROPERTIES=$(cat "$ENV_FILE")
[ -r "$PROPERTIES" ] || fail "isolated idea.properties was not created"
for property in idea.config.path idea.system.path idea.plugins.path idea.log.path; do
  grep -q "^${property}=" "$PROPERTIES" || fail "missing $property in idea.properties"
done

if JETBRAINS_DATAGRIP_FORMATTER="$FAKE_FORMATTER" "$WRAPPER" "$TMP_ROOT/missing.xml" "$SQL_FILE" >/dev/null 2>&1; then
  fail "missing scheme should fail"
fi

if JETBRAINS_DATAGRIP_FORMATTER="$TMP_ROOT/missing-format.sh" "$WRAPPER" "$SCHEME" "$SQL_FILE" >/dev/null 2>&1; then
  fail "missing formatter should fail"
fi

printf '%s\n' 'PASS: JetBrains SQL formatter wrapper contract'
