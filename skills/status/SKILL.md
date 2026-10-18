---
description: Git Flow 상태와 미완료 절차 진단
disable-model-invocation: true
allowed-tools: [Bash]
---

# Status

현재 위치와 Git Flow 절차의 미완료 지점을 진단한다. **진단만 하고 고치지 않는다.**

## 실행 흐름

단계 1 → 3 순서로 실행한다. 단계를 건너뛰거나 병합하지 않는다.

---

## 단계 1: 사실 수집

```bash
git rev-parse --git-dir
git fetch --prune --tags 2>/dev/null

git branch --show-current
git status --porcelain
git branch -a --format='%(refname:short)'
git tag --sort=-creatordate | head -5
```

git repo가 아니면 중단한다. `fetch`가 실패해도 진단은 계속하되, **로컬 정보만으로 판단했음을 보고에 명시한다.**

---

## 단계 2: 진단

### 2-1. 현재 위치

브랜치명에서 타입을 읽는다. Git Flow 브랜치가 아니면 그 사실을 알린다.

### 2-2. 분기점이 올바른가

```bash
git merge-base --is-ancestor origin/main <branch>      # main 조상 여부
git merge-base --is-ancestor origin/develop <branch>   # develop 조상 여부
```

| 타입 | 올바른 분기점 |
|---|---|
| `feature/*`, `release/*` | `develop` |
| `hotfix/*` | `main` |

`hotfix`가 `develop`을 조상으로 가지면 **미출시 변경이 딸려 있을 수 있다.** 경고한다.

### 2-3. 미완료 back-merge

`main`에 있는데 `develop`에 없는 커밋을 찾는다. 이것이 back-merge 누락의 신호다.

```bash
git log origin/develop..origin/main --oneline
```

결과가 있으면 어떤 릴리스나 hotfix가 `develop`에 반영되지 않았는지 보고한다.

### 2-4. 태그가 main에 있는가

릴리스 태그는 `main` 커밋에만 붙어야 한다.

```bash
git branch -a --contains <태그> --format='%(refname:short)' | grep -x 'origin/main'
```

`main`이 포함하지 않는 릴리스 태그가 있으면 경고한다. "지금 운영에 무엇이 떠 있는가"의 기준점이 무너진 상태다.

### 2-5. 열린 Git Flow 브랜치

```bash
git branch -a --format='%(refname:short) %(committerdate:relative)' | grep -E '(feature|release|hotfix)/'
```

`release/*`가 둘 이상이면 알린다. 릴리스는 한 번에 하나가 원칙이다.

---

## 단계 3: 보고

```
현재 위치
  브랜치   release/v1.3.0  (release)
  분기점   develop  정상
  변경     커밋하지 않은 파일 없음

진단
  [경고] main에 있고 develop에 없는 커밋 2건
         a1b2c3d  Merge pull request #55 from hotfix/npe-on-login
         → hotfix/npe-on-login의 develop back-merge가 누락된 것으로 보입니다

  [정상] 릴리스 태그 5건 모두 main에 있음
  [정상] 열린 release 브랜치 1개

열린 브랜치
  release/v1.3.0    2시간 전
  feature/42-oauth  3일 전
```

이상이 없으면 간결하게 보고한다.

```
현재 위치
  브랜치   feature/42-oauth-login  (feature)
  분기점   develop  정상

진단
  이상 없음
```

**발견한 문제를 자동으로 고치지 않는다.** 수정은 사용자가 판단할 일이며, back-merge 누락은 `/git-flow:finish`로, 잘못 붙은 태그는 수동 정정으로 다룬다.

`fetch`에 실패했으면 마지막에 덧붙인다.

```
* 원격 조회에 실패해 로컬 정보만으로 진단했습니다.
```
