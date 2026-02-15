#!/usr/bin/env fish

function die
    echo "error: $argv" >&2
    exit 1
end

set -l TOPIC $argv[1]
test -n "$TOPIC"; or die "Usage: newtopic <topic-title>"

set -l SCRIPT (status --current-filename)
test -n "$SCRIPT"; or die "cannot determine script path"

if type -q path
    set -l SCRIPTDIR (path dirname -- $SCRIPT)
else
    set -l SCRIPTDIR (dirname -- $SCRIPT)
end
set -l ROOT (cd "$SCRIPTDIR/.."; or die "cannot cd to project root"; pwd)

set -l TEMPLATE "$ROOT/notes/templates/topic.md"
test -f "$TEMPLATE"; or die "missing template: $TEMPLATE"

set -l DATE (date -I)

# filename-safe slug
set -l SLUG (string lower -- "$TOPIC")
set SLUG (string replace -a " " "-" -- $SLUG)
set SLUG (string replace -ar "[^a-z0-9-_]" "" -- $SLUG)

test -n "$SLUG"; or die "topic slug became empty; choose a different title"

set -l OUT "$ROOT/notes/topics/$SLUG.md"
mkdir -p (dirname -- "$OUT"); or die "cannot create topic directory"

if test -f "$OUT"
    echo "Topic note exists: $OUT"
else
    set -l content (string collect < "$TEMPLATE"); or die "cannot read template"

    set content (string replace -a "{{TOPIC}}" "$TOPIC" -- $content)
    set content (string replace -a "{{DATE}}"  "$DATE"  -- $content)

    printf "%s" "$content" > "$OUT"; or die "cannot write topic note: $OUT"
    echo "Created: $OUT"
end

set -l EDITOR_CMD $EDITOR
test -n "$EDITOR_CMD"; or set EDITOR_CMD vim
$EDITOR_CMD "$OUT"; or die "editor failed: $EDITOR_CMD"
