#!/bin/bash
set -e
export THEOS="${THEOS:-/home/oladik/theos}"
export PATH="$THEOS/bin:$PATH"
SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
echo "Source: $SRC_DIR, THEOS: $THEOS"
cp -r "$SRC_DIR/"* ~/OpenVK-Legacy/
cd ~/OpenVK-Legacy
make -j2 ipa FINALPACKAGE=1 ENABLE_VISUALIZER="${ENABLE_VISUALIZER:-1}"
if [ -f "packages/"*.deb ]; then
    echo "DEB packages created in ~/OpenVK-Legacy/packages/"
fi
if [ -f ".theos/obj/OpenVK.app" ] || [ -f "OpenVK-Legacy.ipa" ]; then
    echo "IPA / App built successfully!"
fi
cp OpenVK-Legacy.ipa "$SRC_DIR/../" 2>/dev/null || true
cp OpenVK.ipa "$SRC_DIR/../" 2>/dev/null || true
echo "Build complete!"
