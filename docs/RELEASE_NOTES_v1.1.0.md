# Release Notes v1.1.0

## Perubahan Utama

### ✨ Fitur Baru & Peningkatan

#### 📍 Peningkatan Sistem Lokasi
- **Validasi radius lokasi untuk check-in & check-out sesuai site**
  - Check-in hanya bisa dilakukan di radius yang ditentukan untuk setiap site
  - Validasi lokasi otomatis untuk memastikan keakuratan absensi
  - Peringatan jelas jika berada di luar radius site

- **Info penempatan (site) dan instruksi GPS tampil lebih jelas di beranda**
  - Informasi site aktif ditampilkan prominently di dashboard
  - Instruksi GPS yang mudah dipahami untuk navigasi ke lokasi kerja
  - Status koneksi GPS real-time di beranda

#### 🔄 Pelacakan Lokasi Latar Belakang
- **Pelacakan lokasi latar belakang lebih stabil (foreground service & notifikasi)**
  - Foreground service untuk tracking lokasi yang lebih reliable
  - Notifikasi persistent yang menunjukkan status tracking aktif
  - Recovery otomatis saat app di-restart setelah force close
  - Optimasi interval update dari 30 detik ke 5 menit untuk hemat baterai

#### 🛡️ Perbaikan Stabilitas
- **Perbaikan stabilitas dan bug absensi**
  - Fix crash saat menggunakan kamera (unlockAutoFocus & DartMessenger)
  - Recovery system lengkap untuk force close scenarios
  - Optimasi memory dan resource management
  - Perbaikan error handling di seluruh aplikasi

### 🐛 Perbaikan Bug
- **Camera Stability**: Menghilangkan crash saat menggunakan kamera
- **Location Tracking**: Perbaikan tracking saat app di-background
- **Notification System**: Persistent notification untuk status check-in
- **Force Close Recovery**: Auto-recovery saat app di-restart

### 🔧 Perbaikan Teknis
- **Performance**: Optimasi battery usage dengan interval yang lebih efisien
- **Memory Management**: Cleanup resource yang lebih baik
- **Error Handling**: Comprehensive error handling untuk semua operasi
- **Background Services**: Stabilisasi background location tracking

## Catatan Penting
- Notifikasi check-in sekarang update setiap 5 menit (sebelumnya 30 detik) untuk hemat baterai
- Validasi lokasi sekarang lebih ketat sesuai radius site masing-masing
- Recovery system otomatis mengembalikan semua services setelah force close
- Aplikasi lebih stabil dan tahan terhadap berbagai kondisi penggunaan

## Untuk Play Store

### Short Description (80 karakter)
Update lokasi & stabilitas: validasi radius, GPS info jelas, tracking stabil, bug fixes.

### Full Description

**Atenim Mobile v1.1.0 - Update Lokasi & Stabilitas**

**Fitur Baru & Peningkatan:**
✅ **Validasi radius lokasi** untuk check-in & check-out sesuai site
✅ **Info penempatan (site) dan instruksi GPS** tampil lebih jelas di beranda
✅ **Pelacakan lokasi latar belakang lebih stabil** (foreground service & notifikasi)
✅ **Perbaikan stabilitas dan bug absensi** untuk pengalaman yang lebih baik

**Peningkatan Teknis:**
🔋 **Hemat Baterai** - Interval notifikasi dikurangi dari 30 detik ke 5 menit
🛡️ **Anti-Crash** - Sistem recovery lengkap untuk force close
📍 **GPS Stabil** - Tracking lokasi yang lebih reliable di background
⚡ **Performance** - Optimasi memory dan resource management

**Keamanan & Akurasi:**
- Validasi lokasi yang lebih ketat untuk mencegah absensi ilegal
- Recovery otomatis untuk semua data dan services
- Error handling comprehensive di seluruh aplikasi

Update ini membawa peningkatan signifikan dalam stabilitas aplikasi dan akurasi sistem absensi!

---

Terima kasih telah menggunakan Atenim Mobile!

