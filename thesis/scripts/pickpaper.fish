#!/usr/bin/env fish

function die
    echo "error: $argv" >&2
    exit 1
end

type -q fzf; or die "fzf not found"

set -l SCRIPT (status --current-filename)
test -n "$SCRIPT"; or die "cannot determine script path"

if type -q path
    set -l SCRIPTDIR (path dirname -- $SCRIPT)
else
    set -l SCRIPTDIR (dirname -- $SCRIPT)
end
set -l ROOT (cd "$SCRIPTDIR/.."; or die "cannot cd to project root"; pwd)

set -l DIR "$ROOT/notes/papers"
test -d "$DIR"; or die "notes directory not found: $DIR"

set -l FILE (find "$DIR" -maxdepth 1 -type f -name "*.md" | sort | fzf)
test -n "$FILE"; or exit 0

set -l EDITOR_CMD $EDITOR
test -n "$EDITOR_CMD"; or set EDITOR_CMD vim
$EDITOR_CMD "$FILE"; or die "editor failed: $EDITOR_CMD"
