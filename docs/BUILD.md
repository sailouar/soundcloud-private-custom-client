# Build and verification

## Windows authoring lane

Windows 11 is the authoring environment. It does not compile, run, or sign
the native iOS target. No credentials or signing material belong in this
repository.

Run these checks from the repository root in PowerShell:

```powershell
$required = @(
  "Package.swift",
  "SoundCloudPersonal.xcodeproj\project.pbxproj",
  "SoundCloudPersonal.xcodeproj\xcshareddata\xcschemes\SoundCloudPersonal.xcscheme",
  "ios\SoundCloudPersonal\SoundCloudPersonalApp.swift",
  "ios\SoundCloudPersonal\Info.plist",
  "ios\SoundCloudPersonalTests\CapabilityAdapterIntegrationTests.swift",
  "docs\DECISIONS.md"
)
foreach ($path in $required) {
  if (-not (Test-Path $path)) { throw "Missing required artifact: $path" }
}
$swift = Get-Command swift -ErrorAction SilentlyContinue
$xcodebuild = Get-Command xcodebuild -ErrorAction SilentlyContinue
if ($null -eq $swift) { Write-Output "Swift package execution pending on cloud Mac." }
if ($null -eq $xcodebuild) { Write-Output "Xcode execution pending on cloud Mac." }
```

The package and documentation checks are safe to run on Windows. If a Swift
toolchain is installed, also run `swift package describe` and `swift test`.
Otherwise, do not claim Swift compilation or iOS test success.

## Cloud-Mac Xcode lane

Use the repository checkout on a macOS cloud Mac with Xcode. The project is
`SoundCloudPersonal.xcodeproj`, the iOS application target is
`SoundCloudPersonal`, and the shared scheme is `SoundCloudPersonal`. The
candidate deployment target is **iOS 17.0**; confirm it against the installed
Xcode image with `xcodebuild -showBuildSettings`.

```bash
set -euo pipefail
test -d SoundCloudPersonal.xcodeproj
test -f SoundCloudPersonal.xcodeproj/xcshareddata/xcschemes/SoundCloudPersonal.xcscheme
xcodebuild -list -project SoundCloudPersonal.xcodeproj
swift package describe
swift test
xcodebuild -showBuildSettings \
  -project SoundCloudPersonal.xcodeproj \
  -scheme SoundCloudPersonal
SIMULATOR_UDID="$(xcrun simctl list devices available | awk -F '[()]' '/iPhone/{print $2; exit}')"
test -n "$SIMULATOR_UDID"
xcodebuild test \
  -project SoundCloudPersonal.xcodeproj \
  -scheme SoundCloudPersonal \
  -destination "id=$SIMULATOR_UDID"
```

The adapter test must prove
`MockAPITransport -> SoundCloudAPI -> AppEnvironment -> CapabilityStatusViewModel`.
The selected storage test is
`SoundCloudPersonalTests/StorageMigrationSmokeTests/testSwiftDataRelationshipAndMigration`.
Its in-memory relationship/save result is required before the SwiftData
decision is considered cloud-Mac verified.

## Archive and signing boundary

Only the cloud Mac may perform an archive, provisioning, signing, simulator
execution, or device check. Inject the signing identity and provisioning
configuration through the cloud Mac/Xcode environment; never commit them.
Expected outputs are an `.xcarchive` and, only when intentionally configured,
an exported signed `.ipa`. This phase does not require an archive and does
not claim one exists.

The app target sets `CODE_SIGN_STYLE = Automatic` and leaves
`DEVELOPMENT_TEAM` unset, so a fresh checkout opens without a signing team. Set
a team locally for a direct device run; do not commit it.

## Personal AltStore lane

This project is a single-owner sideload, not an App Store release. The build
contains no SoundCloud app secret: the owner enters the client ID and client
secret in the app on first launch, and they are stored in the device Keychain.

### Before the first sign-in

1. Create a SoundCloud developer app (for example through the developer portal's
   *Your Apps* page) and note its client ID and client secret.
2. Register the redirect URI exactly as `soundcloudpersonal://oauth/callback`.
   The scheme is declared in `ios/SoundCloudPersonal/Info.plist`; if you change
   it, change both places together.
3. Do not paste the secret into a tracked file. This repository has no
   build-time secret setting.

### Build the unsigned IPA on macOS

```bash
chmod +x scripts/build-altstore-ipa.sh
./scripts/build-altstore-ipa.sh
```

The script archives with `CODE_SIGNING_ALLOWED=NO`, packages
`build/SoundCloudPersonal.ipa`, and leaves signing to AltServer. Without a Mac,
the IPA cannot be produced and the build remains unverified.

### Install with AltStore

1. Install AltServer on Windows and AltStore Classic on the iPhone with the same
   Apple ID (free Apple ID is sufficient; a paid developer account is not
   required).
2. Keep the iPhone and the AltServer computer on the same network, then sideload
   `build/SoundCloudPersonal.ipa` from AltStore.
3. Trust the developer certificate on the device if iOS asks.
4. Launch the app, enter the SoundCloud client ID and client secret, and complete
   the system-browser sign-in.
5. Refresh the app at least every 7 days through AltServer. The Keychain session
   survives re-signing because the bundle identifier does not change.

### What is still unverified

- `swift test`, `xcodebuild -list`, simulator tests, and the IPA build have not
  run on the Windows authoring host.
- The Keychain, `ASWebAuthenticationSession`, and `URLSession` adapters are
  authored but have not been compiled or exercised on a simulator or device.
- SoundCloud may require a paid plan to register the developer app; confirm this
  on the owner's account before treating sign-in as blocked by code.

## GitHub Actions lane (no Mac at all)

If the repository is **public**, GitHub's hosted `macos-latest` runners are
free (macOS minutes bill at 10×, but public repos are not charged). The
workflow `.github/workflows/build-ipa.yml` runs on every push to `main` and on
manual dispatch:

1. `swift test` — the SoundCloudCore package suites.
2. `xcodebuild -list` and simulator `xcodebuild test` — the app target and
   integration tests, which also closes the pending cloud-Mac verification.
3. `scripts/build-altstore-ipa.sh` — archives with signing disabled and
   packages `build/SoundCloudPersonal.ipa`.
4. Uploads the IPA as the `SoundCloudPersonal-unsigned-ipa` artifact
   (90-day retention).

No secrets are required: the build is unsigned and contains no SoundCloud
credentials. Download the IPA from the workflow run's **Artifacts** section,
then sideload it with AltServer/Sideloadly (Windows) or SideStore, using a free
Apple ID. Keep the repo public; a private repo consumes billed macOS minutes.

## Second-Mac (friend) build handoff

The owner does not need their own Mac. Any macOS machine with Xcode installed
can produce the installable IPA, because the build is unsigned and AltServer
re-signs it with the owner's Apple ID on the Windows PC.

### What the friend needs to do

1. Clone this repository (or receive a zip) and check out the working branch.
2. Optionally verify the code first — this closes the pending cloud-Mac
   verification and is strongly recommended:

   ```bash
   swift package describe
   swift test
   xcodebuild -list -project SoundCloudPersonal.xcodeproj
   # simulator tests, as in the cloud-Mac lane above
   ```

3. Build the unsigned IPA:

   ```bash
   chmod +x scripts/build-altstore-ipa.sh
   ./scripts/build-altstore-ipa.sh
   # -> build/SoundCloudPersonal.ipa
   ```

4. Send `build/SoundCloudPersonal.ipa` back to the owner through any channel.
   The IPA contains no credentials or signing material.

### What the friend must NOT do

- Do not set a development team or sign with a personal certificate. The
  project is configured `CODE_SIGN_STYLE = Automatic` with no team on purpose;
  the owner's AltServer signs with the owner's Apple ID. Signing with the
  friend's Apple ID would tie the app to the friend's account.
- Do not paste the owner's SoundCloud client ID or client secret into any
  tracked file, build setting, or command history that gets committed. The
  repo intentionally has no build-time secret setting.
- Do not commit anything back unless asked; the handoff is one-directional.

### What the owner does with the IPA

Install AltServer on the Windows PC and AltStore (or SideStore) on the iPhone
with the same free Apple ID, sideload `SoundCloudPersonal.ipa`, trust the
developer certificate, then enter the SoundCloud client ID and secret inside
the app on first launch. Refresh at least every 7 days.
