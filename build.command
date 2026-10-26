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
<key>CFBundleShortVersionString</key><string>1.2.0</string>
<key>LSMinimumSystemVersion</key><string>13.0</string>
<key>NSHighResolutionCapable</key><true/>
<key>CFBundleDevelopmentRegion</key><string>en</string>
<key>CFBundleLocalizations</key><array><string>en</string></array>
<key>AppLanguage</key><string>en</string>
</dict></plist>
PLIST
cp LICENSE 'MacSizeExplorer.app/Contents/Resources/LICENSE'
cp THIRD_PARTY_NOTICES.md 'MacSizeExplorer.app/Contents/Resources/THIRD_PARTY_NOTICES.md'
codesign --force --sign - 'MacSizeExplorer.app'
# The same tested executable serves both languages; each bundle declares its UI language.
mkdir -p 'MacSizeExplorer Türkçe.app'
ditto 'MacSizeExplorer.app' 'MacSizeExplorer Türkçe.app'
/usr/libexec/PlistBuddy -c 'Set :CFBundleIdentifier io.github.erhansenlik.macsizeexplorer.tr' 'MacSizeExplorer Türkçe.app/Contents/Info.plist'
/usr/libexec/PlistBuddy -c 'Set :CFBundleDisplayName MacSizeExplorer Türkçe' 'MacSizeExplorer Türkçe.app/Contents/Info.plist'
/usr/libexec/PlistBuddy -c 'Set :CFBundleName MacSizeExplorer Türkçe' 'MacSizeExplorer Türkçe.app/Contents/Info.plist'
/usr/libexec/PlistBuddy -c 'Set :CFBundleDevelopmentRegion tr' 'MacSizeExplorer Türkçe.app/Contents/Info.plist'
/usr/libexec/PlistBuddy -c 'Set :CFBundleLocalizations:0 tr' 'MacSizeExplorer Türkçe.app/Contents/Info.plist'
/usr/libexec/PlistBuddy -c 'Set :AppLanguage tr' 'MacSizeExplorer Türkçe.app/Contents/Info.plist'
codesign --force --sign - 'MacSizeExplorer Türkçe.app'
echo 'Ready: MacSizeExplorer.app (English) + MacSizeExplorer Türkçe.app'
