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

# Generate NScramble.xcodeproj from project.yml
project:
    xcodegen generate

# Build the app for macOS
build-mac: project
    xcodebuild -project NScramble.xcodeproj -scheme NScramble -destination 'platform=macOS' -derivedDataPath DerivedData build

# Build the app for the iPad simulator
build-ipad: project
    xcodebuild -project NScramble.xcodeproj -scheme NScramble -destination 'generic/platform=iOS Simulator' -derivedDataPath DerivedData build

# Build and run the macOS app
run-mac: build-mac
    -osascript -e 'quit app "NScramble"' 2>/dev/null
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
