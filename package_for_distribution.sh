#!/bin/bash
# FlexPAL Control Suite - Distribution Packaging Script
# Version: 1.1.2

set -e  # Exit on error

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_NAME="FlexPal_pannel"
VERSION="1.1.2"
OUTPUT_DIR="$PROJECT_DIR/dist"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

echo "=========================================="
echo "FlexPAL Control Suite - Package Builder"
echo "Version: $VERSION"
echo "=========================================="
echo ""

# Create output directory
mkdir -p "$OUTPUT_DIR"

echo "[1/5] Cleaning build artifacts..."
cd "$PROJECT_DIR"
flutter clean 2>/dev/null || echo "Flutter clean skipped"

echo ""
echo "[2/5] Running analyzer..."
flutter analyze --no-pub | head -20
echo ""

# Package source code
echo "[3/5] Creating source code archive..."
cd "$PROJECT_DIR/.."
ARCHIVE_NAME="FlexPal_pannel_v${VERSION}_source_${TIMESTAMP}"

tar -czf "$OUTPUT_DIR/$ARCHIVE_NAME.tar.gz" \
    --exclude="$PROJECT_NAME/build" \
    --exclude="$PROJECT_NAME/.dart_tool" \
    --exclude="$PROJECT_NAME/.idea" \
    --exclude="$PROJECT_NAME/.vscode" \
    --exclude="$PROJECT_NAME/.flutter-plugins*" \
    --exclude="$PROJECT_NAME/dist" \
    --exclude="$PROJECT_NAME/*.iml" \
    "$PROJECT_NAME"

echo "✓ Created: $OUTPUT_DIR/$ARCHIVE_NAME.tar.gz"
echo "  Size: $(du -h "$OUTPUT_DIR/$ARCHIVE_NAME.tar.gz" | cut -f1)"

# Build executable (platform-specific)
echo ""
echo "[4/5] Building executable for current platform..."
cd "$PROJECT_DIR"

if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    echo "Building for Linux..."
    flutter build linux --release

    if [ -d "build/linux/x64/release/bundle" ]; then
        EXEC_NAME="FlexPal_pannel_v${VERSION}_linux_x64_${TIMESTAMP}"
        cd build/linux/x64/release
        tar -czf "$OUTPUT_DIR/$EXEC_NAME.tar.gz" bundle/
        echo "✓ Created: $OUTPUT_DIR/$EXEC_NAME.tar.gz"
        echo "  Size: $(du -h "$OUTPUT_DIR/$EXEC_NAME.tar.gz" | cut -f1)"
    fi

elif [[ "$OSTYPE" == "darwin"* ]]; then
    echo "Building for macOS..."
    flutter build macos --release

    if [ -d "build/macos/Build/Products/Release" ]; then
        EXEC_NAME="FlexPal_pannel_v${VERSION}_macos_${TIMESTAMP}"
        cd build/macos/Build/Products/Release
        tar -czf "$OUTPUT_DIR/$EXEC_NAME.tar.gz" *.app
        echo "✓ Created: $OUTPUT_DIR/$EXEC_NAME.tar.gz"
        echo "  Size: $(du -h "$OUTPUT_DIR/$EXEC_NAME.tar.gz" | cut -f1)"
    fi

elif [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "win32" ]]; then
    echo "Building for Windows..."
    flutter build windows --release

    if [ -d "build/windows/x64/runner/Release" ]; then
        EXEC_NAME="FlexPal_pannel_v${VERSION}_windows_x64_${TIMESTAMP}"
        cd build/windows/x64/runner/Release
        zip -r "$OUTPUT_DIR/$EXEC_NAME.zip" *
        echo "✓ Created: $OUTPUT_DIR/$EXEC_NAME.zip"
        echo "  Size: $(du -h "$OUTPUT_DIR/$EXEC_NAME.zip" | cut -f1)"
    fi
else
    echo "⚠ Unknown platform: $OSTYPE (skipping executable build)"
fi

# Create README for distribution
echo ""
echo "[5/5] Creating distribution README..."
cd "$OUTPUT_DIR"

cat > README.txt << 'EOF'
FlexPAL Control Suite - Distribution Package
Version: 1.1.2
Build Date: TIMESTAMP_PLACEHOLDER

========================================
CONTENTS
========================================

1. Source Code Archive (*.tar.gz)
   - Complete Flutter project
   - Requires Flutter SDK to run
   - See SETUP_INSTRUCTIONS.md inside

2. Executable Archive (*.tar.gz / *.zip)
   - Pre-built binary for your platform
   - No Flutter SDK required
   - Extract and run directly

========================================
QUICK START (Source Code)
========================================

1. Install Flutter SDK:
   https://docs.flutter.dev/get-started/install

2. Extract the source archive:
   tar -xzf FlexPal_pannel_v*.tar.gz
   cd FlexPal_pannel

3. Install dependencies:
   flutter pub get

4. Run the application:
   flutter run

5. Open SETUP_INSTRUCTIONS.md for configuration

========================================
QUICK START (Executable)
========================================

LINUX:
  tar -xzf FlexPal_pannel_v*_linux_x64_*.tar.gz
  cd bundle
  ./flexpal_pannel

MACOS:
  tar -xzf FlexPal_pannel_v*_macos_*.tar.gz
  open FlexPAL\ Control.app

WINDOWS:
  - Extract FlexPal_pannel_v*_windows_x64_*.zip
  - Run flexpal_pannel.exe

========================================
DOCUMENTATION
========================================

Inside the source archive:
- SETUP_INSTRUCTIONS.md  - Complete setup guide
- CAMERA_INTEGRATION.md  - Camera feature documentation
- TARGET_VALUES_BUG_FIX.md - Bug fix details
- CHANGELOG.md           - Version history

========================================
TROUBLESHOOTING
========================================

If the app doesn't start:
1. Check firewall allows UDP ports 5005/5006
2. Verify Flutter SDK version: flutter --version
3. Run with debug: flutter run -v
4. See SETUP_INSTRUCTIONS.md for detailed help

========================================
SYSTEM REQUIREMENTS
========================================

- OS: Linux / Windows / macOS
- RAM: 4GB minimum (8GB recommended)
- Network: UDP broadcast support
- Optional: MJPEG camera server

========================================
CONTACT & SUPPORT
========================================

Report issues with:
- Debug logs (flutter run -v output)
- System info (OS, network setup)
- Error messages from Logs tab

EOF

sed -i "s/TIMESTAMP_PLACEHOLDER/$(date '+%Y-%m-%d %H:%M:%S')/" README.txt

echo "✓ Created: $OUTPUT_DIR/README.txt"

# Summary
echo ""
echo "=========================================="
echo "✓ Packaging Complete!"
echo "=========================================="
echo ""
echo "Distribution files created in:"
echo "  $OUTPUT_DIR"
echo ""
echo "Files:"
ls -lh "$OUTPUT_DIR" | tail -n +2
echo ""
echo "=========================================="
echo "NEXT STEPS:"
echo "=========================================="
echo ""
echo "1. Test the packages:"
echo "   - Extract source archive in clean directory"
echo "   - Run: flutter pub get && flutter run"
echo "   - Test executable on target platform"
echo ""
echo "2. Share with users:"
echo "   - Send entire dist/ folder contents"
echo "   - Or upload to file sharing service"
echo "   - Include README.txt for instructions"
echo ""
echo "3. For version control (Git):"
echo "   cd $PROJECT_DIR"
echo "   git add ."
echo "   git commit -m 'Release v$VERSION - Camera integration'"
echo "   git tag v$VERSION"
echo "   git push origin main --tags"
echo ""
echo "=========================================="
