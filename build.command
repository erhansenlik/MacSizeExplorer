#!/bin/zsh
set -eu
cd "$(dirname "$0")"
mkdir -p 'MacSizeExplorer.app/Contents/MacOS' 'MacSizeExplorer.app/Contents/Resources'
MACOSX_DEPLOYMENT_TARGET=13.0 swiftc -O -whole-module-optimization -framework Cocoa Source/main.swift -o 'MacSizeExplorer.app/Contents/MacOS/MacSizeExplorer'
cat > 'MacSizeExplorer.app/Contents/Info.plist' <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>MacSizeExplorer</string>
<key>CFBundleIdentifier</key><string>io.github.erhansenlik.macsizeexplorer</string>
<key>CFBundleName</key><string>MacSizeExplorer</string>
<key>CFBundleDisplayName</key><string>MacSizeExplorer</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>1.1.0</string>
<key>LSMinimumSystemVersion</key><string>13.0</string>
<key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
cp LICENSE 'MacSizeExplorer.app/Contents/Resources/LICENSE'
cp THIRD_PARTY_NOTICES.md 'MacSizeExplorer.app/Contents/Resources/THIRD_PARTY_NOTICES.md'
codesign --force --sign - 'MacSizeExplorer.app'
echo 'Hazır: MacSizeExplorer.app'
