#!/usr/bin/env python3
"""Genera el primer borrador del mapa de ECOS (96x54 tiles) y comprueba que sea transitable.

Escribe:
  Resources/Mundo/mapa.txt        un carácter por tile (se edita a mano; ver la leyenda en el archivo)

Uso:
  python tools/generar_mapa.py            # solo el mapa
  python tools/generar_mapa.py --vista C:/ruta/vista.png   # además guarda una imagen de revisión

Después de cambiar el mapa, regenera las vistas previas (ver tools/preview_mapa.gd).
"""
import math
import os
import random
import sys
from collections import deque

W, H = 96, 54
TILE = 32
RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# Centros de las zonas (en tiles)
ZONAS = {
    "Hub": (48, 27), "Final": (48, 5),
    "Rabia": (80, 12), "Culpa": (88, 27), "Ansiedad": (78, 44), "Miedo": (48, 48),
    "Tristeza": (16, 42), "Soledad": (8, 27), "Verguenza": (16, 12),
}

LEYENDA = """\
; ECOS - mapa de 96x54 tiles. Un carácter por tile. Las líneas que empiezan con ';' son comentarios.
; Las dos épocas (Pasado y Presente) usan exactamente este mismo mapa.
;
;   .  hierba                     f  hierba con flores         d  pasto seco
;   r  tierra roja                v  suelo volcánico           b  suelo de bosque oscuro
;   u  suelo de ruinas            a  adoquines
;   c  camino de tierra           s  arena de orilla           w  agua (los bordes son poco profundos y se pueden pisar)
;   R  roca (sólida)              C  acantilado (sólido)       M  muro de piedra (sólido)
;   P  puente                     q  puente roto (parte izquierda)   Q  puente roto (parte derecha)
;   X  bloqueo invisible              T  franja de árboles (sólida; Decorador pone los árboles encima)
;
"""

BLOQUEA = set("CRMXT")
AGUA = set("wPqQ")


# ----------------------------------------------------------------------------
class Ruido:
    """Ruido de valores suave (no periódico) para formas orgánicas."""

    def __init__(self, semilla, escala=8):
        r = random.Random(semilla)
        self.escala = escala
        self.g = {}
        self.r = r

    def _v(self, i, j):
        if (i, j) not in self.g:
            self.g[(i, j)] = self.r.random()
        return self.g[(i, j)]

    def __call__(self, x, y):
        gx, gy = x / self.escala, y / self.escala
        i, j = math.floor(gx), math.floor(gy)
        fx, fy = gx - i, gy - j
        sx, sy = fx * fx * (3 - 2 * fx), fy * fy * (3 - 2 * fy)
        a = self._v(i, j) + (self._v(i + 1, j) - self._v(i, j)) * sx
        b = self._v(i, j + 1) + (self._v(i + 1, j + 1) - self._v(i, j + 1)) * sx
        return a + (b - a) * sy


def dentro(x, y):
    return 0 <= x < W and 0 <= y < H


class Mapa:
    def __init__(self):
        self.g = [["." for _ in range(W)] for _ in range(H)]
        self.rnd = random.Random(2024)
        self.ruido = Ruido(11, 7)
        self.ruido2 = Ruido(23, 5)
        self.camino = set()          # celdas del camino (centro y ancho)
        self.eje_camino = set()      # solo la línea central

    def get(self, x, y):
        return self.g[y][x] if dentro(x, y) else "C"

    def put(self, x, y, ch, solo_sobre=None):
        if dentro(x, y) and (solo_sobre is None or self.g[y][x] in solo_sobre):
            self.g[y][x] = ch

    def elipse(self, cx, cy, rx, ry, ch, solo_sobre=None, irregular=0.28):
        celdas = []
        for y in range(H):
            for x in range(W):
                d = ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2
                if d <= 1.0 + irregular * (self.ruido(x, y) - 0.5) * 2:
                    if solo_sobre is None or self.g[y][x] in solo_sobre:
                        self.g[y][x] = ch
                        celdas.append((x, y))
        return celdas


def fbm(r1, r2, x, y):
    """Ruido de dos escalas (formas orgánicas): valores entre 0 y 1."""
    return 0.65 * r1(x, y) + 0.35 * r2(x, y)


def construir():
    m = Mapa()
    lento = Ruido(3, 12)      # variaciones grandes
    medio = Ruido(11, 6)
    fino = Ruido(31, 2.6)     # para mezclar suelos en manchas pequeñas
    SUELO = set(".fdrvbuTs")
    HIERBAS = set(".fd")

    def mezcla(cx, cy, rx, ry, ch, solo=None, nucleo=0.62, borde=1.18, amp=0.5):
        """Mancha orgánica: el centro es del suelo 'ch' y en el borde se va mezclando con lo que haya
        (la transición dura 2 o 3 tiles), usando ruido y no azar tile por tile."""
        solo = solo or (SUELO | set("a"))
        for y in range(H):
            for x in range(W):
                d = math.hypot((x - cx) / rx, (y - cy) / ry) + (fbm(medio, lento, x + 50, y + 20) - 0.5) * amp
                if d >= borde or m.g[y][x] not in solo:
                    continue
                if d < nucleo or fino(x, y) > 0.18 + 0.64 * (d - nucleo) / (borde - nucleo):
                    m.g[y][x] = ch

    # 1. límite natural: acantilados al norte y al este, agua al sur y al oeste
    rn, rs, re_, rw = Ruido(5, 9), Ruido(6, 9), Ruido(7, 9), Ruido(8, 9)
    norte = [3 + int(rn(x, 0) * 2.4) for x in range(W)]
    for x in range(W):
        if 40 <= x <= 56:
            norte[x] = 3          # detrás de la Puerta del Reflejo el acantilado es bajo
    este = [3 + int(re_(0, y) * 2.4) for y in range(H)]
    sur = [2 + int(rs(x, 0) * 2.4) for x in range(W)]
    oeste = [2 + int(rw(0, y) * 2.2) for y in range(H)]
    for y in range(17, 38):
        oeste[y] = 2          # la colina de Soledad queda a 3 tiles o más del agua del oeste
    for y in range(H):
        for x in range(W):
            if x >= W - este[y]:
                m.g[y][x] = "C"
            elif y >= H - sur[x]:
                m.g[y][x] = "w"
            elif x < oeste[y] and y >= norte[x]:
                m.g[y][x] = "w"
            elif y < norte[x]:
                m.g[y][x] = "C"
    agua_borde = {(x, y) for y in range(H) for x in range(W) if m.g[y][x] == "w"}

    # 2. franja densa de árboles justo dentro del límite (casillas 'T': sólidas; Decorador las llena de árboles)
    grosor = Ruido(9, 5)
    for y in range(H):
        for x in range(W):
            if m.g[y][x] != ".":
                continue
            g = 2 + int(grosor(x, y) * 2.4)
            if (y < norte[x] + g or x >= W - este[y] - g or y >= H - sur[x] - g or x < oeste[y] + g):
                m.g[y][x] = "T"

    # 3. variedad del suelo: hierba con flores en manchas grandes (la variación clara/oscura la pone Mundo.gd)
    flores = Ruido(41, 7)
    for y in range(H):
        for x in range(W):
            if m.g[y][x] == "." and flores(x, y) > 0.72 and fino(x + 9, y + 3) > 0.35:
                m.g[y][x] = "f"

    # 4. suelos de cada zona, con transiciones graduales
    mezcla(80, 12, 12.0, 9.0, "r")                       # Rabia: tierra roja...
    mezcla(80, 12, 7.2, 5.5, "v", nucleo=0.7, borde=1.1)  # ...con el núcleo volcánico
    mezcla(88, 27, 11.5, 8.5, "d", HIERBAS | set("T"))    # Culpa: pasto seco...
    mezcla(88, 27, 7.5, 5.8, "u", nucleo=0.6, borde=1.1)  # ...y ruinas
    mezcla(78, 44, 9.0, 5.8, "a", nucleo=0.97, borde=1.0, amp=0.1)  # Ansiedad: plaza de adoquines
    mezcla(48, 48, 12.0, 8.0, "b", HIERBAS | set("T"))   # Miedo: bosque oscuro
    mezcla(8, 27, 10.0, 8.0, "d", HIERBAS | set("T"))     # Soledad: pasto seco alrededor de la colina
    mezcla(16, 12, 10.5, 7.8, "f", HIERBAS | set("T"))    # Vergüenza: jardín con flores
    mezcla(16, 12, 4.4, 4.0, "a", nucleo=0.97, borde=1.0, amp=0.1)   # y una plaza redonda
    mezcla(48, 27, 11.0, 10.5, "f", HIERBAS, amp=0.35)    # Hub: césped con flores...
    mezcla(48, 27, 6.4, 6.1, "a", nucleo=0.97, borde=1.0, amp=0.1)  # ...y plaza de adoquines
    # Puerta del Reflejo: un hueco natural en el acantilado, con una plataforma de adoquines
    for y in range(0, 12):
        for x in range(41, 56):
            if y >= norte[x] - 1 and m.g[y][x] in "CT":
                m.g[y][x] = "."
    mezcla(48, 6.5, 7.2, 4.3, "a", SUELO | set("a"), nucleo=0.97, borde=1.0, amp=0.1)

    # 5. ríos y lagos
    # Río de Culpa: baja desde los acantilados del este; recto y fijo entre y=24 y 35 (puente roto y vado)
    puntos_rio = [(91, 21.5), (86, 21.5), (84, 22.5), (83.5, 24), (83.5, 31), (83.5, 35), (84, 37)]
    segmentos = list(zip(puntos_rio[:-1], puntos_rio[1:]))

    def dist_rio(px, py):
        mejor = 1e9
        for (a, b) in segmentos:
            ax, ay = a
            bx, by = b
            vx, vy = bx - ax, by - ay
            t = max(0.0, min(1.0, ((px - ax) * vx + (py - ay) * vy) / (vx * vx + vy * vy)))
            mejor = min(mejor, math.hypot(px - (ax + t * vx), py - (ay + t * vy)))
        return mejor

    for y in range(H):
        for x in range(W):
            if 18 <= y <= 38:
                if 30 <= y <= 33:
                    radio = 1.0            # vado: solo 2 de ancho
                elif 24 <= y <= 35:
                    radio = 1.95
                else:
                    radio = 1.95 + (medio(x, y + 80) - 0.5) * 0.9   # fuera del cruce el cauce ondula
                if dist_rio(x + 0.5, y + 0.5) <= radio:
                    m.g[y][x] = "w"
    m.elipse(83.5, 37.5, 4.4, 2.5, "w", irregular=0.3)
    m.elipse(11, 46, 7.2, 4.2, "w", irregular=0.35)      # lago de Tristeza
    for y in (26, 27, 28):                                # puente roto: hueco de 2 tiles
        m.g[y][82], m.g[y][83], m.g[y][84], m.g[y][85] = "P", "q", "w", "Q"

    # 6. caminos: curvos y orgánicos, de 2 a 3 tiles de ancho
    base = [fila[:] for fila in m.g]
    ondas = Ruido(77, 7)

    def catmull(pts, pasos=16):
        res = []
        Pt = [pts[0]] + pts + [pts[-1]]
        for i in range(1, len(Pt) - 2):
            p0, p1, p2, p3 = Pt[i - 1], Pt[i], Pt[i + 1], Pt[i + 2]
            for k in range(pasos):
                t = k / pasos
                t2, t3 = t * t, t * t * t
                res.append(tuple(0.5 * ((2 * p1[j]) + (-p0[j] + p2[j]) * t + (2 * p0[j] - 5 * p1[j] + 4 * p2[j] - p3[j]) * t2 + (-p0[j] + 3 * p1[j] - 3 * p2[j] + p3[j]) * t3) for j in range(2)))
        res.append(pts[-1])
        return res

    def trazar(pts, ondulacion=3.2, semilla=0):
        muestras = catmull([(float(a), float(b)) for a, b in pts])
        n = len(muestras)
        for i, (px, py) in enumerate(muestras):
            s = i / max(1, n - 1)
            # empuje lateral con ruido (nulo en los extremos para que lleguen justo a su sitio)
            if i + 1 < n:
                tx, ty = muestras[i + 1][0] - px, muestras[i + 1][1] - py
            else:
                tx, ty = px - muestras[i - 1][0], py - muestras[i - 1][1]
            largo = math.hypot(tx, ty) or 1.0
            nx, ny = -ty / largo, tx / largo
            sobre = (math.sin(math.pi * s) ** 0.7) * ondulacion * (ondas(i * 0.09, semilla * 17.0) - 0.5) * 2
            cx, cy = px + nx * sobre, py + ny * sobre
            radio = 1.25 + (ondas(i * 0.07 + 40, semilla * 11.0 + 5) - 0.5) * 0.5   # ancho de 2 a 3 tiles
            m.eje_camino.add((int(round(cx)), int(round(cy))))
            for dy in range(-3, 4):
                for dx in range(-3, 4):
                    x, y = int(round(cx)) + dx, int(round(cy)) + dy
                    # distancia exacta al punto de la curva (sin redondear), así el ancho es parejo
                    if math.hypot(x - cx, y - cy) <= radio:
                        if dentro(x, y) and m.g[y][x] in SUELO and m.g[y][x] != "T":
                            m.g[y][x] = "c"

    trazar([(48, 27), (62, 26), (72, 21), (76, 14), (80, 12)], 2.4, semilla=1)          # Rabia
    trazar([(48, 27), (60, 25), (72, 26), (81, 27)], 1.2, semilla=2)                   # Culpa: hasta el puente roto
    trazar([(86, 27), (87, 27), (88, 27)], 0.0, semilla=3)                              # Culpa: orilla este
    trazar([(52, 29), (62, 33), (72, 33), (80, 31)], 1.4, semilla=4)                   # Culpa: hacia el vado
    trazar([(86, 31), (87, 30), (88, 27)], 0.0, semilla=5)                              # Culpa: salida del vado
    trazar([(48, 27), (52, 36), (60, 43), (70, 44), (78, 44)], 2.4, semilla=6)          # Ansiedad
    trazar([(48, 27), (48, 34), (47, 41), (48, 48)], semilla=7)                         # Miedo
    trazar([(48, 27), (44, 35), (34, 41), (24, 42), (16, 42)], 2.4, semilla=8)          # Tristeza
    trazar([(48, 27), (36, 28), (24, 27), (15, 27), (11, 27)], semilla=9)                # Soledad
    trazar([(48, 27), (42, 20), (32, 14), (22, 12), (16, 12)], 2.4, semilla=10)         # Vergüenza
    trazar([(48, 27), (48, 20), (48, 14), (48, 9), (48, 6)], 1.6, semilla=11)           # Reflejo

    # suavizado: filtro de mayoría en un círculo de radio 2 (redondea los escalones de los bordes)
    disco = [(dx, dy) for dy in range(-2, 3) for dx in range(-2, 3) if math.hypot(dx, dy) <= 2.1]
    for _ in range(3):
        nuevo = [fila[:] for fila in m.g]
        for y in range(2, H - 2):
            for x in range(2, W - 2):
                if m.g[y][x] not in SUELO or m.g[y][x] == "T":
                    continue
                dentro_c = sum(1 for dx, dy in disco if m.g[y + dy][x + dx] == "c")
                if m.g[y][x] != "c" and dentro_c >= 11:
                    nuevo[y][x] = "c"
                elif m.g[y][x] == "c" and dentro_c <= 7 and base[y][x] in SUELO:
                    nuevo[y][x] = base[y][x]
        m.g = nuevo
    for y in range(H):
        for x in range(W):
            if m.g[y][x] == "c":
                m.camino.add((x, y))

    # 7. arena solo alrededor del agua (la orilla es irregular, nada de parches sueltos)
    agua = [(x, y) for y in range(H) for x in range(W) if m.g[y][x] in AGUA]
    for (x, y) in agua:
        radio = (1.3 if (x, y) in agua_borde else 1.9) + (medio(x, y + 33) - 0.5) * 0.9
        for dy in range(-3, 4):
            for dx in range(-3, 4):
                if math.hypot(dx, dy) <= radio:
                    m.put(x + dx, y + dy, "s", HIERBAS | set("ruvab"))

    # estanques pequeños en claros vacíos (lejos de caminos y zonas)
    cerca_camino = set()
    for (x, y) in m.camino | m.eje_camino:
        for dy in range(-6, 7):
            for dx in range(-6, 7):
                cerca_camino.add((x + dx, y + dy))
    centros = list(ZONAS.values())
    for (cx, cy, rx, ry) in ((30, 19, 3.0, 2.0), (66, 36, 2.8, 1.8), (34, 10, 2.6, 1.7), (62, 7, 2.6, 1.7), (28, 46, 2.8, 1.8), (68, 21, 2.4, 1.6)):
        if (cx, cy) in cerca_camino or any(math.hypot(cx - a, cy - b) < 11 for a, b in centros):
            continue
        for y in range(cy - 4, cy + 5):
            for x in range(cx - 5, cx + 6):
                if dentro(x, y) and m.g[y][x] in ".fd" and math.hypot((x - cx) / rx, (y - cy) / ry) <= 1.0 + (medio(x, y) - 0.5) * 0.4:
                    m.g[y][x] = "w"
        for y in range(cy - 6, cy + 7):
            for x in range(cx - 7, cx + 8):
                if dentro(x, y) and m.g[y][x] in ".fd" and any(m.g[y + j][x + i] == "w" for i in (-1, 0, 1) for j in (-1, 0, 1) if dentro(x + i, y + j)):
                    m.g[y][x] = "s"

    # 9. colinas elevadas: la de Soledad (entrada al este) y el volcán de Rabia (entrada al suroeste)
    def meseta(cx, cy, rx, ry, suelo, grosor=2.3):
        """Meseta elevada: anillo de acantilado de 2 tiles de alto con sombra; se deja abierto donde pasa el camino."""
        interior = set()
        for y in range(H):
            for x in range(W):
                d = math.hypot((x - cx) / rx, (y - cy) / ry) + (medio(x + 10, y + 60) - 0.5) * 0.18
                if d < 1.0:
                    interior.add((x, y))
        libres_camino = set()
        for (x, y) in m.camino:
            for dy in range(-1, 2):
                for dx in range(-1, 2):
                    libres_camino.add((x + dx, y + dy))
        for y in range(H):
            for x in range(W):
                if (x, y) in interior:
                    if m.g[y][x] in ".fdTsbu":
                        m.g[y][x] = suelo
                    continue
                if (x, y) in libres_camino or m.g[y][x] in "wcRMP":
                    continue
                # ¿está a menos de 'grosor' tiles del interior?
                if any(math.hypot(dx, dy) <= grosor and (x + dx, y + dy) in interior
                       for dy in range(-3, 4) for dx in range(-3, 4)):
                    m.g[y][x] = "C"

    meseta(12, 27, 5.0, 4.4, "f")
    meseta(80, 12, 8.6, 6.4, "v")

    # 8. obstáculos (lejos de los caminos y de los centros de zona)
    cerca = set()
    for (x, y) in m.camino | m.eje_camino:
        for dy in range(-2, 3):
            for dx in range(-2, 3):
                cerca.add((x + dx, y + dy))

    def libre(x, y, margen=3.2):
        if not dentro(x, y) or (x, y) in cerca:
            return False
        return all(math.hypot(x - cx, y - cy) > margen for cx, cy in centros)

    # Rabia: roca volcánica
    cand = [(x, y) for y in range(H) for x in range(W) if m.g[y][x] in "vr" and libre(x, y, 3.5)]
    m.rnd.shuffle(cand)
    for (x, y) in cand[:30]:
        m.g[y][x] = "R"
    cand = [(x, y) for y in range(H) for x in range(W) if m.g[y][x] == "b" and libre(x, y, 4.0)]
    m.rnd.shuffle(cand)
    for (x, y) in cand[:12]:
        m.g[y][x] = "R"
    cand = [(x, y) for y in range(H) for x in range(W) if m.g[y][x] == "s" and 6 <= x <= 26 and 36 <= y <= 50 and libre(x, y, 4.0)]
    m.rnd.shuffle(cand)
    for (x, y) in cand[:7]:
        m.g[y][x] = "R"
    # Culpa: muros de ruinas rotos (segmentos con huecos)
    for (x0, y0, dx, dy, largo) in ((90, 22, 1, 0, 5), (94, 23, 0, 1, 3), (88, 31, 1, 0, 6), (92, 29, 0, 1, 3), (86, 24, 0, 1, 2), (90, 33, 0, 1, 2)):
        for k in range(largo):
            x, y = x0 + dx * k, y0 + dy * k
            if dentro(x, y) and m.g[y][x] in "ud" and libre(x, y, 2.6) and m.rnd.random() < 0.8:
                m.g[y][x] = "M"
    # Ansiedad: pilares repartidos por el borde de la plaza (en círculo, no en rejilla)
    for k in range(7):
        a = k * math.tau / 7 + 0.4
        x, y = round(78 + 8.6 * math.cos(a)), round(44 + 5.6 * math.sin(a))
        if dentro(x, y) and m.g[y][x] in "a.fdusb" and (x, y) not in cerca:
            m.g[y][x] = "M"
    # Vergüenza: pilares en un círculo alrededor de la plaza redonda
    for k in range(8):
        a = k * math.tau / 8 + 0.2
        x, y = round(16 + 7.4 * math.cos(a)), round(12 + 5.6 * math.sin(a))
        if dentro(x, y) and m.g[y][x] in ".fda" and (x, y) not in cerca:
            m.g[y][x] = "M"

    # 10. los centros de zona y el hub deben ser transitables
    for (cx, cy) in centros:
        if m.g[cy][cx] in BLOQUEA or m.g[cy][cx] == "w":
            m.g[cy][cx] = "."
    return m


# ----------------------------------------------------------------------------
def profunda(m, x, y):
    """Agua profunda: una celda 'w' con las 8 vecinas también agua (ahí hay colisión)."""
    if m.get(x, y) != "w":
        return False
    return all(m.get(x + dx, y + dy) in AGUA or not dentro(x + dx, y + dy) for dx in (-1, 0, 1) for dy in (-1, 0, 1))


def transitable(m, x, y):
    if not dentro(x, y):
        return False
    ch = m.g[y][x]
    if ch in BLOQUEA:
        return False
    if ch == "w" and profunda(m, x, y):
        return False
    return True


def alcanzables(m, origen):
    visto = {origen}
    cola = deque([origen])
    while cola:
        x, y = cola.popleft()
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            n = (x + dx, y + dy)
            if n not in visto and transitable(m, *n):
                visto.add(n)
                cola.append(n)
    return visto


def ancho_libre(m, x, y):
    """¿Hay un hueco de 2x2 transitable que contenga la celda? (el jugador cabe)."""
    for ox in (0, -1):
        for oy in (0, -1):
            if all(transitable(m, x + ox + i, y + oy + j) for i in (0, 1) for j in (0, 1)):
                return True
    return False


def verificar(m):
    hub = ZONAS["Hub"]
    ok = True
    alc = alcanzables(m, hub)
    for nombre, (x, y) in ZONAS.items():
        r = (x, y) in alc and ancho_libre(m, x, y)
        print("  %-10s (%2d,%2d): %s" % (nombre, x, y, "alcanzable" if r else "NO ALCANZABLE"))
        ok &= r
    # los caminos no deben cruzar celdas bloqueadas ni quedar estrechos
    estrechos = [(x, y) for (x, y) in m.eje_camino if dentro(x, y) and m.g[y][x] == "c" and not ancho_libre(m, x, y)]
    print("  celdas de camino estrechas:", len(estrechos))
    total = sum(1 for y in range(H) for x in range(W) if transitable(m, x, y))
    aislado = sum(1 for y in range(H) for x in range(W) if transitable(m, x, y) and (x, y) not in alc)
    print("  celdas transitables: %d  (%d desconectadas del hub)" % (total, aislado))
    # el puente roto debe seguir impidiendo el paso directo, pero el vado lo permite
    return ok and not estrechos


def escribir_vista(m, ruta):
    from PIL import Image
    colores = {".": (150, 150, 80), "f": (190, 150, 170), "d": (200, 180, 100), "r": (170, 80, 60), "v": (70, 50, 70),
               "b": (50, 50, 80), "u": (170, 160, 140), "a": (180, 170, 175), "c": (200, 150, 100), "s": (230, 215, 160),
               "w": (80, 120, 190), "R": (110, 90, 105), "C": (90, 70, 95), "M": (140, 130, 150), "P": (150, 100, 60),
               "q": (170, 110, 60), "Q": (170, 110, 60), "X": (255, 0, 0), "T": (40, 90, 50)}
    esc = 10
    img = Image.new("RGB", (W * esc, H * esc))
    px = img.load()
    for y in range(H):
        for x in range(W):
            col = colores[m.g[y][x]]
            if m.g[y][x] == "w" and profunda(m, x, y):
                col = (40, 70, 140)
            for dy in range(esc):
                for dx in range(esc):
                    px[x * esc + dx, y * esc + dy] = col
    for nombre, (cx, cy) in ZONAS.items():
        for k in range(-4, 5):
            for t in (-1, 0):
                for (X, Y) in ((cx * esc + esc // 2 + k, cy * esc + esc // 2 + t), (cx * esc + esc // 2 + t, cy * esc + esc // 2 + k)):
                    if 0 <= X < img.width and 0 <= Y < img.height:
                        px[X, Y] = (255, 255, 0)
    img.save(ruta)
    print("Vista guardada:", ruta)


def main():
    args = sys.argv[1:]
    m = construir()
    print("Comprobando que el mapa sea transitable...")
    bien = verificar(m)
    filas = ["".join(f) for f in m.g]
    assert all(len(f) == W for f in filas) and len(filas) == H
    ruta = os.path.join(RAIZ, "Resources", "Mundo", "mapa.txt")
    os.makedirs(os.path.dirname(ruta), exist_ok=True)
    with open(ruta, "w", encoding="utf-8", newline="\n") as f:
        f.write(LEYENDA + "\n".join(filas) + "\n")
    print("Mapa escrito:", ruta)
    if "--vista" in args:
        escribir_vista(m, args[args.index("--vista") + 1])
    if not bien:
        print("ATENCIÓN: hay zonas no alcanzables o caminos estrechos")
        sys.exit(1)


if __name__ == "__main__":
    main()
