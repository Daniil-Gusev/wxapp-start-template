import os
import shutil
import subprocess
import sys
import tarfile
import tempfile
from pathlib import Path

APPIMAGETOOL_ARCH = {"amd64": "x86_64", "arm64": "aarch64"}

def die(msg: str) -> None:
    sys.exit(f"error: {msg}")

def find_one(directory: Path, pattern: str) -> Path:
    matches = sorted(directory.glob(pattern))
    if len(matches) != 1:
        die(f"expected exactly one '{pattern}' in {directory}, found {len(matches)}: {matches}")
    return matches[0]

def render_template(templates_dir: Path, template_name: str, app_name: str) -> str:
    template_path = templates_dir / template_name
    if not template_path.exists():
        die(f"template not found: {template_path}")
    return template_path.read_text().replace("@APP_NAME@", app_name)

def extract_tarball(tarball: Path, dest: Path) -> Path:
    with tarfile.open(tarball, "r:gz") as tar:
        extract_kwargs = {"filter": "data"} if sys.version_info >= (3, 12) else {}
        tar.extractall(dest, **extract_kwargs)
    entries = list(dest.iterdir())
    if len(entries) != 1 or not entries[0].is_dir():
        die(f"expected {tarball} to contain a single top-level directory, found: {entries}")
    return entries[0]

def app_name_and_version(root_dir: Path) -> tuple[str, str]:
    bin_dir = root_dir / "bin"
    files = [p for p in bin_dir.iterdir() if p.is_file()]
    if len(files) != 1:
        die(f"expected exactly one file in {bin_dir}, found: {files}")
    name = files[0].name
    if not root_dir.name.startswith(name + "-"):
        die(f"top-level dir '{root_dir.name}' doesn't start with '{name}-' as expected")
    version = root_dir.name[len(name) + 1:]
    return name, version

def build_combined_tarball(name, version, arch, root40, root41, templates_dir, out_dir, work):
    combined_root = work / f"{name}-{version}"
    bin_dir = combined_root / "bin"
    bin_dir.mkdir(parents=True)

    shutil.copy2(root40 / "bin" / name, bin_dir / f".{name}.webkit40")
    shutil.copy2(root41 / "bin" / name, bin_dir / f".{name}.webkit41")
    shutil.copy2(templates_dir / "detect_webkit.sh", bin_dir / ".detect_webkit.sh")
    (bin_dir / name).write_text(render_template(templates_dir, "dispatcher_tarball.sh.in", name))

    for f in bin_dir.iterdir():
        f.chmod(0o755)

    share_src = root41 / "share"
    if share_src.exists():
        shutil.copytree(share_src, combined_root / "share")

    out_path = out_dir / f"{name}-{version}-linux-{arch}.tar.gz"
    with tarfile.open(out_path, "w:gz") as tar:
        tar.add(combined_root, arcname=combined_root.name)
    print(f"Created {out_path.name}")

def extract_appimage(appimage: Path, work: Path) -> Path:
    extract_dir = work / f"extract-{appimage.stem}"
    extract_dir.mkdir(parents=True)
    subprocess.run([str(appimage), "--appimage-extract"], cwd=extract_dir, check=True,
                    stdout=subprocess.DEVNULL)
    squashfs_root = extract_dir / "squashfs-root"
    if not squashfs_root.is_dir():
        die(f"'{appimage} --appimage-extract' didn't produce squashfs-root")
    return squashfs_root

def copy_root_item(item: Path, dest: Path) -> None:
    real = item.resolve() if item.is_symlink() else item
    if real.is_dir():
        shutil.copytree(real, dest)
    else:
        shutil.copy2(real, dest)

def build_combined_appimage(name, version, arch, squash40, squash41, templates_dir, out_dir, work):
    appdir = work / "AppDir"
    (appdir / "usr").mkdir(parents=True)

    shutil.copytree(squash40 / "usr", appdir / "usr" / "webkit40")
    shutil.copytree(squash41 / "usr", appdir / "usr" / "webkit41")

    for item in squash41.iterdir():
        if item.name in ("usr", "AppRun"):
            continue
        copy_root_item(item, appdir / item.name)

    shutil.copy2(templates_dir / "detect_webkit.sh", appdir / "detect_webkit.sh")
    (appdir / "AppRun").write_text(render_template(templates_dir, "apprun.sh.in", name))
    (appdir / "AppRun").chmod(0o755)
    (appdir / "detect_webkit.sh").chmod(0o755)

    out_path = out_dir / f"{name}-{version}-{arch}.AppImage"
    full_env = os.environ.copy()
    full_env["ARCH"] = APPIMAGETOOL_ARCH[arch]
    result = subprocess.run(["appimagetool", str(appdir), str(out_path)], env=full_env)
    if result.returncode != 0:
        die(f"appimagetool failed with exit code {result.returncode}")
    print(f"Created {out_path.name}")

def main():
    if len(sys.argv) != 6:
        sys.exit(f"Usage: {sys.argv[0]} <arch> <webkit40-dir> <webkit41-dir> <templates-dir> <out-dir>")

    arch, webkit40_dir, webkit41_dir, templates_dir, out_dir = sys.argv[1:]
    if arch not in APPIMAGETOOL_ARCH:
        die(f"unknown arch '{arch}', expected one of {sorted(APPIMAGETOOL_ARCH)}")

    webkit40_dir = Path(webkit40_dir)
    webkit41_dir = Path(webkit41_dir)
    templates_dir = Path(templates_dir)
    out_dir = Path(out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)

    tar40 = find_one(webkit40_dir, "*.tar.gz")
    tar41 = find_one(webkit41_dir, "*.tar.gz")
    appimage40 = find_one(webkit40_dir, "*.AppImage")
    appimage41 = find_one(webkit41_dir, "*.AppImage")

    with tempfile.TemporaryDirectory(prefix="combine-dual-webkit-") as tmp:
        work = Path(tmp)

        root40 = extract_tarball(tar40, work / "tar40")
        root41 = extract_tarball(tar41, work / "tar41")

        name40, version40 = app_name_and_version(root40)
        name41, version41 = app_name_and_version(root41)
        if (name40, version40) != (name41, version41):
            die(f"webkit2gtk-4.0 and webkit2gtk-4.1 builds disagree on name/version: "
                f"{name40}-{version40} vs {name41}-{version41}")
        name, version = name40, version40

        build_combined_tarball(name, version, arch, root40, root41, templates_dir, out_dir, work / "tarball-out")

        squash40 = extract_appimage(appimage40, work / "appimage40")
        squash41 = extract_appimage(appimage41, work / "appimage41")
        build_combined_appimage(name, version, arch, squash40, squash41, templates_dir, out_dir, work / "appimage-out")

if __name__ == "__main__":
    main()
