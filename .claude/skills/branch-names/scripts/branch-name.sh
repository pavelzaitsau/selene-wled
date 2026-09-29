#!/bin/sh
# Build a branch name to the convention, or check one.
#
#   branch-name.sh [--type <type>] [--create] <ticket|-> <description...>
#   branch-name.sh --check [<name>]        (default: the current branch)
#
# Exit: 0 ok, 1 check failed, 2 usage or no type inferred, 3 name already taken.
set -u

TYPES="feat fix perf refactor test docs build ci chore revert release"

# A project may add a prefix; it may not redefine one. Two ways to add:
#   git config branch-names.extra-types "ticket spike"
#   BRANCH_TYPES_EXTRA="ticket" branch-name.sh ...
extra=""
if command -v git >/dev/null 2>&1; then
  extra=$(git config --get branch-names.extra-types 2>/dev/null) || extra=""
fi
TYPES=$(echo $TYPES ${BRANCH_TYPES_EXTRA:-} $extra)
TARGET=40   # the budget
WALL=50     # the limit
MAX_WORDS=4
PROTECTED="main master"

say() { echo "branch-name: $1" >&2; }

usage() {
  cat >&2 <<'EOF'
usage: branch-name.sh [--type <type>] [--create] <ticket|-> <description...>
       branch-name.sh --check [<name>]
EOF
  exit 2
}

lower() { tr '[:upper:]' '[:lower:]'; }

is_type() {
  for t in $TYPES; do
    if [ "$1" = "$t" ]; then return 0; fi
  done
  return 1
}

# ---------------------------------------------------------------- check

check() {
  name="$1"
  fail=0

  # A protected branch passes every check, including through --check. It was
  # never named to this convention and renaming it is not the answer.
  for p in $PROTECTED; do
    if [ "$name" = "$p" ]; then return 0; fi
  done

  case "$name" in
    # `[[:upper:]]` and not `[A-Z]`: a glob range walks the locale's collation
    # order, and `en_US.UTF-8` orders letters `aAbB...zZ`, so almost every
    # lower-case letter sorts inside `A` to `Z`. Under that locale the range
    # rejected `build/compose-host-hephaestus` for upper case it does not have.
    *[[:upper:]]*) say "upper case is not allowed: $name"; fail=1 ;;
  esac

  # The shape check below also rejects a second slash, but with the generic
  # message. Report the specific fault instead, and stay quiet about shape.
  shape_reported=0
  rest=${name#*/}
  case "$rest" in
    */*) say "more than one slash; git refuses a branch and a directory of one name"
         fail=1; shape_reported=1 ;;
  esac

  # A release branch carries a version, and a version carries dots:
  # `release/2026.3`. Every other type takes words, where a dot is a typo.
  # `git check-ref-format` below still rejects `..` and a `.lock` suffix.
  if [ "${name%%/*}" = "release" ]; then
    shape='^[a-z]+/[a-z0-9]+([.-][a-z0-9]+)*$'
    expected='expected release/<version>, lower case, hyphens and dots'
  else
    shape='^[a-z]+/[a-z0-9]+(-[a-z0-9]+)*$'
    expected='expected <type>/[<ticket>-]<slug>, lower case and hyphens'
  fi

  if ! echo "$name" | grep -qE "$shape"; then
    [ "$shape_reported" -eq 1 ] || say "$expected"
    fail=1
  fi

  prefix=${name%%/*}
  if [ "$prefix" = "$name" ]; then
    say "no type prefix: $name"
    fail=1
  elif ! is_type "$prefix"; then
    say "unknown type '$prefix', expected one of: $TYPES"
    fail=1
  fi

  len=$(printf '%s' "$name" | wc -c | tr -d ' ')
  if [ "$len" -gt "$WALL" ]; then
    say "$len characters, over the $WALL limit"
    fail=1
  elif [ "$len" -gt "$TARGET" ]; then
    say "$len characters, budget is $TARGET"
  fi

  if command -v git >/dev/null 2>&1; then
    git check-ref-format --branch "$name" >/dev/null 2>&1 || {
      say "git refuses this ref name"
      fail=1
    }
  fi

  return "$fail"
}

# ------------------------------------------------------------- generate

# The type lists are spelled out word for word, and matched word for word.
# A stem glob reads `doc` inside `docker`, `test` inside `latest`, `hang`
# inside `change` and `bug` inside `debug`, and each of those named the
# wrong type. Where a stem needs its endings, the endings are listed.
T_REVERT="revert reverts reverted reverting rollback"
T_FIX="fix fixes fixed bug bugs defect defects regression regressions regressed \
broken breaks fails failed failing failure crash crashes wrong incorrect \
leak leaks leaking stale error errors timeout timeouts hangs race races \
duplicate duplicates duplicated duplication corrupt corrupted corruption \
ignored lost stuck missing"
T_DOCS="doc docs document documents documented documenting documentation \
readme changelog comment comments guide guides"
T_TEST="test tests testing coverage flaky fixture fixtures"
T_PERF="slow slower slowness latency speed faster memory cache caching throughput"
T_REFACTOR="refactor refactors refactored refactoring rename renames renamed \
extract extracts split splits simplify simplifies simplified cleanup clean tidy"
T_BUILD="dependency dependencies bump bumps lockfile package packages packaging \
docker dockerfile upgrade upgrades vendor"
T_CI="pipeline pipelines workflow workflows ci hook hooks actions runner"
T_FEAT="add adds added new support supports implement introduce allow allows \
enable enables accept accepts expose exposes option options flag flags \
command commands endpoint endpoints"

# 0 where any word of $2 appears in the list $1.
has_word() {
  for _w in $2; do
    for _l in $1; do
      if [ "$_w" = "$_l" ]; then return 0; fi
    done
  done
  return 1
}

infer_type() {
  ws=$(printf '%s' "$1" | tr -c 'a-z0-9' ' ')
  has_word "$T_REVERT"   "$ws" && { echo revert;   return 0; }
  has_word "$T_FIX"      "$ws" && { echo fix;      return 0; }
  has_word "$T_DOCS"     "$ws" && { echo docs;     return 0; }
  has_word "$T_TEST"     "$ws" && { echo test;     return 0; }
  has_word "$T_PERF"     "$ws" && { echo perf;     return 0; }
  has_word "$T_REFACTOR" "$ws" && { echo refactor; return 0; }
  has_word "$T_BUILD"    "$ws" && { echo build;    return 0; }
  has_word "$T_CI"       "$ws" && { echo ci;       return 0; }
  has_word "$T_FEAT"     "$ws" && { echo feat;     return 0; }
  return 1
}

# Words that carry no fact in a slug. `not` and `no` are deliberately absent:
# dropping a negation inverts the name.
STOPWORDS="a an and are as at be been by for from has have in into is it its of on or so that the this to was were will with our we already still just also very after before during when while then than about if up out off down again every"

is_stopword() {
  for sw in $STOPWORDS; do
    if [ "$1" = "$sw" ]; then return 0; fi
  done
  return 1
}

# The type word itself, repeated in the slug, says the same thing twice.
is_type_echo() {
  case "$2" in
    feat) case "$1" in add|adds|added|adding|new|introduce|implement) return 0 ;; esac ;;
    fix) case "$1" in fix|fixes|fixed|fixing|bugfix) return 0 ;; esac ;;
    docs) case "$1" in document|documents|documenting|docs) return 0 ;; esac ;;
    test) case "$1" in test|tests) return 0 ;; esac ;;
    refactor) case "$1" in refactor|refactors|refactoring) return 0 ;; esac ;;
    revert) case "$1" in revert|reverts) return 0 ;; esac ;;
  esac
  return 1
}

normalise_ticket() {
  t=$(printf '%s' "$1" | lower | tr -cd 'a-z0-9-')
  t=${t#-}
  printf '%s' "$t"
}

generate() {
  type_opt="$1"; create="$2"; ticket_arg="$3"; shift 3
  desc=$(printf '%s' "$*" | lower)
  [ -n "$desc" ] || usage

  type="$type_opt"
  if [ -z "$type" ]; then
    type=$(infer_type "$desc") || {
      say "no type inferred from the description; pass --type, one of: $TYPES"
      exit 2
    }
  fi
  is_type "$type" || { say "unknown type '$type', expected one of: $TYPES"; exit 2; }

  ticket=""
  case "$ticket_arg" in
    -|none|no|"") ticket="" ;;
    *) ticket=$(normalise_ticket "$ticket_arg")
       [ -n "$ticket" ] || { say "ticket '$ticket_arg' has no usable characters"; exit 2; } ;;
  esac

  words=$(printf '%s' "$desc" | tr -c 'a-z0-9' ' ')
  slug=""
  count=0
  for w in $words; do
    [ -n "$w" ] || continue
    if is_stopword "$w"; then continue; fi
    # A version like 0.9 splits into single digits that carry nothing.
    case "$w" in [0-9]) continue ;; esac
    if [ -z "$slug" ] && is_type_echo "$w" "$type"; then
      continue
    fi
    slug="${slug:+$slug-}$w"
    count=$((count + 1))
    if [ "$count" -ge "$MAX_WORDS" ]; then break; fi
  done
  [ -n "$slug" ] || { say "the description left no words for a slug"; exit 2; }

  # Drop trailing words until the whole name fits, keeping at least one.
  name="$type/${ticket:+$ticket-}$slug"
  while [ "$(printf '%s' "$name" | wc -c | tr -d ' ')" -gt "$TARGET" ]; do
    case "$slug" in
      *-*) slug=${slug%-*} ;;
      *) break ;;
    esac
    name="$type/${ticket:+$ticket-}$slug"
  done

  if ! check "$name"; then
    exit 1
  fi

  if command -v git >/dev/null 2>&1 && git rev-parse --git-dir >/dev/null 2>&1; then
    if git show-ref --verify --quiet "refs/heads/$name"; then
      say "branch $name already exists; switch to it or name a different change"
      exit 3
    fi
  fi

  echo "$name"
  if [ "$create" -eq 1 ]; then
    git switch -c "$name" || exit 1
  fi
  return 0
}

# ----------------------------------------------------------------- main

[ $# -gt 0 ] || usage

if [ "$1" = "--check" ]; then
  shift
  target=${1:-}
  if [ -z "$target" ]; then
    target=$(git rev-parse --abbrev-ref HEAD) || exit 2
  fi
  check "$target" || exit 1
  exit 0
fi

type_opt=""
create=0
while [ $# -gt 0 ]; do
  case "$1" in
    --type) shift; type_opt=${1:-}; [ -n "$type_opt" ] || usage; shift ;;
    --type=*) type_opt=${1#--type=}; shift ;;
    --create) create=1; shift ;;
    -h|--help) usage ;;
    --) shift; break ;;
    -) break ;;
    -*) say "unknown option $1"; usage ;;
    *) break ;;
  esac
done

[ $# -ge 2 ] || usage
generate "$type_opt" "$create" "$@"
