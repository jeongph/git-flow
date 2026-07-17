---
description: develop에서 feature 브랜치 시작
disable-model-invocation: true
allowed-tools: [Bash, Read, Glob, Grep]
argument-hint: "[브랜치명 | 이슈번호]"
---

# Feature

`develop`에서 `feature/<name>` 브랜치를 만든다. 인자가 없으면 이 repo의 작업 목록에서 고른다.

인자: `$ARGUMENTS`

## 실행 흐름

단계 1 → 5 순서로 실행한다. 단계를 건너뛰거나 병합하지 않는다.

---

## 단계 1: 사전 확인

```bash
git rev-parse --git-dir                    # git repo인가
git branch --show-current                  # 현재 브랜치
git status --porcelain                     # 작업 트리 상태
git branch -a --format='%(refname:short)'  # develop 존재 확인
```

- git repo가 아니면 중단한다.
- `develop`이 없으면 중단하고 알린다. 이 플러그인은 Git Flow 모델을 전제한다. `develop`이 없는 트렁크 기반 repo라면 이 플러그인이 맞지 않는다.
- 커밋하지 않은 변경이 있으면 **분기 전에** 알리고 확인받는다. 임의로 stash하거나 커밋하지 않는다.

---

## 단계 2: 작업 대상 결정

`$ARGUMENTS`가 있으면 그것을 쓰고 단계 3으로 간다.

- 숫자만 있으면(`42`) 이슈 번호로 해석한다.
- 그 외는 브랜치명으로 해석한다.

비어 있으면 이 repo의 작업 목록에서 고른다. **작업 관리 도구는 프로젝트마다 다르므로 아래 순서로 감지한다.**

1. **CLAUDE.md에 작업 관리 방식이 명시되어 있으면 그것을 따른다.** 팀이 명시적으로 정한 것이므로 추측보다 우선한다.
2. `gh`가 있고 열린 이슈가 있으면 GitHub 이슈를 쓴다 (기본값).
   ```bash
   gh issue list --state open --limit 20
   ```
3. repo에 작업 파일이 있으면 그것을 쓴다 (`docs/tasks.md`·`TODO.md`·`docs/todo/` 등).
4. 아무것도 없으면 사용자에게 직접 묻는다.

```
어떤 작업을 시작할까요?
```

3번으로 감지한 경우 **단정하지 않는다.** 파일이 존재한다고 그것이 작업 목록이라는 보장이 없다.

```
docs/tasks.md 를 작업 목록으로 봤습니다. 맞나요?
```

목록을 제시하고 사용자가 고르게 한다. 임의로 하나를 선택하지 않는다.

---

## 단계 3: 브랜치명 확정

이슈에서 왔으면 번호를 앞에 붙인다. 나중에 PR 본문의 `Closes #<번호>`를 채우는 근거가 된다.

```
feature/42-oauth-login
```

브랜치명 규칙:

- 소문자, 공백은 `-`로
- 한글 제목은 영문으로 옮긴다 (브랜치명은 코드에 준한다)
- 이미 존재하는 브랜치명이면 알리고 다시 묻는다
  ```bash
  git branch -a --format='%(refname:short)' | grep -x 'feature/<name>'
  ```

확정 전 사용자에게 보여주고 확인받는다.

---

## 단계 4: 분기

```bash
git checkout develop
git pull origin develop
git checkout -b feature/<name>
```

`develop`을 반드시 최신화한 뒤 분기한다. 최신화하지 않으면 오래된 기준점에서 갈라져 나중에 불필요한 충돌이 난다.

`git pull`이 실패하면(원격 없음·네트워크 오류) 중단하고 원인을 보고한다. 로컬 `develop`으로 조용히 진행하지 않는다.

---

## 단계 5: 결과 보고

```
feature/42-oauth-login 브랜치를 만들었습니다.

  분기점  develop (<SHA 7자리>)
  이슈    #42 OAuth 로그인 지원

작업 후 /git-flow:finish 로 develop 행 PR을 엽니다.
```

이슈 없이 시작했으면 이슈 줄을 생략한다.
