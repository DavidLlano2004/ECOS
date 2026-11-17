# Protocolo de pruebas de ECOS con personas

## 1. Objetivo

Saber, con un grupo pequeño de personas:

1. **Si el juego se entiende y se puede jugar sin ayuda**: dónde se atascan, qué confunden, qué errores aparecen.
2. **Qué experiencia tuvieron**: qué les gustó, qué cambiarían, qué nota le ponen.
3. **Si hay un cambio en lo que saben y cómo reaccionan ante las emociones** entre el antes y el después de jugar
   (con las 16 preguntas que hace el propio juego).

Esto es una prueba de un juego educativo. **No es un test psicológico** ni da diagnósticos.

## 2. Cuántas personas

Idealmente **de 8 a 12**. Con menos de 6 el análisis no calcula pruebas estadísticas (solo muestra promedios), y con
5 personas ya se encuentran la mayoría de los problemas de uso. Si puedes, incluye gente que juega mucho,
a veces y nunca videojuegos (el juego pregunta la frecuencia).

## 3. Cómo reclutarlas

- Compañeros de clase, amigos y familiares mayores de edad que no hayan visto el juego antes.
- Invítalas por mensaje: "Es una prueba de un juego educativo, dura unos 45 a 60 minutos, es anónima y puedes parar cuando quieras".
- Evita a quienes ayudaron a hacer el juego: ya saben qué hacer.
- Agradece con algo sencillo (un café, créditos en el juego si quieren).

## 4. Guion de la sesión

**Antes (5 min)**
1. Presenta el juego en una frase: "Es un juego sobre emociones; puedes jugar con calma". **No des pistas** sobre los
   controles, las habilidades ni los caminos cerrados.
2. Explica la prueba: "Voy a mirar cómo juegas, no cómo lo haces de bien. Si algo no se entiende, el culpable es el juego".
3. Deja claro que puede parar cuando quiera y que sus respuestas son anónimas.
4. Muestra la pantalla de consentimiento y deja que ella o él elija.

**Durante (30 a 45 min)**
1. Que juegue solo, con el sonido puesto. Tú observas sin hablar.
2. **No ayudes**, salvo que lleve **más de 5 minutos bloqueada**. Si pasa, dale primero una pista mínima ("¿qué crees que te dice ese objeto?") y anótalo.
3. Anota en la hoja de observación: dónde duda o pregunta, qué dice en voz alta, qué errores ve, cuánto tarda en su primera interacción, si usa al Guía, si entiende las compuertas.
4. Si usa la tecla F8 para reportar un problema, no la interrumpas.

**Después (5 a 10 min)**
1. Que termine el juego (o llegue al final que quiera) y conteste el cuestionario final.
2. Deja que vea sus resultados y que dé su opinión sobre el juego (es opcional).
3. Pregunta: "¿Qué fue lo más difícil? ¿Qué te gustó? ¿Algo te hizo sentir mal o incómodo?".
4. Recoge sus archivos (ver el punto 7) y agradece.

## 5. Hoja de observación

Copia esta tabla (una fila por persona) y rellénala durante la sesión.

| Participante | Hora | Dónde se atascó | Qué dijo | Qué errores vio | Cuánto tardó en la primera interacción | ¿Usó al Guía? | ¿Entendió las compuertas? |
|---|---|---|---|---|---|---|---|
| P1 | | | | | | Sí / No | Sí / En parte / No |
| P2 | | | | | | Sí / No | Sí / En parte / No |
| P3 | | | | | | Sí / No | Sí / En parte / No |

Usa un código (P1, P2...) y **no anotes nombres**. Si necesitas relacionar la fila con su archivo, anota el código de participante que aparece en la pantalla de resultados.

## 6. Consideraciones éticas

- **Consentimiento:** el propio juego lo pide antes de empezar. Puede elegir "Jugar sin guardar mis respuestas": las preguntas se hacen igual y no se guarda nada.
- **Anonimato:** el código del participante es aleatorio y no lleva datos personales. No pidas nombre ni correo en los archivos.
- **Puede parar cuando quiera**, sin dar explicaciones y sin que eso cambie nada.
- **No es un test psicológico**: no mide ni diagnostica a nadie. Dilo al empezar y al terminar.
- **Si alguien se siente mal durante el juego** (se angustia, llora, se incomoda mucho):
  1. **Para la sesión** sin presionar para seguir.
  2. **Agradece** su participación y dile que lo que sintió es válido.
  3. **Sugiere hablar con alguien de confianza** o con el **bienestar universitario**.
  4. No intentes dar terapia ni interpretar lo que sintió. Quédate con la persona hasta que esté tranquila.
- Los datos reales **no se suben a un repositorio público**: la carpeta `docs/analisis/datos_reales/` está ignorada por git.

## 7. Cómo recoger los archivos de cada persona

Según cómo juegue:

**En un computador (versión de escritorio)**
- Pantalla de Resultados > **Exportar mis resultados** > copia `ECOS_resultados.csv` de la carpeta Documentos.
- Si hubo reportes con F8: copia la carpeta `reportes` (botón **Abrir carpeta de datos**).
- Opcional: la carpeta `sesiones` de esa misma carpeta de datos (un JSON por persona, con más detalle).

**En la web**
- Pantalla de Resultados > **Exportar mis resultados**: el navegador descarga `ECOS_resultados.csv` (y el JSON de la sesión). Los reportes de F8 también se descargan.

**Con el formulario de Google (sin pedir archivos)**
- En Resultados, la persona copia su **código de resultados** y lo pega en la última pregunta del formulario. Después
  descargas el CSV de respuestas y lo procesas (ver `docs/analisis/COMO_USAR.md`).

Pon los archivos de todas las personas en **`docs/analisis/datos_reales/`** (cambia el nombre a cada uno para que no se pisen: `p1.csv`, `p2.csv`...) y los reportes de F8 en **`docs/analisis/datos_reales/reportes/`**. Luego sigue `docs/analisis/README.md`.
