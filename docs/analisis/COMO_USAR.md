# Cómo procesar los resultados (sin experiencia en terminal)

Esta guía te lleva desde "crear el formulario" hasta "tener los gráficos y el informe". Solo necesitas un
computador con Windows y Python instalado.

## 1. Crear el formulario de Google y probarlo

1. Entra a [forms.google.com](https://forms.google.com) y crea un formulario nuevo llamado, por ejemplo, **"ECOS: tus resultados"**.
2. Pon estas preguntas, **todas opcionales menos la última** (el orden da igual, pero la última es la importante):
   - "¿Qué fue lo que más te gustó?" (respuesta larga)
   - "¿Qué te confundió o qué cambiarías?" (respuesta larga)
   - "¿Viste algún error? Cuéntanos qué pasó" (respuesta larga)
   - **"Pega aquí tu código de resultados"** (respuesta corta, **obligatoria**). Puedes escribir debajo: *"Lo copias en la pantalla de resultados del juego, con el botón 'Copiar código'."*
3. Pulsa **Enviar** y copia el enlace del formulario.
4. Pega ese enlace en el archivo `Resources/config_formulario.json` del juego, en el campo `"url"`. Así aparece el botón **"Abrir formulario"** en la pantalla de resultados. (Si lo dejas vacío, el botón no se muestra.)
5. **Pruébalo tú:** juega hasta el final, pulsa **"Copiar código"**, abre el formulario, pega el código en la última pregunta y envía. Mira en la pestaña "Respuestas" que llegó.

## 2. Descargar el CSV de las respuestas

1. Abre tu formulario y entra a la pestaña **Respuestas**.
2. Pulsa el ícono verde **"Ver en Hojas de cálculo"**.
3. En la hoja: **Archivo > Descargar > Valores separados por comas (.csv)**.
4. Se descarga un archivo con un nombre largo. **Cámbiale el nombre a `respuestas_formulario.csv`**.

## 3. Dónde guardarlo

Pon `respuestas_formulario.csv` en esta carpeta del proyecto (si no existe, créala):

```
docs/analisis/datos_reales/
```

Esa carpeta **no se sube a GitHub** (está ignorada a propósito: son datos de personas).
Si además te mandaron reportes de errores (carpeta `reportes` con archivos `.json`), cópiala en `docs/analisis/datos_reales/reportes/`.

## 4. Ejecutar el comando

**Opción fácil (doble clic):**
1. Abre la carpeta `tools` del proyecto.
2. Haz clic derecho en **`procesar_resultados.ps1`** y elige **"Ejecutar con PowerShell"**.
3. Espera. Al final se abre la carpeta con los resultados. Presiona Enter para cerrar la ventana.

**Opción con la terminal:** desde la carpeta del proyecto escribe:

```
python tools/procesar_resultados.py
```

**Para ver cómo funciona antes de tener datos reales**, usa los datos inventados (no son personas de verdad):

```
python tools/procesar_resultados.py --prueba
```

Los resultados de prueba se guardan aparte, en `docs/analisis/_PRUEBA/resultados/`, y llevan la marca "DATOS DE PRUEBA".

Si te falta alguna librería, el programa te dice el comando exacto, que es:

```
pip install pandas matplotlib scipy
```

## 5. Qué hay en cada archivo (carpeta `docs/analisis/resultados/`)

| Archivo | Qué es |
|---|---|
| `informe.md` | El informe escrito, con un párrafo por resultado y las limitaciones. **Es lo más útil para la documentación.** |
| `resumen.csv` | Los números del antes y el después por bloque (promedio, desviación, ganancia y prueba estadística). |
| `preguntas.csv` | El porcentaje de acierto de cada pregunta. |
| `emociones.csv` | Por emoción: aciertos y cuántas personas mejoraron, se mantuvieron o bajaron. |
| `comentarios.md` | Todo lo que escribieron, agrupado por pregunta, con las palabras que más se repiten y la tabla de errores. |
| `ECOS_resultados_desde_formulario.csv` | Las respuestas decodificadas, una fila por persona. |

**Qué significa cada gráfico:**

- `barras_bloques.png`: cuánto subió (o no) el puntaje en conocimiento (trivia), cómo reaccionan (situaciones) y cómo se sienten (escala). Gris = antes, dorado = después.
- `barras_emociones_trivia.png`: qué emociones se entienden mejor tras jugar.
- `lineas_participantes.png`: cada persona de antes a después. Verde sube, violeta igual, naranja baja. La línea gruesa dorada es el promedio.
- `barras_experiencia.png`: qué tan de acuerdo estuvieron con las afirmaciones sobre el juego (1 a 5). Las rayitas muestran cuánto varían las respuestas.
- `distribucion_nota.png`: cuántas personas dieron 1, 2, 3, 4 o 5 estrellas.
- `sus_participantes.png`: la usabilidad de cada persona (solo si activaste `usar_sus` en `Resources/config_valoracion.json`). Menos de 51 es pobre, de 51 a 68 está por debajo del promedio, de 68 a 80 es bueno y más de 80 es excelente.
- `comparacion_frecuencia.png`: si la opinión cambia según cuánto juegan videojuegos.

**Importante:** con **menos de 6 personas** el programa hace el resumen pero **no calcula pruebas estadísticas** y te lo dice. Son solo promedios, no conclusiones.

## 6. Cómo usar estos resultados en la documentación

1. Copia los gráficos `.png` que necesites a tu documento (todos tienen títulos en español).
2. Usa los párrafos de `informe.md` como base y reescríbelos con tus palabras.
3. **Incluye siempre la sección "Limitaciones"**: muestra pequeña, mismas preguntas antes y después, autoinforme, sin grupo de control, y que no es una medición psicológica validada.
4. Cita solo cifras agregadas (promedios, porcentajes). **No publiques** el archivo con una fila por persona.
5. Para los comentarios, usa frases cortas sin datos personales.

## Si algo falla

| Qué ves | Qué hacer |
|---|---|
| "No encontré el archivo de respuestas del formulario" | El archivo debe llamarse exactamente `respuestas_formulario.csv` y estar en `docs/analisis/datos_reales/`. Revisa el nombre (a veces queda como `.csv.csv` o con un número). |
| "Faltan estas librerías de Python" | Ejecuta `pip install pandas matplotlib scipy` y vuelve a probar. |
| "No encontré Python 3" (al hacer doble clic) | Instala Python desde python.org y marca la casilla **"Add Python to PATH"**. |
| "No encontré ninguna columna con códigos que empiecen con ECOS1:" | El formulario no tiene la pregunta del código, o la gente pegó otra cosa. Para indicar la columna: `python tools/decodificar_codigos.py ARCHIVO.csv --columna "Nombre de la pregunta"`. |
| "Fila N descartada: el control de errores (CRC) no coincide" | Esa persona copió el código incompleto o lo cambió. Pídele que lo copie otra vez con el botón "Copiar código" (no a mano) y lo mande de nuevo. El número N es la fila de la hoja (la 1 es el encabezado). |
| "El participante X aparece más de una vez" | Mandó el formulario dos veces; el programa se queda con la respuesta más reciente. |
| Los gráficos salen vacíos o con "n pequeño" | Hay muy pocas respuestas. Es normal con menos de 6 personas. |
| "AVISO: este CSV tiene la columna 'dato_de_prueba'" | Estás procesando datos inventados. Para datos reales usa tus respuestas del formulario, sin la opción `--prueba`. |
| Se ve raro el texto con tildes en la ventana | Es solo cómo la ventana muestra los caracteres: los archivos se guardan bien. |
