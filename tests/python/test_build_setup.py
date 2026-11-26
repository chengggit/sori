"""Offline regression checks for build-time resource preparation."""
import hashlib
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]


class BuildSetupTests(unittest.TestCase):
    def run_setup(self, script, **options):
        return subprocess.run(
            ['cmake', *[f'-D{k}={v}' for k, v in options.items()],
             '-P', str(ROOT / 'scripts' / script)],
            capture_output=True, text=True, timeout=15,
        )

    def test_package_requires_release_and_caption_helper(self):
        result = self.run_setup('package.cmake', CONFIG='Debug', BUNDLE_HELPER='ON')
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('Packages require Release', result.stderr)
        result = self.run_setup('package.cmake', CONFIG='Release', BUNDLE_HELPER='OFF')
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('SORI_BUNDLE_TRANSCRIPT_HELPER=ON', result.stderr)

    @unittest.skipUnless(__import__('sys').platform.startswith('linux'), 'Linux dispatcher')
    def test_package_passes_selected_directory_and_qt(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            script = root / 'scripts/appimage'
            script.parent.mkdir()
            script.write_text('printf "%s\\n%s" "$SORI_BUILD_DIR" "$QT_ROOT_DIR" > "$SORI_BUILD_DIR/observed"')
            build = root / 'custom build'
            build.mkdir()
            result = self.run_setup('package.cmake', CONFIG='Release', BUNDLE_HELPER='ON',
                                    SOURCE_DIR=root, BUILD_DIR=build,
                                    QMAKE=root / 'qt/bin/qmake')
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual((build / 'observed').read_text().splitlines(),
                             [str(build), str(root / 'qt')])

    def test_missing_external_kiwi_fails_without_downloading(self):
        with tempfile.TemporaryDirectory() as folder:
            result = self.run_setup('prepare-kiwi.cmake', SORI_KIWI_DIR=folder,
                                    SORI_PREPARE_KIWI='OFF', KIWI_LIBRARY='libkiwi.so')
            self.assertNotEqual(result.returncode, 0)
            self.assertIn('Missing Kiwi resource', result.stderr)
            self.assertEqual(list(Path(folder).iterdir()), [])

    def test_complete_external_kiwi_needs_no_marker_or_network(self):
        with tempfile.TemporaryDirectory() as folder:
            for name in ('lib/libkiwi.so', 'models/cong/base/sj.morph',
                         'models/cong/base/cong.mdl'):
                path = Path(folder) / name
                path.parent.mkdir(parents=True, exist_ok=True)
                path.touch()
            result = self.run_setup('prepare-kiwi.cmake', SORI_KIWI_DIR=folder,
                                    SORI_PREPARE_KIWI='OFF', KIWI_LIBRARY='libkiwi.so')
            self.assertEqual(result.returncode, 0, result.stderr)

    def test_python_offline_rejects_missing_or_changed_environment(self):
        with tempfile.TemporaryDirectory() as folder:
            env = Path(folder) / 'python'
            result = self.run_setup('prepare-python.cmake', ENV_DIR=env,
                                    BASE_PYTHON='not-a-python', ALLOW_DOWNLOADS='OFF',
                                    REQUIREMENTS=ROOT / 'scripts/requirements-youtube-build.txt',
                                    RUNTIME_REQUIREMENTS=ROOT / 'scripts/requirements-youtube.txt')
            self.assertNotEqual(result.returncode, 0)
            self.assertIn('Caption environment is not prepared', result.stderr)
            self.assertFalse(env.exists())

    def test_python_cache_reused_offline(self):
        import os
        with tempfile.TemporaryDirectory() as folder:
            env = Path(folder) / 'python'
            python = env / ('Scripts/python.exe' if os.name == 'nt' else 'bin/python')
            python.parent.mkdir(parents=True)
            python.touch()
            requirements = ROOT / 'scripts/requirements-youtube-build.txt'
            runtime = ROOT / 'scripts/requirements-youtube.txt'
            hashes = [hashlib.sha256(p.read_bytes()).hexdigest() for p in (requirements, runtime)]
            marker = env / 'sori-ready.txt'
            marker.write_text(';'.join(['not-a-python', *hashes]))
            before = marker.stat().st_mtime_ns
            result = self.run_setup('prepare-python.cmake', ENV_DIR=env,
                                    BASE_PYTHON='not-a-python', ALLOW_DOWNLOADS='OFF',
                                    REQUIREMENTS=requirements, RUNTIME_REQUIREMENTS=runtime)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(marker.stat().st_mtime_ns, before)
            marker.write_text('outdated')
            result = self.run_setup('prepare-python.cmake', ENV_DIR=env,
                                    BASE_PYTHON='not-a-python', ALLOW_DOWNLOADS='OFF',
                                    REQUIREMENTS=requirements, RUNTIME_REQUIREMENTS=runtime)
            self.assertNotEqual(result.returncode, 0)


if __name__ == '__main__':
    unittest.main()
