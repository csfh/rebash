#!/usr/bin/env bash
# Install rebash and place `rb` on PATH.

set -euo pipefail

REPO="csfh/rebash"
BIN="rb"
PREFIX=""
ACTION=""
CHANNEL=""

die() {
  printf 'install.sh: %s\n' "$*" >&2
  exit 1
}

usage() {
  cat <<'EOF'
Install rebash and place rb on PATH.

Usage:
  install.sh [--prefix DIR] [--channel CHANNEL]
  install.sh --update [--prefix DIR] [--channel CHANNEL]
  install.sh --uninstall [--prefix DIR]
  install.sh --help

Default prefix: ~/.local
Default channel: main (or the channel already installed, for --update)
Installs the rb command to ~/.local/bin/rb

Examples:
  curl -fsSL https://raw.githubusercontent.com/csfh/rebash/main/install.sh | bash
  ./install.sh
  ./install.sh --prefix /usr/local --channel alpha
  ./install.sh --update
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

valid_channel_name() {
  [[ $1 =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]]
}

repo_url() {
  local repo=${REBASH_REPO:-https://github.com/${REPO}.git}
  if [[ -d "$repo" ]]; then
    (cd -- "$repo" && pwd)
    return
  fi
  printf '%s\n' "$repo"
}

read_trimmed() {
  local file=$1
  local value=""
  [[ -r "$file" ]] || return 1
  value=$(<"$file")
  value=${value%%$'\n'*}
  [[ -n $value ]] || return 1
  printf '%s\n' "$value"
}

parse_args() {
  PREFIX="${PREFIX:-$HOME/.local}"
  ACTION="install"
  CHANNEL="${CHANNEL:-}"

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --prefix)
        [[ $# -ge 2 && -n "$2" ]] || die "--prefix requires a directory"
        PREFIX="$2"
        shift 2
        ;;
      --channel)
        [[ $# -ge 2 && -n "$2" ]] || die "--channel requires a value"
        CHANNEL="$2"
        shift 2
        ;;
      --update)
        ACTION="update"
        shift
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
  local channel=$3
  if [[ -d "$repo" ]]; then
    git clone --depth 1 --branch "$channel" "file://$(cd -- "$repo" && pwd)" "$cache" >&2 \
      || die "could not clone ${repo} (channel ${channel})"
    return
  fi
  git clone --depth 1 --branch "$channel" "$repo" "$cache" >&2 \
    || die "could not clone ${repo} (channel ${channel})"
}

sync_cache() {
  local channel=$1
  local cache repo
  [[ -n $channel ]] || die "channel must not be empty"
  valid_channel_name "$channel" || die "invalid channel: ${channel}"
  require_command git
  cache=$(cache_path)
  repo=$(repo_url)
  mkdir -p "$(dirname -- "$cache")"
  if [[ ! -d "$cache/.git" ]]; then
    clone_repo "$repo" "$cache" "$channel"
    printf '%s\n' "$cache"
    return
  fi
  git -C "$cache" remote set-url origin "$repo"
  git -C "$cache" fetch --depth 1 origin "$channel" >&2 || die "channel not found: ${channel}"
  git -C "$cache" checkout -B "$channel" FETCH_HEAD >&2
  printf '%s\n' "$cache"
}

resolve_source() {
  local source
  if source=$(local_source); then
    printf '%s\n' "$source"
    return
  fi
  sync_cache "$CHANNEL"
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
  if [[ -f "$source/install.sh" ]]; then
    install -Dm755 "$source/install.sh" "$dest/install.sh"
  fi
  if [[ -f "$source/init.bash" ]]; then
    install -Dm644 "$source/init.bash" "$dest/init.bash"
  fi
  if [[ -d "$source/plugins" ]]; then
    rm -rf "$dest/plugins"
    cp -a "$source/plugins" "$dest/plugins"
  fi
  write_revision "$dest" "$source"
  printf '%s\n' "$CHANNEL" >"$dest/CHANNEL"
  printf '%s\n' "$(repo_url)" >"$dest/REPO"
}

write_bashrc_hook() {
  local dest=$1
  local bashrc="$HOME/.bashrc"
  local init="$dest/init.bash"
  local tmp
  [[ -f "$init" ]] || return 0
  mkdir -p "$(dirname -- "$bashrc")"
  [[ -f "$bashrc" ]] || : >"$bashrc"
  tmp=$(mktemp)
  if grep -qF '# >>> rebash >>>' "$bashrc"; then
    awk -v init="$init" '
      $0 == "# >>> rebash >>>" {
        print
        print "if [[ -f \"" init "\" ]]; then"
        print "  source \"" init "\""
        print "fi"
        skip=1
        next
      }
      $0 == "# <<< rebash <<<" { skip=0; print; next }
      skip { next }
      { print }
    ' "$bashrc" >"$tmp"
  else
    cat "$bashrc" >"$tmp"
    {
      printf '\n# >>> rebash >>>\n'
      printf 'if [[ -f "%s" ]]; then\n' "$init"
      printf '  source "%s"\n' "$init"
      printf 'fi\n'
      printf '# <<< rebash <<<\n'
    } >>"$tmp"
  fi
  mv "$tmp" "$bashrc"
}

remove_bashrc_hook() {
  local bashrc="$HOME/.bashrc"
  local tmp
  [[ -f "$bashrc" ]] || return 0
  grep -qF '# >>> rebash >>>' "$bashrc" || return 0
  tmp=$(mktemp)
  awk '
    $0 == "# >>> rebash >>>" { skip=1; next }
    $0 == "# <<< rebash <<<" { skip=0; next }
    skip { next }
    { print }
  ' "$bashrc" >"$tmp"
  mv "$tmp" "$bashrc"
}

uninstall() {
  local dest wrapper
  dest=$(data_path "$PREFIX")
  wrapper=$(destination_path "$PREFIX")
  remove_bashrc_hook
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

resolve_channel() {
  local dest
  dest=$(data_path "$PREFIX")
  if [[ -z $CHANNEL && $ACTION == update ]]; then
    CHANNEL=$(read_trimmed "$dest/CHANNEL" || true)
  fi
  CHANNEL=${CHANNEL:-main}
  valid_channel_name "$CHANNEL" || die "invalid channel: ${CHANNEL}"
}

install_rebash() {
  local source dest wrapper sha
  resolve_channel
  dest=$(data_path "$PREFIX")
  wrapper=$(destination_path "$PREFIX")

  if [[ $ACTION == update ]]; then
    [[ -x "$dest/bin/${BIN}" ]] || die "rebash is not installed at ${dest}; run install.sh first"
    if [[ -z ${REBASH_REPO:-} && -r "$dest/REPO" ]]; then
      REBASH_REPO=$(read_trimmed "$dest/REPO")
    fi
    source=$(sync_cache "$CHANNEL")
  else
    source=$(resolve_source)
  fi

  mkdir -p "$(dirname -- "$wrapper")" "$(dirname -- "$dest")"
  [[ -w "$(dirname -- "$wrapper")" ]] || die "cannot write to $(dirname -- "$wrapper"); choose another --prefix or rerun with write access"

  stage "$source" "$dest"
  write_wrapper "$dest" "$wrapper"
  write_bashrc_hook "$dest"

  [[ -x "$wrapper" ]] || die "failed to install ${wrapper}"
  warn_if_not_on_path "$(dirname -- "$wrapper")"
  sha=$(read_trimmed "$dest/REVISION" || true)
  if [[ $ACTION == update ]]; then
    if [[ -n $sha ]]; then
      printf 'updated %s %s\n' "$CHANNEL" "$sha"
    else
      printf 'updated %s\n' "$CHANNEL"
    fi
  else
    printf 'installed %s to %s\n' "$BIN" "$wrapper"
  fi
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
    install | update)
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
