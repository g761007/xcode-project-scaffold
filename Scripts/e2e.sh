#!/bin/bash
#
# The end-to-end layer of §12.1: create a project per preset with the real
# binary, then put the real toolchain through it — `xscaffold init`, which runs
# git and XcodeGen itself, followed by `xcodebuild build` and `xcodebuild test`.
#
# It exists for what the layers below it cannot see. Contract snapshots compare
# file lists and `project.yml`; they do not compile anything, so a template that
# renders perfectly well and does not build, or a `project.yml` that XcodeGen
# accepts and Xcode rejects, reaches here untouched.
#
# Run it with `make e2e`. It needs xcodegen on the PATH and a git identity.

set -euo pipefail

cd "$(dirname "$0")/.."

# An explicit udid, never a device name (§12.2). The same device exists under
# every installed runtime that shipped it, and given the name alone xcodebuild
# warns and takes one of them — leaving nobody able to say what the green tick
# tested. Which device is not important; knowing which one is.
simulator="$(
    xcrun simctl list devices available --json | python3 -c '
import json, sys

candidates = []
for identifier, devices in json.load(sys.stdin)["devices"].items():
    _, _, version = identifier.partition(".SimRuntime.iOS-")
    if not version:
        continue
    iphones = sorted((d for d in devices if d["name"].startswith("iPhone")), key=lambda d: d["name"])
    if iphones:
        candidates.append((tuple(int(part) for part in version.split("-")), iphones[0]))

if not candidates:
    sys.exit("No iPhone simulator is available. Install an iOS runtime in Xcode.")

version, device = max(candidates, key=lambda candidate: candidate[0])
print(device["udid"], device["name"], "(iOS " + ".".join(str(part) for part in version) + ")")
'
)"
read -r udid device <<<"$simulator"

swift build -c release --product xscaffold
xscaffold="$(swift build -c release --show-bin-path)/xscaffold"

root="$(mktemp -d)"
echo "Simulator:  $device $udid"
echo "Projects:   $root"

# Creates one project and puts the toolchain through it. The scheme is the
# project's own name, which is the one Xcode selects when the project is opened
# — so this checks what a user meets first, not a scheme chosen to pass.
check() {
    local name="$1"
    shift
    local project="$root/$name/$name.xcodeproj"

    echo
    echo "==> $name"
    "$xscaffold" init "$name" "$@" --destination "$root/$name"

    # Separately from the test run, which would build anyway: a compile error
    # and a failing test are different problems, and this says which one it is.
    # `-quiet` still prints warnings and errors, so a build that fails is as
    # legible as a verbose one, minus every command that succeeded.
    xcodebuild build -project "$project" -scheme "$name" -destination "id=$udid" -quiet

    # Deliberately not `-quiet`: under it a failing test run prints
    # `** TEST FAILED **` and nothing else — not which test, not what it
    # expected. The whole run is a few dozen lines once the build above is done.
    xcodebuild test -project "$project" -scheme "$name" -destination "id=$udid"
}

check UIKitApp --preset ios-uikit
check SwiftUIApp --preset ios-swiftui

# Environments, which no preset produces and which the two runs above therefore
# say nothing about. They earn a case of their own because they change the
# generated schemes: the default scheme belongs to the Release environment, and
# a project whose first ⌘U cannot compile its own tests is broken on arrival.
cat > "$root/environments.yml" <<'YML'
project:
  name: EnvApp
  bundleIdentifier: com.example.envapp
interface:
  primary: swiftui
environments:
  - name: development
    configuration: Debug
    bundleIdentifierSuffix: .dev
    displayNameSuffix: " Dev"
  - name: staging
    configuration: Staging
    bundleIdentifierSuffix: .stg
    displayNameSuffix: " STG"
  - name: production
    configuration: Release
YML
check EnvApp --config "$root/environments.yml"

echo
echo "Every variant generated, built and tested."
