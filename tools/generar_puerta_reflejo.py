#!/usr/bin/env python3
"""Dibuja la Puerta del Reflejo (una puerta de piedra con un espejo en el centro) con Pillow.

Salida: Assets/Mundo/puerta_reflejo_pasado.png y puerta_reflejo_presente.png (96x112 px).
El Presente es el mismo dibujo con la paleta apagada y una grieta en el espejo.
El punto de apoyo (la base de la puerta) está en el centro de la fila de abajo.

Uso:  python tools/generar_puerta_reflejo.py
"""
import os
import sys

from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from generar_tileset import P, apagar, c  # noqa: E402  (paleta y función de apagado del tileset)

W, H = 96, 112
RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SALIDA = os.path.join(RAIZ, "Assets", "Mundo")


def rect(img, x0, y0, x1, y1, color):
    for y in range(y0, y1):
        for x in range(x0, x1):
            if 0 <= x < W and 0 <= y < H:
                img.putpixel((x, y), tuple(color[:3]) + (255,))


def piedra(img, x0, y0, x1, y1, semilla):
    """Bloques de piedra malva con juntas y luz arriba a la izquierda."""
    muro = P["muro"]
    junta = P["muro_junta"]
    for y in range(y0, y1):
        fila = (y - y0) // 8
        for x in range(x0, x1):
            col = muro[(fila + (x - x0) // 9 + semilla) % 3]
            if (y - y0) % 8 == 0 or (x - x0 + (fila % 2) * 4) % 9 == 0:
                col = junta
            elif (y - y0) % 8 == 1:
                col = tuple(min(255, v + 16) for v in col)
            img.putpixel((x, y), tuple(col[:3]) + (255,))


def dibujar():
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    # escalones de la base
    rect(img, 4, 102, 92, 112, P["roca"][1])
    rect(img, 4, 102, 92, 104, P["roca"][3])
    rect(img, 8, 96, 88, 102, P["roca"][2])
    rect(img, 8, 96, 88, 97, P["roca_clara"])
    for x in range(4, 92):
        img.putpixel((x, 111), tuple(P["contorno"]) + (255,))
    # pared del fondo (oscura)
    rect(img, 22, 30, 74, 96, P["roca_oscura"])
    # pilares laterales
    piedra(img, 10, 30, 26, 96, 0)
    piedra(img, 70, 30, 86, 96, 1)
    for y in range(30, 96):
        for x in (10, 85):
            img.putpixel((x, y), tuple(P["contorno"]) + (255,))
    # capiteles y bases de los pilares
    for (x0, x1) in ((8, 28), (68, 88)):
        rect(img, x0, 26, x1, 32, P["muro_tapa"])
        rect(img, x0, 26, x1, 27, P["roca_clara"])
        rect(img, x0, 31, x1, 32, P["muro_junta"])
        rect(img, x0, 90, x1, 96, P["muro"][2])
        rect(img, x0, 95, x1, 96, P["muro_junta"])
    # dintel con piedra clave
    piedra(img, 6, 8, 90, 26, 2)
    rect(img, 6, 6, 90, 10, P["muro_tapa"])
    rect(img, 6, 6, 90, 7, P["roca_clara"])
    for x in range(6, 90):
        img.putpixel((x, 6), tuple(P["contorno"]) + (255,)) if x in (6, 89) else None
    rect(img, 40, 4, 56, 28, P["muro"][2])
    rect(img, 40, 4, 56, 6, P["roca_clara"])
    rect(img, 40, 4, 41, 28, P["muro_junta"])
    rect(img, 55, 4, 56, 28, P["muro_junta"])
    # gema de la piedra clave
    rect(img, 46, 12, 50, 18, P["agua"][2])
    rect(img, 47, 13, 49, 15, P["agua_espuma"])
    # espejo: marco dorado y cristal con degradado
    mx0, my0, mx1, my1 = 31, 36, 65, 94
    rect(img, mx0 - 2, my0 - 2, mx1 + 2, my1 + 2, P["madera_oscura"])
    rect(img, mx0 - 1, my0 - 1, mx1 + 1, my1 + 1, c("e2b54a"))
    rect(img, mx0, my0, mx1, my1, P["agua_oscura"])
    for y in range(my0, my1):
        t = (y - my0) / (my1 - my0)
        col = P["agua"][3] if t < 0.35 else P["agua_clara"] if t < 0.7 else P["agua"][2]
        for x in range(mx0, mx1):
            img.putpixel((x, y), tuple(col[:3]) + (255,))
    # brillos en diagonal (cristal)
    for k in range(0, 40):
        for ancho, color in ((3, P["agua_espuma"]), (1, c("ffffff"))):
            x = mx0 + 4 + k // 2 + (0 if ancho == 3 else 6)
            y = my1 - 6 - k
            if mx0 <= x < mx1 and my0 <= y < my1 and ancho == 3:
                img.putpixel((x, y), tuple(color) + (255,))
                img.putpixel((min(x + 1, mx1 - 1), y), tuple(color) + (255,))
    for k in range(0, 22):
        x = mx0 + 18 + k // 2
        y = my1 - 8 - k
        if mx0 <= x < mx1 and my0 <= y < my1:
            img.putpixel((x, y), tuple(P["agua_espuma"]) + (255,))
    # sombra suave del marco sobre el cristal
    for x in range(mx0, mx1):
        img.putpixel((x, my0), tuple(P["agua"][1]) + (255,))
        img.putpixel((x, my0 + 1), tuple(P["agua"][2]) + (255,))
    return img


def grieta(img):
    """La grieta del espejo en el Presente."""
    puntos = [(48, 38), (45, 46), (50, 54), (44, 63), (49, 72), (46, 80), (48, 92)]
    for (x0, y0), (x1, y1) in zip(puntos[:-1], puntos[1:]):
        pasos = max(abs(x1 - x0), abs(y1 - y0))
        for i in range(pasos + 1):
            x = round(x0 + (x1 - x0) * i / pasos)
            y = round(y0 + (y1 - y0) * i / pasos)
            img.putpixel((x, y), tuple(P["contorno"]) + (255,))
    return img


def main():
    os.makedirs(SALIDA, exist_ok=True)
    pasado = dibujar()
    pasado.save(os.path.join(SALIDA, "puerta_reflejo_pasado.png"))
    presente = grieta(apagar(pasado))
    presente.save(os.path.join(SALIDA, "puerta_reflejo_presente.png"))
    print("Puerta del Reflejo ->", SALIDA)


if __name__ == "__main__":
    main()
