"""Focused adversarial checks for the bootstrap policy gates (stdlib only)."""
import pathlib
import plistlib
import shutil
import subprocess
import tempfile

root = pathlib.Path(__file__).resolve().parent.parent
with tempfile.TemporaryDirectory(prefix="exhibit-contract-") as temporary:
    copy = pathlib.Path(temporary)
    for path in ("scripts", "Packages", "ExhibitTrail", "ExhibitTrail.xcodeproj", "toolchain.json"):
        source = root / path
        if source.is_dir():
            shutil.copytree(source, copy / path)
        else:
            shutil.copy2(source, copy / path)

    def check(script, valid, *args):
        command = ["python3" if script.endswith(".py") else "bash", str(copy / "scripts" / script), *map(str, args)]
        result = subprocess.run(command, capture_output=True, text=True, timeout=30)
        assert (result.returncode == 0) == valid, (command, result.stdout, result.stderr)

    check("check_contract.py", True)
    project = copy / "ExhibitTrail.xcodeproj/project.pbxproj"
    original = project.read_text()
    project.write_text(original.replace("TARGETED_DEVICE_FAMILY = 1;", "TARGETED_DEVICE_FAMILY = 1,2;", 1))
    check("check_contract.py", False)
    project.write_text(original)

    check("check_zero_network.sh", True)
    source = copy / "ExhibitTrail/Forbidden.swift"
    for snippet in (
        'let session = URLSession.shared',
        'let data = try Data(contentsOf: source)',
        'let url = URL(string: remote)',
        'let image = AsyncImage(url: source)',
        'let web = WKWebsiteDataStore.default()',
        'let player = AVPlayer(url: source)',
        'let asset = AVURLAsset(url: source)',
        'import AVFoundation',
        'import WebKit',
        'import CloudKit',
        'import Network',
        'import Darwin',
        'let sock = socket(AF_INET, SOCK_STREAM, 0)',
    ):
        source.write_text("import Foundation\n" + snippet + "\n")
        check("check_zero_network.sh", False)
    source.unlink()
    package_source = copy / "Packages/ExhibitTrailKit/Sources/ExhibitTrailKit/Forbidden.swift"
    for snippet in ('let session = URLSession.shared', 'let data = try Data(contentsOf: source)'):
        package_source.write_text(snippet + "\n")
        check("check_zero_network.sh", False)
    package_source.unlink()

    check("check_native_only.sh", True)
    for path, content in (
        ("pubspec.yaml", "name: forbidden\n"),
        ("build.gradle", "plugins { id 'org.jetbrains.kotlin.multiplatform' }\n"),
        ("App.csproj", "<Project><PropertyGroup><UseMaui>true</UseMaui></PropertyGroup></Project>\n"),
        ("package.json", '{"dependencies":{"react-native":"*"}}\n'),
    ):
        manifest = copy / path
        manifest.write_text(content)
        check("check_native_only.sh", False)
        manifest.unlink()

    app = copy / "Fixture.app"
    app.mkdir()
    shutil.copy2(copy / "ExhibitTrail/PrivacyInfo.xcprivacy", app / "PrivacyInfo.xcprivacy")
    info = {"UIDeviceFamily": [1], "CFBundleIdentifier": "com.infinityball.exhibittrail",
            "MinimumOSVersion": "26.0", "DTSDKName": "iphonesimulator26.0", "DTSDKBuild": "17A400"}
    plist = app / "Info.plist"
    plist.write_bytes(plistlib.dumps(info))
    check("check_contract.py", True, app)
    for field, invalid in (("UIDeviceFamily", [1, 2]), ("UIDeviceFamily", [1, 3]),
                           ("CFBundleIdentifier", "com.example.other"), ("MinimumOSVersion", "25.0"),
                           ("NSCameraUsageDescription", "Unauthorized permission"),
                           ("DTSDKName", "iphoneos26.0"), ("DTSDKName", "iphonesimulator18.4")):
        plist.write_bytes(plistlib.dumps({**info, field: invalid}))
        check("check_contract.py", False, app)
print("Contract regression checks: PASS (source/build fixtures, network and hybrid canaries)")
