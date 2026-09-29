---
name: branch-names
description: "Name a git branch to one scheme: a type prefix as a folder, the ticket id, and a short slug, lower case and under 40 characters. Use this skill whenever a branch is created, renamed or reviewed, and whenever you check a name against the convention. Trigger it even when the user only says 'start a branch', 'work on PROJ-12' or 'rename this branch'. Do NOT use it for commit messages, which belong to commit-messages, or for choosing a branching model."
license: MIT-0
---

# Branch names

```text
<type>/[<ticket-id>-]<slug>
```

Lower case, hyphens, exactly one slash.

```text
fix/ki-62-retire-queue
feat/plat-1184-cursor-pagination
docs/branch-naming
release/2026.3
```

A branch name is read in `git branch`, in a pull request list, in a worktree path and in whatever CI builds from it. It has one job: say which ticket this is and what it changes.

## The prefix is the change type

The prefix is the type of the commit that lands: `feat`, `fix`, `perf`, `refactor`, `test`, `docs`, `build`, `ci`, `chore`, `revert`. The `commit-messages` skill owns what each type means; this list is a copy of that one. `release` is the one prefix with no commit type behind it, for a branch that stabilises a version while `main` moves on. Its slug is the version, and it is the one slug that takes dots: `release/2026.3`, `release/v1.2.0`.

A branch that fits two types is two branches, for the same reason a commit that fits two types is two commits.

A project may add a prefix. It may not redefine one of these. Where a pipeline owns a prefix of its own, name it once and the checker takes it:

```bash
git config branch-names.extra-types "ticket"
```

Never use a second slash. Git stores `feat/api` as a file and `feat/api/auth` as a directory of the same name. Creating the second while the first exists fails with `cannot lock ref`. Rename one of them.

An owner prefix - `claude/`, `pavel/` - is the other common scheme. It answers a question that `git log` already answers, and it hides the one the reader has.

## The ticket id comes first in the name

Where the work has a ticket, its id follows the prefix: `fix/ki-62-retire-queue`. Everything about that ticket then sorts and tab-completes together.

- Lower case the tracker key. `KI-62` becomes `ki-62`.
- Where the tracker has no key, the bare number is the id: `fix/812-retire-queue`.
- One id per branch. A branch serving two tickets is two branches.
- No ticket, no id. Never invent one, and never substitute a date.

**Lower case is not cosmetic.** macOS and Windows check out on a case-insensitive filesystem, where `feat/KI-62-x` and `feat/ki-62-x` are one loose ref file. The second `git switch -c` either fails or lands you on the first branch, and the branch you thought you made does not exist.

## The slug names the change, in 2 to 4 words

- Take the words from the change, not from the ticket title. A title is written to be found in a tracker; a slug is written to be recognised in a list.
- Drop every word the prefix already carries. `fix/fix-timeout` and `feat/add-export` say `fix` and `add` twice.
- Nouns over verbs: `retire-queue`, not `retires-the-queue`.
- Drop articles and prepositions. A slug is an identifier, not a sentence.

| Weak | Strong |
| --- | --- |
| `feat/ki-88-add-new-support-for-per-step-transports` | `feat/ki-88-per-step-transport` |
| `fix/bugfix` | `fix/ki-62-retire-queue` |
| `chore/updates` | `chore/bump-uv` |
| `feat/pavel-working-on-the-new-login-flow` | `feat/plat-9-login-flow` |

## 40 characters, 50 at the wall

Count the whole name, prefix included. Three things enforce the budget, and only the first is cosmetic.

1. `git branch` and every pull request list truncate the column.
2. A worktree directory takes the branch name, slashes and all.
3. CI that builds a preview environment turns the branch into a DNS label, replacing `/` with `-` and adding its own prefix. A DNS label stops at 63 characters, and two long branches that share a first 63 characters get one environment between them.

## Rename before the first push, not after

A coding agent generates its own name, such as `claude/git-branch-naming-54825b`. Rename it with `git branch -m <new-name>` before the first push.

After a push, a rename is a new branch plus a delete. The open pull request closes, and its review threads close with it. Renaming through the forge's own UI is the only rename that keeps them.

A worktree does not follow a rename. The directory keeps the old name until you move it yourself.

## One branch, one ticket, then delete it

Delete the branch when its pull request merges. A branch left behind makes `git branch --merged` useless as a list of what is done. The next person on that ticket cannot tell your merged branch from a live one.

Never reopen a merged branch for follow-up work. Branch again from `main`.

## What git refuses on its own

Git rejects a space, `..`, `~`, `^`, `:`, `?`, `*`, `[`, a leading `-`, a trailing `/` and a `.lock` suffix. Do not memorise the list; ask git:

```bash
git check-ref-format --branch "$name"
```

## Enforcement

`scripts/branch-name.sh` builds a name and checks one:

```console
$ branch-name.sh PLAT-1184 "the retry keeps firing after a timeout"
fix/plat-1184-retry-keeps-firing-timeout

$ branch-name.sh --type docs - "write up the branch naming convention"
docs/write-branch-naming-convention

$ branch-name.sh --check Feature/KI-62-Fix
branch-name: upper case is not allowed: Feature/KI-62-Fix
branch-name: expected <type>/[<ticket>-]<slug>, lower case and hyphens
branch-name: unknown type 'Feature', expected one of: feat fix perf refactor ...
```

The ticket argument is `-` where there is no ticket. The generator infers the type from the description and exits 2 where it cannot, rather than defaulting to `chore` and hiding the choice. It refuses a name that already exists instead of appending a number. A duplicate name means the branch is already there, and you want to know that.

`--check` passes `main` and `master` unconditionally. Neither was named to this convention, and renaming either is not the answer.

`scripts/pre-push` runs the check over every branch being pushed, and lets `main`, `master` and a delete through. It calls `branch-name.sh` from its own directory, so install both. Run this from the skill directory:

```bash
cp scripts/pre-push scripts/branch-name.sh .git/hooks/
chmod +x .git/hooks/pre-push .git/hooks/branch-name.sh
```

The hook refuses the push where `branch-name.sh` is not beside it or on `PATH`. A hook that cannot check is not a reason to publish an unchecked name.

Set `SKIP_BRANCH_CHECK=1` for the one push that has to go out under an old name.

## Never

| Banned | Why |
| --- | --- |
| Upper case anywhere | Two branches collide into one ref on macOS and Windows |
| An owner or agent prefix | Answers a question `git log` already answers |
| Two slashes | Git refuses the second branch with `cannot lock ref` |
| A date in the name | The ref log already carries the date, and carries it correctly |
| `wip`, `tmp`, `test2`, `new-branch` | Says nothing a reader can act on |
| A ticket title pasted whole | Blows the budget and repeats the tracker |
| Reusing a merged branch | Breaks `git branch --merged` as a list of finished work |

## Before creating a branch

- [ ] Prefix is a type from the list, and matches the commits that will land
- [ ] Ticket id right after the prefix, lower case, where a ticket exists
- [ ] Slug is 2 to 4 words and repeats neither the prefix nor the ticket title
- [ ] Whole name is inside the 40-character budget and never past 50, lower case, one slash
- [ ] `git check-ref-format --branch` accepts it
- [ ] No branch of that name exists already
