# FLSDB - Frontier Lands Encyclopedia

Aplikasi ensiklopedia dan manajemen basis data *Frontier Lands* berbasis Flutter dengan arsitektur *offline-first* dan sinkronisasi *cloud* Supabase.

---

## 1. Dukungan Platform

Aplikasi ini mendukung kompilasi dan distribusi lintas platform:
- **Android**: APK (`.apk`) & App Bundle (`.aab`)
- **iOS**: Unsigned / Signed Application Bundle (`.app` / `.ipa`)
- **Web**: Progressive Web Application (HTML / JavaScript / CanvasKit)
- **Windows Desktop**: Native Win32 x64 Executable (`.exe`)
- **macOS Desktop**: Native macOS Application Bundle (`.app`)
- **Linux Desktop**: Native GTK+ 3.0 Binary (`x86_64`)

---

## 2. Prasyarat Lingkungan Pengembangan

| Perangkat Lunak | Versi Minimum | Catatan |
|---|---|---|
| Flutter SDK | >= 3.13.0 | Channel Stable |
| Dart SDK | >= 3.1.0 | Terbundel bersama Flutter |
| JDK | 17 | Diperlukan untuk kompilasi Android |
| Visual Studio | 2019 / 2022 | Komponen *Desktop development with C++* (Khusus Windows) |
| Xcode | >= 15 | macOS & iOS (Khusus macOS host) |
| Clang, CMake, Ninja, GTK 3 | - | Diperlukan untuk kompilasi Linux |

---

## 3. Konfigurasi Lingkungan (.env)

Aplikasi menggunakan berkas `.env` untuk konfigurasi konektivitas Supabase secara dinamis tanpa mengekspos kredensial ke dalam repositori.

1. Salin template `.env.example` menjadi `.env`:
   ```bash
   cp .env.example .env
   ```
   Atau pada PowerShell (Windows):
   ```powershell
   Copy-Item .env.example .env
   ```
2. Sesuaikan konfigurasi sesuai proyek Supabase:
   ```env
   SUPABASE_URL=https://<project-ref>.supabase.co
   SUPABASE_ANON_KEY=<public-anon-key>
   ```
3. Jika `.env` tidak diisi atau tidak ditemukan, aplikasi secara otomatis berjalan dalam mode **Offline-First** menggunakan basis data lokal SQLite tanpa kegagalan inisialisasi.

> **Peringatan Keamanan**: Berkas `.env` telah didaftarkan dalam `.gitignore`. Jangan pernah memasukkan kunci API rahasia (*service role key*) atau melakukan *commit* berkas `.env` ke dalam sistem kontrol versi (*version control system*).

---

## 4. Panduan Kompilasi Mandiri (Local Build)

### 4.1. Menggunakan Script Otomatisasi

Proyek menyediakan script pembantu untuk memudahkan kompilasi seluruh atau sebagian target.

**Lingkungan Windows (PowerShell):**
```powershell
# Menjalankan kompilasi seluruh target yang didukung host
.\tools\build_all.ps1 -Target all

# Kompilasi target spesifik
.\tools\build_all.ps1 -Target web
.\tools\build_all.ps1 -Target apk
.\tools\build_all.ps1 -Target windows
```

**Lingkungan Linux / macOS (Bash):**
```bash
chmod +x ./tools/build_all.sh

# Menjalankan kompilasi seluruh target yang didukung host
./tools/build_all.sh all

# Kompilasi target spesifik
./tools/build_all.sh web
./tools/build_all.sh apk
./tools/build_all.sh linux   # Pada Linux host
./tools/build_all.sh macos   # Pada macOS host
./tools/build_all.sh ios     # Pada macOS host
```

---

### 4.2. Perintah Manual (Flutter CLI)

#### A. Web
```bash
flutter pub get
flutter build web --release
```
Hasil keluaran: `build/web/`

#### B. Android APK
```bash
flutter pub get
flutter build apk --release
```
Hasil keluaran: `build/app/outputs/flutter-apk/app-release.apk`

#### C. Windows Desktop
```bash
flutter pub get
flutter build windows --release
```
Hasil keluaran: `build/windows/x64/runner/Release/`

#### D. Linux Desktop
```bash
# Instalasi pustaka pendukung (Debian/Ubuntu)
sudo apt-get update && sudo apt-get install -y clang cmake ninja-build pkg-config libgtk-3-dev

flutter pub get
flutter build linux --release
```
Hasil keluaran: `build/linux/x64/release/bundle/`

#### E. macOS Desktop
```bash
flutter pub get
flutter build macos --release
```
Hasil keluaran: `build/macos/Build/Products/Release/rpl.app`

#### F. iOS (Unsigned Release)
```bash
flutter pub get
flutter build ios --release --no-codesign
```
Hasil keluaran: `build/ios/iphoneos/Runner.app`

---

## 5. Otomatisasi CI/CD (GitHub Actions)

Repositori ini telah dilengkapi rancangan alur kerja otomatisasi (*continuous integration*) pada `ci/build.yml` (dapat disalin langsung ke `.github/workflows/build.yml`). Alur kerja ini dirancang untuk memicu pengujian dan kompilasi untuk seluruh 6 target platform pada setiap *push* atau *pull request* ke cabang `main`:

1. **Unit & Widget Test**: Menjalankan analisis statis (`flutter analyze`) dan seluruh rangkaian pengujian (`flutter test`).
2. **Build Android**: Menghasilkan artefak APK rilis.
3. **Build Web**: Menghasilkan bundel aplikasi web teroptimasi.
4. **Build Linux**: Mengompilasi aplikasi desktop pada *runner* Ubuntu dan mengompresi paket distribusi (`.tar.gz`).
5. **Build Windows**: Mengompilasi *native binary* pada *runner* Windows dan mengompresi paket distribusi (`.zip`).
6. **Build macOS**: Mengompilasi *application bundle* pada *runner* macOS dan mengompresi paket distribusi (`.zip`).
7. **Build iOS**: Mengompilasi *iOS payload* pada *runner* macOS dan mengompresi paket distribusi (`.zip`).

Seluruh artefak hasil kompilasi dapat diunduh langsung melalui tab **Actions** pada repositori GitHub setelah alur kerja diaktifkan.

---

## 6. Pengujian

Untuk memastikan integritas fungsionalitas dan konsistensi data:
```bash
flutter test
```
Rangkaian tes mencakup:
- Validasi inisialisasi antarmuka dan navigasi tab ensiklopedia.
- Validasi konsistensi struktur dan integritas *seed data* terhadap dokumen acuan (*Rules Book Frontier Lands*).
