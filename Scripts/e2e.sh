#!/bin/bash
#
# The end-to-end layer of §12.1: create a project per variant with the real
# binary, then put the real toolchain through it — `xscaffold generate` (or the
# one-line `new --variant --yes`), which runs git, XcodeGen and — for the
# dependency matrix — CocoaPods itself, followed by `xcodebuild build` and
# `xcodebuild test`.
#
# It exists for what the layers below it cannot see. Contract snapshots compare
# file lists and `project.yml`; they do not compile anything, so a template that
# renders perfectly well and does not build, or a `project.yml` that XcodeGen
# accepts and Xcode rejects, reaches here untouched.
#
# Run it with `make e2e`. It needs xcodegen and pod on the PATH, a git
# identity, and network access for package resolution and pod installs.

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
    "$xscaffold" generate "$@" --yes --destination "$root/$name"

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

# The macOS equivalent of check(): the destination is the host mac, not a
# simulator, and code signing is switched off so a bare CI runner with no
# signing identity can still build and launch the test host.
check_macos() {
    local name="$1"
    shift
    local project="$root/$name/$name.xcodeproj"

    echo
    echo "==> $name (macOS)"
    "$xscaffold" generate "$@" --yes --destination "$root/$name"

    xcodebuild build -project "$project" -scheme "$name" \
        -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO -quiet
    xcodebuild test -project "$project" -scheme "$name" \
        -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO CODE_SIGN_IDENTITY=-
}

one_line() {
    local name="$1" variant="$2"
    echo
    echo "==> $name (new --variant $variant --yes)"
    "$xscaffold" new "$name" --variant "$variant" --yes --destination "$root/$name"

    xcodebuild build -project "$root/$name/$name.xcodeproj" -scheme "$name" \
        -destination "id=$udid" -quiet
    xcodebuild test -project "$root/$name/$name.xcodeproj" -scheme "$name" \
        -destination "id=$udid"
}

one_line_macos() {
    local name="$1" variant="$2"
    echo
    echo "==> $name (new --variant $variant --yes, macOS)"
    "$xscaffold" new "$name" --variant "$variant" --yes --destination "$root/$name"

    xcodebuild build -project "$root/$name/$name.xcodeproj" -scheme "$name" \
        -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO -quiet
    xcodebuild test -project "$root/$name/$name.xcodeproj" -scheme "$name" \
        -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO CODE_SIGN_IDENTITY=-
}

one_line UIKitApp ios-uikit
one_line SwiftUIApp ios-swiftui

# The MVVM architecture example, which no preset produces: it replaces the app's
# main screen with a view and a concrete view model, and ships its own tests.
# The plain variants above never compile that code, so it earns a run of its own.
cat > "$root/mvvm-uikit.yml" <<'YML'
project:
  name: MVVMApp
  bundleIdentifier: com.example.mvvmapp
interface:
  primary: uikit
architecture:
  pattern: mvvm
  includeExample: true
YML
check MVVMApp --config "$root/mvvm-uikit.yml"

# The same architecture on SwiftUI: the view observes an @Observable view model
# instead of binding through a closure. It is the second interface that proves
# the overlay's shared boundary, exactly as the two plain variants did in v0.1.
cat > "$root/mvvm-swiftui.yml" <<'YML'
project:
  name: MVVMSwiftUIApp
  bundleIdentifier: com.example.mvvmswiftuiapp
interface:
  primary: swiftui
architecture:
  pattern: mvvm
  includeExample: true
YML
check MVVMSwiftUIApp --config "$root/mvvm-swiftui.yml"

# MVVM-C on UIKit: a coordinator driving a list and a detail screen. It restructures
# the app more than MVVM does — the plain root screen is gone — so a build and a run
# of its two screens' view-model tests is the only thing that proves it holds together.
cat > "$root/mvvmc-uikit.yml" <<'YML'
project:
  name: MVVMCApp
  bundleIdentifier: com.example.mvvmcapp
interface:
  primary: uikit
architecture:
  pattern: mvvm-c
  includeExample: true
YML
check MVVMCApp --config "$root/mvvmc-uikit.yml"

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

# macOS, the platform axis v0.3 adds. The two presets cover the plain variants;
# the MVVM overlay ships its own sources, so each interface earns a run of its
# own — SwiftUI observing an @Observable model, AppKit driving one through a
# closure from a code-built NSViewController with no storyboard or xib.
one_line_macos MacSwiftUIApp macos-swiftui
one_line_macos MacAppKitApp macos-appkit

cat > "$root/mvvm-macos-swiftui.yml" <<'YML'
project:
  name: MacMVVMSwiftUIApp
  bundleIdentifier: com.example.macmvvmswiftuiapp
product:
  platform: macos
interface:
  primary: swiftui
architecture:
  pattern: mvvm
  includeExample: true
YML
check_macos MacMVVMSwiftUIApp --config "$root/mvvm-macos-swiftui.yml"

cat > "$root/mvvm-macos-appkit.yml" <<'YML'
project:
  name: MacMVVMAppKitApp
  bundleIdentifier: com.example.macmvvmappkitapp
product:
  platform: macos
interface:
  primary: appkit
architecture:
  pattern: mvvm
  includeExample: true
YML
check_macos MacMVVMAppKitApp --config "$root/mvvm-macos-appkit.yml"

# The dependency matrix (§24.3): representative combinations, not a Cartesian
# product. SPM must resolve on first build; CocoaPods must produce the
# workspace pod install exists for, and the workspace — not the project — must
# build and test, because that is the container users are told to open.
check_pods() {
    local name="$1" config="$2" destination_flags=("${@:3}")
    local workspace="$root/$name/$name.xcworkspace"

    echo
    echo "==> $name (CocoaPods)"
    "$xscaffold" generate --config "$config" --yes --destination "$root/$name"

    test -f "$root/$name/Podfile" || { echo "Podfile missing"; exit 1; }
    test -d "$workspace" || { echo "workspace missing"; exit 1; }

    xcodebuild build -workspace "$workspace" -scheme "$name" "${destination_flags[@]}" -quiet
    xcodebuild test -workspace "$workspace" -scheme "$name" "${destination_flags[@]}"
}

cat > "$root/spm.yml" <<'YML'
project:
  name: SPMApp
  bundleIdentifier: com.example.spmapp
interface:
  primary: swiftui
architecture:
  pattern: mvvm
  includeExample: true
dependencyManagement:
  mode: spm
  spm:
    packages:
      - name: swift-collections
        url: https://github.com/apple/swift-collections.git
        from: "1.1.0"
        products:
          - name: Collections
            targets: [SPMApp]
YML
check SPMApp --config "$root/spm.yml"

cat > "$root/pods.yml" <<'YML'
project:
  name: PodsApp
  bundleIdentifier: com.example.podsapp
interface:
  primary: swiftui
architecture:
  pattern: mvvm
  includeExample: true
dependencyManagement:
  mode: cocoapods
  cocoapods:
    pods:
      - name: SnapKit
        version: "5.7.1"
YML
check_pods PodsApp "$root/pods.yml" -destination "id=$udid"

cat > "$root/mixed.yml" <<'YML'
project:
  name: MixedApp
  bundleIdentifier: com.example.mixedapp
interface:
  primary: swiftui
architecture:
  pattern: mvvm
  includeExample: true
dependencyManagement:
  mode: mixed
  spm:
    packages:
      - name: swift-collections
        url: https://github.com/apple/swift-collections.git
        from: "1.1.0"
        products:
          - name: Collections
            targets: [MixedApp]
  cocoapods:
    pods:
      - name: SnapKit
        version: "5.7.1"
YML
check_pods MixedApp "$root/mixed.yml" -destination "id=$udid"

cat > "$root/pods-macos.yml" <<'YML'
project:
  name: MacPodsApp
  bundleIdentifier: com.example.macpodsapp
product:
  platform: macos
interface:
  primary: appkit
dependencyManagement:
  mode: cocoapods
  cocoapods:
    pods:
      - name: SnapKit
        version: "5.7.1"
YML
check_pods MacPodsApp "$root/pods-macos.yml" \
    -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO CODE_SIGN_IDENTITY=-

echo
echo "Every variant and dependency combination generated, built and tested."
