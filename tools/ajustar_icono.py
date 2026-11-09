from pathlib import Path

from PIL import Image, ImageStat


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "assets" / "icon" / "icon.png"
FOREGROUND = ROOT / "assets" / "icon" / "icon_foreground.png"
CANVAS_SIZE = 1024
SCALE = 0.58


def main():
    with Image.open(SOURCE) as image:
        image = image.convert("RGBA")
        resized_size = (round(CANVAS_SIZE * SCALE),) * 2
        image = image.resize(resized_size, Image.Resampling.LANCZOS)

        canvas = Image.new("RGBA", (CANVAS_SIZE, CANVAS_SIZE), (0, 0, 0, 0))
        offset = ((CANVAS_SIZE - resized_size[0]) // 2,) * 2
        canvas.alpha_composite(image, offset)
        canvas.save(FOREGROUND, format="PNG")

    with Image.open(SOURCE) as image:
        corner = image.convert("RGB").crop((0, 0, 20, 20))
        average = tuple(round(value) for value in ImageStat.Stat(corner).mean)

    color_hex = "#{:02X}{:02X}{:02X}".format(*average)
    print(f"Icono adaptativo generado: {FOREGROUND}")
    print(f"Color promedio de la esquina superior izquierda: {color_hex}")


if __name__ == "__main__":
    main()
