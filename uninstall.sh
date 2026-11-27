#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
TARGET=${DOTFILES_TARGET:-"$HOME"}
DRY_RUN=0

usage() {
  cat <<EOF
Uso: $0 [--dry-run]

Remove os links criados pelo stow em \$HOME. O diretório de dados
(~/.local/share/nvim, ~/.cache/nvim) não é removido.

  --dry-run   mostra o que seria feito, sem alterar nada
  -h, --help  mostra esta ajuda

Variáveis:
  DOTFILES_TARGET  diretório de destino do stow (padrão: \$HOME)
EOF
}

for arg in "$@"; do
  case "$arg" in
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

command -v stow >/dev/null 2>&1 || {
  printf 'erro: GNU Stow não encontrado\n' >&2
  exit 1
}

if [ "$DRY_RUN" -eq 1 ]; then
  (cd "$ROOT" && stow --no-folding -D -n -v -t "$TARGET" .)
  exit 0
fi

(cd "$ROOT" && stow --no-folding -D -v -t "$TARGET" .)

# Remove apenas diretórios vazios que sobraram do modo --no-folding.
if [ -d "$TARGET/.config/nvim" ]; then
  find "$TARGET/.config/nvim" -depth -type d -empty -delete
fi

cat <<EOF

Links removidos de $TARGET.

Os dados do Neovim (plugins, Mason, Treesitter) continuam em:
  \${XDG_DATA_HOME:-\$HOME/.local/share}/nvim
  \${XDG_CACHE_HOME:-\$HOME/.cache}/nvim

Backups de instalações anteriores, se existirem:
EOF

ls -d "$TARGET"/.config/nvim.bak.* 2>/dev/null || printf '  (nenhum)\n'
