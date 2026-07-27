#!/bin/bash
set -e
cd "$(dirname "$0")"

swift build -c release

APP="FurFMDevice.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp .build/release/FurFMDevice "$APP/Contents/MacOS/FurFMDevice"
cp Sources/FurFMDevice/Info.plist "$APP/Contents/Info.plist"
codesign --force --deep -s - "$APP"

echo "Built $APP"
