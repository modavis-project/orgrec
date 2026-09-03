#!/bin/zsh
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUTPUT_ROOT="$PROJECT_ROOT/dist"
APP_PATH="$OUTPUT_ROOT/OrgRec.app"
STAGE_ROOT="$(mktemp -d)"
STAGED_APP="$STAGE_ROOT/OrgRec.app"
SIGNING_IDENTITY="${ORGREC_CODE_SIGN_IDENTITY:--}"
ENTITLEMENTS="$PROJECT_ROOT/Packaging/OrgRec.entitlements"
ARCHITECTURES=(arm64 x86_64)

trap 'rm -rf "$STAGE_ROOT"' EXIT

cd "$PROJECT_ROOT"
PLIST_VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$PROJECT_ROOT/Packaging/Info.plist")"
PLIST_BUILD="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$PROJECT_ROOT/Packaging/Info.plist")"
SOURCE_VERSION="$(sed -n 's/.*public static let version = "\([^"]*\)"/\1/p' "$PROJECT_ROOT/Sources/OrgRecCore/SoftwareVersion.swift")"
SOURCE_BUILD="$(sed -n 's/.*public static let build = "\([^"]*\)"/\1/p' "$PROJECT_ROOT/Sources/OrgRecCore/SoftwareVersion.swift")"
MINIMUM_MACOS="$(/usr/libexec/PlistBuddy -c 'Print :LSMinimumSystemVersion' "$PROJECT_ROOT/Packaging/Info.plist")"
if [[ "$PLIST_VERSION" != "$SOURCE_VERSION" || "$PLIST_BUILD" != "$SOURCE_BUILD" ]]; then
    echo "OrgRec software version does not match Packaging/Info.plist" >&2
    exit 1
fi

RELEASE_BINARIES=()
RESOURCE_BUNDLE=""
for ARCHITECTURE in "${ARCHITECTURES[@]}"; do
    TARGET_TRIPLE="${ARCHITECTURE}-apple-macosx${MINIMUM_MACOS}"
    swift build -c release --triple "$TARGET_TRIPLE"
    BUILD_ROOT="$(swift build -c release --triple "$TARGET_TRIPLE" --show-bin-path)"
    RELEASE_BINARIES+=("$BUILD_ROOT/OrgRec")
    if [[ -z "$RESOURCE_BUNDLE" ]]; then
        RESOURCE_BUNDLE="$BUILD_ROOT/OrgRec_OrgRecCore.bundle"
    fi
done

mkdir -p "$STAGED_APP/Contents/MacOS" "$STAGED_APP/Contents/Resources"
lipo -create "${RELEASE_BINARIES[@]}" -output "$STAGED_APP/Contents/MacOS/OrgRec"
cp "$PROJECT_ROOT/Packaging/Info.plist" "$STAGED_APP/Contents/Info.plist"
cp "$PROJECT_ROOT/Packaging/OrgRec.icns" "$STAGED_APP/Contents/Resources/OrgRec.icns"
if [[ ! -d "$RESOURCE_BUNDLE" ]]; then
    echo "Missing SwiftPM resource bundle: $RESOURCE_BUNDLE" >&2
    exit 1
fi
ditto "$RESOURCE_BUNDLE" "$STAGED_APP/Contents/Resources/OrgRec_OrgRecCore.bundle"
cp "$PROJECT_ROOT/THIRD_PARTY_NOTICES.md" "$STAGED_APP/Contents/Resources/"
ditto "$PROJECT_ROOT/LICENSES" "$STAGED_APP/Contents/Resources/LICENSES"

/usr/bin/plutil -lint "$STAGED_APP/Contents/Info.plist" >/dev/null
/usr/bin/plutil -lint "$ENTITLEMENTS" >/dev/null
if [[ "$(lipo -archs "$STAGED_APP/Contents/MacOS/OrgRec")" != "x86_64 arm64" && "$(lipo -archs "$STAGED_APP/Contents/MacOS/OrgRec")" != "arm64 x86_64" ]]; then
    echo "OrgRec release binary is not universal arm64/x86_64" >&2
    exit 1
fi
if [[ "$SIGNING_IDENTITY" == "-" ]]; then
    codesign --force --deep --options runtime --timestamp=none \
        --entitlements "$ENTITLEMENTS" --sign - "$STAGED_APP"
else
    codesign --force --deep --options runtime --timestamp \
        --entitlements "$ENTITLEMENTS" --sign "$SIGNING_IDENTITY" "$STAGED_APP"
fi
codesign --verify --deep --strict --verbose=2 "$STAGED_APP"
SIGNED_ENTITLEMENTS="$(codesign --display --entitlements :- "$STAGED_APP" 2>&1)"
if [[ "$SIGNED_ENTITLEMENTS" != *"com.apple.security.device.audio-input"* ]]; then
    echo "Signed OrgRec bundle lacks the audio-input entitlement" >&2
    exit 1
fi
mkdir -p "$OUTPUT_ROOT"
if [[ -e "$APP_PATH" ]]; then
    rm -rf "$APP_PATH"
fi
ditto "$STAGED_APP" "$APP_PATH"

echo "$APP_PATH"
