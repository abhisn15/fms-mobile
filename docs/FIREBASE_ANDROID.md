# Firebase Android (`google-services.json`)

## Repo publik (GitHub) — penting

File **`android/app/google-services.json` berisi API key klien** dan **tidak boleh di-commit** ke repository **publik**. Google memindai repo publik dan akan mengirim peringatan jika kunci terlihat.

- Di repo ini file asli **di-ignore** oleh Git; gunakan **`android/app/google-services.json.example`** sebagai acuan, lalu salin menjadi `google-services.json` dan isi dari unduhan Firebase Console (hanya di mesin lokal atau secret CI).
- Jika kunci pernah ter-push ke publik: **batasi / rotate key** di [Google Cloud Console](https://console.cloud.google.com/) → APIs & Services → Credentials.

## Service account ≠ konfigurasi Android

File seperti `atenim-6255f-firebase-adminsdk-*.json` adalah **kredensial server (Firebase Admin SDK)** untuk backend (misalnya Node.js mengirim FCM). File itu **tidak** berisi `mobilesdk_app_id` dan **tidak bisa** dipakai sebagai `android/app/google-services.json`.

Untuk build Android + FCM di app, yang dibutuhkan adalah **`google-services.json` khusus aplikasi Android**, diunduh dari Firebase Console.

## Cara mendapatkan file yang benar

1. Buka [Firebase Console](https://console.firebase.google.com) → pilih project **atenim-6255f** (atau project Anda).
2. **Project settings** (ikon roda gigi) → tab **General**.
3. Di bagian **Your apps**:
   - Jika belum ada app Android: **Add app** → pilih Android → **Android package name** harus sama dengan `applicationId` di Gradle, yaitu **`com.atenim`**.
   - Jika sudah ada: pilih app Android tersebut.
4. Klik **Download google-services.json**.
5. Letakkan file tersebut di **`android/app/google-services.json`** (ganti file lama).

Isi file yang valid memiliki `mobilesdk_app_id` berbentuk `1:...:android:...` (bukan string kosong).

## Build tanpa file lengkap

Gradle hanya menerapkan plugin `com.google.gms.google-services` jika `google-services.json` terdeteksi memiliki **Google App ID** Android yang valid. Tanpa itu, **release build tetap bisa jalan**, tetapi inisialisasi Firebase di device bisa gagal sampai file asli dipasang (lihat log `PushNotificationService`).

## Alternatif: FlutterFire CLI

Anda juga bisa menjalankan:

```bash
dart pub global activate flutterfire_cli
flutterfire configure
```

Ini akan menghasilkan `firebase_options.dart` dan memperbarui konfigurasi platform; tetap biasanya membutuhkan app Android terdaftar di project Firebase yang sama.
