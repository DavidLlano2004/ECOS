"""Santuarios (prompt 4.6): un claro cerrado en el centro de cada una de las 7 zonas de emoción.

Cada santuario es un círculo despejado (radio de unas 3 casillas) rodeado por un anillo de acantilado
('C') de 2 casillas, con UN solo acceso: el camino de la zona que cruza el anillo. En el Presente, el
bloqueo de la emoción se coloca justo en ese acceso y sella sus casillas (colisión) mientras no esté
integrada, así que el santuario solo se alcanza con el bloqueo abierto. En el Pasado el acceso está
libre (ahí vive la criatura).

Escribe Resources/Mundo/santuarios.json con: zona, centro, abertura (centro del acceso en px), dirección
hacia el centro y las casillas del acceso (el "sello").
"""
import json
import math
import os
from collections import deque

RADIO_CLARO = 3.2      # casillas: el claro
GROSOR = 2.2           # casillas: el anillo de acantilado
ZONAS_EMOCION = ["Rabia", "Miedo", "Tristeza", "Soledad", "Culpa", "Ansiedad", "Verguenza"]
IDS = {"Rabia": "rabia", "Miedo": "miedo", "Tristeza": "tristeza", "Soledad": "soledad", "Culpa": "culpa",
       "Ansiedad": "ansiedad", "Verguenza": "verguenza"}
INTERIOR_A_LIMPIAR = set("wCRMXT")    # lo que estorba dentro del claro
SOLIDOS = set("CRMXTw")


def _comps(celdas):
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


def estampar(m, ZONAS, W, H, TILE):
    """Levanta los 7 santuarios y devuelve su lista de datos."""
    res = []
    for zona in ZONAS_EMOCION:
        cx, cy = ZONAS[zona]
        banda, interior = [], []
        for y in range(H):
            for x in range(W):
                d = math.hypot(x - cx, y - cy)
                if d <= RADIO_CLARO:
                    interior.append((x, y))
                elif d <= RADIO_CLARO + GROSOR:
                    banda.append((x, y))
        # El camino: casillas 'c' y, donde el camino pasa sobre una plaza ('a'), la línea del camino +-1 casilla
        eje = m.eje_camino
        paso = {(x, y) for (x, y) in banda if m.g[y][x] == "c"
                or (m.g[y][x] == "a" and any((x + i, y + j) in eje for i in (-1, 0, 1) for j in (-1, 0, 1)))}
        if not paso:
            raise SystemExit("Santuario %s: ningún camino cruza el anillo." % zona)
        comps = sorted(_comps(paso), key=len, reverse=True)
        if len(comps) > 1:
            print("  AVISO santuario %s: %d accesos; se queda el mayor" % (zona, len(comps)))
        acceso = comps[0]
        for (x, y) in interior:
            if m.g[y][x] in INTERIOR_A_LIMPIAR:
                m.g[y][x] = "."
        for (x, y) in banda:
            if (x, y) in acceso:
                continue
            if m.g[y][x] in "PqQ":
                continue
            m.g[y][x] = "C"
        ax = sum(p[0] for p in acceso) / len(acceso) + 0.5
        ay = sum(p[1] for p in acceso) / len(acceso) + 0.5
        dx, dy = (cx + 0.5) - ax, (cy + 0.5) - ay
        largo = math.hypot(dx, dy) or 1.0
        res.append({
            "zona": zona, "id": IDS[zona],
            "centro": [(cx + 0.5) * TILE, (cy + 0.5) * TILE],
            "abertura": [ax * TILE, ay * TILE],
            "direccion": [dx / largo, dy / largo],
            "celdas": [list(p) for p in sorted(acceso)],
        })
    return res


def escribir_json(santuarios, ruta):
    os.makedirs(os.path.dirname(ruta), exist_ok=True)
    with open(ruta, "w", encoding="utf-8", newline="\n") as f:
        json.dump({"santuarios": santuarios}, f, indent=1)


def verificar(m, W, H, TILE, ZONAS, compuertas, santuarios):
    """Con la física de rejilla de 8 px y todas las compuertas abiertas: con el sello cerrado el santuario
    NO se alcanza; con el sello abierto, sí (y hay sitio de sobra dentro)."""
    import compuertas_mapa as cm
    ok = True
    hub = ZONAS["Hub"]
    origen = ((hub[0] + 0.5) * TILE, (hub[1] + 0.5) * TILE + 56)
    todas = {c["id"] for c in compuertas}
    base = cm.casillas_cerradas(compuertas, todas)
    sellos = {s["zona"]: {tuple(p) for p in s["celdas"]} for s in santuarios}
    todos_sellos = set().union(*sellos.values())

    def llega(bloq, px):
        alc = cm.alcance_fisico(m, W, H, TILE, bloq, origen)
        return (int(px[0] // cm.PASO), int(px[1] // cm.PASO)) in alc, alc

    for s in santuarios:
        centro = tuple(s["centro"])
        cerrado, _ = llega(base | todos_sellos, centro)
        abierto, alc = llega(base | (todos_sellos - sellos[s["zona"]]), centro)
        # Sitio dentro del claro (posiciones de 8 px a menos de 3 casillas del centro)
        dentro = sum(1 for (a, b) in alc if math.hypot(a * cm.PASO - centro[0], b * cm.PASO - centro[1]) <= 3 * TILE)
        bien = (not cerrado) and abierto and dentro > 150
        print("  santuario %-9s sellado: %-12s abierto: %-9s posiciones libres en el claro: %d  %s" % (
            s["zona"], "inalcanzable" if not cerrado else "ALCANZABLE (mal)", "alcanzable" if abierto else "NO (mal)", dentro,
            "bien" if bien else "(mal)"))
        ok &= bien
    return ok
