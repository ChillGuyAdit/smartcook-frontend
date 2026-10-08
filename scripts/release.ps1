# SmartCook release tool - the ONLY supported way to ship an APK.
#
#   .\scripts\release.ps1 -Type patch|minor|big|major   # normal release
#   .\scripts\release.ps1 -PublishOnly                  # re-publish current pubspec build
#   .\scripts\release.ps1 -Rollback -To 1.0.12 -Block 14 # roll forward from an old tag
#   .\scripts\release.ps1 -Unpublish                    # restore previous latest.json
#
# One number rules everything: build = pubspec +N = Android versionCode =
# latest.json build (see AGENTS.md). Build always rises by exactly 1.
#
# No OpenSSH on this machine: uploads go through the Paramiko helpers
# (sc_ssh.py / sc_put.py). Their folder defaults to %LOCALAPPDATA%\Temp\sc-ssh,
# override with SC_SSH_DIR. Server paths live in .release.env (gitignored):
#   RELEASE_DIR=/root/smartcook-releases
param(
    [ValidateSet('patch','minor','big','major')][string]$Type,
    [switch]$PublishOnly,
    [switch]$Rollback,
    [string]$To,
    [int[]]$Block = @(),
    [switch]$Unpublish,
    [string]$Version,
    [switch]$NoPush
)

$ErrorActionPreference = 'Stop'
$Root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
Set-Location $Root
$ReleaseCert = '7d237c7980ecaf14cb86e23b8a8d66ac16e5b2357231e4ac0e5d84c28a67ff64'
$sshDir = if ($env:SC_SSH_DIR) { $env:SC_SSH_DIR } else { Join-Path $env:LOCALAPPDATA 'Temp\sc-ssh' }
$releaseDir = '/root/smartcook-releases'
$envFile = Join-Path $Root '.release.env'
if (Test-Path $envFile) {
    Get-Content $envFile | Where-Object { $_ -match '^\s*RELEASE_DIR=(.+)$' } | ForEach-Object { $releaseDir = $Matches[1].Trim() }
}

function Fail($msg) { Write-Host "ERROR: $msg" -ForegroundColor Red; exit 1 }
function Remote([string]$cmd) {
    $f = New-TemporaryFile
    [IO.File]::WriteAllText($f.FullName, $cmd, [Text.UTF8Encoding]::new($false))
    $out = python (Join-Path $sshDir 'sc_ssh.py') $f.FullName
    Remove-Item $f
    $out | ForEach-Object { Write-Host "    $_" }
    if (($out -join "`n") -notmatch '__EXIT_STATUS__=0') { Fail "perintah server gagal: $cmd" }
}
function Upload([string]$local, [string]$remote) {
    python (Join-Path $sshDir 'sc_put.py') $local "$releaseDir/$remote" 420 | Out-Null   # 0644
    if ($LASTEXITCODE -ne 0) { Fail "upload gagal: $local" }
}
if (-not (Test-Path (Join-Path $sshDir 'sc_ssh.py'))) { Fail "Helper Paramiko tidak ada di $sshDir (set SC_SSH_DIR)." }

if ($Unpublish) {
    Write-Host '==> Unpublish: kembalikan latest.json sebelumnya'
    Remote "cd $releaseDir && test -f latest.prev.json && cp latest.json latest.unpublished.json && mv latest.prev.json latest.json && echo restored"
    exit 0
}

# ---------------------------------------------------------------- versions
function Get-Pubspec {
    $m = (Select-String -Path (Join-Path $Root 'pubspec.yaml') -Pattern '^version:\s*(\d+)\.(\d+)\.(\d+)\+(\d+)').Matches[0]
    @{ Major = [int]$m.Groups[1].Value; Minor = [int]$m.Groups[2].Value; Patch = [int]$m.Groups[3].Value; Build = [int]$m.Groups[4].Value }
}
function Set-Pubspec([string]$dir, [string]$name, [int]$build) {
    $p = Join-Path $dir 'pubspec.yaml'
    (Get-Content $p) -replace '^version:.*$', "version: $name+$build" | Set-Content $p -Encoding utf8
}

$cur = Get-Pubspec
if ($PublishOnly) {
    $newBuild = $cur.Build; $newName = "$($cur.Major).$($cur.Minor).$($cur.Patch)"
} else {
    $newBuild = $cur.Build + 1
    if ($Rollback) {
        if (-not $To) { Fail '-Rollback butuh -To <versi stabil>' }
        $Type = 'patch'
        $newName = "$($cur.Major).$($cur.Minor).$($cur.Patch + 1)"
    } else {
        if (-not $Type) { Fail 'Pilih -Type patch|minor|big|major' }
        $newName = switch ($Type) {
            'patch' { "$($cur.Major).$($cur.Minor).$($cur.Patch + 1)" }
            'minor' { "$($cur.Major).$($cur.Minor + 1).0" }
            'big'   { if ($cur.Minor -lt 5) { "$($cur.Major).5.0" } else { "$($cur.Major + 1).0.0" } }
            'major' { "$($cur.Major + 1).0.0" }
        }
    }
    if ($Version) { $newName = $Version }
}
$fullName = "$newName+$newBuild"

# ---------------------------------------------------------------- notes
$notesDir = Join-Path $Root 'release-notes'
$notesFile = Join-Path $notesDir ('{0:D4}-{1}.md' -f $newBuild, $newName)
if (-not (Test-Path $notesFile)) {
    $mand = if ($Type -eq 'major' -or $Rollback) { 'true' } else { 'false' }
    $blocks = if ($Block.Count) { "[$($Block -join ', ')]" } else { '[]' }
    @"
---
version: $newName
build: $newBuild
date: $(Get-Date -Format 'yyyy-MM-dd')
type: $(if ($Rollback) { 'rollback' } else { $Type })
mandatory: $mand
blocks: $blocks
headlineId: TULIS_JUDUL
headlineEn: WRITE_TITLE
notesId: TULIS_RINGKASAN
notesEn: WRITE_SUMMARY
sections: [{"kind":"new","items":["..."]},{"kind":"fix","items":["..."]}]
---
Satu kalimat headline untuk pengguna (Bahasa Indonesia, tanpa istilah teknis).
"@ | Set-Content $notesFile -Encoding utf8
    Fail "Catatan rilis belum ada. Template dibuat di $notesFile - isi lalu jalankan ulang."
}
if ((Get-Content $notesFile -Raw) -match 'TULIS_|WRITE_') { Fail "Isi dulu catatan rilis di $notesFile" }

Write-Host "==> Rilis $fullName"

# ---------------------------------------------------------------- build
$buildRoot = $Root
if ($Rollback) {
    $tag = (git tag --list "app-v$To+*" | Select-Object -Last 1)
    if (-not $tag) { Fail "Tag untuk versi $To tidak ditemukan (app-v$To+N)." }
    $buildRoot = Join-Path $Root 'build\rollback'
    if (Test-Path $buildRoot) { git worktree remove --force $buildRoot 2>$null }
    git worktree prune
    git worktree add --detach $buildRoot $tag | Out-Null
    foreach ($f in 'android\key.properties') { Copy-Item (Join-Path $Root $f) (Join-Path $buildRoot $f) -Force }
    # The rollback build must carry the NEW notes + number, on top of the old code.
    New-Item -ItemType Directory -Force (Join-Path $buildRoot 'release-notes') | Out-Null
    Copy-Item "$notesDir\*.md" (Join-Path $buildRoot 'release-notes') -Force
    Write-Host "==> Rollback: membangun ulang $tag sebagai $fullName"
}
if (-not $PublishOnly) {
    Set-Pubspec $buildRoot $newName $newBuild
    & (Join-Path $buildRoot 'scripts\build_android_release.ps1')
    if (-not $?) { Fail 'build gagal' }
}

# ---------------------------------------------------------------- verify + stage
$sdk = (Get-Content (Join-Path $Root 'android\local.properties') | Where-Object { $_ -match '^sdk.dir=' }) `
        -replace '^sdk.dir=', '' -replace '\\\\', '\' -replace '\\:', ':'
$apksigner = Get-ChildItem (Join-Path $sdk 'build-tools') -Directory `
        | Sort-Object { [version]($_.Name -replace '[^0-9.].*', '') } | Select-Object -Last 1 `
        | ForEach-Object { Join-Path $_.FullName 'apksigner.bat' }
$stage = Join-Path $Root 'build\stage'
if (Test-Path $stage) { Remove-Item $stage -Recurse -Force }
New-Item -ItemType Directory -Force $stage | Out-Null
foreach ($abi in 'arm64', 'arm32') {
    $src = Join-Path $buildRoot "build\releases\smartcook-$fullName-$abi.apk"
    if (-not (Test-Path $src)) { Fail "APK tidak ditemukan: $src" }
    $cert = & $apksigner verify --print-certs $src 2>&1 | Select-String 'SHA-256'
    if ("$cert" -notmatch $ReleaseCert) { Fail "APK $abi TIDAK ditandatangani kunci rilis. Periksa android/key.properties." }
    Copy-Item $src (Join-Path $stage "smartcook-$newName-$abi.apk")
}
Write-Host '==> Signature OK'

python (Join-Path $PSScriptRoot 'build_release_manifest.py') `
    --notes-dir $notesDir --apk-dir $stage --out (Join-Path $stage 'latest.json') `
    --pubspec (Join-Path $buildRoot 'pubspec.yaml')
if ($LASTEXITCODE -ne 0) { Fail 'manifest gagal dibuat' }

# ---------------------------------------------------------------- publish
Write-Host '==> Upload...'
foreach ($abi in 'arm64', 'arm32') { Upload (Join-Path $stage "smartcook-$newName-$abi.apk") "smartcook-$newName-$abi.apk" }
Upload (Join-Path $stage 'latest.json') 'latest.json.tmp'
# Atomic swap so a client never reads a half-written manifest, then keep only
# this release and the previous one (needed for -Unpublish).
Remote @"
cd $releaseDir && cp latest.json latest.prev.json 2>/dev/null; mv latest.json.tmp latest.json
keep="smartcook-$newName-arm64.apk smartcook-$newName-arm32.apk"
for a in `$(python3 -c "import json;[print(x['file']) for x in json.load(open('latest.prev.json'))['apks']]" 2>/dev/null); do keep="`$keep `$a"; done
for f in smartcook-*.apk; do case " `$keep " in *" `$f "*) ;; *) rm -f "`$f";; esac; done
ls -la
"@
Write-Host '==> Terbit di server.'

# ---------------------------------------------------------------- git
$rel = Join-Path $Root 'releases'
foreach ($abi in 'arm64', 'arm32') { Copy-Item (Join-Path $buildRoot "build\releases\smartcook-$fullName-$abi.apk") $rel -Force }
if ($Rollback) { git worktree remove --force $buildRoot; Set-Pubspec $Root $newName $newBuild }
git add pubspec.yaml release-notes
git add -f "releases/smartcook-$fullName-arm64.apk" "releases/smartcook-$fullName-arm32.apk"
git commit -q -m "[chore] release $fullName"
git tag -f "app-v$fullName"
if (-not $NoPush) { git push -q origin main; git push -q -f origin "app-v$fullName" }
Write-Host "==> Selesai: $fullName (tag app-v$fullName). Verifikasi sesuai AGENTS.md > Verifying a release."
