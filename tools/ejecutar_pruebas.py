#!/usr/bin/env python3
"""Ejecuta las pruebas de humo de ECOS en Godot sin ventana y vigila la consola.

    python tools/ejecutar_pruebas.py [--godot RUTA_A_GODOT]

Muestra cuántas comprobaciones pasaron (de tools/pruebas_humo.gd) y cuántos errores o advertencias salieron en la
consola. Los avisos de recursos sin liberar al cerrar Godot (que siempre salen en modo headless) se ignoran.
Termina con código 0 solo si pasó todo y la consola quedó limpia.
"""
import argparse
import os
import re
import subprocess
import sys

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
GODOT = os.environ.get("GODOT", r"C:\Users\Usuario\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe")
# Ruido normal al cerrar Godot sin ventana (no son problemas del juego)
IGNORAR = (
    # Avisos ESPERADOS: la prueba daña el archivo de guardado a propósito, y sin URL del formulario el juego lo avisa en el registro
    re.compile(r"el archivo de guardado está dañado"),
    re.compile(r"config_formulario\.json no tiene 'url'"),
    re.compile(r"leaked at exit|still in use at exit|ObjectDB instances were leaked|RIDs? of type|RID allocations|at: (cleanup|clear|_free_rids)|Pages in use exist|Thread object is being destroyed|wait_to_finish"),
)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--godot", default=GODOT)
    ap.add_argument("--escena", default="res://tools/pruebas_humo.tscn")
    args = ap.parse_args()
    proc = subprocess.run([args.godot, "--headless", "--path", RAIZ, args.escena], capture_output=True, text=True,
                          encoding="utf-8", errors="replace", timeout=1500)
    salida = proc.stdout + "\n" + proc.stderr
    lineas = [l.rstrip() for l in salida.splitlines()]
    fallos = [l for l in lineas if l.startswith("FALLO")]
    resultado = [l for l in lineas if l.startswith("RESULTADO")]
    problemas = [l for l in lineas if re.search(r"ERROR|WARNING|SCRIPT ERROR", l) and not any(p.search(l) for p in IGNORAR)]
    for l in lineas:
        if l.startswith(("---", "FALLO")):
            print(l)
    print()
    print(resultado[-1] if resultado else "RESULTADO: las pruebas no terminaron (revisa la consola)")
    print("Comprobaciones fallidas: %d" % len(fallos))
    print("Errores o advertencias en consola: %d" % len(problemas))
    for l in problemas[:25]:
        print("   ", l)
    sys.exit(0 if (not fallos and not problemas and resultado) else 1)


if __name__ == "__main__":
    main()
