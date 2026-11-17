#!/usr/bin/env python3
"""Análisis de los resultados de ECOS (evaluación antes y después de jugar).

Uso:
    python tools/analizar_resultados.py RUTA [RUTA ...] [--salida docs/analisis] [--reportes CARPETA] [--permitir-prueba]

RUTA puede ser un CSV (ECOS_resultados.csv de un computador) o una carpeta con varios CSV (se unen todos).
Necesita pandas, numpy, matplotlib y scipy.

Genera en la carpeta de salida (por defecto docs/analisis/):
  resumen.csv     participantes, media y desviación de pre y post por bloque, diferencia, ganancia normalizada, Wilcoxon
  preguntas.csv   porcentaje de acierto antes y después de cada pregunta
  emociones.csv   por emoción: aciertos antes y después, y cuántos mejoraron, se mantuvieron o bajaron
  barras_bloques.png, barras_emociones_trivia.png, lineas_participantes.png
  barras_experiencia.png, distribucion_nota.png, sus_participantes.png, comparacion_frecuencia.png   (si hay opiniones)
  comentarios.md  los comentarios libres agrupados por pregunta y por palabras o frases repetidas, y la tabla de errores
  informe.md      un párrafo por resultado en lenguaje claro (aprendizaje y experiencia de usuario) y las limitaciones

SEGURIDAD: se niega a procesar un CSV con la columna "dato_de_prueba" (datos inventados), salvo con
--permitir-prueba; en ese caso escribe "DATOS DE PRUEBA" en cada gráfico y en el informe.
"""
import argparse
import glob
import json
import os
import re
import sys
from collections import Counter

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np
import pandas as pd
from scipy import stats

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# Paleta del juego: morado oscuro y dorado
FONDO = "#1e1b2e"
PANEL = "#2d2845"
DORADO = "#f4c77b"
VIOLETA = "#8a7fa3"
CREMA = "#fff4dc"
VERDE = "#8fd19e"

EMOCIONES = ["rabia", "miedo", "tristeza", "soledad", "culpa", "ansiedad", "verguenza"]
NOMBRES = {"rabia": "Rabia", "miedo": "Miedo", "tristeza": "Tristeza", "soledad": "Soledad", "culpa": "Culpa",
           "ansiedad": "Ansiedad", "verguenza": "Vergüenza"}
# bloque -> (título, mínimo, máximo) del puntaje
BLOQUES = {
    "trivia": ("Conocimiento (trivia)", 0, 7),
    "situaciones": ("Cómo reaccionas (situaciones)", 0, 7),
    "escala": ("Cómo te sientes (escala)", 2, 10),
}
MINIMO_WILCOXON = 6


def leer_csvs(rutas):
    archivos = []
    for r in rutas:
        if os.path.isdir(r):
            archivos += sorted(glob.glob(os.path.join(r, "*.csv")))
        elif os.path.isfile(r):
            archivos.append(r)
        else:
            sys.exit("No existe la ruta: %s" % r)
    if not archivos:
        sys.exit("No encontré ningún CSV en las rutas indicadas.")
    marcos = []
    for a in archivos:
        df = pd.read_csv(a, encoding="utf-8")
        df["_archivo"] = os.path.basename(a)
        marcos.append(df)
    return pd.concat(marcos, ignore_index=True, sort=False), archivos


def ganancia_normalizada(pre, post, maximo):
    """(post - pre) / (máximo - pre), ignorando a quien ya tenía el máximo."""
    valido = pre < maximo
    if valido.sum() == 0:
        return np.nan, 0
    g = (post[valido] - pre[valido]) / (maximo - pre[valido])
    return float(g.mean()), int(valido.sum())


def wilcoxon(pre, post):
    """Devuelve (p, nota). Con n < 6 no se calcula."""
    n = len(pre)
    if n < MINIMO_WILCOXON:
        return np.nan, "no hay datos suficientes (n=%d, hacen falta al menos %d)" % (n, MINIMO_WILCOXON)
    if np.all(post == pre):
        return np.nan, "todas las diferencias son 0"
    try:
        return float(stats.wilcoxon(post, pre).pvalue), ""
    except ValueError as e:
        return np.nan, str(e)


def marca_prueba(ax_o_fig, es_prueba):
    if es_prueba:
        plt.gcf().text(0.01, 0.988, "DATOS DE PRUEBA", ha="left", va="top", color="#e0a070", fontsize=11, fontweight="bold")


def estilo(ax):
    ax.set_facecolor(PANEL)
    for borde in ax.spines.values():
        borde.set_color(VIOLETA)
    ax.tick_params(colors=CREMA)
    ax.xaxis.label.set_color(CREMA)
    ax.yaxis.label.set_color(CREMA)
    ax.title.set_color(DORADO)
    ax.grid(axis="y", color=VIOLETA, alpha=0.25)
    ax.set_axisbelow(True)


def figura(ancho=8, alto=4.6):
    fig, ax = plt.subplots(figsize=(ancho, alto))
    fig.patch.set_facecolor(FONDO)
    estilo(ax)
    return fig, ax


def leyenda(ax):
    l = ax.legend(facecolor=PANEL, edgecolor=VIOLETA, labelcolor=CREMA)
    return l


def main(argv=None):
    ap = argparse.ArgumentParser(description="Análisis de resultados de ECOS")
    ap.add_argument("rutas", nargs="+", help="CSV o carpetas con CSV de ECOS_resultados")
    ap.add_argument("--salida", default=os.path.join(RAIZ, "docs", "analisis"), help="carpeta de salida")
    ap.add_argument("--permitir-prueba", action="store_true", help="acepta CSV de datos de prueba (NO reales)")
    ap.add_argument("--reportes", default=os.path.join(RAIZ, "docs", "analisis", "datos_reales", "reportes"),
                    help="carpeta con los reportes JSON de F8 (por defecto docs/analisis/datos_reales/reportes)")
    args = ap.parse_args(argv)

    df, archivos = leer_csvs(args.rutas)
    es_prueba = "dato_de_prueba" in df.columns
    if es_prueba and not args.permitir_prueba:
        print("=" * 70)
        print("AVISO: este CSV tiene la columna 'dato_de_prueba': son datos INVENTADOS, no reales.")
        print("No se procesa para que no se mezclen por error con resultados de personas.")
        print("Si solo quieres probar el script, usa --permitir-prueba.")
        print("=" * 70)
        sys.exit(2)
    if es_prueba and args.permitir_prueba:
        print("AVISO: DATOS DE PRUEBA (no reales): todo lo que se genere lleva esa marca.")

    # Una fila por participante (si un id aparece dos veces, se queda la última)
    antes = len(df)
    df = df.drop_duplicates(subset="id_participante", keep="last").copy()
    repetidos = antes - len(df)
    for c in ["pre_trivia", "pre_situaciones", "pre_escala", "post_trivia", "post_situaciones", "post_escala"]:
        if c not in df.columns:
            sys.exit("Falta la columna %s: ¿es un CSV de ECOS?" % c)
        df[c] = pd.to_numeric(df[c], errors="coerce")
    completos = df.dropna(subset=["pre_trivia", "pre_situaciones", "pre_escala", "post_trivia", "post_situaciones", "post_escala"]).copy()
    excluidos = len(df) - len(completos)
    df = completos
    n = len(df)
    if n == 0:
        sys.exit("No hay participantes con el antes y el después completos.")
    df["pre_total"] = df["pre_trivia"] + df["pre_situaciones"]
    df["post_total"] = df["post_trivia"] + df["post_situaciones"]

    os.makedirs(args.salida, exist_ok=True)
    avisos = []

    # --- resumen.csv ---
    filas = []
    todos = dict(BLOQUES)
    todos["total"] = ("Total (trivia + situaciones)", 0, 14)
    for clave, (titulo, minimo, maximo) in todos.items():
        pre, post = df["pre_" + clave], df["post_" + clave]
        dif = post - pre
        gan, n_gan = ganancia_normalizada(pre, post, maximo)
        p, nota = wilcoxon(pre.to_numpy(), post.to_numpy())
        if nota.startswith("no hay datos"):
            avisos.append("%s: %s" % (titulo, nota))
        filas.append({
            "bloque": clave, "titulo": titulo, "participantes": n,
            "pre_media": pre.mean(), "pre_sd": pre.std(ddof=1) if n > 1 else np.nan,
            "post_media": post.mean(), "post_sd": post.std(ddof=1) if n > 1 else np.nan,
            "dif_media": dif.mean(), "dif_sd": dif.std(ddof=1) if n > 1 else np.nan,
            "ganancia_normalizada_media": gan, "n_ganancia": n_gan,
            "wilcoxon_p": p, "n_wilcoxon": n, "wilcoxon_nota": nota,
        })
    resumen = pd.DataFrame(filas)
    resumen.round(4).to_csv(os.path.join(args.salida, "resumen.csv"), index=False, encoding="utf-8")

    # --- preguntas.csv ---
    ids = sorted({c[len("pre_"):] for c in df.columns if c.startswith("pre_") and not c.startswith("pre_ok_")
                  and c[4:5] in ("t", "s", "e") and c[5:6] == "_"})
    filas_p = []
    for qid in ids:
        bloque = {"t": "trivia", "s": "situaciones", "e": "escala"}[qid[0]]
        fila = {"id": qid, "bloque": bloque, "emocion": qid[2:] if bloque != "escala" else ""}
        if bloque == "escala":
            pre = pd.to_numeric(df["pre_" + qid], errors="coerce")
            post = pd.to_numeric(df["post_" + qid], errors="coerce")
            fila.update({"pre_media": pre.mean(), "post_media": post.mean(), "pct_acierto_pre": np.nan, "pct_acierto_post": np.nan})
        else:
            pre = pd.to_numeric(df["pre_ok_" + qid], errors="coerce")
            post = pd.to_numeric(df["post_ok_" + qid], errors="coerce")
            fila.update({"pre_media": np.nan, "post_media": np.nan,
                         "pct_acierto_pre": 100 * pre.mean(), "pct_acierto_post": 100 * post.mean()})
        filas_p.append(fila)
    preguntas = pd.DataFrame(filas_p)
    preguntas.round(1).to_csv(os.path.join(args.salida, "preguntas.csv"), index=False, encoding="utf-8")

    # --- emociones.csv ---
    filas_e = []
    for e in EMOCIONES:
        t_pre, t_post = "pre_ok_t_" + e, "post_ok_t_" + e
        s_pre, s_post = "pre_ok_s_" + e, "post_ok_s_" + e
        if not all(c in df.columns for c in (t_pre, t_post, s_pre, s_post)):
            continue
        antes_e = pd.to_numeric(df[t_pre], errors="coerce") + pd.to_numeric(df[s_pre], errors="coerce")
        despues_e = pd.to_numeric(df[t_post], errors="coerce") + pd.to_numeric(df[s_post], errors="coerce")
        dif = (despues_e - antes_e).dropna()
        filas_e.append({
            "emocion": e, "participantes": len(dif),
            "trivia_pct_pre": 100 * pd.to_numeric(df[t_pre], errors="coerce").mean(),
            "trivia_pct_post": 100 * pd.to_numeric(df[t_post], errors="coerce").mean(),
            "situacion_pct_pre": 100 * pd.to_numeric(df[s_pre], errors="coerce").mean(),
            "situacion_pct_post": 100 * pd.to_numeric(df[s_post], errors="coerce").mean(),
            "mejoraron": int((dif > 0).sum()), "se_mantuvieron": int((dif == 0).sum()), "bajaron": int((dif < 0).sum()),
        })
    emociones = pd.DataFrame(filas_e)
    emociones.round(1).to_csv(os.path.join(args.salida, "emociones.csv"), index=False, encoding="utf-8")

    # --- Gráficos ---
    # 1) Barras agrupadas antes y después por bloque (como % del rango de cada puntaje)
    fig, ax = figura()
    x = np.arange(len(BLOQUES))
    ancho = 0.36
    pcts_pre, pcts_post, reales = [], [], []
    for clave, (titulo, minimo, maximo) in BLOQUES.items():
        f = resumen[resumen["bloque"] == clave].iloc[0]
        pcts_pre.append(100 * (f["pre_media"] - minimo) / (maximo - minimo))
        pcts_post.append(100 * (f["post_media"] - minimo) / (maximo - minimo))
        reales.append((f["pre_media"], f["post_media"], maximo))
    b1 = ax.bar(x - ancho / 2, pcts_pre, ancho, color=VIOLETA, label="Antes")
    b2 = ax.bar(x + ancho / 2, pcts_post, ancho, color=DORADO, label="Después")
    for i, (a, d, m) in enumerate(reales):
        ax.text(x[i] - ancho / 2, pcts_pre[i] + 1.5, "%.1f" % a, ha="center", color=CREMA, fontsize=9)
        ax.text(x[i] + ancho / 2, pcts_post[i] + 1.5, "%.1f" % d, ha="center", color=CREMA, fontsize=9)
    ax.set_xticks(x)
    ax.set_xticklabels([v[0] for v in BLOQUES.values()], fontsize=9)
    ax.set_ylabel("Puntaje medio (% del máximo posible)")
    ax.set_ylim(0, 112)
    ax.set_title("Antes y después de jugar, por bloque (n = %d)" % n)
    leyenda(ax)
    marca_prueba(ax, es_prueba)
    fig.tight_layout()
    fig.savefig(os.path.join(args.salida, "barras_bloques.png"), dpi=140, facecolor=FONDO)
    plt.close(fig)

    # 2) Barras por emoción en trivia
    if not emociones.empty:
        fig, ax = figura(9, 4.6)
        x = np.arange(len(emociones))
        ax.bar(x - ancho / 2, emociones["trivia_pct_pre"], ancho, color=VIOLETA, label="Antes")
        ax.bar(x + ancho / 2, emociones["trivia_pct_post"], ancho, color=DORADO, label="Después")
        ax.set_xticks(x)
        ax.set_xticklabels([NOMBRES[e] for e in emociones["emocion"]])
        ax.set_ylabel("Participantes que acertaron (%)")
        ax.set_ylim(0, 112)
        ax.set_title("Trivia: aciertos por emoción, antes y después (n = %d)" % n)
        leyenda(ax)
        marca_prueba(ax, es_prueba)
        fig.tight_layout()
        fig.savefig(os.path.join(args.salida, "barras_emociones_trivia.png"), dpi=140, facecolor=FONDO)
        plt.close(fig)

    # 3) Líneas por participante (total, de pre a post)
    fig, ax = figura(6, 4.8)
    for _, fila in df.iterrows():
        color = VERDE if fila["post_total"] > fila["pre_total"] else (VIOLETA if fila["post_total"] == fila["pre_total"] else "#e0a070")
        ax.plot([0, 1], [fila["pre_total"], fila["post_total"]], color=color, alpha=0.7, marker="o", linewidth=1.3)
    ax.plot([0, 1], [df["pre_total"].mean(), df["post_total"].mean()], color=DORADO, linewidth=3.5, marker="o", markersize=9, label="Media")
    ax.set_xticks([0, 1])
    ax.set_xticklabels(["Antes", "Después"])
    ax.set_xlim(-0.25, 1.25)
    ax.set_ylim(-0.5, 14.5)
    ax.set_ylabel("Total (trivia + situaciones, de 0 a 14)")
    ax.set_title("Cada participante, de antes a después (n = %d)" % n)
    leyenda(ax)
    marca_prueba(ax, es_prueba)
    fig.tight_layout()
    fig.savefig(os.path.join(args.salida, "lineas_participantes.png"), dpi=140, facecolor=FONDO)
    plt.close(fig)

    # --- Experiencia de usuario y comentarios ---
    ux = experiencia_usuario(df, args.salida, es_prueba, args.reportes)

    # --- informe.md ---
    escribir_informe(args.salida, resumen, preguntas, emociones, n, excluidos, repetidos, archivos, es_prueba, avisos, ux)

    print("Participantes analizados: %d (excluidos por datos incompletos: %d; ids repetidos: %d)" % (n, excluidos, repetidos))
    for a in avisos:
        print("AVISO:", a)
    print("Resultados escritos en:", args.salida)



# ----------------------------------------------------------------------------
# Experiencia de usuario (opiniones val_*)

AFIRMACIONES = {
    "u1": "Entendí qué hacer", "u2": "Los controles fueron fáciles", "u3": "Se veía y sonaba bien",
    "u4": "Los textos y pistas ayudaron", "u5": "Ganas de seguir jugando", "u6": "Me hizo pensar en mis emociones",
}
PREGUNTAS_LIBRES = [("val_gusto", "¿Qué fue lo que más te gustó?"), ("val_mejorar", "¿Qué te confundió o qué cambiarías?"),
                    ("val_error", "¿Viste algún error? Cuéntanos qué pasó")]
FRECUENCIAS = ["Nunca", "A veces", "Seguido"]
PALABRAS_VACIAS = set("""a al algo algunas algunos ante antes como con cual cuando de del desde donde el ella ellas ellos en entre era eran es esa
ese eso esta estaba estan este esto estos fue ha han hay la las le les lo los me mi mis muy no nos o para pero poco por porque que se si sin
sobre son su sus tambien te tu tus un una uno unos y ya yo mas más fue fui ser era hubo esa ese hacer hizo""".split())


def quitar_tildes(t):
    for a, b in zip("áéíóúüñ", "aeiouun"):
        t = t.replace(a, b)
    return t


def sus_interpretacion(media):
    if media < 51:
        return "pobre"
    if media < 68:
        return "por debajo del promedio"
    if media < 80:
        return "bueno"
    return "excelente"


def hay_datos(df, col):
    return col in df.columns and pd.to_numeric(df[col], errors="coerce").notna().any()


def experiencia_usuario(df, salida, es_prueba, reportes=None):
    """Genera los gráficos de experiencia de usuario y comentarios.md. Devuelve un diccionario con lo que se calculó."""
    ux = {"hay": False, "n": len(df), "u_medias": {}, "nota": None, "sus": None, "sus_n": 0, "frecuencia": {}, "errores": 0}
    cols_u = [c for c in ["val_u%d" % i for i in range(1, 7)] if hay_datos(df, c)]
    tiene_nota = hay_datos(df, "val_nota")
    if not cols_u and not tiene_nota:
        # Aun sin opiniones numéricas puede haber comentarios o reportes
        escribir_comentarios(df, salida, es_prueba, reportes, ux)
        return ux
    ux["hay"] = True

    # 1) Barras con la media de u1 a u6 (con su desviación)
    if cols_u:
        fig, ax = figura(9, 4.6)
        medias = [pd.to_numeric(df[c], errors="coerce").mean() for c in cols_u]
        sds = [pd.to_numeric(df[c], errors="coerce").std(ddof=1) if len(df) > 1 else 0 for c in cols_u]
        sds = [0 if np.isnan(x) else x for x in sds]
        x = np.arange(len(cols_u))
        ax.bar(x, medias, 0.6, color=DORADO, yerr=sds, capsize=4, error_kw={"ecolor": CREMA})
        for i, m in enumerate(medias):
            ax.text(x[i], m + (sds[i] if sds[i] else 0) + 0.12, "%.1f" % m, ha="center", color=CREMA, fontsize=9)
            ux["u_medias"][cols_u[i][4:]] = (float(m), float(sds[i]))
        ax.set_xticks(x)
        ax.set_xticklabels([AFIRMACIONES[c[4:]] for c in cols_u], fontsize=8, rotation=12, ha="right")
        ax.set_ylim(1, 5.8)
        ax.set_ylabel("Acuerdo medio (1 a 5)")
        ax.set_title("Experiencia de uso: media de cada afirmación (n = %d)" % len(df))
        marca_prueba(ax, es_prueba)
        fig.tight_layout()
        fig.savefig(os.path.join(salida, "barras_experiencia.png"), dpi=140, facecolor=FONDO)
        plt.close(fig)

    # 2) Distribución de la nota general
    if tiene_nota:
        nota = pd.to_numeric(df["val_nota"], errors="coerce").dropna().astype(int)
        fig, ax = figura(6, 4.4)
        cuenta = [int((nota == k).sum()) for k in range(1, 6)]
        ax.bar(range(1, 6), cuenta, 0.6, color=DORADO)
        for k, c in zip(range(1, 6), cuenta):
            ax.text(k, c + 0.05, str(c), ha="center", color=CREMA)
        ax.set_xticks(range(1, 6))
        ax.set_xticklabels(["%d estrella%s" % (k, "" if k == 1 else "s") for k in range(1, 6)], fontsize=8)
        ax.set_ylabel("Participantes")
        ax.set_ylim(0, max(cuenta + [1]) + 1)
        ax.set_title("Nota general del juego (media %.1f, n = %d)" % (nota.mean(), len(nota)))
        marca_prueba(ax, es_prueba)
        fig.tight_layout()
        fig.savefig(os.path.join(salida, "distribucion_nota.png"), dpi=140, facecolor=FONDO)
        plt.close(fig)
        ux["nota"] = (float(nota.mean()), int(len(nota)))

    # 3) SUS por participante (solo si se usó)
    if hay_datos(df, "val_sus"):
        sus = pd.to_numeric(df["val_sus"], errors="coerce").dropna()
        fig, ax = figura(8, 4.6)
        ax.bar(range(len(sus)), sus.values, 0.6, color=VIOLETA)
        for nivel, color, texto in ((51, "#e0a070", "51"), (68, DORADO, "68"), (80, VERDE, "80")):
            ax.axhline(nivel, color=color, linestyle="--", linewidth=1, alpha=0.8)
            ax.text(len(sus) - 0.4, nivel + 1, texto, color=color, fontsize=8, ha="right")
        ax.axhline(sus.mean(), color=DORADO, linewidth=2.5, label="Media %.1f (%s)" % (sus.mean(), sus_interpretacion(sus.mean())))
        ax.set_xticks(range(len(sus)))
        ax.set_xticklabels(["P%d" % (i + 1) for i in range(len(sus))], fontsize=8)
        ax.set_ylim(0, 105)
        ax.set_ylabel("Puntaje SUS (0 a 100)")
        ax.set_title("Usabilidad (SUS) por participante (n = %d)" % len(sus))
        leyenda(ax)
        marca_prueba(ax, es_prueba)
        fig.tight_layout()
        fig.savefig(os.path.join(salida, "sus_participantes.png"), dpi=140, facecolor=FONDO)
        plt.close(fig)
        ux["sus"] = float(sus.mean())
        ux["sus_n"] = int(len(sus))

    # 4) Comparación por frecuencia de juego
    if "val_frecuencia" in df.columns and df["val_frecuencia"].astype(str).isin(FRECUENCIAS).any():
        d = df.copy()
        d["_nota"] = pd.to_numeric(d.get("val_nota"), errors="coerce") if "val_nota" in d.columns else np.nan
        d["_uso"] = d[cols_u].apply(pd.to_numeric, errors="coerce").mean(axis=1) if cols_u else np.nan
        grupos = [(f, d[d["val_frecuencia"] == f]) for f in FRECUENCIAS]
        fig, ax = figura(7, 4.6)
        x = np.arange(len(FRECUENCIAS))
        m_nota = [g["_nota"].mean() if len(g) else np.nan for _, g in grupos]
        m_uso = [g["_uso"].mean() if len(g) else np.nan for _, g in grupos]
        ax.bar(x - ancho_barra / 2, m_nota, ancho_barra, color=DORADO, label="Nota general (1 a 5)")
        ax.bar(x + ancho_barra / 2, m_uso, ancho_barra, color=VIOLETA, label="Media de u1 a u6 (1 a 5)")
        ax.set_xticks(x)
        ax.set_xticklabels(["%s (n = %d)" % (f, len(g)) for f, g in grupos])
        ax.set_ylim(0, 5.8)
        ax.set_ylabel("Media")
        ax.set_title("Opinión según cuánto juegan videojuegos")
        leyenda(ax)
        marca_prueba(ax, es_prueba)
        fig.tight_layout()
        fig.savefig(os.path.join(salida, "comparacion_frecuencia.png"), dpi=140, facecolor=FONDO)
        plt.close(fig)
        ux["frecuencia"] = {f: (len(g), float(g["_nota"].mean()) if len(g) and g["_nota"].notna().any() else None) for f, g in grupos}

    escribir_comentarios(df, salida, es_prueba, reportes, ux)
    return ux


ancho_barra = 0.36


def frases_repetidas(comentarios, minimo=2, maximo=10):
    """Palabras (y pares de palabras) que aparecen en al menos `minimo` comentarios distintos, sin interpretarlas."""
    por_comentario = []
    for c in comentarios:
        palabras = [quitar_tildes(w) for w in re.findall(r"[a-záéíóúüñ]+", c.lower())]
        utiles = [w for w in palabras if w not in PALABRAS_VACIAS and len(w) > 2]
        conjunto = set(utiles)
        conjunto |= {"%s %s" % (palabras[i], palabras[i + 1]) for i in range(len(palabras) - 1)
                     if palabras[i] not in PALABRAS_VACIAS and palabras[i + 1] not in PALABRAS_VACIAS}
        por_comentario.append(conjunto)
    cuenta = Counter()
    for conjunto in por_comentario:
        cuenta.update(conjunto)
    repetidas = [(t, n) for t, n in cuenta.items() if n >= minimo]
    # los pares ganan a las palabras sueltas que contienen; se ordena por veces y por largo
    repetidas.sort(key=lambda x: (-x[1], -len(x[0].split()), x[0]))
    return repetidas[:maximo]


def leer_reportes(carpeta):
    filas = []
    if carpeta and os.path.isdir(carpeta):
        for ruta in sorted(glob.glob(os.path.join(carpeta, "*.json"))):
            try:
                with open(ruta, encoding="utf-8") as f:
                    d = json.load(f)
            except (OSError, ValueError):
                continue
            filas.append({"fecha": str(d.get("fecha_iso", ""))[:16], "escena": os.path.basename(str(d.get("escena", ""))),
                          "epoca": d.get("epoca", ""), "version": d.get("version_juego", ""), "texto": str(d.get("texto", "")).replace("\n", " "),
                          "captura": d.get("captura", "")})
    return filas


def escribir_comentarios(df, salida, es_prueba, reportes, ux):
    L = []
    if es_prueba:
        L += ["> **DATOS DE PRUEBA.** Estos comentarios son inventados (NO reales).", ""]
    L += ["# Comentarios de los participantes", "",
          "Aquí van los comentarios libres tal como se escribieron, agrupados por pregunta. Las palabras y frases que se repiten "
          "se cuentan por número de comentarios distintos; son solo una ayuda para leer, no una interpretación.", ""]
    for col, pregunta in PREGUNTAS_LIBRES:
        L += ["## %s" % pregunta, ""]
        if col not in df.columns:
            L += ["_No hay datos de esta pregunta._", ""]
            continue
        comentarios = [str(c).strip() for c in df[col].fillna("") if str(c).strip() and str(c).strip().lower() != "nan"]
        if not comentarios:
            L += ["_Nadie escribió nada en esta pregunta._", ""]
            continue
        L += ["%d comentario%s de %d participantes." % (len(comentarios), "" if len(comentarios) == 1 else "s", len(df)), ""]
        rep = frases_repetidas(comentarios)
        if rep:
            L.append("**Lo que más se repite:** " + "; ".join("«%s» (%d)" % (t, n) for t, n in rep))
            L.append("")
        elif len(comentarios) < 4:
            L += ["_Hay pocos comentarios para encontrar ideas repetidas._", ""]
        for c in comentarios:
            L.append("- " + c.replace("\n", " "))
        L.append("")
    # Tabla de errores: lo escrito en val_error y los reportes de F8
    L += ["## Errores reportados", ""]
    errores = []
    if "val_error" in df.columns:
        for _, f in df.iterrows():
            t = str(f.get("val_error", "")).strip()
            if t and t.lower() != "nan" and t.lower() not in ("nada", "no", "ninguno", "ninguna"):
                errores.append(("Valoración", str(f.get("id_participante", "")), "", t))
    for r in leer_reportes(reportes):
        errores.append(("Reporte F8 (%s, %s, v%s)" % (r["escena"], r["epoca"], r["version"]), r["fecha"], r["captura"], r["texto"]))
    ux["errores"] = len(errores)
    if errores:
        L += ["| Origen | Participante o fecha | Captura | Qué pasó |", "|---|---|---|---|"]
        for origen, quien, captura, texto in errores:
            L.append("| %s | %s | %s | %s |" % (origen, quien, captura, texto.replace("|", "/").replace("\n", " ")))
        L.append("")
    else:
        L += ["_No hay errores reportados._", ""]
    if reportes:
        L += ["_Los reportes de F8 se leen de `%s` (copia ahí la carpeta `reportes` de cada computador)._" % os.path.relpath(reportes, RAIZ) if os.path.isdir(reportes) else
              "_No se encontró la carpeta de reportes de F8 (`%s`)._" % reportes, ""]
    with open(os.path.join(salida, "comentarios.md"), "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(L))


def fmt_p(p):
    if np.isnan(p):
        return "no calculado"
    return "p < 0,001" if p < 0.001 else ("p = %.3f" % p).replace(".", ",")


def coma(x, dec=2):
    return (("%." + str(dec) + "f") % x).replace(".", ",") if not np.isnan(x) else "—"


def escribir_informe(salida, resumen, preguntas, emociones, n, excluidos, repetidos, archivos, es_prueba, avisos, ux=None):
    L = []
    if es_prueba:
        L += ["> **DATOS DE PRUEBA.** Este informe se generó con datos inventados (NO reales). No lo uses como resultado.", ""]
    L += ["# Resultados de la evaluación de ECOS", ""]
    L.append("Se analizaron las respuestas de **%d participantes** (de %d archivo%s). Cada persona contestó las mismas "
             "16 preguntas antes de jugar y después de terminar el juego: 7 de trivia, 7 de situaciones y 2 de escala."
             % (n, len(archivos), "" if len(archivos) == 1 else "s"))
    if excluidos or repetidos:
        L.append("Se dejaron fuera %d participante%s con datos incompletos y %d fila%s repetida%s." % (
            excluidos, "" if excluidos == 1 else "s", repetidos, "" if repetidos == 1 else "s", "" if repetidos == 1 else "s"))
    L += ["", "## Resultados por bloque", ""]
    for _, f in resumen.iterrows():
        dif = f["dif_media"]
        sentido = "subió" if dif > 0.05 else ("bajó" if dif < -0.05 else "se mantuvo casi igual")
        parrafo = "**%s.** La media %s de %s (desviación %s) a %s (desviación %s); la diferencia media fue de %s%s." % (
            f["titulo"], sentido, coma(f["pre_media"]), coma(f["pre_sd"]), coma(f["post_media"]), coma(f["post_sd"]),
            "+" if dif > 0 else "", coma(dif))
        if f["wilcoxon_nota"].startswith("no hay datos"):
            parrafo += " Con tan pocos participantes (n = %d; hacen falta al menos %d) **no hay datos suficientes para una prueba estadística**." % (f["n_wilcoxon"], MINIMO_WILCOXON)
        elif f["wilcoxon_nota"]:
            parrafo += " No se pudo calcular la prueba de Wilcoxon: %s." % f["wilcoxon_nota"]
        else:
            parrafo += " La prueba de rangos con signo de Wilcoxon para muestras relacionadas dio %s (n = %d)." % (fmt_p(f["wilcoxon_p"]), f["n_wilcoxon"])
        if not np.isnan(f["ganancia_normalizada_media"]):
            parrafo += " La ganancia normalizada media fue de %s (calculada con %d participantes que no tenían ya el máximo)." % (
                coma(f["ganancia_normalizada_media"]), f["n_ganancia"])
        L += [parrafo, ""]
    if not emociones.empty:
        L += ["## Por emoción", ""]
        mejor = emociones.assign(d=emociones["trivia_pct_post"] - emociones["trivia_pct_pre"]).sort_values("d", ascending=False).iloc[0]
        peor = emociones.assign(d=emociones["trivia_pct_post"] - emociones["trivia_pct_pre"]).sort_values("d").iloc[0]
        L.append("En trivia, la emoción con más mejora fue **%s** (de %d %% a %d %% de aciertos) y la de menos cambio fue **%s** (de %d %% a %d %%)." % (
            NOMBRES[mejor["emocion"]], round(mejor["trivia_pct_pre"]), round(mejor["trivia_pct_post"]),
            NOMBRES[peor["emocion"]], round(peor["trivia_pct_pre"]), round(peor["trivia_pct_post"])))
        L += ["", "Mirando trivia y situaciones juntas, por emoción:", ""]
        for _, e in emociones.iterrows():
            L.append("- %s: mejoraron %d, se mantuvieron %d y bajaron %d." % (NOMBRES[e["emocion"]], e["mejoraron"], e["se_mantuvieron"], e["bajaron"]))
        L.append("")
    p = preguntas[preguntas["bloque"] != "escala"].copy()
    if not p.empty:
        p["d"] = p["pct_acierto_post"] - p["pct_acierto_pre"]
        dificil = p.sort_values("pct_acierto_post").iloc[0]
        L += ["## Preguntas", "",
              "La pregunta con menos aciertos al final fue `%s` (%d %%). El detalle de cada pregunta está en `preguntas.csv`." % (dificil["id"], round(dificil["pct_acierto_post"])), ""]
    if ux and ux["hay"]:
        L += ["## Experiencia de usuario", ""]
        if n < MINIMO_WILCOXON:
            L += ["Con solo %d participantes estas cifras son una primera impresión, no una conclusión." % n, ""]
        if ux["u_medias"]:
            partes = ["%s: %s (desviación %s)" % (AFIRMACIONES[k], coma(m, 1), coma(sd, 1)) for k, (m, sd) in ux["u_medias"].items()]
            L += ["En las afirmaciones de 1 (nada de acuerdo) a 5 (totalmente de acuerdo), las medias fueron: " + "; ".join(partes) + ".", ""]
        if ux["nota"]:
            L += ["La nota general media fue de **%s** estrellas sobre 5 (n = %d)." % (coma(ux["nota"][0], 1), ux["nota"][1]), ""]
        if ux["sus"] is not None:
            L += ["El puntaje SUS medio fue de **%s** sobre 100 (n = %d), que por la interpretación habitual se considera **%s** "
                  "(menos de 51: pobre; 51 a 68: por debajo del promedio; 68 a 80: bueno; más de 80: excelente)." % (coma(ux["sus"], 1), ux["sus_n"], sus_interpretacion(ux["sus"])), ""]
        if ux["frecuencia"]:
            partes = ["%s: n = %d" % (f, c) for f, (c, _) in ux["frecuencia"].items()]
            L += ["Según cuánto juegan videojuegos (%s), las medias se comparan en `comparacion_frecuencia.png`; con grupos tan pequeños sirve solo para mirar tendencias." % ", ".join(partes), ""]
        L += ["Los comentarios libres y los errores reportados están en `comentarios.md` (%d error%s anotado%s)." % (ux["errores"], "" if ux["errores"] == 1 else "es", "" if ux["errores"] == 1 else "s"), ""]
    L += ["## Cómo leer estos números", "",
          "El valor p de Wilcoxon indica si la diferencia entre el antes y el después es mayor de lo que se esperaría solo por azar; "
          "un valor p pequeño apoya la idea de un cambio, pero no dice por qué ocurrió ni lo grande que es. "
          "La ganancia normalizada dice qué parte del margen de mejora posible se aprovechó (0 = nada, 1 = todo).", "",
          "## Limitaciones", "",
          "- **Muestra pequeña:** con pocos participantes los resultados son frágiles y las pruebas estadísticas tienen poca potencia.",
          "- **Mismos cuestionarios antes y después:** quienes participan pueden recordar sus respuestas anteriores.",
          "- **Autoinforme:** las situaciones y las escalas dependen de lo que cada persona dice de sí misma, no de lo que hace.",
          "- **Sin grupo de control:** no se puede saber cuánto del cambio se debe al juego y cuánto a otras causas (por ejemplo, haber hecho las preguntas antes).",
          "- **Opiniones:** las valoraciones también son autoinforme y pueden estar influidas por querer agradar a quien hizo el juego.",
          "- **No es una medición psicológica validada:** las preguntas son una herramienta educativa de este proyecto, no un test psicológico ni dan diagnósticos.", ""]
    with open(os.path.join(salida, "informe.md"), "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(L))


if __name__ == "__main__":
    main()
