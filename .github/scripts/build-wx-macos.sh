#!/usr/bin/env bash
set -euo pipefail

: "${WX_VERSION:?WX_VERSION not set}"
: "${WITH_WEBVIEW:?WITH_WEBVIEW not set}"

mkdir "$HOME/wx"
curl --retry 3 -L "https://github.com/wxWidgets/wxWidgets/releases/download/v${WX_VERSION}/wxWidgets-${WX_VERSION}.tar.bz2" \
  | tar xj -C "$RUNNER_TEMP"
cd "$RUNNER_TEMP/wxWidgets-${WX_VERSION}"
mkdir build-static-release && cd build-static-release

webview_opt=""
[ "$WITH_WEBVIEW" = "true" ] && webview_opt="--enable-webview"

../configure \
  --prefix="$HOME/wx" \
  --disable-shared \
  --enable-optimise \
  --disable-debug \
  --disable-debug_info \
  --disable-debug_flag \
  --disable-tests \
  --disable-sys-libs \
  --with-osx_cocoa \
  --with-macosx-version-min=10.10 \
  --enable-universal_binary=arm64,x86_64 \
  --with-cxx=20 \
  --enable-mediactrl \
  $webview_opt \
  --enable-stc \
  --enable-aui \
  --enable-propgrid \
  --enable-ribbon \
  --enable-richtext \
  --enable-xrc \
  --with-opengl > /dev/null

make -j"$(sysctl -n hw.ncpu)" > /dev/null
make install > /dev/null
