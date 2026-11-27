#!/usr/bin/env python3
"""Verify production source settings and, optionally, an already built app.

No app launch, network request, signing, or upload is performed.
"""
import argparse
import hashlib
import json
from pathlib import Path
import plistlib
import subprocess

ROOT = Path(__file__).resolve().parent.parent
BUNDLE_ID = "com.aiankharitonov.cnbridge.dictionary"
DISPLAY_NAME = "Вэнь"
MARKETING_VERSION = "1.2"
BUILD_VERSION = "6"
API_URL = "https://31.129.45.131"


def require(condition, message):
    if not condition:
        raise SystemExit("FAIL: " + message)


def verify_assets(directory):
    manifest = json.loads((directory / "manifest.json").read_text())
    require(manifest["character_count"] == 9574, "Unexpected stroke character count")
    require(len(list((directory / "Characters").glob("*.json"))) == 9574,
            "Stroke character resources missing or unexpected")
    for relative, expected in manifest["files"].items():
        path = directory / relative
        require(path.is_file(), "Missing stroke asset: " + relative)
        require(hashlib.sha256(path.read_bytes()).hexdigest() == expected,
                "Changed stroke asset: " + relative)
    for name in ("ARPHICPL.TXT", "HANZI-WRITER-LICENSE.txt", "HANZI-WRITER-DATA-README.md"):
        require((directory / name).is_file(), "Missing bundled license: " + name)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--app", type=Path, help="Built .app or .xcarchive/Products/Applications/*.app")
    args = parser.parse_args()
    project_path = ROOT / "DictionaryApp.xcodeproj/project.pbxproj"
    project = json.loads(subprocess.check_output([
        "/usr/bin/plutil", "-convert", "json", "-o", "-", str(project_path),
    ]))
    objects = project["objects"]
    target = next(obj for obj in objects.values()
                  if obj.get("isa") == "PBXNativeTarget" and obj.get("name") == "DictionaryApp")
    configuration_list = objects[target["buildConfigurationList"]]
    configurations = [objects[key] for key in configuration_list["buildConfigurations"]]
    require({config["name"] for config in configurations} == {"Debug", "Release"},
            "Unexpected production configurations")
    for config in configurations:
        settings = config["buildSettings"]
        for key, expected in {
            "PRODUCT_BUNDLE_IDENTIFIER": BUNDLE_ID,
            "INFOPLIST_KEY_CFBundleDisplayName": DISPLAY_NAME,
            "CURRENT_PROJECT_VERSION": BUILD_VERSION,
            "MARKETING_VERSION": MARKETING_VERSION,
            "INFOPLIST_FILE": "DictionaryApp-Info.plist",
        }.items():
            require(str(settings.get(key)) == expected, config["name"] + ": incorrect " + key)
    project_text = project_path.read_text()
    for forbidden in ("LOCAL_DEVELOPMENT", ".localdev", "Local Development Guard"):
        require(forbidden not in project_text, "Local build setting in production project: " + forbidden)
    api = (ROOT / "Network/APIService.swift").read_text()
    require('private let baseURL = "' + API_URL + '"' in api, "Production API endpoint changed")
    for forbidden in ("LOCAL_DEVELOPMENT", "127.0.0.1", "localDevelopmentDisabled",
                      "CHINESE_BRIDGE_PREVIEW_JSON_BASE64", "DictionaryPreviewFixture", "DictionaryPreviewError"):
        require(forbidden not in api, "Local isolation code in production API: " + forbidden)
    require("func fetchReferencedEntry(target:" in api, "Missing dictionary link support")
    strokes = (ROOT / "Components/StrokeOrderWebView.swift").read_text()
    require("connect-src 'none'" in strokes, "Stroke HTML does not block networking")
    require("cdn.jsdelivr.net" not in strokes and "LOCAL_DEVELOPMENT" not in strokes,
            "Production stroke implementation is not exclusively bundled")
    verify_assets(ROOT / "StrokeAssets")
    print("PASS: production metadata, API/AI configuration, bundled strokes and license integrity")

    if args.app:
        app = args.app.resolve(strict=True)
        with (app / "Info.plist").open("rb") as source:
            info = plistlib.load(source)
        for key, expected in {
            "CFBundleIdentifier": BUNDLE_ID,
            "CFBundleDisplayName": DISPLAY_NAME,
            "CFBundleVersion": BUILD_VERSION,
            "CFBundleShortVersionString": MARKETING_VERSION,
        }.items():
            require(str(info.get(key)) == expected, "Built app has incorrect " + key)
        require(not info.get("NSAppTransportSecurity", {}).get("NSAllowsArbitraryLoads", False),
                "Built app enables arbitrary cleartext network access")
        require(info.get("ITSAppUsesNonExemptEncryption") is False,
                "Built app does not declare exempt, system-only encryption")
        executable = (app / info["CFBundleExecutable"]).read_bytes()
        require(API_URL.encode() in executable, "Production API not found in compiled app")
        for forbidden in ("127.0.0.1:18765", ".localdev", "ChineseBridge Local", "AI отключён в локальной тестовой сборке.",
                          "CHINESE_BRIDGE_PREVIEW_JSON_BASE64", "Локальная проверка • статьи из файла"):
            require(forbidden.encode() not in executable, "Local-only setting in compiled app: " + forbidden)
        verify_assets(app / "StrokeAssets")
        require((app / "PrivacyInfo.xcprivacy").is_file(), "Privacy manifest missing from app")
        print("PASS: built app name/version/bundle ID, production endpoint, privacy and stroke resources")


if __name__ == "__main__":
    main()
