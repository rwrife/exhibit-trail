"""Source/build contract assertions; Apple build evidence remains CI-only."""
import json
import pathlib
import plistlib
import re
import sys

root = pathlib.Path(__file__).resolve().parent.parent
pin = json.loads((root / "toolchain.json").read_text())
for key, expected in {
    "xcode_version": "26.0.1", "xcode_build": "17A400",
    "iphoneos_sdk": "26.0", "minimum_sdk_major": 26,
    "deployment_target": "26.0", "swift_language_mode": "6",
    "bundle_identifier": "com.infinityball.exhibittrail",
    "targeted_device_family": "1", "native_ipad_support": False,
    "network_allowlist": [],
}.items():
    assert pin[key] == expected, (key, pin[key])
project = (root / "ExhibitTrail.xcodeproj/project.pbxproj").read_text()
ids = set(re.findall(r"\b[A-F0-9]{24}\b", project))
definitions = re.findall(r"^\t\t([A-F0-9]{24})\b[^\n]* = \{", project, re.M)
assert ids == set(definitions) and len(definitions) == len(ids), "project ID closure"
assert re.findall(r"TARGETED_DEVICE_FAMILY = ([^;]+);", project) == ["1"] * 4
assert re.findall(r"SWIFT_VERSION = ([^;]+);", project) == ["6.0"] * 4
assert re.findall(r"IPHONEOS_DEPLOYMENT_TARGET = ([^;]+);", project) == ["26.0"] * 4
assert re.findall(r"PRODUCT_BUNDLE_IDENTIFIER = ([^;]+);", project) == [pin["bundle_identifier"]] * 2
assert "XCLocalSwiftPackageReference" in project
assert "relativePath = Packages/ExhibitTrailKit;" in project
assert not list(root.rglob("*.entitlements")), "No capabilities authorized at bootstrap"
privacy = plistlib.loads((root / "ExhibitTrail/PrivacyInfo.xcprivacy").read_bytes())
assert privacy["NSPrivacyTracking"] is False
assert privacy["NSPrivacyTrackingDomains"] == privacy["NSPrivacyCollectedDataTypes"] == []
if len(sys.argv) == 2:
    app = pathlib.Path(sys.argv[1])
    info = plistlib.loads((app / "Info.plist").read_bytes())
    assert info["UIDeviceFamily"] == [1], info["UIDeviceFamily"]
    assert info["CFBundleIdentifier"] == pin["bundle_identifier"]
    assert float(info["MinimumOSVersion"]) >= 26
    assert info.get("DTSDKName") == "iphonesimulator26.0", info.get("DTSDKName")
    assert info.get("DTSDKBuild"), "SDK build metadata missing"
    print(f"Built SDK: {info['DTSDKName']} ({info['DTSDKBuild']})")
    assert not any("UsageDescription" in key or key in {"NSAppTransportSecurity", "UIBackgroundModes"} for key in info)
    assert plistlib.loads((app / "PrivacyInfo.xcprivacy").read_bytes()) == privacy
    print("Built app UIDeviceFamily == [1], bundle ID, minimum OS, permissions and privacy: PASS")
else:
    assert len(sys.argv) == 1, "Usage: check_contract.py [built.app]"
print("Source contract (pin, 4 iPhone/Swift 6 configurations, bundle ID, project IDs): PASS")
