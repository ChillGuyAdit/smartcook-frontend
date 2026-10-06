# SmartCook — Releases

APK rilis resmi. Unduh sesuai arsitektur processor HP kamu:

| File | Untuk |
| --- | --- |
| `smartcook-1.0.9+10-arm64.apk` | 64-bit (semua HP modern, Android 5.0+) |
| `smartcook-1.0.9+10-arm32.apk` | 32-bit (HP lama / tablet entry-level) |

Cara cek arsitektur HP: Settings → About phone → Android version / processor, atau
di Google Play ketik aplikasi "CPU-Z".

Notes: `arm64` adalah pilihan utama untuk HP baru. Kalau install gagal dengan
`INSTALL_FAILED_NO_MATCHING_ABITS`, berarti HP kamu 32-bit — pakai file `arm32`.

## Memastikan file asli

Cocokkan SHA-256 APK ini dengan yang tercatat di server:

```
arm64  c139546fef50f47c6ad2691e6f8fbcffdc55852cedf723f2c4dcc98e7b59acbe
arm32  c6c355ba6955980c26015401a5802f441f6651c243cd78b4a3e0cbe13c58bcb1
```

## Catatan penting soal pembaruan otomatis

Mulai versi 1.0.9, nomor build aplikasi selalu sama dengan yang tertulis di
`pubspec.yaml` (`1.0.9+10` → build `10`).

APK versi 1.0.7 ke bawah memakai nomor build berbeda (2005/2006/2008) sehingga
**tidak bisa** menerima pembaruan otomatis dari server. Untuk pindah ke versi ini,
hapus manual SmartCook lalu pasang file di atas.