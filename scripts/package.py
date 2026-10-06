"""Package previously signed binaries; validate daemon architecture before shipping."""
import argparse
import io
import pathlib
import struct
import tarfile

ROOT = pathlib.Path(__file__).resolve().parent.parent


def slices(data):
    if data[:4] == bytes.fromhex("cafebabe"):
        count = struct.unpack_from(">I", data, 4)[0]
        if count > 8 or len(data) < 8 + 20 * count:
            raise ValueError("invalid FAT header")
        result = []
        for i in range(count):
            _, _, off, size, _ = struct.unpack_from(">IIIII", data, 8 + 20 * i)
            if off + size > len(data):
                raise ValueError("slice outside file")
            result.extend(slices(data[off:off + size]))
        return result
    if data[:4] != bytes.fromhex("cffaedfe") or len(data) < 32:
        raise ValueError("expected 64-bit Mach-O")
    cpu, subtype, kind, commands, total = struct.unpack_from("<IIIII", data, 4)
    if kind != 6 or total > len(data) - 32:
        raise ValueError("invalid dylib")
    at, signed = 32, False
    for _ in range(commands):
        if at + 8 > 32 + total:
            raise ValueError("truncated command")
        cmd, size = struct.unpack_from("<II", data, at)
        if size < 8 or at + size > 32 + total:
            raise ValueError("invalid command size")
        if cmd == 0x1D:
            off, length = struct.unpack_from("<II", data, at + 8)
            signed = length >= 12 and off + length <= len(data) and data[off:off + 4] == bytes.fromhex("fade0cc0")
        at += size
    if not signed:
        raise ValueError("unsigned dylib")
    return [(cpu, subtype)]


def fat(parts):
    offset, records = 16384, []
    for data in parts:
        architectures = slices(data)
        if len(architectures) != 1:
            raise ValueError("fat() takes thin signed slices")
        cpu, subtype = architectures[0]
        records.append((cpu, subtype, offset, len(data), 14))
        offset = (offset + len(data) + 16383) & ~16383
    out = bytearray(offset)
    struct.pack_into(">II", out, 0, 0xCAFEBABE, len(parts))
    for i, (record, data) in enumerate(zip(records, parts)):
        struct.pack_into(">IIIII", out, 8 + 20 * i, *record)
        out[record[2]:record[2] + len(data)] = data
    return bytes(out)


def archive(files):
    out = io.BytesIO()
    with tarfile.open(fileobj=out, mode="w:gz") as tf:
        for name, data, mode in files:
            info = tarfile.TarInfo(name)
            info.size, info.mode, info.uid, info.gid, info.mtime = len(data), mode, 0, 0, 0
            tf.addfile(info, io.BytesIO(data))
    return out.getvalue()


def main():
    parser = argparse.ArgumentParser(__doc__)
    parser.add_argument("--binaries", type=pathlib.Path, required=True)
    parser.add_argument("--output", type=pathlib.Path, required=True)
    args = parser.parse_args()
    data = []
    for name in ("HappVPNPushRoute", "HappAPNsDNS", "HappAPNsScope"):
        binary = (args.binaries / (name + ".dylib")).read_bytes()
        archs = slices(binary)
        if name == "HappAPNsScope" and (0x0100000C, 0x80000002) not in archs:
            raise ValueError("apsd on the tested A12+ iPhone requires arm64e PAC00")
        prefix = "./var/jb/Library/MobileSubstrate/DynamicLibraries/" + name
        data.extend([(prefix + ".dylib", binary, 0o755),
                     (prefix + ".plist", (ROOT / (name + ".plist")).read_bytes(), 0o644)])
    members = [("debian-binary", b"2.0\n"),
               ("control.tar.gz", archive([("./control", (ROOT / "control").read_bytes(), 0o644)])),
               ("data.tar.gz", archive(data))]
    out = bytearray(b"!<arch>\n")
    for name, member in members:
        header = f'{name + "/":<16}{0:<12}{0:<6}{0:<6}{"100644":<8}{len(member):<10}`\n'.encode()
        assert len(header) == 60
        out.extend(header + member)
        if len(member) % 2:
            out.extend(b"\n")
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_bytes(out)
    print(f"Created {args.output} ({len(out)} bytes), signed daemon architecture verified")


if __name__ == "__main__":
    main()
