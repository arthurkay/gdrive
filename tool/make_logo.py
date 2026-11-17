"""Draws the GDrive logo and writes every icon size the three platforms need.

Run from the project root:  python3 tool/make_logo.py
"""
import os
from PIL import Image, ImageDraw

S = 4  # supersampling factor
N = 1024 * S


def px(v):
    return int(v * S)


def gradient(size, top_left, bottom_right):
    """Diagonal two-colour gradient."""
    ramp = Image.new("RGB", (256, 1))
    for i in range(256):
        t = i / 255
        ramp.putpixel((i, 0), tuple(
            round(a + (b - a) * t) for a, b in zip(top_left, bottom_right)))
    # Stretch the ramp, rotate 45 degrees and crop the centre square.
    big = ramp.resize((size * 2, size * 2)).rotate(-45, resample=Image.BICUBIC)
    off = size // 2
    return big.crop((off, off, off + size, off + size))


def logo():
    # Rounded-square tile with a blue-to-teal gradient.
    tile = gradient(N, (37, 99, 235), (13, 180, 170)).convert("RGBA")
    mask = Image.new("L", (N, N), 0)
    pad = px(56)
    ImageDraw.Draw(mask).rounded_rectangle(
        (pad, pad, N - pad, N - pad), radius=px(210), fill=255)
    tile.putalpha(mask)

    d = ImageDraw.Draw(tile)
    white = (255, 255, 255, 255)
    # Cloud: three circles on a rounded base.
    d.rounded_rectangle((px(236), px(500), px(788), px(708)), px(104), fill=white)
    for cx, cy, r in ((396, 520, 136), (560, 446, 178), (694, 548, 116)):
        d.ellipse((px(cx - r), px(cy - r), px(cx + r), px(cy + r)), fill=white)

    # Two arrows inside the cloud: up (to Drive) and down (to this computer).
    blue, teal = (37, 99, 235, 255), (13, 160, 152, 255)
    w = px(40)

    def arrow(x, tail, tip, colour):
        direction = 1 if tip > tail else -1
        head = px(62)
        d.line((px(x), px(tail), px(x), px(tip) - direction * head // 2),
               fill=colour, width=w)
        d.ellipse((px(x) - w // 2, px(tail) - w // 2,
                   px(x) + w // 2, px(tail) + w // 2), fill=colour)
        d.polygon([(px(x), px(tip)),
                   (px(x) - head, px(tip) - direction * head),
                   (px(x) + head, px(tip) - direction * head)], fill=colour)

    arrow(456, 650, 452, blue)
    arrow(588, 470, 668, teal)
    return tile.resize((1024, 1024), Image.LANCZOS)


def main():
    image = logo()
    image.save("assets/logo.png")
    image.resize((256, 256), Image.LANCZOS).save("assets/logo_256.png")

    mac = "macos/Runner/Assets.xcassets/AppIcon.appiconset"
    for size in (16, 32, 64, 128, 256, 512, 1024):
        image.resize((size, size), Image.LANCZOS).save(
            os.path.join(mac, f"app_icon_{size}.png"))

    image.save("windows/runner/resources/app_icon.ico",
               sizes=[(s, s) for s in (16, 24, 32, 48, 64, 128, 256)])
    print("wrote logo assets")


if __name__ == "__main__":
    main()
