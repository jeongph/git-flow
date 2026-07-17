---
name: git-flow
description: 'Use when working with Git Flow branches — deciding where to branch from, what merges where, when and where a release tag goes, or why a step was blocked. 사용자가 "브랜치 어디서 따지", "이거 hotfix야 feature야", "릴리스 어떻게 해", "태그 언제 붙여", "develop에 다시 머지해야 하나"라고 하거나, AI가 브랜치를 만들거나 릴리스·hotfix를 다룰 때 스스로 사용. 핵심 규율: main은 운영 상태의 단일 진실이며, 릴리스 태그는 머지된 main 커밋에만 붙는다.'
---

# Git Flow

Git Flow 브랜치 모델의 규율과 판단 기준이다. 어디서 분기하고, 무엇이 어디로 머지되며, 태그를 언제 어디에 붙이는지를 다룬다.

비유: 브랜치 이름은 *지금 무엇을 하는가*를 말한다. Git Flow는 거기에 *어디서 왔고 어디로 가는가*를 더한다 — 그 경로가 곧 릴리스 이력이 된다.

**원칙: `main`의 HEAD는 항상 운영에 배포 가능한 상태를 반영한다.** 아래 규칙 대부분이 이 한 전제에서 파생된다.

---

## 1. 브랜치 모델

| 브랜치 | 역할 | 분기 대상 | 머지 대상 |
|---|---|---|---|
| `main` | 운영 배포 상태를 반영. 릴리스 태그가 붙는다 | — | — |
| `develop` | 개발 통합 | `main` (최초 1회) | — |
| `feature/*` | 기능 개발 | `develop` | `develop` |
| `release/*` | 릴리스 준비 | `develop` | `main` **+** `develop` |
| `hotfix/*` | 운영 긴급 수정 | **`main`** | `main` **+** `develop` |

`main`·`develop`에 직접 커밋하지 않는다. 모든 변경은 `feature`·`release`·`hotfix`를 거친다.

## 2. 분기점이 결정적인 이유

`hotfix`가 `main`에서 분기하는 것은 취향이 아니라 필수다.

`develop`에는 아직 출시하지 않은 변경이 쌓여 있다. 거기서 분기해 `main`으로 머지하면 **긴급 수정과 함께 미출시 기능이 통째로 운영에 실려 나간다.** 운영 장애를 고치려다 더 큰 장애를 배포하는 경로가 이것이다.

`main`에서 분기하면 운영에 나가는 변경은 그 수정 하나뿐이다.

## 3. 완료 절차

### release / hotfix

원문이 규정하는 순서다.

```sh
# 1. main에 머지
git merge --no-ff release/v1.2.0

# 2. 머지된 그 커밋에 태그
git tag -a v1.2.0

# 3. develop으로 back-merge
git merge --no-ff release/v1.2.0
```

> "First, the release branch is merged into master... **Next**, that commit on master must be tagged for easy future reference to this historical version."
> — [A successful Git branching model](https://nvie.com/posts/a-successful-git-branching-model/)

**머지가 먼저, 태그가 나중이다.** 태그는 머지로 생긴 커밋을 가리킨다. 둘은 별개의 동작이며, 태그가 머지의 부산물로 자동 생성되지 않는다.

PR로 머지하는 경우 함정이 하나 있다. **머지 커밋은 원격에만 생긴다.** 로컬에서 `git pull` 없이 태그를 붙이면 이전 커밋에 붙는다.

```sh
git checkout main
git pull            # 이 줄이 빠지면 태그가 엉뚱한 커밋을 가리킨다
git tag -a v1.2.0
git push origin v1.2.0
```

### feature

`develop`으로 머지하면 끝이다. 태그도 back-merge도 없다.

## 4. back-merge를 빠뜨리면

`release`·`hotfix`는 **두 곳**으로 간다. `main`에만 머지하고 끝내면 그 변경이 `develop`에 없다.

| 빠뜨린 것 | 결과 |
|---|---|
| release → develop | 버전 번호 확정·막바지 수정이 유실. 다음 릴리스에서 되살아나거나 충돌 |
| hotfix → develop | 고친 버그가 다음 릴리스에서 부활 |

**hotfix 시점에 `release` 브랜치가 열려 있으면 back-merge 대상은 `develop`이 아니라 그 `release` 브랜치다.** 곧 나갈 릴리스가 수정을 품고 나가야 하며, `release`가 나중에 `develop`으로 back-merge되므로 결국 양쪽에 반영된다.

> "when a release branch currently exists, the hotfix changes need to be merged into that release branch, instead of develop"

## 5. 머지와 배포는 별개

`git merge`는 배포하지 않는다. 원문의 *"every commit on master is a new production release by definition"* 은 **정의상의 약속**이지 자동 배포 메커니즘이 아니다.

실제 배포는 CI/CD가 하며, 트리거는 팀이 정한다.

| 트리거 | 특성 |
|---|---|
| 태그 push (`v*`) | 배포 시점을 명시적으로 통제. `main`에 문서 수정이 들어가도 배포되지 않는다. 산출물이 태그와 1:1로 대응해 롤백 기준이 명확하다 |
| `main` push | 단순하지만 `main`의 모든 커밋이 배포로 이어진다 |

어느 쪽이든 **태그는 `main` 커밋에 붙는다**는 규칙은 유지된다. 태그는 운영에 나간 버전을 가리키는 참조이며, 그 대상은 언제나 `main`이다.

## 6. 판단 기준

### 이건 feature인가 hotfix인가

| 질문 | feature | hotfix |
|---|---|---|
| 지금 운영이 깨져 있는가 | 아니오 | 예 |
| 다음 정기 릴리스까지 기다릴 수 있는가 | 예 | 아니오 |
| 분기 대상 | `develop` | `main` |

기준은 긴급도가 아니라 **"운영에 지금 나가야 하는가"** 다. 급한 기능이어도 운영이 멀쩡하면 `feature`다.

### release 브랜치가 필요한가

`release` 브랜치의 존재 이유는 *버전 확정·막바지 수정을 하는 동안 `develop`이 다음 기능을 계속 받게 하는 것*이다.

확정할 버전 파일이 없고 막바지 수정도 없다면 `release` 브랜치는 빈 껍데기다. 생략하고 `develop` → `main` PR로 대신할 수 있다. **이때도 태그는 머지된 `main` 커밋에 붙는다.**

## 7. 강제의 한계

브랜치 규칙을 도구로 100% 막을 수는 없다. 로컬 git 명령은 언제든 우회 가능하다.

진짜 강제가 필요하면 호스팅의 브랜치 보호 규칙(GitHub ruleset 등)을 쓴다. 다만 **태그 대상 커밋이 어느 브랜치에 속하는지는 ruleset으로 강제할 수 없으므로**, 그 검증은 릴리스 파이프라인에서 한다.

## 8. 언제 스킵하나

Git Flow는 **정기 릴리스가 있고 여러 버전이 동시에 존재하는** 제품에 맞는 모델이다.

지속 배포(continuous deployment)하는 웹 서비스, 버전이 하나뿐이고 항상 최신만 쓰는 제품이라면 `develop`·`release` 층이 순수 오버헤드다. 이 경우 트렁크 기반 개발이 더 낫다 — 이 스킬의 규율을 억지로 적용하지 않는다.

## References

- [A successful Git branching model — Vincent Driessen](https://nvie.com/posts/a-successful-git-branching-model/) — 브랜치 모델 원문. 분기·머지 대상, 머지 → 태그 순서, hotfix의 release 우선 back-merge 규정
- [Conventional Commits 1.0.0](https://www.conventionalcommits.org/) — 커밋 타입과 SemVer 영향
- [GitHub Docs — Available rules for rulesets](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets/available-rules-for-rulesets) — 브랜치·태그 보호 규칙의 범위와 한계
