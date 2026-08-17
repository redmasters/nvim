#!/bin/sh
set -eu

usage() {
  printf 'Usage: %s <code-style.xml> <file.sql>\n' "$0" >&2
  exit 64
}

[ "$#" -eq 2 ] || usage

SCHEME=$1
SQL_FILE=$2
FORMATTER=${JETBRAINS_DATAGRIP_FORMATTER:-"$HOME/.local/share/JetBrains/Toolbox/apps/datagrip/bin/format.sh"}
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
LEXER=$SCRIPT_DIR/sql_style_lexer.py
POSTPROCESSOR=$SCRIPT_DIR/jetbrains-sql-postprocess.py
VALIDATOR=$SCRIPT_DIR/validate-sqlstyle-guide.py
CACHE_ROOT=${XDG_CACHE_HOME:-"$HOME/.cache"}/nvim/jetbrains-datagrip-formatter
PROPERTIES_FILE=$CACHE_ROOT/idea.properties

[ -r "$SCHEME" ] || {
  printf 'JetBrains code style scheme is not readable: %s\n' "$SCHEME" >&2
  exit 66
}

[ -r "$SQL_FILE" ] && [ -w "$SQL_FILE" ] || {
  printf 'SQL file is not readable and writable: %s\n' "$SQL_FILE" >&2
  exit 66
}

[ -x "$FORMATTER" ] || {
  printf 'DataGrip formatter is not executable: %s\n' "$FORMATTER" >&2
  exit 69
}

[ -x "$POSTPROCESSOR" ] || {
  printf 'SQL postprocessor is not executable: %s\n' "$POSTPROCESSOR" >&2
  exit 69
}

[ -r "$LEXER" ] || {
  printf 'SQL lexer helper is not readable: %s\n' "$LEXER" >&2
  exit 69
}

[ -x "$VALIDATOR" ] || {
  printf 'SQL Style Guide validator is not executable: %s\n' "$VALIDATOR" >&2
  exit 69
}

umask 077
mkdir -p \
  "$CACHE_ROOT/config" \
  "$CACHE_ROOT/system" \
  "$CACHE_ROOT/plugins" \
  "$CACHE_ROOT/log"

cat > "$PROPERTIES_FILE" <<EOF
idea.config.path=$CACHE_ROOT/config
idea.system.path=$CACHE_ROOT/system
idea.plugins.path=$CACHE_ROOT/plugins
idea.log.path=$CACHE_ROOT/log
idea.auto.reload.plugins=false
EOF

DATAGRIP_PROPERTIES=$PROPERTIES_FILE
export DATAGRIP_PROPERTIES
"$FORMATTER" -s "$SCHEME" "$SQL_FILE"
"$POSTPROCESSOR" "$SQL_FILE"
exec "$VALIDATOR" "$SQL_FILE"
