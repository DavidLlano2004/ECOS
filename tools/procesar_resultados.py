#!/usr/bin/env python3
"""Un solo comando para procesar los resultados de ECOS (sin argumentos obligatorios):

    python tools/procesar_resultados.py

Hace esto, en orden:
  1. Busca docs/analisis/datos_reales/respuestas_formulario.csv (el CSV descargado de la hoja de respuestas de Google
     Forms). Si no está, explica paso a paso cómo conseguirlo y dónde ponerlo, y se detiene.
  2. Decodifica los códigos de resultados y avisa cuántos se leyeron bien y cuáles fallaron (por número de fila).
  3. Ejecuta el análisis completo (aprendizaje, experiencia de usuario y comentarios).
  4. Escribe todo en docs/analisis/resultados/, muestra la lista de archivos creados y abre la carpeta.

Opciones: --prueba (usa los datos de prueba NO REALES y escribe en docs/analisis/_PRUEBA/resultados/),
--no-abrir (no abre la carpeta al terminar).
Si faltan librerías de Python, muestra el comando exacto para instalarlas, sin instalar nada por su cuenta.
"""
import argparse
import os
import sys

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

ENTRADA_REAL = os.path.join(RAIZ, "docs", "analisis", "datos_reales", "respuestas_formulario.csv")
SALIDA_REAL = os.path.join(RAIZ, "docs", "analisis", "resultados")
ENTRADA_PRUEBA = os.path.join(RAIZ, "docs", "analisis", "_PRUEBA", "respuestas_formulario_NO_REALES.csv")
SALIDA_PRUEBA = os.path.join(RAIZ, "docs", "analisis", "_PRUEBA", "resultados")
REPORTES = os.path.join(RAIZ, "docs", "analisis", "datos_reales", "reportes")

# Qué es cada archivo que se crea (para explicarlo al final)
EXPLICACIONES = {
    "ECOS_resultados_desde_formulario.csv": "Las respuestas ya decodificadas (una fila por persona), con el formato de ECOS_resultados.csv.",
    "resumen.csv": "Promedios y desviaciones del antes y el después, la ganancia normalizada y la prueba estadística de cada bloque.",
    "preguntas.csv": "El porcentaje de acierto de cada pregunta, antes y después.",
    "emociones.csv": "Por emoción: aciertos antes y después, y cuántas personas mejoraron, se mantuvieron o bajaron.",
    "barras_bloques.png": "Gráfico de barras: puntaje medio antes y después en trivia, situaciones y escala.",
    "barras_emociones_trivia.png": "Gráfico de barras: cuánta gente acertó la trivia de cada emoción, antes y después.",
    "lineas_participantes.png": "Gráfico de líneas: cada persona, de antes a después (verde sube, naranja baja).",
    "barras_experiencia.png": "Gráfico de barras: qué tan de acuerdo estuvieron con cada afirmación sobre el juego (1 a 5).",
    "distribucion_nota.png": "Gráfico de barras: cuántas personas dieron cada nota (1 a 5 estrellas).",
    "sus_participantes.png": "Gráfico de barras: puntaje de usabilidad (SUS) de cada persona (solo si se usó).",
    "comparacion_frecuencia.png": "Gráfico: la opinión según cuánto juegan videojuegos.",
    "comentarios.md": "Todos los comentarios escritos, agrupados por pregunta, las palabras que más se repiten y los errores reportados.",
    "informe.md": "El informe escrito con un párrafo por resultado y la sección de limitaciones. Es lo que puedes citar en la documentación.",
}

AYUDA_ARCHIVO = """
No encontré el archivo de respuestas del formulario:
    {ruta}

Cómo conseguirlo (paso a paso):
  1. Abre tu formulario de Google (Google Forms) y entra a la pestaña "Respuestas".
  2. Pulsa el ícono verde "Ver en Hojas de cálculo" (se abre una hoja con todas las respuestas).
  3. En esa hoja: menú "Archivo" > "Descargar" > "Valores separados por comas (.csv)".
  4. Se descarga un archivo con un nombre largo. Cámbiale el nombre a:  respuestas_formulario.csv
  5. Ponlo en esta carpeta (créala si no existe):
         {carpeta}
  6. Vuelve a ejecutar este comando.

Si solo quieres ver cómo funciona con datos inventados, ejecuta:  python tools/procesar_resultados.py --prueba
"""


def comprobar_librerias():
    faltan = []
    for modulo, paquete in (("pandas", "pandas"), ("matplotlib", "matplotlib"), ("scipy", "scipy"), ("numpy", "numpy")):
        try:
            __import__(modulo)
        except ImportError:
            faltan.append(paquete)
    if faltan:
        print("Faltan estas librerías de Python: %s" % ", ".join(faltan))
        print("Instálalas con este comando (cópialo y pégalo tal cual):\n")
        print("    pip install pandas matplotlib scipy\n")
        print("(Yo no instalo nada por mi cuenta.) Después vuelve a ejecutar este comando.")
        sys.exit(1)


def abrir_carpeta(ruta):
    try:
        if sys.platform.startswith("win"):
            os.startfile(ruta)  # noqa: S606 (abre el Explorador de Windows)
        elif sys.platform == "darwin":
            os.system('open "%s"' % ruta)
        else:
            os.system('xdg-open "%s" >/dev/null 2>&1 &' % ruta)
    except OSError as e:
        print("No pude abrir la carpeta automáticamente (%s). Está en: %s" % (e, ruta))


def main():
    ap = argparse.ArgumentParser(description="Procesa los resultados de ECOS (decodifica y analiza)")
    ap.add_argument("--prueba", action="store_true", help="usa los datos de prueba (NO reales)")
    ap.add_argument("--no-abrir", action="store_true", help="no abrir la carpeta al terminar")
    args = ap.parse_args()

    entrada = ENTRADA_PRUEBA if args.prueba else ENTRADA_REAL
    salida = SALIDA_PRUEBA if args.prueba else SALIDA_REAL
    print("=" * 66)
    print("ECOS: procesar resultados" + ("   (DATOS DE PRUEBA, NO REALES)" if args.prueba else ""))
    print("=" * 66)

    # 1. El archivo del formulario
    if not os.path.isfile(entrada):
        print(AYUDA_ARCHIVO.format(ruta=entrada, carpeta=os.path.dirname(entrada)))
        sys.exit(1)
    comprobar_librerias()
    import decodificar_codigos
    import analizar_resultados

    os.makedirs(salida, exist_ok=True)

    # 2. Decodificar los códigos
    print("\nPaso 1 de 2: leyendo los códigos de resultados...")
    csv_decodificado = os.path.join(salida, "ECOS_resultados_desde_formulario.csv")
    resumen = decodificar_codigos.decodificar_archivo(entrada, salida=csv_decodificado)
    if resumen["leidos"] == 0:
        print("\nNo se pudo leer ningún código. Revisa que la columna con los códigos sea la correcta "
              "(puedes indicarla con:  python tools/decodificar_codigos.py ARCHIVO --columna \"Nombre\").")
        sys.exit(1)
    n = resumen["usados"]
    if n < analizar_resultados.MINIMO_WILCOXON:
        print("\nOJO: solo hay %d participante%s. Hago el resumen, pero NO calculo pruebas estadísticas "
              "(hacen falta al menos %d personas para que tengan sentido)." % (n, "" if n == 1 else "s", analizar_resultados.MINIMO_WILCOXON))

    # 3. Analizar
    print("\nPaso 2 de 2: analizando (aprendizaje, experiencia de usuario y comentarios)...")
    argumentos = [csv_decodificado, "--salida", salida, "--reportes", REPORTES]
    if args.prueba:
        argumentos.append("--permitir-prueba")
    analizar_resultados.main(argumentos)

    # 4. Lista de archivos
    print("\n" + "=" * 66)
    print("Listo. Todo quedó en esta carpeta:\n    %s\n" % salida)
    print("Archivos creados:")
    for nombre in sorted(os.listdir(salida)):
        if os.path.isfile(os.path.join(salida, nombre)):
            print("  - %s\n      %s" % (nombre, EXPLICACIONES.get(nombre, "")))
    if not args.no_abrir:
        abrir_carpeta(salida)


if __name__ == "__main__":
    main()
