# Skills

Five writing skills, vendored so that a clone of this repository carries the
rules its own documentation and commits are held to.

| Skill | Governs |
| --- | --- |
| `branch-names` | Branch naming |
| `commit-messages` | Conventional Commits, and what earns a body |
| `docs-linter` | The Vale gate behind the writing rules |
| `markdown-formatting` | Markdown that renders the same everywhere |
| `technical-writing` | Prose in any file: README, comments, commit bodies |

## These are copies

The skills live in [copydesk](https://github.com/pavelzaitsau/copydesk), and that copy is the one
to edit. The files here are refreshed from a local clone of it, `~/Projects/copydesk` by default:

```bash
tools/sync-skills.sh
```

Editing a skill here instead puts the change one `rsync` away from being
overwritten, and leaves the source repository wrong for every other project.

MIT-0 licensed; each skill carries its own `LICENSE.txt`.
