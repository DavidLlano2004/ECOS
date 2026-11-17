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

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PREGUNTAS = os.path.join(RAIZ, "Resources", "Cuestionario", "preguntas.json")
SALIDA = os.path.join(RAIZ, "docs", "analisis", "_PRUEBA", "datos_prueba_NO_REALES.csv")
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
    return c


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
        filas.append(fila)
    os.makedirs(os.path.dirname(SALIDA), exist_ok=True)
    with open(SALIDA, "w", encoding="utf-8", newline="") as f:
        w = csv.DictWriter(f, fieldnames=cols)
        w.writeheader()
        w.writerows(filas)
    print("Datos de prueba (NO REALES) escritos en:", SALIDA)


if __name__ == "__main__":
    main()
