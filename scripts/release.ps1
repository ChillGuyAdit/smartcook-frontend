# SmartCook release tool — publish a signed APK + manifest to the VPS.
#
#   .\scripts\release.ps1 -Type patch|minor|big|major [-Mandatory|-Optional]
#   .\scripts\release.ps1 -PublishOnly            # re-upload current build
#
# Server details live in .release.env (gitignored):
#   RELEASE_SSH_HOST=192.154.111.198
#   RELEASE_SSH_PORT=22232
#   RELEASE_DIR=/root/smartcook-releases
#   RELEASE_USER=root
param(
    [ValidateSet('patch','minor','big','major')][string]$Type,
    [switch]$Mandatory,
    [switch]$Optional,
    [switch]$PublishOnly,
    [string]$Version,
    [switch]$NoPush
)

$ErrorActionPreference = 'Stop'
$Root = Resolve-Path (Join-Path $PSScriptRoot '..')
Set-Location $Root
$ReleaseCert = '7d237c7980ecaf14cb86e23b8a8d66ac16e5b2357231e4ac0e5d84c28a67ff64'

function Fail($msg) { Write-Host "ERROR: $msg" -ForegroundColor Red; exit 1 }
function Invoke-Quiet([scriptblock]$cmd) {
    $prev = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try { & $cmd 2>&1 | Out-Null } finally { $ErrorActionPreference = $prev }
}

$envFile = Join-Path $Root '.release.env'
if (-not (Test-Path $envFile)) {
    Fail ".release.env belum ada. Salin .release.env.example lalu isi RELEASE_SSH / RELEASE_DIR."
}
$cfg = @{}
Get-Content $envFile | Where-Object { $_ -match '^\s*([A-Z_]+)=(.*)$' } | ForEach-Object {
    $cfg[$Matches[1]] = $Matches[2].Trim()
}
foreach ($k in 'RELEASE_SSH','RELEASE_DIR') {
    if (-not $cfg[$k]) { Fail "$k belum diisi di .release.env" }
}
$port = if ($cfg['RELEASE_SSH_PORT']) { $cfg['RELEASE_SSH_PORT'] } else { '22' }
$user = if ($cfg['RELEASE_USER']) { $cfg['RELEASE_USER'] } else { 'root' }

function Remote([string]$cmd) {
    ssh -o BatchMode=yes -p $port "${user}@$($cfg['RELEASE_SSH'])" $cmd
    if ($LASTEXITCODE -ne 0) { Fail "perintah server gagal: $cmd" }
}
function Upload([string]$local, [string]$remoteName) {
    scp -q -P $port $local "${user}@$($cfg['RELEASE_SSH']):$($cfg['RELEASE_DIR'])/$remoteName"
    if ($LASTEXITCODE -ne 0) { Fail "upload gagal: $local" }
}

# ---------------------------------------------------------------- versions
function Get-Pubspec {
    $line = (Select-String -Path pubspec.yaml -Pattern '^version:\s*(\d+)\.(\d+)\.(\d+)\+(\d+)').Matches[0]
    return @{
        Major = [int]$line.Groups[1].Value; Minor = [int]$line.Groups[2].Value
        Patch = [int]$line.Groups[3].Value; Build = [int]$line.Groups[4].Value
    }
}
function Set-Pubspec([string]$dir, [string]$name, [int]$build) {
    $p = Join-Path $dir 'pubspec.yaml'
    (Get-Content $p) -replace '^version:.*$', "version: $name+$build" | Set-Content $p -Encoding utf8
}

$cur = Get-Pubspec
$newBuild = $cur.Build + 1
if ($PublishOnly) {
    $newBuild = $cur.Build
    $newName = "$($cur.Major).$($cur.Minor).$($cur.Patch)"
} else {
    if (-not $Type) { Fail 'Pilih -Type patch|minor|big|major' }
    $newName = switch ($Type) {
        'patch' { "$($cur.Major).$($cur.Minor).$($cur.Patch + 1)" }
        'minor' { "$($cur.Major).$($cur.Minor + 1).0" }
        'big'   { if ($cur.Minor -lt 5) { "$($cur.Major).5.0" } else { "$($cur.Major + 1).0.0" } }
        'major' { "$($cur.Major + 1).0.0" }
    }
    if ($Version) { $newName = $Version }
}

# ---------------------------------------------------------------- notes
$notesDir = Join-Path $Root 'release-notes'
if (-not (Test-Path $notesDir)) { New-Item -ItemType Directory -Force $notesDir | Out-Null }
$notesFile = Join-Path $notesDir ('{0:D4}-{1}.md' -f $newBuild, $newName)
if (-not (Test-Path $notesFile)) {
    $defaultMandatory = if ($Type -eq 'major') { 'true' } else { 'false' }
    @"
---
version: $newName
build: $newBuild
date: $(Get-Date -Format 'yyyy-MM-dd')
type: $Type
mandatory: $defaultMandatory
blocks: []
---
Tulis catatan rilis untuk pengguna di sini (Bahasa Indonesia, tanpa istilah teknis).

Yang baru
- ...

Perbaikan
- ...
"@ | Set-Content $notesFile -Encoding utf8
    Fail "Catatan rilis belum ada. Template dibuat di $notesFile - isi lalu jalankan ulang."
}
if ((Get-Content $notesFile -Raw) -match 'Tulis catatan rilis') {
    Fail "Isi dulu catatan rilis di $notesFile"
}

function Read-Note([string]$path) {
    $raw = Get-Content $path -Raw -Encoding utf8
    if ($raw -notmatch '(?s)^---\s*\r?\n(.*?)\r?\n---\s*\r?\n(.*)$') { Fail "Frontmatter rusak: $path" }
    $front = $Matches[1]; $body = $Matches[2].Trim(); $meta = @{}
    $front -split '\r?\n' | Where-Object { $_ -match '^(\w+):\s*(.*)$' } | ForEach-Object {
        $meta[$Matches[1]] = $Matches[2].Trim()
    }
    $blocks = @()
    if ($meta['blocks'] -match '\[(.*)\]') {
        $blocks = @($Matches[1] -split ',' | ForEach-Object { [int]$_.Trim() } | Where-Object { $_ })
    }
    return [pscustomobject]@{
        version = $meta['version']; build = [int]$meta['build']; date = $meta['date']
        type = $meta['type']; mandatory = ($meta['mandatory'] -eq 'true'); blocks = $blocks
        notes = $body
    }
}
$note = Read-Note $notesFile
if ($Mandatory) { $note.mandatory = $true }
if ($Optional) { $note.mandatory = $false }

Write-Host ("==> Rilis {0}+{1} ({2}) - update {3}" -f $newName, $newBuild, $note.type, $(if ($note.mandatory) { 'WAJIB' } else { 'opsional' }))

# ---------------------------------------------------------------- build
if (-not $PublishOnly) {
    Set-Pubspec $Root $newName $newBuild
    flutter build apk --release
    if ($LASTEXITCODE -ne 0) { Fail 'flutter build apk --release gagal' }
}

$fullName = "$newName+$newBuild"
$apkPath = Join-Path $Root "build\app\outputs\flutter-apk\app-release.apk"

$sdk = (Get-Content 'android\local.properties' | Where-Object { $_ -match '^sdk.dir=' }) `
        -replace '^sdk.dir=', '' -replace '\\\\', '\' -replace '\\:', ':'
$apksigner = Get-ChildItem (Join-Path $sdk 'build-tools') -Directory `
        | Sort-Object { [version]($_.Name -replace '[^0-9.].*', '') } `
        | Select-Object -Last 1 `
        | ForEach-Object { Join-Path $_.FullName 'apksigner.bat' }

if (-not (Test-Path $apkPath)) { Fail "APK tidak ditemukan: $apkPath" }
$certOut = & $apksigner verify --print-certs $apkPath 2>&1 | Select-String 'SHA-256'
if ("$certOut" -notmatch $ReleaseCert) {
    Fail "APK TIDAK ditandatangani kunci rilis. Periksa android/key.properties."
}
$apkSha = (Get-FileHash $apkPath -Algorithm SHA256).Hash.ToLower()
$apkSize = (Get-Item $apkPath).Length
Write-Host '==> Signature & SHA-256 OK'

# ---------------------------------------------------------------- manifest
$remote = "smartcook-$newName.apk"
# Fold every existing release-notes/*.md into history (newest first).
$all = Get-ChildItem $notesDir -Filter '*.md' | ForEach-Object { Read-Note $_.FullName } | Sort-Object build
$mandatoryBuilds = @($all | Where-Object { $_.mandatory -and $_.build -le $newBuild } | ForEach-Object build)
$minBuild = if ($mandatoryBuilds.Count) { ($mandatoryBuilds | Measure-Object -Maximum).Maximum } else { 1 }
$blocked = @($all | ForEach-Object { $_.blocks } | Where-Object { $_ } | Sort-Object -Unique)

$manifest = [ordered]@{
    version = $newName
    build = $newBuild
    minBuild = [int]$minBuild
    blockedBuilds = $blocked
    releaseType = $note.type
    date = $note.date
    notes = ($note.notes -split '\r?\n\s*\r?\n')[0].Trim()
    apks = @(@{
        abi = 'arm64'
        file = $remote
        sha256 = $apkSha
        sizeBytes = $apkSize
    })
    history = @($all | Sort-Object build -Descending | ForEach-Object {
        [ordered]@{
            version = $_.version; build = $_.build; date = $_.date
            type = $_.type; notes = $_.notes
        }
    })
}
$manifestPath = Join-Path $Root 'build\latest.json'
New-Item -ItemType Directory -Force (Split-Path $manifestPath) | Out-Null
[IO.File]::WriteAllText($manifestPath, ($manifest | ConvertTo-Json -Depth 6), [Text.UTF8Encoding]::new($false))

# ---------------------------------------------------------------- publish
$prevPath = Join-Path $Root 'build\latest.prev.json'
if (Test-Path $prevPath) { Remove-Item $prevPath }
Invoke-Quiet { ssh -o BatchMode=yes -p $port "${user}@$($cfg['RELEASE_SSH'])" `
        (sh -c "'cd $($cfg['RELEASE_DIR']) && (test -f latest.json && scp latest.json latest.prev.json)' || true'") }
# Actually pull via scp into local prev
Invoke-Quiet { scp -q -P $port "${user}@$($cfg['RELEASE_SSH']):$($cfg['RELEASE_DIR'])/latest.json" $prevPath }

Write-Host '==> Upload APK...'
Upload $apkPath $remote
Upload $manifestPath 'latest.json.tmp'
# Atomic swap on the server: copy current latest.json aside, then rename.
Remote ("cd {0} && (test -f latest.json && cp latest.json latest.prev.json || true) && mv latest.json.tmp latest.json" -f $cfg['RELEASE_DIR'])
Write-Host '==> Terbit di server.'

# ---------------------------------------------------------------- git
git add pubspec.yaml release-notes
git -c user.name="Sulthan Adam Rahmadi" -c user.email="sultanadamr@gmail.com" commit -q -m "[chore] release $fullName ($($note.type))"
$tagName = "app-v$fullName"
git tag -f $tagName
if (-not $NoPush) {
    git push -q origin main
    git push -q -f origin $tagName
}
Write-Host "==> Selesai: $fullName (tag $tagName)"