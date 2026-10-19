<#
.SYNOPSIS
    Script otomatisasi build multi-platform untuk lingkungan Windows.

.DESCRIPTION
    Menyediakan eksekusi build untuk platform Android (APK), Web, dan Windows Desktop.
    Memastikan konfigurasi lokal (.env) tersedia sebelum proses kompilasi.

.PARAMETER Target
    Platform target kompilasi: 'all', 'apk', 'web', 'windows'. Default: 'all'.

.PARAMETER Mode
    Mode rilis Flutter: 'release', 'debug', 'profile'. Default: 'release'.

.EXAMPLE
    .\tools\build_all.ps1 -Target web
    .\tools\build_all.ps1 -Target all -Mode release
#>

[CmdletBinding()]
param(
    [ValidateSet('all', 'apk', 'web', 'windows')]
    [string]$Target = 'all',

    [ValidateSet('release', 'debug', 'profile')]
    [string]$Mode = 'release'
)

$ErrorActionPreference = 'Stop'

function Write-Log([string]$Message, [string]$Level = 'INFO') {
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    Write-Host "[$timestamp] [$Level] $Message"
}

# 1. Verifikasi direktori kerja
$rootDir = (Get-Item $PSScriptRoot).Parent.FullName
Set-Location $rootDir
Write-Log "Root direktori proyek: $rootDir"

# 2. Inisialisasi berkas konfigurasi (.env) jika belum ada
$envFile = Join-Path $rootDir ".env"
$envExample = Join-Path $rootDir ".env.example"

if (!(Test-Path $envFile)) {
    if (Test-Path $envExample) {
        Write-Log "Berkas .env tidak ditemukan. Menyalin dari .env.example..."
        Copy-Item -Path $envExample -Destination $envFile
    } else {
        Write-Log "Peringatan: Berkas .env dan .env.example tidak ditemukan." "WARN"
    }
}

# 3. Validasi Flutter CLI
if (!(Get-Command flutter -ErrorAction SilentlyContinue)) {
    throw "Flutter SDK tidak terdeteksi dalam PATH sistem. Pastikan Flutter telah terpasang."
}

# 4. Sinkronisasi dependensi
Write-Log "Menjalankan flutter pub get..."
flutter pub get

# 5. Eksekusi build sesuai target
$distDir = Join-Path $rootDir "dist"
if (!(Test-Path $distDir)) {
    New-Item -ItemType Directory -Force -Path $distDir | Out-Null
}

if ($Target -eq 'all' -or $Target -eq 'apk') {
    Write-Log "Memulai kompilasi Android APK ($Mode)..."
    flutter build apk --$Mode
    $apkSource = Join-Path $rootDir "build\app\outputs\flutter-apk\app-$Mode.apk"
    if (Test-Path $apkSource) {
        Copy-Item -Path $apkSource -Destination (Join-Path $distDir "rpl-android-$Mode.apk") -Force
        Write-Log "Artefak APK berhasil dibuat: dist/rpl-android-$Mode.apk"
    }
}

if ($Target -eq 'all' -or $Target -eq 'web') {
    Write-Log "Memulai kompilasi Web ($Mode)..."
    flutter build web --$Mode
    Write-Log "Artefak Web berhasil dibuat di: build/web/"
}

if ($Target -eq 'all' -or $Target -eq 'windows') {
    Write-Log "Memulai kompilasi Windows Desktop ($Mode)..."
    try {
        flutter build windows --$Mode
        $windowsOutputDir = Join-Path $rootDir "build\windows\x64\runner\Release"
        if (Test-Path $windowsOutputDir) {
            $zipOutput = Join-Path $distDir "rpl-windows-x64.zip"
            Compress-Archive -Path "$windowsOutputDir\*" -DestinationPath $zipOutput -Force
            Write-Log "Artefak Windows berhasil dikompresi: dist/rpl-windows-x64.zip"
        }
    } catch {
        Write-Log "Gagal melakukan build Windows: $($_.Exception.Message)" "WARN"
        Write-Log "Pastikan komponen 'Desktop development with C++' pada Visual Studio terpasang." "WARN"
    }
}

Write-Log "Proses build selesai."
