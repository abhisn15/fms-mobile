# FMS MOBILE — Business Flow Documentation

> Dokumen ini menjelaskan **alur bisnis end-to-end** dari aplikasi mobile Atenim Workforce (Flutter), termasuk koneksi ke backend Atenim (Next.js) dan mekanisme offline.

---

## Daftar Isi

- [Gambaran Umum Aplikasi](#gambaran-umum-aplikasi)
- [Arsitektur Mobile App](#arsitektur-mobile-app)
- [Koneksi ke Backend (atenim)](#koneksi-ke-backend-atenim)
- [Flow 1 — Autentikasi & Manajemen Sesi](#flow-1--autentikasi--manajemen-sesi)
- [Flow 2 — Home / My Day](#flow-2--home--my-day)
- [Flow 3 — Absensi (Check-in / Check-out)](#flow-3--absensi-check-in--check-out)
- [Flow 4 — Istirahat (Break)](#flow-4--istirahat-break)
- [Flow 5 — Shift & Jadwal](#flow-5--shift--jadwal)
- [Flow 6 — Aktivitas Harian](#flow-6--aktivitas-harian)
- [Flow 7 — Patroli & Checkpoint (Security)](#flow-7--patroli--checkpoint-security)
- [Flow 8 — Request (Izin/Cuti/Sakit)](#flow-8--request-izincutisakit)
- [Flow 9 — Laporan Kejadian (Incident Report)](#flow-9--laporan-kejadian-incident-report)
- [Flow 10 — Tim & Tugas (Leader)](#flow-10--tim--tugas-leader)
- [Flow 11 — Checkpoint Leader](#flow-11--checkpoint-leader)
- [Flow 12 — Payroll Slip](#flow-12--payroll-slip)
- [Flow 13 — Realtime Location Tracking](#flow-13--realtime-location-tracking)
- [Flow 14 — Offline & Sync](#flow-14--offline--sync)
- [Flow 15 — Versi App & Update Check](#flow-15--versi-app--update-check)
- [Peta Screen ↔ Provider ↔ Service ↔ Endpoint](#peta-screen--provider--service--endpoint)
- [Panduan Menambah Fitur Baru](#panduan-menambah-fitur-baru)

---

## Gambaran Umum Aplikasi

FMS Mobile adalah **aplikasi Flutter** untuk karyawan dan leader di lapangan. Aplikasi ini merupakan **klien mobile** dari backend Atenim (Next.js) dan menyediakan fitur:

- Absensi (check-in/out dengan selfie + GPS)
- Istirahat (break session)
- Aktivitas harian & patroli keamanan
- Request izin/cuti/sakit
- Laporan kejadian
- Manajemen tim & tugas (untuk leader)
- Slip gaji
- Realtime location tracking

**Role yang didukung:** Karyawan dan Leader (subset dari karyawan yang memiliki tim).

---

## Arsitektur Mobile App

```
┌──────────────────────────────────────────────────────────┐
│                     FMS MOBILE (Flutter)                  │
│                                                          │
│  ┌──────────┐    ┌──────────┐    ┌──────────────────┐   │
│  │ Screens  │───▶│ Providers│───▶│    Services       │   │
│  │ (UI)     │    │ (State)  │    │ (API + Business)  │   │
│  └──────────┘    └──────────┘    └────────┬─────────┘   │
│                                           │              │
│                                           ▼              │
│                                  ┌────────────────┐      │
│                                  │   ApiService    │      │
│                                  │   (Dio + Cookie)│      │
│                                  └────────┬───────┘      │
│                                           │              │
│  ┌─────────────────────┐                  │              │
│  │ OfflineStorageService│◀── fallback ────┘              │
│  │ (SharedPreferences)  │                                │
│  └──────────────────────┘                                │
└──────────────────────────────────────────────────────────┘
                         │
                         ▼ HTTP (Cookie session)
┌──────────────────────────────────────────────────────────┐
│              ATENIM BACKEND (Next.js)                     │
│              API_BASE_URL dari .env                       │
└──────────────────────────────────────────────────────────┘
```

### State Management: Provider

| Provider | Tanggung Jawab |
|----------|----------------|
| `AuthProvider` | Login/logout, user data, OTP, cache user |
| `AttendanceProvider` | Absensi, check-in/out, break, shift |
| `ShiftProvider` | Jadwal shift |
| `ActivityProvider` | Aktivitas harian, patroli, sync offline |
| `RequestProvider` | Request izin/cuti |
| `CheckpointProvider` | Checkpoint ESS & leader |
| `ConnectivityProvider` | Status online/offline |
| `DeveloperOptionsProvider` | Opsi developer (mock GPS warning) |

---

## Koneksi ke Backend (atenim)

### Base URL

File `.env` (asset Flutter):
```
API_BASE_URL=http://192.168.x.x:2025   # LAN / development
API_BASE_URL=https://atenim.domain.com  # production
```

Dibaca via `ApiConfig.baseUrl` → `flutter_dotenv`.

### Autentikasi: Cookie Session

Mobile **TIDAK** menggunakan Bearer token. Mekanisme auth sama persis dengan browser web:

1. Login → backend set `Set-Cookie: atenim_session=...`
2. Dio interceptor simpan cookie ke `SharedPreferences`
3. Setiap request berikutnya, cookie diset di header `Cookie`
4. Session expired (401/403 di `/api/session`) → auto logout

### Gambar / File

URL gambar di-resolve melalui `ApiConfig.getImageUrl()`:
- Jika path relatif → `API_BASE_URL + path`
- Jika GCS URL → langsung pakai (bucket dari `GCS_BUCKET_NAME`)

---

## Flow 1 — Autentikasi & Manajemen Sesi

```
[Buka App] ──▶ AuthProvider.init()
                    │
                    ▼
            Ada cached user di SharedPreferences?
                    │
           ┌────────┴────────┐
           │                 │
          Ya               Tidak
           │                 │
           ▼                 ▼
    GET /api/session     Tampilkan LoginScreen
    (validasi cookie)          │
           │                   ▼
    ┌──────┴──────┐     POST /api/auth/login
    │             │     (email/NIK + password)
  Valid       Invalid          │
    │             │            ▼
    │          Clear cache  Set cookie
    │          → LoginScreen   │
    │                          │
    ▼                          ▼
  Cek: perlu set password?
    │
  ┌─┴──────────────┐
  │                │
  Ya              Tidak
  │                │
  ▼                ▼
ForcePassword   HomeScreen
Screen               │
  │                  ▼
  └──────▶    [App Siap Digunakan]
```

**Forgot password flow:**
1. `POST /api/auth/forgot-password` → kirim OTP ke email
2. `POST /api/auth/verify-otp` → verifikasi kode OTP
3. `POST /api/auth/reset-password` → set password baru

---

## Flow 2 — Home / My Day

```
[HomeScreen] ──PageView──▶ 4 Tab:
    │
    ├─ Tab 0: HomeTab (My Day)
    │   ├─ Status absensi hari ini
    │   ├─ Durasi kerja real-time
    │   ├─ Info shift yang di-assign
    │   ├─ Tombol Check-in / Check-out
    │   ├─ Riwayat 10 hari terakhir
    │   └─ Checkpoint progress (jika ada)
    │
    ├─ Tab 1: AttendanceScreen (Riwayat)
    │
    ├─ Tab 2: ActivityScreen (Aktivitas)
    │
    └─ Tab 3: MoreSheet (Menu Lainnya)
        ├─ Request (Izin/Cuti)
        ├─ Laporan Kejadian
        ├─ Patroli (jika security)
        ├─ Team (jika leader)
        ├─ Slip Gaji
        └─ Pengaturan / Profil
```

---

## Flow 3 — Absensi (Check-in / Check-out)

```
[HomeTab] ──Belum check-in──▶ Tampilkan tombol Check-In
                                    │
                                    ▼
                          Ada shift assignment?
                          ┌────────┴────────┐
                          │                 │
                        Ya                Tidak
                        (locked)          (pilih manual)
                          │                 │
                          └────────┬────────┘
                                   ▼
                          Buka CameraScreen
                          → Ambil selfie
                                   │
                                   ▼
                          Ambil GPS (geolocator)
                                   │
                                   ▼
                   POST /api/ess/attendance/check-in
                   (FormData: foto, shiftId, lat, lng)
                                   │
                          ┌────────┴────────┐
                          │                 │
                       Sukses             Gagal
                          │                 │
                    Update state      Tampilkan error
                    Mulai background   (atau simpan offline)
                    tracking
                          │
              ··· Karyawan bekerja ···
                          │
                          ▼
              Tombol Check-Out muncul
                          │
                          ▼
                   POST /api/ess/attendance/check-out
                   (FormData: foto, lat, lng)
                          │
                          ▼
                   Stop background tracking
                   Update state
```

---

## Flow 4 — Istirahat (Break)

```
[Sudah check-in] ──Start Break──▶ POST .../break/start
                                        │
                                        ▼
                                  Timer istirahat berjalan
                                        │
                                        ▼
                  ──End Break──▶ POST .../break/end
                                        │
                                        ▼
                                  Durasi tercatat
```

---

## Flow 5 — Shift & Jadwal

```
[Karyawan] ──Lihat Jadwal──▶ GET /api/ess/shifts/schedule
                                    │
                                    ▼
                          MyShiftScreen
                          (kalender + daftar shift per hari)

[Leader] ──Kelola Shift Tim──▶ GET /api/leader/shifts/master
                                GET /api/leader/shifts/assignments
                                POST/DELETE .../assignments
                                    │
                                    ▼
                          TeamShiftManageScreen
                          (assign shift ke anggota)
```

---

## Flow 6 — Aktivitas Harian

```
[Karyawan] ──Buka Aktivitas──▶ GET /api/ess/activities
                                    │
                                    ▼
                          ActivityScreen (daftar)
                                    │
                  ──Tambah──▶ ActivityFormScreen
                              (summary, highlights, blockers,
                               plans, sentiment, focus hours, foto)
                                    │
                                    ▼
                          POST /api/ess/activity
                          (multipart: data + foto)
                                    │
                          ┌─────────┴─────────┐
                          │                   │
                       Online              Offline
                          │                   │
                    Kirim langsung      Simpan ke pending
                    ke API              (OfflineStorageService)
                          │                   │
                          └─────────┬─────────┘
                                    ▼
                          Aktivitas tersimpan
```

---

## Flow 7 — Patroli & Checkpoint (Security)

```
[Security] ──Buka Patroli──▶ PatroliScreen
                                    │
                              Isi summary
                                    │
              ┌─────────────────────┤ (per checkpoint)
              │                     │
              ▼                     ▼
       Ambil foto            Isi findings
       (CameraScreen)        GPS otomatis
              │                     │
              └──────────┬──────────┘
                         ▼
                  Tandai checkpoint selesai
                  (ulangi sampai semua selesai)
                         │
                         ▼
              POST /api/ess/activity
              (type: patroli, checkpoints JSON, foto)
                         │
                         ▼
              PatroliActivity tersimpan di backend
```

---

## Flow 8 — Request (Izin/Cuti/Sakit)

```
[Karyawan] ──Buka Request──▶ GET /api/ess/requests
                                    │
                                    ▼
                          RequestsScreen (daftar)
                                    │
                  ──Buat Baru──▶ RequestFormScreen
                                 (jenis, tanggal, alasan)
                                    │
                                    ▼
                          POST /api/ess/requests
                                    │
                                    ▼
                          Status: PENDING
                                    │
                          (Menunggu approval dari
                           Supervisor/Admin via web)
                                    │
                          ┌─────────┴─────────┐
                          │                   │
                      APPROVED             REJECTED
                          │
                   Status: BERLANGSUNG
                   → Disable check-in, aktivitas, patroli
```

---

## Flow 9 — Laporan Kejadian (Incident Report)

```
[Karyawan] ──Buka Incident──▶ GET /api/ess/incident-report
                                    │
                                    ▼
                          IncidentReportScreen (daftar)
                                    │
                  ──Buat Baru──▶ IncidentReportFormScreen
                                 (deskripsi, foto, GPS)
                                    │
                                    ▼
                          POST /api/ess/incident-report
                          (multipart: data + foto)
                                    │
                                    ▼
                          Laporan tersimpan
```

---

## Flow 10 — Tim & Tugas (Leader)

```
[Leader] ──Buka Team──▶ GET /api/leader/teams
                         GET /api/leader/teams/members
                                    │
                                    ▼
                          TeamScreen (daftar anggota)
                                    │
              ──Monitoring──▶ GET /api/leader/attendance
                              (lihat absensi anggota)
                                    │
              ──Tugas──▶ TeamTasksScreen
                         GET /api/leader/tasks
                         POST /api/leader/tasks (buat tugas)
                         PATCH /api/leader/tasks/:id (update)
                         DELETE /api/leader/tasks/:id (hapus)
                                    │
[Karyawan] ──Lihat Tugas──▶ GET /api/ess/tasks
```

---

## Flow 11 — Checkpoint Leader

```
[Leader] ──Template──▶ GET /api/leader/checkpoint-templates
                        (template checkpoint yang tersedia)
                                    │
                                    ▼
         ──Assign──▶ POST /api/leader/checkpoint-assignments
                     (assign template ke anggota tim)
                                    │
                                    ▼
         ──Monitor──▶ GET /api/leader/checkpoint-progress
                      (lihat progress per anggota)
                                    │
                                    ▼
[Karyawan] ──Kerjakan──▶ GET /api/ess/activity/checkpoints
                          POST /api/ess/activity/checkpoint-complete
```

---

## Flow 12 — Payroll Slip

```
[Karyawan] ──Buka Slip Gaji──▶ GET /api/ess/payroll-slips
                                       │
                                       ▼
                             PayrollSlipsScreen (daftar)
                                       │
                      ──Lihat Detail──▶ GET /api/ess/payroll-slips/:id/pdf
                                        atau
                                        GET .../webview-token
                                       │
                                       ▼
                             PDF Viewer / WebView
```

---

## Flow 13 — Realtime Location Tracking

```
[Check-in berhasil] ──Mulai Tracking──▶ BackgroundTrackingService
                                               │
                                    (interval: setiap beberapa detik)
                                               │
                                               ▼
                                    Ambil GPS (geolocator)
                                               │
                                               ▼
                              POST /api/supervisor/attendance/realtime/log
                              (lat, lng, durasi, timestamp)
                                               │
                              ··· Terus berjalan sampai check-out ···
                                               │
[Check-out] ──Stop Tracking──▶ Hentikan background service
```

**Area monitoring alert (dari backend):**
- Warning: > 60 menit di lokasi sama
- Critical: > 120 menit di lokasi sama
- Notifikasi lokal di mobile

---

## Flow 14 — Offline & Sync

```
[ConnectivityProvider] ──Monitor status jaringan──▶
                                    │
                     ┌──────────────┴──────────────┐
                     │                             │
                  Online                        Offline
                     │                             │
              Kirim langsung              Simpan ke pending queue
              ke API                      (OfflineStorageService
                     │                     → SharedPreferences)
                     │                             │
                     │                    Data yang di-queue:
                     │                    • Check-in/out
                     │                    • Aktivitas
                     │                    • Patroli
                     │                    • Request
                     │                    • Location logs
                     │                             │
                     │              ┌──────────────┘
                     │              │ (saat kembali online)
                     │              ▼
                     │     syncPendingActivities()
                     │     syncPendingCheckIn/Out()
                     │     dll.
                     │              │
                     └──────────────┘
                              │
                              ▼
                    Data ter-sync ke backend
```

**Cache lokal (SharedPreferences):**
- `user_data` — data user (untuk tampilan cepat)
- `cookies` — session cookie
- `is_logged_in` — flag login
- `cached_attendance`, `cached_shifts`, `cached_activities`, `cached_requests` — snapshot data
- `pending_*` — antrian data yang belum terkirim

---

## Flow 15 — Versi App & Update Check

```
[App startup] ──▶ GET /api/version?platform=android
                         │
                         ▼
                 Bandingkan versi lokal vs server
                         │
              ┌──────────┴──────────┐
              │                     │
          Sama/lebih baru       Ada update
              │                     │
           (lanjut)            Tampilkan dialog
                                    │
                         ┌──────────┴──────────┐
                         │                     │
                     Opsional              Wajib (force)
                         │                     │
                    Bisa dismiss          Harus update
                                        (buka Play Store)
```

---

## Peta Screen ↔ Provider ↔ Service ↔ Endpoint

| Screen | Provider | Service | Endpoint Utama |
|--------|----------|---------|----------------|
| `LoginScreen` | `AuthProvider` | `AuthService` | `POST /api/auth/login` |
| `ForcePasswordScreen` | `AuthProvider` | `AuthService` | `POST /api/ess/profile/set-password` |
| `HomeTab` | `AttendanceProvider`, `ShiftProvider` | `AttendanceService` | `GET /api/ess/attendance/session/current`, `GET /api/ess/shifts` |
| `AttendanceScreen` | `AttendanceProvider` | `AttendanceService` | `GET /api/ess/attendance` |
| Check-in/out | `AttendanceProvider` | `AttendanceService` | `POST /api/ess/attendance/check-in`, `/check-out` |
| Break | `AttendanceProvider` | `AttendanceService` | `POST .../break/start`, `.../break/end` |
| `MyShiftScreen` | `ShiftProvider` | `ShiftScheduleService` | `GET /api/ess/shifts/schedule` |
| `ActivityScreen` | `ActivityProvider` | `ActivityService` | `GET /api/ess/activities` |
| `ActivityFormScreen` | `ActivityProvider` | `ActivityService` | `POST /api/ess/activity` |
| `PatroliScreen` | `ActivityProvider` | `ActivityService` | `POST /api/ess/activity` (type: patroli) |
| `RequestsScreen` | `RequestProvider` | `RequestService` | `GET /api/ess/requests` |
| `RequestFormScreen` | `RequestProvider` | `RequestService` | `POST /api/ess/requests` |
| `IncidentReportScreen` | — | — | `GET /api/ess/incident-report` |
| `IncidentReportFormScreen` | — | — | `POST /api/ess/incident-report` |
| `TeamScreen` | — | `TeamService` | `GET /api/leader/teams`, `.../members` |
| `TeamTasksScreen` | — | `TeamService` | `GET/POST/PATCH/DELETE /api/leader/tasks` |
| `TeamShiftManageScreen` | — | `AttendanceService` | `GET/POST/DELETE /api/leader/shifts/assignments` |
| `LeaderCheckpointTasksScreen` | `CheckpointProvider` | `CheckpointService` | `GET/POST /api/leader/checkpoint-*` |
| `PayrollSlipsScreen` | — | `PayrollSlipService` | `GET /api/ess/payroll-slips` |
| `ProfileScreen` | `AuthProvider` | `ProfileService` | `PUT /api/ess/profile` |
| Background Tracking | — | `BackgroundTrackingService`, `RealtimeLocationService` | `POST /api/supervisor/attendance/realtime/log` |

---

## Panduan Menambah Fitur Baru

Setiap fitur baru di mobile mengikuti pola yang konsisten:

### 1. Definisikan endpoint di backend (atenim)

Buat route di `app/api/<namespace>/<feature>/route.ts`. Pastikan:
- Namespace sesuai role (`ess` untuk karyawan, `leader` untuk leader)
- Pakai `getSessionFromRequest()` untuk auth
- Response shape konsisten (JSON)

### 2. Tambah path di `api_config.dart`

```dart
static String get newFeature => '/api/ess/new-feature';
```

### 3. Buat model di `lib/models/`

```dart
class NewFeatureModel {
  final int id;
  final String name;
  NewFeatureModel({required this.id, required this.name});
  factory NewFeatureModel.fromJson(Map<String, dynamic> json) => ...;
}
```

### 4. Buat service di `lib/services/`

```dart
class NewFeatureService {
  final ApiService _api = ApiService();
  Future<List<NewFeatureModel>> getAll() async {
    final response = await _api.get(ApiConfig.newFeature);
    return (response.data as List).map((e) => NewFeatureModel.fromJson(e)).toList();
  }
}
```

### 5. Buat provider di `lib/providers/`

```dart
class NewFeatureProvider extends ChangeNotifier {
  List<NewFeatureModel> _items = [];
  bool _isLoading = false;
  // ... fetch, notifyListeners, error handling
}
```

### 6. Buat screen di `lib/screens/`

Gunakan `Consumer<NewFeatureProvider>` untuk reactivity.

### 7. (Opsional) Dukung offline

Tambahkan logic di `OfflineStorageService` untuk cache dan pending queue.

### 8. Register provider

Di `main.dart`, tambahkan `ChangeNotifierProvider` baru di `MultiProvider`.

### 9. Tambah navigasi

Di `home_screen.dart` atau `main.dart` routes.

---

> **Catatan:** Dokumen ini merupakan peta bisnis flow tingkat tinggi untuk mobile app. Untuk detail backend dan endpoint lengkap, lihat [BUSINESS_FLOW.md di atenim](../../atenim/docs/BUSINESS_FLOW.md). Untuk panduan teknis mobile, lihat [README.md](../README.md).
