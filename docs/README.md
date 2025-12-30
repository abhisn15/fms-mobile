<div align="center">
  <img src="../assets/icon.png" alt="Atenim Logo" width="120" height="120">
</div>

# Dokumentasi Atenim Mobile App

Dokumentasi lengkap untuk perbaikan dan optimasi aplikasi Atenim Mobile.

## Daftar Dokumentasi

### 🔧 Perbaikan Bug

1. **[Camera Fix](CAMERA_FIX.md)**
   - Perbaikan preview kamera yang terlihat gepeng
   - Solusi aspect ratio untuk full screen tanpa distorsi
   - Default kamera depan untuk selfie

2. **[Check-Out Force Close Fix](CHECKOUT_FIX.md)**
   - Perbaikan force close di device low-end (Redmi 5)
   - Validasi ukuran file untuk mencegah OOM
   - Error handling untuk memory issues
   - Timeout protection untuk upload

3. **[Loading State Fix](LOADING_FIX.md)**
   - Perbaikan tombol check-in/check-out yang stuck loading
   - Menghapus pemanggilan duplikat loadAttendance
   - Memastikan loading state di-reset dengan benar

### Release & Distribusi

1. **[Release Notes v1.0.8](RELEASE_NOTES_v1.0.8.md)** - Catatan rilis versi
2. **[Release Signing Setup](RELEASE_SIGNING_SETUP.md)** - Setup signing untuk Play Store
3. **[Create Keystore](CREATE_KEYSTORE.md)** - Panduan membuat keystore
4. **[Play Store Upload Guide](PLAY_STORE_UPLOAD_GUIDE.md)** - Panduan upload ke Play Store
5. **[Google Play Description](GOOGLE_PLAY_DESCRIPTION.md)** - Listing description Play Store
6. **[Icon Setup](ICON_SETUP.md)** - Panduan setup icon aplikasi
7. **[Security Guide](SECURITY.md)** - Panduan keamanan konfigurasi

## Fitur Utama

### ✅ Check-In/Check-Out
- Selfie dengan kamera depan sebagai default
- GPS otomatis
- Validasi ukuran file untuk device low-end
- Error handling yang baik

### ✅ Camera
- Preview dengan aspect ratio yang benar
- Responsive untuk berbagai ukuran layar
- Permission handling
- Fallback resolution untuk device lama

### ✅ Memory Optimization
- Validasi ukuran file sebelum upload
- Error handling untuk OOM
- Timeout protection
- Pesan error yang jelas untuk user

## Troubleshooting

Jika mengalami masalah, lihat dokumentasi spesifik di atas atau cek [README utama](../README.md) untuk troubleshooting umum.

## Kontribusi

Untuk menambah dokumentasi baru, buat file `.md` di folder `docs/` dan tambahkan link di file ini.

