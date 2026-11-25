// A line that looks like a table row but sits outside any table.
//
// GitHub Flavored Markdown starts a table at a header plus a delimiter row. A
// blank line ends it, so a row written below that blank line is a paragraph.
// It renders as literal pipes, and the content is silently not in the table.
//
// No built-in rule catches this. MD055 and MD056 check pipe style and column
// count *within* a parsed table, and the orphaned line was never parsed as one.
// Measured on 2026-09-14: a row one blank line below its table passed a whole
// gate and reached review as raw pipes on the rendered page.
//
// Rows inside fenced code are skipped, because a fence holds whatever it holds.
// The parser decides where a fence ends, not a regular expression here. A
// hand-written tracker closed a four-backtick fence on an inner three-backtick
// line, and flagged the example rows after it.
// Inline code such as `a | b` never matches: the test is a line that both opens
// and closes with a pipe.
//
// Load it through `customRules` in the project's markdownlint-cli2 config.
// assets/.markdownlint-cli2.jsonc does that, and says why it has to be there:
//
//   "customRules": ["<path to>/assets/rules/table-row-outside-table.js"]

module.exports = {
  names: ["EG001", "table-row-outside-table"],
  description: "Line looks like a table row but is not in a table",
  tags: ["tables"],
  parser: "micromark",
  function: function tableRowOutsideTable(params, onError) {
    const skipped = new Set();
    const walk = (tokens) => {
      for (const token of tokens) {
        if (token.type === "table" || token.type === "codeFenced") {
          for (let line = token.startLine; line <= token.endLine; line++) {
            skipped.add(line);
          }
        }
        if (token.children && token.children.length) walk(token.children);
      }
    };
    walk(params.parsers.micromark.tokens);

    params.lines.forEach((line, index) => {
      const lineNumber = index + 1;
      if (skipped.has(lineNumber)) return;
      // A blockquote marker is not part of the row: `> | a | b |` orphaned inside
      // a quote renders as literal pipes too.
      const text = line.replace(/^\s*(>\s?)+/, "").trim();
      const pipes = (text.match(/\|/g) || []).length;
      if (text.startsWith("|") && text.endsWith("|") && pipes >= 3) {
        onError({
          lineNumber,
          detail:
            "a blank line above it ended the table, so this renders as literal pipes",
        });
      }
    });
  },
};
