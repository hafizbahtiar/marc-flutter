#!/usr/bin/env bash
#
# setup.sh — bina APK/AAB dengan konfigurasi interaktif.
#
# Aliran:
#   1) Tanya semua soalan dahulu
#   2) flutter clean         (auto)
#   3) flutter pub get       (auto)
#   4) build_runner          (jika dipilih & tersedia)
#   5) build APK / AAB
#   6) salin + rename output ke  {nama_app}-{YYYYMMDD}({build}).{ext}
#
set -euo pipefail

cd "$(dirname "$0")"

# ── Baca maklumat semasa dari pubspec ──────────────────────────────
APP_NAME="$(grep -E '^name:' pubspec.yaml | head -1 | awk '{print $2}')"
VERSION_LINE="$(grep -E '^version:' pubspec.yaml | head -1 | awk '{print $2}')"
CUR_NAME="${VERSION_LINE%%+*}"                       # 1.0.0
if [[ "$VERSION_LINE" == *+* ]]; then
  CUR_BUILD="${VERSION_LINE#*+}"                      # 1
else
  CUR_BUILD="0"
fi

echo "==================================================="
echo " Setup build — $APP_NAME"
echo " Versi semasa: ${CUR_NAME}+${CUR_BUILD}"
echo "==================================================="
echo

# ── 1) Soalan (semua ditanya dahulu) ───────────────────────────────

read -r -p "1) Jalankan build generator (build_runner)? [y/N]: " Q_GEN
Q_GEN="${Q_GEN:-n}"

read -r -p "2) Naikkan build number? (${CUR_BUILD} -> $((CUR_BUILD + 1))) [Y/n]: " Q_BUILD
Q_BUILD="${Q_BUILD:-y}"

read -r -p "3) Version name [kekal: ${CUR_NAME}]: " Q_NAME
NEW_NAME="${Q_NAME:-$CUR_NAME}"

NEW_BUILD="$CUR_BUILD"
if [[ "$Q_BUILD" =~ ^[Yy]$ ]]; then
  NEW_BUILD=$((CUR_BUILD + 1))
fi

ARTIFACT=""
while [[ "$ARTIFACT" != "apk" && "$ARTIFACT" != "aab" ]]; do
  read -r -p "4) Bina APK atau AAB? [apk/aab]: " ARTIFACT
  ARTIFACT="$(echo "$ARTIFACT" | tr '[:upper:]' '[:lower:]')"
done

NEW_VERSION="${NEW_NAME}+${NEW_BUILD}"

# ── Ringkasan + pengesahan ─────────────────────────────────────────
echo
echo "---------------------------------------------------"
echo " build_runner : ${Q_GEN}"
echo " version      : ${VERSION_LINE}  ->  ${NEW_VERSION}"
echo " output       : $(echo "$ARTIFACT" | tr '[:lower:]' '[:upper:]')"
echo "---------------------------------------------------"
read -r -p "Teruskan? [Y/n]: " GO
GO="${GO:-y}"
[[ "$GO" =~ ^[Yy]$ ]] || { echo "Dibatalkan."; exit 0; }

# ── Kemas kini pubspec version ─────────────────────────────────────
if [[ "$NEW_VERSION" != "$VERSION_LINE" ]]; then
  sed -i '' -E "s|^version:.*|version: ${NEW_VERSION}|" pubspec.yaml
  echo "→ pubspec.yaml: version: ${NEW_VERSION}"
fi

# ── 2) clean  3) pub get ───────────────────────────────────────────
echo "→ flutter clean"
flutter clean
echo "→ flutter pub get"
flutter pub get

# ── 4) build_runner (jika dipilih & tersedia) ──────────────────────
if [[ "$Q_GEN" =~ ^[Yy]$ ]]; then
  if grep -q 'build_runner' pubspec.yaml; then
    echo "→ dart run build_runner build --delete-conflicting-outputs"
    dart run build_runner build --delete-conflicting-outputs
  else
    echo "⚠ build_runner tiada dalam pubspec — langkau."
  fi
fi

# ── 5) build ───────────────────────────────────────────────────────
if [[ "$ARTIFACT" == "apk" ]]; then
  echo "→ flutter build apk --release"
  flutter build apk --release
  SRC="build/app/outputs/flutter-apk/app-release.apk"
  EXT="apk"
else
  echo "→ flutter build appbundle --release"
  flutter build appbundle --release
  SRC="build/app/outputs/bundle/release/app-release.aab"
  EXT="aab"
fi

# ── 6) salin + rename ──────────────────────────────────────────────
if [[ ! -f "$SRC" ]]; then
  echo "✗ Output tidak dijumpai: $SRC"
  exit 1
fi

DATE="$(date +%Y%m%d)"
OUT_DIR="$ARTIFACT"
DEST="${OUT_DIR}/${APP_NAME}-${DATE}(${NEW_BUILD}).${EXT}"

mkdir -p "$OUT_DIR"
cp "$SRC" "$DEST"

echo
echo "✓ Siap: $DEST"
