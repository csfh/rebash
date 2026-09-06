# Load enabled rebash plugins into the current bash. Safe to source from
# ~/.bashrc. Does not source the user's bashrc.

if [[ -z ${REBASH_ROOT:-} ]]; then
  REBASH_ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
fi
export REBASH_ROOT

rebash_load_plugins() {
  local list name file
  list="${XDG_CONFIG_HOME:-$HOME/.config}/rebash/plugins"
  [[ -r "$list" && -n ${REBASH_ROOT:-} ]] || return 0
  while IFS= read -r name || [[ -n $name ]]; do
    [[ -z $name || $name == \#* ]] && continue
    [[ $name =~ ^[A-Za-z][A-Za-z0-9_-]*$ ]] || continue
    file="$REBASH_ROOT/plugins/$name/plugin.bash"
    if [[ -f "$file" ]]; then
      # shellcheck disable=SC1090
      source "$file"
    else
      printf 'rebash: plugin %s is up but missing %s\n' "$name" "$file" >&2
    fi
  done <"$list"
}

if [[ ${REBASH_INIT:-0} != 1 ]]; then
  REBASH_INIT=1
  export REBASH_INIT
  rb() {
    command rb "$@"
    local status=$?
    if [[ $status -eq 0 && ${1:-} == up ]]; then
      rebash_load_plugins
    fi
    return "$status"
  }
fi

rebash_load_plugins
