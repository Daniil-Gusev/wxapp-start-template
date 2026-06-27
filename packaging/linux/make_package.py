import os
import shutil
import subprocess
import sys
import tarfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
from dep_check import linux_unexpected_deps, report, require_tool

def make_tarball(name, version, arch, install_prefix, out_dir, dep_check_tool, wx_lib_names):
    exe = install_prefix / "bin" / name
    report(linux_unexpected_deps(exe, dep_check_tool, wx_lib_names), exe, "Linux")

    archive_path = out_dir / f"{name}-{version}-linux-{arch}.tar.gz"
    root_folder = f"{name}-{version}"

    with tarfile.open(archive_path, "w:gz") as tar:
        for subdir in ["bin", "share"]:
            src_path = install_prefix / subdir
            if src_path.exists():
                tar.add(src_path, arcname=f"{root_folder}/{subdir}")

    print(f"Created {archive_path.name}")

def make_appimage(name, version, arch, install_prefix, pkg_build_dir, src_root, out_dir):
    linuxdeploy = shutil.which("linuxdeploy")
    if not linuxdeploy:
        print("WARNING: 'linuxdeploy' not found on PATH, skipping AppImage creation.", file=sys.stderr)
        return

    desktop = pkg_build_dir / f"{name}.desktop"
    icon = src_root / "assets" / "app.png"
    if not desktop.exists():
        print(f"WARNING: {desktop} not found, skipping AppImage creation.", file=sys.stderr)
        return
    if not icon.exists():
        print(f"WARNING: {icon} not found, skipping AppImage creation.", file=sys.stderr)
        return
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

    cmd = [
        linuxdeploy,
        "--appdir", str(appdir),
        "--executable", str(exe),
        "--desktop-file", str(desktop),
        "--icon-file", str(named_icon),
        "--plugin", "gtk",
        "--output", "appimage",
    ]
    
    result = subprocess.run(cmd, env=env)
    if result.returncode != 0:
        sys.exit(result.returncode)

    print(f"Created {out_file.name}")

    if appdir.exists():
        shutil.rmtree(appdir)

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

    make_tarball(name, version, arch, install_prefix, out_dir, dep_check_tool, wx_lib_names)
    make_appimage(name, version, arch, install_prefix, pkg_build_dir, src_root, out_dir)

if __name__ == "__main__":
    main()
