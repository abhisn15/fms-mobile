# Camera Preview Aspect Ratio Fix

## Masalah
Preview kamera terlihat gepeng (distorted) karena aspect ratio tidak dipertahankan dengan benar.

## Solusi
Menggunakan `Transform.scale` dengan perhitungan aspect ratio yang benar untuk memastikan preview mengisi layar tanpa distorsi.

## Kode yang Benar

```dart
// Build camera preview dengan scaling yang benar untuk full screen tanpa distorsi
Widget _buildCameraPreview() {
  if (_controller == null || !_controller!.value.isInitialized) {
    return Container(color: Colors.black);
  }

  final size = MediaQuery.of(context).size;
  var scale = size.aspectRatio * _controller!.value.aspectRatio;

  // To prevent scaling down, invert the value
  if (scale < 1) scale = 1 / scale;

  return ClipRect(
    child: Transform.scale(
      scale: scale,
      child: Center(
        child: CameraPreview(_controller!),
      ),
    ),
  );
}
```

## Penjelasan

1. **Perhitungan Scale**: 
   - `size.aspectRatio` = lebar layar / tinggi layar
   - `_controller!.value.aspectRatio` = aspect ratio dari preview kamera
   - `scale = size.aspectRatio * _controller!.value.aspectRatio` untuk menghitung scale factor

2. **Inversi Scale**:
   - Jika `scale < 1`, berarti preview lebih kecil dari layar
   - Inversi dengan `1 / scale` untuk memastikan preview mengisi layar

3. **Transform.scale**:
   - Menggunakan `Transform.scale` untuk meng-scale preview tanpa mengubah aspect ratio
   - `ClipRect` memotong bagian yang overflow

4. **Center Alignment**:
   - Preview di-center agar terlihat proporsional

## Default Camera
Untuk selfie (check-in/check-out), kamera depan digunakan sebagai default:

```dart
// Set kamera depan sebagai default untuk selfie
_currentCameraIndex = _findFrontCameraIndex();

int _findFrontCameraIndex() {
  for (int i = 0; i < _cameras!.length; i++) {
    if (_cameras![i].lensDirection == CameraLensDirection.front) {
      return i;
    }
  }
  return 0; // Fallback ke kamera pertama jika tidak ada depan
}
```

## Hasil
- Preview kamera tidak lagi terlihat gepeng
- Aspect ratio dipertahankan dengan benar
- Preview mengisi layar tanpa distorsi
- Kompatibel dengan berbagai ukuran layar

