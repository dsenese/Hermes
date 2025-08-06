#!/bin/bash

echo "=== Hermes Accessibility Permission Fix ==="
echo ""
echo "Current app location:"
echo "/Users/dominicsenese008/projects/Hermes/build/Build/Products/Debug/Hermes.app"
echo ""

# Check if the app is signed
echo "Checking code signing..."
codesign -dv --verbose=4 /Users/dominicsenese008/projects/Hermes/build/Build/Products/Debug/Hermes.app 2>&1 | grep -E "(Authority|Identifier|adhoc)"

echo ""
echo "Bundle identifier:"
/usr/libexec/PlistBuddy -c "Print CFBundleIdentifier" /Users/dominicsenese008/projects/Hermes/build/Build/Products/Debug/Hermes.app/Contents/Info.plist

echo ""
echo "=== MANUAL STEPS REQUIRED ==="
echo "1. Open System Preferences > Security & Privacy > Privacy > Accessibility"
echo "2. Click the lock icon and authenticate"
echo "3. If 'Hermes' is already in the list, remove it with the '-' button"
echo "4. Click the '+' button"
echo "5. Navigate to: /Users/dominicsenese008/projects/Hermes/build/Build/Products/Debug/"
echo "6. Select 'Hermes.app' and click 'Open'"
echo "7. Make sure the checkbox next to Hermes is checked"
echo "8. Close System Preferences"
echo ""
echo "Opening System Preferences now..."
open "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"

echo ""
echo "After completing the steps above, restart Hermes for changes to take effect."