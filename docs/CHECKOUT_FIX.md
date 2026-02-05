# Check-Out Force Close Fix untuk Device Low-End

## Masalah
Aplikasi force close saat melakukan check-out di device low-end seperti Redmi 5, terutama saat upload foto.

## Penyebab
1. **Out of Memory (OOM)**: Foto terlalu besar menyebabkan aplikasi kehabisan memori saat membuat MultipartFile
2. **Timeout**: Upload foto memakan waktu terlalu lama tanpa timeout protection
3. **Error handling tidak memadai**: Error memory tidak ditangani dengan baik

## Solusi

### 1. Validasi Ukuran File

Sebelum upload, aplikasi memvalidasi ukuran file untuk mencegah OOM:

```dart
// Validasi file sebelum upload untuk mencegah OOM di device low-end
try {
  final fileStat = await photo.stat();
  final fileSizeMB = fileStat.size / (1024 * 1024);
  debugPrint('[AttendanceService] Photo size: ${fileSizeMB.toStringAsFixed(2)} MB');
  
  // Jika file terlalu besar (>10MB), bisa menyebabkan OOM di device low-end
  if (fileSizeMB > 10) {
    throw Exception('Foto terlalu besar (${fileSizeMB.toStringAsFixed(2)} MB). Maksimal 10 MB.');
  }
} catch (e) {
  if (e.toString().contains('terlalu besar')) {
    rethrow;
  }
  debugPrint('[AttendanceService] ⚠ Could not check file size: $e');
  // Continue anyway if we can't check size
}
```

### 2. Error Handling untuk Memory Issues

Menambahkan error handling khusus untuk masalah memory:

```dart
// Buat MultipartFile dengan error handling untuk mencegah OOM
MultipartFile? photoFile;
try {
  photoFile = await MultipartFile.fromFile(
    photo.path,
  ).timeout(
    const Duration(seconds: 10),
    onTimeout: () {
      throw Exception('Timeout saat membaca file foto. File mungkin terlalu besar.');
    },
  );
} catch (e) {
  if (e.toString().contains('OutOfMemory') || 
      e.toString().contains('out of memory') ||
      e.toString().contains('Memory')) {
    throw Exception('Memori tidak cukup untuk memproses foto. Coba ambil foto dengan resolusi lebih kecil.');
  }
  rethrow;
}
```

### 3. Timeout untuk Upload

Menambahkan timeout untuk mencegah aplikasi hang:

```dart
final response = await _apiService.postFormData(
  ApiConfig.checkOut,
  formData,
).timeout(
  const Duration(seconds: 60), // Timeout 60 detik untuk upload
  onTimeout: () {
    throw Exception('Upload timeout. Koneksi mungkin lambat atau file terlalu besar.');
  },
);
```

### 4. Error Handling di Provider

Provider mendeteksi error memory/timeout dan tidak menyimpan ke pending:

```dart
} catch (e) {
  // Check if it's a memory-related error
  final errorStr = e.toString().toLowerCase();
  if (errorStr.contains('memory') || 
      errorStr.contains('outofmemory') ||
      errorStr.contains('terlalu besar') ||
      errorStr.contains('timeout')) {
    // Don't save to pending for memory/timeout errors - user needs to retry with smaller photo
    _error = ErrorHandler.getErrorMessage(e);
    debugPrint('[AttendanceProvider] ✗ Check-out failed due to memory/timeout: $_error');
    return false;
  }
  
  // If online check-out fails for other reasons, save to pending
  // ...
}
```

## Hasil

- ✅ Tidak ada force close: Error ditangani dengan baik
- ✅ Validasi file: File terlalu besar ditolak sebelum upload
- ✅ Error handling: Pesan error yang jelas untuk masalah memory/timeout
- ✅ Timeout protection: Mencegah aplikasi hang saat upload
- ✅ User experience: User mendapat feedback yang jelas tentang masalah

## Catatan

Perbaikan ini juga diterapkan untuk check-in untuk konsistensi dan mencegah masalah yang sama.

