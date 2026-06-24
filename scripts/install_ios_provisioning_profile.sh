#!/usr/bin/env bash
set -euo pipefail

: "${PROVISIONING_PROFILE_BASE64:?PROVISIONING_PROFILE_BASE64 is required}"

PP_PATH="${RUNNER_TEMP}/build_pp.mobileprovision"
echo -n "${PROVISIONING_PROFILE_BASE64}" | base64 --decode -o "${PP_PATH}"

mkdir -p "${HOME}/Library/MobileDevice/Provisioning Profiles"
UUID="$(/usr/libexec/PlistBuddy -c 'Print :UUID' /dev/stdin <<< "$(security cms -D -i "${PP_PATH}")")"
cp "${PP_PATH}" "${HOME}/Library/MobileDevice/Provisioning Profiles/${UUID}.mobileprovision"

echo "Installed provisioning profile ${UUID}"
