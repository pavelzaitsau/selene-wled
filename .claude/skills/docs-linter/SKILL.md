---
name: docs-linter
description: "Set up and tune a Vale style gate for a documentation set: install, pre-commit and CI wiring, ready rule files for hedging, filler, vague obligation and abbreviations, and the config traps that cost an afternoon each. Use this skill whenever documentation style needs enforcing rather than advising - adding the linter to a repository, writing or tuning a rule, or working out why a rule fired or stayed silent. Trigger it when someone asks to 'check the docs automatically', 'stop people writing X' or 'add a style check to CI'. Do NOT use it for the writing rules themselves, which live in technical-writing, or for Markdown structure, which is markdown-formatting."
license: MIT-0
compatibility: "Vale on PATH (brew install vale); the rule files and traps need Vale 3.x, whose vocabulary layout is `styles/config/vocabularies/`"
---

# Docs style gate

A convention nobody checks decays within a quarter. Everything a linter can express belongs to the linter, and stops being prose.

The writing rules this gate enforces are in the `technical-writing` skill. This skill covers the machine.

| Enforceable by a linter | Not enforceable, stays in a skill |
| --- | --- |
| Banned words and hedges | Whether a section is complete |
| Vague obligation instead of RFC 2119 | Whether an ADR had real alternatives |
| Sentence length | Whether a fact is in the right file |
| Abbreviations in prose | Whether a comment states why |
| Terminology substitutions | Whether a number is true |

The shipped config in `assets/vale/` is a starting point, not a standard. The shipped config avoids every trap listed below.

## Install

Vale is a Go binary, not a package of your language's ecosystem. Install it separately, or the hook fails to spawn instead of passing silently.

```bash
cp -r assets/vale/.vale.ini assets/vale/styles .
vale --minAlertLevel=error <docs-root>/
```

## Wiring

Pre-commit, in the `local` repo block:

```yaml
      - id: vale-docs
        name: docs style (Vale)
        entry: vale --minAlertLevel=error
        language: system
        files: ^<docs-root>/.*\.md$
```

CI, as a step after the code linter:

```yaml
      - name: docs
        uses: errata-ai/vale-action@v3.0.0
        with:
          version: 3.20.0
          files: <docs-root>
          fail_on_error: true
          filter_mode: nofilter
```

`filter_mode: nofilter` makes the step fail on any error in the docs root. The action's default, `added`, fails only on errors in lines the pull request adds.

Pin both the action and Vale. A floating ref, such as `@reviewdog`, or the default `version: latest` changes a rule's meaning underneath a build nobody touched.

`scripts/lint-docs.sh` does the same without the action, and exits 127 with an install hint when Vale is absent.

`Docs.Rfc2119` is a warning, not an error, and deliberately so. RFC 2119 keywords belong in normative text only, and the gate cannot tell a specification from a README. An error-level rule here would force `MUST` into every guide.

Errors block. Warnings do not. Put a rule at `error` only when a false positive is worse than the thing it catches never being written.

## Shipped rules

Each rule file holds its own word list. The table says what a rule is for and never copies the list. The Level column is a copy of each file's `level:`, which the file owns.

| Rule | Level | Catches |
| --- | --- | --- |
| `Docs.Hedging` | error | A hedge where a number with a scope belongs |
| `Docs.Filler` | error | A word that carries no fact |
| `Docs.Rfc2119` | warning | An obligation phrased vaguely instead of with an RFC 2119 keyword |
| `Docs.NoAbbrev` | error | An ad-hoc abbreviation in prose |
| `Docs.HiddenVerbs` | warning | A verb hidden in a noun phrase, or a long form of a short word |
| `Docs.Passive` | warning | An agentless passive |
| `Docs.SentenceLength` | warning | A sentence over the limit in rule 3 of the `technical-writing` skill |
| `Docs.Rfc2119Case` | warning | A lowercase `must` or `should` where an obligation is meant |
| `Docs.LongDash` | error | An em or en dash anywhere outside code |
| `Docs.Terms` | error | Project terminology, empty until the project fills it |
| `Vale.Terms` | error | Wrong capitalisation of a proper noun |
| `Vale.Avoid` | error | A word listed in `reject.txt` |

## Config traps

Each one costs an afternoon to find.

**List `Vale` in `BasedOnStyles`.** `reject.txt` and the capitalisation check behind `accept.txt` run as `Vale.Avoid` and `Vale.Terms`, which belong to the built-in `Vale` style. With a project style alone, `reject.txt` is dead config that looks like it works. `accept.txt` works either way, and every rule treats its entries as exceptions, so an entry there also silences every `Docs` rule for that word.

**`raw` concatenates, `tokens` alternates.** A list under `raw:` is joined into one regular expression, not OR-ed. Two or more alternatives under `raw:` silently produce a pattern that never matches. Use `tokens:` for alternatives.

**Rule patterns are not RE2.** Vale 3 compiles rule patterns with `regexp2`, which supports lookahead and lookbehind. State an exclusion directly: `Docs.Hedging` stops a match before a hyphen with `(?!-)`.

**Substitutions do not match across a line break.** A phrase wrapped by the formatter passes the rule. Reflow the paragraph if the rule matters.

**Vale already skips code in Markdown.** Fenced blocks and inline code spans are exempt with no setting. Do not add a `BlockIgnores` pattern for fences: a lazy pattern across lines swallowed every line after the first fence, and the gate passed everything. Code being exempt is why a style rule cites the wording it bans inside backticks. Outside them, the rule text trips its own rule.

**Spell check is off by design.** `Vale.Spelling = NO`. On a technical corpus it produces more noise than every other rule combined.

## Adding a rule

1. Write the rule under `styles/Docs/`.
2. Write a probe file containing the wording the rule is meant to catch.
3. Write a probe file containing legitimate domain text the rule is meant to pass. **This step is not optional.** A `Filler` rule that bans `just` also flags `just-in-time`, and only the false-positive probe exposes it.
4. Run both probes at `--minAlertLevel=warning`.
5. If the rule encodes terminology, generate it from the project's term list. The term registry in the `technical-writing` skill's `references/vocabulary.md` says why.

## What is deliberately not linted

- Any word that is also a legitimate domain term. List it in the free-words section of the project's term list instead.
- Chat and review comments. The gate covers files.
- Anything only a reviewer can judge: completeness, ordering, whether a claim is true.

## Adapting to a project

Fill these four. The paths are the shipped ones; after the install step above, the same files sit under `styles/` at the repository root.

1. The routing table from the `technical-writing` skill, section One home per fact, copied into the contributor guide with the project's real paths.
2. `assets/vale/styles/Docs/Terms.yml` - the project's terminology substitutions, generated from the term list.
3. `assets/vale/styles/config/vocabularies/Project/accept.txt` - proper nouns and product names, so `Vale.Terms` enforces their capitalisation. Every rule skips an entry here, so list names only, never a word a rule bans.
4. `assets/vale/styles/config/vocabularies/Project/reject.txt` - the misspellings this project produces.

Tune three more where the project needs it: the docs root, the severity of each rule, and the `NoAbbrev` word list. Everything else moves to a new repository unchanged.
