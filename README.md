# wxWidgets Application Template

A cross-platform C++20 application template built with [wxWidgets](https://www.wxwidgets.org/) and [Meson](https://mesonbuild.com/). Covers the full lifecycle from project skeleton to distributable packages on macOS, Linux, and Windows.

## Contents

- [What's included](#whats-included)
- [Customising for your project](#customising-for-your-project)
- [Building](#building)
- [Platform setup](#platform-setup)
  - [macOS](#macos)
  - [Linux](#linux)
  - [Windows](#windows)
- [Notes on static vs dynamic linking](#notes-on-static-vs-dynamic-linking)
- [Acknowledgements](#acknowledgements)

## What's included

**Build system** — Meson with C++20, unity builds, and PCH enabled by default. Picks up wxWidgets via `wx-config`. Toolchain files for native macOS (universal and x86\_64-only) and MinGW cross-compilation (32- and 64-bit) are provided under `toolchains/`.

**Application skeleton** — `App`, `MainFrame`, and `MainPanel` wired together with the standard wxWidgets idioms: `wxPersistenceManager` for window geometry, `wxSingleInstanceChecker`, a menu bar that behaves correctly on macOS (Window menu, `SetExitOnFrameDelete(false)`, re-create window on app re-activate), `wxLog` to a file in the user data directory, and an unhandled-exception handler. All user-visible strings go through `_()`.

**Localization** — `gettext`-based, with `locale/wxExample/` for application catalogs and `locale/wxstd/` for the standard wxWidgets translations. The runtime loader resolves the locale directory relative to the executable, so it works both from the build tree and from an installed/packaged layout.

**Versioning** — `src/version.cpp.in` is configured by Meson and exposes `APP_NAME`, `APP_VERSION`, `APP_REVISION` (short git hash), `APP_VENDOR`, `APP_DESCRIPTION`, and `APP_COPYRIGHT` as `const char*` globals.

**Packaging** — platform-specific scripts and Meson configuration under `packaging/`:

- **macOS** — assembles an `.app` bundle with `dylibbundler`, then wraps it in a `.dmg` with `create-dmg`.
- **Linux** — builds a portable `tar.gz` (after a dependency sanity check via `ldd`) and an AppImage via `linuxdeploy` with the GTK and AppImage plugins.
- **Windows** — stages a portable `.zip`, then produces an NSIS installer (`makensis`). The NSI template supports both 32- and 64-bit registry views and includes the full MUI2 language list.

**Dependency checking** — `packaging/dep_check.py` inspects the compiled binary for unexpected runtime dependencies before packaging: `ldd` on Linux (watches for dynamic wxWidgets libs leaking through), `objdump` or `dumpbin` on Windows (watches for non-system DLLs).

## Customising for your project

Edit `packaging/meson.build` to set:

```
vendor_name      = 'YourName'
copyright_holder = 'Your holder'
copyright_year   = '2026'
app_description  = 'Your description'
bundle_id_prefix = 'com.example'
```

Rename the project in the root `meson.build` (`project('wxExample', ...)`). That name is used as the executable name, the bundle name, the gettext domain, and the AppImage filename, so it propagates everywhere automatically.

Replace `assets/app.png` (Linux icon) and `assets/app.ico` (Windows icon) with your own. Add `assets/app.icns` for macOS.

## Building

```sh
meson setup build
meson compile -C build
```

To produce a distributable package, just run the `package` target — it handles the install step internally:

```sh
meson compile -C build package
```

Packages land in `build/packages/`.

---

## Platform setup

### macOS

**Tools required:**

- Xcode command-line tools (`xcode-select --install`)
- Meson and Ninja (`brew install meson ninja`)
- `dylibbundler` (`brew install dylibbundler`)
- `create-dmg` (`brew install create-dmg`)

**Building wxWidgets (recommended — static, universal binary):**

```sh
cd /path/to/wxWidgets
mkdir build-static && cd build-static
../configure \
  --prefix=/opt/wx \
  --disable-shared \
  --enable-optimise \
  --disable-debug \
  --disable-debug_info \
  --disable-debug_flag \
  --disable-tests \
  --disable-sys-libs \
  --enable-pch \
  --with-osx_cocoa \
  --with-macosx-version-min=10.13 \
  --enable-universal_binary=arm64,x86_64 \
  --with-cxx=20 \
  --enable-mediactrl \
  --enable-webview \
  --enable-stc \
  --enable-aui \
  --enable-propgrid \
  --enable-ribbon \
  --enable-richtext \
  --enable-xrc \
  --with-opengl
make -j$(sysctl -n hw.logicalcpu)
sudo make install
```

The template supports dynamic wxWidgets builds too, but static linking is strongly recommended. When bundling a dynamic build, `dylibbundler` copies all `.dylib` files into the app bundle — the resulting `.dmg` ends up noticeably larger than the equivalent statically linked binary after stripping.

**Configuring the project:**

Add the `bin/` directory of your wxWidgets installation to `PATH` before running `meson setup`, so that the correct `wx-config` is picked up:

```sh
export PATH=/path/to/wx/bin:$PATH
```

For a universal binary (recommended if distributing publicly):

```sh
meson setup build \
  --cross-file toolchains/macos-universal-native.txt \
  --buildtype release
```

For native architecture only:

```sh
meson setup build --buildtype release
```

---

### Linux

**Tools required:**

- Meson and Ninja (`apt install meson ninja-build` or equivalent)
- GTK3 development headers (`apt install libgtk-3-dev` or equivalent)
- `gettext` (`apt install gettext`)
- `linuxdeploy` with the GTK plugin and AppImage plugin — download the AppImages from the [linuxdeploy releases page](https://github.com/linuxdeploy/linuxdeploy/releases), make them executable, and place them on `PATH`. The packaging script invokes `linuxdeploy` with `--plugin gtk --output appimage`, so `linuxdeploy-plugin-gtk` must also be on `PATH`.

**Building wxWidgets (recommended — static, no system libs):**

```sh
cd /path/to/wxWidgets
mkdir build-static && cd build-static
../configure \
  --prefix=/opt/wx \
  --disable-shared \
  --enable-optimise \
  --disable-debug \
  --disable-debug_info \
  --disable-debug_flag \
  --disable-tests \
  --disable-sys-libs \
  --with-gtk=3 \
  --with-cxx=20 \
  --enable-mediactrl \
  --enable-webview \
  --enable-stc \
  --enable-aui \
  --enable-propgrid \
  --enable-ribbon \
  --enable-richtext \
  --enable-xrc \
  --with-opengl \
  --with-libcurl
make -j$(nproc)
sudo make install
```

Adjust `--with-gtk=2` if you need to target very old systems. `--with-libcurl` is needed for `wxWebRequest`. As with macOS, the packaging pipeline supports dynamic builds (the dep-check step will simply warn rather than skip the tarball if only system-level wx libs are found), but a statically linked binary is more portable and results in a smaller AppImage than a dynamic build where libraries need to be bundled.

**Configuring the project:**

```sh
export PATH=/path/to/wx/bin:$PATH
meson setup build --buildtype release
```

---

### Windows

MSVC is not tested. MinGW is the recommended toolchain, either natively on Windows or as a cross-compiler from Linux/macOS.

**Native build (MSYS2):**

Install MSYS2, then from the UCRT64 shell:

```sh
pacman -S mingw-w64-ucrt-x86_64-gcc mingw-w64-ucrt-x86_64-meson \
          mingw-w64-ucrt-x86_64-ninja nsis
```

Build wxWidgets into a local prefix, then put its `bin/` on `PATH` before configuring:

```sh
export PATH=/path/to/wx-win/bin:$PATH
meson setup build --buildtype release
```

**Cross-compilation from Linux/macOS:**

Install `mingw-w64` and optionally `wine` for running the test suite.

```sh
# Debian/Ubuntu
apt install mingw-w64

# Homebrew
brew install mingw-w64
```

**Building wxWidgets for Windows (64-bit, static, fully self-contained):**

```sh
cd /path/to/wxWidgets
mkdir build-win64 && cd build-win64
LDFLAGS="-static -static-libgcc -static-libstdc++" \
CXXFLAGS="-static-libgcc -static-libstdc++" \
../configure \
  --prefix=/opt/wx-win \
  --host=x86_64-w64-mingw32 \
  --disable-shared \
  --enable-optimise \
  --disable-debug \
  --disable-debug_info \
  --disable-debug_flag \
  --disable-tests \
  --disable-sys-libs \
  --with-msw \
  --with-cxx=20 \
  --enable-accessibility \
  --enable-webview \
  --enable-mediactrl \
  --enable-stc \
  --enable-aui \
  --enable-propgrid \
  --enable-ribbon \
  --enable-richtext \
  --enable-xrc \
  --with-opengl \
  --with-winhttp
make -j$(nproc)
sudo make install
```

The `LDFLAGS`/`CXXFLAGS` flags bake the GCC and C++ runtime into the static library at link time, so the final `.exe` has no dependency on `libgcc_s`, `libstdc++`, or `libwinpthread`. After stripping, a statically linked MinGW binary is typically smaller than the equivalent MSVC build with redistributable DLLs, and it runs on a clean Windows install without any runtime setup.

For 32-bit, replace `x86_64-w64-mingw32` with `i686-w64-mingw32` and adjust the prefix.

**Packaging tools:**

- NSIS (`makensis`) must be on `PATH`. On Linux: `apt install nsis`. On macOS: `brew install nsis`. On Windows/MSYS2: `pacman -S nsis`.
- `objdump` from the MinGW toolchain is used for dependency checking and must be on `PATH` (it is when building natively in MSYS2; for cross-compilation it's part of the toolchain and is declared in the toolchain file).

**Configuring for cross-compilation (64-bit):**

The toolchain file references `wx-config` by name, so the wxWidgets `bin/` directory for your Windows build must be on `PATH` before running `meson setup`:

```sh
export PATH=/path/to/wx-win/bin:$PATH
meson setup build \
  --cross-file toolchains/windows-mingw64-static-cross.txt \
  --buildtype release
```

32-bit uses `toolchains/windows-mingw32-static-cross.txt` with a 32-bit wxWidgets prefix.

---

## Notes on static vs dynamic linking

For all platforms the recommended approach is to build wxWidgets with `--disable-shared --disable-sys-libs`. The reasons:

- **macOS** — a dynamic build requires `dylibbundler` to copy all `.dylib` files into the app bundle at packaging time. The bundled `.dylib` files plus codesigning overhead typically result in a `.dmg` that is meaningfully larger than the stripped static binary.
- **Linux** — dynamic wx builds link against shared libraries that won't be present on arbitrary distros. You end up having to bundle them into the AppImage anyway, which increases size and complexity. A static binary passes the `ldd` dep-check cleanly and produces a lean portable tarball in addition to the AppImage.
- **Windows/MinGW** — with the `LDFLAGS`/`CXXFLAGS` flags shown above, the C++ runtime is baked in. The final `.exe` can be stripped to a small, dependency-free binary that runs without redistributable setup on any Windows version you targeted at configure time.

## Acknowledgements

- [wxWidgets](https://www.wxwidgets.org/) — the cross-platform GUI toolkit this template is built around.
- [Meson](https://mesonbuild.com/) — build system.
- [linuxdeploy](https://github.com/linuxdeploy/linuxdeploy) — AppImage packaging for Linux.
- [dylibbundler](https://github.com/auriamg/macdylibbundler) — dynamic library bundling for macOS.
- [create-dmg](https://github.com/create-dmg/create-dmg) — DMG creation for macOS.
- [NSIS](https://nsis.sourceforge.io/) — installer toolchain for Windows.
