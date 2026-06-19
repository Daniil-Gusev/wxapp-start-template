import os
import sys
import shutil
import zipfile
from pathlib import Path

def main():
    name = sys.argv[1]
    version = sys.argv[2]
    install_prefix = Path(os.environ["MESON_INSTALL_PREFIX"])
    out_dir = Path(os.environ.get("PKG_OUT_DIR", "."))

    archive_path = out_dir / f"{name}-{version}-windows.zip"
    staging_dir = out_dir / f"{name}_staging"

    if staging_dir.exists():
        shutil.rmtree(staging_dir)
    staging_dir.mkdir()

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

    shutil.rmtree(staging_dir)
    print(f"Created {archive_path.name}")

if __name__ == "__main__":
    main()
