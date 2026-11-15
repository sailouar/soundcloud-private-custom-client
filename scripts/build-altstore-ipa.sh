#!/usr/bin/env bash
# Build an unsigned device IPA for personal AltStore/AltServer sideloading.
#
# Run on macOS with Xcode installed. AltServer re-signs the IPA with the
# owner's Apple ID, so no signing identity is needed here. The SoundCloud
# client ID and secret are entered on the device at first launch and are not
# part of this build.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

BUILD_DIR="$ROOT/build"
ARCHIVE="$BUILD_DIR/SoundCloudPersonal.xcarchive"
IPA="$BUILD_DIR/SoundCloudPersonal.ipa"

rm -rf "$BUILD_DIR/Payload" "$IPA"
mkdir -p "$BUILD_DIR"

xcodebuild \
  -project SoundCloudPersonal.xcodeproj \
  -scheme SoundCloudPersonal \
  -configuration Release \
  -sdk iphoneos \
  -archivePath "$ARCHIVE" \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY="" \
  archive

APP="$ARCHIVE/Products/Applications/SoundCloudPersonal.app"
test -d "$APP"

mkdir -p "$BUILD_DIR/Payload"
cp -R "$APP" "$BUILD_DIR/Payload/"
(cd "$BUILD_DIR" && /usr/bin/zip -qry "$IPA" Payload)

echo "Unsigned IPA: $IPA"
echo "Install it with AltServer using the same Apple ID used for signing."
