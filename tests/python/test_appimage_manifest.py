"""Source lookup must cover distro-private libraries without mixing architectures."""
import importlib.util
from pathlib import Path
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location('manifest', ROOT / 'scripts/appimage-manifest.py')
manifest = importlib.util.module_from_spec(spec)
spec.loader.exec_module(manifest)


def elf(machine=62, bits=2):
    header = bytearray(20)
    header[:6] = b'\x7fELF' + bytes([bits, 1])
    header[18:20] = machine.to_bytes(2, 'little')
    return bytes(header)


class ManifestTests(unittest.TestCase):
    def test_finds_private_multiarch_library(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            private = root / 'x86_64-linux-gnu/pulseaudio/libpulsecommon-16.1.so'
            private.parent.mkdir(parents=True)
            private.write_bytes(elf())
            index = manifest.library_index([root, root])
            self.assertEqual(index[private.name], [private])
            self.assertEqual(manifest.matching_elf(index[private.name], elf()), private)

    def test_rejects_wrong_architecture_and_non_elf_files(self):
        with tempfile.TemporaryDirectory() as folder:
            paths = [Path(folder) / name for name in ('arm', 'x86', 'script', 'x64')]
            for path, data in zip(paths, (elf(183), elf(3, 1), b'not a library', elf())):
                path.write_bytes(data)
            self.assertEqual(manifest.matching_elf(paths, elf()), paths[-1])
            self.assertIsNone(manifest.matching_elf(paths[:-1], elf()))


if __name__ == '__main__':
    unittest.main()
