# Merilis SmartCook (APK)

Semua rilis lewat `scripts/release.ps1`. Skrip membangun APK arm64 + arm32 (universal dilarang, `--split-per-abi` dilarang), memastikan `versionCode == pubspec +N`, memverifikasi tanda tangan rilis, membuat `latest.json`, mengunggah ke server dengan swap atomik, lalu commit + tag `app-vX.Y.Z+N` + push.

## Satu nomor build

`pubspec +N` = Android `versionCode` = `build` di `latest.json` = nomor di nama file catatan rilis (`0014-1.0.13.md`). Tidak ada penomoran kedua. Build selalu naik tepat 1; nama versi boleh turun (rollback).

## Sekali di tiap laptop

1. `android/key.properties` + file kunci rilis (tidak di-commit).
2. Helper Paramiko (`sc_ssh.py`, `sc_put.py`, `creds.json`) di `%LOCALAPPDATA%\Temp\sc-ssh\` atau set `SC_SSH_DIR`. Tidak ada OpenSSH di mesin ini.
3. Opsional `.release.env` (gitignored): `RELEASE_DIR=/root/smartcook-releases`.

## Jenis rilis

| Jenis | `-Type` | Contoh | Kapan | Default update |
| --- | --- | --- | --- | --- |
| PATCH | `patch` | 1.0.13 -> 1.0.14 | bug fix, teks, performa | opsional |
| MINOR | `minor` | 1.0.x -> 1.1.0 | fitur baru kecil/sedang | opsional |
| BIG | `big` | 1.x -> 1.5.0 -> 2.0.0 | paket fitur besar / redesign | opsional |
| MAJOR | `major` | 1.x -> 2.0.0 | rombak total / API break | **wajib** |
| Pemulihan | `-Rollback` | lihat bawah | kembali ke versi stabil | wajib bagi build yang diblokir |

Wajib/opsional diatur `mandatory:` di catatan rilis. Rilis wajib menaikkan `minBuild` ke build itu; HP di bawahnya mendapat dialog yang tidak bisa ditutup. Rilis wajib lama tetap berlaku.

## Rilis biasa

```powershell
.\scripts\release.ps1 -Type patch
```

1. Run pertama: skrip membuat template `release-notes/<build>-<versi>.md` lalu berhenti. Isi, lalu jalankan ulang perintah yang sama.
2. Catatan rilis: Bahasa Indonesia, awam, tanpa jargon (lihat aturan di AGENTS.md). **Hanya perubahan di aplikasi.** Perubahan backend dicatat di `smartcook-backend`, bukan di sini. Rilis yang hanya mengubah backend tidak butuh APK.
3. Jangan hapus catatan lama: itu sumber riwayat di aplikasi.
4. Verifikasi (AGENTS.md > Verifying a release).

## Rollback

Android tidak bisa menurunkan build, jadi rollback = membangun ulang kode versi stabil dengan build baru:

```powershell
.\scripts\release.ps1 -Rollback -To 1.0.12 -Block 14
```

Build 14 masuk `blocks`, jadi HP yang memakainya wajib update; HP lain tetap opsional.

## Batal terbit

```powershell
.\scripts\release.ps1 -Unpublish
```

Mengembalikan `latest.prev.json`. HP yang sudah terlanjur memasang tetap butuh rollback.

## Jangan

- `flutter build apk --split-per-abi` atau APK universal.
- Mengedit `latest.json` di server dengan tangan. Selalu lewat skrip.
- Memakai ulang atau menurunkan nomor build.
- Menulis host/password server di file yang di-commit.
