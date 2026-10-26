#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
APP="${BUILD_DIR:-build}/Duo Auto Switch.app"
mkdir -p "$APP/Contents/MacOS"
swiftc -swift-version 5 -O src/KeyProtocol.swift src/kbfwd.swift src/main.swift -o "$APP/Contents/MacOS/duo-auto"
/usr/libexec/PlistBuddy -c 'Clear dict' "$APP/Contents/Info.plist" 2>/dev/null || true
python3 - "$APP" <<'PY'
import plistlib,sys,pathlib
p=pathlib.Path(sys.argv[1])/'Contents/Info.plist'
p.write_bytes(plistlib.dumps(dict(CFBundleIdentifier='ai.joymicro.deskflow-duo.auto',CFBundleName='Duo Auto Switch',CFBundleExecutable='duo-auto',CFBundlePackageType='APPL',CFBundleShortVersionString='0.2.0',LSUIElement=True,NSInputMonitoringUsageDescription='Detect physical input to switch Deskflow direction.')))
PY
# Local ad-hoc signing; not notarization. Stable identifier avoids needless permission churn.
codesign --force --sign "${SIGN_IDENTITY:--}" --identifier ai.joymicro.deskflow-duo.auto -r='designated => identifier "ai.joymicro.deskflow-duo.auto"' "$APP"
codesign --verify --strict "$APP"
echo "Built $APP"
