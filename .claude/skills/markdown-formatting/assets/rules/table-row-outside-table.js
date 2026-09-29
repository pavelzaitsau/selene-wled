// A line that looks like a table row but sits outside any table.
//
// GitHub Flavored Markdown starts a table at a header plus a delimiter row. A
// blank line ends it, so a row written below that blank line is a paragraph:
// it renders as literal pipes, and the content is silently not in the table.
//
// No built-in rule catches this. MD055 and MD056 check pipe style and column
// count *within* a parsed table, and the orphaned line was never parsed as one,
// so both stay quiet. Measured on 2026-09-14: a row separated from its table by
// one blank line passed a whole gate and reached review as raw pipes on the
// rendered page.
//
// Rows inside fenced code are skipped, because a fence holds whatever it holds.
// Inline code such as `a | b` never matches: the test is a line that both opens
// and closes with a pipe.
//
// markdownlint-cli2 loads this through `customRules` in the consuming project's
// own config, because `customRules` is a cli2 option and not a markdownlint one:
//
//   "customRules": ["<path to>/assets/rules/table-row-outside-table.js"]

module.exports = {
  names: ["EG001", "table-row-outside-table"],
  description: "Line looks like a table row but is not in a table",
  tags: ["tables"],
  parser: "micromark",
  function: function tableRowOutsideTable(params, onError) {
    const inTable = new Set();
    const walk = (tokens) => {
      for (const token of tokens) {
        if (token.type === "table") {
          for (let line = token.startLine; line <= token.endLine; line++) {
            inTable.add(line);
          }
        }
        if (token.children && token.children.length) walk(token.children);
      }
    };
    walk(params.parsers.micromark.tokens);

    const fenced = new Set();
    let openFence = null;
    params.lines.forEach((line, index) => {
      const fence = /^\s{0,3}(`{3,}|~{3,})/.exec(line);
      if (fence) {
        if (openFence === null) openFence = fence[1][0];
        else if (fence[1][0] === openFence) openFence = null;
      }
      if (openFence !== null) fenced.add(index + 1);
    });

    params.lines.forEach((line, index) => {
      const lineNumber = index + 1;
      if (inTable.has(lineNumber) || fenced.has(lineNumber)) return;
      const text = line.trim();
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
