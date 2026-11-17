# Publicar ECOS en la web con Vercel

ECOS se exporta como una página web estática (Godot 4, renderizador Compatibility / WebGL 2, sin hilos) y se aloja
en Vercel (plan gratuito, solo archivos estáticos). El juego se publica en una **rama aparte llamada `web`**, que
solo contiene los archivos exportados; así `main` queda limpia.

## 0. Antes de empezar (una sola vez)

- Instala las **plantillas de exportación de Godot 4.7.2**: en el editor, `Editor > Administrar plantillas de
  exportación > Descargar e instalar`. Sin ellas no se puede exportar.
- Tener `git` configurado con tu usuario y acceso al repositorio de GitHub (`git push` funciona).
- El preset **"Web"** ya está en `export_presets.cfg` (versión sin hilos, sin extensiones, sin PWA, en modo release,
  sin `tools/`, `docs/`, escenas de prueba, `.md`, `.py`, `.ps1` ni ejemplos del Dialogue Manager).

## a) Ejecutar `tools/publicar_web.ps1`

Desde la raíz del proyecto, en PowerShell:

```powershell
powershell -ExecutionPolicy Bypass -File tools\publicar_web.ps1
```

El script:

1. Exporta con `godot --headless --export-release "Web" build/web/index.html`.
2. Crea `build/web/vercel.json` con las cabeceras de caché (`immutable` para `.wasm`, `.pck` y `.png`;
   `max-age=0, must-revalidate` para `index.html`). No lleva cabeceras COOP/COEP porque no hay hilos.
3. Muestra el tamaño de cada archivo y avisa si alguno pasa de 80 MB.
4. Publica el contenido de `build/web` en la rama `web` con un **git worktree temporal** (no toca tu rama ni tus
   cambios sin commit): un commit por publicación, `Publicación <versión> <fecha>`, y `git push origin web`.

Opciones: `-SoloExportar` (no publica), `-SinPush` (commit pero sin subir), `-ForzarPush` (si el push se rechaza,
pide confirmación para un `--force-with-lease`), `-Godot RUTA` (si Godot está en otro sitio).

La versión sale de `config/version` en `project.godot`. Súbela cuando publiques algo nuevo.

## b) Configurar Vercel (una sola vez)

1. En [vercel.com](https://vercel.com): **Add New > Project** e importa el repositorio de GitHub.
2. **Framework Preset:** `Other`.
3. **Build Command:** vacío. **Output Directory:** `.` (un punto).
4. Despliega. Luego, en **Settings > Git**, pon **Production Branch = `web`**.

## c) Probar el enlace de producción

Abre la URL de Vercel (`https://tu-proyecto.vercel.app`) en Chrome y en Firefox y revisa:

- Carga la pantalla de título (la primera vez tarda por la descarga) y suena la música tras hacer clic en "Comenzar".
- Jugar un rato; abrir la pausa (ESC); guardar y recargar la página: "Continuar" debe seguir ahí.
- Terminar el juego (o usar las teclas de depuración en una versión de prueba local) y pulsar "Exportar mis
  resultados": se descarga `ECOS_resultados.csv`.
- Pantalla completa desde las Opciones de la pausa.

## d) Actualizar el juego

1. Haz tus cambios y commitea en `main` como siempre.
2. Sube `config/version` en `project.godot`.
3. Ejecuta de nuevo `tools\publicar_web.ps1`. Vercel despliega solo cuando llega el commit a la rama `web`.
4. Si ya habías abierto el juego antes y ves la versión vieja: los `.wasm`, `.pck` y `.png` se guardan un año en el
   navegador (`immutable`) con el mismo nombre. Recarga forzada (Ctrl+F5) o borra los datos del sitio. Si eso te molesta,
   baja el `max-age` de esas reglas en el script (por ejemplo a 3600) y vuelve a publicar.

## e) Límites que debes recordar

- **100 MB por archivo** en el plan gratuito de Vercel (el objetivo es no pasar de **80 MB**).
- **Solo uso no comercial** en el plan gratuito (Hobby).
- **El juego se juega con teclado**: en móviles se muestra un aviso en la pantalla de título.
- La partida se guarda **en el navegador** (almacenamiento del sitio): si el jugador borra los datos del sitio o usa
  otro navegador/dispositivo, no la verá. Las respuestas de la evaluación se **descargan** como archivo.
- En la web no hay botón "Salir" ni "Abrir carpeta de datos".

## Prueba local (antes de publicar)

```powershell
powershell -ExecutionPolicy Bypass -File tools\publicar_web.ps1 -SoloExportar
cd build\web
python -m http.server 8000
```

Abre `http://localhost:8000`. (No hace falta ninguna cabecera especial porque el build no usa hilos.)
