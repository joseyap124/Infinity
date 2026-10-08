#!/usr/bin/env bash
# Siapkan proyek Flutter dari repo ini. Dipakai semua workflow.
#   tool/ci_setup.sh android   -> proyek Android + tes + overlay native
#   tool/ci_setup.sh web       -> proyek web (prototipe iPhone)
set -euo pipefail
platform="${1:-android}"
here="$(cd "$(dirname "$0")" && pwd)"
# Baca nilai dari versions.env (tidak di-source karena PACKAGES berisi spasi).
PACKAGES="$(grep -E '^PACKAGES=' "$here/versions.env" | cut -d= -f2-)"

flutter --version
flutter create --org com.jose --project-name infinity --platforms "$platform" .
rm -rf test
if [ "$platform" = android ]; then cp -r tests test; fi
# shellcheck disable=SC2086
flutter pub add $PACKAGES
if [ -f "$here/pubspec.lock" ]; then
  cp "$here/pubspec.lock" pubspec.lock
  flutter pub get --enforce-lockfile
  echo "Dependensi mengikuti tool/pubspec.lock"
else
  echo "PERINGATAN: tool/pubspec.lock belum ada, dependensi tidak dikunci"
fi
if [ "$platform" = android ]; then python3 tool/setup_android.py; fi
