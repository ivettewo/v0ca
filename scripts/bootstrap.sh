#!/bin/bash
# Готовит рабочую копию к сборке: локальный xcconfig, генерация .xcodeproj из
# project.yml, восстановление пинов SPM. Запускать после клона и после любых
# правок project.yml.
#
#     ./scripts/bootstrap.sh
set -euo pipefail

cd "$(dirname "$0")/.."

if [ ! -f Config/Local.xcconfig ]; then
    cp Config/Local.xcconfig.example Config/Local.xcconfig
    echo "→ Создан Config/Local.xcconfig — впиши свой DEVELOPMENT_TEAM."
fi

if ! command -v xcodegen >/dev/null; then
    echo "✗ Нет xcodegen. Установи: brew install xcodegen" >&2
    exit 1
fi

xcodegen generate

# .xcodeproj не в гите и создаётся заново, поэтому пины SPM храним в корне
# репозитория и кладём внутрь проекта после каждой генерации.
if [ -f Package.resolved ]; then
    resolved_dir="v0ca.xcodeproj/project.xcworkspace/xcshareddata/swiftpm"
    mkdir -p "$resolved_dir"
    cp Package.resolved "$resolved_dir/Package.resolved"
    echo "→ Версии пакетов восстановлены из Package.resolved."
fi

echo "✓ Готово. Открывай v0ca.xcodeproj."
