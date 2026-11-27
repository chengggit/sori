#!/usr/bin/env python3
"""Check the assembled AppDir without reading or modifying the user's library."""
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile

appdir = Path(sys.argv[1]).resolve()
wayland = '--wayland' in sys.argv[2:]
integration = appdir / 'usr/plugins/wayland-graphics-integration-client/libqt-plugin-wayland-egl.so'
if not integration.is_file():
    raise SystemExit(f'Missing bundled Wayland EGL client integration: {integration}')
with tempfile.TemporaryDirectory(prefix="sori-appimage-check-") as directory:
    root = Path(directory)
    empty = root / "empty.env"
    empty.write_text("")
    env = os.environ.copy()
    env.update(
        QT_QPA_PLATFORM="offscreen", QT_QUICK_BACKEND="software",
        SORI_ENV_FILE=str(empty), LD_LIBRARY_PATH=str(appdir / "usr/lib"),
    )
    if wayland:
        env['QT_QPA_PLATFORM'] = 'wayland'
        env['QT_WAYLAND_CLIENT_BUFFER_INTEGRATION'] = 'wayland-egl'
        env.pop('QT_QUICK_BACKEND', None)
    env.pop("SORI_YOUTUBE_API_KEY", None)
    for key in ("XDG_DATA_HOME", "XDG_CONFIG_HOME", "XDG_CACHE_HOME"):
        env[key] = str(root / key.lower())
    subprocess.run([str(appdir / "AppRun"), "--help"], env=env, cwd=root, check=True, timeout=30,
                   stdout=subprocess.DEVNULL)
    for name in ("ffmpeg", "ffprobe"):
        subprocess.run([str(appdir / "usr/bin" / name), "-version"], env=env, cwd=root,
                       check=True, timeout=30, stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)
    helper = appdir / "usr/bin/helpers/sori-youtube-transcript/sori-youtube-transcript"
    result = subprocess.check_output([str(helper), "--self-test"], env=env, cwd=root, timeout=30)
    if not json.loads(result).get("ready"):
        raise SystemExit("Bundled transcript helper is not ready")
    linked = subprocess.check_output(["ldd", str(appdir / "usr/bin/sori")], env=env, text=True)
    plugin_linked = subprocess.check_output(['ldd', str(integration)], env=env, text=True)
    if 'not found' in plugin_linked:
        raise SystemExit(plugin_linked)
    if "not found" in linked:
        raise SystemExit(linked)
    for line in linked.splitlines():
        if "libQt6" in line or "libmpv.so" in line:
            resolved = Path(line.split("=>", 1)[1].strip().split()[0])
            if not resolved.is_relative_to(appdir):
                raise SystemExit(f"Runtime escaped bundle: {line}")
    for resource in ("lib/libkiwi.so", "models/cong/base/sj.morph", "models/cong/base/cong.mdl"):
        if not (appdir / "usr/bin/kiwi" / resource).is_file():
            raise SystemExit(f"Missing bundled Kiwi resource: {resource}")
    process = subprocess.Popen([str(appdir / "AppRun")], env=env, cwd=root,
                               stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
    try:
        output, _ = process.communicate(timeout=6)
        raise SystemExit(f"App exited during startup ({process.returncode}):\n{output}")
    except subprocess.TimeoutExpired:
        process.terminate()
        output, _ = process.communicate(timeout=10)
        if "QQmlApplicationEngine failed" in output:
            raise SystemExit(output)
    print(f"AppDir checks passed: private Qt/mpv, Wayland EGL plugin, media tools, helper, Kiwi resources, isolated {'Wayland/OpenGL' if wayland else 'offscreen'} startup.")
