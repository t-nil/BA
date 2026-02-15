#!/usr/bin/env fish

function die
    echo "error: $argv" >&2
    exit 1
end

type -q rg; or die "ripgrep (rg) not found"

set -l FILTER $argv[1]

set -l SCRIPT (status --current-filename)
test -n "$SCRIPT"; or die "cannot determine script path"

if type -q path
    set -l SCRIPTDIR (path dirname -- $SCRIPT)
else
    set -l SCRIPTDIR (dirname -- $SCRIPT)
end
set -l ROOT (cd "$SCRIPTDIR/.."; or die "cannot cd to project root"; pwd)

set -l NOTES "$ROOT/notes/papers"
test -d "$NOTES"; or die "notes directory not found: $NOTES"

if test -n "$FILTER"
    echo "== [Q] lines =="
    rg -n --no-heading "^\s*-\s*\[Q\]" "$NOTES"

    echo
    echo "== Use: lines matching '$FILTER' =="
    rg -n --no-heading "^\s*Use:\s*.*$FILTER" "$NOTES"
else
    rg -n --no-heading "^\s*-\s*\[Q\]" "$NOTES"
end
