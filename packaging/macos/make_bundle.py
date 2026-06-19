import os
import shutil
import subprocess
import sys
from pathlib import Path

def run(cmd: list, **kwargs) -> subprocess.CompletedProcess:
    result = subprocess.run(cmd, **kwargs)
    if result.returncode != 0:
        sys.exit(result.returncode)
    return result

def check_tool(name: str, hint: str):
    if shutil.which(name) is None:
        print(f"error: {name} not found, install with: {hint}", file=sys.stderr)
        sys.exit(1)

def get_wx_dylibs(binary: Path) -> list[str]:
    result = subprocess.run(
        ["otool", "-L", str(binary)],
        capture_output=True, text=True
    )
    return [
        line.strip().split()[0]
        for line in result.stdout.splitlines()
        if "wx" in line.lower() and ".dylib" in line
    ]

def install_translations(src_root: Path, build_prefix: Path, resources: Path, bundle_name: str):
    (resources / "en.lproj").mkdir(exist_ok=True)
    locale_src = build_prefix / "share" / "locale"
    if not locale_src.exists():
        return

    for lang_dir in locale_src.iterdir():
        if not lang_dir.is_dir():
            continue
        lc_messages = lang_dir / "LC_MESSAGES"
        for domain in (bundle_name, "wxstd"):
            mo_file = lc_messages / f"{domain}.mo"
            if mo_file.exists():
                lproj = resources / f"{lang_dir.name}.lproj"
                lproj.mkdir(exist_ok=True)
                shutil.copy2(mo_file, lproj / f"{domain}.mo")

def patch_plist_localizations(contents: Path):
    import plistlib
    plist_path = contents / "Info.plist"
    with open(plist_path, "rb") as f:
        plist = plistlib.load(f)

    langs = [d.stem for d in (contents / "Resources").iterdir()
             if d.suffix == ".lproj"]
    plist["CFBundleLocalizations"] = sorted(langs)

    with open(plist_path, "wb") as f:
        plistlib.dump(plist, f)

def create_dmg(app_path: Path, dmg_path: Path, bundle_name: str, version: str, icns_path: Path | None):
    if dmg_path.exists():
        dmg_path.unlink()

    cmd = [
        "create-dmg",
        "--volname", f"{bundle_name} {version}",
        "--window-size", "600", "400",
        "--icon-size", "100",
        "--icon", f"{bundle_name}.app", "150", "190",
        "--hide-extension", f"{bundle_name}.app",
        "--app-drop-link", "450", "190",
    ]
    if icns_path is not None and icns_path.exists():
        cmd += ["--volicon", str(icns_path)]
    cmd += [str(dmg_path), str(app_path)]

    result = subprocess.run(cmd)
    if result.returncode != 0 and not dmg_path.exists():
        print(f"error: create-dmg failed with code {result.returncode}", file=sys.stderr)
        sys.exit(result.returncode)

def main():
    if len(sys.argv) < 3:
        print(f"Usage: {sys.argv[0]} <bundle_name> <version>", file=sys.stderr)
        sys.exit(1)

    check_tool("create-dmg", "brew install create-dmg")

    bundle_name = sys.argv[1]
    version     = sys.argv[2]
    prefix     = Path(os.environ["MESON_INSTALL_PREFIX"])
    build_root = Path(os.environ.get("MESON_PROJECT_BUILD_ROOT") or os.environ["MESON_BUILD_ROOT"])
    src_root   = Path(os.environ["MESON_SOURCE_ROOT"])

    app_path   = prefix / f"{bundle_name}.app"
    contents   = app_path / "Contents"
    macos_dir  = contents / "MacOS"
    resources  = contents / "Resources"
    frameworks = contents / "Frameworks"

    for d in (macos_dir, resources, frameworks):
        d.mkdir(parents=True, exist_ok=True)

    executable = prefix / "bin" / bundle_name
    if not executable.exists():
        print(f"error: executable not found: {executable}", file=sys.stderr)
        sys.exit(1)
    shutil.copy2(executable, macos_dir / bundle_name)

    plist = build_root / "Info.plist"
    if not plist.exists():
        print(f"error: Info.plist not found: {plist}", file=sys.stderr)
        sys.exit(1)
    shutil.copy2(plist, contents / "Info.plist")

    icns_src = src_root / "assets" / "app.icns"
    icns_dst = resources / "app.icns"
    if icns_src.exists():
        shutil.copy2(icns_src, icns_dst)

    wx_dylibs = get_wx_dylibs(macos_dir / bundle_name)
    if wx_dylibs:
        check_tool("dylibbundler", "brew install dylibbundler")
        run([
            "dylibbundler", "-od", "-b",
            "-x", str(macos_dir / bundle_name),
            "-d", str(frameworks),
            "-p", "@executable_path/../Frameworks",
        ])
    install_translations(src_root, prefix, resources, bundle_name)
    patch_plist_localizations(contents)

    out_dir = Path(os.environ.get("PKG_OUT_DIR", prefix))
    dmg_path = out_dir / f"{bundle_name}-{version}.dmg"
    create_dmg(app_path, dmg_path, bundle_name, version, icns_dst if icns_dst.exists() else None)

if __name__ == "__main__":
    main()
