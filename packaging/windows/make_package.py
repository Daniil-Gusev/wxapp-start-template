import os
import sys
import shutil
import zipfile
import subprocess
from pathlib import Path

def main():
    if len(sys.argv) < 3:
        print(f"Usage: {sys.argv[0]} <name> <version>", file=sys.stderr)
        sys.exit(1)

    name = sys.argv[1]
    version = sys.argv[2]

    install_prefix = Path(os.environ["MESON_INSTALL_PREFIX"])
    build_root = Path(os.environ.get("MESON_PROJECT_BUILD_ROOT") or os.environ["MESON_BUILD_ROOT"])
    out_dir = Path(os.environ.get("PKG_OUT_DIR", "."))

    archive_path = out_dir / f"{name}-{version}-windows-portable.zip"
    staging_dir = out_dir / f"{name}_staging"

    if staging_dir.exists():
        shutil.rmtree(staging_dir)
    staging_dir.mkdir(parents=True, exist_ok=True)

    exe_src = install_prefix / "bin" / f"{name}.exe"
    if not exe_src.exists():
        exe_src = install_prefix / "bin" / name
    shutil.copy2(exe_src, staging_dir / f"{name}.exe")

    locale_src = install_prefix / "share" / "locale"
    if locale_src.exists():
        shutil.copytree(locale_src, staging_dir / "locale")

    with zipfile.ZipFile(archive_path, 'w', zipfile.ZIP_DEFLATED) as zf:
        for root, _, files in os.walk(staging_dir):
            for file in files:
                file_path = Path(root) / file
                arcname = file_path.relative_to(staging_dir)
                zf.write(file_path, arcname)
    print(f"Created {archive_path.name}")

    makensis_bin = shutil.which("makensis")    
    if not makensis_bin:
        print("WARNING: 'makensis' not found. Skipping Windows installer creation.", file=sys.stderr)
    else:
        installer_path = out_dir / f"{name}-{version}-windows-installer.exe"
        
        meson_nsi_path = build_root / "installer.nsi"        
        if not meson_nsi_path.exists():
            print(f"error: installer.nsi not found in build root: {meson_nsi_path}", file=sys.stderr)
            sys.exit(1)

        nsi_content = meson_nsi_path.read_text(encoding='utf-8')
        
        final_staging_path = str(staging_dir.resolve())
        final_installer_path = str(installer_path.resolve())
        
        nsi_content = nsi_content.replace("{{STAGING_DIR}}", final_staging_path)
        nsi_content = nsi_content.replace("{{OUT_FILE}}", final_installer_path)
        
        final_nsi_path = build_root / "installer_final.nsi"
        final_nsi_path.write_text(nsi_content, encoding='utf-8')
        cmd = [makensis_bin, str(final_nsi_path.resolve())]

        try:
            print("Running makensis to create installer...")
            subprocess.run(cmd, check=True)
            print(f"Created {installer_path.name}")
            final_nsi_path.unlink()
        except subprocess.CalledProcessError as e:
            print(f"Error: makensis failed with exit code {e.returncode}", file=sys.stderr)

    if staging_dir.exists():
        shutil.rmtree(staging_dir)

if __name__ == "__main__":
    main()
