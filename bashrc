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
