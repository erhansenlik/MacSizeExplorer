#!/bin/zsh
set -eu
cd "$(dirname "$0")"
for app in 'MacSizeExplorer.app' 'MacSizeExplorer Türkçe.app'; do
    test -x "$app/Contents/MacOS/MacSizeExplorer"
    codesign --verify --deep --strict "$app"
done
mkdir -p downloads .build
package_stage=$(mktemp -d "$PWD/.build/dmg-stage.XXXXXX")
trap 'rm -rf "$package_stage"' EXIT
for app in 'MacSizeExplorer.app' 'MacSizeExplorer Türkçe.app'; do
    ditto "$app" "$package_stage/$app"
done
ln -s /Applications "$package_stage/Applications"
cp LICENSE THIRD_PARTY_NOTICES.md "$package_stage/"
cat > "$package_stage/Install.txt" <<'TXT'
MacSizeExplorer 1.2.0 — macOS 13+ / Intel

ENGLISH
Drag MacSizeExplorer.app onto Applications to install the English version.
Open it and click Choose folder… to analyze a folder or disk.
Use the magnifying glass buttons to zoom, Fit to reset, and Expand for a larger window.

TÜRKÇE
Türkçe sürüm için MacSizeExplorer Türkçe.app dosyasını Applications klasörüne sürükleyin.
Uygulamayı açıp Klasör seç… düğmesine basın.
Büyüteç düğmeleriyle yakınlaştırın; Sığdır ile sıfırlayın, Büyüt ile büyük pencere açın.

Both apps are ad hoc signed, not Apple notarized. macOS may ask you to approve opening them
in System Settings > Privacy & Security. Do not disable system security protections.

These apps scan without modifying your files. Copyright and MIT license: LICENSE.
System resources and review limitations: THIRD_PARTY_NOTICES.md.
TXT
package_arch=$(uname -m)
if [[ "$package_arch" == x86_64 ]]; then package_arch=Intel; else package_arch=AppleSilicon; fi
package_name="MacSizeExplorer-1.2.0-macOS-${package_arch}.dmg"
hdiutil create -volname 'MacSizeExplorer 1.2.0' -srcfolder "$package_stage" -format UDZO -ov "downloads/$package_name"
python3 - "$package_name" <<'PY'
from pathlib import Path
import hashlib,sys
p=Path('downloads')/sys.argv[1]
Path('downloads/SHA256SUMS.txt').write_text(hashlib.sha256(p.read_bytes()).hexdigest()+'  '+p.name+'\n')
PY
echo "Ready: downloads/$package_name"
