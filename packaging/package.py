import os
import sys
import subprocess
import tempfile
from pathlib import Path

def main():
    if len(sys.argv) < 7:
        sys.exit("Usage: package.py <name> <version> <build_dir> <source_dir> <host_system> <prefix>")

    name, version, build_dir, source_dir, host_system, prefix = sys.argv[1:7]

    build_dir = Path(build_dir).resolve()
    source_dir = Path(source_dir).resolve()
    prefix_path = Path(prefix)
    
    out_dir = build_dir / "packages"
    out_dir.mkdir(exist_ok=True)

    with tempfile.TemporaryDirectory() as tmpdir:
        destdir = Path(tmpdir)
        
        print(f"Installing to temporary destdir: {destdir}")
        subprocess.run(
            ["meson", "install", "--quiet", "-C", str(build_dir), "--destdir", str(destdir), "--no-rebuild"], 
            check=True
        )

        if prefix_path.is_absolute():
            relative_prefix = Path(*prefix_path.parts[1:])
            drive = prefix_path.drive
            if drive:
                install_prefix = destdir / drive.replace(':', '').lower() / relative_prefix
            else:
                install_prefix = destdir / relative_prefix
        else:
            install_prefix = destdir / prefix_path

        env = os.environ.copy()
        env["MESON_INSTALL_PREFIX"] = str(install_prefix)
        env["MESON_PROJECT_BUILD_ROOT"] = str(build_dir)
        env["MESON_SOURCE_ROOT"] = str(source_dir)
        env["PKG_OUT_DIR"] = str(out_dir)

        script_map = {
            "darwin": "macos/make_bundle.py",
            "windows": "windows/make_package.py",
            "linux": "linux/make_package.py"
        }

        if host_system not in script_map:
            sys.exit(f"Error: No packaging script defined for host system '{host_system}'")

        script = source_dir / "packaging" / script_map[host_system]
        if not script.exists():
            sys.exit(f"Error: Packaging script not found: {script}")

        print(f"Running packaging script for {host_system}...")
        subprocess.run([sys.executable, str(script), name, version], env=env, cwd=out_dir, check=True)

if __name__ == "__main__":
    main()
