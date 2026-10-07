# Merilis SmartCook (APK)

Semua rilis lewat `scripts/build_android_release.ps1` + `scripts/release.ps1`
(SmartCook). Skrip ini membangun APK 64-bit & 32-bit, memastikan tanda tangan
rilis, menghitung SHA-256, menerbitkan ke server rilis, membuat git tag,
commit, dan push.

## Sekali di tiap laptop

1. `android/key.properties` + file kunci rilis (minta ke maintainer; **jangan**
   di-commit).
2. Salin `.release.env.example` → `.release.env` dan isi `RELEASE_SSH` (user@host)
   + `RELEASE_DIR` (folder `smartcook-releases` di VPS).

## Sebuah rilis — langkah operasional

```
pwsh .\scripts\build_android_release.ps1            # bangun + cek tanda tangan
pwsh .\scripts\release.ps1 -Type patch -Notes .\release-notes\0027-1.0.12.md
```

Apa yang terjadi:

1. Catatan rilis dari file MD wajib sudah ditulis sebelumnya — skrip gagal
   kalau tidak ada.
2. Versi di `pubspec.yaml` di-bump sesuai `-Type` (lihat §11.2 di root AGENTS.md).
3. APK arm64 + arm32 dibangun.
4. SHA-256 dihitung dan dibandingkan ke fingerprint rilis. APK yang tidak
   ditandatangani kunci rilis ditolak sebelum sampai ke server.
5. File diunggah ke server, manifest `latest.json` ditulis ulang, dan server
   restart.
6. Git commit + tag + push.
7. GitHub Release dibuat lewat `gh release create`.

Kalau langkah mana pun gagal, script exit non-zero dan tidak menyentuh apa
pun — tidak ada risiko setengah-rilis.

## Catatan rilis — ditulis sebelum rilis

File wajib di `smartcook-frontend/release-notes/<build>-<version>.md`,
nama file padded 4-digit build agar urut saat di-`ls`. Bahasa Indonesia,
sopan, ringkas, dan ditonton seperti Kelvin di project sebelah.

Batas:

- Tidak ada jargon teknis (server, token, fingerprint, debug log, telemetry).
- Tidak ada yang menyebut nama developer atau commit.
- Tidak ada referensi ke nama aplikasi internal.
- Frontend 4 sections maksimal: `Yang baru`, `Perbaikan`, `Segera lain` (header).
  Bullets singkat, satu kalimat per poin. Hindari kata-kata yang sama di awal
  bullet supaya tidak monoton.
- Hindari emoji berlebihan. Kalau pakai, satu saja di paling strategis.

Penomoran build selalu naik. Frontend tidak pernah reuse build number, tidak
pernah turun. Rollback resmi = rilis patch dengan catatan yang menjelaskan
"kembali naik 1 versi sekaligus karena…"。

## Setelah rilis — verifikasi end-to-end

```
# 1. server healthy
curl -sS -o /dev/null -w "health=%{http_code}\n" \
  http://127.0.0.1:2122/api/health

# 2. manifest matches reality
cd /root/smartcook-releases && node -e "
require('dotenv').config();
const {parseReleaseManifest} = require('/root/smartcook-backend/src/modules/app/schema');
const fs = require('fs'); const crypto = require('crypto');
const m = parseReleaseManifest(fs.readFileSync('latest.json','utf8'));
for (const a of m.apks) {
  const real = crypto.createHash('sha256').update(fs.readFileSync(a.file)).digest('hex');
  console.log(a.abi, real === a.sha256 ? 'MATCH' : 'MISMATCH');
}
"

# 3. GitHub release page
gh release view vX.Y.Z -X

# 4. forced update matrix (older build = MANDATORY, equal = no dialog)
for b in <old> <previous> <current>; do
  curl -sS -H "X-Smartcook-Cert: $CERT" -H "X-Smartcook-Build: $b" \
    http://127.0.0.1:2122/api/app/version | jq '.data.mandatory'
done
```

## Yang selalu ditolak otomatis

- APK dengan tanda tangan rilis berbeda.
- APK yang Android `versionCode`-nya tidak sama dengan `+N` di `pubspec.yaml`
  (lihat root AGENTS.md §update-contracts).
- Catatan rilis yang mengandung nama developer, commit hash, atau jargon internal.
- Build number yang sama atau lebih kecil dari yang sudah diterbitkan.
- Release sebelum `flutter analyze lib` lulus.