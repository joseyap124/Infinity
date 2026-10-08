#!/usr/bin/env python3
"""Cek APK sebelum dirilis: library native harus rata 16 KB (syarat HP
Android 15+ dengan halaman memori 16 KB). Keluar dengan kode 1 kalau gagal.

    python3 tool/check_apk.py Infinity-v3.0.apk
"""
import struct
import sys
import zipfile

PAGE = 16384


def check(path):
    bad = []
    with zipfile.ZipFile(path) as z, open(path, 'rb') as raw:
        for info in z.infolist():
            if not info.filename.endswith('.so') or '/arm64-v8a/' not in info.filename:
                continue
            data = z.read(info)
            if data[:4] != b'\x7fELF' or data[4] != 2:
                continue
            phoff = struct.unpack_from('<Q', data, 0x20)[0]
            phentsize, phnum = struct.unpack_from('<HH', data, 0x36)
            aligns = []
            for k in range(phnum):
                off = phoff + k * phentsize
                if struct.unpack_from('<I', data, off)[0] == 1:  # PT_LOAD
                    aligns.append(struct.unpack_from('<Q', data, off + 48)[0])
            raw.seek(info.header_offset)
            head = raw.read(30)
            n, m = struct.unpack_from('<HH', head, 26)
            dataoff = info.header_offset + 30 + n + m
            ok_elf = aligns and min(aligns) >= PAGE
            ok_zip = info.compress_type != 0 or dataoff % PAGE == 0
            status = 'OK' if ok_elf and ok_zip else 'GAGAL'
            print(f'{status} {info.filename} align={min(aligns) if aligns else "?"} zip%16K={dataoff % PAGE}')
            if status != 'OK':
                bad.append(info.filename)
    return bad


if __name__ == '__main__':
    failed = []
    for p in sys.argv[1:]:
        failed += check(p)
    if failed:
        print('Library belum rata 16 KB:', ', '.join(failed))
        sys.exit(1)
    print('Semua library native rata 16 KB.')
