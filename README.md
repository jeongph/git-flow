# git-flow

[![version](https://img.shields.io/github/v/release/jeongph/git-flow?label=version&color=blue)](https://github.com/jeongph/git-flow/releases)
[![license](https://img.shields.io/github/license/jeongph/git-flow?color=lightgrey)](LICENSE)

Git Flow에 따라 브랜치를 만들고 PR로 병합합니다. 잘못된 분기나 태그 생성도 확인합니다.

브랜치 종류에 맞는 기준 브랜치에서 작업을 시작하고, 커밋을 분석해 다음 버전을 제안합니다. 릴리스 완료 절차를 단계별로 진행하며, 브랜치 규칙을 위반하는 명령을 차단합니다.

[English](README.en.md)

## 개념

**Git Flow**는 Vincent Driessen이 2010년 제안한 브랜치 모델입니다. `main`, `develop`, `feature`, `release`, `hotfix`로 역할을 나눠 정기 릴리스와 긴급 수정의 경로를 분리합니다.

원래의 `git flow` CLI는 두 구현체(`nvie/gitflow`, `gitflow-avh`) 모두 아카이브되었습니다. 또한 로컬에서 직접 머지(`git merge --no-ff`)하는 방식이라 PR 리뷰 단계가 없습니다.

이 플러그인은 브랜치 모델, 태그 규칙, back-merge 규칙을 원문 그대로 지키면서 **반영 수단만 PR로 바꿉니다**.

### 방지하려는 실수

Git Flow의 완료 절차는 병합, 태그 생성, `develop`에 변경 반영 등 여러 단계로 이루어집니다. 순서를 빠뜨리거나 잘못 진행하면 다음과 같은 문제가 생길 수 있습니다.

| 흔한 실수 | 결과 |
|---|---|
| `git pull` 없이 태그 생성 | 태그가 이전 커밋을 가리킨다 |
| release를 `main`에만 머지 | 버전 확정과 막바지 수정이 `develop`에서 유실 |
| hotfix를 `develop`에서 분기 | 미출시 기능이 운영에 함께 배포 |
| `--squash` 머지 | 릴리스와 hotfix 경계가 히스토리에서 소실 |

이 플러그인은 절차를 실행하고, 위 네 가지를 훅으로 차단합니다.

## 설치

```sh
/plugin marketplace add jeongph/claude-plugins
/plugin install git-flow@jeongph-claude-plugins
```

설치 후 `/reload-plugins` 또는 Claude Code 재시작으로 활성화됩니다.

**요구사항**: `git`, [`gh`](https://cli.github.com/) (GitHub CLI, 인증 완료 상태), `main`과 `develop` 브랜치가 있는 저장소.

## 컴포넌트

| 종류 | 이름 | 역할 |
|------|------|------|
| 명령 | `/git-flow:feature [name]` | `develop`에서 feature 브랜치 시작. 인자 없으면 작업 목록에서 선택 |
| 명령 | `/git-flow:release [version]` | `develop`에서 release 브랜치 시작. 인자 없으면 다음 버전 추론 |
| 명령 | `/git-flow:hotfix [name]` | **`main`에서** hotfix 브랜치 시작 |
| 명령 | `/git-flow:finish` | 현재 상태를 확인해 다음 단계로 진행. 완료한 단계는 건너뜀 |
| 명령 | `/git-flow:status` | 현재 위치와 미완료 back-merge 진단 |
| 지식 | `git-flow` | 브랜치 모델 규칙. 분기점, 태그, back-merge 판단 기준 (자동 로드) |
| 훅 | `PreToolUse (Bash 트리거)` | 모델 위반 차단 |

## 사용 예

### 기능 개발 시작

```
/git-flow:feature
```

인자 없이 실행하면 이 저장소의 작업 목록에서 고릅니다. 작업 관리 도구는 프로젝트마다 달라서 자동으로 감지합니다. CLAUDE.md에 적힌 방식이 있으면 그것을, 없으면 GitHub 이슈를, 그것도 없으면 저장소의 작업 파일(`docs/tasks.md` 등)을 씁니다.

```
진행할 작업을 고르세요:

  #42  [Feature] OAuth 로그인 지원
  #47  [Bug] 자정 넘어가면 집계 누락

→ feature/42-oauth-login으로 분기합니다
```

이슈 번호가 브랜치명에 들어가면 PR 본문의 `Closes #42`가 자동으로 채워집니다.

브랜치명을 직접 지정할 수도 있습니다.

```
/git-flow:feature oauth-login
```

### 릴리스 시작과 버전 추론

```
/git-flow:release
```

마지막 릴리스 태그 이후의 커밋을 [Conventional Commits](https://www.conventionalcommits.org/) 규격으로 분석해 다음 버전을 계산합니다.

```
마지막 릴리스: v1.2.0 (2026-06-30)
develop에 그 이후 커밋 14건:

  feat      3건  ← MINOR 사유
  fix       8건
  refactor  2건
  docs      1건

BREAKING CHANGE 없음

→ v1.3.0을 제안합니다. 이걸로 진행할까요?
```

커밋 컨벤션이 감지되지 않거나 태그가 없으면 **추론하지 않고 묻습니다.** 추측한 값을 계산 결과처럼 제시하지 않습니다.

### 단계별 완료

```
/git-flow:finish
```

현재 브랜치의 종류와 상태를 확인해 다음 단계 하나를 진행합니다. 태그는 머지된 `main` 커밋에 붙어야 하는데 머지는 리뷰와 CI를 거치므로 한 번에 끝나지 않습니다.

| 상태 | 동작 |
|---|---|
| PR 없음 | PR 생성 후 멈춤 (리뷰와 CI는 사람의 몫) |
| PR 열림 | 상태만 보고 |
| PR 머지됨 | `git pull` 후 머지 커밋에 태그 제안 |
| 태그 완료 | back-merge PR 생성 |

같은 명령을 다시 실행하면 완료한 단계는 건너뛰고 현재 상태에 맞는 절차를 진행합니다.

### 진단

```
/git-flow:status
```

```
현재 위치
  브랜치   release/v1.3.0  (release)
  분기점   develop  정상

진단
  [경고] main에 있고 develop에 없는 커밋 2건
         → hotfix/npe-on-login의 back-merge 누락으로 보입니다
```

진단만 하고 고치지 않습니다.

### 위반 차단

슬래시 명령을 거치지 않고 Bash 도구로 Git을 직접 실행해도 훅이 검사합니다.

```
$ git tag -a v1.3.0        # release/v1.3.0 브랜치에서

[git-flow] release/v1.3.0에서 릴리스 태그를 만들 수 없다.

릴리스 태그는 머지된 main 커밋에만 붙는다. main은 '지금 운영에 무엇이 떠 있는가'를
알려 주는 유일한 기준이다. 여기가 어긋나면 롤백 기준점과 hotfix 분기점이 함께 무너진다.

  git checkout main && git pull    # 머지 커밋을 받아온 뒤
  git tag -a <버전>                 # 그 커밋에 붙인다
```

차단 대상은 네 가지입니다.

- `main`과 `develop`에 직접 커밋
- `--squash` 머지
- `develop`에서 hotfix 분기
- `main`이 아닌 커밋에 릴리스 태그

**끄기**: 초기 셋업이나 잘못 붙은 태그를 고칠 때처럼 훅을 꺼야 하는 경우도 있습니다.

```sh
GIT_FLOW_GUARD=off git commit -m "..."
```

**한계**: 훅은 Bash 명령 문자열을 검사합니다. 실수를 막는 도구이지 권한 통제 수단이 아닙니다. 강제가 필요하면 [브랜치 보호 규칙](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets/available-rules-for-rulesets)을 함께 쓰십시오.

## 적용 대상

Git Flow는 **정기 릴리스가 있고 여러 버전이 동시에 존재하는** 제품에 맞는 모델입니다.

지속 배포하는 웹 서비스나 항상 최신 버전만 쓰는 제품이라면 `develop`과 `release` 층이 오버헤드입니다. 이런 프로젝트에서는 트렁크 기반 개발을 검토할 수 있습니다. 이 플러그인은 Git Flow 절차가 필요한 프로젝트를 대상으로 합니다.

## References

- [A successful Git branching model — Vincent Driessen](https://nvie.com/posts/a-successful-git-branching-model/)
- [Conventional Commits 1.0.0](https://www.conventionalcommits.org/)

## 라이선스

MIT ([LICENSE](LICENSE) 참조)
