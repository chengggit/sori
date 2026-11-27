"""Exercise draft release handling offline with a fake GitHub CLI."""
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]


@unittest.skipUnless(sys.platform.startswith('linux'), 'Release job runs on Linux')
class DraftReleaseTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name) / 'project with spaces'
        self.script = self.root / 'scripts/ci/draft-release.sh'
        self.script.parent.mkdir(parents=True)
        shutil.copyfile(ROOT / 'scripts/ci/draft-release.sh', self.script)
        self.notes = self.root / '.github/releases/v1.0.0.md'
        self.notes.parent.mkdir(parents=True)
        self.notes.write_text('# Changes\n\nHandwritten release notes.\n')
        self.assets = self.root / 'dist'
        self.assets.mkdir()
        for name in ['Sori.AppImage', 'Sori-setup-unsigned.exe', 'Sori.dmg']:
            package = self.assets / name
            package.write_bytes(b'package fixture')
            digest = hashlib.sha256(package.read_bytes()).hexdigest()
            newline = '\r\n' if name.endswith('.exe') else '\n'
            package.with_name(name + '.sha256').write_bytes(f'{digest}  {name}{newline}'.encode())
        self.log = self.root / 'calls.jsonl'
        bin_dir = self.root / 'bin'
        bin_dir.mkdir()
        fake = bin_dir / 'gh'
        fake.write_text(f'#!{sys.executable}\n' + '''import json, os, sys
from pathlib import Path
args = sys.argv[1:]
with open(os.environ['SORI_RELEASE_TEST_LOG'], 'a') as log:
    log.write(json.dumps(args) + '\\n')
if args[:2] == ['release', 'view']:
    state = os.environ['SORI_RELEASE_TEST_STATE']
    if state == 'missing':
        sys.exit(1)
    print('true' if state == 'draft' else 'false')
if '--notes-file' in args:
    assert Path(args[args.index('--notes-file') + 1]).read_text().startswith('# Changes')
''')
        fake.chmod(0o755)
        self.env = dict(os.environ, PATH=str(bin_dir) + os.pathsep + os.environ['PATH'],
                        GH_REPO='example/sori', RELEASE_TAG='v1.0.0',
                        SORI_RELEASE_TEST_LOG=str(self.log), SORI_RELEASE_TEST_STATE='missing')

    def run_release(self, state='missing'):
        self.env['SORI_RELEASE_TEST_STATE'] = state
        result = subprocess.run(['bash', str(self.script), str(self.assets)],
                                env=self.env, capture_output=True, text=True, timeout=10)
        calls = [json.loads(line) for line in self.log.read_text().splitlines()] if self.log.exists() else []
        return result, calls

    def test_creates_draft_with_handwritten_notes_and_six_assets(self):
        result, calls = self.run_release()
        self.assertEqual(result.returncode, 0, result.stderr)
        create = calls[1]
        self.assertEqual(create[:3], ['release', 'create', 'v1.0.0'])
        self.assertIn('--draft', create)
        self.assertIn('--verify-tag', create)
        self.assertEqual(create[create.index('--notes-file') + 1], str(self.notes))
        upload = calls[2]
        self.assertEqual(upload[:3], ['release', 'upload', 'v1.0.0'])
        self.assertEqual(len(upload[3:-1]), 6)
        self.assertEqual(upload[-1], '--clobber')

    def test_rerun_refreshes_draft_notes_and_assets(self):
        result, calls = self.run_release('draft')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual([call[1] for call in calls], ['view', 'edit', 'upload'])
        self.assertIn('--notes-file', calls[1])

    def test_published_release_is_not_modified(self):
        result, calls = self.run_release('published')
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('Refusing to modify published release', result.stderr)
        self.assertEqual(len(calls), 1)

    def test_missing_notes_prevents_release(self):
        self.notes.unlink()
        result, calls = self.run_release()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('.github/releases/v1.0.0.md', result.stderr)
        self.assertEqual(calls, [])

    def test_missing_platform_prevents_release(self):
        (self.assets / 'Sori.dmg').unlink()
        result, calls = self.run_release()
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(calls, [])

    def test_corrupt_package_prevents_release(self):
        (self.assets / 'Sori.dmg').write_bytes(b'corrupt')
        result, calls = self.run_release()
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(calls, [])
