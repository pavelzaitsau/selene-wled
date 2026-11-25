---
name: markdown-formatting
description: "Format Markdown so it renders the same everywhere and passes a linter: heading levels, blank lines around every block, list markers and nesting, fenced code with a language, links, and tables. Use this skill whenever you write or edit a .md file, review someone else's Markdown, fix a document that renders wrong, or build a table by hand. Trigger it even when the user only says 'write the README', 'fix this doc' or 'add a table' without naming Markdown. Do NOT use it for the wording itself, which belongs to the technical-writing skill, or for rendering Markdown to another format."
license: MIT-0
compatibility: "markdownlint-cli2 for the optional gate; no dependency for the rules themselves"
---

# Markdown formatting

Markdown has no single specification. GitHub Flavored Markdown, CommonMark and every editor's own parser disagree at the edges. The disagreement is silent: the document looks right where you wrote it, and collapses somewhere else.

The rules here are the intersection that renders the same in every common parser. They match the markdownlint defaults, so a document that follows them also passes the gate.

Wording is a separate concern. Sentence rules, structure and vocabulary live in the `technical-writing` skill.

## Blank lines decide almost everything

Most Markdown that renders differently in two places is a missing blank line. GitHub lets a heading, a list, a fence or a table start on the line after a paragraph. Parsers that follow the original `Markdown.pl` do not let a list interrupt a paragraph, so there the list joins the paragraph as plain text. GitHub shows nothing wrong, so the defect survives review.

Surround every block-level element with a blank line: headings, lists, fenced code, tables, blockquotes and horizontal rules. The blank line costs nothing on GitHub, and the stricter parsers need it.

Fragile:

````markdown
## Setup
Run the installer.
- download it
- run it
```bash
npm install
```
| Step | Time |
| --- | --- |
````

Portable:

````markdown
## Setup

Run the installer.

- download it
- run it

```bash
npm install
```

| Step | Time |
| --- | --- |
| download | 1 min |
````

## Headings

- One `#` heading per document, first line of the file. It is the title.
- Descend one level at a time. A `##` never jumps to `####`; the reader and every table-of-contents generator use the levels to build a tree.
- ATX style only: `## Heading`, one space after the hashes, nothing after the text. Setext underlines and closing hashes are a second style, and mixing styles is the most common inconsistency in a repository.
- No trailing punctuation. A heading is a label, not a sentence.
- Headings become anchors: lower-cased, spaces to hyphens, punctuation dropped. `## Set up the gate` is `#set-up-the-gate`. Rename a heading and every link to it breaks silently.

## Lists

Pick one unordered marker and keep it for the whole document. `-` is the safest: `*` collides with emphasis and `+` is rare enough that some editors mishandle it.

Number an ordered list one of two ways, and never both inside one list. Write `1.` on every item where nobody cites the list by number. The source survives reordering, and a diff shows one line instead of a renumbered block. Write real numbers where the text says "rule 5" or "step 3". A reader who greps the source needs to find that number.

Indent a nested list to the column where the text of its parent starts, not to the marker: two spaces under a `-` marker, three under `1.`. A child indented two spaces under `1.` leaves the list on GitHub, and `MD007` and `MD032` then flag it as a separate list.

```markdown
- the parent item
  - the child, two spaces in
    - the grandchild, four

1. the ordered parent
   - the child, three spaces in
```

A blank line before the list and after it. Without the trailing one, the paragraph that follows joins the last item.

A list item that holds more than a line keeps its continuation indented to the same column as the item text.

## Code

Fenced blocks only, three backticks, never indented blocks. An indented block hides in a diff review, and reads the same as a nested list continuation.

Always name the language. It drives highlighting. A linter treats a missing language as an error, because an unlabelled block is a block someone pasted in a hurry.

Use `text` for output that has no language, and `console` or `bash` for a shell session. Where the content itself contains three backticks, fence it with four.

Inline code takes single backticks and no padding spaces: `` `--flag` ``, not `` ` --flag ` ``.

## Links and images

- `[text](url)`. The reversed form `(text)[url]` renders as literal characters in most parsers and as a link in the rest, which is worse.
- Link text describes the destination. `click here` and `this link` tell a screen reader nothing and read as noise in a list of links.
- A bare URL in prose is wrapped in angle brackets: `<https://example.com>`. Without them some parsers autolink and some do not.
- Every image carries alt text. `![Coverage badge](badge.svg)`, never `![](badge.svg)`.
- A link to a heading inside the repository uses the anchor form: `[the gate](#the-gate)`.

## Emphasis

`**bold**` and `_italic_`, one style each, consistently. Underscores inside a word break in parsers that predate CommonMark, so `snake_case_name` in prose belongs in backticks.

Emphasis is not a heading. A bold line standing alone where a heading belongs breaks the document tree, the table of contents and every anchor link.

## Tables

Tables are where hand-written Markdown fails most often. The full rules, including alignment and the pipe-escaping trap, are in `references/tables.md`. Rules 2 and 3 break rendering on GitHub itself. Rules 1 and 4 are what GitHub's documentation asks for; GitHub's renderer forgives both, and other renderers need not.

1. **A blank line before the table.** GitHub renders a table that starts on the line after a paragraph, so this is portability, not rendering there.
2. **No blank line inside the table.** A blank line ends it, so every row below renders as literal pipes. The rows look right in the source and the content is silently outside the table.
3. **Every row has the same number of cells.** A short row gets empty cells; a long row loses its extra cells. Count the pipes when a table looks wrong.
4. **Three hyphens per column in the delimiter row**, with one space inside each pipe: `| --- | --- |`. The GFM specification accepts one hyphen, and GitHub renders it. GitHub's own documentation asks for three, so three is the form every reader recognises.

Rule 2 is the one no built-in check catches. `assets/rules/table-row-outside-table.js` catches it and says why the built-in rules miss it, and `assets/.markdownlint-cli2.jsonc` loads it.

```markdown
| Setting | Default | Effect |
| --- | --- | --- |
| `timeout` | 30 s | How long one attempt waits |
```

Column widths do not have to line up in the source. The rendered output is the same either way, so write whichever reads better and do not spend a review on it.

## The file itself

- No hard tabs. Tab width varies by editor, and a tab inside a list breaks the indentation the parser expects.
- No trailing spaces, with one exception: two trailing spaces are a hard line break. Prefer restructuring so the break is not needed, and never let an editor strip them silently where they are load-bearing.
- One blank line between blocks, never two.
- The file ends with exactly one newline.
- Inline HTML only where Markdown has no equivalent: `<sub>`, `<sup>`, `<kbd>`, `<br>`. HTML does not render on every surface that shows Markdown.

## Line length

Wrapping is a project decision, and this skill does not impose one. Where prose is unwrapped, one paragraph per line, turn the line-length rule off rather than leave it failing:

```jsonc
"MD013": false
```

A half-enforced rule trains everyone to ignore the linter.

## The gate

`assets/.markdownlint.jsonc` carries these rules as configuration, and `assets/.markdownlint-cli2.jsonc` adds the one custom rule beside them. Run both with:

```bash
scripts/lint-markdown.sh docs/
```

The rule numbers behind each section, and what each one catches, are in `references/rules.md`.

## Before committing a document

- [ ] One `#` heading, on the first line
- [ ] Heading levels descend one at a time
- [ ] A blank line before and after every list, fence, table and blockquote
- [ ] Every fence names a language
- [ ] One list marker style, one emphasis style, throughout
- [ ] Every table row has the same cell count
- [ ] No bare URL, no empty link text, no image without alt text
- [ ] The file ends with a single newline
