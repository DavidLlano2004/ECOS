"""Compuertas de habilidad del mapa (prompt 4.5): cercan tres zonas y dejan UN hueco tapado por una compuerta.

  puente_rabia     Rabia      puente roto sobre un barranco   Reparar (la da Culpa)
  roca_verguenza   Vergüenza  roca grande                     Impulso (la da Rabia)
  zarzal_ansiedad  Ansiedad   zarzal oscuro                   Visión  (la da Miedo)

Culpa, Miedo, Tristeza, Soledad y la Puerta del Reflejo quedan libres. El orden no tiene ciclos:
Culpa (libre) -> Rabia -> Vergüenza, y Miedo (libre) -> Ansiedad.

Cada cierre es una banda elíptica de 3 casillas de muro alrededor de la zona. El hueco es el trozo de
camino que cruza la banda (más 1 casilla a cada lado). Las casillas del hueco las tapa la compuerta
(colisión por casilla); todo lo demás de la banda es sólido de verdad, así que no se puede rodear.
"""
import json
import math
import os
from collections import deque

GROSOR = 3.0
SOLIDOS_BASE = set("CRMXTwBX")

CIERRES = [
    {"id": "puente_rabia", "tipo": "puente", "zona": "Rabia", "centro": (80, 12), "rx": 9.0, "ry": 6.8, "muro": "C",
     "habilidad": "reparacion", "emocion": "culpa"},
    {"id": "roca_verguenza", "tipo": "roca", "zona": "Verguenza", "centro": (16, 12), "rx": 12.5, "ry": 8.5, "muro": "R",
     "habilidad": "impulso", "emocion": "rabia"},
    {"id": "zarzal_ansiedad", "tipo": "zarzal", "zona": "Ansiedad", "centro": (78, 44), "rx": 11.0, "ry": 7.0, "muro": "T",
     "habilidad": "vision", "emocion": "miedo"},
]
# Qué zona es la de cada emoción (para el grafo de dependencias)
ZONA_DE = {"rabia": "Rabia", "miedo": "Miedo", "tristeza": "Tristeza", "soledad": "Soledad", "culpa": "Culpa",
           "ansiedad": "Ansiedad", "verguenza": "Verguenza"}


def _en_banda(c, x, y):
    cx, cy = c["centro"]
    d = math.hypot((x - cx) / c["rx"], (y - cy) / c["ry"])
    return 1.0 <= d < 1.0 + GROSOR / ((c["rx"] + c["ry"]) / 2.0)


def _componentes(celdas):
    resto, comps = set(celdas), []
    while resto:
        ini = resto.pop()
        comp, cola = {ini}, deque([ini])
        while cola:
            x, y = cola.popleft()
            for dx in (-1, 0, 1):
                for dy in (-1, 0, 1):
                    n = (x + dx, y + dy)
                    if n in resto:
                        resto.discard(n)
                        comp.add(n)
                        cola.append(n)
        comps.append(comp)
    return comps


def estampar(m, W, H, TILE):
    """Levanta los tres cierres en el mapa y devuelve la lista de compuertas (con sus casillas)."""
    resultado = []
    for c in CIERRES:
        banda = [(x, y) for y in range(H) for x in range(W) if _en_banda(c, x, y)]
        paso = {(x, y) for (x, y) in banda if m.g[y][x] == "c"}
        if not paso:
            raise SystemExit("La compuerta %s: el camino no cruza la banda del cierre." % c["id"])
        hueco = {(x, y) for (x, y) in banda
                 if m.g[y][x] not in SOLIDOS_BASE and any((x + dx, y + dy) in paso for dx in (-1, 0, 1) for dy in (-1, 0, 1))}
        comps = _componentes(hueco)
        if len(comps) != 1:
            # Si otro camino cruza la banda, se deja solo el hueco más grande y el otro se tapa con muro
            comps.sort(key=len, reverse=True)
            print("  AVISO %s: %d huecos; se queda el mayor" % (c["id"], len(comps)))
            hueco = comps[0]
            paso = {p for p in paso if p in hueco}
        for (x, y) in banda:
            if (x, y) not in hueco and m.g[y][x] not in SOLIDOS_BASE and m.g[y][x] != "P":
                m.g[y][x] = c["muro"]
        cx = sum(p[0] for p in hueco) / len(hueco) + 0.5
        cy = sum(p[1] for p in hueco) / len(hueco) + 0.5
        vx, vy = cx - c["centro"][0], cy - c["centro"][1]
        cruza = "h" if abs(vx) > abs(vy) else "v"   # por dónde se cruza (la dirección del camino)
        resultado.append({
            "id": c["id"], "tipo": c["tipo"], "zona": c["zona"], "habilidad": c["habilidad"], "emocion": c["emocion"],
            "celdas": sorted(hueco), "paso": sorted(paso), "cruza": cruza,
            "centro": [cx * TILE, cy * TILE],
        })
    return resultado


def escribir_json(compuertas, ruta):
    salida = []
    for c in compuertas:
        d = dict(c)
        d["celdas"] = [list(p) for p in c["celdas"]]
        d["paso"] = [list(p) for p in c["paso"]]
        salida.append(d)
    os.makedirs(os.path.dirname(ruta), exist_ok=True)
    with open(ruta, "w", encoding="utf-8", newline="\n") as f:
        json.dump({"compuertas": salida}, f, indent=1)


# ----------------------------------------------------------------------------
# Comprobación física: cada 8 px con la caja real de los pies del jugador (14x8, de y-8 a y)

PASO = 8
CAJA_X, CAJA_ARRIBA = 7, 8


def _solido_px(m, W, H, TILE, bloqueadas, px, py):
    """¿Hay un tile sólido (o casilla de compuerta cerrada) en el punto (px, py)?"""
    x, y = int(px // TILE), int(py // TILE)
    if not (0 <= x < W and 0 <= y < H):
        return True
    ch = m.g[y][x]
    return ch in "CRMXTw" or (x, y) in bloqueadas


def alcance_fisico(m, W, H, TILE, bloqueadas, origen_px):
    """Todas las posiciones (rejilla de 8 px) que el jugador alcanza desde origen_px."""
    def cabe(px, py):
        for ox in (-CAJA_X, CAJA_X - 0.01):
            for oy in (-CAJA_ARRIBA, -0.01):
                if _solido_px(m, W, H, TILE, bloqueadas, px + ox, py + oy):
                    return False
        return True

    ini = (int(origen_px[0] // PASO), int(origen_px[1] // PASO))
    if not cabe(ini[0] * PASO, ini[1] * PASO):
        return set()
    visto, cola = {ini}, deque([ini])
    while cola:
        a, b = cola.popleft()
        for da, db in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            n = (a + da, b + db)
            if n not in visto and cabe(n[0] * PASO, n[1] * PASO):
                visto.add(n)
                cola.append(n)
    return visto


def casillas_cerradas(compuertas, abiertas):
    """Casillas con colisión según qué compuertas están abiertas (el puente abierto deja libre solo su paso)."""
    s = set()
    for c in compuertas:
        celdas = {tuple(p) for p in c["celdas"]}
        if c["id"] not in abiertas:
            s |= celdas
        elif c["tipo"] == "puente":
            s |= celdas - {tuple(p) for p in c["paso"]}
    return s


def verificar(m, W, H, TILE, ZONAS, compuertas):
    """Imprime y devuelve True si se cumple todo lo pedido: alcance con cada conjunto de compuertas,
    grafo sin ciclos y nadie encerrado."""
    from itertools import combinations
    ok = True
    hub = ZONAS["Hub"]
    origen = ((hub[0] + 0.5) * TILE, (hub[1] + 0.5) * TILE + 56)
    ids = [c["id"] for c in compuertas]

    def zonas_alcanzadas(abiertas):
        alc = alcance_fisico(m, W, H, TILE, casillas_cerradas(compuertas, abiertas), origen)
        res = set()
        for nombre, (zx, zy) in ZONAS.items():
            if (int((zx + 0.5) * TILE // PASO), int((zy + 0.5) * TILE // PASO)) in alc:
                res.add(nombre)
        return res, alc

    libres = {"Hub", "Final", "Tristeza", "Soledad", "Miedo", "Culpa"}
    sin, alc_sin = zonas_alcanzadas(set())
    bien = sin == libres
    print("  sin ninguna habilidad se llega a: %s" % ", ".join(sorted(sin)))
    print("    -> libres alcanzadas, Rabia/Vergüenza/Ansiedad NO: %s" % ("SI" if bien else "NO (mal)"))
    ok &= bien
    for c in compuertas:
        z, _ = zonas_alcanzadas({c["id"]})
        extra = z - libres
        esperado = {c["zona"]}
        # Con solo esa compuerta abierta se alcanza su zona (y nada más de las cerradas)
        bien = extra == esperado
        print("  con %-9s (%s): zonas nuevas %s %s" % (c["habilidad"], c["id"], sorted(extra), "bien" if bien else "(mal)"))
        ok &= bien
    # Ninguna combinación encierra al jugador: todo lo alcanzable vuelve al hub (la rejilla es simétrica,
    # así que basta con comprobar que no hay casillas de camino alcanzables solo de ida: se comprueba el
    # origen desde cada zona alcanzada)
    for n in range(len(ids) + 1):
        for comb in combinations(ids, n):
            z, alc = zonas_alcanzadas(set(comb))
            vuelve = True
            for nombre in z:
                zx, zy = ZONAS[nombre]
                desde = ((zx + 0.5) * TILE, (zy + 0.5) * TILE)
                a2 = alcance_fisico(m, W, H, TILE, casillas_cerradas(compuertas, set(comb)), desde)
                if (int(origen[0] // PASO), int(origen[1] // PASO)) not in a2:
                    vuelve = False
            print("  abiertas %-45s -> %d zonas, siempre puede volver al hub: %s" % (list(comb), len(z), "si" if vuelve else "NO (mal)"))
            ok &= vuelve
    # Grafo de dependencias: cada compuerta pide una habilidad que da una emoción en una zona alcanzable
    # ANTES de abrirla (sin ciclos): se va ganando alcance paso a paso hasta alcanzarlo todo.
    abiertas, zonas = set(), set(libres)
    orden = []
    avanza = True
    while avanza:
        avanza = False
        for c in compuertas:
            if c["id"] in abiertas:
                continue
            if ZONA_DE[c["emocion"]] in zonas:
                abiertas.add(c["id"])
                zonas.add(c["zona"])
                orden.append("%s (da %s) abre %s" % (ZONA_DE[c["emocion"]], c["habilidad"], c["zona"]))
                avanza = True
    todo = len(abiertas) == len(compuertas)
    print("  grafo (orden de apertura): %s" % " -> ".join(orden))
    print("  el grafo se resuelve sin ciclos ni bucles imposibles: %s" % ("SI" if todo else "NO (mal)"))
    ok &= todo
    return ok
