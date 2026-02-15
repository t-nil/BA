#!/usr/bin/env fish

function die
    echo "error: $argv" >&2
    exit 1
end

# Options:
#   -m/--missing : show only missing notes
#   -f/--found   : show only found notes
#   -h/--help
argparse h/help m/missing f/found -- $argv; or exit 2

if set -q _flag_help
    echo "Usage: bibnotes.fish"
    echo "  -m, --missing   show only missing notes"
    echo "  -f, --found     show only found notes"
    exit 0
end

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

set -l BIB $ROOT/bibliography.bib
test -f "$BIB"; or die "bib file not found: $BIB"

set -l NOTESDIR $ROOT/notes
test -d "$NOTESDIR"; or die "notes directory not found: $NOTESDIR"

# Collect citekeys (simple one-line entry header regex)
set -l keys
while read -l line
    # Captures citekey in patterns like:
    #   @type{citekey,
    #   @type(citekey,
    set -l k (string match -r --groups-only '^\s*@\w+\s*[{(]\s*([^,\s]+)\s*,' -- $line)
    if test -n "$k"
        set -a keys $k
    end
end < "$BIB"

if test (count $keys) -eq 0
    die "no citekeys found (expected lines like: @article{key, ...})"
end

# Deduplicate (external `sort` is the simplest reliable way)
set -l uniq (printf "%s\n" $keys | sort -u)

# Header
set_color --bold
printf "%-6s  %s\n" "NOTE" "CITEKEY"
set_color normal
printf "%-6s  %s\n" "----" "------------------------------"

set -l found 0
set -l missing 0

for k in $uniq
    set -l note ""
    # consider both .md and .typ notes (edit list to taste)
    for ext in md typ
        if test -f "$NOTESDIR/$k.$ext"
            set note "$NOTESDIR/$k.$ext"
            break
        end
    end

    if test -n "$note"
        set found (math $found + 1)
        if set -q _flag_missing
            continue
        end
        set_color green
        printf "%-6s" "FOUND"
        set_color normal
        printf "  %s\n" "$k"
    else
        set missing (math $missing + 1)
        if set -q _flag_found
            continue
        end
        set_color red
        printf "%-6s" "MISS"
        set_color normal
        printf "  %s\n" "$k"
    end
end

echo
set_color --bold
printf "Total: %d | " (count $uniq)
set_color green
printf "FOUND %d " $found
set_color normal
printf "| "
set_color red
printf "MISSING %d\n" $missing
set_color normal
