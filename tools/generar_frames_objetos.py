#!/usr/bin/env python3
"""Crea los SpriteFrames de los objetos de los acertijos de habilidad.

Lee las hojas Assets/Mundo/objetos_habilidad_a.png y _b.png (512x256, cuadros de 128x128,
4 columnas x 2 filas: fila 1 = estado inicial, fila 2 = resuelto) y escribe un SpriteFrames por
objeto en Resources/Mundo/frames_objeto_<nombre>.tres, con dos animaciones de un solo cuadro:
"inicial" y "resuelto".

  hoja A = roca_rompible, planta_marchita, placa_doble, porton_roto
  hoja B = plataforma_movil, camino_oculto, niebla_sombra, fragmento

Uso:  python tools/generar_frames_objetos.py
"""
import os

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CUADRO = 128
HOJAS = {
    "a": ["roca_rompible", "planta_marchita", "placa_doble", "porton_roto"],
    "b": ["plataforma_movil", "camino_oculto", "niebla_sombra", "fragmento"],
}


def escribir(hoja: str, columna: int, nombre: str) -> None:
    ruta_hoja = "res://Assets/Mundo/objetos_habilidad_%s.png" % hoja
    texto = '[gd_resource type="SpriteFrames" format=3]\n\n'
    texto += '[ext_resource type="Texture2D" path="%s" id="1_hoja"]\n\n' % ruta_hoja
    for fila, estado in ((0, "inicial"), (1, "resuelto")):
        texto += '[sub_resource type="AtlasTexture" id="AtlasTexture_%s"]\n' % estado
        texto += 'atlas = ExtResource("1_hoja")\n'
        texto += "region = Rect2(%d, %d, %d, %d)\n\n" % (columna * CUADRO, fila * CUADRO, CUADRO, CUADRO)
    texto += "[resource]\nanimations = [{\n"
    partes = []
    for estado in ("inicial", "resuelto"):
        partes.append('"frames": [{\n"duration": 1.0,\n"texture": SubResource("AtlasTexture_%s")\n}],\n'
                      '"loop": false,\n"name": &"%s",\n"speed": 1.0\n' % (estado, estado))
    texto += "}, {\n".join(partes)
    texto += "}]\n"
    destino = os.path.join(RAIZ, "Resources", "Mundo", "frames_objeto_%s.tres" % nombre)
    with open(destino, "w", encoding="utf-8", newline="\n") as f:
        f.write(texto)
    print("Escrito:", destino)


def main() -> None:
    for hoja, nombres in HOJAS.items():
        for columna, nombre in enumerate(nombres):
            escribir(hoja, columna, nombre)


if __name__ == "__main__":
    main()
