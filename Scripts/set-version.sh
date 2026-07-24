#!/bin/bash
#
# Stamps a release version into ScaffoldVersion.swift, replacing the
# development placeholder. The release workflow runs this with the pushed
# tag's number before building, which keeps the tag the single source of the
# version (§20.3): nothing in the repository carries a release number, and the
# smoke test fails the release if the shipped binary disagrees with its tag.
#
# Usage: Scripts/set-version.sh 0.4.0
set -euo pipefail

version="${1:?usage: set-version.sh <version, without the leading v>}"
file="$(dirname "$0")/../Sources/ScaffoldSchema/ScaffoldVersion.swift"

sed -i '' "s/\"0\.0\.0-dev\"/\"${version}\"/" "$file"

grep -q "\"${version}\"" "$file" || {
    echo "Failed to stamp ${version} into ${file} — was the placeholder changed?" >&2
    exit 1
}
