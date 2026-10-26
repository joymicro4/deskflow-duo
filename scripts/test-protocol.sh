#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
TEST_DIR=$(mktemp -d)
trap 'rm -rf "$TEST_DIR"' EXIT
swiftc -swift-version 5 src/KeyProtocol.swift tests/KeyProtocolTests.swift -o "$TEST_DIR/protocol-tests"
"$TEST_DIR/protocol-tests"
