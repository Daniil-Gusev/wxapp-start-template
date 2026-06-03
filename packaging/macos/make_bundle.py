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

def main():
    if len(sys.argv) < 3:
        print(f"Usage: {sys.argv[0]} <bundle_name> <version>", file=sys.stderr)
        sys.exit(1)

    bundle_name = sys.argv[1]
    prefix     = Path(os.environ["MESON_INSTALL_PREFIX"])
    build_root = Path(os.environ.get("MESON_PROJECT_BUILD_ROOT") or os.environ["MESON_BUILD_ROOT"])
    src_root   = Path(os.environ["MESON_SOURCE_ROOT"])

    contents   = prefix / f"{bundle_name}.app" / "Contents"
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

    icns = src_root / "assets" / "app.icns"
    if icns.exists():
        shutil.copy2(icns, resources / "app.icns")

    wx_dylibs = get_wx_dylibs(macos_dir / bundle_name)
    if wx_dylibs:
        dylibbundler = shutil.which("dylibbundler")
        if not dylibbundler:
            print("error: dylibbundler not found, install with: brew install dylibbundler", file=sys.stderr)
            sys.exit(1)
        run([
            dylibbundler, "-od", "-b",
            "-x", str(macos_dir / bundle_name),
            "-d", str(frameworks),
            "-p", "@executable_path/../Frameworks",
        ])
    install_translations(src_root, prefix, resources, bundle_name)
    patch_plist_localizations(contents)

if __name__ == "__main__":
    main()
