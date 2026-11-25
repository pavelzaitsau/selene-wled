---
name: commit-messages
description: "Write a commit message that follows Conventional Commits 1.0.0: type, optional scope, imperative subject, ticket id, optional body, footers, and breaking-change marking. Use this skill whenever a commit is being prepared, amended, squashed or reviewed, and whenever a message needs checking against the convention. Trigger it even when the user only says 'commit this', 'what should the message be' or 'clean up these commits'. Do NOT use it for pull request descriptions, changelogs or release notes."
license: MIT-0
---

# Commit messages

```text
<type>[optional scope][!]: [TICKET-ID] <description>

[optional body]

[optional footer(s)]
```

English, imperative, plain. Hyphens only, never a long dash.

## Cut everything that carries no fact

Shorter wins at every level, and stops exactly where a fact would go.

- No body where the subject already says it.
- No scope where the change spans areas, or where a ticket id already names the place.
- No footer that repeats what the subject or the body states.
- No word whose removal changes nothing: `properly`, `correctly`, `some`, `various`, `also`, `now`.

Articles and negation stay. `a retry` and `the retry` are different claims, and a dropped `not` inverts one.

A subject a reader cannot act on is not shorter, it is empty.

## One commit, one change

A change that fits two types is two commits. Formatting never travels with logic, and a mass rename travels alone.

Every commit builds and passes its tests on its own. The cost of breaking this shows up once, in `git bisect`, and by then the history is already useless.

## Subject

The subject stands alone and carries the whole change for a reader of `git log --oneline`.

- 50 characters or fewer, including type and scope. Over 72 is rejected.
- Lower case after the colon. No trailing period.
- Imperative mood: `add`, not `added` or `adds`, and never `I`. `git log` reads as a list of actions, not a diary.
- Say what the commit does, not what the author did.

| Weak | Strong |
| --- | --- |
| `update parser` | `accept a trailing comma in a list` |
| `fix bug` | `stop a retry from firing after a timeout` |
| `refactor code` | `move date parsing out of the request handler` |
| `improve performance` | `cache the compiled pattern between calls` |
| `wip`, `misc` | the change itself, or no commit yet |

| Type | When |
| --- | --- |
| `feat` | new behaviour a user can observe |
| `fix` | a defect in existing behaviour |
| `perf` | same behaviour, less time or memory |
| `refactor` | structure changes, behaviour does not |
| `test` | tests only |
| `docs` | documentation, comments, agent instructions |
| `build` | dependencies, lockfiles, packaging, Docker |
| `ci` | pipelines, hooks, build targets |
| `chore` | anything the other types do not cover |
| `revert` | undoes an earlier commit |

A project may add types. It may not silently redefine these.

The type sets the version bump, which is why the choice is not a matter of taste.

| Marking | Release |
| --- | --- |
| `feat` | minor |
| `fix`, `perf` | patch |
| `!` or `BREAKING CHANGE:` | major |
| everything else | none |

**Scope** is optional: one lower-case noun in parentheses naming the area touched, no spaces. Omit it when the change spans more than one area. Keep the project's scope list short and closed; an open list turns into free text within a month.

### Ticket id

Where the work has a ticket, its id goes in the subject, immediately after the colon, in the tracker's own casing.

```text
fix: PROJ-482 reject a token past its session
```

The id counts against the 50 characters. A ticket key plus a scope leaves little room, so drop the scope first: the ticket already says where the work belongs.

One id in the subject. Further ones go to a `Refs:` footer.

An id closes nothing by itself. A tracker that closes on commit needs its own footer, `Closes: #812` or the equivalent.

## Breaking change

Mark it twice: `!` before the colon, and a `BREAKING CHANGE:` footer saying what breaks.

```text
feat(api)!: return a cursor instead of an offset

BREAKING CHANGE: pagination callers pass `cursor`; `offset` is gone.
```

`BREAKING CHANGE` is uppercase. `BREAKING-CHANGE` is a synonym. The specification reads every other token in any case, but this convention writes the type in lower case, and both gates reject `Feat:`.

## Body

**Most commits have no body.** If the subject covers the change, stop there.

Write one only when the change needs a justification the subject cannot carry: a rejected alternative, an outside constraint, a number that drove the decision.

**Three sentences, one paragraph, and stop.** A body with sections in it is a document in the wrong place. Put that in the file the change touches, where the next reader looks for it. Or put it in the pull request, where a reviewer can answer it. Someone reads a commit body once, running `git log` against a line they do not understand. The body pays for itself in the first two lines or not at all.

The body says why. The diff already says what. A body that restates the subject costs the reader time twice, and teaches them to skip the bodies that matter.

```text
perf(cache): check and fetch a miss in one call

The read path hit the database twice for every miss: once to check, once to fetch. One call does both. It removes about 40% of read load at peak.

Refs: #812
```

**Do not wrap.** One paragraph per line, however long. A blank line separates paragraphs, and nothing else breaks a line. Wrapped bodies fight every tool that reflows them.

## Footers

Each footer is `Token: value` or `Token #value`, one per line, after a blank line. Tokens use hyphens instead of spaces, except `BREAKING CHANGE`.

Useful ones: `BREAKING CHANGE:`, `Refs:`, `Closes:`, `Reviewed-by:`. A project may define its own, such as a metric delta.

No line names a tool or an assistant. `Co-Authored-By`, `Generated with`, `Claude-Session` and their kin are noise in `git log`, and they outlive their accuracy.

A revert names what it undoes:

```text
revert: drop the retry on a 429

Refs: 676104e
```

## Squash merge

A squash merge writes the pull request title into the history, not the commits on the branch. The title follows every rule above, or the convention leaks into `main` the first time someone merges.

The pull request body becomes the commit body: unwrapped, one paragraph per line, and inside the three-sentence budget. A pull request with more to say than that says it in a review comment or in the document, neither of which lands in `git log`.

Keep `Closes:` in the pull request body. In a branch commit it closes the ticket on merge, which is early.

## Before committing

`assets/commitlint.config.js` and `scripts/commit-msg` check the mechanical half of this list. `references/enforcement.md` says which gate checks what, and why.

- [ ] One change, one type
- [ ] Subject 50 characters or fewer, imperative, lower case, no period
- [ ] Ticket id in the subject where one exists
- [ ] Breaking change carries both `!` and the footer
- [ ] The body earns its place, or there is none, and it is at most three sentences
- [ ] The body, if present, is unwrapped and says why
- [ ] No attribution line, no long dash
