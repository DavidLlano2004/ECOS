#!/usr/bin/env python3
"""Genera el primer borrador del mapa de ECOS (96x54 tiles) y comprueba que sea transitable.

Escribe:
  Resources/Mundo/mapa.txt        un carácter por tile (se edita a mano; ver la leyenda en el archivo)
  Scenes/Mundo/Mundo.tscn         solo con --escena (Marker2D de zonas y de decoración)

Uso:
  python tools/generar_mapa.py            # solo el mapa
  python tools/generar_mapa.py --escena   # mapa + escena (SOBREESCRIBE Mundo.tscn)
  python tools/generar_mapa.py --vista C:/ruta/vista.png   # además guarda una imagen de revisión

Una vez que edites el mapa o la escena a mano, no vuelvas a usar --escena.
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
;   X  bloqueo invisible
;
"""

BLOQUEA = set("CRMX")
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


def construir():
    m = Mapa()
    SUELO = set(".fdrvbua")
    HIERBAS = set(".fd")

    # 1. variedad de suelo: manchas de flores y de pasto seco
    for y in range(H):
        for x in range(W):
            n, n2 = m.ruido(x, y), m.ruido2(x + 40, y + 70)
            if n > 0.70 and m.rnd.random() < 0.5:
                m.g[y][x] = "f"
            elif n2 > 0.70 and m.rnd.random() < 0.7:
                m.g[y][x] = "d"

    # 2. suelos de cada zona
    # Rabia: tierra roja con núcleo volcánico
    m.elipse(80, 12, 10.5, 8.0, "r")
    m.elipse(80, 12, 6.8, 5.2, "v")
    # Culpa: pasto seco y ruinas
    m.elipse(88, 27, 10.5, 8.0, "d", HIERBAS)
    m.elipse(88, 27, 7.0, 5.5, "u")
    # Ansiedad: plaza de adoquines con borde de ruinas
    for y in range(40, 49):
        for x in range(71, 86):
            m.put(x, y, "a")
    # Miedo: bosque oscuro
    m.elipse(48, 48, 10.5, 7.2, "b")
    # Soledad: pasto seco alrededor de la colina
    m.elipse(8, 27, 9.5, 7.5, "d", HIERBAS)
    # Vergüenza: jardín con flores y plaza de adoquines en cruz
    m.elipse(16, 12, 9.5, 7.0, "f", HIERBAS)
    for k in range(-6, 7):
        m.put(16 + k, 12, "a")
        m.put(16, 12 + k, "a")
    m.elipse(16, 12, 3.6, 3.6, "a", irregular=0.0)
    # Hub: plaza de adoquines con césped claro alrededor
    m.elipse(48, 27, 9.5, 9.5, "f", HIERBAS, irregular=0.1)
    m.elipse(48, 27, 6.2, 6.2, "a", irregular=0.05)
    # Puerta del Reflejo: plataforma de adoquines
    for y in range(4, 11):
        for x in range(43, 54):
            m.put(x, y, "a")

    # 3. límite natural: acantilados al norte y al este, agua al sur y al oeste
    rn, rs, re_, rw = Ruido(5, 6), Ruido(6, 6), Ruido(7, 6), Ruido(8, 6)
    for y in range(H):
        for x in range(W):
            norte = 3 + int(rn(x, 0) * 2.4)
            este = 3 + int(re_(0, y) * 2.4)
            sur = 2 + int(rs(x, 0) * 2.4)
            oeste = 2 + int(rw(0, y) * 2.2)
            if x >= W - este:
                m.g[y][x] = "C"
            elif y >= H - sur:
                m.g[y][x] = "w"
            elif x < oeste and y >= norte:
                m.g[y][x] = "w"
            elif y < norte:
                m.g[y][x] = "C"
    # el rincón noroeste: acantilado hasta donde empieza el agua
    agua_borde = {(x, y) for y in range(H) for x in range(W) if m.g[y][x] == "w"}
    # 4. ríos y lagos
    # Río de Culpa: nace en los acantilados del este, baja y termina en un estanque. Se estrecha en un vado.
    puntos_rio = [(91, 21.5), (86, 21.5), (84, 22.5), (83.5, 27), (83.5, 31), (84, 35), (83.5, 37)]
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
                radio = 1.0 if 30 <= y <= 33 else 1.95   # vado: solo 2 de ancho
                if dist_rio(x + 0.5, y + 0.5) <= radio:
                    m.g[y][x] = "w"
    m.elipse(83.5, 37.5, 4.2, 2.3, "w", irregular=0.1)
    # Lago de Tristeza
    m.elipse(11, 46, 6.8, 3.9, "w", irregular=0.25)
    # Puente roto sobre el río (en el camino directo del hub a Culpa): hueco de 2 tiles
    for y in (26, 27, 28):
        m.g[y][82], m.g[y][83], m.g[y][84], m.g[y][85] = "P", "q", "w", "Q"

    # arena de orilla alrededor de toda el agua
    agua = [(x, y) for y in range(H) for x in range(W) if m.g[y][x] in AGUA]
    for (x, y) in agua:
        radio = 1.3 if (x, y) in agua_borde else 2.2   # el borde del mapa lleva menos arena que los lagos y ríos
        for dy in range(-2, 3):
            for dx in range(-2, 3):
                if math.hypot(dx, dy) <= radio:
                    m.put(x + dx, y + dy, "s", HIERBAS | set("ruva"))
    # el puente conserva su arena: no hace falta

    # 5. caminos de tierra del hub a cada zona (3 de ancho)
    def catmull(pts, pasos=14):
        res = []
        P = [pts[0]] + pts + [pts[-1]]
        for i in range(1, len(P) - 2):
            p0, p1, p2, p3 = P[i - 1], P[i], P[i + 1], P[i + 2]
            for k in range(pasos):
                t = k / pasos
                t2, t3 = t * t, t * t * t
                res.append(tuple(0.5 * ((2 * p1[j]) + (-p0[j] + p2[j]) * t + (2 * p0[j] - 5 * p1[j] + 4 * p2[j] - p3[j]) * t2 + (-p0[j] + 3 * p1[j] - 3 * p2[j] + p3[j]) * t3) for j in range(2)))
        res.append(pts[-1])
        return res

    def trazar(pts):
        for (px, py) in catmull([(float(a), float(b)) for a, b in pts]):
            m.eje_camino.add((int(round(px)), int(round(py))))
            for dy in range(-2, 3):
                for dx in range(-2, 3):
                    if math.hypot(dx, dy) <= 1.6:
                        x, y = int(round(px)) + dx, int(round(py)) + dy
                        if dentro(x, y) and m.g[y][x] in "." "fdrvbus":
                            m.g[y][x] = "c"
                        if dentro(x, y) and m.g[y][x] in "ca":
                            m.camino.add((x, y))

    trazar([(48, 27), (58, 24), (66, 19), (73, 14), (80, 12)])                # Rabia
    trazar([(48, 27), (60, 27), (72, 27), (81, 27)])                           # Culpa: hasta el puente roto
    trazar([(86, 27), (87, 27), (88, 27)])                                     # Culpa: orilla este
    trazar([(54, 28), (64, 31), (72, 31), (80, 31)])                           # Culpa: hacia el vado
    trazar([(86, 31), (87, 30), (88, 27)])                                     # Culpa: salida del vado
    trazar([(48, 27), (56, 32), (64, 38), (72, 43), (78, 44)])                 # Ansiedad
    trazar([(48, 27), (48, 34), (47, 41), (48, 48)])                           # Miedo
    trazar([(48, 27), (38, 32), (28, 38), (20, 41), (16, 42)])                 # Tristeza
    trazar([(48, 27), (36, 28), (24, 27), (14, 27), (8, 27)])                  # Soledad
    trazar([(48, 27), (38, 22), (28, 16), (20, 13), (16, 12)])                 # Verguenza
    trazar([(48, 27), (48, 20), (48, 14), (48, 9), (48, 5)])                   # Final

    # 6. obstáculos (lejos de los caminos y de los centros de zona)
    cerca_camino = set()
    for (x, y) in m.camino | m.eje_camino:
        for dy in range(-2, 3):
            for dx in range(-2, 3):
                cerca_camino.add((x + dx, y + dy))
    centros = list(ZONAS.values())

    def libre(x, y, margen=3.2):
        if not dentro(x, y) or (x, y) in cerca_camino:
            return False
        return all(math.hypot(x - cx, y - cy) > margen for cx, cy in centros)

    # Rabia: roca volcánica
    cand = [(x, y) for y in range(H) for x in range(W) if m.g[y][x] in "vr" and libre(x, y, 3.5)]
    m.rnd.shuffle(cand)
    for (x, y) in cand[:30]:
        m.g[y][x] = "R"
    # Miedo: algunas rocas en el bosque
    cand = [(x, y) for y in range(H) for x in range(W) if m.g[y][x] == "b" and libre(x, y, 4.0)]
    m.rnd.shuffle(cand)
    for (x, y) in cand[:12]:
        m.g[y][x] = "R"
    # Tristeza: rocas en la orilla del lago
    cand = [(x, y) for y in range(H) for x in range(W) if m.g[y][x] == "s" and 6 <= x <= 26 and 36 <= y <= 50 and libre(x, y, 4.0)]
    m.rnd.shuffle(cand)
    for (x, y) in cand[:7]:
        m.g[y][x] = "R"
    # Culpa: muros de ruinas rotos (segmentos con huecos)
    for (x0, y0, dx, dy, largo) in ((90, 22, 1, 0, 5), (94, 23, 0, 1, 3), (88, 31, 1, 0, 6), (92, 29, 0, 1, 3), (86, 24, 0, 1, 2), (90, 33, 0, 1, 2)):
        for k in range(largo):
            x, y = x0 + dx * k, y0 + dy * k
            if m.g[y][x] in "ud" and libre(x, y, 2.6) and m.rnd.random() < 0.8:
                m.g[y][x] = "M"
    # Ansiedad: pilares en las esquinas y a mitad de cada lado de la plaza
    for (x, y) in ((71, 40), (85, 40), (71, 48), (85, 48), (78, 40), (78, 48)):
        if libre(x, y, 1.0) or (x, y) not in cerca_camino:
            m.g[y][x] = "M"
    # Vergüenza: pilares junto a las cuatro entradas del jardín
    for (x, y) in ((11, 9), (11, 15), (21, 9), (21, 15), (13, 6), (19, 6), (13, 18), (19, 18)):
        if (x, y) not in cerca_camino:
            m.g[y][x] = "M"
    # Puerta del Reflejo: muro con la entrada abierta al sur
    for x in range(42, 55):
        m.g[3][x] = "M"
    for y in range(3, 9):
        m.g[y][42] = "M"
        m.g[y][54] = "M"
    for (x, y) in ((43, 9), (53, 9)):
        m.g[y][x] = "M"
    # Soledad: una colina de acantilados con la entrada hacia el este
    for y in range(H):
        for x in range(W):
            d = math.hypot((x - 8) / 5.6, (y - 27) / 4.6)
            if 0.82 <= d <= 1.12 and not (x >= 8 and abs(y - 27) <= 1):
                if m.g[y][x] not in "wCs":
                    m.g[y][x] = "C"
    # la colina por dentro: hierba con flores
    for y in range(H):
        for x in range(W):
            if math.hypot((x - 8) / 5.6, (y - 27) / 4.6) < 0.82 and m.g[y][x] in "dc.":
                m.g[y][x] = "f" if m.g[y][x] != "c" else "c"

    # 7. los centros de zona y el hub deben ser transitables
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


# ----------------------------------------------------------------------------
def posiciones_decoracion(m):
    rnd = random.Random(77)
    cerca = set()
    for (x, y) in m.camino | m.eje_camino:
        for dy in range(-2, 3):
            for dx in range(-2, 3):
                cerca.add((x + dx, y + dy))

    def lejos_de_centros(x, y, r):
        return all(math.hypot(x - cx, y - cy) > r for cx, cy in ZONAS.values())

    def elegir(cond, cantidad, separacion, semilla_extra=0):
        cand = [(x, y) for y in range(H) for x in range(W) if cond(x, y)]
        rnd.shuffle(cand)
        elegidos = []
        for p in cand:
            if all(math.hypot(p[0] - q[0], p[1] - q[1]) >= separacion for q in elegidos):
                elegidos.append(p)
            if len(elegidos) >= cantidad:
                break
        return elegidos

    ocupado = lambda x, y: m.g[y][x] in BLOQUEA or m.g[y][x] in AGUA or (x, y) in cerca
    margen = lambda x, y: 4 <= x < W - 5 and 4 <= y < H - 6

    arboles = elegir(lambda x, y: m.g[y][x] == "b" and not ocupado(x, y) and lejos_de_centros(x, y, 3.0), 34, 2.4)
    arboles += elegir(lambda x, y: m.g[y][x] in ".fd" and not ocupado(x, y) and margen(x, y) and lejos_de_centros(x, y, 7.0), 56, 4.0)
    arboles += elegir(lambda x, y: m.g[y][x] in "f" and not ocupado(x, y) and 6 <= x <= 26 and 5 <= y <= 19 and lejos_de_centros(x, y, 5.5), 4, 5.0)
    rocas = elegir(lambda x, y: m.g[y][x] in "rvds." and not ocupado(x, y) and margen(x, y) and lejos_de_centros(x, y, 4.0), 24, 3.5)
    farolas = []
    for k in range(6):  # alrededor de la plaza del hub
        a = math.pi * 2 * k / 6 + 0.5
        farolas.append((round(48 + 6.8 * math.cos(a)), round(27 + 6.8 * math.sin(a))))
    farolas += [(46, 8), (50, 8), (13, 12), (19, 12), (16, 9), (16, 15), (74, 41), (82, 41), (87, 24), (80, 14)]
    farolas = [p for p in farolas if dentro(*p) and m.g[p[1]][p[0]] not in BLOQUEA and m.g[p[1]][p[0]] not in AGUA]
    bancos = [(10, 25), (45, 22), (51, 32)]
    arcos = [(12, 8), (20, 8), (12, 16), (20, 16), (16, 6)]
    espejos = [(14, 10), (18, 10), (14, 14), (18, 14), (16, 12)]
    return {"arboles": arboles, "rocas": rocas, "faroles": farolas, "bancos": bancos, "arcos": arcos, "espejos": espejos}


def escribir_escena(m, deco):
    def px(p):
        return (p[0] * TILE + TILE // 2, p[1] * TILE + TILE // 2)

    marcadores = [("Spawn_Hub", ZONAS["Hub"])]
    for nombre in ("Rabia", "Miedo", "Tristeza", "Soledad", "Culpa", "Ansiedad", "Verguenza"):
        marcadores.append(("Zona_" + nombre, ZONAS[nombre]))
    marcadores.append(("Zona_Final", ZONAS["Final"]))

    capas = [
        ("Suelo", False), ("Orilla", False), ("Camino", False), ("Agua", False), ("Colision", False),
    ]
    L = []
    L.append("[gd_scene format=3]\n")
    L.append('[ext_resource type="Script" path="res://Scripts/Mundo/Mundo.gd" id="1_script"]')
    L.append('[ext_resource type="PackedScene" path="res://Scenes/Personajes/Player.tscn" id="2_player"]')
    L.append('[ext_resource type="TileSet" path="res://Resources/Mundo/tileset_pasado.tres" id="3_pasado"]')
    L.append('[ext_resource type="TileSet" path="res://Resources/Mundo/tileset_presente.tres" id="4_presente"]\n')
    L.append('[node name="Mundo" type="Node2D"]')
    L.append('script = ExtResource("1_script")\n')
    for epoca, ts_id, visible in (("Pasado", "3_pasado", True), ("Presente", "4_presente", False)):
        L.append('[node name="%s" type="Node2D" parent="."]' % epoca)
        L.append("y_sort_enabled = true")
        if not visible:
            L.append("visible = false")
        L.append("")
        for nombre, _ in capas:
            L.append('[node name="%s" type="TileMapLayer" parent="%s"]' % (nombre, epoca))
            L.append('tile_set = ExtResource("%s")\n' % ts_id)
        L.append('[node name="Objetos" type="Node2D" parent="%s"]' % epoca)
        L.append("y_sort_enabled = true\n")
        L.append('[node name="Detalles" type="TileMapLayer" parent="%s/Objetos"]' % epoca)
        L.append("y_sort_enabled = true")
        L.append('tile_set = ExtResource("%s")\n' % ts_id)
        if epoca == "Pasado":
            x, y = px(ZONAS["Hub"])
            L.append('[node name="Jugador" parent="Pasado/Objetos" instance=ExtResource("2_player")]')
            L.append("position = Vector2(%d, %d)\n" % (x, y))
    L.append('[node name="Marcadores" type="Node2D" parent="."]\n')
    for nombre, pos in marcadores:
        x, y = px(pos)
        L.append('[node name="%s" type="Marker2D" parent="Marcadores"]' % nombre)
        L.append("position = Vector2(%d, %d)\n" % (x, y))
    L.append('[node name="Decoracion" type="Node2D" parent="."]\n')
    for grupo, titulo, prefijo in (("arboles", "Arboles", "Arbol"), ("rocas", "Rocas", "Roca"), ("faroles", "Faroles", "Farol"),
                                   ("bancos", "Bancos", "Banco"), ("arcos", "Arcos", "Arco"), ("espejos", "Espejos", "Espejo")):
        L.append('[node name="%s" type="Node2D" parent="Decoracion"]\n' % titulo)
        for i, p in enumerate(deco[grupo], 1):
            x, y = px(p)
            L.append('[node name="%s_%02d" type="Marker2D" parent="Decoracion/%s" groups=["%s"]]' % (prefijo, i, titulo, grupo))
            L.append("position = Vector2(%d, %d)\n" % (x, y))
    ruta = os.path.join(RAIZ, "Scenes", "Mundo", "Mundo.tscn")
    with open(ruta, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(L))
    print("Escena escrita:", ruta)


def escribir_vista(m, ruta):
    from PIL import Image
    colores = {".": (150, 150, 80), "f": (190, 150, 170), "d": (200, 180, 100), "r": (170, 80, 60), "v": (70, 50, 70),
               "b": (50, 50, 80), "u": (170, 160, 140), "a": (180, 170, 175), "c": (200, 150, 100), "s": (230, 215, 160),
               "w": (80, 120, 190), "R": (110, 90, 105), "C": (90, 70, 95), "M": (140, 130, 150), "P": (150, 100, 60),
               "q": (170, 110, 60), "Q": (170, 110, 60), "X": (255, 0, 0)}
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
    if "--escena" in args:
        escribir_escena(m, posiciones_decoracion(m))
    if "--vista" in args:
        escribir_vista(m, args[args.index("--vista") + 1])
    if not bien:
        print("ATENCIÓN: hay zonas no alcanzables o caminos estrechos")
        sys.exit(1)


if __name__ == "__main__":
    main()
