#!/usr/bin/env bash
#
# Script otomatisasi build multi-platform untuk lingkungan Unix/Linux/macOS.
#

set -euo pipefail

TARGET="${1:-all}"
MODE="${2:-release}"

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${PROJECT_ROOT}"

echo "[INFO] Root direktori proyek: ${PROJECT_ROOT}"

# Inisialisasi berkas .env jika belum ada
if [ ! -f .env ]; then
  if [ -f .env.example ]; then
    echo "[INFO] Berkas .env tidak ditemukan. Menyalin dari .env.example..."
    cp .env.example .env
  fi
fi

# Validasi Flutter CLI
if ! command -v flutter &> /dev/null; then
  echo "[ERROR] Flutter SDK tidak ditemukan dalam PATH."
  exit 1
fi

echo "[INFO] Mengambil dependensi proyek (flutter pub get)..."
flutter pub get

mkdir -p dist

case "${TARGET}" in
  apk)
    echo "[INFO] Membangun Android APK (${MODE})..."
    flutter build apk --"${MODE}"
    cp "build/app/outputs/flutter-apk/app-${MODE}.apk" "dist/rpl-android-${MODE}.apk"
    echo "[INFO] Sukses: dist/rpl-android-${MODE}.apk"
    ;;

  web)
    echo "[INFO] Membangun Web (${MODE})..."
    flutter build web --"${MODE}"
    echo "[INFO] Sukses: build/web/"
    ;;

  linux)
    echo "[INFO] Membangun Linux Desktop (${MODE})..."
    flutter build linux --"${MODE}"
    tar -czvf "dist/rpl-linux-x64.tar.gz" -C build/linux/x64/release/bundle .
    echo "[INFO] Sukses: dist/rpl-linux-x64.tar.gz"
    ;;

  macos)
    echo "[INFO] Membangun macOS Desktop (${MODE})..."
    flutter build macos --"${MODE}"
    (cd build/macos/Build/Products/Release && zip -r "../../../../../dist/rpl-macos.zip" rpl.app)
    echo "[INFO] Sukses: dist/rpl-macos.zip"
    ;;

  ios)
    echo "[INFO] Membangun iOS Application (${MODE}, unsigned)..."
    flutter build ios --"${MODE}" --no-codesign
    (cd build/ios/iphoneos && zip -r "../../../dist/rpl-ios.zip" Runner.app)
    echo "[INFO] Sukses: dist/rpl-ios.zip"
    ;;

  all)
    echo "[INFO] Membangun target Web..."
    flutter build web --"${MODE}"

    echo "[INFO] Membangun target APK..."
    flutter build apk --"${MODE}"
    cp "build/app/outputs/flutter-apk/app-${MODE}.apk" "dist/rpl-android-${MODE}.apk"

    UNAME_OUT="$(uname -s)"
    case "${UNAME_OUT}" in
      Linux*)
        echo "[INFO] Membangun target Linux Desktop..."
        flutter build linux --"${MODE}"
        tar -czvf "dist/rpl-linux-x64.tar.gz" -C build/linux/x64/release/bundle .
        ;;
      Darwin*)
        echo "[INFO] Membangun target macOS Desktop..."
        flutter build macos --"${MODE}"
        (cd build/macos/Build/Products/Release && zip -r "../../../../../dist/rpl-macos.zip" rpl.app)

        echo "[INFO] Membangun target iOS..."
        flutter build ios --"${MODE}" --no-codesign
        (cd build/ios/iphoneos && zip -r "../../../dist/rpl-ios.zip" Runner.app)
        ;;
      *)
        echo "[WARN] Host OS tidak mendukung build native desktop Linux/macOS secara langsung."
        ;;
    esac
    ;;

  *)
    echo "[ERROR] Target tidak dikenali: ${TARGET}. Pilihan: all, apk, web, linux, macos, ios."
    exit 1
    ;;
esac

echo "[INFO] Seluruh proses build selesai."
