#!/usr/bin/env bash
# Git Flow 위반을 차단한다 (PreToolUse, matcher: Bash).
#
# 판정은 결정론적으로 확인 가능한 것만 한다. exit 2로 도구 호출을 차단하고
# stderr로 이유와 우회 방법을 전달한다.
#
# 한계: Bash 명령 문자열을 정규식으로 본다. 실수를 막는 도구이지 권한 통제가
# 아니다. 진짜 강제가 필요하면 호스팅 서비스의 브랜치 보호 규칙을 쓴다.
set -uo pipefail

# GIT_FLOW_GUARD=off로 전체를 끈다
[ "${GIT_FLOW_GUARD:-on}" = "off" ] && exit 0

INPUT=$(cat)

# stdin JSON에서 필드 추출: jq가 있으면 jq, 없으면 grep/sed로 폴백
json_get() {
  local path="$1" key="${1##*.}"
  if command -v jq >/dev/null 2>&1; then
    printf '%s' "$INPUT" | jq -r "$path // empty" 2>/dev/null
  else
    printf '%s' "$INPUT" \
      | grep -o "\"${key}\"[[:space:]]*:[[:space:]]*\"[^\"]*\"" \
      | head -1 \
      | sed -e "s/\"${key}\"[[:space:]]*:[[:space:]]*\"//" -e 's/"$//'
  fi
}

COMMAND=$(json_get '.tool_input.command')
CWD=$(json_get '.cwd')

[ -z "$COMMAND" ] && exit 0

# 다른 repo를 대상으로 하면 현재 브랜치로 판단할 수 없으므로 통과시킨다
case "$COMMAND" in
  *"git -C"*|*"--git-dir"*|*"--work-tree"*) exit 0 ;;
esac

# git repo가 아니면 대상이 아니다
[ -n "$CWD" ] && cd "$CWD" 2>/dev/null
git rev-parse --git-dir >/dev/null 2>&1 || exit 0

BRANCH=$(git branch --show-current 2>/dev/null) || exit 0
[ -z "$BRANCH" ] && exit 0   # detached HEAD

deny() {
  printf '%s\n' "$1" >&2
  printf '\n우회가 필요하면 GIT_FLOW_GUARD=off를 설정하거나 사용자에게 확인받는다.\n' >&2
  exit 2
}

# ── 1. main·develop 직접 커밋 ────────────────────────────────
if [[ "$COMMAND" =~ git[[:space:]]+(commit|cherry-pick|revert)([[:space:]]|$) ]]; then
  if [ "$BRANCH" = "main" ] || [ "$BRANCH" = "develop" ]; then
    deny "[git-flow] ${BRANCH} 브랜치에 직접 커밋할 수 없다.

Git Flow에서 모든 변경은 feature, release, hotfix 브랜치를 거쳐 PR로 들어온다.
  /git-flow:feature   기능 개발 (develop에서 분기)
  /git-flow:hotfix    운영 긴급 수정 (main에서 분기)"
  fi
fi

# ── 2. squash 머지 ───────────────────────────────────────────
if [[ "$COMMAND" =~ (git[[:space:]]+merge|gh[[:space:]]+pr[[:space:]]+merge) ]] \
   && [[ "$COMMAND" =~ --squash ]]; then
  deny "[git-flow] squash 머지는 브랜치 단위 작업 묶음을 없앤다.

릴리스와 hotfix의 경계가 히스토리에서 사라져 '어느 릴리스에 무엇이 들어갔는지'를
추적할 수 없게 된다. --merge를 쓴다 (머지 커밋 보존).
  gh pr merge <번호> --merge --delete-branch"
fi

# ── 3. develop에서 hotfix 분기 ───────────────────────────────
if [[ "$COMMAND" =~ git[[:space:]]+(checkout[[:space:]]+-b|switch[[:space:]]+-c)[[:space:]]+hotfix/ ]]; then
  # 분기 대상이 명시되어 있으면(git checkout -b hotfix/x main) 그것을 따르므로 통과
  if ! [[ "$COMMAND" =~ hotfix/[^[:space:]]+[[:space:]]+(origin/)?main ]]; then
    if [ "$BRANCH" = "develop" ]; then
      deny "[git-flow] hotfix를 develop에서 분기할 수 없다.

develop에는 아직 출시하지 않은 변경이 쌓여 있다. 여기서 분기해 main으로 머지하면
긴급 수정과 함께 미출시 기능이 통째로 운영에 실려 나간다.

  git checkout main && git pull && git checkout -b hotfix/<name>
  또는 /git-flow:hotfix"
    fi
  fi
fi

# ── 4. main이 아닌 커밋에 릴리스 태그 ────────────────────────
if [[ "$COMMAND" =~ git[[:space:]]+tag([[:space:]]|$) ]] \
   && [[ "$COMMAND" =~ v?[0-9]+\.[0-9]+ ]] \
   && ! [[ "$COMMAND" =~ [[:space:]]-(d|-delete|l|-list|n[0-9]*)([[:space:]]|$) ]]; then
  if [ "$BRANCH" != "main" ]; then
    deny "[git-flow] ${BRANCH}에서 릴리스 태그를 만들 수 없다.

릴리스 태그는 머지된 main 커밋에만 붙는다. main은 '지금 운영에 무엇이 떠 있는가'를
알려 주는 유일한 기준이다. 여기가 어긋나면 롤백 기준점과 hotfix 분기점이 함께 무너진다.

  git checkout main && git pull    # 머지 커밋을 받아온 뒤
  git tag -a <버전>                 # 그 커밋에 붙인다"
  fi
fi

exit 0
