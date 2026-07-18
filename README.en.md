# git-flow

A Claude Code plugin that automates the **Git Flow branching model over pull requests**.

Once installed — branches start from the correct base, the next version is computed from your commits and proposed, release completion advances step by step, and commands that break the model are blocked.

[한국어](README.md)

## Concept

**Git Flow** is the branching model Vincent Driessen proposed in 2010. It separates `main`, `develop`, `feature`, `release`, and `hotfix` so that scheduled releases and emergency fixes travel different paths.

The original `git flow` CLI (`nvie/gitflow`, `gitflow-avh`) is archived in both implementations, and it assumes local direct merges (`git merge --no-ff`) with no pull request review step.

This plugin **keeps the branching model, tagging rules, and back-merge rules exactly as the original defines them, while implementing the integration path as pull requests**.

### Why this exists

In Git Flow, mistakes rarely happen when you *create* a branch. They happen when you *finish* one. Completion is multi-step, order-dependent, and hard to undo.

| Common mistake | Consequence |
|---|---|
| Tagging without `git pull` first | The tag points at the previous commit |
| Merging a release into `main` only | Version bumps and last-minute fixes are lost from `develop` |
| Branching a hotfix off `develop` | Unreleased features ship to production alongside the fix |
| Merging with `--squash` | Release and hotfix boundaries vanish from history |

This plugin runs the procedure and blocks those four with hooks.

## Install

```sh
/plugin marketplace add jeongph/claude-plugins
/plugin install git-flow@jeongph-claude-plugins
```

Run `/reload-plugins` or restart Claude Code to activate.

**Requirements** — `git`, [`gh`](https://cli.github.com/) (GitHub CLI, authenticated), and a repository with `main` and `develop` branches.

## Components

| Type | Name | Role |
|------|------|------|
| Command | `/git-flow:feature [name]` | Start a feature branch from `develop`. Picks from your task list when no argument is given |
| Command | `/git-flow:release [version]` | Start a release branch from `develop`. Infers the next version when no argument is given |
| Command | `/git-flow:hotfix [name]` | Start a hotfix branch from **`main`** |
| Command | `/git-flow:finish` | Advance the current branch to its next step (idempotent) |
| Command | `/git-flow:status` | Diagnose current position and missing back-merges |
| Skill | `git-flow` | Branching model discipline — base, tagging, and back-merge judgment (auto-loaded) |
| Hook | `PreToolUse (Bash matcher)` | Blocks violations of the model |

## Usage

### Start a feature

```
/git-flow:feature
```

With no argument, it picks from this repository's task list. Task tooling differs per project, so it detects: whatever CLAUDE.md specifies takes priority, otherwise GitHub issues, otherwise a task file in the repo (`docs/tasks.md` and friends).

```
Pick a task to start:

  #42  [Feature] OAuth login support
  #47  [Bug] Aggregation drops rows across midnight

→ branching as feature/42-oauth-login
```

When the branch name carries an issue number, `Closes #42` is filled into the pull request body automatically.

You can name the branch directly instead:

```
/git-flow:feature oauth-login
```

### Start a release — version inference

```
/git-flow:release
```

Commits since the last release tag are analyzed against the [Conventional Commits](https://www.conventionalcommits.org/) spec to compute the next version.

```
Last release: v1.2.0 (2026-06-30)
14 commits on develop since then:

  feat      3  ← MINOR trigger
  fix       8
  refactor  2
  docs      1

No BREAKING CHANGE

→ Proposing v1.3.0. Proceed?
```

If no commit convention is detected, or the repository has no tags, it **asks instead of inferring**. A guess is never presented as a computed result.

### Finish — one step at a time

```
/git-flow:finish
```

Reads the current branch type and state, then takes **exactly one step**. A tag must land on the merged `main` commit, but merging goes through review and CI — so this cannot complete in a single call.

| State | Action |
|---|---|
| No PR | Create the PR and stop (review and CI are yours) |
| PR open | Report status only |
| PR merged | `git pull`, then propose tagging the merge commit |
| Tag done | Open the back-merge PR |

It is idempotent — safe to run repeatedly, and finished steps are skipped.

### Diagnose

```
/git-flow:status
```

```
Position
  branch   release/v1.3.0  (release)
  base     develop  ok

Diagnosis
  [warn] 2 commits on main are missing from develop
         → looks like hotfix/npe-on-login was never backmerged
```

It diagnoses only; it does not fix.

### Blocking violations

Hooks apply even when you bypass the commands and run git directly.

```
$ git tag -a v1.3.0        # while on release/v1.3.0

[git-flow] Cannot create a release tag on release/v1.3.0.

Release tags belong on merged main commits only. main is the single source of truth
for what is running in production; break that and you lose both your rollback anchor
and your hotfix base.

  git checkout main && git pull    # fetch the merge commit first
  git tag -a <version>             # then tag it
```

Four things are blocked:

- Direct commits to `main` and `develop`
- `--squash` merges
- Hotfix branches cut from `develop`
- Release tags on non-`main` commits

**Turning it off** — legitimate exceptions exist, such as initial setup or correcting a misplaced tag.

```sh
GIT_FLOW_GUARD=off git commit -m "..."
```

**Limits** — the hook inspects Bash command strings. It guards against mistakes; it is not access control. Pair it with [branch protection rules](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets/available-rules-for-rulesets) when you need real enforcement.

## When not to use this

Git Flow suits products with **scheduled releases and multiple versions live at once**.

For a continuously deployed web service, or any product where only the latest version exists, the `develop` and `release` layers are pure overhead. Trunk-based development fits better, and this plugin will not help.

## References

- [A successful Git branching model — Vincent Driessen](https://nvie.com/posts/a-successful-git-branching-model/)
- [Conventional Commits 1.0.0](https://www.conventionalcommits.org/)

## License

MIT — see [LICENSE](LICENSE)
