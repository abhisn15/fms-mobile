# Setup Release Signing untuk Google Play Store

## Masalah
Error: "You uploaded an APK or Android App Bundle that was signed in debug mode"

## Solusi: Buat Release Keystore

### 1. Generate Keystore

Jalankan di terminal (di folder `android/`):

```bash
cd android
keytool -genkey -v -keystore upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

**Isi informasi yang diminta:**
- **Keystore password**: Buat password yang kuat (simpan dengan aman!)
- **Key password**: Bisa sama dengan keystore password atau berbeda
- **Nama lengkap**: Nama Anda atau nama perusahaan
- **Organizational Unit**: Departemen (opsional)
- **Organization**: Nama perusahaan
- **City**: Kota
- **State**: Provinsi
- **Country code**: ID (untuk Indonesia)

**PENTING**: Simpan password dengan aman! Jika hilang, tidak bisa update app di Play Store.

### 2. Buat File `key.properties`

Buat file `android/key.properties` (copy dari `key.properties.example`):

```properties
storePassword=YOUR_KEYSTORE_PASSWORD
keyPassword=YOUR_KEY_PASSWORD
keyAlias=upload
storeFile=../upload-keystore.jks
```

**Ganti:**
- `YOUR_KEYSTORE_PASSWORD` → Password keystore yang Anda buat
- `YOUR_KEY_PASSWORD` → Password key yang Anda buat

### 3. Verifikasi Setup

Pastikan file ada:
- ✅ `android/upload-keystore.jks` (keystore file)
- ✅ `android/key.properties` (konfigurasi)

### 4. Rebuild Bundle dengan Release Signing

```bash
flutter clean
flutter build appbundle --release
```

Bundle sekarang akan di-sign dengan release keystore, bukan debug key.

### 5. Upload ke Play Store

Upload `build/app/outputs/bundle/release/app-release.aab` ke Google Play Console.

## Keamanan

⚠️ **PENTING**:
- **JANGAN commit** `upload-keystore.jks` dan `key.properties` ke Git!
- Simpan keystore di tempat yang aman (backup!)
- Jika keystore hilang, tidak bisa update app di Play Store
- File sudah di-ignore di `.gitignore`

## Troubleshooting

### Error: "keytool: command not found"
- Install Java JDK
- Atau gunakan path lengkap: `"C:\Program Files\Java\jdk-XX\bin\keytool.exe"`

### Error: "Keystore was tampered with, or password was incorrect"
- Pastikan password di `key.properties` benar
- Pastikan `keyAlias` benar (default: "upload")

### Error: "Signing config not found"
- Pastikan `key.properties` ada di folder `android/`
- Pastikan path `storeFile` benar (relatif ke `android/` folder)

## Alternatif: Google Play App Signing

Jika menggunakan **Google Play App Signing** (recommended):
1. Upload bundle dengan keystore sendiri (bisa debug untuk pertama kali)
2. Google akan generate upload key untuk Anda
3. Download upload certificate dari Play Console
4. Gunakan certificate tersebut untuk signing ke depannya

---

**Last Updated**: 2025-01-XX

