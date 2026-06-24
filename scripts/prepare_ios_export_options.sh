#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEMPLATE="${ROOT_DIR}/ios/ExportOptions.plist.example"
OUTPUT="${ROOT_DIR}/ios/ExportOptions.plist"

: "${APPLE_TEAM_ID:?APPLE_TEAM_ID is required}"
: "${IOS_PROVISIONING_PROFILE_NAME:?IOS_PROVISIONING_PROFILE_NAME is required}"

sed \
  -e "s/APPLE_TEAM_ID/${APPLE_TEAM_ID}/g" \
  -e "s/IOS_PROVISIONING_PROFILE_NAME/${IOS_PROVISIONING_PROFILE_NAME}/g" \
  "${TEMPLATE}" > "${OUTPUT}"

echo "Wrote ${OUTPUT}"
