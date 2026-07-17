# syntax=docker/dockerfile:1.7

ARG WX_VERSION=3.2.11
ARG ALMA_BASE_PKGS="epel-release dnf-plugins-core make pkgconf git curl xz openssl ca-certificates python3.11 python3.11-pip gettext file bzip2 tar"
ARG ALMA_GUI_PKGS="gtk3-devel gstreamer1-devel gstreamer1-plugins-base-devel gstreamer1-plugins-bad-free-devel gstreamer1-plugins-good gstreamer1-plugins-ugly-free alsa-lib-devel pulseaudio-libs-devel libsecret-devel gspell-devel libunwind-devel libnotify-devel libcurl-devel mesa-libGL-devel mesa-libGLU-devel freeglut-devel libSM-devel libXtst-devel"
ARG DEBIAN_BASE_PKGS="apt-utils make pkg-config git curl file tar bzip2 xz-utils ca-certificates python3 gettext pipx python3-venv ninja-build"
ARG DEBIAN_MINGW_PKGS="gcc-mingw-w64-x86-64 g++-mingw-w64-x86-64 binutils-mingw-w64-x86-64 mingw-w64-tools"
ARG DEBIAN_WEBKIT41_GUI_PKGS="build-essential libgtk-3-dev libwebkit2gtk-4.1-dev libgstreamer1.0-dev libgstreamer-plugins-base1.0-dev libgstreamer-plugins-bad1.0-dev gstreamer1.0-plugins-good gstreamer1.0-plugins-ugly libasound2-dev libpulse-dev libsecret-1-dev libgspell-1-dev libunwind-dev libnotify-dev libcurl4-openssl-dev libgl1-mesa-dev libglu1-mesa-dev freeglut3-dev libsm-dev libxtst-dev"
ARG WX_COMMON_OPTS="--disable-shared --enable-optimise --disable-debug --disable-debug_info --disable-debug_flag --disable-tests --disable-sys-libs --with-cxx=20 --enable-mediactrl --enable-stc --enable-aui --enable-propgrid --enable-ribbon --enable-richtext --enable-xrc --with-opengl"
ARG WX_MINGW_OPTS="--with-msw --enable-accessibility --with-winhttp"
ARG MINGW_TARGET="x86_64-w64-mingw32"
ARG WITH_WEBVIEW=false
ARG APT_MIRROR_UBUNTU=archive.ubuntu.com
ARG APT_MIRROR_UBUNTU_PORTS=ports.ubuntu.com
ARG APT_MIRROR_UBUNTU_SECURITY=security.ubuntu.com

# Base toolchains (OS + compiler + meson/ninja), no wx-specific env yet

FROM --platform=linux/amd64 almalinux:8 AS base-amd64
ARG WX_VERSION
ARG ALMA_BASE_PKGS
RUN --mount=type=cache,target=/var/cache/dnf,sharing=locked,id=dnf-amd64 \
    dnf install -y ${ALMA_BASE_PKGS} > /dev/null&& \
    dnf config-manager --set-enabled powertools > /dev/null && \
    dnf install -y gcc-toolset-14-gcc gcc-toolset-14-gcc-c++ gcc-toolset-14-binutils > /dev/null
ENV PATH="/opt/rh/gcc-toolset-14/root/usr/bin:${PATH}"
RUN --mount=type=cache,target=/root/.cache/pip,id=pip-amd64 \
    pip3.11 install meson ninja > /dev/null
ENV WX_VERSION=${WX_VERSION}
RUN curl --retry 3 -L https://github.com/wxWidgets/wxWidgets/releases/download/v${WX_VERSION}/wxWidgets-${WX_VERSION}.tar.bz2 | tar xj -C /opt

FROM --platform=linux/arm64 almalinux:8 AS base-arm64
ARG WX_VERSION
ARG ALMA_BASE_PKGS
RUN --mount=type=cache,target=/var/cache/dnf,sharing=locked,id=dnf-arm64 \
    dnf install -y ${ALMA_BASE_PKGS} > /dev/null && \
    dnf config-manager --set-enabled powertools > /dev/null && \
    dnf install -y gcc-toolset-14-gcc gcc-toolset-14-gcc-c++ gcc-toolset-14-binutils > /dev/null
ENV PATH="/opt/rh/gcc-toolset-14/root/usr/bin:${PATH}"
RUN --mount=type=cache,target=/root/.cache/pip,id=pip-arm64 \
    pip3.11 install meson ninja > /dev/null
ENV WX_VERSION=${WX_VERSION}
RUN curl --retry 3 -L https://github.com/wxWidgets/wxWidgets/releases/download/v${WX_VERSION}/wxWidgets-${WX_VERSION}.tar.bz2 | tar xj -C /opt

FROM --platform=linux/amd64 ubuntu:22.04 AS base-ubuntu2204-amd64
ARG WX_VERSION
ARG DEBIAN_BASE_PKGS
ARG APT_MIRROR_UBUNTU
ARG APT_MIRROR_UBUNTU_PORTS
ARG APT_MIRROR_UBUNTU_SECURITY
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked,id=apt-ubuntu22-amd64 \
    --mount=type=cache,target=/var/lib/apt,sharing=locked,id=aptlib-ubuntu22-amd64 \
    if [ -f /etc/apt/sources.list.d/ubuntu.sources ]; then sed -i "s|archive.ubuntu.com|${APT_MIRROR_UBUNTU}|g; s|ports.ubuntu.com|${APT_MIRROR_UBUNTU_PORTS}|g; s|security.ubuntu.com|${APT_MIRROR_UBUNTU_SECURITY}|g" /etc/apt/sources.list.d/ubuntu.sources; elif [ -f /etc/apt/sources.list ]; then sed -i "s|archive.ubuntu.com|${APT_MIRROR_UBUNTU}|g; s|ports.ubuntu.com|${APT_MIRROR_UBUNTU_PORTS}|g; s|security.ubuntu.com|${APT_MIRROR_UBUNTU_SECURITY}|g" /etc/apt/sources.list; fi && \
    apt-get -o Acquire::Retries=5 -o Acquire::http::Timeout=60 update > /dev/null && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends ${DEBIAN_BASE_PKGS} build-essential gnupg > /dev/null && \
    curl -fsSL "https://keyserver.ubuntu.com/pks/lookup?op=get&search=0xC8EC952E2A0E1FBDC5090F6A2C277A0A352154E5" | gpg --dearmor -o /etc/apt/trusted.gpg.d/ubuntu-toolchain-r.gpg && \
    echo "deb https://ppa.launchpadcontent.net/ubuntu-toolchain-r/test/ubuntu jammy main" > /etc/apt/sources.list.d/ubuntu-toolchain-r.list && \
    apt-get -o Acquire::Retries=5 -o Acquire::http::Timeout=60 update > /dev/null && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends gcc-14 g++-14 > /dev/null && \
    update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-14 100 && \
    update-alternatives --install /usr/bin/g++ g++ /usr/bin/g++-14 100
ENV PIPX_HOME=/opt/pipx
ENV PIPX_BIN_DIR=/usr/local/bin
ENV PATH="${PIPX_BIN_DIR}:${PATH}"
RUN --mount=type=cache,target=/root/.cache/pip,id=pip-ubuntu22-amd64 \
    pipx install meson > /dev/null
ENV WX_VERSION=${WX_VERSION}
RUN curl --retry 3 -L https://github.com/wxWidgets/wxWidgets/releases/download/v${WX_VERSION}/wxWidgets-${WX_VERSION}.tar.bz2 | tar xj -C /opt

FROM --platform=linux/arm64 ubuntu:22.04 AS base-ubuntu2204-arm64
ARG WX_VERSION
ARG DEBIAN_BASE_PKGS
ARG APT_MIRROR_UBUNTU
ARG APT_MIRROR_UBUNTU_PORTS
ARG APT_MIRROR_UBUNTU_SECURITY
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked,id=apt-ubuntu22-arm64 \
    --mount=type=cache,target=/var/lib/apt,sharing=locked,id=aptlib-ubuntu22-arm64 \
    if [ -f /etc/apt/sources.list.d/ubuntu.sources ]; then sed -i "s|archive.ubuntu.com|${APT_MIRROR_UBUNTU}|g; s|ports.ubuntu.com|${APT_MIRROR_UBUNTU_PORTS}|g; s|security.ubuntu.com|${APT_MIRROR_UBUNTU_SECURITY}|g" /etc/apt/sources.list.d/ubuntu.sources; elif [ -f /etc/apt/sources.list ]; then sed -i "s|archive.ubuntu.com|${APT_MIRROR_UBUNTU}|g; s|ports.ubuntu.com|${APT_MIRROR_UBUNTU_PORTS}|g; s|security.ubuntu.com|${APT_MIRROR_UBUNTU_SECURITY}|g" /etc/apt/sources.list; fi && \
    apt-get -o Acquire::Retries=5 -o Acquire::http::Timeout=60 update > /dev/null && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends ${DEBIAN_BASE_PKGS} build-essential gnupg > /dev/null && \
    curl -fsSL "https://keyserver.ubuntu.com/pks/lookup?op=get&search=0xC8EC952E2A0E1FBDC5090F6A2C277A0A352154E5" | gpg --dearmor -o /etc/apt/trusted.gpg.d/ubuntu-toolchain-r.gpg && \
    echo "deb https://ppa.launchpadcontent.net/ubuntu-toolchain-r/test/ubuntu jammy main" > /etc/apt/sources.list.d/ubuntu-toolchain-r.list && \
    apt-get -o Acquire::Retries=5 -o Acquire::http::Timeout=60 update > /dev/null && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends gcc-14 g++-14 > /dev/null && \
    update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-14 100 && \
    update-alternatives --install /usr/bin/g++ g++ /usr/bin/g++-14 100
ENV PIPX_HOME=/opt/pipx
ENV PIPX_BIN_DIR=/usr/local/bin
ENV PATH="${PIPX_BIN_DIR}:${PATH}"
RUN --mount=type=cache,target=/root/.cache/pip,id=pip-ubuntu22-arm64 \
    pipx install meson > /dev/null
ENV WX_VERSION=${WX_VERSION}
RUN curl --retry 3 -L https://github.com/wxWidgets/wxWidgets/releases/download/v${WX_VERSION}/wxWidgets-${WX_VERSION}.tar.bz2 | tar xj -C /opt

# General-purpose Ubuntu amd64 base

FROM --platform=linux/amd64 ubuntu:25.10 AS base-ubuntu-amd64
ARG WX_VERSION
ARG DEBIAN_BASE_PKGS
ARG APT_MIRROR_UBUNTU
ARG APT_MIRROR_UBUNTU_PORTS
ARG APT_MIRROR_UBUNTU_SECURITY
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked,id=apt-ubuntu-amd64 \
    --mount=type=cache,target=/var/lib/apt,sharing=locked,id=aptlib-ubuntu-amd64 \
    if [ -f /etc/apt/sources.list.d/ubuntu.sources ]; then sed -i "s|archive.ubuntu.com|${APT_MIRROR_UBUNTU}|g; s|ports.ubuntu.com|${APT_MIRROR_UBUNTU_PORTS}|g; s|security.ubuntu.com|${APT_MIRROR_UBUNTU_SECURITY}|g" /etc/apt/sources.list.d/ubuntu.sources; elif [ -f /etc/apt/sources.list ]; then sed -i "s|archive.ubuntu.com|${APT_MIRROR_UBUNTU}|g; s|ports.ubuntu.com|${APT_MIRROR_UBUNTU_PORTS}|g; s|security.ubuntu.com|${APT_MIRROR_UBUNTU_SECURITY}|g" /etc/apt/sources.list; fi && \
    apt-get -o Acquire::Retries=5 -o Acquire::http::Timeout=60 update > /dev/null && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends ${DEBIAN_BASE_PKGS} > /dev/null
ENV PIPX_HOME=/opt/pipx
ENV PIPX_BIN_DIR=/usr/local/bin
ENV PATH="${PIPX_BIN_DIR}:${PATH}"
RUN --mount=type=cache,target=/root/.cache/pip,id=pip-ubuntu-amd64 \
    pipx install meson > /dev/null
ENV WX_VERSION=${WX_VERSION}
RUN curl --retry 3 -L https://github.com/wxWidgets/wxWidgets/releases/download/v${WX_VERSION}/wxWidgets-${WX_VERSION}.tar.bz2 | tar xj -C /opt

# wxWidgets static builds

FROM --platform=linux/amd64 base-amd64 AS wx-linux-amd64
ARG WX_VERSION
ARG ALMA_GUI_PKGS
ARG WX_COMMON_OPTS
ARG WITH_WEBVIEW
ENV LDFLAGS="-static-libgcc -static-libstdc++" \
    CXXFLAGS="-static-libgcc -static-libstdc++" \
    CFLAGS="-static-libgcc"
RUN --mount=type=cache,target=/var/cache/dnf,sharing=locked,id=dnf-amd64 \
    if [ "${WITH_WEBVIEW}" = "true" ]; then \
      dnf install -y ${ALMA_GUI_PKGS} webkit2gtk3-devel > /dev/null; \
    else \
      dnf install -y ${ALMA_GUI_PKGS} > /dev/null; \
    fi
WORKDIR /opt/wxWidgets-${WX_VERSION}
RUN mkdir build-static-release && cd build-static-release && \
    webview_opt=""; [ "${WITH_WEBVIEW}" = "true" ] && webview_opt="--enable-webview"; \
    ../configure --prefix=/opt/wx-linux-amd64 ${WX_COMMON_OPTS} ${webview_opt} --with-gtk=3 --with-libcurl > /dev/null && \
    make -j$(nproc) > /dev/null && make install > /dev/null

FROM --platform=linux/arm64 base-arm64 AS wx-linux-arm64
ARG WX_VERSION
ARG ALMA_GUI_PKGS
ARG WX_COMMON_OPTS
ARG WITH_WEBVIEW
ENV LDFLAGS="-static-libgcc -static-libstdc++" \
    CXXFLAGS="-static-libgcc -static-libstdc++" \
    CFLAGS="-static-libgcc"
RUN --mount=type=cache,target=/var/cache/dnf,sharing=locked,id=dnf-arm64 \
    if [ "${WITH_WEBVIEW}" = "true" ]; then \
      dnf install -y ${ALMA_GUI_PKGS} webkit2gtk3-devel > /dev/null; \
    else \
      dnf install -y ${ALMA_GUI_PKGS} > /dev/null; \
    fi
WORKDIR /opt/wxWidgets-${WX_VERSION}
RUN mkdir build-static-release && cd build-static-release && \
    webview_opt=""; [ "${WITH_WEBVIEW}" = "true" ] && webview_opt="--enable-webview"; \
    ../configure --prefix=/opt/wx-linux-arm64 ${WX_COMMON_OPTS} ${webview_opt} --with-gtk=3 --with-libcurl > /dev/null && \
    make -j$(nproc) > /dev/null && make install > /dev/null

FROM --platform=linux/amd64 base-ubuntu-amd64 AS wx-mingw64
ARG WX_VERSION
ARG MINGW_TARGET
ARG DEBIAN_MINGW_PKGS
ARG WX_COMMON_OPTS
ARG WX_MINGW_OPTS
ARG WITH_WEBVIEW
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked,id=apt-ubuntu-amd64 \
    --mount=type=cache,target=/var/lib/apt,sharing=locked,id=aptlib-ubuntu-amd64 \
    apt-get -o Acquire::Retries=5 -o Acquire::http::Timeout=60 update > /dev/null && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends ${DEBIAN_MINGW_PKGS} > /dev/null
RUN update-alternatives --set ${MINGW_TARGET}-gcc /usr/bin/${MINGW_TARGET}-gcc-posix > /dev/null && \
    update-alternatives --set ${MINGW_TARGET}-g++ /usr/bin/${MINGW_TARGET}-g++-posix > /dev/null
ENV LDFLAGS="-static -static-libgcc -static-libstdc++" \
    CXXFLAGS="-static-libgcc -static-libstdc++"
WORKDIR /opt/wxWidgets-${WX_VERSION}
RUN mkdir build-static-release && cd build-static-release && \
    webview_opt=""; [ "${WITH_WEBVIEW}" = "true" ] && webview_opt="--enable-webview"; \
    ../configure --prefix=/opt/wx-win64 --host=${MINGW_TARGET} ${WX_COMMON_OPTS} ${webview_opt} ${WX_MINGW_OPTS} > /dev/null && \
    make -j$(nproc) > /dev/null && make install > /dev/null

# wxWidgets static build against webkit2gtk-4.1 instead of the legacy webkit2gtk3 (4.0)

FROM --platform=linux/amd64 base-ubuntu2204-amd64 AS wx-linux-amd64-webkit41
ARG WX_VERSION
ARG DEBIAN_WEBKIT41_GUI_PKGS
ARG WX_COMMON_OPTS
ENV LDFLAGS="-static-libgcc -static-libstdc++" \
    CXXFLAGS="-static-libgcc -static-libstdc++" \
    CFLAGS="-static-libgcc"
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked,id=apt-ubuntu22-amd64 \
    --mount=type=cache,target=/var/lib/apt,sharing=locked,id=aptlib-ubuntu22-amd64 \
    apt-get -o Acquire::Retries=5 -o Acquire::http::Timeout=60 update > /dev/null && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends ${DEBIAN_WEBKIT41_GUI_PKGS} > /dev/null
WORKDIR /opt/wxWidgets-${WX_VERSION}
RUN mkdir build-static-release && cd build-static-release && \
    ../configure --prefix=/opt/wx-linux-amd64-webkit41 ${WX_COMMON_OPTS} --enable-webview --with-gtk=3 --with-libcurl > /dev/null && \
    make -j$(nproc) > /dev/null && make install > /dev/null

FROM --platform=linux/arm64 base-ubuntu2204-arm64 AS wx-linux-arm64-webkit41
ARG WX_VERSION
ARG DEBIAN_WEBKIT41_GUI_PKGS
ARG WX_COMMON_OPTS
ENV LDFLAGS="-static-libgcc -static-libstdc++" \
    CXXFLAGS="-static-libgcc -static-libstdc++" \
    CFLAGS="-static-libgcc"
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked,id=apt-ubuntu22-arm64 \
    --mount=type=cache,target=/var/lib/apt,sharing=locked,id=aptlib-ubuntu22-arm64 \
    apt-get -o Acquire::Retries=5 -o Acquire::http::Timeout=60 update > /dev/null && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends ${DEBIAN_WEBKIT41_GUI_PKGS} > /dev/null
WORKDIR /opt/wxWidgets-${WX_VERSION}
RUN mkdir build-static-release && cd build-static-release && \
    ../configure --prefix=/opt/wx-linux-arm64-webkit41 ${WX_COMMON_OPTS} --enable-webview --with-gtk=3 --with-libcurl > /dev/null && \
    make -j$(nproc) > /dev/null && make install > /dev/null

# Packaging tools layered on top of each wx build

FROM --platform=linux/amd64 wx-linux-amd64 AS tools-linux-amd64
RUN curl --retry 3 -L -o /usr/local/bin/linuxdeploy https://github.com/linuxdeploy/linuxdeploy/releases/download/continuous/linuxdeploy-x86_64.AppImage > /dev/null && \
    curl --retry 3 -L -o /usr/local/bin/linuxdeploy-plugin-appimage https://github.com/linuxdeploy/linuxdeploy-plugin-appimage/releases/download/continuous/linuxdeploy-plugin-appimage-x86_64.AppImage > /dev/null && \
    curl --retry 3 -L -o /usr/local/bin/linuxdeploy-plugin-gtk https://raw.githubusercontent.com/linuxdeploy/linuxdeploy-plugin-gtk/master/linuxdeploy-plugin-gtk.sh > /dev/null && \
    chmod +x /usr/local/bin/linuxdeploy /usr/local/bin/linuxdeploy-plugin-appimage /usr/local/bin/linuxdeploy-plugin-gtk
ENV APPIMAGE_EXTRACT_AND_RUN=1
ENV PATH="/opt/wx-linux-amd64/bin:${PATH}"

FROM --platform=linux/arm64 wx-linux-arm64 AS tools-linux-arm64
RUN curl --retry 3 -L -o /usr/local/bin/linuxdeploy https://github.com/linuxdeploy/linuxdeploy/releases/download/continuous/linuxdeploy-aarch64.AppImage > /dev/null && \
    curl --retry 3 -L -o /usr/local/bin/linuxdeploy-plugin-appimage https://github.com/linuxdeploy/linuxdeploy-plugin-appimage/releases/download/continuous/linuxdeploy-plugin-appimage-aarch64.AppImage > /dev/null && \
    curl --retry 3 -L -o /usr/local/bin/linuxdeploy-plugin-gtk https://raw.githubusercontent.com/linuxdeploy/linuxdeploy-plugin-gtk/master/linuxdeploy-plugin-gtk.sh > /dev/null && \
    chmod +x /usr/local/bin/linuxdeploy /usr/local/bin/linuxdeploy-plugin-appimage /usr/local/bin/linuxdeploy-plugin-gtk
ENV APPIMAGE_EXTRACT_AND_RUN=1
ENV PATH="/opt/wx-linux-arm64/bin:${PATH}"

FROM --platform=linux/amd64 wx-mingw64 AS tools-win64
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get -o Acquire::Retries=5 -o Acquire::http::Timeout=60 update > /dev/null && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends wine64 nsis > /dev/null
ENV PATH="/opt/wx-win64/bin:${PATH}"

FROM --platform=linux/amd64 wx-linux-amd64-webkit41 AS tools-linux-amd64-webkit41
RUN curl --retry 3 -L -o /usr/local/bin/linuxdeploy https://github.com/linuxdeploy/linuxdeploy/releases/download/continuous/linuxdeploy-x86_64.AppImage > /dev/null && \
    curl --retry 3 -L -o /usr/local/bin/linuxdeploy-plugin-appimage https://github.com/linuxdeploy/linuxdeploy-plugin-appimage/releases/download/continuous/linuxdeploy-plugin-appimage-x86_64.AppImage > /dev/null && \
    curl --retry 3 -L -o /usr/local/bin/linuxdeploy-plugin-gtk https://raw.githubusercontent.com/linuxdeploy/linuxdeploy-plugin-gtk/master/linuxdeploy-plugin-gtk.sh > /dev/null && \
    chmod +x /usr/local/bin/linuxdeploy /usr/local/bin/linuxdeploy-plugin-appimage /usr/local/bin/linuxdeploy-plugin-gtk
ENV APPIMAGE_EXTRACT_AND_RUN=1
ENV PATH="/opt/wx-linux-amd64-webkit41/bin:${PATH}"

FROM --platform=linux/arm64 wx-linux-arm64-webkit41 AS tools-linux-arm64-webkit41
RUN curl --retry 3 -L -o /usr/local/bin/linuxdeploy https://github.com/linuxdeploy/linuxdeploy/releases/download/continuous/linuxdeploy-aarch64.AppImage > /dev/null && \
    curl --retry 3 -L -o /usr/local/bin/linuxdeploy-plugin-appimage https://github.com/linuxdeploy/linuxdeploy-plugin-appimage/releases/download/continuous/linuxdeploy-plugin-appimage-aarch64.AppImage > /dev/null && \
    curl --retry 3 -L -o /usr/local/bin/linuxdeploy-plugin-gtk https://raw.githubusercontent.com/linuxdeploy/linuxdeploy-plugin-gtk/master/linuxdeploy-plugin-gtk.sh > /dev/null && \
    chmod +x /usr/local/bin/linuxdeploy /usr/local/bin/linuxdeploy-plugin-appimage /usr/local/bin/linuxdeploy-plugin-gtk
ENV APPIMAGE_EXTRACT_AND_RUN=1
ENV PATH="/opt/wx-linux-arm64-webkit41/bin:${PATH}"

# Project build per target

FROM --platform=linux/amd64 tools-linux-amd64 AS compile-linux-amd64
ARG WITH_WEBVIEW
COPY . /src
WORKDIR /src
RUN meson setup build --wipe -Dwith_webview=${WITH_WEBVIEW} && ninja -C build

FROM compile-linux-amd64 AS build-linux-amd64
RUN ninja -C build package > /dev/null && mkdir -p /out/linux-amd64 && cp -r build/packages/. /out/linux-amd64/

FROM scratch AS export-linux-amd64-plain
COPY --from=build-linux-amd64 /out/linux-amd64 /

FROM --platform=linux/arm64 tools-linux-arm64 AS compile-linux-arm64
ARG WITH_WEBVIEW
COPY . /src
WORKDIR /src
RUN meson setup build --wipe -Dwith_webview=${WITH_WEBVIEW} && ninja -C build

FROM compile-linux-arm64 AS build-linux-arm64
RUN ninja -C build package > /dev/null && mkdir -p /out/linux-arm64 && cp -r build/packages/. /out/linux-arm64/

FROM scratch AS export-linux-arm64-plain
COPY --from=build-linux-arm64 /out/linux-arm64 /

FROM --platform=linux/amd64 tools-win64 AS compile-win64
ARG WITH_WEBVIEW
COPY . /src
WORKDIR /src
RUN meson setup build --wipe -Dwith_webview=${WITH_WEBVIEW} --cross-file toolchains/windows-mingw64-static-cross.txt && ninja -C build

FROM compile-win64 AS build-win64
RUN ninja -C build package > /dev/null && mkdir -p /out/win64 && cp -r build/packages/. /out/win64/

FROM scratch AS export-win64
COPY --from=build-win64 /out/win64 /

FROM --platform=linux/amd64 tools-linux-amd64-webkit41 AS compile-linux-amd64-webkit41
ARG WITH_WEBVIEW
COPY . /src
WORKDIR /src
RUN meson setup build --wipe -Dwith_webview=${WITH_WEBVIEW} && ninja -C build

FROM compile-linux-amd64-webkit41 AS build-linux-amd64-webkit41
RUN ninja -C build package > /dev/null && mkdir -p /out/linux-amd64-webkit41 && cp -r build/packages/. /out/linux-amd64-webkit41/

FROM scratch AS export-linux-amd64-webkit41
COPY --from=build-linux-amd64-webkit41 /out/linux-amd64-webkit41 /

FROM --platform=linux/arm64 tools-linux-arm64-webkit41 AS compile-linux-arm64-webkit41
ARG WITH_WEBVIEW
COPY . /src
WORKDIR /src
RUN meson setup build --wipe -Dwith_webview=${WITH_WEBVIEW} && ninja -C build

FROM compile-linux-arm64-webkit41 AS build-linux-arm64-webkit41
RUN ninja -C build package > /dev/null && mkdir -p /out/linux-arm64-webkit41 && cp -r build/packages/. /out/linux-arm64-webkit41/

FROM scratch AS export-linux-arm64-webkit41
COPY --from=build-linux-arm64-webkit41 /out/linux-arm64-webkit41 /

# Combine webkit2gtk-4.0 and webkit2gtk-4.1 artifacts into dual-webkit deliverables

FROM --platform=linux/amd64 base-ubuntu-amd64 AS combine-linux-amd64
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked,id=apt-ubuntu-amd64 \
    --mount=type=cache,target=/var/lib/apt,sharing=locked,id=aptlib-ubuntu-amd64 \
    apt-get -o Acquire::Retries=5 -o Acquire::http::Timeout=60 update > /dev/null && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends squashfs-tools > /dev/null
RUN curl --retry 3 -L -o /usr/local/bin/appimagetool https://github.com/AppImage/appimagetool/releases/download/continuous/appimagetool-x86_64.AppImage > /dev/null && \
    chmod +x /usr/local/bin/appimagetool
ENV APPIMAGE_EXTRACT_AND_RUN=1
COPY packaging/linux/combine_dual_webkit.py packaging/linux/detect_webkit.sh packaging/linux/dispatcher_tarball.sh.in packaging/linux/apprun.sh.in /opt/combine/
COPY --from=build-linux-amd64 /out/linux-amd64 /artifacts/webkit40
COPY --from=build-linux-amd64-webkit41 /out/linux-amd64-webkit41 /artifacts/webkit41
RUN mkdir -p /out/linux-amd64-combined && \
    python3 /opt/combine/combine_dual_webkit.py amd64 /artifacts/webkit40 /artifacts/webkit41 /opt/combine /out/linux-amd64-combined

FROM scratch AS export-linux-amd64-combined
COPY --from=combine-linux-amd64 /out/linux-amd64-combined /

FROM --platform=linux/arm64 base-ubuntu2204-arm64 AS combine-linux-arm64
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked,id=apt-ubuntu22-arm64 \
    --mount=type=cache,target=/var/lib/apt,sharing=locked,id=aptlib-ubuntu22-arm64 \
    apt-get -o Acquire::Retries=5 -o Acquire::http::Timeout=60 update > /dev/null && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends squashfs-tools > /dev/null
RUN curl --retry 3 -L -o /usr/local/bin/appimagetool https://github.com/AppImage/appimagetool/releases/download/continuous/appimagetool-aarch64.AppImage > /dev/null && \
    chmod +x /usr/local/bin/appimagetool
ENV APPIMAGE_EXTRACT_AND_RUN=1
COPY packaging/linux/combine_dual_webkit.py packaging/linux/detect_webkit.sh packaging/linux/dispatcher_tarball.sh.in packaging/linux/apprun.sh.in /opt/combine/
COPY --from=build-linux-arm64 /out/linux-arm64 /artifacts/webkit40
COPY --from=build-linux-arm64-webkit41 /out/linux-arm64-webkit41 /artifacts/webkit41
RUN mkdir -p /out/linux-arm64-combined && \
    python3 /opt/combine/combine_dual_webkit.py arm64 /artifacts/webkit40 /artifacts/webkit41 /opt/combine /out/linux-arm64-combined

FROM scratch AS export-linux-arm64-combined
COPY --from=combine-linux-arm64 /out/linux-arm64-combined /

FROM scratch AS export-linux-amd64-false
COPY --from=export-linux-amd64-plain / /
FROM scratch AS export-linux-amd64-true
COPY --from=export-linux-amd64-combined / /
FROM export-linux-amd64-${WITH_WEBVIEW} AS export-linux-amd64

FROM scratch AS export-linux-arm64-false
COPY --from=export-linux-arm64-plain / /
FROM scratch AS export-linux-arm64-true
COPY --from=export-linux-arm64-combined / /
FROM export-linux-arm64-${WITH_WEBVIEW} AS export-linux-arm64

# Default export: Linux artifacts (plain or dual-webkit, per WITH_WEBVIEW) + Windows build

FROM scratch AS export
COPY --from=export-linux-amd64 / /
COPY --from=export-linux-arm64 / /
COPY --from=build-win64 /out/win64 /
