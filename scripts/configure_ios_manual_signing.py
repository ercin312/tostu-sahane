#!/usr/bin/env python3
"""Apply manual App Store signing settings to the Runner Release configuration."""

from __future__ import annotations

import os
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PBXPROJ = ROOT / "ios" / "Runner.xcodeproj" / "project.pbxproj"
RELEASE_CONFIG_ID = "97C147071CF9000F007C117D"


def main() -> int:
    team_id = os.environ.get("APPLE_TEAM_ID", "").strip()
    profile_name = os.environ.get("IOS_PROVISIONING_PROFILE_NAME", "").strip()
    if not team_id or not profile_name:
        print("APPLE_TEAM_ID and IOS_PROVISIONING_PROFILE_NAME are required", file=sys.stderr)
        return 1

    content = PBXPROJ.read_text(encoding="utf-8")
    pattern = (
        rf"({RELEASE_CONFIG_ID} /\* Release \*/ = \{{\n\t\t\tisa = XCBuildConfiguration;\n"
        rf"\t\t\tbaseConfigurationReference = [^;]+;\n\t\t\tbuildSettings = \{{)(.*?)(\n\t\t\t\}};\n\t\t\tname = Release;)"
    )
    match = re.search(pattern, content, flags=re.DOTALL)
    if not match:
        print("Runner Release build configuration not found", file=sys.stderr)
        return 1

    settings = match.group(2)
    settings = re.sub(r"CODE_SIGN_STYLE = Automatic;", "CODE_SIGN_STYLE = Manual;", settings)
    settings = re.sub(
        r'"CODE_SIGN_IDENTITY\[sdk=iphoneos\*\]" = "iPhone Developer";',
        '"CODE_SIGN_IDENTITY[sdk=iphoneos*]" = "Apple Distribution";',
        settings,
    )
    if "DEVELOPMENT_TEAM" in settings:
        settings = re.sub(r"DEVELOPMENT_TEAM = [^;]+;", f"DEVELOPMENT_TEAM = {team_id};", settings)
    else:
        settings += f"\n\t\t\t\tDEVELOPMENT_TEAM = {team_id};"
    if "PROVISIONING_PROFILE_SPECIFIER" in settings:
        settings = re.sub(
            r'PROVISIONING_PROFILE_SPECIFIER = "[^"]*";',
            f'PROVISIONING_PROFILE_SPECIFIER = "{profile_name}";',
            settings,
        )
    else:
        settings += f'\n\t\t\t\tPROVISIONING_PROFILE_SPECIFIER = "{profile_name}";'
    if "CODE_SIGN_IDENTITY" not in settings:
        settings += '\n\t\t\t\t"CODE_SIGN_IDENTITY[sdk=iphoneos*]" = "Apple Distribution";'

    updated = content[: match.start(2)] + settings + content[match.end(2) :]
    PBXPROJ.write_text(updated, encoding="utf-8")
    print(f"Configured manual signing for {RELEASE_CONFIG_ID} (team={team_id})")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
