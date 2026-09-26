PACKAGES := ScrambleKit StatsKit Storage
# Command Line Tools-only setups sometimes do not load the Swift Testing macro plugin; pass it explicitly.
TESTING_PLUGINS := $(shell xcode-select -p)/usr/lib/swift/host/plugins/testing
SWIFT_TEST_FLAGS := $(if $(wildcard $(TESTING_PLUGINS)),-Xswiftc -plugin-path -Xswiftc $(TESTING_PLUGINS))

.PHONY: test test-swift test-worker project
test: test-swift test-worker

test-swift:
	@for p in $(PACKAGES); do echo "== $$p"; (cd Packages/$$p && swift test $(SWIFT_TEST_FLAGS)) || exit 1; done

test-worker:
	cd worker && bun run typecheck

project:
	xcodegen generate
