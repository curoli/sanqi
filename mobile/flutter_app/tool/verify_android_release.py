"""Check release Rust packaging and 64-bit ELF 16 KB load alignment."""

from pathlib import Path
import struct
import zipfile


ABIS = ("armeabi-v7a", "arm64-v8a", "x86_64")


def verify_elf(data, name):
    if data[:6] != b"\x7fELF\x02\x01":
        raise ValueError(f"Not a little-endian 64-bit ELF: {name}")
    table = struct.unpack_from("<Q", data, 32)[0]
    size, count = struct.unpack_from("<HH", data, 54)
    loads = 0
    for index in range(count):
        kind, _, offset, address, _, _, _, alignment = struct.unpack_from(
            "<IIQQQQQQ", data, table + index * size
        )
        if kind == 1:  # PT_LOAD
            loads += 1
            if alignment < 16384 or (address - offset) % 16384:
                raise ValueError(f"ELF load segment is not 16 KB aligned: {name}")
    if not loads:
        raise ValueError(f"No ELF load segments: {name}")


def verify_archive(path, prefix):
    with zipfile.ZipFile(path) as archive:
        for abi in ABIS:
            for library in ("libsanqi_mobile.so", "libflutter.so", "libapp.so"):
                name = f"{prefix}lib/{abi}/{library}"
                if name not in archive.namelist():
                    raise ValueError(f"Missing {name} in {path}")
        for name in archive.namelist():
            if name.startswith(tuple(f"{prefix}lib/{abi}/" for abi in ABIS[1:])) and name.endswith(".so"):
                verify_elf(archive.read(name), name)
    print(f"Verified native libraries and 16 KB ELF alignment: {path.name}")


if __name__ == "__main__":
    verify_archive(Path("build/app/outputs/bundle/release/app-release.aab"), "base/")
    verify_archive(Path("build/app/outputs/flutter-apk/app-release.apk"), "")
