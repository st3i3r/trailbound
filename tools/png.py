#!/usr/bin/env python3
"""Minimal PNG codec for the Trailbound tooling — stdlib only.

Reads 8-bit, non-interlaced RGB (2) and RGBA (6) PNGs — what PixelLab
and Pixelorama emit — and writes 8-bit RGBA. Not a general codec.
"""
import struct, zlib

SIG = b"\x89PNG\r\n\x1a\n"


def _chunks(data):
    if not data.startswith(SIG):
        raise ValueError("not a PNG file")
    pos = len(SIG)
    while pos < len(data):
        ln, typ = struct.unpack(">I4s", data[pos:pos + 8])
        yield typ, data[pos + 8:pos + 8 + ln]
        pos += 12 + ln


def read(path):
    """-> (w, h, rows): rows[y] = bytearray of w*4 RGBA bytes."""
    w = h = depth = ctype = None
    idat = b""
    for typ, body in _chunks(open(path, "rb").read()):
        if typ == b"IHDR":
            w, h, depth, ctype, _, _, interlace = struct.unpack(">IIBBBBB", body)
            if depth != 8 or ctype not in (2, 6) or interlace:
                raise ValueError(
                    f"unsupported PNG (depth={depth} ctype={ctype} "
                    f"interlace={interlace}); open it in Pixelorama")
        elif typ == b"IDAT":
            idat += body
    ch = 4 if ctype == 6 else 3
    raw = zlib.decompress(idat)
    stride, rows, prev = w * ch, [], bytearray(w * ch)
    for y in range(h):
        f = raw[y * (stride + 1)]
        line = bytearray(raw[y * (stride + 1) + 1:(y + 1) * (stride + 1)])
        if f == 1:                                   # Sub
            for i in range(ch, stride):
                line[i] = (line[i] + line[i - ch]) & 0xFF
        elif f == 2:                                 # Up
            for i in range(stride):
                line[i] = (line[i] + prev[i]) & 0xFF
        elif f == 3:                                 # Average
            for i in range(stride):
                a = line[i - ch] if i >= ch else 0
                line[i] = (line[i] + (a + prev[i]) // 2) & 0xFF
        elif f == 4:                                 # Paeth
            for i in range(stride):
                a = line[i - ch] if i >= ch else 0
                b = prev[i]
                c = prev[i - ch] if i >= ch else 0
                p = a + b - c
                pa, pb, pc = abs(p - a), abs(p - b), abs(p - c)
                line[i] = (line[i] + (a if pa <= pb and pa <= pc
                                      else b if pb <= pc else c)) & 0xFF
        elif f != 0:
            raise ValueError(f"bad filter {f}")
        prev = line                                  # raw-layout row for filters
        if ch == 3:                                  # RGB -> RGBA
            rgba = bytearray(w * 4)
            for i in range(w):
                rgba[i * 4:i * 4 + 3] = line[i * 3:i * 3 + 3]
                rgba[i * 4 + 3] = 255
            line = rgba
        rows.append(line)
    return w, h, rows


def write(path, w, h, rows):
    """rows[y] = bytearray of w*4 RGBA bytes, written with filter 0."""
    def chunk(typ, body):
        return (struct.pack(">I", len(body)) + typ + body
                + struct.pack(">I", zlib.crc32(typ + body)))
    raw = b"".join(b"\x00" + bytes(r) for r in rows)
    out = (SIG
           + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0))
           + chunk(b"IDAT", zlib.compress(raw, 9))
           + chunk(b"IEND", b""))
    with open(path, "wb") as f:
        f.write(out)


def bbox_alpha(rows, x0, y0, w, h):
    """Opaque-pixel bounding box inside a region -> (x, y, w, h) or None."""
    x_min, y_min, x_max, y_max = x0 + w, y0 + h, -1, -1
    for y in range(y0, y0 + h):
        row = rows[y]
        for x in range(x0, x0 + w):
            if row[x * 4 + 3]:
                if x < x_min: x_min = x
                if x > x_max: x_max = x
                if y < y_min: y_min = y
                if y > y_max: y_max = y
    if x_max < 0:
        return None
    return x_min - x0, y_min - y0, x_max - x_min + 1, y_max - y_min + 1
