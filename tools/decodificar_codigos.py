#!/usr/bin/env python3
"""Decodifica los códigos de resultados de ECOS que los jugadores pegaron en un formulario de Google.

    python tools/decodificar_codigos.py RESPUESTAS_FORMULARIO.csv [--salida RUTA.csv] [--columna "Nombre de la columna"]

Entrada: el CSV descargado de la hoja de respuestas de Google Forms (Respuestas > Hojas de cálculo > Archivo > Descargar > CSV).
El script localiza la columna con el código por su prefijo "ECOS1:" (aunque cambie el nombre de la pregunta); con
--columna se le puede indicar el nombre si hiciera falta.

Salida: un CSV con el MISMO formato que ECOS_resultados.csv (así tools/analizar_resultados.py funciona sin cambios),
con las columnas de opinión del formulario intactas al final, y un informe en pantalla de cuántos códigos se leyeron bien.
- Se verifica el control de errores (CRC32) de cada código; los inválidos se descartan y se listan por NÚMERO DE FILA.
- Si un id_participante aparece repetido, se queda con el más reciente (y lo avisa).

Formato del código (lo genera Scripts/Sistemas/CodigoResultados.gd):
    "ECOS1:" + base64 seguro para URL de (JSON compacto comprimido con zlib) + CRC32 (8 hex) del texto base64
"""
import argparse
import base64
import csv
import json
import os
import re
import sys
import zlib

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PREGUNTAS = os.path.join(RAIZ, "Resources", "Cuestionario", "preguntas.json")
PREFIJO = "ECOS1:"
VERSION_FORMATO = 1
PATRON = re.compile(r"ECOS1:[A-Za-z0-9_\-]+")
FINALES = {"b": "bueno", "n": "neutro", "d": "dificil"}
FRECUENCIAS = ["Nunca", "A veces", "Seguido"]
BLOQUES = ("trivia", "situaciones", "escala")


# ----------------------------------------------------------------------------
# Código

def crc32_hex(texto):
    return "%08x" % (zlib.crc32(texto.encode("ascii")) & 0xFFFFFFFF)


def codificar(datos):
    """Igual que CodigoResultados.codificar del juego (sirve para generar datos de prueba)."""
    crudo = json.dumps(datos, separators=(",", ":"), ensure_ascii=False).encode("utf-8")
    b64 = base64.urlsafe_b64encode(zlib.compress(crudo, 9)).decode("ascii").rstrip("=")
    return PREFIJO + b64 + crc32_hex(b64)


def decodificar(codigo):
    """Devuelve (datos, error). error es "" si todo salió bien."""
    texto = codigo.strip()
    if not texto.startswith(PREFIJO):
        return None, "falta el prefijo ECOS1:"
    cuerpo = texto[len(PREFIJO):]
    if len(cuerpo) <= 8:
        return None, "el código está cortado"
    b64, crc = cuerpo[:-8], cuerpo[-8:].lower()
    if crc32_hex(b64) != crc:
        return None, "el control de errores (CRC) no coincide: código cortado o mal copiado"
    try:
        relleno = "=" * ((4 - len(b64) % 4) % 4)
        crudo = zlib.decompress(base64.urlsafe_b64decode(b64 + relleno))
        datos = json.loads(crudo.decode("utf-8"))
    except Exception as e:  # noqa: BLE001 (cualquier fallo de contenido es "código inválido")
        return None, "no se pudo leer el contenido (%s)" % type(e).__name__
    if not isinstance(datos, dict) or datos.get("v") != VERSION_FORMATO:
        return None, "no es un código de ECOS de la versión esperada"
    return datos, ""


# ----------------------------------------------------------------------------
# Del código al formato de ECOS_resultados.csv

def cargar_banco():
    with open(PREGUNTAS, encoding="utf-8") as f:
        return json.load(f)


def columnas_estandar(banco):
    c = ["id_participante", "fecha_iso", "duracion_min", "final", "integradas", "atacadas", "ignoradas", "pendientes",
         "fragmentos", "habilidades", "pre_trivia", "pre_situaciones", "pre_escala", "post_trivia", "post_situaciones",
         "post_escala"]
    for bloque in BLOQUES:
        for p in banco[bloque]:
            c += ["pre_" + p["id"], "post_" + p["id"]]
            if bloque != "escala":
                c += ["pre_ok_" + p["id"], "post_ok_" + p["id"]]
    c += ["val_u%d" % i for i in range(1, 7)]
    c += ["val_nota", "val_frecuencia", "val_sus", "val_gusto", "val_mejorar", "val_error"]
    return c


def fila_estandar(datos, banco):
    """Un diccionario columna -> valor con el mismo contenido que escribe el juego en ECOS_resultados.csv."""
    f = {
        "id_participante": datos.get("id", ""), "fecha_iso": datos.get("f", ""), "duracion_min": datos.get("d", ""),
        "final": FINALES.get(datos.get("fin", ""), datos.get("fin", "")),
        "integradas": datos.get("i", ""), "atacadas": datos.get("a", ""), "ignoradas": datos.get("ig", ""),
        "pendientes": datos.get("p", ""), "fragmentos": "", "habilidades": "",
    }
    for fase, clave_p, clave_r in (("pre", "pre", "rp"), ("post", "post", "rq")):
        p = datos.get(clave_p, [0, 0, 0])
        f[fase + "_trivia"], f[fase + "_situaciones"], f[fase + "_escala"] = p[0], p[1], p[2]
        respuestas = datos.get(clave_r, "")
        k = 0
        for bloque in BLOQUES:
            for q in banco[bloque]:
                ch = respuestas[k] if k < len(respuestas) else "-"
                k += 1
                if ch == "-":
                    f["%s_%s" % (fase, q["id"])] = ""
                    if bloque != "escala":
                        f["%s_ok_%s" % (fase, q["id"])] = ""
                    continue
                valor = int(ch)
                f["%s_%s" % (fase, q["id"])] = valor
                if bloque != "escala":
                    f["%s_ok_%s" % (fase, q["id"])] = 1 if valor == int(q["correcta"]) else 0
    v = datos.get("val")
    if v:
        for i, ch in enumerate(v.get("u", ""), start=1):
            f["val_u%d" % i] = int(ch) if ch.isdigit() and ch != "0" else ""
        f["val_nota"] = v.get("n", "") or ""
        fr = v.get("fr", -1)
        f["val_frecuencia"] = FRECUENCIAS[fr] if 0 <= fr < len(FRECUENCIAS) else ""
        f["val_sus"] = v["sp"] if v.get("sp", -1) is not None and v.get("sp", -1) >= 0 else ""
    return f


def asignar_comentarios(fila, encabezados, fila_original):
    """Pone en val_gusto, val_mejorar y val_error las columnas de texto del formulario que se reconocen por su pregunta."""
    for h in encabezados:
        bajo = h.lower()
        valor = (fila_original.get(h) or "").strip()
        if not valor:
            continue
        if "gust" in bajo:
            fila["val_gusto"] = valor
        elif "confund" in bajo or "cambiar" in bajo:
            fila["val_mejorar"] = valor
        elif "error" in bajo or "problema" in bajo:
            fila["val_error"] = valor


# ----------------------------------------------------------------------------

def encontrar_columna(encabezados, filas, nombre=None):
    if nombre:
        if nombre not in encabezados:
            sys.exit("No existe la columna '%s'. Columnas del archivo: %s" % (nombre, ", ".join(encabezados)))
        return nombre
    mejor, cuenta = None, 0
    for h in encabezados:
        n = sum(1 for f in filas if PATRON.search(f.get(h) or ""))
        if n > cuenta:
            mejor, cuenta = h, n
    if mejor is None:
        sys.exit("No encontré ninguna columna con códigos que empiecen con %s. Usa --columna para indicar cuál es." % PREFIJO)
    return mejor


def leer_filas(ruta):
    # utf-8-sig quita la marca (BOM) que Excel y Google a veces añaden al principio
    with open(ruta, encoding="utf-8-sig", newline="") as f:
        lector = csv.DictReader(f)
        filas = list(lector)
        return lector.fieldnames or [], filas


def decodificar_archivo(ruta, columna=None, salida=None, silencioso=False):
    """Decodifica el CSV del formulario y escribe el CSV con el formato de ECOS_resultados.csv.
    Devuelve un diccionario con el resumen: {leidos, invalidos: [numeros de fila], repetidos, salida, filas}."""
    encabezados, filas = leer_filas(ruta)
    if not filas:
        sys.exit("El archivo está vacío.")
    col = encontrar_columna(encabezados, filas, columna)
    banco = cargar_banco()
    columnas = columnas_estandar(banco)
    # Datos de prueba (inventados): la marca viaja al CSV de salida para que el análisis se niegue a mezclarlos con datos reales
    es_prueba = "dato_de_prueba" in encabezados or "NO_REALES" in os.path.basename(ruta).upper().replace("NO_REALES", "NO_REALES")
    extras = [h for h in encabezados if h != col and h != "dato_de_prueba"]
    leidos, invalidos, descartadas = [], [], []
    for numero, f in enumerate(filas, start=2):   # la fila 1 es el encabezado
        crudo = f.get(col) or ""
        m = PATRON.search(crudo)
        if not m:
            invalidos.append((numero, "no tiene código"))
            continue
        datos, error = decodificar(m.group(0))
        if datos is None:
            invalidos.append((numero, error))
            continue
        fila = fila_estandar(datos, banco)
        asignar_comentarios(fila, extras, f)
        for h in extras:   # las columnas del formulario, intactas (con prefijo si chocan con las estándar)
            nombre = h if h not in columnas else "form_" + h
            fila[nombre] = f.get(h, "")
        fila["_numero"] = numero
        if es_prueba:
            fila["dato_de_prueba"] = "SI"
        leidos.append(fila)
    # Id repetido: se queda con el más reciente
    por_id, repetidos = {}, []
    for fila in leidos:
        i = fila["id_participante"]
        if i in por_id:
            repetidos.append(i)
            if str(fila["fecha_iso"]) >= str(por_id[i]["fecha_iso"]):
                por_id[i] = fila
        else:
            por_id[i] = fila
    finales = list(por_id.values())
    nombres_extra = [(h if h not in columnas else "form_" + h) for h in extras]
    encabezado_final = (["dato_de_prueba"] if es_prueba else []) + columnas + nombres_extra
    if salida is None:
        salida = os.path.join(os.path.dirname(os.path.abspath(ruta)), "ECOS_resultados_desde_formulario.csv")
    os.makedirs(os.path.dirname(os.path.abspath(salida)), exist_ok=True)
    with open(salida, "w", encoding="utf-8", newline="") as f:
        w = csv.DictWriter(f, fieldnames=encabezado_final, extrasaction="ignore")
        w.writeheader()
        w.writerows(finales)
    resumen = {"prueba": es_prueba, "total": len(filas), "leidos": len(leidos), "invalidos": invalidos, "repetidos": repetidos,
               "usados": len(finales), "salida": salida, "columna": col}
    if not silencioso:
        imprimir_informe(resumen)
    return resumen


def imprimir_informe(r):
    if r.get("prueba"):
        print("AVISO: son DATOS DE PRUEBA (NO reales); el CSV de salida lleva la marca dato_de_prueba.")
    print("Columna con los códigos: %s" % r["columna"])
    print("Filas en el archivo: %d" % r["total"])
    print("Códigos leídos bien: %d de %d" % (r["leidos"], r["total"]))
    for numero, motivo in r["invalidos"]:
        print("  Fila %d descartada: %s" % (numero, motivo))
    for i in sorted(set(r["repetidos"])):
        print("  AVISO: el participante %s aparece más de una vez; me quedé con el más reciente." % i)
    print("Participantes en el CSV final: %d" % r["usados"])
    print("CSV escrito en: %s" % r["salida"])


def main():
    ap = argparse.ArgumentParser(description="Decodifica los códigos de resultados de ECOS")
    ap.add_argument("csv", help="CSV descargado de la hoja de respuestas del formulario")
    ap.add_argument("--salida", help="CSV de salida (por defecto, junto al de entrada)")
    ap.add_argument("--columna", help="nombre de la columna con el código (si no se detecta sola)")
    args = ap.parse_args()
    r = decodificar_archivo(args.csv, args.columna, args.salida)
    if r["leidos"] == 0:
        sys.exit(1)


if __name__ == "__main__":
    main()
