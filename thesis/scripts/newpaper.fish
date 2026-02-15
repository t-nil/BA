#!/usr/bin/env fish

function die
    echo "error: $argv" >&2
    exit 1
end

set -l CITEKEY $argv[1]
test -n "$CITEKEY"; or die "Usage: newpaper <citekey>"

# Compute project root relative to this script location.
set -l SCRIPT (status --current-filename)
test -n "$SCRIPT"; or die "cannot determine script path (status --current-filename)"

# Prefer fish's `path` builtin when present, fallback to external dirname.
set -l SCRIPTDIR
if type -q path
    set SCRIPTDIR (path dirname -- $SCRIPT)
else
    set SCRIPTDIR (dirname -- $SCRIPT)
end

set -l ROOT (realpath "$SCRIPTDIR/..")
cd $ROOT; or die "cannot cd to project root"

set -l TEMPLATE "$ROOT/notes/templates/paper.md"
set -l OUT      "$ROOT/notes/papers/$CITEKEY.md"
set -l PDF      "$ROOT/papers/$CITEKEY.pdf"
set -l DATE     (date -I)

test -f "$TEMPLATE"; or die "missing template: $TEMPLATE"
mkdir -p (dirname -- "$OUT"); or die "cannot create notes directory"

if test -f "$OUT"
    echo "Note exists: $OUT"
else
    # Read template preserving newlines, then substitute placeholders.
    set -l content (string collect < "$TEMPLATE"); or die "cannot read template"

    # Substitute placeholders and write note (preserves newlines)
    string replace -a "{{CITEKEY}}" "$CITEKEY" < "$TEMPLATE" \
    | string replace -a "{{TITLE}}"   ""        \
    | string replace -a "{{YEAR}}"    ""        \
    | string replace -a "{{SOURCE}}"  ""        \
    | string replace -a "{{DATE}}"    "$DATE"   \
    > "$OUT"; or die "cannot write note: $OUT"

    printf "%s" "$content" > "$OUT"; or die "cannot write note: $OUT"
    echo "Created: $OUT"
end

# --- Open PDF first (best effort, non-fatal) ---
if test -f "$PDF"
    if type -q zathura
        # zathura supports --fork on many installs; use it when available
        zathura --fork "$PDF" >/dev/null 2>&1; or begin
            zathura "$PDF" >/dev/null 2>&1 &
            disown $last_pid
        end
    else if type -q sioyek
        sioyek "$PDF" >/dev/null 2>&1 &
        disown $last_pid
    else if type -q xdg-open
        xdg-open "$PDF" >/dev/null 2>&1 &
        disown $last_pid
    else
        echo "warn: no PDF opener found (zathura/sioyek/xdg-open). PDF at: $PDF" >&2
    end
else
    echo "warn: no PDF found at: $PDF" >&2
end

# --- Then open note in editor (foreground) ---
set -l EDITOR_CMD $EDITOR
test -n "$EDITOR_CMD"; or set EDITOR_CMD vim
$EDITOR_CMD "$OUT"; or die "editor failed: $EDITOR_CMD"
