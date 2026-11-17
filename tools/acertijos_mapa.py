"""Acertijos de habilidad en el mapa del Presente (lo usa generar_mapa.py).

Excava siete recintos cerrados (muro de acantilado 'C' de 2 tiles) en sitios libres, cada uno en
la zona de una emoción DISTINTA a la que da su habilidad. Cada recinto tiene UNA sola entrada, tapada
por su acertijo, y una rama lateral de camino que lo une a un camino principal (así se llega desde el
hub sin necesitar ninguna habilidad). Dentro hay un fragmento de memoria.

Escribe Resources/Mundo/acertijos.json con lo que Mundo.gd necesita para colocar los objetos (solo en
la época Presente) y las zonas que el Decorador debe dejar libres.

El diseño se hace en coordenadas locales con la entrada al sur; si hace falta, el recinto se voltea
verticalmente (entrada al norte).
"""
import json
import math
import os
from collections import deque

G = 2          # grosor del muro de cada recinto (tiles)
TILE = 32
LIBRES = set(".fdrvbsuaTR")     # suelo donde puede ir un recinto (el muro y el interior); puede comerse
#                                  árboles de la franja del borde o rocas sueltas, el recinto sigue siendo sólido
MARGEN_OK = set(".fdrvbsuacTRC")  # el margen de alrededor puede rozar caminos o sólidos, pero no agua
PARA_RAMA = set(".fdrvbus")     # por donde puede pasar la rama de camino
MARGEN = 1
LARGO_MAX_RAMA = 30
# Recintos que se colocan antes que los demás (los pequeños quedaban sin sitio al final)
ORDEN_PRIMERO = ("culpa", "soledad")

# emoción (de la que sale el fragmento) -> habilidad, zona donde está el acertijo y forma del recinto
ACERTIJOS = [
    dict(emocion="rabia", habilidad="impulso", zona="Verguenza", tipo="roca", iw=4, ih=2, ew=2, suelo="f"),
    dict(emocion="miedo", habilidad="vision", zona="Culpa", tipo="niebla", iw=5, ih=2, ew=3, suelo="b"),
    dict(emocion="tristeza", habilidad="calma", zona="Ansiedad", tipo="plantas", iw=5, ih=2, ew=3, suelo="f"),
    dict(emocion="soledad", habilidad="vinculo", zona="Miedo", tipo="placas", iw=4, ih=2, ew=2, suelo="b"),
    dict(emocion="culpa", habilidad="reparacion", zona="Soledad", tipo="porton", iw=4, ih=2, ew=2, suelo="d"),
    dict(emocion="ansiedad", habilidad="pausa", zona="Rabia", tipo="plataforma", iw=7, ih=6, ew=3, suelo="r"),
    dict(emocion="verguenza", habilidad="revelar", zona="Tristeza", tipo="camino", iw=9, ih=5, ew=3, gap_col=0, suelo="f"),
]


def disenar(a):
    """Diseño de un recinto en píxeles locales, con la entrada al sur (abajo)."""
    iw, ih, ew = a["iw"], a["ih"], a["ew"]
    gcol = a.get("gap_col", (iw - ew) // 2)       # primera columna del hueco, contada desde el interior
    ancho, alto = iw + 2 * G, ih + 2 * G
    cx = (G + gcol + ew / 2.0) * TILE             # centro del hueco (x)
    cy = (G + ih + 1) * TILE                       # mitad del grosor del muro de la entrada (y)
    d = {"ancho": ancho, "alto": alto, "gcol": gcol, "ew": ew, "cx": cx, "cy": cy,
         "objetos": [], "abismos": [], "bloqueo": [], "exterior": [], "fragmento": None}
    hueco = [(G + gcol + i, G + ih + k) for i in range(ew) for k in range(G)]   # celdas del hueco (tiles)
    fx = (G + iw / 2.0) * TILE
    t = a["tipo"]
    if t == "roca":
        d["objetos"].append(dict(escena="RocaRompible", pos=(cx, cy), props={"ancho_colision": ew * TILE}))
        d["bloqueo"] = hueco
        d["fragmento"] = (fx, (G + 0.5) * TILE + 8)
    elif t == "niebla":
        d["objetos"].append(dict(escena="NieblaSombra", pos=(cx, cy), props={"ancho_colision": ew * TILE}))
        d["bloqueo"] = hueco
        d["fragmento"] = (fx, (G + 0.5) * TILE + 8)
    elif t == "plantas":
        for i in range(ew):
            d["objetos"].append(dict(escena="PlantaMarchita", pos=((G + gcol + i + 0.5) * TILE, cy)))
        d["bloqueo"] = hueco
        d["fragmento"] = (fx, (G + 0.5) * TILE + 8)
    elif t == "porton":
        d["objetos"].append(dict(escena="PortonRoto", pos=(cx, cy), props={"ancho_colision": ew * TILE}))
        d["bloqueo"] = hueco
        d["fragmento"] = (fx, (G + 0.5) * TILE + 8)
    elif t == "placas":
        d["objetos"].append(dict(escena="PuertaPlacas", pos=(cx, cy),
                                 props={"ancho": ew * TILE, "id_mecanismo": a["emocion"]}))
        y_ext = (alto + 1) * TILE      # la placa ocupa la fila justo debajo del recinto (origen en su borde de arriba)
        for lado in (-1, 1):
            d["objetos"].append(dict(escena="PlacaDoble", pos=(cx + lado * 2 * TILE, y_ext),
                                     props={"id_mecanismo": a["emocion"]}))
            d["exterior"].append((int((cx + lado * 2 * TILE) // TILE), alto + 1))
        d["bloqueo"] = hueco
        d["fragmento"] = (fx, (G + 0.5) * TILE + 8)
    elif t == "plataforma":
        # de arriba abajo: zona del fragmento (2 filas), abismo (2 filas), antesala (2 filas)
        fila_abismo = G + 2
        zona = (G * TILE, fila_abismo * TILE, iw * TILE, 2 * TILE)
        d["abismos"].append(zona)
        d["bloqueo"] = [(G + c, fila_abismo + k) for c in range(iw) for k in range(2)]
        d["objetos"].append(dict(escena="PlataformaMovil", pos=(G * TILE + iw * TILE / 2.0, fila_abismo * TILE),
                                 props={"x_min": G * TILE + 47.0, "x_max": (G + iw) * TILE - 47.0,
                                        "velocidad": 150.0, "alto_soporte": 64.0}))
        d["fragmento"] = (fx, (G + 1.0) * TILE + 8)
    elif t == "camino":
        # de izquierda a derecha: antesala (3 columnas), ravina (3) y claro (3)
        col_ravina = G + 3
        zona = (col_ravina * TILE, G * TILE, 3 * TILE, ih * TILE)
        d["abismos"].append(zona)
        d["bloqueo"] = [(col_ravina + c, G + r) for c in range(3) for r in range(ih)]
        y_puente = (G + (ih - 2) / 2.0) * TILE
        d["objetos"].append(dict(escena="CaminoOculto", pos=((col_ravina + 1.5) * TILE, y_puente),
                                 props={"ancho_soporte": 96.0, "alto_soporte": 64.0}))
        d["fragmento"] = ((G + 7.5) * TILE, (G + ih / 2.0) * TILE + 8)
    return d


def _voltear_y(y, alto):
    return alto * TILE - y


def en_mundo(d, x0, y0, volteado):
    """Pasa el diseño local (px) a coordenadas del mundo (px) según el ancla (tiles) y la orientación."""
    alto = d["alto"]
    ox, oy = x0 * TILE, y0 * TILE

    def pos(p):
        x, y = p
        return [ox + x, oy + (_voltear_y(y, alto) if volteado else y)]

    def rect(r):
        x, y, w, h = r
        ny = _voltear_y(y + h, alto) if volteado else y
        return [ox + x, oy + ny, w, h]

    salida = {"objetos": [], "abismos": [rect(r) for r in d["abismos"]], "fragmento": pos(d["fragmento"])}
    for o in d["objetos"]:
        props = dict(o.get("props", {}))
        for clave in ("x_min", "x_max"):
            if clave in props:
                props[clave] += ox
        salida["objetos"].append({"escena": o["escena"], "pos": pos(o["pos"]), "props": props})
    return salida


def celdas_a_mundo(celdas, d, x0, y0, volteado):
    alto = d["alto"]
    return [(x0 + c, y0 + ((alto - 1 - r) if volteado else r)) for (c, r) in celdas]


def estampar(m, zonas, W, H, dentro, transitable):
    """Excava los recintos en el mapa `m` y devuelve la lista de especificaciones (para el JSON).

    Cada recinto va en la zona (la más cercana) que NO sea la de la emoción que da su habilidad, a
    una distancia razonable de su centro, lejos del hub, de la Puerta del Reflejo y de los centros de
    zona (ahí van portales y bloqueos). Se prefiere la zona asignada y repartir entre zonas."""
    ocupado = set()   # celdas reservadas por recintos ya puestos (con margen)
    especificaciones = []
    usadas = {}       # cuántos acertijos hay ya en cada zona
    centros_emocion = {n: v for n, v in zonas.items() if n not in ("Hub", "Final")}
    # los recintos grandes primero, que son los que más cuesta colocar
    for a in sorted(ACERTIJOS, key=lambda x: (x["emocion"] not in ORDEN_PRIMERO, -((x["iw"] + 2 * G) * (x["ih"] + 2 * G)))):
        d = disenar(a)
        propia = a["emocion"].capitalize()      # la zona de su propia emoción: ahí NO puede ir
        mejor = None
        # Primero con la distancia normal a la zona; si no cabe, se amplía el rango
        for rango in ((8, 22), (6, 30), (6, 48), (4, 70)):
            if mejor is not None:
                break
            mejor = _buscar_sitio(m, d, a, propia, rango, centros_emocion, zonas, usadas, ocupado, W, H, dentro)
        if mejor is None:
            raise SystemExit("No hay sitio para el acertijo de %s (%s)" % (a["emocion"], a["tipo"]))
        usadas[mejor["cercana"]] = usadas.get(mejor["cercana"], 0) + 1
        especificacion = aplicar(m, d, a, mejor, ocupado, W, H)
        especificacion["zona"] = mejor["cercana"]   # la zona donde quedó de verdad
        especificaciones.append(especificacion)
    return especificaciones


def _buscar_sitio(m, d, a, propia, rango, centros_emocion, zonas, usadas, ocupado, W, H, dentro):
    """El mejor sitio para un recinto con la distancia a la zona dentro de `rango`, o None."""
    if True:
        candidatos = []
        for y0 in range(2, H - d["alto"] - 2):
            for x0 in range(2, W - d["ancho"] - 2):
                cx = x0 + d["ancho"] / 2.0
                cy = y0 + d["alto"] / 2.0
                cercana = min(centros_emocion, key=lambda n: math.hypot(cx - centros_emocion[n][0], cy - centros_emocion[n][1]))
                dist = math.hypot(cx - centros_emocion[cercana][0], cy - centros_emocion[cercana][1])
                if cercana == propia or dist < rango[0] or dist > rango[1]:
                    continue
                if math.hypot(cx - zonas["Hub"][0], cy - zonas["Hub"][1]) < 13 or math.hypot(cx - zonas["Final"][0], cy - zonas["Final"][1]) < 11:
                    continue
                if any(math.hypot(cx - v[0], cy - v[1]) < (8 if rango[0] >= 6 else 7) for v in zonas.values()):
                    continue
                penal = (0.0 if cercana == a["zona"] else 5.0) + 4.0 * usadas.get(cercana, 0)
                for volteado in (False, True):
                    candidatos.append((penal + abs(dist - 13.0) * 0.5, y0, x0, volteado, cercana))
        candidatos.sort()
        mejor = None
        for (base, y0, x0, volteado, cercana) in candidatos:
            r = evaluar(m, d, a, x0, y0, volteado, ocupado, W, H, dentro)
            if r is None:
                continue
            puntos = base + r["puntos"]
            if mejor is None or puntos < mejor["puntos"]:
                mejor = dict(r, puntos=puntos, x0=x0, y0=y0, volteado=volteado, cercana=cercana)
        return mejor


def _celdas_recinto(d, x0, y0):
    return [(x, y) for y in range(y0, y0 + d["alto"]) for x in range(x0, x0 + d["ancho"])]


def evaluar(m, d, a, x0, y0, volteado, ocupado, W, H, dentro):
    """¿Cabe el recinto aquí y se puede unir con una rama a un camino? Devuelve la rama y su puntuación."""
    ancho, alto = d["ancho"], d["alto"]
    # espacio libre: el recinto, un margen alrededor (más al lado de la entrada) y las placas de fuera
    extra_s = 3 if a["tipo"] == "placas" else 2
    y_ini = y0 - MARGEN - (extra_s if volteado else 0)
    y_fin = y0 + alto + MARGEN + (0 if volteado else extra_s)
    x_ext = 0
    for y in range(y_ini, y_fin):
        for x in range(x0 - MARGEN - x_ext, x0 + ancho + MARGEN + x_ext):
            if not dentro(x, y) or (x, y) in ocupado:
                return None
            dentro_recinto = x0 <= x < x0 + ancho and y0 <= y < y0 + alto
            if m.g[y][x] not in (LIBRES if dentro_recinto else MARGEN_OK):
                return None
    # celdas desde donde sale la rama: justo fuera del hueco de la entrada
    gcol, ew = d["gcol"], d["ew"]
    fila_ext = (y0 - 1) if volteado else (y0 + alto)
    salidas = [(x0 + G + gcol + i, fila_ext) for i in range(ew)]
    prohibidas = set(_celdas_recinto(d, x0, y0))
    for c in salidas:
        prohibidas.discard(c)
    rama = buscar_rama(m, salidas, prohibidas, ocupado, W, H, dentro)
    if rama is None:
        return None
    return {"rama": rama, "puntos": len(rama) * 0.6 + abs(0.0)}


def buscar_rama(m, salidas, prohibidas, ocupado, W, H, dentro):
    """Camino más corto (por tiles libres) desde la salida del recinto hasta un camino 'c' existente."""
    previo = {}
    cola = deque()
    for s in salidas:
        if dentro(*s) and m.g[s[1]][s[0]] in PARA_RAMA and s not in ocupado:
            previo[s] = None
            cola.append((s, 0))
    while cola:
        (x, y), largo = cola.popleft()
        if m.g[y][x] == "c":
            ruta = []
            c = (x, y)
            while c is not None:
                ruta.append(c)
                c = previo[c]
            return ruta[::-1]
        if largo >= LARGO_MAX_RAMA:
            continue
        for dx, dy in ((0, 1), (0, -1), (1, 0), (-1, 0)):
            n = (x + dx, y + dy)
            if n in previo or not dentro(*n) or n in prohibidas or n in ocupado:
                continue
            if m.g[n[1]][n[0]] not in PARA_RAMA and m.g[n[1]][n[0]] != "c":
                continue
            previo[n] = (x, y)
            cola.append((n, largo + 1))
    return None


def aplicar(m, d, a, r, ocupado, W, H):
    """Estampa el recinto y su rama en el mapa y devuelve su especificación."""
    x0, y0, volteado = r["x0"], r["y0"], r["volteado"]
    ancho, alto = d["ancho"], d["alto"]
    gcol, ew = d["gcol"], d["ew"]
    # muro de acantilado de G tiles y suelo propio dentro
    for ly in range(alto):
        for lx in range(ancho):
            en_muro = lx < G or lx >= ancho - G or ly < G or ly >= alto - G
            y = y0 + ((alto - 1 - ly) if volteado else ly)
            m.g[y][x0 + lx] = "C" if en_muro else a["suelo"]
    # el hueco de la entrada (G filas) es suelo
    for (c, rr) in [(G + gcol + i, G + d_ih(d) + k) for i in range(ew) for k in range(G)]:
        y = y0 + ((alto - 1 - rr) if volteado else rr)
        m.g[y][x0 + c] = a["suelo"]
    # rama de camino: cada celda y sus vecinas de la derecha y de abajo (2 tiles de ancho)
    prohibidas = set(_celdas_recinto(d, x0, y0))
    for (x, y) in r["rama"]:
        for dx, dy in ((0, 0), (1, 0), (0, 1)):
            cx, cy = x + dx, y + dy
            if (cx, cy) in prohibidas and not _es_hueco(d, x0, y0, volteado, cx, cy):
                continue
            if 0 < cx < W - 1 and 0 < cy < H - 1 and m.g[cy][cx] in PARA_RAMA:
                m.g[cy][cx] = "c"
    # reservar el sitio (con margen) para que ningún otro recinto ni el Decorador lo toquen
    for (x, y) in _celdas_recinto(d, x0, y0):
        for dx in range(-1, 2):
            for dy in range(-1, 2):
                ocupado.add((x + dx, y + dy))
    mundo = en_mundo(d, x0, y0, volteado)
    celdas_bloqueo = celdas_a_mundo(d["bloqueo"], d, x0, y0, volteado)
    ext = celdas_a_mundo([(c, rr) for (c, rr) in d["exterior"]], d, x0, y0, volteado)
    return {
        "emocion": a["emocion"], "habilidad": a["habilidad"], "zona": a["zona"], "tipo": a["tipo"],
        "rect": [x0, y0, ancho, alto], "volteado": volteado,
        "interior": [x0 + G, y0 + G, d_iw(a), d_ih_real(a)],
        "objetos": mundo["objetos"], "abismos": mundo["abismos"], "fragmento": mundo["fragmento"],
        "bloqueo": [list(c) for c in celdas_bloqueo],
        "rama": [list(c) for c in r["rama"]],
        "reservada": reservada_rect(a, d, x0, y0, volteado),
    }


def reservada_rect(a, d, x0, y0, volteado):
    """Rectángulo (tiles) que el Decorador debe dejar libre: el recinto, un margen y el lado de la entrada."""
    extra = 3 if a["tipo"] == "placas" else 2
    arriba = y0 - 1 - (extra if volteado else 0)
    return [x0 - 1, arriba, d["ancho"] + 2, d["alto"] + 2 + extra]


def d_ih(d):
    return d["alto"] - 2 * G


def d_iw(a):
    return a["iw"]


def d_ih_real(a):
    return a["ih"]


def _es_hueco(d, x0, y0, volteado, x, y):
    alto = d["alto"]
    ly = (alto - 1 - (y - y0)) if volteado else (y - y0)
    lx = x - x0
    return G + d["gcol"] <= lx < G + d["gcol"] + d["ew"] and G + d_ih(d) <= ly < alto


def escribir_json(especificaciones, ruta):
    datos = {"acertijos": especificaciones}
    with open(ruta, "w", encoding="utf-8", newline="\n") as f:
        json.dump(datos, f, indent=1, ensure_ascii=False)
        f.write("\n")
