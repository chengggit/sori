#!/usr/bin/env python3
"""Record a native bundle's build baseline and copy installed RPM license notices."""
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import sysconfig

appdir = Path(sys.argv[1]).resolve()
project = Path(__file__).resolve().parent.parent
qmake = os.environ.get("QMAKE", "qmake6")
qt = subprocess.check_output([qmake, "-query", "QT_VERSION"], text=True).strip()
libdir = Path(subprocess.check_output([qmake, "-query", "QT_INSTALL_LIBS"], text=True).strip())
qtarch = Path(subprocess.check_output([qmake, "-query", "QT_INSTALL_ARCHDATA"], text=True).strip())
libexec = Path(subprocess.check_output([qmake, "-query", "QT_INSTALL_LIBEXECS"], text=True).strip())
libraries = []
original_paths = []
for path in (appdir / "usr").rglob("*"):
    if not path.is_file() or path.is_symlink():
        continue
    with path.open("rb") as source:
        if source.read(4) != b"\x7fELF":
            continue
    relative = path.relative_to(appdir / "usr")
    candidates = [Path("/usr") / relative, libdir / path.name]
    multiarch = sysconfig.get_config_var("MULTIARCH")
    if multiarch:
        candidates += [Path("/usr/lib") / multiarch / path.name, Path("/lib") / multiarch / path.name]
    if relative.parts[0] in ("qml", "plugins"):
        candidates.insert(0, qtarch / relative)
    if relative.parts[0] == "libexec":
        candidates.insert(0, libexec / path.name)
    if str(relative) == "bin/sori":
        candidates.insert(0, project / "build/sori")
    if str(relative).startswith("bin/helpers/"):
        candidates.insert(0, project / "build" / Path(*relative.parts[1:]))
    if str(relative) == "bin/kiwi/lib/libkiwi.so":
        candidates.insert(0, project / "resources/kiwi/lib/libkiwi.so")
    original = next((candidate for candidate in candidates if candidate.is_file()), None)
    if original is None:
        original = next((candidate for candidate in libdir.rglob(path.name) if candidate.is_file()), None)
    if original is None:
        raise SystemExit(f"Cannot locate original ELF for {relative}")
    # The pinned deployment tool corrupts RELR relocations in some Fedora Qt
    # plugins while rewriting ELF files. Keep original binaries byte-for-byte;
    # AppRun supplies private loader paths to the app and all its subprocesses.
    shutil.copy2(original, path)
    original_paths.append(original)
    libraries.append(path)

versions = subprocess.check_output(
    ["readelf", "--version-info", str(appdir / "usr/bin/sori")], text=True
)
glibc = sorted(set(re.findall(r"GLIBC_(\d+\.\d+)", versions)), key=lambda v: tuple(map(int, v.split("."))))
runtime_versions = subprocess.check_output(
    ["readelf", "--version-info", *(str(path) for path in libraries)], text=True,
    stderr=subprocess.DEVNULL,
)
runtime_glibc = sorted(set(re.findall(r"GLIBC_(\d+\.\d+)", runtime_versions)),
                      key=lambda v: tuple(map(int, v.split("."))))
metadata = {
    "commit": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=project, text=True).strip(),
    "qt": qt,
    "executable_glibc_minimum": glibc[-1] if glibc else None,
    "bundle_glibc_minimum": runtime_glibc[-1] if runtime_glibc else None,
    "host_os": Path("/etc/os-release").read_text(),
    "note": "Local build baseline only; cross-distribution compatibility requires separate testing.",
    "elf_files": sorted(str(p.relative_to(appdir)) for p in libraries),
}

if shutil.which("rpm"):
    originals = {str(path) for path in original_paths}
    if originals:
        result = subprocess.run(
            ["rpm", "-qf", "--qf", "%{NAME}\t%{VERSION}-%{RELEASE}\t%{LICENSE}\t%{SOURCERPM}\n", *sorted(originals)],
            text=True, capture_output=True, check=False,
        )
        packages = sorted(set(line for line in result.stdout.splitlines() if "\t" in line))
        metadata["rpm_packages"] = packages
        for package in sorted({line.split("\t")[0] for line in packages}):
            files = subprocess.check_output(["rpm", "-ql", package], text=True).splitlines()
            for name in files:
                source = Path(name)
                if name.startswith("/usr/share/licenses/") and source.is_file():
                    target = appdir / source.relative_to("/")
                    target.parent.mkdir(parents=True, exist_ok=True)
                    shutil.copy2(source, target)

(appdir / "usr/share/doc/sori/BUILDINFO.json").write_text(json.dumps(metadata, indent=2) + "\n")
