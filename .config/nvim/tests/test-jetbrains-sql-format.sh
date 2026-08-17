#!/bin/sh
set -eu

CONFIG_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
WRAPPER="$CONFIG_ROOT/scripts/jetbrains-sql-format.sh"
POSTPROCESSOR="$CONFIG_ROOT/scripts/jetbrains-sql-postprocess.py"
VALIDATOR="$CONFIG_ROOT/scripts/validate-sqlstyle-guide.py"
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
[ -x "$POSTPROCESSOR" ] || fail "postprocessor is missing or not executable: $POSTPROCESSOR"
[ -x "$VALIDATOR" ] || fail "validator is missing or not executable: $VALIDATOR"

SCHEME="$TMP_ROOT/style.xml"
SQL_FILE="$TMP_ROOT/input.sql"
FAKE_FORMATTER="$TMP_ROOT/fake-format.sh"
ARGS_FILE="$TMP_ROOT/args.txt"
ENV_FILE="$TMP_ROOT/env.txt"

printf '%s\n' '<code_scheme name="test" />' > "$SCHEME"
cat > "$SQL_FILE" <<'SQL'
create table clientes.cliente (
usuario_id bigint primary key,
nome varchar(150) not null,
telefone varchar(30),
data_nascimento date,
restaurant_id bigint not null,
name varchar(150) not null,

constraint uq_category_restaurant_name unique (restaurant_id, name),
constraint fk_cliente_usuario foreign key (usuario_id) references identidade.usuario (usuario_id) on delete cascade
);
SQL
chmod 600 "$SQL_FILE"

cat > "$FAKE_FORMATTER" <<'FAKE'
#!/bin/sh
set -eu
: "${DATAGRIP_PROPERTIES:?DATAGRIP_PROPERTIES was not set}"
printf '%s\n' "$DATAGRIP_PROPERTIES" > "$TEST_ENV_FILE"
printf '%s\n' "$@" > "$TEST_ARGS_FILE"
cat > "$3" <<'SQL'
CREATE TABLE clientes.cliente (
      usuario_id BIGINT
            PRIMARY KEY,
      nome VARCHAR(150) NOT NULL,
      telefone VARCHAR(30),
      data_nascimento DATE,
      restaurant_id BIGINT NOT NULL,
      name VARCHAR(150) NOT NULL,

      CONSTRAINT uq_category_restaurant_name UNIQUE (restaurant_id, name),
      CONSTRAINT fk_cliente_usuario
            FOREIGN KEY (usuario_id)
                  REFERENCES identidade.usuario (usuario_id)
                  ON DELETE CASCADE
);
SQL
FAKE
chmod +x "$FAKE_FORMATTER"

TEST_ARGS_FILE="$ARGS_FILE" \
TEST_ENV_FILE="$ENV_FILE" \
JETBRAINS_DATAGRIP_FORMATTER="$FAKE_FORMATTER" \
XDG_CACHE_HOME="$TMP_ROOT/cache" \
  "$WRAPPER" "$SCHEME" "$SQL_FILE"

EXPECTED="$TMP_ROOT/expected.sql"
cat > "$EXPECTED" <<'SQL'
CREATE TABLE clientes.cliente (
      usuario_id BIGINT PRIMARY KEY,
      nome VARCHAR(150) NOT NULL,
      telefone VARCHAR(30),
      data_nascimento DATE,
      restaurant_id BIGINT NOT NULL,
      name VARCHAR(150) NOT NULL,

      CONSTRAINT uq_category_restaurant_name
          UNIQUE (restaurant_id, name),
      CONSTRAINT fk_cliente_usuario
          FOREIGN KEY (usuario_id)
          REFERENCES identidade.usuario (usuario_id)
          ON DELETE CASCADE
  );
SQL
cmp -s "$EXPECTED" "$SQL_FILE" || fail "DDL post-processing did not produce the expected layout"
[ "$(stat -c '%a' "$SQL_FILE")" = '600' ] || fail "postprocessor changed SQL file permissions"
"$VALIDATOR" "$SQL_FILE" || fail "formatted SQL failed SQL Style Guide validation"
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

INVALID="$TMP_ROOT/invalid-style.sql"
cat > "$INVALID" <<'SQL'
create table clientes.cliente (
	usuario_id bigint
);
SQL
if "$VALIDATOR" "$INVALID" >/dev/null 2>&1; then
  fail "validator should reject lowercase keywords and tabs"
fi

INLINE_UNIQUE="$TMP_ROOT/inline-unique.sql"
cat > "$INLINE_UNIQUE" <<'SQL'
CREATE TABLE categories.category (
      restaurant_id BIGINT NOT NULL,
      name VARCHAR(150) NOT NULL,

      CONSTRAINT uq_category_restaurant_name UNIQUE (restaurant_id, name)
  );
SQL
if "$VALIDATOR" "$INLINE_UNIQUE" >/dev/null 2>&1; then
  fail "validator should reject named UNIQUE on the CONSTRAINT line"
fi

QUOTED_AND_COMMENTED="$TMP_ROOT/quoted-and-commented.sql"
cat > "$QUOTED_AND_COMMENTED" <<'SQL'
SELECT 'create table constraint unique', "default", $$foreign key on delete$$;
-- create table constraint unique
/* outer create table
   /* nested unique constraint */
   on delete cascade */
SQL
"$VALIDATOR" "$QUOTED_AND_COMMENTED" || fail "validator treated quoted/commented text as executable SQL"

COMMENTED_PRIMARY="$TMP_ROOT/commented-primary.sql"
cat > "$COMMENTED_PRIMARY" <<'SQL'
CREATE TABLE example.comment_safety (
      id BIGINT, -- identifier
            PRIMARY KEY (id)
  );
SQL
"$POSTPROCESSOR" "$COMMENTED_PRIMARY"
grep -q '^      id BIGINT, -- identifier$' "$COMMENTED_PRIMARY" || fail "postprocessor changed the commented column"
grep -q '^            PRIMARY KEY (id)$' "$COMMENTED_PRIMARY" || fail "postprocessor folded PRIMARY KEY into a line comment"
if "$VALIDATOR" "$COMMENTED_PRIMARY" >/dev/null 2>&1; then
  fail "validator should fail safely instead of accepting commented-out PRIMARY KEY"
fi

TABLE_PRIMARY="$TMP_ROOT/table-primary.sql"
cat > "$TABLE_PRIMARY" <<'SQL'
CREATE TABLE example.table_primary (
      id BIGINT,
            PRIMARY KEY (id)
  );
SQL
"$POSTPROCESSOR" "$TABLE_PRIMARY"
grep -q '^      id BIGINT,$' "$TABLE_PRIMARY" || fail "postprocessor changed the preceding table column"
grep -q '^            PRIMARY KEY (id)$' "$TABLE_PRIMARY" || fail "postprocessor converted table PRIMARY KEY to inline syntax"
if "$VALIDATOR" "$TABLE_PRIMARY" >/dev/null 2>&1; then
  fail "validator should reject unsupported table-level PRIMARY KEY layout"
fi

QUOTED_CREATE="$TMP_ROOT/quoted-create.sql"
cat > "$QUOTED_CREATE" <<'SQL'
SELECT $body$
CREATE TABLE embedded (
id BIGINT
);
$body$;
SQL
cp "$QUOTED_CREATE" "$QUOTED_CREATE.before"
"$POSTPROCESSOR" "$QUOTED_CREATE"
cmp -s "$QUOTED_CREATE.before" "$QUOTED_CREATE" || fail "postprocessor changed CREATE TABLE text inside a dollar-quoted literal"

DOLLAR_IDENTIFIER="$TMP_ROOT/dollar-identifier.sql"
cat > "$DOLLAR_IDENTIFIER" <<'SQL'
SELECT foo$tag$ FROM t;
create table visible (
id bigint
);
SELECT bar$tag$ FROM t;
SQL
cp "$DOLLAR_IDENTIFIER" "$DOLLAR_IDENTIFIER.before"
"$POSTPROCESSOR" "$DOLLAR_IDENTIFIER"
if cmp -s "$DOLLAR_IDENTIFIER.before" "$DOLLAR_IDENTIFIER"; then
  fail "dollar tag inside an identifier incorrectly masked executable CREATE TABLE"
fi
grep -q '^  );$' "$DOLLAR_IDENTIFIER" || fail "CREATE TABLE after dollar identifier was not normalized"
if "$VALIDATOR" "$DOLLAR_IDENTIFIER" >/dev/null 2>&1; then
  fail "validator ignored lowercase CREATE TABLE after dollar identifiers"
fi

COLUMN_AFTER_CONSTRAINT="$TMP_ROOT/column-after-constraint.sql"
cat > "$COLUMN_AFTER_CONSTRAINT" <<'SQL'
CREATE TABLE example.constraint_then_column (
      first_id BIGINT NOT NULL,

      CONSTRAINT uq_first_id
          UNIQUE (first_id),
      second_id BIGINT NOT NULL
  );
SQL
"$VALIDATOR" "$COLUMN_AFTER_CONSTRAINT" || fail "constraint state leaked into the following column"

printf '%s\n' 'PASS: JetBrains SQL formatter wrapper contract'
