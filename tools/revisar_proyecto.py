#!/usr/bin/env python3
"""Revisión de calidad de ECOS, sin ejecutar el juego (solo Python estándar; Godot sin ventana para dos comprobaciones).

    python tools/revisar_proyecto.py [--sin-godot] [--godot RUTA]

Genera docs/revision_calidad.md con los hallazgos agrupados por gravedad: "bloquea la entrega", "conviene arreglar" y
"detalle". No arregla nada. Revisa:
  - referencias res:// rotas (.tscn, .tres, .gd, .dialogue, .json y project.godot);
  - diálogos: que compilen y que todos los títulos a los que se salta existan;
  - textos que mencionan teclas que no corresponden al Input Map;
  - posibles faltas de ortografía o tildes (solo candidatas);
  - audios esperados que faltan, que sobran y sonidos que no se conectan a ningún evento;
  - recursos EmocionData con campos vacíos;
  - archivos de más de 5 MB y el peso aproximado del juego exportado;
  - teclas de depuración sin protección con OS.is_debug_build();
  - advertencias de nodo de las escenas (con Godot sin ventana; se omite con --sin-godot).
"""
import argparse
import json
import os
import re
import subprocess
import sys

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
GODOT = os.environ.get("GODOT", r"C:\Users\Usuario\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe")
SALIDA = os.path.join(RAIZ, "docs", "revision_calidad.md")

# Carpetas que NO forman parte del juego exportado o son de terceros
OMITIR = (".git", ".godot", ".claude", "build", "docs", "tools", "audio_originales", "addons", "__pycache__")
BLOQUEA, CONVIENE, DETALLE = "bloquea", "conviene", "detalle"
hallazgos = {BLOQUEA: [], CONVIENE: [], DETALLE: []}


def anotar(gravedad, titulo, detalle):
    hallazgos[gravedad].append((titulo, detalle))


def archivos(extensiones, incluir_tools=False, incluir_docs=False):
    omitir = tuple(o for o in OMITIR if not ((o == "tools" and incluir_tools) or (o == "docs" and incluir_docs)))
    for base, carpetas, nombres in os.walk(RAIZ):
        carpetas[:] = [c for c in carpetas if c not in omitir]
        for n in nombres:
            if n.endswith(extensiones):
                yield os.path.join(base, n)


def rel(ruta):
    return os.path.relpath(ruta, RAIZ).replace("\\", "/")


def leer(ruta):
    with open(ruta, encoding="utf-8", errors="replace") as f:
        return f.read()


# ----------------------------------------------------------------------------
def referencias_rotas():
    rotas = []
    patron = re.compile(r"res://[^\"'\s,)\]}>]+")
    for ruta in list(archivos((".tscn", ".tres", ".gd", ".dialogue", ".json", ".godot", ".cfg"))):
        texto = leer(ruta)
        for n, linea in enumerate(texto.splitlines(), start=1):
            if linea.lstrip().startswith("#") and ruta.endswith(".gd"):
                continue   # comentarios
            for m in patron.finditer(linea):
                r = m.group(0).rstrip(".:;")
                if "%" in r or "{" in r or "*" in r or r.endswith("/"):
                    continue   # rutas armadas por código con un formato
                destino = os.path.join(RAIZ, r[len("res://"):])
                if not os.path.exists(destino):
                    rotas.append((rel(ruta), n, r))
    for ruta, n, r in rotas:
        anotar(BLOQUEA, "Referencia rota: %s" % r, "%s, línea %d" % (ruta, n))
    return len(rotas)


# ----------------------------------------------------------------------------
def dialogos_saltos():
    total = 0
    for ruta in archivos((".dialogue",)):
        texto = leer(ruta)
        titulos = set(re.findall(r"^~\s+(\S+)", texto, re.MULTILINE))
        for n, linea in enumerate(texto.splitlines(), start=1):
            for m in re.finditer(r"=>!?\s*([A-Za-z_][\w]*)", linea):
                destino = m.group(1)
                if destino.upper() == "END":
                    continue
                total += 1
                if destino not in titulos:
                    anotar(BLOQUEA, "Diálogo salta a un título que no existe: %s" % destino, "%s, línea %d" % (rel(ruta), n))
    return total


# ----------------------------------------------------------------------------
NOMBRES_TECLA = {32: "ESPACIO", 4194305: "ESC", 4194306: "TAB", 4194309: "ENTER", 4194319: "IZQUIERDA", 4194320: "ARRIBA", 4194321: "DERECHA", 4194322: "ABAJO"}


def nombre_tecla(codigo):
    if codigo in NOMBRES_TECLA:
        return NOMBRES_TECLA[codigo]
    if 65 <= codigo <= 90 or 48 <= codigo <= 57:
        return chr(codigo)
    if 4194332 <= codigo <= 4194343:
        return "F%d" % (codigo - 4194331)
    return str(codigo)


def acciones_input_map():
    """accion -> conjunto de nombres de tecla definidos en project.godot."""
    texto = leer(os.path.join(RAIZ, "project.godot"))
    seccion = texto.split("[input]", 1)[1].split("\n[", 1)[0] if "[input]" in texto else ""
    acciones = {}
    for m in re.finditer(r"^(\w+)=\{(.*?)\n\}", seccion, re.MULTILINE | re.DOTALL):
        teclas = {nombre_tecla(int(k)) for k in re.findall(r'"physical_keycode":(\d+)', m.group(2)) if int(k) != 0}
        acciones[m.group(1)] = teclas
    return acciones


def teclas_en_textos():
    acciones = acciones_input_map()
    definidas = set().union(*acciones.values()) if acciones else set()
    # Teclas que el propio juego documenta fuera del Input Map: números de habilidad, depuración y F8 (reporte), F11 no se usa
    # F5, F6, F7, F9 y F10 son atajos del editor de Godot (se mencionan en la documentación para trabajar, no en el juego)
    conocidas = definidas | {str(i) for i in range(1, 8)} | {"F5", "F6", "F7", "F9", "F10", "F2", "F3", "F4", "F8", "H", "J", "K", "L", "U", "I", "O", "M", "Y", "ENTER", "A", "D", "W", "S", "ESC", "ESPACIO", "TAB"}
    patron = re.compile(r"(?:pulsa|pulsar|presiona|aprieta|mantén|manten|tecla|teclas)\s+(?:la\s+tecla\s+)?(?:la\s+)?(?:las\s+)?([A-Z]\b|F\d{1,2}\b|ESC\b|ESPACIO\b|TAB\b|ENTER\b|Q\b)")
    patron_f = re.compile(r"\bF(\d{1,2})\b")
    diferencias = []
    for ruta in archivos((".gd", ".dialogue", ".json", ".md", ".tres"), incluir_docs=False):
        if rel(ruta).startswith("Scripts/Mundo/Prueba") or "ejemplo" in rel(ruta).lower():
            continue
        for n, linea in enumerate(leer(ruta).splitlines(), start=1):
            if re.search(r"KEY_F\d|keycode", linea):
                continue
            for m in patron.finditer(linea):
                t = m.group(1)
                # Q (VIAJAR) es una alternativa OCULTA a E junto a un portal: ningún texto del juego debe mencionarla
                if t == "Q" and not ruta.endswith((".md", ".gd")):
                    diferencias.append((rel(ruta), n, t, linea.strip()[:100]))
                    continue
                if t not in conocidas:
                    diferencias.append((rel(ruta), n, t, linea.strip()[:100]))
            for m in patron_f.finditer(linea):
                t = "F" + m.group(1)
                if t not in conocidas and t not in ("F11",):
                    diferencias.append((rel(ruta), n, t, linea.strip()[:100]))
    for ruta, n, t, texto in diferencias:
        en_el_juego = not ruta.endswith(".md")
        anotar(CONVIENE if en_el_juego else DETALLE, "%s menciona la tecla %s, que no está en el Input Map ni en las teclas documentadas" % ("Un texto del juego" if en_el_juego else "La documentación", t), "%s, línea %d: «%s»" % (ruta, n, texto))
    # Teclas que el Input Map define pero que los textos del juego dicen con otro nombre: se listan como detalle
    return len(diferencias), acciones


# ----------------------------------------------------------------------------
# Palabras que prácticamente nunca van sin tilde en español (candidatas seguras)
SIN_TILDE = {
    "tambien": "también", "accion": "acción", "acciones": None, "emocion": "emoción", "atencion": "atención", "informacion": "información",
    "direccion": "dirección", "ademas": "además", "despues": "después", "ultimo": "último", "ultima": "última", "proximo": "próximo",
    "musica": "música", "camara": "cámara", "numero": "número", "pagina": "página", "rapido": "rápido", "facil": "fácil", "dificil": "difícil",
    "asi": "así", "aqui": "aquí", "alli": "allí", "adios": "adiós", "ningun": "ningún", "algun": "algún", "habilidad ": None, "sabado": "sábado",
    "cancion": "canción", "decision": "decisión", "conexion": "conexión", "opcion": "opción", "seccion": "sección", "pantalla ": None,
    "esta bien": "está bien", "mas alla": "más allá", "que paso": "qué pasó", "como estas": "cómo estás",
}
SIN_TILDE = {k: v for k, v in SIN_TILDE.items() if v}


def textos_del_juego():
    """Rinde (ruta, línea, texto) de lo que el jugador lee: diálogos, JSON de textos, cadenas de los .gd y campos de los .tres."""
    for ruta in archivos((".dialogue",)):
        for n, linea in enumerate(leer(ruta).splitlines(), start=1):
            m = re.match(r"^\s*(?:[-\w áéíóúÁÉÍÓÚñÑ]+:\s+)?(.+)$", linea)
            if linea.strip() and not linea.lstrip().startswith(("#", "~", "$>", "=>", "if", "elif", "else", "set")):
                yield rel(ruta), n, linea.strip()
    for ruta in archivos((".json",)):
        if rel(ruta).startswith(("Resources/Mundo/",)) or "config_" in ruta:
            continue
        try:
            datos = json.loads(leer(ruta))
        except ValueError:
            continue
        pila = [datos]
        while pila:
            x = pila.pop()
            if isinstance(x, dict):
                pila += [v for k, v in x.items() if k not in ("id", "emocion", "tipo", "habilidad_requerida", "emocion_que_la_da", "zona_destino", "version", "nota")]
            elif isinstance(x, list):
                pila += x
            elif isinstance(x, str) and " " in x:
                yield rel(ruta), 0, x
    for ruta in archivos((".tres",)):
        for n, linea in enumerate(leer(ruta).splitlines(), start=1):
            m = re.match(r'^(?:nombre\w*|descripcion\w*|mensaje\w*|frase\w*|mejora\w*|regalo\w*|titulo|habilidad_(?:nombre|descripcion))\s*=\s*"(.*)"\s*$', linea)
            if m:
                yield rel(ruta), n, m.group(1)
    for ruta in archivos((".gd",)):
        if rel(ruta).startswith("Scripts/Mundo/Prueba"):
            continue
        for n, linea in enumerate(leer(ruta).splitlines(), start=1):
            if linea.lstrip().startswith(("#", "##", "print", "push_warning", "push_error")):
                continue
            for m in re.finditer(r'"((?:[^"\\]|\\.){14,})"', linea):
                t = m.group(1)
                if t.count(" ") >= 2 and "func" not in t and "(" not in t and not t.startswith(("res://", "user://", "%", "~")) and re.search(r"[a-záéíóú]{3}", t):
                    yield rel(ruta), n, t


def ortografia():
    candidatas = []
    palabras = re.compile(r"\b(%s)\b" % "|".join(re.escape(k.strip()) for k in SIN_TILDE), re.IGNORECASE)
    for ruta, n, texto in textos_del_juego():
        for m in palabras.finditer(texto):
            palabra = m.group(1).lower()
            candidatas.append((ruta, n, palabra, SIN_TILDE.get(palabra, SIN_TILDE.get(palabra + " ", "")), texto[:90]))
    # "mas" sin tilde suelto como candidata dudosa (puede ser la conjunción "mas"; casi siempre es "más")
    for ruta, n, texto in textos_del_juego():
        if re.search(r"\bmas\b", texto) and not re.search(r"\bmas\s+que\b.*\bpero\b", texto):
            candidatas.append((ruta, n, "mas", "más", texto[:90]))
    for ruta, n, palabra, sugerida, texto in candidatas:
        anotar(CONVIENE, "Posible falta de tilde: «%s» (¿%s?)" % (palabra, sugerida), "%s%s: «%s»" % (ruta, (", línea %d" % n) if n else "", texto))
    return len(candidatas)


# ----------------------------------------------------------------------------
def audio():
    texto = leer(os.path.join(RAIZ, "Autoload", "Sonido.gd"))

    def lista(nombre):
        m = re.search(r"const %s := \[(.*?)\]" % nombre, texto, re.DOTALL)
        return re.findall(r'"([^"]+)"', m.group(1)) if m else []

    esperados = {"Efectos": lista("EFECTOS"), "Ambiente": lista("AMBIENTES"), "Musica": lista("MUSICAS")}
    existentes = {}
    for carpeta in esperados:
        base = os.path.join(RAIZ, "Assets", "Audio", carpeta)
        existentes[carpeta] = {os.path.splitext(f)[0] for f in os.listdir(base) if f.endswith((".wav", ".ogg", ".mp3"))} if os.path.isdir(base) else set()
    for carpeta, nombres in esperados.items():
        for n in nombres:
            if n not in existentes[carpeta]:
                anotar(BLOQUEA, "Falta el audio «%s»" % n, "Debería estar en Assets/Audio/%s/ (el juego no rompe: avisa una vez en la consola)" % carpeta)
        for n in sorted(existentes[carpeta] - set(nombres)):
            anotar(CONVIENE, "Sobra el audio «%s» (no está en el catálogo de Sonido.gd)" % n, "Assets/Audio/%s/" % carpeta)
    # Sonidos sin conectar: se busca el nombre (o su patrón) en el código, fuera de las listas del catálogo
    codigo = ""
    for ruta in archivos((".gd",), incluir_tools=False):
        t = leer(ruta)
        if rel(ruta) == "Autoload/Sonido.gd":
            t = re.sub(r"const (EFECTOS|AMBIENTES|MUSICAS) := \[.*?\]", "", t, flags=re.DOTALL)
            t = re.sub(r"const VOLUMEN_DB := \{.*?\n\}", "", t, flags=re.DOTALL)
        codigo += t + "\n"
    patrones = [r"emo_%s", r"final_%s", r"hab_", r"musica_pasado", r"amb_"]
    sin_conectar = []
    for carpeta, nombres in esperados.items():
        for n in nombres:
            usado = ('"%s"' % n) in codigo
            if not usado and n.startswith("emo_") and "emo_%s" in codigo:
                usado = True
            if not usado and n.startswith("final_") and "final_%s" in codigo:
                usado = True
            if not usado and n.startswith("hab_") and ('"hab_' in codigo):
                usado = True
            if not usado and n.startswith(("musica_", "amb_")) and ("musica_" in codigo or "amb_" in codigo):
                usado = True
            if not usado:
                sin_conectar.append(n)
    for n in sin_conectar:
        anotar(CONVIENE, "Sonido sin conectar a ningún evento: «%s»" % n, "El nombre no aparece en el código fuera del catálogo")
    total = sum(len(v) for v in esperados.values())
    return total, sin_conectar


# ----------------------------------------------------------------------------
def emociones_vacias():
    m = re.findall(r"@export(?:_multiline)?\s+var\s+(\w+)", leer(os.path.join(RAIZ, "Scripts", "Datos", "EmocionData.gd")))
    campos = [c for c in m if c != "orden"]
    ruta = os.path.join(RAIZ, "Resources", "Emociones")
    revisadas = 0
    for f in sorted(os.listdir(ruta)):
        if not f.endswith(".tres") or f.startswith("frames_"):
            continue
        revisadas += 1
        texto = leer(os.path.join(ruta, f))
        for c in campos:
            mm = re.search(r"^%s\s*=\s*(.*)$" % c, texto, re.MULTILINE)
            if mm is None or mm.group(1).strip() in ('""', ""):
                anotar(CONVIENE if c != "frames" else BLOQUEA, "EmocionData con el campo «%s» vacío" % c, "Resources/Emociones/%s" % f)
    return revisadas


# ----------------------------------------------------------------------------
def archivos_grandes():
    grandes = []
    try:
        salida = subprocess.run(["git", "ls-files"], cwd=RAIZ, capture_output=True, text=True, encoding="utf-8").stdout.splitlines()
    except OSError:
        salida = []
    for f in salida:
        ruta = os.path.join(RAIZ, f)
        if os.path.isfile(ruta) and os.path.getsize(ruta) > 5 * 1024 * 1024:
            grandes.append((f, os.path.getsize(ruta) / 1048576))
    for f, mb in sorted(grandes, key=lambda x: -x[1]):
        anotar(DETALLE, "Archivo grande en el repositorio: %s (%.1f MB)" % (f, mb), "Más de 5 MB; conviene que no crezca el repositorio")
    # Peso aproximado de lo que se exporta (sin comprimir)
    total = 0
    por_tipo = {}
    for carpeta in ("Assets", "Resources", "Scenes", "Scripts", "Dialogos", "Autoload", "Shaders"):
        for base, _, nombres in os.walk(os.path.join(RAIZ, carpeta)):
            for n in nombres:
                if n.endswith((".import", ".uid", ".md")):
                    continue
                tam = os.path.getsize(os.path.join(base, n))
                total += tam
                ext = os.path.splitext(n)[1]
                por_tipo[ext] = por_tipo.get(ext, 0) + tam
    return grandes, total / 1048576, por_tipo


# ----------------------------------------------------------------------------
def teclas_depuracion():
    """Teclas de letra o F que se comprueban en el código y no están protegidas con OS.is_debug_build()."""
    sin_proteger = []
    permitidas = {"Autoload/Reportes.gd": {"KEY_F8"}}   # F8 (reportar un problema) funciona también en la versión final a propósito
    for ruta in archivos((".gd",)):
        r = rel(ruta)
        if r.startswith("Scripts/Mundo/Prueba"):
            continue   # arenas de prueba: no se exportan
        lineas = leer(ruta).splitlines()
        for n, linea in enumerate(lineas):
            for m in re.finditer(r"\bKEY_(F\d{1,2}|[A-Z])\b", linea):
                tecla = "KEY_" + m.group(1)
                if tecla in permitidas.get(r, set()):
                    continue
                contexto = "\n".join(lineas[max(0, n - 25):n + 1])
                if "is_debug_build" not in contexto:
                    sin_proteger.append((r, n + 1, tecla))
    for r, n, t in sin_proteger:
        anotar(BLOQUEA, "Tecla de depuración sin proteger: %s" % t, "%s, línea %d: debe estar dentro de OS.is_debug_build()" % (r, n))
    return len(sin_proteger)


def mundo_dependencias_debug():
    # Escenas de prueba: que estén excluidas del export
    presets = leer(os.path.join(RAIZ, "export_presets.cfg")) if os.path.exists(os.path.join(RAIZ, "export_presets.cfg")) else ""
    for esc in ("PruebaEmociones.tscn", "PruebaHabilidades.tscn"):
        if esc not in presets:
            anotar(CONVIENE, "La escena de prueba %s no está excluida del export" % esc, "export_presets.cfg")


# ----------------------------------------------------------------------------
def revisar_con_godot(godot):
    resultado = {"escenas": 0, "dialogos": 0}
    if not os.path.exists(godot):
        anotar(DETALLE, "No se pudo revisar con Godot", "No encuentro Godot en %s (usa --godot RUTA o la variable GODOT)." % godot)
        return resultado
    p = subprocess.run([godot, "--headless", "--path", RAIZ, "res://tools/revisar_godot.tscn"], capture_output=True, text=True,
                       encoding="utf-8", errors="replace", timeout=600)
    for linea in (p.stdout + "\n" + p.stderr).splitlines():
        partes = linea.strip().split("|")
        if partes[0] == "AVISO_ESCENA" and len(partes) >= 4:
            anotar(CONVIENE, "Advertencia de nodo en una escena: %s" % partes[3], "%s, nodo %s" % (partes[1].replace("res://", ""), partes[2]))
        elif partes[0] == "ERROR_ESCENA":
            anotar(BLOQUEA, "Escena que no se puede abrir", "%s: %s" % (partes[1].replace("res://", ""), partes[2]))
        elif partes[0] == "ERROR_DIALOGO":
            # Un .dialogue vacío que ningún código carga no bloquea nada: es un archivo sobrante
            nombre = partes[1].replace("res://", "")
            cargado = any(os.path.basename(nombre) in leer(r) for r in archivos((".gd", ".tscn", ".tres")))
            anotar(BLOQUEA if cargado or "no se compiló" in partes[2] else CONVIENE, "Diálogo que no compila o está vacío%s" % ("" if cargado else " (y ningún archivo lo usa)"), "%s: %s" % (nombre, partes[2]))
        elif partes[0] == "AVISOS_NO_DISPONIBLES":
            anotar(DETALLE, "No se pudieron leer las advertencias de nodo (triángulos amarillos)", partes[1] + ". Ninguna escena dio error al abrirse; revísalas a mano en el editor si quieres.")
        elif partes[0] == "REVISADO":
            resultado["escenas"] = int(partes[1].split()[0])
            resultado["dialogos"] = int(partes[2].split()[0])
        elif "SCRIPT ERROR" in linea or ("ERROR" in linea and "res://" in linea and "leak" not in linea):
            anotar(BLOQUEA, "Error al abrir escenas o diálogos en Godot", linea.strip()[:160])
    if resultado["escenas"] == 0:
        anotar(DETALLE, "La revisión con Godot no terminó", "Revisa la consola: python tools/revisar_proyecto.py --godot RUTA")
    return resultado


# ----------------------------------------------------------------------------
def escribir_informe(resumen):
    L = ["# Revisión de calidad de ECOS", "",
         "Generado por `tools/revisar_proyecto.py` (no arregla nada). Las pruebas con el juego en marcha están en `tools/pruebas_humo.gd` y `tools/pruebas_casos.gd` (`python tools/ejecutar_pruebas.py`), y los resultados de los casos extra, en `docs/pruebas_casos.md`.", "",
         "## Resumen", ""]
    for k, v in resumen.items():
        L.append("- %s: %s" % (k, v))
    L.append("")
    titulos = {BLOQUEA: "Bloquea la entrega", CONVIENE: "Conviene arreglar", DETALLE: "Detalle"}
    for g in (BLOQUEA, CONVIENE, DETALLE):
        L += ["## %s (%d)" % (titulos[g], len(hallazgos[g])), ""]
        if not hallazgos[g]:
            L += ["_Nada en esta categoría._", ""]
            continue
        agrupados = {}
        for t, d in hallazgos[g]:
            agrupados.setdefault(t, []).append(d)
        for t, ds in agrupados.items():
            L.append("- **%s**%s" % (t, (" (%d veces)" % len(ds)) if len(ds) > 1 else ""))
            for d in ds[:8]:
                L.append("  - %s" % d)
            if len(ds) > 8:
                L.append("  - ... y %d más" % (len(ds) - 8))
        L.append("")
    os.makedirs(os.path.dirname(SALIDA), exist_ok=True)
    with open(SALIDA, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(L))


def main():
    ap = argparse.ArgumentParser(description="Revisión de calidad de ECOS")
    ap.add_argument("--sin-godot", action="store_true", help="no abrir Godot (omite advertencias de escenas y compilación de diálogos)")
    ap.add_argument("--godot", default=GODOT)
    args = ap.parse_args()
    resumen = {}
    resumen["Referencias res:// rotas"] = referencias_rotas()
    resumen["Saltos de diálogo comprobados"] = dialogos_saltos()
    n, acciones = teclas_en_textos()
    resumen["Textos con teclas que no corresponden"] = n
    resumen["Acciones del Input Map"] = ", ".join("%s (%s)" % (a, "/".join(sorted(t)) or "sin tecla") for a, t in acciones.items())
    resumen["Posibles faltas de tilde (candidatas)"] = ortografia()
    total_audio, sin_conectar = audio()
    resumen["Audios del catálogo"] = "%d (%d sin conectar a ningún evento)" % (total_audio, len(sin_conectar))
    resumen["Recursos EmocionData revisados"] = emociones_vacias()
    grandes, mb, por_tipo = archivos_grandes()
    resumen["Archivos de más de 5 MB"] = len(grandes)
    resumen["Peso aproximado del juego exportado (sin comprimir, sin el motor)"] = "%.1f MB (%s)" % (mb, ", ".join("%s %.1f MB" % (e or "otros", t / 1048576) for e, t in sorted(por_tipo.items(), key=lambda x: -x[1])[:4]))
    resumen["Teclas de depuración sin proteger"] = teclas_depuracion()
    mundo_dependencias_debug()
    if args.sin_godot:
        resumen["Revisión con Godot"] = "omitida (--sin-godot)"
    else:
        r = revisar_con_godot(args.godot)
        resumen["Escenas y diálogos abiertos con Godot"] = "%d escenas, %d diálogos" % (r["escenas"], r["dialogos"])
    anotar(DETALLE, "El motor web pesa aparte", "El .wasm de Godot (sin hilos) pesa unas decenas de MB sin comprimir; solo se puede medir exportando (faltan las plantillas de exportación).")
    escribir_informe(resumen)
    print("Informe escrito en %s" % SALIDA)
    for g, nombre in ((BLOQUEA, "Bloquea la entrega"), (CONVIENE, "Conviene arreglar"), (DETALLE, "Detalle")):
        print("  %-20s %d" % (nombre, len(hallazgos[g])))


if __name__ == "__main__":
    main()
