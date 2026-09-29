# Tables

Loaded from the `markdown-formatting` skill, whose body is `../SKILL.md`.

A Markdown table is the element most likely to be written by hand and least likely to survive editing. Everything below is about keeping it correct through the second and third edit, not just the first.

## The shape

```markdown
| Column | Column | Column |
|---|---|---|
| cell | cell | cell |
```

Three parts, in order, with no blank line between them:

1. **Header row.** Every table has one. There is no syntax for a table without a header; leave the cells empty if the columns need no names, but keep the row.
2. **Delimiter row.** At least three hyphens per column. Fewer parses as a paragraph in some renderers.
3. **Body rows.** Zero or more.

A blank line before the table and after it. The one before is a hard requirement on GitHub: without it the table renders as a paragraph of pipes.

## The rule that loses data

**Every row carries the same number of cells as the header.** A row with fewer cells leaves holes; a row with more loses the extra cells without warning. Nothing in the rendered output says a column went missing, which is why this survives review.

When a table renders wrong, count the pipes per line before looking at anything else.

## Alignment

The delimiter row sets it, with a colon on the side the text is pushed to:

```markdown
| Left | Centre | Right |
|:---|:---:|---:|
| a | b | c |
```

Numbers read better right-aligned; everything else left. Centre only for short status columns, because centred text has no common left edge for the eye to follow down the column.

Alignment is per column and cannot vary by row.

## Pipes inside a cell

A literal `|` ends the cell unless it is escaped:

```markdown
| Pattern | Meaning |
|---|---|
| `a \| b` | either a or b |
```

The backslash is needed even inside backticks: the parser splits the row into cells before it parses inline code. An unescaped pipe is the most common cause of a table that renders one column short. It shows up wherever a table documents a regular expression or a shell pipeline.

## What fits in a cell

Inline formatting works: links, `code`, **bold**, _italic_.

Block content does not. No lists, no fenced code, no paragraphs, no headings. A line break inside a cell needs `<br>`, which is HTML and does not render everywhere.

A cell needing more than one line is a signal that the table is the wrong shape. Two ways out. Move the long content into prose under the table, and keep a short label in the cell. Or split the table into sections, one heading each.

## When not to use a table

A table earns its place when facts have two dimensions: rows are items, columns are properties of every item.

- One dimension is a list. A two-column table where the second column is a sentence is a list wearing a costume.
- More than five or six columns will not fit a screen, and a horizontally scrolled table is unreadable. Transpose it, or split it.
- Ordered steps are a numbered list. A table cannot show that step 3 depends on step 2.

## Checklist

- [ ] A blank line before the table and after it
- [ ] A header row and a delimiter row with at least three hyphens per column
- [ ] Every row has the same cell count as the header
- [ ] Every literal `|` inside a cell is escaped as `\|`
- [ ] No cell holds a list, a fence or a paragraph
- [ ] Alignment set where a column holds numbers
