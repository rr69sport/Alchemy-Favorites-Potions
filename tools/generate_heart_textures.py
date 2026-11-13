"""Genera las texturas del corazón de la pestaña de favoritas (textures/heart_*.dds).

Uso:
    python tools/generate_heart_textures.py [carpeta_de_salida]

Por defecto escribe en la carpeta textures/ del addon. Requiere numpy y Pillow.

Las cuatro texturas (normal, pulsada, ratón encima, desactivada) tienen el corazón del
mismo tamaño: el juego dibuja la pestaña normal a 51 px y la pulsada o con el ratón
encima a 64 px, así que el contenido ocupa unos 42 de los 64 px para que se vean iguales.
"""
import sys
from pathlib import Path

import numpy as np
from PIL import Image

SIZE = 64
SUPERSAMPLING = 8  # se dibuja a 8x y se reduce, para bordes suaves
HEART_EXTENT = 3.6  # mayor valor, corazón más pequeño dentro de la textura

# nombre: (color RGB, opacidad)
STATES = {
    "up": ((205, 78, 88), 1.0),
    "over": ((240, 110, 120), 1.0),
    "down": ((255, 140, 150), 1.0),
    "disabled": ((120, 120, 120), 0.6),
}


def create_heart(color, alpha):
    """Dibuja un corazón centrado con la curva implícita (x^2+y^2-1)^3 - x^2*y^3 <= 0."""
    side = SIZE * SUPERSAMPLING
    ys, xs = np.mgrid[0:side, 0:side]
    u = (xs - side / 2 + 0.5) / side * HEART_EXTENT
    v = -(ys - side / 2 + 0.5) / side * HEART_EXTENT
    mask = ((u * u + v * v - 1) ** 3 - u * u * v**3) <= 0

    # Centra la forma: la curva no es simétrica respecto al origen en vertical
    rows, cols = np.where(mask)
    shift_y = int(round(side / 2 - (rows.min() + rows.max()) / 2))
    shift_x = int(round(side / 2 - (cols.min() + cols.max()) / 2))
    mask = np.roll(np.roll(mask, shift_y, 0), shift_x, 1)

    coverage = mask.reshape(SIZE, SUPERSAMPLING, SIZE, SUPERSAMPLING).mean(axis=(1, 3))

    pixels = np.zeros((SIZE, SIZE, 4), np.uint8)
    pixels[..., 0], pixels[..., 1], pixels[..., 2] = color
    pixels[..., 3] = (coverage * alpha * 255).round().astype(np.uint8)
    return Image.fromarray(pixels, "RGBA")


def main():
    default_output = Path(__file__).resolve().parent.parent / "textures"
    output_dir = Path(sys.argv[1]) if len(sys.argv) > 1 else default_output
    output_dir.mkdir(parents=True, exist_ok=True)

    for state, (color, alpha) in STATES.items():
        path = output_dir / f"heart_{state}.dds"
        create_heart(color, alpha).save(path, pixel_format="DXT5")
        print(f"escrito {path}")


if __name__ == "__main__":
    main()
