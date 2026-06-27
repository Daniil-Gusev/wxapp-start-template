import os
import sys
import shutil
import zipfile
import subprocess
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
from dep_check import windows_unexpected_deps, report, require_tool

def resolve_exe(name: str, install_prefix: Path) -> Path:
    exe = install_prefix / "bin" / f"{name}.exe"
    if exe.exists():
        return exe
    return install_prefix / "bin" / name

def make_portable_zip(name, version, arch, install_prefix, out_dir, dep_check_tool, dep_check_kind) -> Path:
    exe_src = resolve_exe(name, install_prefix)
    unexpected, unresolved = windows_unexpected_deps(exe_src, dep_check_tool, dep_check_kind)
    if not report(unexpected, exe_src, "Windows", unresolved=unresolved):
        sys.exit(1)

    staging_dir = out_dir / f"{name}_staging"
    if staging_dir.exists():
        shutil.rmtree(staging_dir)
    staging_dir.mkdir(parents=True, exist_ok=True)

    shutil.copy2(exe_src, staging_dir / f"{name}.exe")
    locale_src = install_prefix / "share" / "locale"
    if locale_src.exists():
        shutil.copytree(locale_src, staging_dir / "locale")

    archive_path = out_dir / f"{name}-{version}-windows-{arch}-portable.zip"
    with zipfile.ZipFile(archive_path, 'w', zipfile.ZIP_DEFLATED) as zf:
        for root, _, files in os.walk(staging_dir):
            for file in files:
                file_path = Path(root) / file
                arcname = file_path.relative_to(staging_dir)
                zf.write(file_path, arcname)
    print(f"Created {archive_path.name}")

    return staging_dir

def make_installer(name, version, arch, pkg_build_dir, staging_dir, out_dir):
    makensis_bin = shutil.which("makensis")
    if not makensis_bin:
        print("WARNING: 'makensis' not found, skipping Windows installer creation.", file=sys.stderr)
        return

    installer_path = out_dir / f"{name}-{version}-windows-{arch}-installer.exe"
    meson_nsi_path = pkg_build_dir / "installer.nsi"
    if not meson_nsi_path.exists():
        print(f"error: installer.nsi not found in build root: {meson_nsi_path}", file=sys.stderr)
        sys.exit(1)

    nsi_content = meson_nsi_path.read_text(encoding='utf-8')
    nsi_content = nsi_content.replace("{{STAGING_DIR}}", str(staging_dir.resolve()))
    nsi_content = nsi_content.replace("{{OUT_FILE}}", str(installer_path.resolve()))

    final_nsi_path = pkg_build_dir / "installer_final.nsi"
    final_nsi_path.write_text(nsi_content, encoding='utf-8')

    cmd = [makensis_bin, str(final_nsi_path.resolve())]
    try:
        print("Running makensis to create installer...")
        subprocess.run(cmd, check=True)
        print(f"Created {installer_path.name}")
        final_nsi_path.unlink()
    except subprocess.CalledProcessError as e:
        print(f"Error: makensis failed with exit code {e.returncode}", file=sys.stderr)

def main():
    if len(sys.argv) < 3:
        print(f"Usage: {sys.argv[0]} <name> <version>", file=sys.stderr)
        sys.exit(1)

    name = sys.argv[1]
    version = sys.argv[2]

    install_prefix = Path(os.environ["MESON_INSTALL_PREFIX"])
    pkg_build_dir = Path(os.environ["PKG_BUILD_DIR"])
    out_dir = Path(os.environ.get("PKG_OUT_DIR", "."))

    arch = os.environ.get("TARGET_ARCH", "")
    if not arch:
        sys.exit("error: TARGET_ARCH not set in environment")

    dep_check_kind = os.environ.get("DEP_CHECK_KIND", "")
    dep_check_tool = require_tool(
        os.environ.get("DEP_CHECK_TOOL", ""),
        dep_check_kind,
        "install objdump (mingw toolchain) or run from a Developer Command Prompt (dumpbin) and reconfigure",
    )

    staging_dir = make_portable_zip(name, version, arch, install_prefix, out_dir, dep_check_tool, dep_check_kind)
    make_installer(name, version, arch, pkg_build_dir, staging_dir, out_dir)

    if staging_dir.exists():
        shutil.rmtree(staging_dir)

if __name__ == "__main__":
    main()
