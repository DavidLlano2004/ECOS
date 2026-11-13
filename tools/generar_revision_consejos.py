#!/usr/bin/env python3
"""Escribe docs/consejos_para_revision.md con las frases de Resources/Consejos/*.json agrupadas por
emoción (para revisarlas). Lee los JSON, así que refleja siempre lo que tiene el juego.

Uso:  python tools/generar_revision_consejos.py
"""
import json
import os

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ORDEN = [("rabia", "Rabia"), ("miedo", "Miedo"), ("tristeza", "Tristeza"), ("soledad", "Soledad"),
         ("culpa", "Culpa"), ("ansiedad", "Ansiedad"), ("verguenza", "Vergüenza")]
GRUPOS = ["qué es y para qué sirve"] * 3 + ["cómo se nota en el cuerpo"] * 2 + ["algo pequeño que se puede hacer"] * 3 \
    + ["una forma de acompañarla"] * 2 + ["hablarlo con alguien de confianza"] * 2


def main() -> None:
    lineas = ["# Consejos de las emociones, para revisión", "",
              "Se muestran, de uno en uno al azar, cuando le hablas de nuevo a una emoción ya integrada (en el Pasado o en su forma aliada del Presente). "
              "Cada emoción habla en primera persona. Se editan en `Resources/Consejos/<id>.json` (la lista `frases`), sin tocar el código.", ""]
    total = 0
    for id_, nombre in ORDEN:
        with open(os.path.join(RAIZ, "Resources", "Consejos", id_ + ".json"), encoding="utf-8") as f:
            frases = json.load(f)["frases"]
        lineas += ["## %s (`%s.json`, %d frases)" % (nombre, id_, len(frases)), ""]
        for i, frase in enumerate(frases):
            tipo = GRUPOS[i] if i < len(GRUPOS) else ""
            lineas.append("%d. %s  *(%s)*" % (i + 1, frase, tipo))
        lineas.append("")
        total += len(frases)
    lineas.insert(2, "**Total: %d frases.**" % total)
    lineas.insert(3, "")
    destino = os.path.join(RAIZ, "docs", "consejos_para_revision.md")
    os.makedirs(os.path.dirname(destino), exist_ok=True)
    with open(destino, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(lineas) + "\n")
    print("Escrito %s (%d frases)" % (destino, total))


if __name__ == "__main__":
    main()
