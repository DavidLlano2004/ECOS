#!/usr/bin/env python3
"""Procesa los audios descargados (ElevenLabs, .mp3) y los deja en Assets/Audio/.

Uso (necesita ffmpeg: o está en el PATH o está instalado el paquete `imageio-ffmpeg`):
    python tools/procesar_audio.py CARPETA_CON_LOS_MP3 [--solo nombre1,nombre2] [--sin-copiar-originales]

Qué hace:
  1. Empareja cada .mp3 con la lista de nombres de abajo (hay un alias para un nombre mal escrito).
  2. Copia los originales a audio_originales/ (en la raíz, fuera de Assets y en .gitignore).
  3. Procesa:
       EFECTOS  -> recorta el silencio inicial dejando 10 ms y el final por debajo de -45 dB, normaliza el
                   pico a -3 dB, fundido de salida de 50 ms, .wav 44.1 kHz 16 bits.
       AMBIENTE -> solo recorta el silencio inicial si lo hay, sin tocar el final; ~ -26 LUFS; .ogg (calidad 4).
       MUSICA   -> ~ -20 LUFS; fundido de salida de 1.5 s solo en los tres finales; .ogg (calidad 4).
  4. Escribe en Assets/Audio/Efectos, Ambiente y Musica con los nombres exactos.
  5. Imprime una tabla con duración, pico y volumen antes y después.

La ganancia de ambientes y música nunca deja el pico por encima de -1.5 dB (margen para la compresión).
"""
import array
import os
import re
import shutil
import subprocess
import sys
import tempfile

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

EFECTOS = """dialogo_blip dialogo_blip_guia dialogo_abrir dialogo_cerrar dialogo_opciones
ui_mover ui_aceptar ui_elegir ui_cancelar diario_abrir diario_cerrar guardar
emo_rabia emo_miedo emo_tristeza emo_soledad emo_culpa emo_ansiedad emo_verguenza
emo_rabia_integrada emo_miedo_integrada emo_tristeza_integrada emo_soledad_integrada
emo_culpa_integrada emo_ansiedad_integrada emo_verguenza_integrada
integrar_exito atacar_ignorar habilidad_desbloqueada fragmento_recogido viaje_epoca bloqueo_abre
hab_impulso hab_vision hab_calma hab_vinculo hab_reparar hab_pausa hab_revelar hab_denegada
paso paso_piedra
roca_rompe planta_florece placa_activa porton_repara puente_aparece niebla_disipa titulo_comenzar luz_blanca
cofre_abre mejora_habilidad compuerta_abre pista""".split()
AMBIENTE = "amb_pasado amb_presente amb_lluvia portal_activo".split()
MUSICA = "musica_titulo musica_pasado musica_presente final_bueno final_neutro final_dificil".split()
FINALES = {"final_bueno", "final_neutro", "final_dificil"}
#: nombres con errores de escritura en la descarga -> nombre correcto
ALIAS = {"mo_miedo_integrada": "emo_miedo_integrada"}

OBJETIVO_AMBIENTE_LUFS = -26.0
OBJETIVO_MUSICA_LUFS = -20.0
PICO_EFECTOS_DB = -3.0
PICO_MAXIMO_OGG_DB = -1.5
UMBRAL_INICIO_DB = -50
UMBRAL_FINAL_DB = -45
CARPETA_DE = {"efecto": "Efectos", "ambiente": "Ambiente", "musica": "Musica"}


def buscar_ffmpeg() -> str:
    exe = shutil.which("ffmpeg")
    if exe:
        return exe
    try:
        import imageio_ffmpeg
        return imageio_ffmpeg.get_ffmpeg_exe()
    except ImportError:
        sys.exit("No encuentro ffmpeg (ni en el PATH ni con el paquete imageio-ffmpeg).")


FFMPEG = buscar_ffmpeg()


def tipo_de(nombre: str) -> str:
    if nombre in EFECTOS:
        return "efecto"
    if nombre in AMBIENTE:
        return "ambiente"
    return "musica"


# ---------------------------------------------------------------------------
# Medición
def info(ruta: str):
    """(segundos, hz, canales) de un archivo, leyendo lo que imprime ffmpeg."""
    texto = subprocess.run([FFMPEG, "-hide_banner", "-i", ruta], capture_output=True, text=True).stderr
    d = re.search(r"Duration: (\d+):(\d+):([\d.]+)", texto)
    segundos = int(d.group(1)) * 3600 + int(d.group(2)) * 60 + float(d.group(3)) if d else 0.0
    f = re.search(r"(\d+) Hz, (mono|stereo|(\d+) channels)", texto)
    hz = int(f.group(1)) if f else 44100
    canales = 1 if (f and f.group(2) == "mono") else (2 if (f and f.group(2) == "stereo") else int(f.group(3)) if f and f.group(3) else 2)
    return segundos, hz, canales


def decodificar(ruta: str, filtros: str, hz: int, canales: int) -> array.array:
    """Las muestras (decimales entre -1 y 1) del archivo, ya con los filtros aplicados."""
    cmd = [FFMPEG, "-hide_banner", "-loglevel", "error", "-i", ruta]
    if filtros:
        cmd += ["-af", filtros]
    cmd += ["-ar", str(hz), "-ac", str(canales), "-f", "f32le", "-"]
    datos = subprocess.run(cmd, capture_output=True, check=True).stdout
    muestras = array.array("f")
    muestras.frombytes(datos[: len(datos) // 4 * 4])
    return muestras


def medir(ruta: str, filtros: str = "") -> dict:
    """Duración (s), pico (dBFS) y volumen integrado (LUFS) de un archivo, tras los filtros indicados."""
    segundos, hz, canales = info(ruta)
    m = decodificar(ruta, filtros, hz, canales)
    pico = max(max(m), -min(m)) if len(m) else 0.0
    pico_db = 20 * __import__("math").log10(pico) if pico > 0 else -120.0
    duracion = len(m) / (hz * canales) if len(m) else 0.0
    cadena = (filtros + "," if filtros else "") + "ebur128=peak=true"
    salida = subprocess.run([FFMPEG, "-hide_banner", "-nostats", "-i", ruta, "-af", cadena, "-f", "null", "-"],
                            capture_output=True, text=True).stderr
    # el resumen final tiene "    I:         -23.1 LUFS"
    resumen = salida[salida.rfind("Summary:"):]
    l = re.search(r"I:\s+(-?[\d.]+) LUFS", resumen)
    lufs = float(l.group(1)) if l else float("nan")
    return {"duracion": duracion, "pico_db": pico_db, "lufs": lufs, "hz": hz, "canales": canales}


# ---------------------------------------------------------------------------
# Procesado
def filtro_inicio() -> str:
    # quita el silencio del principio dejando 10 ms
    return "silenceremove=start_periods=1:start_threshold=%ddB:start_silence=0.01" % UMBRAL_INICIO_DB


def filtro_inicio_y_final() -> str:
    # el final se recorta dándole la vuelta al audio
    return filtro_inicio() + ",areverse,silenceremove=start_periods=1:start_threshold=%ddB,areverse" % UMBRAL_FINAL_DB


def codificar(entrada: str, salida: str, filtros: str, ogg: bool, hz: int) -> None:
    cmd = [FFMPEG, "-hide_banner", "-loglevel", "error", "-y", "-i", entrada]
    if filtros:
        cmd += ["-af", filtros]
    cmd += ["-vn", "-ar", str(hz)]
    cmd += ["-c:a", "libvorbis", "-q:a", "4"] if ogg else ["-c:a", "pcm_s16le"]
    cmd.append(salida)
    subprocess.run(cmd, check=True)


def loudnorm_dos_pasadas(origen: str, previo: str, objetivo: float) -> str:
    """Filtro `loudnorm` de dos pasadas para llegar al volumen objetivo respetando el pico real máximo.
    Se usa solo con los archivos que no llegan al objetivo subiendo la ganancia sin pasarse de pico
    (por ejemplo, un ambiente muy bajito con algún pico suelto): ahí hace falta comprimir un poco."""
    ajustes = "loudnorm=I=%.1f:TP=%.1f:LRA=11" % (objetivo, PICO_MAXIMO_OGG_DB)
    cadena = (previo + "," if previo else "") + ajustes + ":print_format=json"
    salida = subprocess.run([FFMPEG, "-hide_banner", "-nostats", "-i", origen, "-af", cadena, "-f", "null", "-"],
                            capture_output=True, text=True).stderr
    bloque = salida[salida.rfind("{"):salida.rfind("}") + 1]
    medidas = {}
    for clave in ("input_i", "input_tp", "input_lra", "input_thresh", "target_offset"):
        medidas[clave] = re.search(r'"' + clave + r'"\s*:\s*"(-?[\d.]+|-inf)"', bloque).group(1)
    return (previo + "," if previo else "") + ajustes + \
        ":measured_I=%s:measured_TP=%s:measured_LRA=%s:measured_thresh=%s:offset=%s:linear=true" % (
            medidas["input_i"], medidas["input_tp"], medidas["input_lra"], medidas["input_thresh"], medidas["target_offset"])


def procesar(nombre: str, origen: str, destino: str) -> dict:
    tipo = tipo_de(nombre)
    antes = medir(origen)
    if tipo == "efecto":
        recorte = filtro_inicio_y_final()
        tras_recorte = medir(origen, recorte)
        if tras_recorte["duracion"] < 0.02:
            sys.exit("%s: el recorte de silencio deja el audio vacío" % nombre)
        ganancia = PICO_EFECTOS_DB - tras_recorte["pico_db"]
        fade = min(0.05, tras_recorte["duracion"])
        filtros = "%s,volume=%.3fdB,afade=t=out:st=%.4f:d=%.4f" % (recorte, ganancia, tras_recorte["duracion"] - fade, fade)
        codificar(origen, destino, filtros, ogg=False, hz=44100)
    else:
        objetivo = OBJETIVO_AMBIENTE_LUFS if tipo == "ambiente" else OBJETIVO_MUSICA_LUFS
        recorte = filtro_inicio() if tipo == "ambiente" else ""
        base = medir(origen, recorte)
        ganancia = objetivo - base["lufs"]
        # nunca por encima del pico máximo: un ogg puede pasarse un poco del pico al comprimir
        tope = PICO_MAXIMO_OGG_DB - base["pico_db"]
        limitado = ganancia > tope
        ganancia = min(ganancia, tope)
        if limitado:
            partes = [loudnorm_dos_pasadas(origen, recorte, objetivo)]
        else:
            partes = [p for p in (recorte, "volume=%.3fdB" % ganancia) if p]
        if nombre in FINALES:
            duracion = base["duracion"]
            partes.append("afade=t=out:st=%.4f:d=1.5" % max(0.0, duracion - 1.5))
        codificar(origen, destino, ",".join(partes), ogg=True, hz=44100)
        antes["limitado"] = limitado
    despues = medir(destino)
    return {"nombre": nombre, "tipo": tipo, "antes": antes, "despues": despues}


# ---------------------------------------------------------------------------
def main() -> None:
    args = sys.argv[1:]
    if not args:
        sys.exit(__doc__)
    carpeta = args[0]
    solo = None
    if "--solo" in args:
        solo = set(args[args.index("--solo") + 1].split(","))
    copiar = "--sin-copiar-originales" not in args

    # 1. Emparejar
    archivos = {}
    for f in sorted(os.listdir(carpeta)):
        if f.lower().endswith(".mp3"):
            base = f[:-4]
            archivos[ALIAS.get(base, base)] = os.path.join(carpeta, f)
    esperados = EFECTOS + AMBIENTE + MUSICA
    faltan = [n for n in esperados if n not in archivos]
    sobran = [n for n in archivos if n not in esperados]
    print("Emparejados: %d de %d. Faltan: %s. Sobran: %s" % (len(archivos) - len(sobran), len(esperados), faltan or "ninguno", sobran or "ninguno"))

    # 2. Originales
    if copiar:
        os.makedirs(os.path.join(RAIZ, "audio_originales"), exist_ok=True)
        for f in sorted(os.listdir(carpeta)):
            if f.lower().endswith(".mp3") and ALIAS.get(f[:-4], f[:-4]) in esperados:
                shutil.copy2(os.path.join(carpeta, f), os.path.join(RAIZ, "audio_originales", f))
        print("Originales copiados a audio_originales/")

    # 3 y 4. Procesar y colocar
    resultados = []
    for nombre in esperados:
        if nombre not in archivos or (solo and nombre not in solo):
            continue
        tipo = tipo_de(nombre)
        carpeta_destino = os.path.join(RAIZ, "Assets", "Audio", CARPETA_DE[tipo])
        os.makedirs(carpeta_destino, exist_ok=True)
        extension = ".wav" if tipo == "efecto" else ".ogg"
        resultados.append(procesar(nombre, archivos[nombre], os.path.join(carpeta_destino, nombre + extension)))
        print("  procesado", nombre)

    # 5. Tabla
    print()
    print("| archivo | tipo | dur. antes (s) | pico antes (dB) | dur. después (s) | pico después (dB) | LUFS antes | LUFS después |")
    print("|---|---|---|---|---|---|---|---|")
    for r in resultados:
        a, d = r["antes"], r["despues"]
        mostrar_lufs = r["tipo"] != "efecto"
        print("| %s | %s | %.2f | %.1f | %.2f | %.1f | %s | %s |" % (
            r["nombre"], r["tipo"], a["duracion"], a["pico_db"], d["duracion"], d["pico_db"],
            "%.1f" % a["lufs"] if mostrar_lufs else "-", ("%.1f" % d["lufs"]) if mostrar_lufs else "-"))
    limitados = [r["nombre"] for r in resultados if r["antes"].get("limitado")]
    if limitados:
        print("\nNo llegaban al volumen objetivo solo con ganancia sin pasar de %.1f dB de pico, así que se normalizaron con loudnorm (algo de compresión): %s" % (PICO_MAXIMO_OGG_DB, ", ".join(limitados)))


if __name__ == "__main__":
    main()
