# Git plug: bash aliases for everyday git.

if [[ ${REBASH_PLUG_GIT:-0} == 1 ]]; then
  return 0 2>/dev/null || exit 0
fi
REBASH_PLUG_GIT=1

alias g='git'

alias ga='git add'
alias gaa='git add -A'
alias gap='git add -p'
alias gav='git add -v'

alias gb='git branch'
alias gba='git branch -a'
alias gbd='git branch -d'
alias gbD='git branch -D'
alias gbm='git branch -m'
alias gbr='git branch -r'

alias gc='git commit'
alias gcm='git commit -m'
alias gca='git commit --amend'
alias gcan='git commit --amend --no-edit'
alias gcam='git commit -a -m'

alias gco='git checkout'
alias gcb='git checkout -b'
alias gcl='git clone'
alias gcp='git cherry-pick'

alias gd='git diff'
alias gds='git diff --staged'
alias gdw='git diff --word-diff'

alias gf='git fetch'
alias gfa='git fetch --all --prune'

alias gl='git log --oneline --decorate --graph'
alias gll='git log --oneline'
alias glg='git log --graph --decorate --all'

alias gm='git merge'
alias gmt='git mergetool'

alias gp='git push'
alias gpf='git push --force-with-lease'
alias gpu='git push -u origin HEAD'
alias gpl='git pull'
alias gplr='git pull --rebase'

alias gr='git remote'
alias grv='git remote -v'
alias grb='git rebase'
alias grbi='git rebase -i'
alias grbc='git rebase --continue'
alias grba='git rebase --abort'
alias grbs='git rebase --skip'
alias grm='git rm'
alias grs='git reset'
alias grsh='git reset --hard'
alias grst='git restore'
alias grss='git restore --staged'

alias gs='git status'
alias gss='git status -s'
alias gsh='git show'

alias gst='git stash'
alias gstp='git stash pop'
alias gstl='git stash list'
alias gsta='git stash apply'

alias gsw='git switch'
alias gswc='git switch -c'

alias gt='git tag'
alias gmv='git mv'
alias gundo='git reset --soft HEAD~1'
alias gwho='git shortlog -sn'

rebash_git_default_branch() {
  local ref
  ref=$(git symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null) || true
  if [[ -n $ref ]]; then
    printf '%s\n' "${ref#origin/}"
    return 0
  fi
  if git show-ref --verify --quiet refs/heads/main; then
    printf 'main\n'
    return 0
  fi
  if git show-ref --verify --quiet refs/heads/master; then
    printf 'master\n'
    return 0
  fi
  return 1
}

gcom() {
  git checkout "$(rebash_git_default_branch)"
}

gswm() {
  git switch "$(rebash_git_default_branch)"
}

gwip() {
  git add -A && git commit -m 'wip'
}
