# syntax=docker/dockerfile:1.7

ARG WX_VERSION=3.2.11
ARG ALMA_BASE_PKGS="epel-release dnf-plugins-core make pkgconf git curl xz ca-certificates python3.11 python3.11-pip gettext file bzip2 tar"
ARG ALMA_GUI_PKGS="gtk3-devel webkit2gtk3-devel gstreamer1-devel gstreamer1-plugins-base-devel gstreamer1-plugins-bad-free-devel gstreamer1-plugins-good gstreamer1-plugins-ugly-free alsa-lib-devel pulseaudio-libs-devel libsecret-devel gspell-devel libunwind-devel libnotify-devel libcurl-devel mesa-libGL-devel mesa-libGLU-devel freeglut-devel libSM-devel libXtst-devel"
ARG DEBIAN_BASE_PKGS="make pkg-config git curl xz-utils ca-certificates python3 gettext file bzip2 tar pipx python3-venv ninja-build"
ARG DEBIAN_MINGW_PKGS="gcc-mingw-w64-x86-64 g++-mingw-w64-x86-64 binutils-mingw-w64-x86-64"
ARG WX_COMMON_OPTS="--disable-shared --enable-optimise --disable-debug --disable-debug_info --disable-debug_flag --disable-tests --disable-sys-libs --with-cxx=20 --enable-webview --enable-mediactrl --enable-stc --enable-aui --enable-propgrid --enable-ribbon --enable-richtext --enable-xrc --with-opengl"
ARG WX_MINGW_OPTS="--with-msw --enable-accessibility --with-winhttp"
ARG MINGW_TARGET="x86_64-w64-mingw32"

# Base toolchains (OS + compiler + meson/ninja), no wx-specific env yet

FROM --platform=linux/amd64 almalinux:8 AS base-amd64
ARG WX_VERSION
ARG ALMA_BASE_PKGS
RUN --mount=type=cache,target=/var/cache/dnf,sharing=locked,id=dnf-amd64 \
    dnf install -y ${ALMA_BASE_PKGS} && \
    dnf config-manager --set-enabled powertools && \
    dnf install -y gcc-toolset-14-gcc gcc-toolset-14-gcc-c++ gcc-toolset-14-binutils && \
    dnf update -y ca-certificates openssl
ENV PATH="/opt/rh/gcc-toolset-14/root/usr/bin:${PATH}"
RUN --mount=type=cache,target=/root/.cache/pip,id=pip-amd64 \
    pip3.11 install meson ninja
ENV WX_VERSION=${WX_VERSION}
RUN curl --retry 3 -L https://github.com/wxWidgets/wxWidgets/releases/download/v${WX_VERSION}/wxWidgets-${WX_VERSION}.tar.bz2 | tar xj -C /opt

FROM --platform=linux/arm64 almalinux:8 AS base-arm64
ARG WX_VERSION
ARG ALMA_BASE_PKGS
RUN --mount=type=cache,target=/var/cache/dnf,sharing=locked,id=dnf-arm64 \
    dnf install -y ${ALMA_BASE_PKGS} && \
    dnf config-manager --set-enabled powertools && \
    dnf install -y gcc-toolset-14-gcc gcc-toolset-14-gcc-c++ gcc-toolset-14-binutils && \
    dnf update -y ca-certificates openssl
ENV PATH="/opt/rh/gcc-toolset-14/root/usr/bin:${PATH}"
RUN --mount=type=cache,target=/root/.cache/pip,id=pip-arm64 \
    pip3.11 install meson ninja
ENV WX_VERSION=${WX_VERSION}
RUN curl --retry 3 -L https://github.com/wxWidgets/wxWidgets/releases/download/v${WX_VERSION}/wxWidgets-${WX_VERSION}.tar.bz2 | tar xj -C /opt

# wxWidgets static builds

FROM --platform=linux/amd64 base-amd64 AS wx-linux-amd64
ARG WX_VERSION
ARG ALMA_GUI_PKGS
ARG WX_COMMON_OPTS
ENV LDFLAGS="-static-libgcc -static-libstdc++" \
    CXXFLAGS="-static-libgcc -static-libstdc++" \
    CFLAGS="-static-libgcc"
RUN --mount=type=cache,target=/var/cache/dnf,sharing=locked,id=dnf-amd64 \
    dnf install -y ${ALMA_GUI_PKGS}
WORKDIR /opt/wxWidgets-${WX_VERSION}
RUN mkdir build-static-release && cd build-static-release && \
    ../configure --prefix=/opt/wx-linux-amd64 ${WX_COMMON_OPTS} --with-gtk=3 --with-libcurl > /dev/null && \
    make -j$(nproc) && make install

FROM --platform=linux/arm64 base-arm64 AS wx-linux-arm64
ARG WX_VERSION
ARG ALMA_GUI_PKGS
ARG WX_COMMON_OPTS
ENV LDFLAGS="-static-libgcc -static-libstdc++" \
    CXXFLAGS="-static-libgcc -static-libstdc++" \
    CFLAGS="-static-libgcc"
RUN --mount=type=cache,target=/var/cache/dnf,sharing=locked,id=dnf-arm64 \
    dnf install -y ${ALMA_GUI_PKGS}
WORKDIR /opt/wxWidgets-${WX_VERSION}
RUN mkdir build-static-release && cd build-static-release && \
    ../configure --prefix=/opt/wx-linux-arm64 ${WX_COMMON_OPTS} --with-gtk=3 --with-libcurl > /dev/null && \
    make -j$(nproc) && make install

FROM --platform=linux/amd64 debian:trixie-slim AS wx-mingw64
ARG WX_VERSION
ARG MINGW_TARGET
ARG DEBIAN_BASE_PKGS
ARG DEBIAN_MINGW_PKGS
ARG WX_COMMON_OPTS
ARG WX_MINGW_OPTS
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get update && \
    apt-get install -y --no-install-recommends ${DEBIAN_BASE_PKGS} ${DEBIAN_MINGW_PKGS} ca-certificates
RUN update-alternatives --set ${MINGW_TARGET}-gcc /usr/bin/${MINGW_TARGET}-gcc-posix && \
    update-alternatives --set ${MINGW_TARGET}-g++ /usr/bin/${MINGW_TARGET}-g++-posix
ENV PIPX_HOME=/opt/pipx
ENV PIPX_BIN_DIR=/usr/local/bin
ENV PATH="${PIPX_BIN_DIR}:${PATH}"
RUN --mount=type=cache,target=/root/.cache/pip,id=pip-win64 \
    pipx install meson
ENV WX_VERSION=${WX_VERSION}
ENV LDFLAGS="-static -static-libgcc -static-libstdc++" \
    CXXFLAGS="-static-libgcc -static-libstdc++"
RUN curl --retry 3 -L https://github.com/wxWidgets/wxWidgets/releases/download/v${WX_VERSION}/wxWidgets-${WX_VERSION}.tar.bz2 | tar xj -C /opt
WORKDIR /opt/wxWidgets-${WX_VERSION}
RUN mkdir build-static-release && cd build-static-release && \
    ../configure --prefix=/opt/wx-win64 --host=${MINGW_TARGET} ${WX_COMMON_OPTS} ${WX_MINGW_OPTS} > /dev/null && \
    make -j$(nproc) && make install

# Packaging tools layered on top of each wx build

FROM --platform=linux/amd64 wx-linux-amd64 AS tools-linux-amd64
RUN curl --retry 3 -L -o /usr/local/bin/linuxdeploy https://github.com/linuxdeploy/linuxdeploy/releases/download/continuous/linuxdeploy-x86_64.AppImage && \
    curl --retry 3 -L -o /usr/local/bin/linuxdeploy-plugin-appimage https://github.com/linuxdeploy/linuxdeploy-plugin-appimage/releases/download/continuous/linuxdeploy-plugin-appimage-x86_64.AppImage && \
    curl --retry 3 -L -o /usr/local/bin/linuxdeploy-plugin-gtk https://raw.githubusercontent.com/linuxdeploy/linuxdeploy-plugin-gtk/master/linuxdeploy-plugin-gtk.sh && \
    chmod +x /usr/local/bin/linuxdeploy /usr/local/bin/linuxdeploy-plugin-appimage /usr/local/bin/linuxdeploy-plugin-gtk
ENV APPIMAGE_EXTRACT_AND_RUN=1
ENV PATH="/opt/wx-linux-amd64/bin:${PATH}"

FROM --platform=linux/arm64 wx-linux-arm64 AS tools-linux-arm64
RUN curl --retry 3 -L -o /usr/local/bin/linuxdeploy https://github.com/linuxdeploy/linuxdeploy/releases/download/continuous/linuxdeploy-aarch64.AppImage && \
    curl --retry 3 -L -o /usr/local/bin/linuxdeploy-plugin-appimage https://github.com/linuxdeploy/linuxdeploy-plugin-appimage/releases/download/continuous/linuxdeploy-plugin-appimage-aarch64.AppImage && \
    curl --retry 3 -L -o /usr/local/bin/linuxdeploy-plugin-gtk https://raw.githubusercontent.com/linuxdeploy/linuxdeploy-plugin-gtk/master/linuxdeploy-plugin-gtk.sh && \
    chmod +x /usr/local/bin/linuxdeploy /usr/local/bin/linuxdeploy-plugin-appimage /usr/local/bin/linuxdeploy-plugin-gtk
ENV APPIMAGE_EXTRACT_AND_RUN=1
ENV PATH="/opt/wx-linux-arm64/bin:${PATH}"

FROM --platform=linux/amd64 wx-mingw64 AS tools-win64
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get update && \
    apt-get install -y --no-install-recommends wine64 nsis
ENV PATH="/opt/wx-win64/bin:${PATH}"

# Project build per target

FROM --platform=linux/amd64 tools-linux-amd64 AS build-linux-amd64
COPY . /src
WORKDIR /src
RUN meson setup build --wipe && ninja -C build && ninja -C build package && mkdir -p /out/linux-amd64 && cp -r build/packages/. /out/linux-amd64/

FROM --platform=linux/arm64 tools-linux-arm64 AS build-linux-arm64
COPY . /src
WORKDIR /src
RUN meson setup build --wipe && ninja -C build && ninja -C build package && mkdir -p /out/linux-arm64 && cp -r build/packages/. /out/linux-arm64/

FROM --platform=linux/amd64 tools-win64 AS build-win64
COPY . /src
WORKDIR /src
RUN meson setup build --wipe --cross-file toolchains/windows-mingw64-static-cross.txt && ninja -C build && ninja -C build package && mkdir -p /out/win64 && cp -r build/packages/. /out/win64/

FROM scratch AS export
COPY --from=build-linux-amd64 /out/linux-amd64 /
COPY --from=build-linux-arm64 /out/linux-arm64 /
COPY --from=build-win64 /out/win64 /
