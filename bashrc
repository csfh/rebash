# Rebash startup. Sourced by `rb` through --rcfile (interactive) and BASH_ENV
# (non-interactive).

if [[ ${REBASH:-0} == 1 ]]; then
  return 0 2>/dev/null || exit 0
fi

if [[ $- == *i* && ${REBASH_SKIP_USER_RC:-0} != 1 && -f "${HOME}/.bashrc" ]]; then
  # shellcheck disable=SC1090
  source "${HOME}/.bashrc"
fi

REBASH=1
export REBASH
export REBASH_ROOT="${REBASH_ROOT:-}"

rebash_load_plugs() {
  local list name file
  list="${XDG_CONFIG_HOME:-$HOME/.config}/rebash/plugs"
  [[ -r "$list" && -n ${REBASH_ROOT:-} ]] || return 0
  while IFS= read -r name || [[ -n $name ]]; do
    [[ -z $name || $name == \#* ]] && continue
    [[ $name =~ ^[A-Za-z][A-Za-z0-9_-]*$ ]] || continue
    file="$REBASH_ROOT/plugs/$name/plug.bash"
    if [[ -f "$file" ]]; then
      # shellcheck disable=SC1090
      source "$file"
    else
      printf 'rebash: plug %s is up but missing %s\n' "$name" "$file" >&2
    fi
  done <"$list"
}

rebash_load_plugs
