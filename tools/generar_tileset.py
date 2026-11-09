#!/usr/bin/env python3
"""Genera los tilesets de ECOS por código (Pillow).

Salida:
  Assets/Mundo/tileset_pasado.png     paleta cálida (dorados, ocres, rosas, morados)
  Assets/Mundo/tileset_presente.png   EL MISMO dibujo con la paleta cambiada (azul grisáceo, menos contraste)
  tools/tileset_info.json             dónde está cada tile (lo lee tools/construir_tileset.gd)

Todas las texturas son sin costuras: el ruido es periódico (se repite cada 32 px) y los detalles
"dan la vuelta" por los bordes. Los terrenos con transiciones (camino, arena, agua) son
autotiles de 47 piezas con bordes suaves e irregulares.

Uso:  python tools/generar_tileset.py
"""
import json
import math
import os
import random

from PIL import Image

T = 32                 # tamaño del tile
COLUMNAS = 16          # columnas del atlas
RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SALIDA = os.path.join(RAIZ, "Assets", "Mundo")


def c(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


# ----------------------------------------------------------------------------
# Paleta del Pasado (dorados, ocres, rosas, morados suaves, sombras violetas)
# ----------------------------------------------------------------------------
P = {
    "contorno": c("2a1c3a"),
    "sombra": c("3d2a52"),
    # hierba: oliva dorado cálido (sin verdes saturados)
    "hierba": [c("66713a"), c("81853f"), c("9c9a4c"), c("b7ae61")],
    "hierba_clara": c("cdc377"),
    "hierba_oro": c("e2cf7c"),
    "hierba_oscura": c("545c30"),
    "flor_rosa": c("ec93b4"), "flor_lila": c("ab8ddb"), "flor_crema": c("f8e8b4"), "flor_oro": c("f4c24c"),
    # pasto seco
    "seco": [c("8c7d3f"), c("a58f48"), c("bba65c"), c("d0bd78")],
    "seco_oscuro": c("826535"), "seco_claro": c("f0dba0"),
    # camino de tierra
    "tierra": [c("93633f"), c("ae7b4b"), c("c5945f"), c("d9ae7a")],
    "tierra_oscura": c("744d33"), "tierra_clara": c("e6c392"),
    "borde_camino": c("5e3f2d"),
    # arena de orilla
    "arena": [c("d3b985"), c("e0c996"), c("ead6a8"), c("f2e2bd")],
    "arena_oscura": c("b89a68"), "arena_clara": c("f8ecd0"),
    "borde_arena": c("a98a5c"),
    # agua (refleja el atardecer)
    "agua": [c("476a9c"), c("5a80b3"), c("729dc9"), c("8db6dc")],
    "agua_clara": c("c4dcf0"), "agua_espuma": c("f2eef0"), "agua_oscura": c("37557f"),
    "borde_agua": c("2f4a78"),
    # roca y acantilado (malva)
    "roca": [c("5b475f"), c("76606f"), c("927a84"), c("ad939b")],
    "roca_clara": c("c8b0b4"), "roca_oscura": c("3e2f48"),
    # muro de piedra
    "muro": [c("7d6a7f"), c("93808f"), c("a8949c")], "muro_junta": c("54435c"), "muro_tapa": c("bba7ab"),
    # adoquines
    "adoquin": [c("9a8794"), c("ae9ca4"), c("c0b0b0")], "adoquin_junta": c("5d4a64"),
    # tierra roja (zona de Rabia)
    "roja": [c("8e4535"), c("a85841"), c("bf6e4d"), c("d38a63")],
    "roja_oscura": c("6a3329"), "roja_clara": c("e4a97c"),
    # suelo volcánico
    "volcan": [c("3a2a3e"), c("4a3548"), c("5a4252")],
    "lava": c("e8582c"), "lava_clara": c("fba04a"), "brasa": c("ffd37a"),
    # suelo de bosque oscuro
    "bosque": [c("2f2c4a"), c("3b3857"), c("484564")],
    "bosque_hoja": [c("565078"), c("6a6480"), c("4a5a52")], "bosque_oscuro": c("232038"),
    # suelo de ruinas
    "ruina": [c("a89886"), c("b9a998"), c("c9bcab")],
    "ruina_junta": c("5f5062"), "ruina_musgo": c("8b8a4a"), "ruina_grieta": c("4a3c52"),
    # madera (puentes)
    "madera": [c("7d5238"), c("9a6b46"), c("b4825a")], "madera_oscura": c("4e3223"), "madera_clara": c("cfa070"),
}

BAYER = [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]


# ----------------------------------------------------------------------------
# Utilidades de dibujo sin costuras
# ----------------------------------------------------------------------------
class RuidoPeriodico:
    """Ruido de valores que se repite cada T píxeles (sin costuras)."""

    def __init__(self, semilla, celdas):
        r = random.Random(semilla)
        self.n = celdas
        self.g = [[r.random() for _ in range(celdas)] for _ in range(celdas)]

    def __call__(self, x, y):
        gx = (x % T) / T * self.n
        gy = (y % T) / T * self.n
        x0, y0 = int(gx) % self.n, int(gy) % self.n
        x1, y1 = (x0 + 1) % self.n, (y0 + 1) % self.n
        fx, fy = gx - int(gx), gy - int(gy)
        sx, sy = fx * fx * (3 - 2 * fx), fy * fy * (3 - 2 * fy)
        a = self.g[y0][x0] + (self.g[y0][x1] - self.g[y0][x0]) * sx
        b = self.g[y1][x0] + (self.g[y1][x1] - self.g[y1][x0]) * sx
        return a + (b - a) * sy


def nuevo():
    return Image.new("RGBA", (T, T), (0, 0, 0, 0))


def poner(img, x, y, color, alfa=255):
    img.putpixel((x % T, y % T), tuple(color[:3]) + (alfa,))


def base_ruidosa(semilla, rampa, contraste=1.0, dither=0.18, estirar=(1.0, 1.0), escalas=(4, 8)):
    """Relleno con ruido periódico cuantizado a la rampa de colores con trama ordenada (dither)."""
    n1 = RuidoPeriodico(semilla, escalas[0])
    n2 = RuidoPeriodico(semilla + 101, escalas[1])
    img = nuevo()
    for y in range(T):
        for x in range(T):
            v = 0.62 * n1(x * estirar[0], y * estirar[1]) + 0.38 * n2(x * estirar[0], y * estirar[1])
            v = (v - 0.5) * contraste + 0.5
            v += (BAYER[y % 4][x % 4] / 16.0 - 0.5) * dither
            idx = max(0, min(len(rampa) - 1, int(v * len(rampa))))
            poner(img, x, y, rampa[idx])
    return img


def puntos(img, r, cantidad, colores, largo=1):
    for _ in range(cantidad):
        x, y = r.randrange(T), r.randrange(T)
        col = r.choice(colores)
        for k in range(largo):
            poner(img, x, y - k, col)


def flor(img, x, y, color, centro):
    poner(img, x, y, centro)
    for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
        poner(img, x + dx, y + dy, color)


def piedrita(img, x, y, claro, oscuro):
    poner(img, x, y, claro)
    poner(img, x + 1, y, claro)
    poner(img, x, y + 1, oscuro)
    poner(img, x + 1, y + 1, oscuro)


def linea(img, x0, y0, x1, y1, color):
    pasos = max(abs(x1 - x0), abs(y1 - y0), 1)
    for i in range(pasos + 1):
        poner(img, round(x0 + (x1 - x0) * i / pasos), round(y0 + (y1 - y0) * i / pasos), color)


# ----------------------------------------------------------------------------
# Texturas de suelo (opacas, sin costuras): mucho color plano, manchas grandes y detalles AGRUPADOS
# ----------------------------------------------------------------------------
def limpiar(img):
    """Quita los píxeles sueltos: un píxel distinto a sus 4 vecinos (que son iguales entre sí) se funde con ellos."""
    px = img.load()
    out = img.copy()
    po = out.load()
    for y in range(T):
        for x in range(T):
            vec = [px[(x + 1) % T, y], px[(x - 1) % T, y], px[x, (y + 1) % T], px[x, (y - 1) % T]]
            if px[x, y] not in vec:
                for v in vec:
                    if vec.count(v) >= 3:
                        po[x, y] = v
                        break
    return out


def base_manchas(semilla, rampa, escalas=(3, 6), umbral=(0.40, 0.60)):
    """Fondo plano con dos o tres manchas grandes de los tonos vecinos (sin trama ni ruido fino).
    rampa: [oscuro, medio, claro]."""
    n1 = RuidoPeriodico(semilla, escalas[0])
    n2 = RuidoPeriodico(semilla + 101, escalas[1])
    img = nuevo()
    for y in range(T):
        for x in range(T):
            v = 0.65 * n1(x, y) + 0.35 * n2(x, y)
            idx = 0 if v < umbral[0] else 2 if v > umbral[1] else 1
            poner(img, x, y, rampa[idx])
    return limpiar(img)


def mata(img, x, y, claro, oscuro):
    """Mata de hierba de 3 px de ancho: una 'V' clara con la base más oscura."""
    poner(img, x - 1, y - 2, claro)
    poner(img, x - 1, y - 1, claro)
    poner(img, x, y - 1, claro)
    poner(img, x + 1, y - 2, claro)
    poner(img, x + 1, y - 1, claro)
    poner(img, x, y, oscuro)


def racimo_flores(img, r, x, y, colores, centro, cantidad):
    """Un racimo de 3 a 5 florecitas muy juntas."""
    for i in range(cantidad):
        fx = x + r.randint(-4, 4)
        fy = y + r.randint(-3, 3)
        flor(img, fx, fy, r.choice(colores), centro)


def tex_hierba(semilla, tono=1, flores=0, matas=3, piedras=0):
    """tono 0 = oscura, 1 = media, 2 = clara. La variación grande se reparte en Mundo.gd con ruido."""
    r = random.Random(semilla)
    h = P["hierba"]
    rampas = {0: [h[0], h[1], h[1]], 1: [h[1], h[1], h[2]], 2: [h[1], h[2], h[2]]}
    img = base_manchas(semilla, [P["hierba_oscura"], h[0], h[1]] if tono == 0 else [h[0], h[1], h[2]] if tono == 1
                       else [h[1], h[2], P["hierba"][3]])
    claro = [h[2], h[3], P["hierba"][3]][tono]
    oscuro = [P["hierba_oscura"], h[0], h[1]][tono]
    for _ in range(matas):
        mata(img, r.randrange(3, T - 3), r.randrange(4, T - 2), claro, oscuro)
    for _ in range(piedras):
        piedrita(img, r.randrange(2, T - 3), r.randrange(2, T - 3), P["roca"][3], P["roca"][1])
    if flores:
        racimo_flores(img, r, r.randrange(6, T - 6), r.randrange(6, T - 6),
                      [P["flor_rosa"], P["flor_lila"], P["flor_crema"]], P["flor_oro"], flores)
    return img


def tex_seco(semilla):
    r = random.Random(semilla)
    s = P["seco"]
    img = base_manchas(semilla, [s[0], s[1], s[2]])
    for _ in range(3):
        mata(img, r.randrange(3, T - 3), r.randrange(4, T - 2), s[3], P["seco_oscuro"])
    return img


def tex_camino(semilla):
    r = random.Random(semilla)
    t = P["tierra"]
    img = base_manchas(semilla, [t[0], t[1], t[2]], escalas=(3, 5), umbral=(0.38, 0.64))
    for _ in range(2):
        piedrita(img, r.randrange(2, T - 3), r.randrange(2, T - 3), P["tierra_clara"], P["tierra_oscura"])
    for _ in range(2):  # arañazos cortos agrupados (2 px)
        x, y = r.randrange(2, T - 4), r.randrange(2, T - 3)
        poner(img, x, y, P["tierra_oscura"])
        poner(img, x + 1, y, P["tierra_oscura"])
    return img


def tex_arena(semilla):
    r = random.Random(semilla)
    a = P["arena"]
    img = base_manchas(semilla, [a[0], a[1], a[2]], escalas=(3, 5), umbral=(0.38, 0.64))
    for _ in range(3):  # ondas de viento de 3 px
        x, y = r.randrange(2, T - 5), r.randrange(2, T - 2)
        linea(img, x, y, x + 3, y, P["arena_oscura"])
    for _ in range(2):
        piedrita(img, r.randrange(2, T - 3), r.randrange(2, T - 3), P["arena_clara"], P["arena_oscura"])
    return img


def tex_roja(semilla):
    r = random.Random(semilla)
    ro = P["roja"]
    img = base_manchas(semilla, [ro[0], ro[1], ro[2]], escalas=(3, 6))
    for _ in range(2):
        x, y = r.randrange(2, T - 8), r.randrange(4, T - 4)
        linea(img, x, y, x + r.randint(4, 6), y + r.randint(-1, 1), P["roja_oscura"])  # grieta
    piedrita(img, r.randrange(2, T - 3), r.randrange(2, T - 3), P["roja_clara"], P["roja_oscura"])
    return img


def tex_volcanico(semilla):
    r = random.Random(semilla)
    v = P["volcan"]
    img = base_manchas(semilla, [v[0], v[1], v[2]], escalas=(3, 6))
    for _ in range(2):  # grietas de lava agrupadas, con brillo
        x, y = r.randrange(4, T - 8), r.randrange(4, T - 4)
        for _ in range(r.randint(4, 6)):
            nx, ny = x + r.choice([1, 1, 2]), y + r.choice([-1, 0, 1])
            linea(img, x, y, nx, ny, P["lava"])
            poner(img, x, y - 1, P["lava_clara"]) if r.random() < 0.4 else None
            x, y = nx, ny
    return img


def tex_bosque(semilla):
    r = random.Random(semilla)
    b = P["bosque"]
    img = base_manchas(semilla, [b[0], b[1], b[2]], escalas=(3, 6))
    for _ in range(3):  # hojarasca en parejas
        x, y = r.randrange(2, T - 3), r.randrange(2, T - 3)
        col = r.choice(P["bosque_hoja"])
        poner(img, x, y, col)
        poner(img, x + 1, y, col)
    return img


def tex_ruinas(semilla):
    r = random.Random(semilla)
    img = nuevo()
    # losas de 16x16 con tono propio y juntas oscuras
    for gy in range(2):
        for gx in range(2):
            col = r.choice(P["ruina"])
            for y in range(16):
                for x in range(16):
                    poner(img, gx * 16 + x, gy * 16 + y, col)
            for k in range(16):
                poner(img, gx * 16 + k, gy * 16, P["ruina_junta"])
                poner(img, gx * 16, gy * 16 + k, P["ruina_junta"])
    for _ in range(4):
        x, y = r.randrange(T), r.randrange(T)
        linea(img, x, y, x + r.randint(-4, 4), y + r.randint(2, 5), P["ruina_grieta"])
    for _ in range(6):  # manchas de musgo
        x, y = r.randrange(T), r.randrange(T)
        poner(img, x, y, P["ruina_musgo"])
        poner(img, x + 1, y, P["ruina_musgo"])
        poner(img, x, y + 1, P["ruina_musgo"])
    return img


def tex_adoquines(semilla):
    r = random.Random(semilla)
    img = nuevo()
    for fila in range(4):  # 4 filas de piedras de 8x8, alternadas
        desplazo = 4 if fila % 2 else 0
        for col in range(4):
            base = r.choice(P["adoquin"])
            ox, oy = col * 8 + desplazo, fila * 8
            for y in range(8):
                for x in range(8):
                    c_px = base
                    if x == 0 or y == 0:
                        c_px = P["adoquin_junta"]
                    elif x == 1 and y == 1:
                        c_px = P["adoquin"][2]
                    elif x >= 6 or y >= 6:
                        c_px = tuple(max(0, v - 18) for v in base)
                    poner(img, ox + x, oy + y, c_px)
    return img


# ----------------------------------------------------------------------------
# Piezas altas / especiales (con transparencia)
# ----------------------------------------------------------------------------
def tex_roca():
    img = nuevo()
    # sombra en el suelo
    for y in range(T):
        for x in range(T):
            if ((x - 16) / 12.5) ** 2 + ((y - 26) / 4.0) ** 2 <= 1:
                poner(img, x, y, P["contorno"], 90)
    cx, cy, rx, ry = 16, 17, 12, 10
    dentro = set()
    for y in range(T):
        for x in range(T):
            if ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2 <= 1:
                dentro.add((x, y))
    for (x, y) in dentro:
        luz = (-(x - cx) / rx - (y - cy) / ry) * 0.5  # luz desde arriba a la izquierda
        idx = 2 if luz > 0.25 else 1 if luz > -0.2 else 0
        if luz > 0.55:
            idx = 3
        poner(img, x, y, P["roca"][idx])
    r = random.Random(7)
    for _ in range(3):
        x, y = r.randint(10, 22), r.randint(13, 22)
        linea(img, x, y, x + r.randint(-3, 3), y + r.randint(2, 4), P["roca_oscura"])
    for (x, y) in dentro:  # contorno oscuro
        if any((x + dx, y + dy) not in dentro for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
            poner(img, x, y, P["contorno"])
    return img


def tex_acantilado_cara(semilla):
    """Cara del acantilado: bandas verticales planas de 3 tonos, borde superior iluminado y
    una sombra de 2 px más oscura al pie."""
    r = random.Random(semilla)
    cols = RuidoPeriodico(semilla, 6)
    img = nuevo()
    ro = P["roca"]
    for y in range(T):
        for x in range(T):
            v = cols(x * 0.7 + (y // 9) * 3, 3)
            poner(img, x, y, ro[0] if v < 0.40 else ro[2] if v > 0.62 else ro[1])
    img = limpiar(img)
    for x in range(T):  # borde superior iluminado
        poner(img, x, 0, P["roca_clara"])
        poner(img, x, 1, ro[3])
    for _ in range(3):  # grietas verticales de 4 a 6 px
        x, y = r.randrange(3, T - 3), r.randrange(4, 18)
        linea(img, x, y, x, y + r.randint(4, 6), P["roca_oscura"])
    for x in range(T):  # sombra al pie: 2 px más oscuros
        poner(img, x, T - 2, P["sombra"])
        poner(img, x, T - 1, P["contorno"])
    return img


def tex_acantilado_cima(semilla):
    """Parte alta del acantilado: roca plana con manchas y alguna piedrita."""
    r = random.Random(semilla)
    ro = P["roca"]
    img = base_manchas(semilla, [ro[1], ro[2], ro[3]], escalas=(3, 5), umbral=(0.36, 0.66))
    for _ in range(2):
        x, y = r.randrange(2, T - 6), r.randrange(2, T - 3)
        linea(img, x, y, x + r.randint(3, 5), y + r.randint(-1, 1), P["roca_oscura"])
    piedrita(img, r.randrange(2, T - 3), r.randrange(2, T - 3), P["roca_clara"], ro[1])
    return img


def tex_muro(semilla, remate=True):
    """Muro de piedra. Con remate (losa clara arriba) para la primera pieza de un tramo; sin remate
    para las piezas de abajo, así los muros altos no parecen escalones."""
    r = random.Random(semilla)
    img = nuevo()
    for y in range(T):
        for x in range(T):
            poner(img, x, y, P["muro"][1])
    y_ini = 0
    if remate:
        for x in range(T):
            for y in range(8):
                poner(img, x, y, P["muro_tapa"])
            poner(img, x, 0, P["contorno"])
            poner(img, x, 7, P["muro_junta"])
        y_ini = 8
    hileras = (T - y_ini) // 8
    for hilera in range(hileras):
        y0 = y_ini + hilera * 8
        desplazo = 8 if (hilera + (0 if remate else 1)) % 2 else 0
        for x in range(T):
            poner(img, x, y0, P["muro_junta"])
        for bx in range(2):
            x0 = (bx * 16 + desplazo) % T
            col = r.choice(P["muro"])
            for y in range(y0 + 1, y0 + 8):
                for x in range(15):
                    poner(img, x0 + 1 + x, y, col)
            for y in range(y0 + 1, y0 + 8):
                poner(img, x0, y, P["muro_junta"])
            for x in range(14):
                poner(img, x0 + 1 + x, y0 + 1, tuple(min(255, v + 18) for v in col))
    for x in range(T):  # sombra al pie
        poner(img, x, T - 1, P["muro_junta"])
    return img


def tex_sombra():
    """Sombra suave de 2 px (más una franja débil) que cae bajo muros y acantilados sobre el suelo."""
    img = nuevo()
    for y, alfa in ((0, 95), (1, 80), (2, 38)):
        for x in range(T):
            poner(img, x, y, P["sombra"], alfa)
    return img


def tex_puente(roto=None):
    """Puente de madera horizontal (se cruza de izquierda a derecha). roto: None, 'izq' o 'der'."""
    img = nuevo()
    r = random.Random(11)
    for y in range(T):
        for x in range(T):
            if roto == "izq" and x >= 14 + (3 if (y // 3) % 2 else 0):
                continue
            if roto == "der" and x < 18 - (3 if (y // 3) % 2 else 0):
                continue
            tablon = (y - 4) // 6
            if y < 3 or y >= T - 3:
                poner(img, x, y, P["madera_oscura"])  # barandas
            else:
                col = P["madera"][(tablon + (x // 11)) % 3]
                if (y - 4) % 6 == 0:
                    col = P["madera_oscura"]
                elif (y - 4) % 6 == 1:
                    col = P["madera_clara"]
                poner(img, x, y, col)
    for x in range(T):  # contornos arriba y abajo
        for y in (0, T - 1):
            if img.getpixel((x, y))[3]:
                poner(img, x, y, P["contorno"])
    for px, py in ((4, 6), (4, 12), (4, 18), (4, 24), (27, 6), (27, 12), (27, 18), (27, 24)):
        if img.getpixel((px, py))[3]:
            poner(img, px, py, P["madera_oscura"])
    return img


# ----------------------------------------------------------------------------
# Agua animada (4 cuadros)
# ----------------------------------------------------------------------------
def tex_agua(cuadro, variante=0):
    """Agua de colores casi planos con manchas grandes y 3 destellos de 2 px que se desplazan cada cuadro."""
    r = random.Random(5 + variante * 13)
    a = P["agua"]
    img = base_manchas(31 + variante * 17, [a[0], a[1], a[2]], escalas=(3, 5), umbral=(0.38, 0.64))
    for i in range(3):  # destellos: 2 px claros que se mueven 6 px a la derecha por cuadro
        x, y = r.randrange(T), r.randrange(2, T - 2)
        xx = x + cuadro * 6
        poner(img, xx, y, P["agua_clara"])
        poner(img, xx + 1, y, P["agua_clara"])
    for _ in range(2):  # rayitas oscuras cortas, fijas
        x, y = r.randrange(T), r.randrange(T)
        poner(img, x, y, P["agua_oscura"])
        poner(img, x + 1, y, P["agua_oscura"])
    return img


# ----------------------------------------------------------------------------
# Autotiles de 47 piezas con bordes suaves
# ----------------------------------------------------------------------------
LADOS = ["N", "NE", "E", "SE", "S", "SO", "O", "NO"]


def patrones_47():
    """Los 47 patrones únicos de vecinos (una esquina solo cuenta si sus dos lados están)."""
    vistos = set()
    resultado = []
    for n in range(256):
        b = {LADOS[i]: bool(n >> i & 1) for i in range(8)}
        if not (b["N"] and b["E"]):
            b["NE"] = False
        if not (b["S"] and b["E"]):
            b["SE"] = False
        if not (b["S"] and b["O"]):
            b["SO"] = False
        if not (b["N"] and b["O"]):
            b["NO"] = False
        clave = tuple(b[k] for k in LADOS)
        if clave not in vistos:
            vistos.add(clave)
            resultado.append(b)
    resultado.sort(key=lambda b: sum(1 << i for i, k in enumerate(LADOS) if b[k]))
    assert len(resultado) == 47, len(resultado)
    return resultado


class Borde:
    """Ruido periódico a lo largo de un borde (continuo entre tiles vecinos)."""

    def __init__(self, fase1, fase2, amplitud):
        self.f1, self.f2, self.a = fase1, fase2, amplitud

    def __call__(self, t):
        return self.a * (0.6 * math.sin(2 * math.pi * 2 * t / T + self.f1) + 0.4 * math.sin(2 * math.pi * 5 * t / T + self.f2))


def mascara(b, margen, semilla, radio=10):
    """Máscara booleana TxT del terreno según sus vecinos. Los lados sin vecino se retiran
    'margen' píxeles con un borde que ondula muy poco; las esquinas se redondean con un radio grande
    (así los caminos y las orillas no hacen escalones)."""
    r = random.Random(semilla)
    bn = {k: Borde(r.uniform(0, 6.28), r.uniform(0, 6.28), 0.9) for k in "NSEO"}  # un ruido por lado, igual en todos los tiles
    m = [[True] * T for _ in range(T)]
    for y in range(T):
        for x in range(T):
            px, py = x + 0.5, y + 0.5
            dentro = True
            if not b["O"] and px < margen + bn["O"](py):
                dentro = False
            if not b["E"] and px > T - margen - bn["E"](py):
                dentro = False
            if not b["N"] and py < margen + bn["N"](px):
                dentro = False
            if not b["S"] and py > T - margen - bn["S"](px):
                dentro = False
            # esquinas convexas (dos lados sin vecino): redondeadas
            for (lx, ly, cx, cy) in (("O", "N", margen + radio, margen + radio),
                                     ("E", "N", T - margen - radio, margen + radio),
                                     ("O", "S", margen + radio, T - margen - radio),
                                     ("E", "S", T - margen - radio, T - margen - radio)):
                if not b[lx] and not b[ly]:
                    if (px < cx if lx == "O" else px > cx) and (py < cy if ly == "N" else py > cy):
                        if math.hypot(px - cx, py - cy) > radio:
                            dentro = False
            # esquinas cóncavas (lados con vecino pero esquina vacía): mordisco redondo
            for (esq, lx, ly, ex, ey) in (("NO", "O", "N", 0, 0), ("NE", "E", "N", T, 0),
                                         ("SO", "O", "S", 0, T), ("SE", "E", "S", T, T)):
                if b[lx] and b[ly] and not b[esq]:
                    if math.hypot(px - ex, py - ey) < margen + radio * 0.55:
                        dentro = False
            m[y][x] = dentro
    return m


def componer_autotile(textura, b, margen, color_borde, color_interior, semilla, estilo="tierra"):
    """Recorta 'textura' con la máscara y dibuja el borde.
    estilo 'tierra': línea de 1 px más oscura donde la hierba se monta sobre el camino o la arena,
                     con algunas hojas de hierba que asoman 1 px hacia dentro.
    estilo 'agua':   espuma clara en la orilla y una sombra suave de 2 px más oscura por fuera."""
    m = mascara(b, margen, semilla)

    def adentro(x, y):
        if 0 <= x < T and 0 <= y < T:
            return m[y][x]
        if x < 0 and 0 <= y < T:
            return b["O"]
        if x >= T and 0 <= y < T:
            return b["E"]
        if y < 0 and 0 <= x < T:
            return b["N"]
        if y >= T and 0 <= x < T:
            return b["S"]
        return True

    def cerca_fuera(x, y, d):
        """¿Hay un píxel de fuera de la máscara a distancia (4-vecinos) <= d?"""
        for k in range(1, d + 1):
            for dx, dy in ((k, 0), (-k, 0), (0, k), (0, -k)):
                if not adentro(x + dx, y + dy):
                    return k
        return 0

    img = nuevo()
    for y in range(T):
        for x in range(T):
            if not m[y][x]:
                if estilo == "agua":  # sombra suave de 2 px por fuera de la orilla
                    k = 0
                    for dist in (1, 2):
                        for dx, dy in ((dist, 0), (-dist, 0), (0, dist), (0, -dist)):
                            if 0 <= x + dx < T and 0 <= y + dy < T and m[y + dy][x + dx]:
                                k = dist
                                break
                        if k:
                            break
                    if k:
                        img.putpixel((x, y), tuple(P["contorno"]) + (95 if k == 1 else 50,))
                continue
            k = cerca_fuera(x, y, 2)
            if estilo == "agua":
                if k == 1:
                    espuma = ((x * 7 + y * 5 + semilla) % 5) != 0  # la espuma tiene pequeños cortes
                    img.putpixel((x, y), tuple(P["agua_espuma"] if espuma else P["agua_clara"]) + (255,))
                elif k == 2 and (x + y) % 3 == 0:
                    img.putpixel((x, y), tuple(P["agua_clara"]) + (255,))
                else:
                    img.putpixel((x, y), textura.getpixel((x, y)))
                continue
            if k == 1:
                img.putpixel((x, y), tuple(color_borde) + (255,))
            elif k == 2 and color_interior is not None and (x * 3 + y * 7 + semilla) % 7 == 0:
                img.putpixel((x, y), tuple(color_interior) + (255,))  # hojita de hierba que asoma
            else:
                img.putpixel((x, y), textura.getpixel((x, y)))
    return img


# ----------------------------------------------------------------------------
# Presente: la misma imagen con otra paleta (azul grisáceo apagado, menos contraste)
# ----------------------------------------------------------------------------
def apagar(img):
    px = img.load()
    out = img.copy()
    po = out.load()
    for y in range(img.height):
        for x in range(img.width):
            r, g, b, a = px[x, y]
            if a == 0:
                continue
            lum = 0.299 * r + 0.587 * g + 0.114 * b
            # conserva un poco del color original y lo lleva hacia el azul grisáceo
            r2 = lum + (r - lum) * 0.14
            g2 = lum + (g - lum) * 0.14
            b2 = lum + (b - lum) * 0.14
            r2, g2, b2 = r2 * 0.80, g2 * 0.92, b2 * 1.06 + 6
            # menos contraste: se acerca al gris medio
            r2 = 118 + (r2 - 118) * 0.74
            g2 = 124 + (g2 - 124) * 0.74
            b2 = 142 + (b2 - 142) * 0.74
            po[x, y] = (max(0, min(255, int(r2))), max(0, min(255, int(g2))), max(0, min(255, int(b2))), a)
    return out



# ----------------------------------------------------------------------------
# Decoración suelta de 16x16: matas, flores, piedritas y hojas (se reparten con ruido en Mundo.gd)
# ----------------------------------------------------------------------------
D = 16


def pd(img, x, y, color):
    if 0 <= x < D and 0 <= y < D:
        img.putpixel((x, y), tuple(color[:3]) + (255,))


def det_mata(semilla):
    """Mata de hierba: 3 o 4 puntas juntas, con la base más oscura."""
    r = random.Random(semilla)
    img = Image.new("RGBA", (D, D), (0, 0, 0, 0))
    h = P["hierba"]
    for i in range(r.randint(3, 4)):
        x = 4 + i * 3 + r.randint(-1, 0)
        alto = r.randint(3, 5)
        for k in range(alto):
            pd(img, x + (1 if k == alto - 1 and i % 2 else 0), 12 - k, h[3] if k >= alto - 2 else h[2])
        pd(img, x, 13, P["hierba_oscura"])
    return img


def det_flores(semilla, color):
    """Racimo de 3 florecitas con hojas verdes."""
    r = random.Random(semilla)
    img = Image.new("RGBA", (D, D), (0, 0, 0, 0))
    h = P["hierba"]
    sitios = [(4, 10), (9, 7), (11, 11)]
    for (x, y) in sitios:
        pd(img, x, y + 2, h[1])
        pd(img, x, y + 1, h[2])
        pd(img, x - 1, y + 2, h[2])
        pd(img, x + 1, y + 2, h[2])
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            pd(img, x + dx, y + dy, color)
        pd(img, x, y, P["flor_oro"])
    return img


def det_piedras(semilla):
    """Tres piedritas de 2x2 (o 3x2) con luz arriba y sombra abajo."""
    r = random.Random(semilla)
    img = Image.new("RGBA", (D, D), (0, 0, 0, 0))
    for (x, y, ancho) in ((3, 9, 3), (9, 6, 2), (10, 11, 2)):
        for dx in range(ancho):
            pd(img, x + dx, y, P["roca"][3] if dx < ancho - 1 else P["roca"][2])
            pd(img, x + dx, y + 1, P["roca"][1])
        pd(img, x + 1, y + 2, P["contorno"])
        pd(img, x + ancho - 1, y + 2, P["contorno"])
    return img


def det_hojas(semilla, colores, secas=False):
    """Dos o tres hojas caídas (Pasado, de colores) u hojas secas (Presente, curvadas y apagadas)."""
    r = random.Random(semilla)
    img = Image.new("RGBA", (D, D), (0, 0, 0, 0))
    sitios = [(3, 9), (8, 5), (9, 11)]
    for i, (x, y) in enumerate(sitios[:r.randint(2, 3)]):
        col = colores[(i + semilla) % len(colores)]
        osc = tuple(int(v * 0.7) for v in col)
        if secas:
            for dx, dy in ((0, 1), (1, 0), (2, 0), (3, 1)):
                pd(img, x + dx, y + dy, col)
            pd(img, x + 1, y + 1, osc)
        else:
            for dx, dy in ((0, 1), (1, 0), (1, 1), (2, 0), (2, 1)):
                pd(img, x + dx, y + dy, col)
            pd(img, x + 1, y + 1, osc)  # nervio
    return img


def construir_detalles():
    """Hoja de detalles (Pasado y Presente). Devuelve (png_pasado, png_presente, info)."""
    h = P["hierba"]
    hojas_vivas = [c("e0833a"), c("e2b54a"), c("c8604a"), c("d99a52")]
    hojas_secas = [c("8a6a45"), c("7a6048"), c("96794f"), c("6e5a44")]
    nombres = []
    celdas = []
    for i in range(4):
        nombres.append(("matas", len(celdas)))
        celdas.append((det_mata(100 + i), det_mata(100 + i)))
    for i, col in enumerate((P["flor_rosa"], P["flor_lila"], P["flor_crema"], P["flor_oro"])):
        nombres.append(("flores", len(celdas)))
        celdas.append((det_flores(200 + i, col), det_flores(200 + i, col)))
    for i in range(3):
        nombres.append(("piedras", len(celdas)))
        celdas.append((det_piedras(300 + i), det_piedras(300 + i)))
    for i in range(4):
        nombres.append(("hojas", len(celdas)))
        celdas.append((det_hojas(400 + i, hojas_vivas), det_hojas(400 + i, hojas_secas, secas=True)))
    columnas = 8
    filas = (len(celdas) + columnas - 1) // columnas
    pasado = Image.new("RGBA", (columnas * D, filas * D), (0, 0, 0, 0))
    presente = Image.new("RGBA", (columnas * D, filas * D), (0, 0, 0, 0))
    info = {"tamano": D, "grupos": {}}
    for i, (img_p, img_s) in enumerate(celdas):
        pasado.paste(img_p, ((i % columnas) * D, (i // columnas) * D))
        presente.paste(img_s, ((i % columnas) * D, (i // columnas) * D))
    for grupo, i in nombres:
        info["grupos"].setdefault(grupo, []).append([i % columnas, i // columnas])
    return pasado, apagar(presente), info


# ----------------------------------------------------------------------------
# Ensamblado del atlas
# ----------------------------------------------------------------------------
def construir():
    base = {}  # nombre -> (columna, fila)
    piezas = []  # (col, fila, imagen)

    def poner_tile(nombre, col, fila, img):
        base[nombre] = [col, fila]
        piezas.append((col, fila, img))

    # fila 0: suelos
    lista0 = [
        ("hierba_0", tex_hierba(1, matas=3)), ("hierba_1", tex_hierba(2, matas=2)), ("hierba_2", tex_hierba(3, matas=4)),
        ("hierba_3", tex_hierba(4, matas=2, piedras=1)),
        ("hierba_flores_0", tex_hierba(5, matas=2, flores=4)), ("hierba_flores_1", tex_hierba(6, matas=1, flores=5)),
        ("pasto_seco_0", tex_seco(7)), ("pasto_seco_1", tex_seco(8)),
        ("tierra_roja_0", tex_roja(9)), ("tierra_roja_1", tex_roja(10)),
        ("volcanico_0", tex_volcanico(11)), ("volcanico_1", tex_volcanico(12)),
        ("bosque_0", tex_bosque(13)), ("bosque_1", tex_bosque(14)),
        ("ruinas_0", tex_ruinas(15)), ("ruinas_1", tex_ruinas(16)),
    ]
    for i, (nombre, img) in enumerate(lista0):
        poner_tile(nombre, i, 0, img)

    # fila 1: piezas altas y especiales
    lista1 = [
        ("adoquines_0", tex_adoquines(21)), ("adoquines_1", tex_adoquines(22)),
        ("roca", tex_roca()),
        ("acantilado_cara_0", tex_acantilado_cara(23)), ("acantilado_cara_1", tex_acantilado_cara(24)),
        ("acantilado_cima_0", tex_acantilado_cima(25)), ("acantilado_cima_1", tex_acantilado_cima(26)),
        ("muro_piedra_0", tex_muro(27)), ("muro_piedra_1", tex_muro(28)),
        ("muro_cuerpo_0", tex_muro(29, remate=False)), ("muro_cuerpo_1", tex_muro(30, remate=False)),
        ("puente_h", tex_puente()), ("puente_roto_izq", tex_puente("izq")), ("puente_roto_der", tex_puente("der")),
        ("colision", nuevo()), ("colision_agua_profunda", nuevo()),
    ]
    for i, (nombre, img) in enumerate(lista1):
        poner_tile(nombre, i, 1, img)

    pats = patrones_47()
    info_auto = {}

    def bits_json(b):
        return {k: b[k] for k in LADOS}

    # camino (filas 3-5) y arena (filas 6-8)
    tex_c, tex_a = tex_camino(41), tex_arena(42)
    for nombre, tex, fila0, margen, borde, inter, sem in (
            ("camino", tex_c, 3, 5, P["borde_camino"], P["hierba"][2], 100),
            ("arena", tex_a, 6, 6, P["borde_arena"], P["hierba"][2], 200)):
        tiles = []
        for j, b in enumerate(pats):
            col, fila = j % COLUMNAS, fila0 + j // COLUMNAS
            piezas.append((col, fila, componer_autotile(tex, b, margen, borde, inter, sem)))
            tiles.append({"coords": [col, fila], "bits": bits_json(b)})
        info_auto[nombre] = {"tiles": tiles, "cuadros": 1}

    # agua: 4 cuadros uno al lado del otro por patrón (filas 9-20)
    cuadros = [tex_agua(f) for f in range(4)]
    tiles = []
    for j, b in enumerate(pats):
        col0, fila = (j % 4) * 4, 9 + j // 4
        for f in range(4):
            piezas.append((col0 + f, fila, componer_autotile(cuadros[f], b, 6, P["borde_agua"], P["agua_clara"], 300, "agua")))
        tiles.append({"coords": [col0, fila], "bits": bits_json(b)})
    info_auto["agua"] = {"tiles": tiles, "cuadros": 4}

    # Variantes de la pieza "llena" de cada terreno: Godot elige entre ellas al azar, así las
    # superficies grandes (un lago, un camino ancho) no repiten siempre el mismo dibujo.
    llena = next(b for b in pats if all(b[k] for k in LADOS))
    col_v = 0
    for nombre, fn, semillas, margen, borde, inter, sem in (
            ("camino", tex_camino, (51, 61), 5, P["borde_camino"], P["hierba"][2], 100),
            ("arena", tex_arena, (52, 62), 6, P["borde_arena"], P["hierba"][2], 200)):
        for semilla in semillas:
            piezas.append((col_v, 21, componer_autotile(fn(semilla), llena, margen, borde, inter, sem)))
            info_auto[nombre]["tiles"].append({"coords": [col_v, 21], "bits": bits_json(llena), "variante": True})
            col_v += 1
    for v in (1, 2):
        col0 = (v - 1) * 4
        for f in range(4):
            piezas.append((col0 + f, 22, componer_autotile(tex_agua(f, v), llena, 6, P["borde_agua"], P["agua_clara"], 300, "agua")))
        info_auto["agua"]["tiles"].append({"coords": [col0, 22], "bits": bits_json(llena), "variante": True})

    # fila 23: variantes de hierba (más oscura y más clara) y la sombra que cae bajo muros y acantilados
    extra = [
        ("sombra_s", tex_sombra()),
    ]
    for i, (nombre, img) in enumerate(extra):
        poner_tile(nombre, i, 23, img)

    filas_total = 24
    atlas = Image.new("RGBA", (COLUMNAS * T, filas_total * T), (0, 0, 0, 0))
    for (col, fila, img) in piezas:
        atlas.paste(img, (col * T, fila * T))
    return atlas, {"tamano": T, "columnas": COLUMNAS, "filas": filas_total, "base": base, "autotiles": info_auto}


def main():
    os.makedirs(SALIDA, exist_ok=True)
    atlas, info = construir()
    ruta_pasado = os.path.join(SALIDA, "tileset_pasado.png")
    ruta_presente = os.path.join(SALIDA, "tileset_presente.png")
    atlas.save(ruta_pasado)
    apagar(atlas).save(ruta_presente)
    with open(os.path.join(RAIZ, "tools", "tileset_info.json"), "w", encoding="utf-8") as f:
        json.dump(info, f, indent=1, ensure_ascii=False)
    d_pasado, d_presente, d_info = construir_detalles()
    d_pasado.save(os.path.join(SALIDA, "detalles_pasado.png"))
    d_presente.save(os.path.join(SALIDA, "detalles_presente.png"))
    with open(os.path.join(RAIZ, "tools", "detalles_info.json"), "w", encoding="utf-8") as f:
        json.dump(d_info, f, indent=1, ensure_ascii=False)
    print("Detalles 16x16 -> detalles_pasado.png / detalles_presente.png")
    print("Atlas %dx%d  ->  %s" % (atlas.width, atlas.height, ruta_pasado))
    print("Presente      ->  %s" % ruta_presente)
    print("Tiles base: %d | autotiles: %s" % (len(info["base"]), {k: len(v["tiles"]) for k, v in info["autotiles"].items()}))


if __name__ == "__main__":
    main()
