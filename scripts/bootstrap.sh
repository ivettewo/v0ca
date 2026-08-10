#!/bin/bash
# Prepares the working copy for building: local xcconfig, .xcodeproj generation
# from project.yml, SPM pin restore. Run after cloning and after any change to
# project.yml.
#
#     ./scripts/bootstrap.sh
set -euo pipefail

cd "$(dirname "$0")/.."

if [ ! -f Config/Local.xcconfig ]; then
    cp Config/Local.xcconfig.example Config/Local.xcconfig
    echo "→ Created Config/Local.xcconfig — fill in your DEVELOPMENT_TEAM."
fi

if ! command -v xcodegen >/dev/null; then
    echo "✗ xcodegen not found. Install it: brew install xcodegen" >&2
    exit 1
fi

xcodegen generate

# .xcodeproj is not tracked and gets regenerated, so SPM pins live in the repo
# root and are copied into the project after every generation.
if [ -f Package.resolved ]; then
    resolved_dir="v0ca.xcodeproj/project.xcworkspace/xcshareddata/swiftpm"
    mkdir -p "$resolved_dir"
    cp Package.resolved "$resolved_dir/Package.resolved"
    echo "→ Package versions restored from Package.resolved."
fi

echo "✓ Done. Open v0ca.xcodeproj."
