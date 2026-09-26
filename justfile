packages := "ScrambleKit StatsKit Storage TimerKit"
ipad := "iPad (A16)"
bundle_id := "hu.nxu.nscramble"

default:
    @just --list

# Run all Swift package tests and the sync worker tests
test: worker-test
    #!/usr/bin/env bash
    set -euo pipefail
    for p in {{packages}}; do
        echo "== $p"
        (cd Packages/$p && swift test)
    done

# Test and typecheck the sync worker
worker-test:
    cd worker && bun install --silent && bun test && bunx tsc --noEmit

# Local sync server (worker code on an in-memory database) at http://127.0.0.1:8788, API key "dev-token"
worker-dev:
    cd worker && bun install --silent && SYNC_TOKEN=dev-token bun scripts/dev-server.ts

# Apply D1 migrations and deploy the sync worker to Cloudflare
worker-deploy:
    cd worker && wrangler d1 migrations apply nscramble --remote && wrangler deploy

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

# Build and run the app on the iPad simulator
run-ipad: build-ipad
    -xcrun simctl boot "{{ipad}}" 2>/dev/null
    @# Newer Xcodes replace Simulator.app with DeviceHub.app.
    dev="$(xcode-select -p)"; if [ -d "$dev/Applications/Simulator.app" ]; then open "$dev/Applications/Simulator.app"; else open "$dev/../Applications/DeviceHub.app"; fi
    xcrun simctl install "{{ipad}}" DerivedData/Build/Products/Debug-iphonesimulator/NScramble.app
    xcrun simctl launch --terminate-running-process "{{ipad}}" {{bundle_id}}

# Open the project in Xcode
open: project
    open NScramble.xcodeproj
