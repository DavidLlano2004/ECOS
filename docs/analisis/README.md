# Análisis de resultados de ECOS

Aquí se analizan las respuestas que el juego guarda antes y después de jugar (16 preguntas: 7 de trivia, 7 de
situaciones y 2 de escala). El análisis lo hace `tools/analizar_resultados.py`.

## 1. Recoger los datos

Cada persona que juega y **acepta guardar sus respuestas** genera un archivo CSV en su computador:

1. Al terminar el juego, en la pantalla de resultados, pulsa **"Exportar mis resultados"**. Eso copia el archivo a su
   carpeta Documentos con el nombre `ECOS_resultados.csv`. (Si no se pudo, el juego muestra la carpeta donde está y
   un botón "Abrir carpeta".)
2. Ese archivo tiene una fila por partida terminada y no lleva datos personales (solo un código aleatorio de 6
   caracteres).
3. Copia el `ECOS_resultados.csv` de cada computador a **`docs/analisis/datos_reales/`**, cambiándole el nombre para
   que no se pisen (por ejemplo `ana.csv`, `luis.csv`). Esa carpeta NO se sube a GitHub (está en `.gitignore`), así
   que créala si no existe.

Si algún computador tiene un `ecos_resultados_v2.csv` (pasa si el banco de preguntas cambió a mitad del estudio),
no se puede mezclar con el otro formato: analízalos por separado.

## 2. Ejecutar el análisis

Hace falta Python con `pandas`, `numpy`, `matplotlib` y `scipy`:

```
pip install pandas numpy matplotlib scipy
python tools/analizar_resultados.py docs/analisis/datos_reales
```

También puedes pasarle uno o varios archivos: `python tools/analizar_resultados.py ana.csv luis.csv`.
Los resultados se escriben en `docs/analisis/` (o en la carpeta que pongas con `--salida`):

| Archivo | Qué contiene |
|---|---|
| `resumen.csv` | participantes, media y desviación de antes y después por bloque, diferencia, ganancia normalizada y prueba de Wilcoxon |
| `preguntas.csv` | porcentaje de acierto antes y después de cada pregunta |
| `emociones.csv` | por emoción: aciertos antes y después, y cuántos mejoraron, se mantuvieron o bajaron |
| `barras_bloques.png`, `barras_emociones_trivia.png`, `lineas_participantes.png` | gráficos |
| `informe.md` | un párrafo por resultado en lenguaje claro y las limitaciones |

Con menos de 6 participantes el script avisa de que no hay datos suficientes y no calcula la prueba de Wilcoxon.

## 3. Datos de prueba (NO reales)

Para probar que todo funciona sin datos reales:

```
python tools/generar_datos_prueba.py
python tools/analizar_resultados.py docs/analisis/_PRUEBA --permitir-prueba --salida docs/analisis/_PRUEBA/salida
```

`generar_datos_prueba.py` crea 12 participantes inventados en `_PRUEBA/datos_prueba_NO_REALES.csv`, con una primera
columna `dato_de_prueba = SI`. El script de análisis **se niega a procesar** un CSV con esa columna, salvo con
`--permitir-prueba`; en ese caso escribe "DATOS DE PRUEBA" en cada gráfico y en el informe. Así no se mezclan por
error con resultados reales.

## Importante

- Los datos reales de participantes no se suben al repositorio público (`docs/analisis/datos_reales/` está en
  `.gitignore`). Si publicas resultados, usa solo cifras agregadas (el `resumen.csv`, los gráficos y el informe).
- Esto no es una medición psicológica validada: lee siempre la sección "Limitaciones" del informe.

## 4. Experiencia de usuario y comentarios

Si los CSV traen las columnas de opinión (`val_*`), el análisis también genera `barras_experiencia.png` (media de las seis
afirmaciones con su desviación), `distribucion_nota.png`, `sus_participantes.png` (solo si se activó `usar_sus` en
`Resources/config_valoracion.json`; con la interpretación habitual: menos de 51 pobre, 51 a 68 por debajo del promedio,
68 a 80 bueno, más de 80 excelente), `comparacion_frecuencia.png` y `comentarios.md` (comentarios libres agrupados por
pregunta y por palabras repetidas, y la tabla de errores). Los reportes de F8 se leen de `docs/analisis/datos_reales/reportes/`
(copia ahí la carpeta `reportes` de cada computador; se puede cambiar con `--reportes`).

El protocolo para hacer las pruebas con personas está en `docs/protocolo_pruebas.md`.
