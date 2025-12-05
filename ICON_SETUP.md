# App Icon Setup Instructions

Untuk mengatur app icon menggunakan `assets/icon.png`, ikuti langkah berikut:

## Metode 1: Menggunakan flutter_launcher_icons (Recommended)

1. Install package:
```bash
flutter pub add --dev flutter_launcher_icons
```

2. Tambahkan konfigurasi di `pubspec.yaml`:
```yaml
dev_dependencies:
  flutter_launcher_icons: ^0.13.1

flutter_launcher_icons:
  android: true
  ios: true
  image_path: "assets/icon.png"
  adaptive_icon_background: "#ffffff"
  adaptive_icon_foreground: "assets/icon.png"
```

3. Generate icons:
```bash
flutter pub get
flutter pub run flutter_launcher_icons
```

## Metode 2: Manual (Android)

Jika ingin setup manual untuk Android:

1. Buat berbagai ukuran icon dari `assets/icon.png`:
   - mipmap-mdpi: 48x48 px
   - mipmap-hdpi: 72x72 px
   - mipmap-xhdpi: 96x96 px
   - mipmap-xxhdpi: 144x144 px
   - mipmap-xxxhdpi: 192x192 px

2. Ganti file `ic_launcher.png` di setiap folder mipmap dengan ukuran yang sesuai:
   - `android/app/src/main/res/mipmap-mdpi/ic_launcher.png`
   - `android/app/src/main/res/mipmap-hdpi/ic_launcher.png`
   - `android/app/src/main/res/mipmap-xhdpi/ic_launcher.png`
   - `android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png`
   - `android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png`

3. Rebuild aplikasi:
```bash
flutter clean
flutter pub get
flutter run
```

## Catatan

- Icon harus berbentuk persegi (square)
- Format PNG dengan transparansi (jika diperlukan)
- Pastikan icon terlihat jelas pada berbagai ukuran

