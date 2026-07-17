---
description: develop에서 release 브랜치 시작 (다음 버전 추론)
disable-model-invocation: true
allowed-tools: [Bash]
argument-hint: "[버전]"
---

# Release

`develop`에서 `release/<version>` 브랜치를 만든다. 인자가 없으면 마지막 릴리스 이후의 커밋을 분석해 다음 버전을 제안한다.

인자: `$ARGUMENTS`

## 실행 흐름

단계 1 → 5 순서로 실행한다. 단계를 건너뛰거나 병합하지 않는다.

---

## 단계 1: 사전 확인

```bash
git rev-parse --git-dir
git branch --show-current
git status --porcelain
git branch -a --format='%(refname:short)'
```

- git repo가 아니거나 `develop`이 없으면 중단한다.
- 커밋하지 않은 변경이 있으면 알리고 확인받는다.
- 이미 열린 `release/*` 브랜치가 있으면 알린다. 릴리스는 한 번에 하나가 원칙이다.
  ```bash
  git branch -a --format='%(refname:short)' | grep 'release/'
  ```

---

## 단계 2: 버전 결정

`$ARGUMENTS`가 있으면 그 값을 쓰고 단계 4로 간다. 형식이 SemVer가 아니면 알리고 확인받는다.

비어 있으면 추론한다.

### 2-1. 기준점 확보

```bash
git fetch --tags
git describe --tags --abbrev=0     # 마지막 릴리스 태그
```

태그가 하나도 없으면 **추론하지 않고 묻는다.**

```
릴리스 태그가 없어 다음 버전을 추론할 수 없습니다. 어떤 버전으로 시작할까요? (예: v1.0.0)
```

### 2-2. 커밋 수집

```bash
git log <마지막태그>..develop --pretty=format:'%s%n%b%n---'
```

### 2-3. 타입별 SemVer 영향 집계

[Conventional Commits](https://www.conventionalcommits.org/) 규격을 따른다.

| 감지 | 영향 |
|---|---|
| 제목에 `!`(예: `feat(api)!:`) 또는 본문·푸터에 `BREAKING CHANGE:` | MAJOR |
| `feat` | MINOR |
| `fix` · `perf` | PATCH |
| 그 외 (`docs`·`chore`·`refactor`·`style`·`test`·`build`·`ci`) | 없음 |

가장 높은 영향 하나가 다음 버전을 결정한다. MAJOR가 하나라도 있으면 MAJOR다.

**커밋 제목이 타입 접두어를 따르지 않으면 추론하지 않고 묻는다.** 추측한 값을 계산 결과처럼 제시하지 않는다.

```
커밋 제목에서 Conventional Commits 형식이 감지되지 않아 버전을 추론할 수 없습니다.
어떤 버전으로 릴리스할까요? (마지막 릴리스: v1.2.0)
```

### 2-4. 태그 prefix 관습 따르기

기존 태그가 `v1.2.0`이면 `v`를 붙이고, `1.2.0`이면 붙이지 않는다. 임의로 바꾸지 않는다.

---

## 단계 3: 제안·확인

계산 결과를 근거와 함께 보여주고 확인받는다.

```
마지막 릴리스: v1.2.0 (2026-06-30)
develop에 그 이후 커밋 14건:

  feat      3건  ← MINOR 사유
  fix       8건
  refactor  2건
  docs      1건

BREAKING CHANGE 없음

→ v1.3.0 을 제안합니다. 이걸로 진행할까요?
```

MAJOR인 경우 근거가 된 커밋을 명시한다.

```
  feat(api)!  1건  ← MAJOR 사유: 인증 헤더를 Authorization으로 변경
```

**사용자 확인 없이 다음 단계로 넘어가지 않는다.**

---

## 단계 4: 분기

```bash
git checkout develop
git pull origin develop
git checkout -b release/<version>
```

`git pull`이 실패하면 중단하고 원인을 보고한다.

---

## 단계 5: 결과 보고

```
release/v1.3.0 브랜치를 만들었습니다.

  분기점  develop (<SHA 7자리>)
  범위    v1.2.0..develop 커밋 14건

이 브랜치에서 할 일:
  - 버전 번호·메타데이터 확정
  - 막바지 버그 수정 (새 기능 추가 금지)
  - 검증 (test, build)

완료 후 /git-flow:finish 로 main 행 PR을 엽니다.
```

`release` 브랜치에는 **새 기능을 추가하지 않는다.** 이 브랜치가 열려 있는 동안 `develop`은 다음 릴리스 기능을 계속 받는다.
