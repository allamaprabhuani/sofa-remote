#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
LOCATION=(--scratch-path "${SOFA_BUILD_DIR:-.build}")
EXTRA=()
# Standalone command-line tools can lack automatic discovery of the Swift Testing plugin.
SWIFT_BIN="$(xcrun --find swift)"
PLUGIN="$(dirname "$SWIFT_BIN")/../lib/swift/host/plugins/testing/libTestingMacros.dylib"
if [ -f "$PLUGIN" ]; then EXTRA=(-Xswiftc -load-plugin-library -Xswiftc "$PLUGIN"); fi
swift test "${LOCATION[@]}" --disable-xctest ${EXTRA[@]+"${EXTRA[@]}"}
node Tests/Web/transport.test.cjs
node Tests/Web/remote.test.cjs
python3 Tests/Signing/signing_test.py
