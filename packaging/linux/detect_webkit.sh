#!/usr/bin/env bash

detect_webkit_version() {
    local cache

    PATH="$PATH:/sbin:/usr/sbin"

    if ! command -v ldconfig >/dev/null 2>&1; then
        return 1
    fi

    cache="$(ldconfig -p 2>/dev/null)"

    if grep -q 'libwebkit2gtk-4\.1\.so' <<<"$cache"; then
        echo "4.1"
        return 0
    fi
    if grep -q 'libwebkit2gtk-4\.0\.so' <<<"$cache"; then
        echo "4.0"
        return 0
    fi
    return 1
}
