#!/usr/bin/env python3
"""Генератор иконки приложения: солнце + облако на градиенте неба.

Запуск: python3 gen_icon.py
Создаёт icon.png (легаси, full-bleed) и icon_foreground.png (передний план
adaptive-иконки, арт в безопасной зоне) рядом со скриптом.
"""

from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

SS = 4  # суперсэмплинг для гладких краёв
SIZE = 1024


def lerp(a, b, t):
    return tuple(round(a[i] + (b[i] - a[i]) * t) for i in range(3))


def render_art(size):
    """Солнце + облако на прозрачном фоне, сторона = size."""
    s = size * SS
    img = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)

    # ── Солнце с лучами ──────────────────────────────────────────────
    cx, cy = 0.60 * s, 0.38 * s
    r = 0.150 * s

    for i in range(8):  # лучи: скруглённые прямоугольники по кругу
        angle = i * 45
        ray = Image.new("RGBA", (s, s), (0, 0, 0, 0))
        rd = ImageDraw.Draw(ray)
        rd.rounded_rectangle(
            [cx - 0.035 * s, cy - r * 1.62, cx + 0.035 * s, cy - r * 1.22],
            radius=0.035 * s,
            fill=(255, 202, 84, 255),
        )
        img = Image.alpha_composite(img, ray.rotate(angle, center=(cx, cy)))

    d = ImageDraw.Draw(img)
    d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=(255, 213, 79, 255))
    # блик на диске
    d.ellipse(
        [cx - r * 0.62, cy - r * 0.70, cx + r * 0.18, cy + r * 0.10],
        fill=(255, 228, 138, 255),
    )

    # ── Облако ───────────────────────────────────────────────────────
    def blob(x, y, rad):
        d.ellipse([x - rad, y - rad, x + rad, y + rad], fill=(255, 255, 255, 255))

    body_top, body_bot = 0.60 * s, 0.72 * s
    d.rounded_rectangle(
        [0.20 * s, body_top, 0.66 * s, body_bot],
        radius=(body_bot - body_top) / 2,
        fill=(255, 255, 255, 255),
    )
    blob(0.30 * s, 0.575 * s, 0.095 * s)
    blob(0.44 * s, 0.535 * s, 0.115 * s)
    blob(0.57 * s, 0.585 * s, 0.088 * s)

    # мягкая тень под облаком
    shadow = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    sd = ImageDraw.Draw(shadow)
    sd.ellipse(
        [0.22 * s, 0.685 * s, 0.64 * s, 0.76 * s],
        fill=(20, 40, 70, 70),
    )
    shadow = shadow.filter(ImageFilter.GaussianBlur(0.035 * s))
    img = Image.alpha_composite(shadow, img)

    # облако перекрывает низ солнца — перерисуем его поверх бликующего слоя
    d = ImageDraw.Draw(img)
    d.rounded_rectangle(
        [0.20 * s, body_top, 0.66 * s, body_bot],
        radius=(body_bot - body_top) / 2,
        fill=(255, 255, 255, 255),
    )
    blob(0.30 * s, 0.575 * s, 0.095 * s)
    blob(0.44 * s, 0.535 * s, 0.115 * s)
    blob(0.57 * s, 0.585 * s, 0.088 * s)

    return img.resize((size, size), Image.LANCZOS)


def gradient_bg(size, top, bottom):
    img = Image.new("RGB", (size, size))
    d = ImageDraw.Draw(img)
    for y in range(size):
        d.line([(0, y), (size, y)], fill=lerp(top, bottom, y / size))
    return img.convert("RGBA")


def paste_center(base, art, scale, dy=0.0):
    w = int(base.width * scale)
    a = art.resize((w, w), Image.LANCZOS)
    x = (base.width - w) // 2
    y = int((base.height - w) / 2 + dy * base.height)
    base.alpha_composite(a, (x, y))


def main():
    out = Path(__file__).parent
    art = render_art(SIZE)

    # Легаси-иконка: полный градиент неба + арт.
    legacy = gradient_bg(SIZE, (43, 91, 143), (24, 48, 82))
    paste_center(legacy, art, 0.86, dy=0.01)
    legacy.save(out / "icon.png")

    # Передний план adaptive: арт в безопасной зоне (~66%), фон задаёт цвет.
    fg = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    paste_center(fg, art, 0.62, dy=0.005)
    fg.save(out / "icon_foreground.png")

    print("OK: icon.png, icon_foreground.png")


if __name__ == "__main__":
    main()
