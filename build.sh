#!/bin/bash
set -e

APP_NAME="MacLauncher"
BUNDLE_DIR="${APP_NAME}.app"
CONTENTS_DIR="${BUNDLE_DIR}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"

echo "=== Building ${APP_NAME} (Universal macOS Binary) ==="

# Clean previous build artifacts
rm -rf "${BUNDLE_DIR}"
rm -f "${APP_NAME}_arm64" "${APP_NAME}_x86_64"

# Create bundle folders
mkdir -p "${MACOS_DIR}"

# Resolve macOS SDK
SDK_PATH=$(xcrun --show-sdk-path --sdk macosx)
echo "SDK Path: ${SDK_PATH}"

# Find all Swift source files
SWIFT_FILES=$(find Sources -name "*.swift")
echo "Compiling files:"
echo "${SWIFT_FILES}"

# 1. Compile Apple Silicon Slice
echo "Compiling arm64 slice..."
swiftc -target arm64-apple-macosx14.0 \
       -sdk "${SDK_PATH}" \
       -parse-as-library \
       -o "${APP_NAME}_arm64" \
       ${SWIFT_FILES}

# 2. Compile Intel x86 Slice
echo "Compiling x86_64 slice..."
swiftc -target x86_64-apple-macosx14.0 \
       -sdk "${SDK_PATH}" \
       -parse-as-library \
       -o "${APP_NAME}_x86_64" \
       ${SWIFT_FILES}

# 3. Combine both architectures using lipo
echo "Stitching universal binary..."
lipo -create -output "${MACOS_DIR}/${APP_NAME}" "${APP_NAME}_arm64" "${APP_NAME}_x86_64"

# 4. Copy Info.plist to bundle
echo "Installing Info.plist..."
cp Info.plist "${CONTENTS_DIR}/Info.plist"

# 5. Sign the application bundle
echo "Signing application bundle..."
codesign --force --deep --sign - "${BUNDLE_DIR}"

# Clean up temp binaries
rm -f "${APP_NAME}_arm64" "${APP_NAME}_x86_64"

echo "=== Build Succeeded! Created ${BUNDLE_DIR} ==="
file "${MACOS_DIR}/${APP_NAME}"
