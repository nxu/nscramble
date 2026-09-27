packages := "ScrambleKit StatsKit Storage TimerKit"
ipad := "iPad (A16)"
iphone := "iPhone 17"
bundle_id := "hu.nxu.nscramble"

default:
    @just --list

# Run all Swift package tests
test:
    #!/usr/bin/env bash
    set -euo pipefail
    for p in {{packages}}; do
        echo "== $p"
        (cd Packages/$p && swift test)
    done

# Regenerate the cubing.js reference fixture used by ScrambleKit tests
cubingjs-fixture:
    cd scripts/cubingjs-fixture && bun install && bun generate.ts

# Redraw the app icon (scripts/app-icon.swift) into the asset catalog
app-icon:
    swift scripts/app-icon.swift App/Resources/Assets.xcassets/AppIcon.appiconset

# Generate NScramble.xcodeproj from project.yml
project:
    xcodegen generate

# Build the app for macOS
build-mac: project
    xcodebuild -project NScramble.xcodeproj -scheme NScramble -destination 'platform=macOS' -derivedDataPath DerivedData build

# Build the app for the iPad simulator
build-ipad: project
    xcodebuild -project NScramble.xcodeproj -scheme NScramble -destination 'generic/platform=iOS Simulator' -derivedDataPath DerivedData build

# Release build of the Mac app, zipped into dist/ (e.g. `just package-mac 1.2.3 42`)
package-mac version build="1": project
    #!/usr/bin/env bash
    set -euo pipefail
    # CFBundleShortVersionString must be numeric: 1.2.3-beta.1 -> 1.2.3 (the file name keeps the full version).
    xcodebuild -project NScramble.xcodeproj -scheme NScramble -configuration Release \
        -destination 'generic/platform=macOS' -derivedDataPath DerivedData \
        MARKETING_VERSION="$(echo "{{version}}" | cut -d- -f1)" CURRENT_PROJECT_VERSION="{{build}}" build
    mkdir -p dist
    ditto -c -k --keepParent DerivedData/Build/Products/Release/NScramble.app "dist/NScramble-{{version}}-macos.zip"

# Release build of the iPhone/iPad app as an unsigned IPA in dist/ (e.g. `just package-ios 1.2.3 42`)
package-ios version build="1": project
    #!/usr/bin/env bash
    set -euo pipefail
    xcodebuild -project NScramble.xcodeproj -scheme NScramble -configuration Release \
        -destination 'generic/platform=iOS' -derivedDataPath DerivedData \
        MARKETING_VERSION="$(echo "{{version}}" | cut -d- -f1)" CURRENT_PROJECT_VERSION="{{build}}" \
        CODE_SIGNING_ALLOWED=NO build
    rm -rf dist/ipa && mkdir -p dist/ipa/Payload
    cp -R DerivedData/Build/Products/Release-iphoneos/NScramble.app dist/ipa/Payload/
    (cd dist/ipa && zip -qr "../NScramble-{{version}}-ios-unsigned.ipa" Payload)
    rm -rf dist/ipa

# Build and run the macOS app
run-mac: build-mac
    -osascript -e 'quit app "NScramble"' 2>/dev/null
    sleep 1
    @# Refresh Launch Services so the Dock picks up a changed icon.
    /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f DerivedData/Build/Products/Debug/NScramble.app
    open DerivedData/Build/Products/Debug/NScramble.app

# Build and run the app on an iOS simulator (default: the iPad one)
run-sim device=ipad: build-ipad
    -xcrun simctl boot "{{device}}" 2>/dev/null
    @# Newer Xcodes replace Simulator.app with DeviceHub.app.
    dev="$(xcode-select -p)"; if [ -d "$dev/Applications/Simulator.app" ]; then open "$dev/Applications/Simulator.app"; else open "$dev/../Applications/DeviceHub.app"; fi
    xcrun simctl install "{{device}}" DerivedData/Build/Products/Debug-iphonesimulator/NScramble.app
    xcrun simctl launch --terminate-running-process "{{device}}" {{bundle_id}}

# Build and run the app on the iPhone simulator
run-iphone: (run-sim iphone)

# Build and run the app on the iPad simulator
run-ipad: (run-sim ipad)

# Open the project in Xcode
open: project
    open NScramble.xcodeproj
