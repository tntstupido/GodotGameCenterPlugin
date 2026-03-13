#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUTPUT_ZIP="${ROOT_DIR}/GodotGameCenterPlugin-v0.1.0-ios.zip"

cd "${ROOT_DIR}"
rm -f "${OUTPUT_ZIP}"
zip -r "${OUTPUT_ZIP}" ios/plugins/game_center_plugin
echo "Created ${OUTPUT_ZIP}"

