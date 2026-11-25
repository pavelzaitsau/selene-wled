# Vocabulary

Loaded from the `technical-writing` skill, whose body is `../SKILL.md`. Look a word up here; do not read it end to end.

## Prefer

A swap that a linter can apply everywhere, such as `utilize` to `use`, lives in the `Docs.HiddenVerbs` rule of the `docs-linter` skill and is not repeated here. This table holds the swaps that need a reader's judgement, because the long word is correct in some domain.

| Prefer | Over |
| --- | --- |
| fail | `be unsuccessful`, `error out` |
| delete | `remove`, `purge`, `clean up` |
| check | `verify`, `ensure` (`Verified by:` stays as a template field name) |
| build | `construct`, `generate` (reserve `generate` for code generation) |
| send | `transmit`, `dispatch` |
| read / write | `consume` / `persist` |

## Words to pin to one meaning

Each of these carries two meanings in most codebases. Pick one per document, and say which on first use.

| Word | The two meanings that collide | Resolution |
| --- | --- | --- |
| `should` | a recommendation, and an expectation about behaviour | `SHOULD` for the recommendation; `is expected to` for behaviour |
| `may` | permission, and possibility | `MAY` for permission; `can` for possibility |
| `error` / `failure` / `fault` | the value returned, the operation's outcome, the defect | Fix one per document and never swap |
| `invalid` / `malformed` | violates a rule, and cannot be parsed | `malformed` before parsing, `invalid` after |
| `argument` / `parameter` | the value passed, the name in the signature | Use both correctly, never interchangeably |
| `user` / `caller` / `client` | a human, calling code, a remote system | Name which one on first use |
| `timeout` / `deadline` | a duration, and a point in time | Duration takes a unit; a deadline takes a timestamp |
| `optional` | may be omitted, and may be null | State which. They are different contracts |
| `async` | non-blocking, and eventually consistent | Never let it mean the second one silently |
| `validate` | check a schema, and check a business rule | Reserve `validate` for schema; use `check` for the rule |

## Never write

Filler and hedges live in the `Docs.Filler` and `Docs.Hedging` rules of the `docs-linter` skill. This table holds the words a linter cannot judge.

| Banned | Reason |
| --- | --- |
| `just` | Filler. `Docs.Filler` leaves it out; the `docs-linter` skill, section Adding a rule, says why |
| `should work` | An untested claim wearing a hedge. A ban on `should work` would also flag `the parser should work on a copy` |
| `etc.`, `and so on` in a normative list | A specification with an open list specifies nothing |
| `TBD` with no owner | See TODO discipline |
| `we` in reference documentation | Name the actor: the service, the caller, the operator |

## A project term registry

One concept, one word. Repetition of the exact term is correct. Varying a name for style is how two words for one thing enter a codebase.

A registry that lists only approved words eats the language around it. It needs three parts, not one:

1. **Canonical** - the approved word, its one-sentence meaning, and at least one banned synonym. A term with no banned synonym is a glossary entry, not a rule.
2. **Free** - ordinary words that look like terms and stay as they are. Without this list a registry starts banning real domain vocabulary, and the ban carries the same authority as the rest of the file.
3. **Banned** - the wrong wording, each entry with its reason. A ban with no reason gets reverted by the next reader.

Generate the linter rule from the registry. Never maintain the list and the rule by hand: two hand-synchronised copies drift, and the drift stays invisible until someone greps for it.

## What NOT to optimize

Do not compress by abbreviating words. In every common tokenizer a frequent English word costs one token, while an ad-hoc abbreviation splits into two or three. `cfg` is not cheaper than `config`. Both are worse for the reader and for grep.

Compression comes from deleting sentences, not from shortening words.
