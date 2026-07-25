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
    shift 2
    echo
    echo "==> $name (new --variant $variant $* --yes)"
    "$xscaffold" new "$name" --variant "$variant" "$@" --yes --destination "$root/$name"

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

# The generated project's own Makefile, run the way its README tells a user to.
# Everything else here calls xcodebuild directly, with a udid resolved above —
# which is correct for a matrix, and means the recipes the project ships were
# never executed. They were wrong in three ways for three versions because of
# it: a hardcoded simulator, an iOS destination on macOS projects, and the
# `.xcodeproj` where a CocoaPods project needs its workspace.
#
# No `make test` on iOS: it boots a simulator, and the run above has already
# proved the tests pass. What this adds is that the recipes resolve and run.
check_makefile() {
    local name="$1"
    shift
    echo
    echo "==> $name (its own Makefile)"
    "$xscaffold" generate "$@" --yes --destination "$root/$name"

    # Not `make lint`: the linters are the lint job's business and are not
    # installed here. What this proves is that the recipes resolve — a
    # destination that exists, and the container the project is actually
    # driven through.
    ( cd "$root/$name" && make build )
}

one_line UIKitApp ios-uikit
one_line SwiftUIApp ios-swiftui

# The MVVM architecture example, stated directly rather than through the preset
# that also brings it: it replaces the app's main screen with a view and a
# concrete view model, and ships its own tests. The plain variants above never
# compile that code, so it earns a run of its own.
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

# The same example at the exact version its `@Observable` view model needs
# (XS0014). The case above runs at the default target, where the macro has been
# available for releases — so it says nothing about where the boundary is. If
# Observation ever turns out to need more than iOS 17.0, this fails and the
# validator's floor is wrong.
cat > "$root/mvvm-swiftui-floor.yml" <<'YML'
project:
  name: MVVMFloorApp
  bundleIdentifier: com.example.mvvmfloorapp
product:
  deploymentTarget: "17.0"
interface:
  primary: swiftui
architecture:
  pattern: mvvm
  includeExample: true
YML
check MVVMFloorApp --config "$root/mvvm-swiftui-floor.yml"

# And the fix XS0014 suggests: the pattern without its example really does build
# at the project floor, so the suggestion is not a dead end.
cat > "$root/mvvm-swiftui-no-example.yml" <<'YML'
project:
  name: MVVMNoExampleApp
  bundleIdentifier: com.example.mvvmnoexampleapp
product:
  deploymentTarget: "15.0"
interface:
  primary: swiftui
architecture:
  pattern: mvvm
  includeExample: false
YML
check MVVMNoExampleApp --config "$root/mvvm-swiftui-no-example.yml"

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

# Environments, which the runs above say nothing about. They earn a case of
# their own because they change the generated schemes: the default scheme
# belongs to the Release environment, and a project whose first ⌘U cannot
# compile its own tests is broken on arrival.
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

# The widget extension (§11.6). It earns a run because it is the first second
# target the tool generates: only a real build says whether the app-extension
# target links, whether its sources compile against WidgetKit, and whether the
# app still builds with an extension embedded in it. project.yml assertions
# say none of that.
#
# Deliberately at the supported floor rather than the default: the widget's
# sources reach for WidgetKit API that arrived after it, and the compiler only
# checks availability against the deployment target it is given. At 18.0 this
# case passed while a 15.0 project generated, validated and then failed to
# compile — which is exactly the gap e2e exists to close.
#
# Both extensions at once rather than one each: they are separate targets in
# separate directories, so the case that could go wrong is the app embedding
# two of them, not either alone.
cat > "$root/widget.yml" <<'YML'
project:
  name: ExtensionsApp
  bundleIdentifier: com.example.extensionsapp
product:
  deploymentTarget: "15.0"
interface:
  primary: swiftui
extensions:
  widget: {}
  notificationService: {}
YML
check ExtensionsApp --config "$root/widget.yml"

# macOS, the platform axis v0.3 adds. The two one-line runs below cover the
# plain variants; the MVVM overlay ships its own sources, so each interface
# earns a run of its own — SwiftUI observing an @Observable model, AppKit
# driving one through a closure from a code-built NSViewController with no
# storyboard or xib.
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
ci:
  provider: github-actions
YML
check SPMApp --config "$root/spm.yml"

# The ci section lands its workflow files (§21). GitHub CI itself is not run
# here — the files existing and parsing is the generation-side contract, and
# the workflow-shape tests pin their contents.
for workflow in build test lint; do
    test -f "$root/SPMApp/.github/workflows/$workflow.yml" \
        || { echo "$workflow.yml missing"; exit 1; }
done

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

# Bundler and version pinning (§11.4) — the reason enterprise teams reach for
# CocoaPods in the first place. Generation runs `bundle install` and then
# `bundle exec pod install`, so the pods are installed by the CocoaPods the
# Gemfile names rather than by whatever happens to be on the machine. The plan
# tests assert that sequence; only a run proves it succeeds.
cat > "$root/bundler.yml" <<'YML'
project:
  name: BundlerApp
  bundleIdentifier: com.example.bundlerapp
interface:
  primary: swiftui
dependencyManagement:
  mode: cocoapods
  cocoapods:
    bundler:
      enabled: true
      cocoapodsVersion: "1.16.2"
    pods:
      - name: SnapKit
        version: "5.7.1"
YML
check_pods BundlerApp "$root/bundler.yml" -destination "id=$udid"

# The Gemfile carries the pin xscaffold wrote, and `bundle install` left its
# lock beside it — which together are what make the version reproducible.
test -f "$root/BundlerApp/Gemfile" || { echo "Gemfile missing"; exit 1; }
grep -q "cocoapods', '1.16.2'" "$root/BundlerApp/Gemfile" \
    || { echo "Gemfile does not pin the requested CocoaPods"; exit 1; }
test -f "$root/BundlerApp/Gemfile.lock" || { echo "Gemfile.lock missing"; exit 1; }

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

# The preset axis (§17). Every case above states its fields directly, so none of
# them says whether a preset's own combination compiles — and a preset is the
# one thing here nobody reviews field by field before generating, because
# choosing it is the whole point.
#
# Each runs at the floor its own contents impose, not at the default target
# (§24.3, and the v0.6 lesson: the default target hid an availability bug for
# two releases). That floor is not one number. Both presets bring the MVVM
# example, and the SwiftUI example observes through `@Observable`, which arrived
# in iOS 17 — so `standard` on SwiftUI cannot go below 17.0 and the validator
# says so (XS0014), while the UIKit example observes through a closure and
# builds at the project floor of 15.0. The two cases take one floor each.
#
# Stated as `preset:` in a document rather than passed as `--preset`: the flag
# routes through the document, so the resolution under test is the same one,
# and only a document can also pin the deployment target these cases exist for.
cat > "$root/preset-standard.yml" <<'YML'
preset: standard
project:
  name: PresetStandardApp
  bundleIdentifier: com.example.presetstandardapp
product:
  deploymentTarget: "17.0"
interface:
  primary: swiftui
YML
check PresetStandardApp --config "$root/preset-standard.yml"

cat > "$root/preset-production.yml" <<'YML'
preset: production
project:
  name: PresetProductionApp
  bundleIdentifier: com.example.presetproductionapp
product:
  deploymentTarget: "15.0"
interface:
  primary: uikit
YML
check PresetProductionApp --config "$root/preset-production.yml"

# production brings UI tests, three environments with values, the xcconfigs
# those imply, a secrets example and CI. The build above proves they compile
# together; these say the files a user was promised are actually there.
for expected in \
    Configurations/Debug.xcconfig \
    Configurations/Staging.xcconfig \
    Configurations/Release.xcconfig \
    Configurations/Secrets.example.xcconfig \
    Resources/en.lproj/Localizable.strings \
    .github/workflows/build.yml
do
    test -f "$root/PresetProductionApp/$expected" \
        || { echo "production preset did not produce $expected"; exit 1; }
done

# production + CocoaPods (§17): the enterprise default nobody switches on by
# hand. Naming the mode is enough — normalization adds Bundler and pins the
# CocoaPods version, so the install runs through `bundle exec` and the whole
# team resolves the same one. The plan tests assert the sequence; only this
# proves it installs, and that the workspace it produces builds and tests.
cat > "$root/preset-production-pods.yml" <<'YML'
preset: production
project:
  name: PresetPodsApp
  bundleIdentifier: com.example.presetpodsapp
product:
  deploymentTarget: "15.0"
interface:
  primary: uikit
dependencyManagement:
  mode: cocoapods
  cocoapods:
    pods:
      - name: SnapKit
        version: "5.7.1"
YML
check_pods PresetPodsApp "$root/preset-production-pods.yml" -destination "id=$udid"

# The flag itself, once. The three cases above name the preset in a document,
# which is where `--preset` routes anyway — but "anyway" is a claim about the
# CLI, and this is the layer that stops taking claims. It runs at the default
# target, because no flag sets the deployment target; the floors are the
# documents' job above.
one_line PresetFlagApp ios-swiftui --preset standard

# Nothing in that document asked for Bundler; the preset did. The pin is the
# point — an unpinned Gemfile would install whatever resolved that day.
test -f "$root/PresetPodsApp/Gemfile" || { echo "production + pods produced no Gemfile"; exit 1; }
grep -q "cocoapods', '1.16.2'" "$root/PresetPodsApp/Gemfile" \
    || { echo "production + pods did not pin the CocoaPods version"; exit 1; }
test -f "$root/PresetPodsApp/Gemfile.lock" || { echo "bundle install left no lock"; exit 1; }

# One per platform, and one through a workspace: the three shapes the Makefile
# renders differently.
cat > "$root/make-ios.yml" <<'YML'
project:
  name: MakeIOSApp
  bundleIdentifier: com.example.makeiosapp
interface:
  primary: swiftui
YML
check_makefile MakeIOSApp --config "$root/make-ios.yml"

cat > "$root/make-mac.yml" <<'YML'
project:
  name: MakeMacApp
  bundleIdentifier: com.example.makemacapp
product:
  platform: macos
interface:
  primary: appkit
YML
check_makefile MakeMacApp --config "$root/make-mac.yml"

cat > "$root/make-pods.yml" <<'YML'
project:
  name: MakePodsApp
  bundleIdentifier: com.example.makepodsapp
interface:
  primary: swiftui
dependencyManagement:
  mode: cocoapods
  cocoapods:
    pods:
      - name: SnapKit
        version: "5.7.1"
YML
check_makefile MakePodsApp --config "$root/make-pods.yml"

echo
echo "Every variant, preset and dependency combination generated, built and tested."
