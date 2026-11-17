#!/usr/bin/env python3
"""Crea un CSV de EJEMPLO (12 participantes INVENTADOS) para probar tools/analizar_resultados.py.

    python tools/generar_datos_prueba.py

Escribe docs/analisis/_PRUEBA/datos_prueba_NO_REALES.csv. El archivo lleva NO_REALES en el nombre y una primera
columna "dato_de_prueba" con el valor "SI": el script de análisis se niega a procesarlo salvo con
--permitir-prueba (y en ese caso escribe "DATOS DE PRUEBA" en los gráficos y en el informe). Así no se mezclan
por error con resultados reales.

Las columnas son las mismas que escribe el juego (Scripts/Sistemas/Exportacion.gd), leídas del banco de
preguntas (Resources/Cuestionario/preguntas.json).
"""
import csv
import json
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import decodificar_codigos

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PREGUNTAS = os.path.join(RAIZ, "Resources", "Cuestionario", "preguntas.json")
SALIDA = os.path.join(RAIZ, "docs", "analisis", "_PRUEBA", "datos_prueba_NO_REALES.csv")
SALIDA_FORMULARIO = os.path.join(RAIZ, "docs", "analisis", "_PRUEBA", "respuestas_formulario_NO_REALES.csv")
PARTICIPANTES = 12


def columnas(banco):
    c = ["dato_de_prueba", "id_participante", "fecha_iso", "duracion_min", "final", "integradas", "atacadas",
         "ignoradas", "pendientes", "fragmentos", "habilidades", "pre_trivia", "pre_situaciones", "pre_escala",
         "post_trivia", "post_situaciones", "post_escala"]
    for bloque in ("trivia", "situaciones", "escala"):
        for p in banco[bloque]:
            c += ["pre_" + p["id"], "post_" + p["id"]]
            if bloque != "escala":
                c += ["pre_ok_" + p["id"], "post_ok_" + p["id"]]
    c += ["val_u%d" % i for i in range(1, 7)]
    c += ["val_nota", "val_frecuencia", "val_sus", "val_gusto", "val_mejorar", "val_error"]
    return c


GUSTOS = ["La música y los dibujos", "Me gustó el final y la música", "Las emociones y sus historias", "Los dibujos y el mundo en dos épocas",
          "La historia de cada emoción", "", "El Guía y la música", "Los recuerdos de cada emoción"]
MEJORAS = ["No entendí las compuertas al principio", "Las pistas eran poco claras", "Me confundió el diario", "", "Quería saber a dónde ir al principio",
           "No entendí las compuertas", "", "Más pistas para las compuertas"]
ERRORES = ["", "", "", "Se quedó pegado un texto al viajar de época", "", "", "", "No vi ninguno"]


def sus_azar(azar):
    """Un puntaje SUS inventado: respuestas de 1 a 5 y el cálculo oficial (impares valor-1, pares 5-valor, x 2.5)."""
    suma = 0
    for i in range(1, 11):
        v = azar.choice([4, 4, 5, 3]) if i % 2 == 1 else azar.choice([1, 2, 2, 3])
        suma += (v - 1) if i % 2 == 1 else (5 - v)
    return suma * 2.5


def a_codigo(fila, banco):
    """El código de resultados (formato ECOS1) que generaría el juego para esta fila inventada."""
    rp, rq = "", ""
    for bloque in ("trivia", "situaciones", "escala"):
        for p in banco[bloque]:
            rp += str(fila["pre_" + p["id"]])
            rq += str(fila["post_" + p["id"]])
    datos = {"v": 1, "id": fila["id_participante"], "f": fila["fecha_iso"][:16], "g": "1.0.0", "fin": fila["final"][0],
             "i": fila["integradas"], "a": fila["atacadas"], "ig": fila["ignoradas"], "p": fila["pendientes"], "d": fila["duracion_min"],
             "pre": [fila["pre_trivia"], fila["pre_situaciones"], fila["pre_escala"]],
             "post": [fila["post_trivia"], fila["post_situaciones"], fila["post_escala"]], "rp": rp, "rq": rq,
             "val": {"u": "".join(str(fila["val_u%d" % k]) for k in range(1, 7)), "n": fila["val_nota"],
                     "fr": ["Nunca", "A veces", "Seguido"].index(fila["val_frecuencia"]), "s": "",
                     "sp": fila["val_sus"] if fila["val_sus"] != "" else -1.0}}
    return decodificar_codigos.codificar(datos)


def main():
    azar = random.Random(2024)
    with open(PREGUNTAS, encoding="utf-8") as f:
        banco = json.load(f)
    cols = columnas(banco)
    filas = []
    for i in range(PARTICIPANTES):
        habilidad = azar.uniform(0.35, 0.65)         # cuánto sabía antes
        mejora = azar.uniform(-0.05, 0.40)           # cuánto mejora (algunos casi nada o un poco menos)
        fila = {"dato_de_prueba": "SI", "id_participante": "PRUEBA%02d" % (i + 1),
                "fecha_iso": "2026-11-%02dT1%d:%02d:00" % (10 + i % 8, i % 10, (i * 7) % 60),
                "duracion_min": round(azar.uniform(25, 70), 1)}
        integradas = azar.choice([3, 4, 5, 6, 7, 7])
        fila.update({"final": "bueno" if integradas == 7 else "neutro", "integradas": integradas,
                     "atacadas": 7 - integradas, "ignoradas": 0, "pendientes": 0,
                     "fragmentos": azar.randint(0, 7), "habilidades": integradas})
        totales = {"pre": {"trivia": 0, "situaciones": 0, "escala": 0}, "post": {"trivia": 0, "situaciones": 0, "escala": 0}}
        for fase, prob in (("pre", habilidad), ("post", min(0.97, max(0.05, habilidad + mejora)))):
            for bloque in ("trivia", "situaciones", "escala"):
                for p in banco[bloque]:
                    if bloque == "escala":
                        base = 3 if fase == "pre" else 4
                        valor = min(5, max(1, base + azar.choice([-1, 0, 0, 1])))
                        fila["%s_%s" % (fase, p["id"])] = valor
                        totales[fase]["escala"] += valor
                        continue
                    ok = 1 if azar.random() < prob else 0
                    elegida = 0 if ok else azar.randint(1, len(p["opciones"]) - 1)
                    fila["%s_%s" % (fase, p["id"])] = elegida
                    fila["%s_ok_%s" % (fase, p["id"])] = ok
                    totales[fase][bloque] += ok
        for fase in ("pre", "post"):
            for bloque in ("trivia", "situaciones", "escala"):
                fila["%s_%s" % (fase, bloque)] = totales[fase][bloque]
        # Opinión sobre el juego (inventada)
        for k in range(1, 7):
            fila["val_u%d" % k] = azar.choice([3, 4, 4, 5, 5]) if k != 4 else azar.choice([2, 3, 4, 4])
        fila["val_nota"] = azar.choice([3, 4, 4, 5, 5])
        fila["val_frecuencia"] = azar.choice(["Nunca", "A veces", "A veces", "Seguido"])
        fila["val_sus"] = sus_azar(azar) if i % 3 != 2 else ""   # no todos contestaron el SUS
        fila["val_gusto"] = GUSTOS[i % len(GUSTOS)]
        fila["val_mejorar"] = MEJORAS[i % len(MEJORAS)]
        fila["val_error"] = ERRORES[i % len(ERRORES)]
        filas.append(fila)
    os.makedirs(os.path.dirname(SALIDA), exist_ok=True)
    with open(SALIDA, "w", encoding="utf-8", newline="") as f:
        w = csv.DictWriter(f, fieldnames=cols)
        w.writeheader()
        w.writerows(filas)
    print("Datos de prueba (NO REALES) escritos en:", SALIDA)
    # Las mismas 12 personas, como las respuestas de un formulario de Google (con su código de resultados)
    with open(SALIDA_FORMULARIO, "w", encoding="utf-8", newline="") as f:
        w = csv.writer(f)
        w.writerow(["dato_de_prueba", "Marca temporal", "¿Qué fue lo que más te gustó?", "¿Qué te confundió o qué cambiarías?",
                    "¿Viste algún error? Cuéntanos qué pasó", "Pega aquí tu código de resultados"])
        for fila in filas:
            marca = fila["fecha_iso"].replace("T", " ")
            w.writerow(["SI", marca, fila["val_gusto"], fila["val_mejorar"], fila["val_error"], a_codigo(fila, banco)])
    print("Respuestas de formulario de prueba (NO REALES) escritas en:", SALIDA_FORMULARIO)


if __name__ == "__main__":
    main()
