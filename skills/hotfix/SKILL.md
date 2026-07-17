---
description: main에서 hotfix 브랜치 시작 (운영 긴급 수정)
disable-model-invocation: true
allowed-tools: [Bash, Read, Glob, Grep]
argument-hint: "[이슈명 | 이슈번호]"
---

# Hotfix

**`main`**에서 `hotfix/<name>` 브랜치를 만든다. 운영에서 발견된 문제를 즉시 고치는 계획 외 릴리스다.

인자: `$ARGUMENTS`

## 실행 흐름

단계 1 → 5 순서로 실행한다. 단계를 건너뛰거나 병합하지 않는다.

---

## 단계 1: 사전 확인

```bash
git rev-parse --git-dir
git branch --show-current
git status --porcelain
```

- git repo가 아니면 중단한다.
- 커밋하지 않은 변경이 있으면 알리고 확인받는다.

### hotfix가 맞는지 먼저 판단한다

| 질문 | feature | hotfix |
|---|---|---|
| 지금 운영이 깨져 있는가 | 아니오 | 예 |
| 다음 정기 릴리스까지 기다릴 수 있는가 | 예 | 아니오 |

기준은 긴급도가 아니라 **"운영에 지금 나가야 하는가"** 다. 급한 기능이어도 운영이 멀쩡하면 `feature`다. 판단이 서지 않으면 사용자에게 확인한다.

---

## 단계 2: 작업 대상 결정

`$ARGUMENTS`가 있으면 그것을 쓴다. 숫자만 있으면 이슈 번호로 해석한다.

비어 있으면 `feature`와 같은 순서로 감지한다.

1. CLAUDE.md에 작업 관리 방식이 명시되어 있으면 그것
2. `gh`가 있으면 열린 이슈 (기본값)
3. repo의 작업 파일
4. 없으면 직접 묻는다

```
어떤 문제를 고칠까요?
```

---

## 단계 3: 버전 제안

hotfix는 계획 외 릴리스이므로 PATCH를 올린다.

```bash
git fetch --tags
git describe --tags --abbrev=0     # 예: v1.2.0 → v1.2.1
```

태그가 없으면 버전을 묻지 않고 넘어간다. 태그 없는 repo라면 `finish` 단계에서 다시 판단한다.

버전은 브랜치명이 아니라 **완료 시점의 태그**에 쓰인다. 브랜치명은 문제를 가리킨다.

```
hotfix/npe-on-login       ← 문제를 가리킨다
hotfix/v1.2.1             ← 지양. 버전은 태그의 몫이다
```

---

## 단계 4: main에서 분기

```bash
git checkout main
git pull origin main
git checkout -b hotfix/<name>
```

**`develop`이 아니라 `main`에서 분기한다.** 이것은 취향이 아니라 필수다.

`develop`에는 아직 출시하지 않은 변경이 쌓여 있다. 거기서 분기해 `main`으로 머지하면 긴급 수정과 함께 **미출시 기능이 통째로 운영에 실려 나간다.** 운영 장애를 고치려다 더 큰 장애를 배포하는 경로가 이것이다.

`git pull`이 실패하면 중단한다. 오래된 로컬 `main`에서 분기하면 이미 배포된 다른 수정을 되돌릴 수 있다.

---

## 단계 5: 결과 보고

분기점이 `main`임을 명시적으로 보여준다.

```
hotfix/npe-on-login 브랜치를 만들었습니다.

  분기점  main (<SHA 7자리>)   ← develop 아님
  현재 운영  v1.2.0
  예상 태그  v1.2.1

수정 후 /git-flow:finish 로 main 행 PR을 엽니다.
```

태그가 없는 repo면 `현재 운영`·`예상 태그` 줄을 생략한다.
