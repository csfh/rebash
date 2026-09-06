#!/usr/bin/env bash
# Install rebash and place `rb` on PATH.

set -euo pipefail

REPO="csfh/rebash"
BIN="rb"
PREFIX=""
ACTION=""

die() {
  printf 'install.sh: %s\n' "$*" >&2
  exit 1
}

usage() {
  cat <<'EOF'
Install rebash and place rb on PATH.

Usage:
  install.sh [--prefix DIR]
  install.sh --uninstall [--prefix DIR]
  install.sh --help

Default prefix: ~/.local
Installs the rb command to ~/.local/bin/rb

Examples:
  curl -fsSL https://raw.githubusercontent.com/csfh/rebash/main/install.sh | bash
  ./install.sh
  ./install.sh --prefix /usr/local
  ./install.sh --uninstall
EOF
}

destination_path() {
  local prefix="${1%/}"
  printf '%s\n' "${prefix}/bin/${BIN}"
}

data_path() {
  local prefix="${1%/}"
  printf '%s\n' "${prefix}/share/rebash"
}

cache_path() {
  printf '%s\n' "${XDG_CACHE_HOME:-$HOME/.cache}/rebash/src"
}

repo_url() {
  printf '%s\n' "${REBASH_REPO:-https://github.com/${REPO}.git}"
}

parse_args() {
  PREFIX="${PREFIX:-$HOME/.local}"
  ACTION="install"

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --prefix)
        [[ $# -ge 2 && -n "$2" ]] || die "--prefix requires a directory"
        PREFIX="$2"
        shift 2
        ;;
      --uninstall)
        ACTION="uninstall"
        shift
        ;;
      -h | --help)
        ACTION="help"
        shift
        ;;
      *)
        die "unknown option: $1"
        ;;
    esac
  done

  [[ -n "$PREFIX" ]] || die "prefix must not be empty"
}

require_command() {
  local name=$1
  command -v "$name" >/dev/null 2>&1 || die "missing required command: ${name}"
}

warn_if_not_on_path() {
  local bin_dir=$1
  case ":${PATH}:" in
    *:"${bin_dir}":*) ;;
    *)
      printf 'note: %s is not on PATH\n' "$bin_dir"
      ;;
  esac
}

script_dir() {
  local src=${BASH_SOURCE[0]:-$0}
  if [[ $src == /dev/fd/* || $src == /proc/self/fd/* ]]; then
    return 1
  fi
  (cd -- "$(dirname -- "$src")" && pwd)
}

local_source() {
  local here
  here=$(script_dir) || return 1
  [[ -x "$here/bin/${BIN}" && -f "$here/bashrc" ]] || return 1
  printf '%s\n' "$here"
}

clone_repo() {
  local repo=$1
  local cache=$2
  if [[ -d "$repo" ]]; then
    git clone --depth 1 "file://$(cd -- "$repo" && pwd)" "$cache" || die "could not clone ${repo}"
    return
  fi
  git clone --depth 1 "$repo" "$cache" || die "could not clone ${repo}"
}

sync_cache() {
  local cache repo
  require_command git
  cache=$(cache_path)
  repo=$(repo_url)
  mkdir -p "$(dirname -- "$cache")"
  if [[ ! -d "$cache/.git" ]]; then
    clone_repo "$repo" "$cache"
    printf '%s\n' "$cache"
    return
  fi
  git -C "$cache" remote set-url origin "$repo"
  git -C "$cache" fetch --depth 1 origin
  git -C "$cache" checkout -B "$(git -C "$cache" rev-parse --abbrev-ref HEAD)" FETCH_HEAD
  printf '%s\n' "$cache"
}

resolve_source() {
  local source
  if source=$(local_source); then
    printf '%s\n' "$source"
    return
  fi
  sync_cache
}

write_revision() {
  local dest=$1
  local source=$2
  local sha=""
  if git -C "$source" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    sha=$(git -C "$source" rev-parse HEAD)
  fi
  [[ $sha =~ ^[0-9a-f]{4,40}$ ]] || return 0
  printf '%s\n' "$sha" >"$dest/REVISION"
}

write_wrapper() {
  local dest=$1
  local wrapper=$2
  mkdir -p "$(dirname -- "$wrapper")"
  rm -f "$wrapper"
  cat >"$wrapper" <<EOF
#!/usr/bin/env bash
exec "$dest/bin/${BIN}" "\$@"
EOF
  chmod 755 "$wrapper"
}

stage() {
  local source=$1
  local dest=$2
  [[ -x "$source/bin/${BIN}" && -f "$source/bashrc" ]] || die "source is missing bin/${BIN} or bashrc: ${source}"
  mkdir -p "$dest/bin"
  require_command install
  install -Dm755 "$source/bin/${BIN}" "$dest/bin/${BIN}"
  install -Dm644 "$source/bashrc" "$dest/bashrc"
  if [[ -d "$source/plugins" ]]; then
    rm -rf "$dest/plugins"
    cp -a "$source/plugins" "$dest/plugins"
  fi
  write_revision "$dest" "$source"
}

uninstall() {
  local dest wrapper
  dest=$(data_path "$PREFIX")
  wrapper=$(destination_path "$PREFIX")
  if [[ -e "$wrapper" || -L "$wrapper" ]]; then
    rm -f "$wrapper" || die "cannot remove ${wrapper}"
    printf 'removed %s\n' "$wrapper"
  else
    printf 'rb is not installed at %s\n' "$wrapper"
  fi
  if [[ -e "$dest" ]]; then
    rm -rf "$dest" || die "cannot remove ${dest}"
    printf 'removed %s\n' "$dest"
  fi
}

install_rebash() {
  local source dest wrapper
  source=$(resolve_source)
  dest=$(data_path "$PREFIX")
  wrapper=$(destination_path "$PREFIX")

  mkdir -p "$(dirname -- "$wrapper")" "$(dirname -- "$dest")"
  [[ -w "$(dirname -- "$wrapper")" ]] || die "cannot write to $(dirname -- "$wrapper"); choose another --prefix or rerun with write access"

  stage "$source" "$dest"
  write_wrapper "$dest" "$wrapper"

  [[ -x "$wrapper" ]] || die "failed to install ${wrapper}"
  warn_if_not_on_path "$(dirname -- "$wrapper")"
  printf 'installed %s to %s\n' "$BIN" "$wrapper"
}

main() {
  parse_args "$@"
  case "$ACTION" in
    help)
      usage
      ;;
    uninstall)
      uninstall
      ;;
    install)
      install_rebash
      ;;
    *)
      die "internal error: unknown action ${ACTION}"
      ;;
  esac
}

# BASH_SOURCE is unset when the script is piped to bash (curl | bash).
if [[ -z ${BASH_SOURCE[0]:-} || ${BASH_SOURCE[0]} == "$0" ]]; then
  main "$@"
fi
