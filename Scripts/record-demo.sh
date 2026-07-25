#!/bin/bash
#
# Records two sessions into docs/demo/, driving the real binary through a
# pseudo-terminal. Run it after changing either flow so the demos in the README
# cannot drift from what the binary actually says.
#
#   new-preview.txt  the interactive flow: `new Bookshelf --variant ios-swiftui`,
#                    look at the file plan, then Save scaffold.yml and exit
#   new-preset.txt   the one-line flow: the same project at `--preset standard`,
#                    with `--yes`, which asks nothing
#
# Both recordings replace the temporary working directory with a stable stand-in,
# so re-recording an unchanged flow produces no diff and a real change stands out.
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
demo_dir="$root/docs/demo"
mkdir -p "$demo_dir"

echo "Building xscaffold…" >&2
swift build --package-path "$root" >&2
binary="$(swift build --package-path "$root" --show-bin-path)/xscaffold"

workspace="$(mktemp -d)"
trap 'rm -rf "$workspace"' EXIT
cd "$workspace"

# Answers, paced so each question is on screen before its answer arrives:
# bundle identifier (default), architecture (Minimal), environments (none),
# menu: 4 (show the file plan), then 2 (save scaffold.yml and exit).
(
    sleep 1
    printf '\n'
    sleep 0.4
    printf '1\n'
    sleep 0.4
    printf '1\n'
    sleep 1
    printf '4\n'
    sleep 0.8
    printf '2\n'
    sleep 1
) | script -q /dev/null "$binary" new Bookshelf --variant ios-swiftui --skip-git > raw.txt 2>&1 || true

# `script` records the pty's echoes and control characters; strip carriage
# returns and the echoed answer lines' artifacts for a readable transcript, and
# put a stable path where the temporary directory was.
clean() {
    # Both spellings of the workspace: mktemp hands back /var/folders/…, and the
    # binary prints the standardised /private/var/folders/… of the same place.
    tr -d '\r' \
        | sed -e 's/\^D//g' -e "s#/private$workspace#~/work#g" -e "s#$workspace#~/work#g"
}

{
    echo "\$ xscaffold new Bookshelf --variant ios-swiftui"
    echo
    clean < raw.txt
} > "$demo_dir/new-preview.txt"

# The declarative half of the same request: a preset instead of the questions.
# No pty here — `--yes` asks nothing, and `script` refuses a stdin that is not
# a terminal.
rm -rf Bookshelf
"$binary" new Bookshelf --variant ios-swiftui --preset standard --yes \
    > raw-preset.txt 2>&1 || true

{
    echo "\$ xscaffold new Bookshelf --variant ios-swiftui --preset standard --yes"
    echo
    clean < raw-preset.txt
} > "$demo_dir/new-preset.txt"

echo "Wrote $demo_dir/new-preview.txt and $demo_dir/new-preset.txt" >&2
