# wxWidgets Application Template

A ready-to-use starting point for a cross-platform desktop app in C++20, built with
[wxWidgets](https://www.wxwidgets.org/) and [Meson](https://mesonbuild.com/). It gives you a
working app skeleton, localization, versioning, and full packaging pipelines for macOS, Linux,
and Windows (including Docker-based CI builds), so you can start writing your app instead of
setting up build/release plumbing.

## Contents

- [Why use this](#why-use-this)
- [What's included](#whats-included)
- [Customising for your project](#customising-for-your-project)
  - [`with_webview` build option](#with_webview-build-option)
- [Building locally](#building-locally)
  - [macOS](#macos)
  - [Linux](#linux)
  - [Windows](#windows)
- [Static vs dynamic linking](#static-vs-dynamic-linking)
- [Docker builds](#docker-builds)
- [CI/CD](#cicd)
- [License](#license)

## Why use this

Getting a wxWidgets project from "hello world" to something you can actually ship —
signed-ish `.app`/`.dmg` on macOS, an AppImage and portable tarball on Linux, an NSIS
installer on Windows — normally takes a lot of one-off scripting. This template already
does that work:

- one Meson project that builds identically on all three platforms;
- a `package` build target that produces distributable artifacts, not just a binary;
- reproducible Docker-based builds for Linux and Windows, so you don't need those toolchains
  installed locally;
- GitHub Actions workflows wired to the same Docker images, plus a native macOS runner.

Use it as a template repo, or copy the pieces you need (packaging scripts, toolchain files,
CI workflows) into an existing project.

## What's included

- **App skeleton** — `App`, `MainFrame`, `MainPanel` with the usual wxWidgets idioms:
  `wxPersistenceManager` for window geometry, `wxSingleInstanceChecker`, a menu bar that
  behaves correctly on macOS (Window menu, `SetExitOnFrameDelete(false)`, window re-creation
  on app re-activate), file-based logging via `wxLog`, and an unhandled-exception handler.
  All user-facing strings go through `_()`.
- **Build system** — Meson, C++20, unity builds and precompiled headers enabled by default.
  Native and cross-compilation toolchain files live in `toolchains/`.
- **Localization** — gettext-based. Application strings live in `locale/wxExample/`, the
  standard wxWidgets translations in `locale/wxstd/`. The catalog loader resolves the locale
  directory relative to the executable, so it works both from the build tree and from an
  installed/packaged layout.
- **Versioning** — `src/version.cpp.in` is filled in by Meson and exposes `APP_NAME`,
  `APP_VERSION`, `APP_REVISION` (short git hash), `APP_VENDOR`, `APP_DESCRIPTION`,
  `APP_COPYRIGHT` as `const char*` globals.
- **Packaging** (`packaging/`) — per-platform scripts invoked by the `package` build target:
  - **macOS** — assembles a `.app` bundle with `dylibbundler`, wraps it in a `.dmg` with
    `create-dmg`.
  - **Linux** — builds a portable `tar.gz` (after an `ldd`-based dependency sanity check) and
    an AppImage via `linuxdeploy`.
  - **Windows** — stages a portable `.zip` and an NSIS installer (`makensis`), with both
    32-bit and 64-bit registry views and the full MUI2 language list.
- **Dependency checking** — `packaging/dep_check.py` inspects the compiled binary for runtime
  dependencies that won't exist on a clean machine, before packaging: `ldd` on Linux,
  `objdump`/`dumpbin` on Windows.

## Customising for your project

Edit `packaging/meson.build`:

```
vendor_name      = 'YourName'
copyright_holder = 'Your holder'
copyright_year   = '2026'
app_description  = 'Your description'
bundle_id_prefix = 'com.example'
```

Rename the project in the root `meson.build` (`project('wxExample', ...)`). That name becomes
the executable name, the bundle name, and the AppImage filename automatically — but the
gettext catalog directory does not follow it on its own: rename `locale/wxExample/` to match
your new project name exactly (it's used both as the directory name and, via
`i18n.gettext(meson.project_name(), ...)`, as the catalog domain that `App::SetupLocalization`
loads at runtime). If the two names don't match, your application catalog simply won't be found.

Replace `assets/app.png` (Linux icon) and `assets/app.ico` (Windows icon) with your own. Add
`assets/app.icns` for macOS.

### `with_webview` build option

`meson_options.txt` defines `with_webview` (boolean, default `false`). It controls whether the
`webview` wxWidgets module is requested at configure time:

```sh
meson setup build -Dwith_webview=true
```

This only selects the module on the wxWidgets side — the wxWidgets library you link against
still has to be built with `--enable-webview` (see the per-platform build steps below), or
configuration will fail. The Docker builds and CI workflows expose the same switch as a
`WITH_WEBVIEW` build arg / `with_webview` workflow input.

## Building locally

```sh
meson setup build
meson compile -C build
```

To produce distributable packages:

```sh
meson compile -C build package
```

Packages land in `build/packages/`.

### macOS

Requires: Xcode command-line tools, Meson/Ninja (`brew install meson ninja`), and for
packaging, `dylibbundler` and `create-dmg` (`brew install dylibbundler create-dmg`).

Build wxWidgets as a static universal binary:

```sh
cd /path/to/wxWidgets
mkdir build-static && cd build-static
../configure \
  --prefix=/opt/wx \
  --disable-shared --enable-optimise \
  --disable-debug --disable-debug_info --disable-debug_flag \
  --disable-tests --disable-sys-libs \
  --with-osx_cocoa --with-macosx-version-min=10.13 \
  --enable-universal_binary=arm64,x86_64 \
  --with-cxx=20 \
  --enable-mediactrl --enable-webview --enable-stc --enable-aui \
  --enable-propgrid --enable-ribbon --enable-richtext --enable-xrc --with-opengl
make -j$(sysctl -n hw.logicalcpu)
sudo make install
```

Put `wx-config` on `PATH`, then configure the project:

```sh
export PATH=/opt/wx/bin:$PATH
meson setup build --cross-file toolchains/macos-universal-native.txt --buildtype release -Db_pch=false
# or, native architecture only:
meson setup build --buildtype release
```

The universal toolchain compiles for `arm64` and `x86_64` in one pass; precompiled headers
don't work across that split, so `-Db_pch=false` is required whenever
`macos-universal-native.txt` is used. Single-arch builds (`macos-arm64-native.txt`,
`macos-x86_64-native.txt`, or no cross-file) keep PCH enabled by default.

### Linux

Requires: Meson/Ninja, GTK3 dev headers, `gettext`, and for packaging, `linuxdeploy` with the
GTK and AppImage plugins (download from the
[linuxdeploy releases page](https://github.com/linuxdeploy/linuxdeploy/releases), make
executable, put on `PATH`).

Build wxWidgets static, no system libs:

```sh
cd /path/to/wxWidgets
mkdir build-static && cd build-static
../configure \
  --prefix=/opt/wx \
  --disable-shared --enable-optimise \
  --disable-debug --disable-debug_info --disable-debug_flag \
  --disable-tests --disable-sys-libs \
  --with-gtk=3 --with-cxx=20 \
  --enable-mediactrl --enable-webview --enable-stc --enable-aui \
  --enable-propgrid --enable-ribbon --enable-richtext --enable-xrc \
  --with-opengl --with-libcurl
make -j$(nproc)
sudo make install
```

`--with-libcurl` is needed for `wxWebRequest`. Then:

```sh
export PATH=/opt/wx/bin:$PATH
meson setup build --buildtype release
```

### Windows

MinGW is the recommended and tested toolchain (native via MSYS2, or cross-compiled from
Linux/macOS). MSVC is not tested.

**Native (MSYS2, UCRT64 shell):**

```sh
pacman -S mingw-w64-ucrt-x86_64-gcc mingw-w64-ucrt-x86_64-meson \
          mingw-w64-ucrt-x86_64-ninja nsis
```

**Cross-compiling:** install `mingw-w64` (`apt install mingw-w64` / `brew install mingw-w64`).

Build wxWidgets, static, fully self-contained:

```sh
cd /path/to/wxWidgets
mkdir build-win64 && cd build-win64
LDFLAGS="-static -static-libgcc -static-libstdc++" \
CXXFLAGS="-static-libgcc -static-libstdc++" \
../configure \
  --prefix=/opt/wx-win --host=x86_64-w64-mingw32 \
  --disable-shared --enable-optimise \
  --disable-debug --disable-debug_info --disable-debug_flag \
  --disable-tests --disable-sys-libs \
  --with-msw --with-cxx=20 --enable-accessibility \
  --enable-webview --enable-mediactrl --enable-stc --enable-aui \
  --enable-propgrid --enable-ribbon --enable-richtext --enable-xrc \
  --with-opengl --with-winhttp
make -j$(nproc)
sudo make install
```

For 32-bit, use `i686-w64-mingw32` and a separate prefix.

Packaging needs NSIS (`makensis`) on `PATH` (`apt install nsis` / `brew install nsis` /
`pacman -S nsis`), and `objdump` from the MinGW toolchain for dependency checking.

Configure (64-bit cross-compile):

```sh
export PATH=/opt/wx-win/bin:$PATH
meson setup build \
  --cross-file toolchains/windows-mingw64-static-cross.txt \
  --buildtype release
```

32-bit: `toolchains/windows-mingw32-static-cross.txt` with a 32-bit wxWidgets prefix.

## Static vs dynamic linking

Static (`--disable-shared --disable-sys-libs`) is recommended everywhere:

- **macOS** — a dynamic build needs `dylibbundler` to copy every `.dylib` into the app
  bundle at packaging time, which makes the `.dmg` noticeably larger than the stripped
  static binary.
- **Linux** — dynamic wx builds depend on shared libraries that won't exist on arbitrary
  distros, so you'd have to bundle them into the AppImage anyway. A static binary passes the
  `ldd` dependency check cleanly and produces a lean portable tarball as well as the AppImage.
- **Windows/MinGW** — with the `LDFLAGS`/`CXXFLAGS` shown above, the C++ runtime is baked
  into the binary at link time. The resulting `.exe` has no dependency on `libgcc_s`,
  `libstdc++`, or `libwinpthread`, and needs no redistributable setup.

## Docker builds

You don't need the Linux/Windows toolchains installed locally — `docker-bake.hcl` builds them
in containers via Docker Buildx:

```sh
docker buildx bake webview   # or: docker buildx bake simple
```

`simple` builds without `wxWebView`; `webview` builds with it. Windows is always built via
MinGW cross-compilation inside the same containers. Output lands in `dist/`.

**Why Linux needs two webkit builds.** `wxWebView` on Linux links against `webkit2gtk`, which
has two incompatible ABIs in the wild: the legacy `webkit2gtk-4.0` (still the only option on
some distros/enterprise releases) and the current `webkit2gtk-4.1` (used elsewhere; `4.0` is
often unavailable or deprecated there). A binary built against one won't load on a system that
only has the other. The `webview` target builds against both, then combines them into a single
tarball/AppImage with a small dispatcher that detects the installed `webkit2gtk` version at
startup and launches the matching binary — so one artifact runs on both kinds of systems.

## CI/CD

GitHub Actions (`.github/workflows/`) mirrors the local Docker builds:

- **`build.yml`** — the entry point. Runs on push to `master`, on `v*` tags, and PRs. It
  fans out to `linux.yml`, `windows.yml`, and `macos.yml`; each only produces full
  installable packages for tag pushes or manual runs, otherwise it just compiles as a
  sanity check.
- **`linux.yml`** / **`windows.yml`** — build the same Docker targets as `docker-bake.hcl`,
  for `amd64` and `arm64` (Linux) or `amd64` (Windows), with layer caching via `gha` cache.
- **`macos.yml`** — runs natively on a `macos-14` runner (Docker can't cross-build macOS),
  building `arm64`, `x86_64`, and `universal` variants; caches the compiled wxWidgets build.
- **`release.yml`** — on tag pushes, collects all platform artifacts and creates a draft
  GitHub release.

`with_webview` is currently hardcoded to `false` in `build.yml`; flip it there if you want
CI to build the webview-enabled variant.

## License

MIT — see [LICENSE](LICENSE).
