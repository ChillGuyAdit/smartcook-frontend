# Build SmartCook release APKs — split by CPU ABI (lighter per device).
#
# Uses `--target-platform` per ABI instead of `--split-per-abi`, and that
# detail is load-bearing. With `--split-per-abi` the Flutter Gradle plugin
# rewrites the Android `versionCode` to `abiVersionCode * 1000 + build`
# (arm64 -> 2008, arm32 -> 1008 for build 8). `package_info_plus` on Android
# returns exactly that number as `buildNumber`, so the app reported 2008 to
# /api/app/version while latest.json published `build: 8`. `installedBuild <
# minBuild` could then never be true, mandatory updates never blocked, and
# the update dialog never appeared. Building per target platform keeps
# `versionCode == pubspec +N` for every APK, which is what the update check
# compares against. Kelilink does the same for exactly this reason.
#
# Output: build/app/outputs/flutter-apk/app-release.apk (renamed per ABI)
param(
  [string]$ApiBaseUrl = ""
)

$ErrorActionPreference = "Stop"
$Root = Resolve-Path (Join-Path $PSScriptRoot "..")
Set-Location $Root

$envFile = Join-Path $Root "build\android-release.env"
if (-not $ApiBaseUrl -and (Test-Path $envFile)) {
  Get-Content $envFile | ForEach-Object {
    if ($_ -match '^\s*#' -or $_ -match '^\s*$') { return }
    if ($_ -match '^API_BASE_URL=(.+)$') { $ApiBaseUrl = $Matches[1].Trim() }
  }
}
if (-not $ApiBaseUrl) {
  $ApiBaseUrl = "https://api.himatif-encoder.com"
}

# The build number and version name are baked in as Dart defines so the app
# can report its own release build without depending on the Android
# `versionCode` (see the note about --split-per-abi at the top of this file).
$versionLine = Select-String -Path (Join-Path $Root "pubspec.yaml") -Pattern '^version:\s*(.+)$'
if (-not $versionLine) { throw "pubspec.yaml tidak punya baris version:" }
$version = $versionLine.Matches.Groups[1].Value.Trim()          # e.g. 1.0.7+8
if ($version -notmatch '^([\d.]+)\+(\d+)$') { throw "Format version tidak dikenal: $version" }
$versionName = $Matches[1]
$buildNumber = [int]$Matches[2]

$releasesDir = Join-Path $Root "build\releases"
New-Item -ItemType Directory -Force -Path $releasesDir | Out-Null

$define = "API_BASE_URL=$ApiBaseUrl,SMARTCOOK_BUILD=$buildNumber,SMARTCOOK_VERSION=$versionName"

Write-Host "==> SmartCook $version (build $buildNumber) | API: $ApiBaseUrl"

Write-Host "==> flutter pub get"
flutter pub get

Write-Host "==> Build arm64-v8a (64-bit, HP modern)"
flutter build apk --release --target-platform android-arm64 --dart-define=$define
if ($LASTEXITCODE -ne 0) { throw "Build arm64 GAGAL - jangan lanjut. APK lama masih di folder build dan bisa jadi versi sebelumnya." }
$arm64Out = Join-Path $releasesDir "smartcook-$version-arm64.apk"
Copy-Item (Join-Path $Root "build\app\outputs\flutter-apk\app-release.apk") $arm64Out -Force
Write-Host "    -> $arm64Out"

Write-Host "==> Build armeabi-v7a (32-bit, HP lama)"
flutter build apk --release --target-platform android-arm --dart-define=$define
if ($LASTEXITCODE -ne 0) { throw "Build arm32 GAGAL - jangan lanjut. APK lama masih di folder build dan bisa jadi versi sebelumnya." }
$arm32Out = Join-Path $releasesDir "smartcook-$version-arm32.apk"
Copy-Item (Join-Path $Root "build\app\outputs\flutter-apk\app-release.apk") $arm32Out -Force
Write-Host "    -> $arm32Out"

# Guard: the Android versionCode must equal the pubspec build number, because
# that is the number /api/app/version compares against. If it ever drifts
# again, mandatory updates silently stop working - so fail the build instead
# of shipping an APK nobody can update from.
$aapt = Get-ChildItem (Join-Path $env:LOCALAPPDATA "Android\Sdk\build-tools") -Directory -ErrorAction SilentlyContinue |
  Sort-Object Name -Descending | Select-Object -First 1
if ($aapt) {
  foreach ($apk in @($arm64Out, $arm32Out)) {
    $code = (& (Join-Path $aapt.FullName "aapt.exe") dump badging $apk 2>$null |
      Select-String "versionCode='(\d+)'").Matches.Groups[1].Value
    if ($code -and [int]$code -ne $buildNumber) {
      throw "versionCode APK ($code) != build pubspec ($buildNumber). Update check akan rusak - perbaiki build script."
    }
    Write-Host "    OK versionCode=$code  $apk"
  }
}

Write-Host "==> Selesai. Install sesuai CPU:"
Write-Host "    64-bit : $arm64Out"
Write-Host "    32-bit : $arm32Out"