#!/bin/bash
#
# Prints the CHANGELOG section for one version — everything between its
# `## [x.y.z]` heading and the next one — so the GitHub Release can carry the
# notes that were already written instead of a second telling of them.
# Prints nothing (and exits 0) when the version has no section; the workflow
# falls back to generated notes.
#
# Usage: Scripts/release-notes.sh 0.4.0
set -euo pipefail

version="${1:?usage: release-notes.sh <version, without the leading v>}"
changelog="$(dirname "$0")/../CHANGELOG.md"

awk -v ver="$version" '
    $0 ~ "^## \\[" ver "\\]" { inside = 1; next }
    inside && /^## \[/ { exit }
    inside { print }
' "$changelog"
