# Cara Membuat Keystore untuk Release Signing

## Opsi 1: Menggunakan Android Studio (Paling Mudah)

1. Buka **Android Studio**
2. **Build** → **Generate Signed Bundle / APK**
3. Pilih **Android App Bundle**
4. Klik **Create new...** untuk membuat keystore baru
5. Isi informasi:
   - **Key store path**: Pilih lokasi (misal: `android/upload-keystore.jks`)
   - **Password**: Buat password yang kuat
   - **Key alias**: `upload`
   - **Key password**: Bisa sama dengan keystore password
   - **Validity**: 10000 (atau lebih)
   - **Certificate**: Isi informasi Anda
6. Klik **OK** → keystore akan dibuat
7. **Jangan** build bundle sekarang, cukup ambil keystore-nya

## Opsi 2: Menggunakan Java JDK (Jika Terinstall)

Cari lokasi Java JDK, lalu jalankan:

```powershell
# Cek apakah Java terinstall
java -version

# Jika Java ada, cari keytool
# Biasanya di: C:\Program Files\Java\jdk-XX\bin\keytool.exe
# Atau di Android SDK: C:\Users\TPM\AppData\Local\Android\Sdk\jbr\bin\keytool.exe

# Jalankan keytool dengan path lengkap
& "C:\Users\TPM\AppData\Local\Android\Sdk\jbr\bin\keytool.exe" -genkey -v -keystore android\upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

## Opsi 3: Download Java JDK

Jika Java belum terinstall:

1. Download Java JDK dari: https://adoptium.net/
2. Install Java JDK
3. Set environment variable `JAVA_HOME`:
   ```powershell
   $env:JAVA_HOME = "C:\Program Files\Eclipse Adoptium\jdk-XX"
   ```
4. Tambahkan ke PATH:
   ```powershell
   $env:PATH += ";$env:JAVA_HOME\bin"
   ```
5. Jalankan keytool:
   ```powershell
   cd android
   keytool -genkey -v -keystore upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
   ```

## Opsi 4: Menggunakan Online Tool (Tidak Recommended)

⚠️ **TIDAK DISARANKAN** untuk production karena keamanan, tapi bisa digunakan untuk testing:
- https://keystore-explorer.org/ (download tool)
- Atau gunakan Android Studio (lebih aman)

## Setelah Keystore Dibuat

1. **Buat file `android/key.properties`**:
   ```properties
   storePassword=YOUR_KEYSTORE_PASSWORD
   keyPassword=YOUR_KEY_PASSWORD
   keyAlias=upload
   storeFile=../upload-keystore.jks
   ```

2. **Rebuild bundle**:
   ```powershell
   flutter clean
   flutter build appbundle --release
   ```

## Catatan Penting

- ⚠️ **Simpan keystore dengan aman!** Jika hilang, tidak bisa update app di Play Store
- ⚠️ **Jangan commit** keystore dan `key.properties` ke Git (sudah di-ignore)
- ✅ **Backup keystore** di tempat yang aman
- ✅ Gunakan password yang kuat

---

**Recommended**: Gunakan **Opsi 1 (Android Studio)** karena paling mudah dan aman.

