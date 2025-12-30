# Google Play Store Upload Guide

## Error yang Terjadi

1. **"You need to upload an APK or Android App Bundle"**
2. **"You can't rollout this release because it doesn't allow any existing users to upgrade"**
3. **"This release does not add or remove any app bundles"**

## Solusi

### 1. Update Version Code

Edit `pubspec.yaml`:
```yaml
version: 1.0.0+2  # +2 = version code (harus lebih tinggi dari versi sebelumnya)
```

Jika ini release pertama, gunakan:
```yaml
version: 1.0.0+1
```

### 2. Rebuild Bundle dengan Version Baru

```bash
flutter clean
flutter pub get
flutter build appbundle --release
```

### 3. Upload ke Play Console

1. Buka [Google Play Console](https://play.google.com/console)
2. Pilih aplikasi Anda
3. **Production** → **Create new release** (atau **Internal testing** untuk testing)
4. Upload file: `build/app/outputs/bundle/release/app-release.aab`
5. Isi **Release notes**
6. **Save** → **Review release** → **Start rollout**

### 4. Pastikan App Signing

**PENTING**: Untuk production, jangan gunakan debug signing!

Setup app signing:
1. Di Play Console: **Setup** → **App signing**
2. Google akan generate signing key untuk Anda (recommended)
3. Atau upload keystore sendiri

### 5. Checklist Upload

- [ ] Version code lebih tinggi dari versi sebelumnya
- [ ] Bundle file berhasil di-build (`app-release.aab`)
- [ ] File size < 150MB (bundle Anda ~50MB ✅)
- [ ] App signing sudah dikonfigurasi
- [ ] Release notes sudah diisi
- [ ] Screenshots dan metadata sudah lengkap (jika first release)

## Troubleshooting

### Error: "Version code already exists"
- Update version code di `pubspec.yaml` ke angka yang lebih tinggi
- Rebuild bundle

### Error: "App bundle not found"
- Pastikan file `app-release.aab` ada di `build/app/outputs/bundle/release/`
- Cek ukuran file (harus > 0 bytes)

### Error: "Signing key mismatch"
- Pastikan menggunakan keystore yang sama untuk semua release
- Atau gunakan Google Play App Signing (recommended)

## Quick Fix

1. Update version:
   ```yaml
   version: 1.0.0+2
   ```

2. Rebuild:
   ```bash
   flutter clean
   flutter build appbundle --release
   ```

3. Upload file baru ke Play Console

---

**File bundle location**: `build/app/outputs/bundle/release/app-release.aab`

