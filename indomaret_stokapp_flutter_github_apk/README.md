# Indomaret StokApp — Flutter

Aplikasi Flutter offline-first untuk mengelola katalog snack, lokasi rak, lokasi gudang, status stok, foto, pencarian teks/suara, serta backup/restore JSON.

## Fitur

- Header gradient biru dan logo Indomaret lokal sebagai asset.
- Mode terang/gelap.
- Database lokal menggunakan `SharedPreferences`.
- Katalog bawaan 25 snack populer.
- Status `ADA / REFILL / KOSONG`.
- Swipe kiri untuk hapus.
- Edit produk dengan long-press atau tombol edit.
- Bottom sheet tambah/edit.
- Foto kamera/galeri dan kompresi ukuran sebelum disimpan sebagai Base64.
- Pencarian suara Bahasa Indonesia `id_ID`.
- Pencarian suara ditumpuk dengan koma.
- Pemisahan brand populer ketika ucapan tidak memakai tanda baca.
- Strict phrase matching untuk pencarian suara.
- Backup JSON dan import JSON.
- Haptic feedback dan system click.
- Bottom navigation Pencarian / Tambah Produk.

## Menjalankan

Pastikan Flutter SDK sudah terpasang.

```bash
flutter pub get
flutter run
```

Android:

```bash
flutter run -d android
```

Windows:

```bash
flutter run -d windows
```

Build APK:

```bash
flutter build apk --release
```

Build Windows:

```bash
flutter build windows --release
```

## Permission Android

Tambahkan permission berikut ke:

`android/app/src/main/AndroidManifest.xml`

di dalam tag `<manifest>`:

```xml
<uses-permission android:name="android.permission.RECORD_AUDIO"/>
<uses-permission android:name="android.permission.CAMERA"/>
```

## Permission iOS

Tambahkan ke `ios/Runner/Info.plist`:

```xml
<key>NSMicrophoneUsageDescription</key>
<string>StokApp membutuhkan mikrofon untuk pencarian snack dengan suara.</string>
<key>NSSpeechRecognitionUsageDescription</key>
<string>StokApp menggunakan pengenalan suara untuk mencari snack.</string>
<key>NSCameraUsageDescription</key>
<string>StokApp membutuhkan kamera untuk foto rak atau dus.</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>StokApp membutuhkan akses foto untuk memilih foto rak atau dus.</string>
```

## Catatan penyimpanan

Data inventory disimpan pada key:

`indomaret_snack_db`

Mode gelap disimpan pada:

`indomaret_stokapp_dark`

Backup JSON dapat dipindahkan ke perangkat lain melalui menu share/file.

Logo Indomaret sudah disertakan sebagai asset lokal sehingga tampilan header tetap muncul ketika aplikasi benar-benar offline.
