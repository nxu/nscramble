packages := "ScrambleKit StatsKit Storage TimerKit"

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

# Open the project in Xcode
open: project
    open NScramble.xcodeproj
