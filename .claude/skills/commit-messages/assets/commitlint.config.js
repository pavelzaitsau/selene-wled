// Conventional Commits 1.0.0, tuned to the commit-messages skill.
//   npm i -D @commitlint/cli @commitlint/config-conventional
module.exports = {
  extends: ['@commitlint/config-conventional'],
  rules: {
    'type-enum': [
      2,
      'always',
      ['feat', 'fix', 'perf', 'refactor', 'test', 'docs', 'build', 'ci', 'chore', 'revert'],
    ],
    'type-case': [2, 'always', 'lower-case'],
    'scope-case': [2, 'always', 'lower-case'],
    'subject-empty': [2, 'never'],
    'subject-full-stop': [2, 'never', '.'],
    'header-max-length': [2, 'always', 72],
    'header-min-length': [2, 'always', 15],

    // Off, with the next two: references/enforcement.md says why.
    'subject-case': [0],
    'body-max-line-length': [0],
    'footer-max-line-length': [0],

    'body-leading-blank': [2, 'always'],
    'footer-leading-blank': [2, 'always'],
  },
};
