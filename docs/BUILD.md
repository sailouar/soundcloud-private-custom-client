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
