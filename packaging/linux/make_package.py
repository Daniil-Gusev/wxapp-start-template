import os
import shutil
import subprocess
import sys
import fnmatch
import tarfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
from dep_check import linux_unexpected_deps, linux_links_lib, report, require_tool

def make_tarball(name, version, arch, install_prefix, out_dir, dep_check_tool, wx_lib_names) -> bool:
    exe = install_prefix / "bin" / name
    ok = report(linux_unexpected_deps(exe, dep_check_tool, wx_lib_names), exe, "Linux")
    if not ok:
        print("Skipping portable tar.gz .", file=sys.stderr)
        return False

    archive_path = out_dir / f"{name}-{version}-linux-{arch}.tar.gz"
    root_folder = f"{name}-{version}"

    with tarfile.open(archive_path, "w:gz") as tar:
        for subdir in ["bin", "share"]:
            src_path = install_prefix / subdir
            if src_path.exists():
                tar.add(src_path, arcname=f"{root_folder}/{subdir}")

    print(f"Created {archive_path.name}")
    return True

GTK_LIB_PREFIXES = ["libgtk-3.so", "libgtk-4.so", "libgtk-x11-2.0.so"]

EXCLUDE_LIB_PATTERNS = [
    "libwebkit2gtk*",
    "libjavascriptcoregtk*",
    "libsoup-*",
    "libglib-2.0*",
    "libgobject-2.0*",
    "libgio-2.0*",
    "libgmodule-2.0*",
    "libgthread-2.0*",
]

def exclude_library_args(patterns) -> list:
    args = []
    for pattern in patterns:
        args += ["--exclude-library", pattern]
    return args

def clean_excluded_libraries(appdir, patterns) -> None:
    usr_lib_dir = appdir / "usr" / "lib"
    if not usr_lib_dir.exists():
        return
    for root, _, files in os.walk(usr_lib_dir):
        for filename in files:
            for pattern in patterns:
                if fnmatch.fnmatch(filename, pattern):
                    file_path = os.path.join(root, filename)
                    try:
                        if os.path.islink(file_path) or os.path.isfile(file_path):
                            os.remove(file_path)
                            print(f"  Removed: {filename}")
                    except Exception as e:
                        print(f"  Failed to remove {filename}: {e}", file=sys.stderr)

def make_appimage(name, version, arch, install_prefix, pkg_build_dir, src_root, out_dir, dep_check_tool) -> bool:
    linuxdeploy = shutil.which("linuxdeploy")
    if not linuxdeploy:
        print("WARNING: 'linuxdeploy' not found on PATH, skipping AppImage creation.", file=sys.stderr)
        return False

    desktop = pkg_build_dir / f"{name}.desktop"
    icon = src_root / "assets" / "app.png"
    if not desktop.exists():
        print(f"WARNING: {desktop} not found, skipping AppImage creation.", file=sys.stderr)
        return False
    if not icon.exists():
        print(f"WARNING: {icon} not found, skipping AppImage creation.", file=sys.stderr)
        return False

    appdir = out_dir / "AppDir"
    if appdir.exists():
        shutil.rmtree(appdir)

    exe = install_prefix / "bin" / name
    out_file = out_dir / f"{name}-{version}-{arch}.AppImage"
    named_icon = out_dir / f"{name}{icon.suffix}"
    shutil.copy2(icon, named_icon)

    env = os.environ.copy()
    env["OUTPUT"] = str(out_file)
    env["ARCH"] = arch

    exclude_args = exclude_library_args(EXCLUDE_LIB_PATTERNS)
    cmd = [
        linuxdeploy,
        "--appdir", str(appdir),
        "--executable", str(exe),
        "--desktop-file", str(desktop),
        "--icon-file", str(named_icon),
    ] + exclude_args
    if linux_links_lib(exe, dep_check_tool, GTK_LIB_PREFIXES):
        cmd += ["--plugin", "gtk"]
    result = subprocess.run(cmd, env=env)
    if result.returncode != 0:
        sys.exit(result.returncode)

    print("Cleaning up excluded libraries from AppDir...")
    clean_excluded_libraries(appdir, EXCLUDE_LIB_PATTERNS)

    print("Packaging final AppImage...")
    pack_cmd = [
        linuxdeploy,
        "--appdir", str(appdir),
    ] + exclude_args + [
        "--output", "appimage",
    ]
    result = subprocess.run(pack_cmd, env=env)
    if result.returncode != 0:
        sys.exit(result.returncode)

    if named_icon.exists():
        os.remove(named_icon)
    if appdir.exists():
        shutil.rmtree(appdir)
    print(f"Created {out_file.name}")
    return True

def main():
    if len(sys.argv) < 3:
        print(f"Usage: {sys.argv[0]} <name> <version>", file=sys.stderr)
        sys.exit(1)

    name = sys.argv[1]
    version = sys.argv[2]

    install_prefix = Path(os.environ["MESON_INSTALL_PREFIX"])
    pkg_build_dir = Path(os.environ["PKG_BUILD_DIR"])
    src_root = Path(os.environ["MESON_SOURCE_ROOT"])
    out_dir = Path(os.environ.get("PKG_OUT_DIR", "."))
    arch = os.environ.get("TARGET_ARCH", "")
    if not arch:
        sys.exit("error: TARGET_ARCH not set in environment")

    dep_check_tool = require_tool(
        os.environ.get("DEP_CHECK_TOOL", ""),
        os.environ.get("DEP_CHECK_KIND", ""),
        "install ldd and reconfigure",
    )
    wx_lib_names = [n for n in os.environ.get("DEP_CHECK_WX_LIBS", "").split(":") if n]

    tarball_ok = make_tarball(name, version, arch, install_prefix, out_dir, dep_check_tool, wx_lib_names)
    img_ok = make_appimage(name, version, arch, install_prefix, pkg_build_dir, src_root, out_dir, dep_check_tool)

    if not tarball_ok and not img_ok:
        sys.exit(1)

if __name__ == "__main__":
    main()
