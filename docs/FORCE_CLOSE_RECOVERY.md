# 🔄 FORCE CLOSE RECOVERY SYSTEM

## 📋 Overview

Sistem recovery untuk menangani force close aplikasi dan memastikan semua services dan data ter-restore dengan benar saat aplikasi di-restart.

## ⚠️ Masalah yang Ditangani

### Saat Force Close Terjadi:
- ✅ **Persistent Notification hilang** - Check-in status masih aktif tapi notifikasi hilang
- ✅ **Background Location Tracking berhenti** - Tidak ada location tracking lagi
- ✅ **Pending Sync Data hilang** - Data yang belum sync ke server hilang
- ✅ **Timer Updates berhenti** - Notifikasi durasi tidak update lagi

## 🔧 Solusi Recovery System

### 1. App Lifecycle Recovery

**File**: `lib/main.dart` - `AppLifecycleHandler`

```dart
@override
void didChangeAppLifecycleState(AppLifecycleState state) {
  final isForeground = state == AppLifecycleState.resumed;
  _setForeground(isForeground);

  // Recover services when app comes back from background/force close
  if (state == AppLifecycleState.resumed) {
    _recoverServicesAfterForceClose();
  }
}
```

### 2. Persistent Notification Recovery

**File**: `lib/providers/attendance_provider.dart`

```dart
// Saat load attendance, cek apakah ada active check-in
if (_attendanceData?.today != null) {
  final today = _attendanceData!.today!;
  if (today.checkIn != null && today.checkOut == null) {
    // Restore persistent notification
    await PersistentNotificationService.showCheckInNotification(today);
    PersistentNotificationService.startPeriodicUpdates(today);
    debugPrint('✓ Persistent notification restored for active check-in');
  }
}
```

### 3. Background Tracking Recovery

**File**: `lib/main.dart` - Recovery method

```dart
Future<void> _recoverServicesAfterForceClose() async {
  // 1. Re-check background tracking status
  final trackingState = await TrackingStateService.getTrackingState();
  if (trackingState.isTracking) {
    debugPrint('🔄 Background tracking was active, restarting...');
    await BackgroundTrackingService.ensureRunning();
  }
}
```

### 4. Pending Data Sync Recovery

**File**: `lib/main.dart` - Sync recovery

```dart
Future<void> _syncPendingData() async {
  // Sync pending activities
  final activityProvider = Provider.of<ActivityProvider>(context, listen: false);
  await activityProvider.syncPendingActivities();

  // Sync pending location logs
  final attendanceProvider = Provider.of<AttendanceProvider>(context, listen: false);
  final realtimeService = attendanceProvider.realtimeService;
  await realtimeService.syncPendingLocationLogs();
}
```

## 📊 Recovery Flow

```
App Force Closed → User Reopens App → AppLifecycleHandler.resumed
                    ↓
            _recoverServicesAfterForceClose()
                    ↓
        ┌─────────────────────────────────────┐
        │ 1. Restore Persistent Notification   │
        │ 2. Restart Background Tracking       │
        │ 3. Sync Pending Data                 │
        └─────────────────────────────────────┘
                    ↓
            ✅ All Services Recovered
```

## 🛡️ Data Persistence Strategy

### 1. Offline Storage
- **Activities**: Disimpan di local storage saat offline
- **Location Logs**: Queue pending logs untuk sync nanti
- **Attendance State**: Cache check-in status

### 2. State Recovery
- **Check-in Status**: Restore dari server API atau cache
- **Background Services**: Restart otomatis berdasarkan tracking state
- **Notifications**: Re-show persistent notification

## 🧪 Testing Scenarios

### ✅ Force Close Recovery Test:
1. Check-in → Persistent notification muncul
2. Force close app (swipe away)
3. Reopen app → Notification kembali muncul
4. Background tracking tetap berjalan
5. Pending data ter-sync otomatis

### ✅ Background Recovery Test:
1. App di-background (home button)
2. Tunggu beberapa saat
3. Reopen app → Semua services normal

### ✅ Offline Recovery Test:
1. Offline mode → Data disimpan local
2. Force close app
3. Online lagi → Data ter-sync otomatis

## 🔍 Monitoring & Debugging

### Debug Logs:
```dart
debugPrint('[AppLifecycleHandler] 🔄 Recovering services after app resume...');
debugPrint('[AppLifecycleHandler] ✅ Services recovered successfully');
debugPrint('[AppLifecycleHandler] ❌ Failed to recover services: $e');
```

### Recovery Status Check:
- ✅ Persistent notification visible
- ✅ Background service running (check notification bar)
- ✅ Location tracking active
- ✅ No pending sync errors

## 🚨 Error Handling

### Jika Recovery Gagal:
- **Notification**: Tidak kritis, bisa manual check-in ulang
- **Background Tracking**: Restart otomatis saat check-in berikutnya
- **Pending Data**: Tetap di local storage, sync saat koneksi kembali

### Graceful Degradation:
- App tetap bisa digunakan meski recovery partial fail
- User tidak aware ada masalah internal
- Data tetap aman di local storage

## 📈 Performance Impact

### Minimal Overhead:
- ✅ Recovery hanya saat app resume
- ✅ Async operations tidak block UI
- ✅ Efficient state checks
- ✅ No continuous polling

### Battery Optimization:
- ✅ Services hanya restart jika sebelumnya aktif
- ✅ Smart sync timing
- ✅ Background service optimized

## 🎯 User Experience

### Seamless Recovery:
- ✅ User tidak perlu manual restart services
- ✅ Check-in status tetap terlihat
- ✅ Location tracking otomatis resume
- ✅ No data loss experience

### Transparent Operation:
- ✅ Recovery terjadi di background
- ✅ No loading screens atau interruptions
- ✅ Normal app behavior maintained

---

## 🔧 Implementation Files

- `lib/main.dart` - AppLifecycleHandler & recovery logic
- `lib/providers/attendance_provider.dart` - Notification recovery
- `lib/services/persistent_notification_service.dart` - Notification management
- `lib/services/background_tracking_service.dart` - Background service management
- `lib/services/tracking_state_service.dart` - State persistence

## ✅ Status: FULLY IMPLEMENTED

Recovery system untuk force close sudah **100% siap** dan akan memastikan aplikasi kembali normal setelah force close tanpa intervensi user! 🚀✨
