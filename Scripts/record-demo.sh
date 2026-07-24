#!/bin/bash
#
# Records the interactive preview flow into docs/demo/new-preview.txt, driving
# the real binary through a pseudo-terminal. Run it after changing the flow so
# the demo in the README cannot drift from what the binary actually says.
#
# The session it records: `new Bookshelf --variant ios-swiftui`, look at the
# file plan, then choose Save scaffold.yml and exit.
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

{
    echo "\$ xscaffold new Bookshelf --variant ios-swiftui"
    echo
    # `script` records the pty's echoes and control characters; strip carriage
    # returns and the echoed answer lines' artifacts for a readable transcript.
    tr -d '\r' < raw.txt | sed -e 's/\^D//g'
} > "$demo_dir/new-preview.txt"

echo "Wrote $demo_dir/new-preview.txt" >&2
