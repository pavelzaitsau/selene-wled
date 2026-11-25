# Enforcement

Loaded from the `commit-messages` skill, whose body is `../SKILL.md`. Read it when installing or tuning the gates.

A rule nobody checks lasts until the first rush.

## commitlint

`assets/commitlint.config.js` covers structure: the type list, the case, the 72-character wall, the missing blank lines. It disables `body-max-line-length` and `footer-max-line-length`, because the defaults fight the no-wrap rule: a `BREAKING CHANGE:` footer is one line, however long.

`header-min-length` is 15. A shorter header, such as `fix: typo`, names no place, and a reader of `git log --oneline` cannot act on it.

`subject-case` is off on purpose. A ticket id is uppercase and fails every case rule commitlint offers, so the hook checks the word after the id instead.

## The `commit-msg` hook

`scripts/commit-msg` covers what commitlint cannot express: attribution lines, long dashes, and the lower-case start of the description after a ticket id. It warns past 50 characters and fails past 72.

It also checks that a type is present and that the subject has no trailing period, which commitlint checks too. The overlap is deliberate: most projects install the hook and never install commitlint, and `update the parser` is the message that reaches `main` without it. The type list stays in commitlint alone. A project extends that list in one file, and a second copy in the hook would drift from it in silence.

The hook stops at the scissors line that `git commit -v` adds, so a diff that quotes an attribution line does not fail the commit. It still reads comment lines, because `git commit -m` keeps them in the commit.

The attribution check normalises each line first, so an indent or a leading emoji does not smuggle a line past it.

`Signed-off-by` is refused by default and is the one line worth keeping in a project that runs DCO. Set `ALLOW_SIGNOFF=1` there.

A coding agent adds its own attribution unless told otherwise. Turn that off in the agent's settings; leaving the hook to catch it every commit is a fight, not a gate.
