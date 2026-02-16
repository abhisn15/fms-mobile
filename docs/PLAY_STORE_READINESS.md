# Kesiapan FMS Mobile untuk Production (Play Store)

## ✅ Yang Sudah Siap

| Item | Status |
|------|--------|
| **Versi app** | `1.5.3+30` (versionName + versionCode) di `pubspec.yaml` |
| **Application ID** | `com.atenim` (unik untuk Play Store) |
| **Release signing** | Konfigurasi di `android/app/build.gradle.kts` — pakai `key.properties` jika ada |
| **Fallback signing** | Jika `key.properties` tidak ada, pakai debug (hanya untuk testing; production harus pakai release keystore) |
| **Minify/Shrink** | `minifyEnabled = false`, `shrinkResources = false` — aman untuk rilis pertama |
| **Permissions** | Internet, Camera, Location (fine/coarse/background), Foreground Service, Notifications, Wake Lock — sesuai kebutuhan |
| **Google Maps** | API key dari `.env` (`GOOGLE_MAPS_API_KEY`) via manifest placeholder |
| **Keamanan** | `.env` dan `key.properties` / `*.jks` di-ignore Git |
| **API URL** | Dari `.env` (`API_BASE_URL`); fallback hanya untuk emulator |
| **Dokumentasi** | `RELEASE_SIGNING_SETUP.md`, `CREATE_KEYSTORE.md`, `SECURITY.md`, `playstore-location-troubleshooting.md` |

---

## ⚠️ Yang Harus Dilakukan Sebelum Upload Play Store

### 1. Release keystore & signing (wajib)

- Buat keystore: ikuti `docs/CREATE_KEYSTORE.md` atau `docs/RELEASE_SIGNING_SETUP.md`.
- Letakkan:
  - `android/key.properties` (berisi `storePassword`, `keyPassword`, `keyAlias`, `storeFile`).
  - File keystore (mis. `android/upload-keystore.jks`) sesuai `storeFile` di `key.properties`.
- **Jangan** commit kedua file ini ke Git (sudah di-ignore).
- Tanpa ini, build release akan pakai debug signing dan Play Store akan menolak upload.

### 2. File `.env` untuk production

- Di root project `fms_mobile/` harus ada file `.env` (tidak di-commit).
- Untuk build production, isi minimal:
  - `API_BASE_URL=https://your-production-api.com` (tanpa trailing slash).
  - `GOOGLE_MAPS_API_KEY=...` (untuk Maps di release).
  - `GCS_BUCKET_NAME=...` jika dipakai.
- Tanpa `API_BASE_URL` production, app akan pakai default emulator (`http://10.0.2.2:3001`) di release — tidak boleh untuk production.

### 3. Build App Bundle (AAB)

```bash
cd c:\Abhi\projects\fms_mobile
flutter clean
flutter pub get
flutter build appbundle --release
```

- Output: `build/app/outputs/bundle/release/app-release.aab`.
- Upload file ini ke Google Play Console (Production atau Internal testing).

### 4. Google Play Console

- **App content**: Privacy policy URL (wajib jika ada data pribadi).
- **Sensitive permissions**: Isi form “Background location” dan “Foreground service” — gunakan penjelasan di `playstore-location-troubleshooting.md` (tracking lokasi karyawan untuk absensi, hanya saat check-in, dll.).
- **Store listing**: Judul, deskripsi pendek/panjang, screenshot, icon 512x512, feature graphic jika diminta.
- **Pricing**: Tetapkan free/paid.
- **Target audience**: Pilih usia & negara.

### 5. (Opsional) Naikkan version sebelum rilis

- Edit `pubspec.yaml`: `version: 1.5.3+30` → naikkan misalnya jadi `1.5.4+31` (versionName+versionCode) setiap rilis baru ke Play Store.

---

## Ringkasan

- **Kode & konfigurasi**: Sudah siap untuk production (signing config, env, permissions, docs).
- **Yang wajib Anda siapkan**:  
  1) Release keystore + `key.properties`,  
  2) `.env` production (API_BASE_URL + GOOGLE_MAPS_API_KEY),  
  3) Build AAB dengan `flutter build appbundle --release`,  
  4) Isian di Play Console (kebijakan privasi, izin sensitif, store listing).

Setelah keystore dan `.env` production siap, jalankan `flutter build appbundle --release`; jika berhasil, app siap di-upload ke Play Store.
