# Build APK langsung dari HP

## Cara paling mudah

1. Buat repository baru di GitHub.
2. Upload seluruh isi ZIP ini ke repository.
3. Commit ke branch `main`.
4. Buka tab **Actions**.
5. Pilih **Build Indomaret StokApp APK**.
6. Jika diperlukan, tekan **Run workflow**.
7. Tunggu sampai job selesai.
8. Buka hasil workflow yang sukses.
9. Di bagian **Artifacts**, download:
   `Indomaret-StokApp-APK`
10. Extract ZIP artifact tersebut. Di dalamnya ada:
    `Indomaret-StokApp-release.apk`
11. Install APK di HP.

## Tidak perlu laptop

Semua proses Flutter dilakukan oleh GitHub Actions di cloud. HP hanya dipakai untuk mengelola repository dan mengunduh APK.

## Jika Actions gagal

Buka:
Actions → Build Indomaret StokApp APK → job yang gagal → lihat langkah merah.

Kesalahan paling umum:
- dependency package berubah,
- versi Flutter berubah,
- konfigurasi Android permission,
- atau batas build GitHub Actions.

## Catatan

Workflow memakai Flutter stable dan Java 17. Android project yang belum ada akan dibuat otomatis oleh `flutter create`, kemudian permission microphone dan camera ditambahkan sebelum build.
