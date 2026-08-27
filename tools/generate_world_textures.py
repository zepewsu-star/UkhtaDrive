from pathlib import Path
import math, random, struct, zlib

OUT = Path('data/visual')
OUT.mkdir(parents=True, exist_ok=True)


def png_rgb(path, w, h, pixel):
    raw = bytearray()
    for y in range(h):
        raw.append(0)
        for x in range(w):
            r, g, b = pixel(x, y)
            raw.extend((max(0,min(255,int(r))), max(0,min(255,int(g))), max(0,min(255,int(b)))))
    def chunk(tag, data):
        return struct.pack('>I', len(data)) + tag + data + struct.pack('>I', zlib.crc32(tag + data) & 0xffffffff)
    data = b'\x89PNG\r\n\x1a\n'
    data += chunk(b'IHDR', struct.pack('>IIBBBBB', w, h, 8, 2, 0, 0, 0))
    data += chunk(b'IDAT', zlib.compress(bytes(raw), 9))
    data += chunk(b'IEND', b'')
    path.write_bytes(data)


def noise(x, y, seed=0):
    n = (x * 374761393 + y * 668265263 + seed * 69069) & 0xffffffff
    n = (n ^ (n >> 13)) * 1274126177 & 0xffffffff
    return ((n ^ (n >> 16)) & 255) / 255.0


def road_pixel(x, y):
    n = noise(x, y, 7)
    v = 55 + n * 25
    # pale compacted snow / salt streaks
    if ((x + 2*y) % 71) < 5 or ((2*x-y) % 97) < 4:
        v += 25
    return v * 0.95, v, v * 1.03


def snow_pixel(x, y):
    n = noise(x, y, 13)
    wave = 6 * math.sin(x * 0.10) + 4 * math.sin(y * 0.07)
    v = 205 + n * 32 + wave
    return v * 0.96, v * 0.985, min(255, v * 1.02)


def facade_pixel(variant):
    bases = [(150,145,138),(128,139,146),(161,148,132)]
    br, bg, bb = bases[variant]
    def p(x, y):
        # mortar / panel seams
        nx, ny = x % 64, y % 48
        n = (noise(x, y, 31 + variant) - .5) * 18
        r,g,b = br+n,bg+n,bb+n
        if nx < 2 or ny < 2:
            r,g,b = r-25,g-25,b-24
        # windows, with occasional warm apartment light
        wx, wy = x % 64, y % 48
        if 13 <= wx <= 44 and 11 <= wy <= 34:
            cell = (x//64)*17 + (y//48)*11 + variant
            if cell % 7 == 0:
                return (230,174,95)
            return (38,48,58)
        return r,g,b
    return p


def flat_normal(x, y):
    # small deterministic variation around +Z normal
    dx = int((noise(x, y, 61)-.5)*12)
    dy = int((noise(x, y, 79)-.5)*12)
    return 128+dx, 128+dy, 252


png_rgb(OUT/'road_winter.png', 256, 256, road_pixel)
png_rgb(OUT/'road_normal.png', 256, 256, flat_normal)
png_rgb(OUT/'snow_winter.png', 256, 256, snow_pixel)
png_rgb(OUT/'snow_normal.png', 256, 256, flat_normal)
for i in range(3):
    png_rgb(OUT/f'facade_{i+1}.png', 256, 256, facade_pixel(i))
    png_rgb(OUT/f'facade_{i+1}_normal.png', 256, 256, flat_normal)

print('generated world PBR textures in', OUT)
