import struct, zlib, math

def create_png(width, height, pixels):
    def png_chunk(chunk_type, data):
        chunk_data = chunk_type + data
        crc = zlib.crc32(chunk_data) & 0xffffffff
        return struct.pack('>I', len(data)) + chunk_data + struct.pack('>I', crc)
    ihdr_data = struct.pack('>IIBBBBB', width, height, 8, 2, 0, 0, 0)
    raw_data = b''
    for y in range(height):
        raw_data += b'\x00'
        for x in range(width):
            raw_data += bytes(pixels[y][x])
    return b'\x89PNG\r\n\x1a\n' + png_chunk(b'IHDR', ihdr_data) + png_chunk(b'IDAT', zlib.compress(raw_data, 9)) + png_chunk(b'IEND', b'')

size = 1024
cx, cy = size//2, size//2
pixels = [[[0,0,0] for _ in range(size)] for _ in range(size)]

for y in range(size):
    for x in range(size):
        pixels[y][x] = [98, 0, 234]

for i in range(-500, 500, 60):
    for t in range(size):
        x, y = t, t + i
        if 0 <= y < size:
            for w in range(3):
                if 0 <= y+w < size:
                    pixels[y+w][x] = [
                        min(255, pixels[y+w][x][0] + 30),
                        min(255, pixels[y+w][x][1] + 15),
                        min(255, pixels[y+w][x][2] + 30)
                    ]

def draw_hex(cx, cy, radius, thickness, color):
    for y in range(size):
        for x in range(size):
            dx, dy = x-cx, y-cy
            angle = math.atan2(dy, dx)
            snap = round(angle/(math.pi/3))*(math.pi/3)
            dist = math.sqrt(dx*dx+dy*dy)
            hex_r = radius*math.cos(math.pi/6)/max(0.001, math.cos(angle-snap))
            if abs(dist-hex_r) < thickness:
                pixels[y][x] = color

draw_hex(cx, cy, 420, 18, [255,255,255])
draw_hex(cx, cy, 320, 14, [210,160,255])
draw_hex(cx, cy, 220, 10, [255,255,255])
draw_hex(cx, cy, 120, 8,  [210,160,255])

for y in range(size):
    for x in range(size):
        dx, dy = abs(x-cx), abs(y-cy)
        if dx+dy < 80:
            b = 1-(dx+dy)/80
            pixels[y][x] = [
                min(255, int(pixels[y][x][0]*(1-b)+255*b)),
                min(255, int(pixels[y][x][1]*(1-b)+200*b)),
                min(255, int(pixels[y][x][2]*(1-b)+255*b))
            ]

import os
path = os.path.expanduser('~/Desktop/Topher/practice_pilot/assets/icon/')
with open(path+'icon.png','wb') as f:
    f.write(create_png(size, size, pixels))
with open(path+'icon_foreground.png','wb') as f:
    f.write(create_png(size, size, pixels))
print('Done!')