# Analisis: Sesi & Update di FMS Mobile

## Pertanyaan
Apakah saat ada update (misalnya versi app baru), sesi pengguna berakhir? Apakah ada risiko bug?

---

## 1. Apakah update mengakhiri sesi?

**Tidak.** Saat ada update aplikasi (versi baru tersedia):

- **GlobalUpdateChecker** hanya memanggil **VersionService** dan menampilkan **UpdateDialog** (Update Wajib / Update Sekarang).
- **UpdateDialog** hanya membuka URL Play Store; **tidak ada** pemanggilan `logout()` atau clear session.
- Data user dan cookie tetap tersimpan di SharedPreferences.

**Kesimpulan:** Adanya notifikasi update **tidak** mengakhiri sesi. User tetap login sampai:
- User logout manual, atau
- Backend mengembalikan 401/403 pada validasi session (lihat bawah).

---

## 2. Kapan sesi dianggap berakhir (auto logout)?

Sesi dianggap berakhir dan **auto logout** hanya ketika:

1. App memanggil **GET `/api/session`** (validasi session), dan  
2. Backend mengembalikan **401 Unauthorized** atau **403 Forbidden**.

Alur singkat:

- **ApiService** (interceptor) mendeteksi 401/403 **hanya** untuk request ke `ApiConfig.session` (`/api/session`).
- Jika path = `/api/session` dan status 401/403 → memanggil callback **session expired** (hanya sekali per “kejadian”).
- Callback di **main.dart** memanggil `_handleAutoLogout()` → `AuthProvider.logout()` → clear data + redirect ke login + SnackBar: *"Sesi Anda telah berakhir. Silakan login kembali."*

Pemanggilan GET `/api/session` terjadi antara lain di:

- **AuthService.getCurrentUser()** (saat cek auth / refresh session).
- **AuthProvider._checkAuthStatus()** dan **AuthProvider._refreshSessionInBackground()**.

Jadi: sesi “berakhir” di sisi app hanya ketika **validasi session ke backend** gagal (401/403), bukan karena ada update.

---

## 3. Perilaku yang sudah diperbaiki: auto logout hanya sekali

**Masalah:** Flag `_isLoggingOut` di **ApiService** diset `true` saat session-expired callback dipanggil dan **tidak pernah di-reset**. Akibatnya, setelah user pernah kena auto logout lalu login lagi, jika session expired lagi, callback bisa tidak memicu logout kedua kali.

**Perbaikan:**

- Di **ApiService** ditambah method **`resetSessionExpiredState()`** yang meng-set `_isLoggingOut = false`.
- Di **main.dart**, di dalam `_handleAutoLogout()`, setelah `authProvider.logout()` selesai, dipanggil **`ApiService().resetSessionExpiredState()`**.

Dengan ini, setiap kali user sudah selesai logout (manual atau auto), state session-expired di-reset sehingga kejadian session expired berikutnya (setelah login lagi) tetap memicu auto logout dengan benar.

---

## 4. 401/403 dari endpoint lain (bukan /api/session)

Saat ini **hanya** 401/403 pada **GET `/api/session`** yang memicu auto logout.

Jika backend mengembalikan 401/403 pada endpoint lain (misalnya check-in, attendance, requests):

- App **tidak** melakukan auto logout.
- User hanya mendapat error untuk request tersebut (misalnya “Unauthorized”).
- UI tetap menganggap user masih login.

Ini bisa membingungkan user (“kenapa tiba-tiba gagal?”) jika penyebabnya session sudah invalid. Opsi pengembangan ke depan (opsional):

- Tetap hanya session endpoint yang trigger auto logout (aman, tidak ada salah panggil untuk 403 Forbidden yang memang bukan “session expired”), atau
- Memperluas aturan: 401/403 dari endpoint yang memerlukan auth (misalnya semua `/api/ess/*`) juga memicu session expired dan redirect ke login (perlu hati-hati agar 403 “forbidden” bukan session tidak salah diperlakukan sebagai “session expired”).

---

## 5. Ringkasan

| Situasi                         | Sesi berakhir? | Auto logout? |
|---------------------------------|----------------|--------------|
| Ada update app (versi baru)     | Tidak          | Tidak        |
| User tutup app lalu buka lagi  | Tidak*         | Tidak*       |
| GET /api/session → 401/403      | Ya             | Ya           |
| Endpoint lain → 401/403         | Tidak (di app) | Tidak        |
| User logout manual              | Ya             | N/A          |

\* Kecuali saat buka lagi app memanggil GET `/api/session` dan backend mengembalikan 401/403.

**Kesimpulan:** Update **tidak** mengakhiri sesi. Sesi berakhir hanya saat validasi session ke backend gagal (401/403 pada `/api/session`) atau user logout manual. Perilaku auto logout setelah login ulang sudah diperbaiki dengan reset state session-expired setelah logout.

---

## 6. Efek perubahan (reset session-expired state)

**Perubahan:** Setelah auto logout selesai, `ApiService().resetSessionExpiredState()` dipanggil sehingga `_isLoggingOut` kembali `false`.

**Efek:**
- **Sebelum:** User A kena auto logout → login lagi → session expired lagi → callback tidak jalan (karena `_isLoggingOut` masih true) → user tetap di dashboard padahal session invalid.
- **Sesudah:** Setiap kali logout selesai (manual atau auto), state di-reset. Session expired berikutnya tetap memicu auto logout dan redirect ke login dengan pesan "Sesi Anda telah berakhir".

Tidak ada efek samping: reset hanya dipanggil setelah logout selesai, jadi tidak memicu logout ganda.

---

## 7. Saat logout, apakah semuanya benar-benar dihapus?

Saat **logout** (manual atau auto), urutan pembersihan:

| Yang dibersihkan | Lokasi | Keterangan |
|------------------|--------|------------|
| **Tracking state** | `TrackingStateService.clearTrackingState()` | userId, attendanceId, check-in date, interval tracking. |
| **Background tracking** | `BackgroundTrackingService.stop()` | Service pelacakan lokasi dihentikan; notifikasi foreground "Atenim Active" hilang. |
| **Notifikasi check-in** | `PersistentNotificationService.hideCheckInNotification()` + `stopPeriodicUpdates()` | Notifikasi "Check-in Aktif" (ID 999) di-cancel; timer update durasi di-stop. |
| **Data offline & pending** | `OfflineStorageService().clearAll()` | Cache: attendance, shifts, activities, requests. Pending: check-in, check-out, activities, patroli, requests, location logs. |
| **Auth data** | `AuthService.logout()` | User data, legacy user, flag is_logged_in, cookies. |
| **State provider** | `_user = null; _error = null; notifyListeners()` | UI menganggap user sudah tidak login. |

**Jawaban:** Ya. Setelah logout, **pemberitahuan check-in** dan **notifikasi layanan tracking** dihapus/dihentikan, **semua data offline dan pending** di-clear, dan **data auth (user, cookie)** dihapus. Tidak ada data sesi atau notifikasi user yang sengaja dibiarkan; kalau ada kegagalan di salah satu langkah (misalnya clear notification gagal), logout tetap lanjut dan hanya log warning.
