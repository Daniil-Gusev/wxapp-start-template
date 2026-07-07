import re
import subprocess
import sys
from pathlib import Path

WINDOWS_SYSTEM_DLLS = {
    "kernel32.dll", "user32.dll", "gdi32.dll", "advapi32.dll", "shell32.dll",
    "shlwapi.dll", "ole32.dll", "oleaut32.dll", "comctl32.dll", "comdlg32.dll",
    "winspool.drv", "ws2_32.dll", "version.dll", "wininet.dll", "crypt32.dll",
    "secur32.dll", "imm32.dll", "msimg32.dll", "winmm.dll", "uxtheme.dll",
    "dwmapi.dll", "setupapi.dll", "msvcrt.dll", "ntdll.dll", "rpcrt4.dll",
    "oleacc.dll", "gdiplus.dll", "powrprof.dll", "userenv.dll",
    "kernelbase.dll", "ucrtbase.dll", "msvcp_win.dll", "win32u.dll",
    "shcore.dll", "bcrypt.dll", "iphlpapi.dll", "psapi.dll", "dnsapi.dll",
    "normaliz.dll",
}

def require_tool(tool, kind, hint):
    if not tool:
        sys.exit(f"error: dependency-check tool for kind '{kind}' was not found by meson; {hint}")
    return tool

def _objdump_imports(tool, exe):
    out = subprocess.run([tool, "-p", str(exe)], capture_output=True, text=True, check=True).stdout
    return re.findall(r"DLL Name:\s*(\S+)", out)

def _dumpbin_imports(tool, exe):
    out = subprocess.run([tool, "/dependents", "/nologo", str(exe)], capture_output=True, text=True, check=True).stdout
    deps = []
    in_block = False
    started = False
    for line in out.splitlines():
        if "dependencies:" in line:
            in_block = True
            continue
        if not in_block:
            continue
        stripped = line.strip()
        if not stripped:
            if started:
                break
            continue
        started = True
        deps.append(stripped)
    return deps

def _direct_imports(tool, kind, exe):
    if kind == "objdump":
        return _objdump_imports(tool, exe)
    if kind == "dumpbin":
        return _dumpbin_imports(tool, exe)
    sys.exit(f"error: unsupported dependency-check tool kind '{kind}'")

def _locate_dll(name, search_dirs):
    for d in search_dirs:
        candidate = d / name
        if candidate.exists():
            return candidate
    return None

def windows_unexpected_deps(exe: Path, tool: str, kind: str):
    exe = Path(exe)
    search_dirs = [exe.resolve().parent]
    visited = set()
    unexpected = set()
    unresolved = set()
    queue = [exe]

    while queue:
        current = queue.pop()
        key = current.name.lower()
        if key in visited:
            continue
        visited.add(key)

        for dll_name in _direct_imports(tool, kind, current):
            lname = dll_name.lower()
            if lname in WINDOWS_SYSTEM_DLLS or lname.startswith("api-ms-win-"):
                continue
            unexpected.add(dll_name)
            if lname in visited:
                continue
            located = _locate_dll(dll_name, search_dirs)
            if located:
                queue.append(located)
            else:
                unresolved.add(dll_name)

    return sorted(unexpected, key=str.lower), sorted(unresolved, key=str.lower)

def _linux_ldd_lines(exe: Path, tool: str):
    out = subprocess.run([tool, str(exe)], capture_output=True, text=True, check=True).stdout
    return out.splitlines()

def linux_unexpected_deps(exe: Path, tool: str, wx_lib_names: list[str]) -> list[str]:
    patterns = [f"lib{name}.so" for name in wx_lib_names if name]
    unexpected = []
    for line in _linux_ldd_lines(exe, tool):
        m = re.match(r"^\s*(\S+)\s*=>", line)
        if not m:
            continue
        soname = m.group(1)
        if any(soname.startswith(p) for p in patterns):
            unexpected.append(soname)
    return sorted(set(unexpected), key=str.lower)

def linux_links_lib(exe: Path, tool: str, lib_prefixes: list[str]) -> bool:
    for line in _linux_ldd_lines(exe, tool):
        m = re.match(r"^\s*(\S+)\s*=>", line)
        soname = m.group(1) if m else None
        if soname is None:
            m2 = re.match(r"^\s*(\S+\.so[\d.]*)\s", line)
            soname = m2.group(1) if m2 else None
        if soname and any(soname.startswith(p) for p in lib_prefixes):
            return True
    return False

def report(deps, exe, platform, unresolved=None) -> bool:
    label = f"[dep-check] {exe.name} ({platform})"
    if not deps:
        print(f"{label}: OK, no unexpected runtime dependencies found")
        return True
    print(f"{label}: FAIL, found dependencies that won't be present on a clean machine:", file=sys.stderr)
    for d in deps:
        print(f"  - {d}", file=sys.stderr)
    if unresolved:
        print(f"{label}: the following could not be located on disk...", file=sys.stderr)
        for d in unresolved:
            print(f"  - {d}", file=sys.stderr)
    return False
