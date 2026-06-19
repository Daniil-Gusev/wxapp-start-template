import os
import sys
import tarfile
from pathlib import Path

def main():
    name = sys.argv[1]
    version = sys.argv[2]
    install_prefix = Path(os.environ["MESON_INSTALL_PREFIX"])
    out_dir = Path(os.environ.get("PKG_OUT_DIR", "."))

    archive_path = out_dir / f"{name}-{version}-linux.tar.gz"
    root_folder = f"{name}-{version}"

    with tarfile.open(archive_path, "w:gz") as tar:
        for subdir in ["bin", "share"]:
            src_path = install_prefix / subdir
            if src_path.exists():
                tar.add(src_path, arcname=f"{root_folder}/{subdir}")

    print(f"Created {archive_path.name}")

if __name__ == "__main__":
    main()
