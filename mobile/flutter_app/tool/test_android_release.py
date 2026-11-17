"""Exercise signing-secret handling and the release artifact compatibility gate."""

import base64
from pathlib import Path
import stat
import struct
import tempfile
import unittest
import zipfile

from prepare_android_signing import prepare
from verify_android_release import ABIS, verify_archive, verify_elf


def elf(alignment=16384):
    data = bytearray(120)
    data[:6] = b"\x7fELF\x02\x01"
    struct.pack_into("<Q", data, 32, 64)
    struct.pack_into("<HH", data, 54, 56, 1)
    struct.pack_into("<IIQQQQQQ", data, 64, 1, 0, 0, 0, 0, 0, 0, alignment)
    return data


class ReleaseTest(unittest.TestCase):
    def test_secret_file_permissions_and_environment(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory)
            environment = {
                "SANQI_ANDROID_KEYSTORE_BASE64": base64.b64encode(b"fake-key").decode(),
                "SANQI_ANDROID_KEYSTORE_PATH": str(path / "upload.jks"),
                "SANQI_ANDROID_STORE_PASSWORD": "store password with spaces=$",
                "SANQI_ANDROID_KEY_ALIAS": "upload",
                "SANQI_ANDROID_KEY_PASSWORD": "key password with spaces=$",
                "GITHUB_ENV": str(path / "env"),
            }
            for bad in ({"SANQI_ANDROID_KEY_ALIAS": ""},
                        {"SANQI_ANDROID_KEY_PASSWORD": "bad\ninjected=value"},
                        {"SANQI_ANDROID_KEYSTORE_BASE64": "not-base64!"}):
                with self.assertRaises(ValueError):
                    prepare({**environment, **bad})
                self.assertFalse((path / "upload.jks").exists())
            prepare(environment)
            self.assertEqual((path / "upload.jks").read_bytes(), b"fake-key")
            self.assertEqual(stat.S_IMODE((path / "upload.jks").stat().st_mode), 0o600)
            self.assertIn("SANQI_ANDROID_STORE_PASSWORD=store password with spaces=$\n",
                          (path / "env").read_text())
            with self.assertRaises(FileExistsError):
                prepare(environment)

    def test_elf_alignment(self):
        verify_elf(elf(), "good.so")
        with self.assertRaises(ValueError):
            verify_elf(elf(4096), "bad.so")
        with self.assertRaises(ValueError):
            verify_elf(b"not an ELF", "bad.so")

    def test_bundle_and_apk_packaging(self):
        with tempfile.TemporaryDirectory() as directory:
            for prefix in ("", "base/"):
                path = Path(directory) / "archive.zip"
                for missing in (False, True):
                    with zipfile.ZipFile(path, "w") as archive:
                        for abi in ABIS:
                            for library in ("libsanqi_mobile.so", "libflutter.so", "libapp.so"):
                                if missing and abi == "arm64-v8a" and library == "libsanqi_mobile.so":
                                    continue
                                archive.writestr(f"{prefix}lib/{abi}/{library}", elf())
                    if missing:
                        with self.assertRaises(ValueError):
                            verify_archive(path, prefix)
                    else:
                        verify_archive(path, prefix)


if __name__ == "__main__":
    unittest.main()
