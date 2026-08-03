#!/bin/bash
# Собирает Release-версию и упаковывает её в DMG с ярлыком «Программы»,
# складывая результат в installer/.
#
#     ./scripts/make_installer.sh
#
# На выходе два файла: installer/v0ca-<версия>.dmg (архив конкретной версии)
# и installer/v0ca-latest.dmg (копия последней сборки — постоянная ссылка).
set -euo pipefail

cd "$(dirname "$0")/.."

OUT_DIR="installer"
BUILD_DIR="$(mktemp -d)"
trap 'rm -rf "$BUILD_DIR"' EXIT

VERSION=$(awk '/MARKETING_VERSION:/ {print $2}' project.yml)
[ -n "$VERSION" ] || { echo "✗ Не нашёл MARKETING_VERSION в project.yml" >&2; exit 1; }

echo "→ Сборка Release ${VERSION}…"
xcodebuild -project v0ca.xcodeproj -scheme v0ca -configuration Release \
    -destination 'platform=macOS' \
    CONFIGURATION_BUILD_DIR="$BUILD_DIR" \
    build >/dev/null

APP="$BUILD_DIR/v0ca.app"
[ -d "$APP" ] || { echo "✗ Сборка не дала v0ca.app" >&2; exit 1; }

echo "→ Проверка подписи…"
codesign --verify --deep --strict "$APP" || echo "  ⚠︎ Подпись не прошла проверку — DMG всё равно соберём."

echo "→ Упаковка DMG…"
STAGE="$BUILD_DIR/dmg"
mkdir -p "$STAGE"
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"

mkdir -p "$OUT_DIR"
DMG="$OUT_DIR/v0ca-${VERSION}.dmg"
rm -f "$DMG" "$OUT_DIR/v0ca-latest.dmg"
hdiutil create -volname "v0ca ${VERSION}" -srcfolder "$STAGE" -ov -format UDZO "$DMG" >/dev/null
cp "$DMG" "$OUT_DIR/v0ca-latest.dmg"

echo "✓ $DMG ($(du -h "$DMG" | cut -f1))"
echo "✓ $OUT_DIR/v0ca-latest.dmg"
echo
echo "Сборка подписана Development-сертификатом и не нотаризована — на чужом Mac"
echo "Gatekeeper заблокирует первый запуск. Что сказать пользователю:"
echo "  1) правый клик по v0ca в Программах → «Открыть» → «Открыть» в диалоге;"
echo "  2) либо Системные настройки → Конфиденциальность и безопасность → «Открыть всё равно»;"
echo "  3) либо снять карантин руками: xattr -dr com.apple.quarantine /Applications/v0ca.app"
echo "Убрать этот шаг совсем можно только сертификатом Developer ID + нотаризацией."
