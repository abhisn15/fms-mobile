<div align="center">
  <img src="assets/icon.png" alt="Atenim Logo" width="120" height="120">
</div>

# Atenim Mobile App - Employee Management System

Aplikasi mobile Flutter untuk karyawan dengan semua fitur dari website employee, fokus pada absensi dan integrasi Google Cloud Storage untuk upload gambar.

## Fitur Utama

### ✅ Login (Hanya untuk Karyawan)
- Login hanya bisa dilakukan oleh user dengan role `karyawan`
- Session management dengan cookie-based authentication
- Auto-redirect ke home jika sudah login

### ✅ My Day (Home)
- Check-in dengan selfie dan GPS otomatis
- Check-out dengan selfie dan GPS otomatis
- Tampilan status kehadiran hari ini
- Durasi waktu bekerja (real-time)
- Informasi shift yang di-assign
- Riwayat kehadiran 10 hari terakhir

### ✅ Attendance (Absensi)
- Riwayat kehadiran lengkap
- Status kehadiran (Present, Late, Absent, Leave, Sick, Remote)
- Detail check-in dan check-out per hari
- Filter dan refresh data

### ✅ Daily Activity (Aktivitas Harian)
- Submit aktivitas harian dengan foto
- Summary, sentiment (positif/netral/negatif)
- Focus hours tracking
- Highlights, blockers, dan plans
- Upload foto langsung ke Google Cloud Storage
- GPS otomatis saat upload foto

### ✅ Leave Request (Request Izin)
- Buat leave request (izin, cuti, sakit)
- Pilih tanggal mulai dan akhir
- Alasan request
- Lihat status request (pending, approved, rejected, berlangsung)
- Riwayat semua request

### ✅ Patroli (Security Patrol)
- 8 checkpoint default untuk security
- Upload foto per checkpoint dengan GPS otomatis
- Summary dan notes untuk laporan patroli
- Semua foto terintegrasi langsung ke Google Cloud Storage
- Validasi semua checkpoint harus diselesaikan sebelum submit

### ✅ Profile (Profil)
- Lihat informasi profil
- Update foto profil dengan kamera
- Upload foto profil ke Google Cloud Storage
- Logout

## Teknologi yang Digunakan

- **Framework**: Flutter 3.10+
- **State Management**: Provider
- **HTTP Client**: Dio
- **Local Storage**: SharedPreferences
- **Image Picker**: image_picker & camera
- **Location**: geolocator
- **Permissions**: permission_handler
- **Date Formatting**: intl
- **Image Display**: cached_network_image

## Setup & Instalasi

### 1. Install Dependencies

```bash
cd fms_mobile
flutter pub get
```

### 2. Setup Environment Variables

Buat file `.env` di root folder `fms_mobile/` (copy dari `.env.example` jika ada):

```env
# API Configuration
# Pilih salah satu sesuai dengan environment Anda:

# 1. Android Emulator (default)
API_BASE_URL=http://10.0.2.2:3001

# 2. iOS Simulator
# API_BASE_URL=http://localhost:3001

# 3. Physical Device (ganti dengan IP komputer Anda)
# API_BASE_URL=http://192.168.1.100:3001

# 4. Production
# API_BASE_URL=https://atenim.tpm-facility.com

# Google Cloud Storage Configuration
GCS_BUCKET_NAME=mms.mindotek.com
```

**Cara menemukan IP komputer untuk Physical Device:**
- Windows: `ipconfig` (lihat IPv4 Address)
- Mac/Linux: `ifconfig` atau `ip addr` (lihat inet address)
- Pastikan device dan komputer dalam jaringan WiFi yang sama

**PENTING**: File `.env` sudah di-ignore oleh Git untuk keamanan. Jangan commit file `.env` ke repository!

Jika belum ada file `.env`, buat manual dengan isi di atas, atau copy dari `.env.example` jika tersedia.

### 3. Setup Permissions

#### Android (`android/app/src/main/AndroidManifest.xml`)

Tambahkan permissions:

```xml
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.CAMERA"/>
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>
```

#### iOS (`ios/Runner/Info.plist`)

Tambahkan keys:

```xml
<key>NSCameraUsageDescription</key>
<string>Aplikasi memerlukan akses kamera untuk mengambil foto absensi dan aktivitas</string>
<key>NSLocationWhenInUseUsageDescription</key>
<string>Aplikasi memerlukan akses lokasi untuk tracking absensi</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>Aplikasi memerlukan akses galeri foto untuk memilih foto</string>
```

### 4. Run App

```bash
flutter run
```

## Struktur Project

```
lib/
├── config/
│   └── api_config.dart          # Konfigurasi API endpoints
├── models/
│   ├── user_model.dart          # Model User
│   ├── attendance_model.dart     # Model Attendance
│   ├── shift_model.dart          # Model Shift
│   ├── activity_model.dart       # Model Activity & Patroli
│   └── request_model.dart        # Model Leave Request
├── services/
│   ├── api_service.dart          # HTTP client dengan cookie handling
│   ├── auth_service.dart         # Authentication service
│   ├── attendance_service.dart   # Attendance API calls
│   ├── activity_service.dart     # Activity & Patroli API calls
│   ├── request_service.dart      # Leave Request API calls
│   └── profile_service.dart      # Profile API calls
├── providers/
│   ├── auth_provider.dart        # Auth state management
│   ├── attendance_provider.dart  # Attendance state management
│   ├── shift_provider.dart       # Shift state management
│   ├── activity_provider.dart    # Activity state management
│   └── request_provider.dart     # Request state management
├── screens/
│   ├── auth/
│   │   └── login_screen.dart     # Login screen (karyawan only)
│   ├── home/
│   │   ├── home_screen.dart      # Bottom navigation wrapper
│   │   └── home_tab.dart         # My Day tab
│   ├── attendance/
│   │   └── attendance_screen.dart # Attendance history
│   ├── activity/
│   │   ├── activity_screen.dart  # Activity list
│   │   └── activity_form_screen.dart # Activity form
│   ├── requests/
│   │   ├── requests_screen.dart  # Request list
│   │   └── request_form_screen.dart # Request form
│   ├── patroli/
│   │   └── patroli_screen.dart  # Security patrol
│   ├── profile/
│   │   └── profile_screen.dart   # Profile management
│   └── camera/
│       └── camera_screen.dart    # Camera untuk foto
└── main.dart                     # App entry point
```

## Integrasi Google Cloud Storage

Semua upload gambar (check-in, check-out, activity, patroli checkpoint, profile) otomatis terintegrasi dengan backend yang sudah menggunakan Google Cloud Storage. Flow:

1. User mengambil foto dengan kamera atau memilih dari gallery
2. Foto dikirim ke backend API sebagai FormData
3. Backend mengkonversi ke WebP dan upload ke Google Cloud Storage
4. Backend mengembalikan public URL dari Google Cloud Storage
5. URL disimpan di database dan ditampilkan di aplikasi

**Tidak perlu konfigurasi Google Cloud di mobile app** - semua handling dilakukan di backend.

## Alur Check-In/Check-Out

1. User membuka aplikasi → Home tab
2. Jika belum check-in:
   - Pilih shift (jika belum di-assign admin)
   - Ambil selfie dengan kamera
   - GPS otomatis direkam saat submit
   - Submit check-in
3. Jika sudah check-in tapi belum check-out:
   - Tampilkan durasi waktu bekerja
   - Tombol check-out muncul
   - Ambil selfie untuk check-out
   - GPS otomatis direkam
   - Submit check-out

## Alur Patroli

1. User buka tab Patroli
2. Isi summary laporan patroli
3. Untuk setiap checkpoint:
   - Klik checkpoint untuk menyelesaikan
   - Ambil foto dengan kamera
   - Foto otomatis di-upload ke Google Cloud Storage
   - GPS otomatis direkam
   - Checkpoint ditandai selesai
4. Setelah semua checkpoint selesai:
   - Submit laporan patroli
   - Semua data (summary, checkpoints dengan foto & GPS) tersimpan

## Testing

### Test Login
- Email: `karyawan@example.com` (sesuaikan dengan data di database)
- Password: `Karyawan#123` (sesuaikan dengan konfigurasi backend)

### Test Check-In
1. Login sebagai karyawan
2. Buka Home tab
3. Klik "Check-In"
4. Ambil selfie
5. Submit

### Test Daily Activity
1. Buka tab "Aktivitas"
2. Klik tombol "+"
3. Isi form aktivitas
4. Ambil foto (opsional)
5. Submit

## Troubleshooting

### Error: Connection refused
- Pastikan backend server berjalan
- Cek base URL di `api_config.dart`
- Untuk device fisik, pastikan device dan komputer dalam jaringan yang sama

### Error: Camera not available
- Pastikan permission kamera sudah diberikan
- Cek `AndroidManifest.xml` atau `Info.plist`

### Error: Location not available
- Pastikan permission location sudah diberikan
- Pastikan GPS aktif di device

### Error: Upload failed
- Cek koneksi internet
- Pastikan backend Google Cloud Storage sudah dikonfigurasi dengan benar

### Error: Force close di device low-end
- Foto terlalu besar (>10MB) akan ditolak
- Aplikasi akan menampilkan error message yang jelas
- Coba ambil foto dengan resolusi lebih kecil

## Catatan Penting

1. **Login hanya untuk karyawan**: Aplikasi ini hanya bisa digunakan oleh user dengan role `karyawan`. Admin dan supervisor tidak bisa login.

2. **Semua foto terintegrasi dengan Google Cloud Storage**: Backend sudah menangani semua upload ke Google Cloud Storage, mobile app hanya mengirim file ke backend.

3. **GPS otomatis**: GPS direkam otomatis saat upload foto atau submit form, tidak perlu manual input koordinat.

4. **Session management**: Menggunakan cookie-based authentication, session dikelola otomatis oleh backend.

5. **Offline support**: Aplikasi belum support offline mode, pastikan koneksi internet tersedia.

6. **Memory optimization**: Aplikasi sudah dioptimasi untuk device low-end dengan validasi ukuran file dan error handling yang baik.

## Development

### Menambah Fitur Baru

1. Buat model di `lib/models/`
2. Buat service di `lib/services/`
3. Buat provider di `lib/providers/`
4. Buat screen di `lib/screens/`
5. Update navigation di `home_screen.dart`

### Menambah API Endpoint

1. Tambahkan endpoint di `lib/config/api_config.dart`
2. Buat method di service yang sesuai
3. Update provider untuk menggunakan method baru
4. Update UI untuk menggunakan provider

## Dokumentasi Tambahan

- [Camera Fix Documentation](docs/CAMERA_FIX.md) - Dokumentasi perbaikan camera preview
- [Release Notes](RELEASE_NOTES_v1.0.8.md) - Catatan rilis versi
- [Security](SECURITY.md) - Informasi keamanan
- [Play Store Upload Guide](PLAY_STORE_UPLOAD_GUIDE.md) - Panduan upload ke Play Store

## License

Internal use only - ATENIM WORKFORCE
