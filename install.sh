#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
TARGET=${DOTFILES_TARGET:-"$HOME"}
SYNC=0
DRY_RUN=0

usage() {
  cat <<EOF
Uso: $0 [--sync] [--dry-run]

  --sync      instala os plugins conforme o lazy-lock.json
  --dry-run   mostra o que seria feito, sem alterar nada
  -h, --help  mostra esta ajuda

Variáveis:
  DOTFILES_TARGET  diretório de destino do stow (padrão: \$HOME)
EOF
}

for arg in "$@"; do
  case "$arg" in
    --sync) SYNC=1 ;;
    --dry-run) DRY_RUN=1 ;;
    -h | --help)
      usage
      exit 0
      ;;
    *)
      printf 'Opção desconhecida: %s\n\n' "$arg" >&2
      usage >&2
      exit 64
      ;;
  esac
done

fail() {
  printf 'erro: %s\n' "$1" >&2
  exit 1
}

warn() {
  printf 'aviso: %s\n' "$1" >&2
}

run() {
  if [ "$DRY_RUN" -eq 1 ]; then
    printf '+ %s\n' "$*"
  else
    "$@"
  fi
}

command -v git >/dev/null 2>&1 || fail "git não encontrado"
command -v stow >/dev/null 2>&1 || fail "GNU Stow não encontrado (instale o pacote 'stow')"
command -v nvim >/dev/null 2>&1 || fail "Neovim não encontrado"

NVIM_VERSION=$(nvim --version | sed -n '1s/^NVIM v//p')
NVIM_MAJOR=${NVIM_VERSION%%.*}
NVIM_REST=${NVIM_VERSION#*.}
NVIM_MINOR=${NVIM_REST%%.*}

if [ -z "$NVIM_MAJOR" ] || [ -z "$NVIM_MINOR" ]; then
  fail "não foi possível detectar a versão do Neovim"
fi

if [ "$NVIM_MAJOR" -eq 0 ] && [ "$NVIM_MINOR" -lt 11 ]; then
  fail "Neovim 0.11+ é necessário (encontrado v$NVIM_VERSION)"
fi

for tool in rg gcc curl node npm; do
  command -v "$tool" >/dev/null 2>&1 || warn "'$tool' não encontrado; algumas linguagens podem não funcionar"
done

if ! command -v fd >/dev/null 2>&1 && ! command -v fdfind >/dev/null 2>&1; then
  warn "'fd' não encontrado; o picker de arquivos fica mais lento"
fi

NVIM_TARGET="$TARGET/.config/nvim"
BACKUP=""

if [ ! -d "$TARGET" ]; then
  if [ "$DRY_RUN" -eq 1 ]; then
    printf 'aviso: %s não existe (seria criado)\n' "$TARGET" >&2
  else
    mkdir -p "$TARGET"
  fi
fi

is_ours() {
  if [ -L "$NVIM_TARGET" ]; then
    [ "$(readlink -f "$NVIM_TARGET")" = "$ROOT/.config/nvim" ]
  elif [ -f "$NVIM_TARGET/init.lua" ]; then
    [ "$(readlink -f "$NVIM_TARGET/init.lua")" = "$ROOT/.config/nvim/init.lua" ]
  else
    return 1
  fi
}

if [ -e "$NVIM_TARGET" ] || [ -L "$NVIM_TARGET" ]; then
  if ! is_ours; then
    BACKUP="$NVIM_TARGET.bak.$(date +%Y%m%d-%H%M%S)"
    printf 'Configuração existente encontrada em %s\n' "$NVIM_TARGET"
    printf 'Movendo para %s\n' "$BACKUP"
    run mv "$NVIM_TARGET" "$BACKUP"
  fi
fi

printf '\nVerificando conflitos de stow em %s...\n' "$TARGET"
if ! (cd "$ROOT" && stow --no-folding -n -v -t "$TARGET" .); then
  printf '\nConflitos encontrados. Resolva os arquivos acima e rode novamente.\n' >&2
  if [ -n "$BACKUP" ]; then
    printf 'Seu backup está em %s\n' "$BACKUP" >&2
  fi
  exit 1
fi

printf '\nAplicando stow em %s...\n' "$TARGET"
if [ "$DRY_RUN" -eq 1 ]; then
  (cd "$ROOT" && stow --no-folding -n -v -t "$TARGET" .)
else
  (cd "$ROOT" && stow --no-folding --restow -v -t "$TARGET" .)
fi

if [ "$SYNC" -eq 1 ]; then
  printf '\nInstalando plugins conforme o lazy-lock (pode demorar)...\n'
  run nvim --headless "+Lazy! restore" +qa
fi

cat <<EOF

Pronto. Próximos passos:
  1. Abra o Neovim: nvim
  2. Aguarde a instalação dos plugins restantes (:Lazy)
  3. Confira a saúde: :checkhealth
  4. Instale ferramentas externas: :Mason

Atualização:
  git pull && ./install.sh --sync

Desinstalação:
  ./uninstall.sh
EOF

if [ -n "$BACKUP" ] && [ "$DRY_RUN" -eq 0 ]; then
  printf '\nBackup da configuração anterior: %s\n' "$BACKUP"
fi
