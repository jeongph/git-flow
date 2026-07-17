---
description: 현재 브랜치의 Git Flow 절차를 다음 단계로 진행
disable-model-invocation: true
allowed-tools: [Bash]
---

# Finish

현재 브랜치의 타입과 진행 상태를 읽어 **다음 한 걸음만** 딛는다.

release·hotfix의 완료는 한 번에 끝나지 않는다. 태그는 머지된 `main` 커밋에 붙어야 하는데, 머지는 리뷰·CI를 거치므로 그 사이에 시간이 흐른다. 그래서 이 스킬은 **멱등적**이다 — 몇 번을 호출해도 안전하며, 이미 끝난 단계는 건너뛴다.

## 실행 흐름

단계 1 → 4 순서로 실행한다. 단계를 건너뛰거나 병합하지 않는다.

---

## 단계 1: 브랜치 타입 감지

```bash
git branch --show-current
```

| 브랜치 | 타입 |
|---|---|
| `feature/*` | feature |
| `release/*` | release |
| `hotfix/*` | hotfix |
| `main` · `develop` | **중단** |
| 그 외 | **중단** |

`main`·`develop`에 서 있거나 Git Flow 브랜치가 아니면 중단하고 알린다. 임의로 브랜치를 만들지 않는다.

```
현재 main 브랜치입니다. finish는 feature·release·hotfix 브랜치에서 실행합니다.
```

---

## 단계 2: 현재 상태 감지

```bash
git status --porcelain                    # 미커밋 변경
git log origin/<branch>..<branch> --oneline 2>/dev/null   # 미푸시 커밋
gh pr list --head <branch> --state all --json number,state,baseRefName,mergedAt,mergeCommit,url
```

미커밋 변경이 있으면 **먼저 알리고 확인받는다.** 임의로 커밋하지 않는다.

```
커밋하지 않은 변경이 3건 있습니다. 커밋 후 다시 실행하거나, 이대로 PR을 열까요?
```

---

## 단계 3: 다음 한 걸음

### feature

| 감지한 상태 | 다음 한 걸음 |
|---|---|
| develop 행 PR 없음 | PR 생성 (base=`develop`) → **멈춘다** |
| PR 열려 있음 | 상태만 보고. 머지하지 않는다 |
| PR 머지됨 | 완료 보고 (태그·back-merge 없음) |

### release · hotfix

| 감지한 상태 | 다음 한 걸음 |
|---|---|
| main 행 PR 없음 | PR 생성 (base=`main`) → **멈춘다** |
| PR 열려 있음 | 상태만 보고 (CI·리뷰 대기). 머지하지 않는다 |
| PR 머지됨 + 태그 없음 | `git pull` → 머지 커밋 확인 → 태그 생성·push **제안** |
| 태그 있음 + back-merge PR 없음 | back-merge PR 생성 |
| back-merge 머지됨 | 완료 보고 |

---

### 3-A. PR 생성

```bash
git push -u origin <branch>
gh pr create --base <base> --head <branch> --title "<제목>" --body "<본문>"
```

base는 타입이 정한다. **임의로 바꾸지 않는다.**

| 타입 | base |
|---|---|
| feature | `develop` |
| release · hotfix | `main` |

브랜치명에 이슈 번호가 있으면(`feature/42-oauth-login`) 본문에 연결한다.

```
Closes #42
```

PR을 만들고 **멈춘다.** 리뷰·CI는 사람의 몫이다. 이어서 머지하지 않는다.

---

### 3-B. PR 열려 있음

상태만 보고한다.

```bash
gh pr checks <번호> 2>/dev/null
gh pr view <번호> --json reviewDecision,mergeable
```

```
PR #58 이 열려 있습니다 (release/v1.3.0 → main)

  CI      통과
  리뷰    대기 중
  머지    가능

머지되면 /git-flow:finish 를 다시 실행해 태그를 붙입니다.
```

**머지하지 않는다.** 사용자가 명시적으로 머지를 지시하면 그때 수행하며, 이때도 `--squash`는 쓰지 않는다.

```bash
gh pr merge <번호> --merge --delete-branch
```

`--squash`는 브랜치 단위 작업 묶음을 없애 릴리스·hotfix의 경계를 추적할 수 없게 만든다.

---

### 3-C. PR 머지됨 + 태그 없음 (release · hotfix)

**머지 커밋은 원격에만 있다. `git pull` 없이 태그를 붙이면 이전 커밋을 가리킨다.**

```bash
git checkout main
git pull origin main
git log -1 --format='%H %s'          # 머지 커밋 확인
git tag --points-at HEAD             # 이미 태그가 있는지
```

태그 값을 결정한다.

- release: 브랜치명의 버전 (`release/v1.3.0` → `v1.3.0`)
- hotfix: 마지막 태그의 PATCH를 올린 값 (`v1.2.0` → `v1.2.1`)
- 태그 prefix는 기존 관습을 따른다 (`v1.2.0` ↔ `1.2.0`)

HEAD가 `main`이고 머지 커밋이 맞는지 확인한 뒤 **제안**한다.

```
PR #58 이 머지되었습니다.

  main HEAD   a1b2c3d  Merge pull request #58 from release/v1.3.0
  붙일 태그   v1.3.0

이 커밋에 태그를 붙이고 push할까요?
```

확인받은 뒤 실행한다.

```bash
git tag -a v1.3.0 -m "v1.3.0"
git push origin v1.3.0
```

**확인 없이 태그를 push하지 않는다.** 태그 push는 배포 파이프라인을 트리거할 수 있다.

---

### 3-D. 태그 있음 + back-merge PR 없음 (release · hotfix)

`release`·`hotfix`는 **두 곳**으로 간다. `main`에만 머지하고 끝내면 그 변경이 `develop`에 없다.

| 빠뜨린 것 | 결과 |
|---|---|
| release → develop | 버전 확정·막바지 수정 유실 |
| hotfix → develop | 고친 버그가 다음 릴리스에서 부활 |

back-merge 대상을 정한다.

```bash
git branch -a --format='%(refname:short)' | grep 'release/'
```

| 조건 | back-merge 대상 |
|---|---|
| hotfix이고, 열린 `release/*` 브랜치가 있음 | **그 release 브랜치** |
| 그 외 | `develop` |

곧 나갈 릴리스가 수정을 품고 나가야 하기 때문이다. `release`가 나중에 `develop`으로 back-merge되므로 결국 양쪽에 반영된다.

```bash
gh pr create --base <대상> --head <branch> --title "<제목>" --body "<본문>"
```

브랜치가 이미 삭제되었으면(머지 시 `--delete-branch`) 태그에서 되살린다.

```bash
git checkout -b <branch> <태그>
git push -u origin <branch>
```

---

## 단계 4: 결과 보고

무엇을 했고 다음이 무엇인지 항상 함께 보고한다.

```
release/v1.3.0 → main PR #58 을 열었습니다.

  https://github.com/<owner>/<repo>/pull/58

다음: 리뷰·CI 통과 후 머지 → /git-flow:finish 재실행 (태그)
```

완료 시:

```
릴리스 v1.3.0 완료

  main      a1b2c3d  태그 v1.3.0
  develop   PR #59 머지됨 (back-merge)

배포는 CI/CD의 몫입니다. 태그 트리거를 쓴다면 v1.3.0 push로 시작됩니다.
```
