#!/usr/bin/env python3
"""Análisis de los resultados de ECOS (evaluación antes y después de jugar).

Uso:
    python tools/analizar_resultados.py RUTA [RUTA ...] [--salida docs/analisis] [--permitir-prueba]

RUTA puede ser un CSV (ECOS_resultados.csv de un computador) o una carpeta con varios CSV (se unen todos).
Necesita pandas, numpy, matplotlib y scipy.

Genera en la carpeta de salida (por defecto docs/analisis/):
  resumen.csv     participantes, media y desviación de pre y post por bloque, diferencia, ganancia normalizada, Wilcoxon
  preguntas.csv   porcentaje de acierto antes y después de cada pregunta
  emociones.csv   por emoción: aciertos antes y después, y cuántos mejoraron, se mantuvieron o bajaron
  barras_bloques.png, barras_emociones_trivia.png, lineas_participantes.png
  informe.md      un párrafo por resultado en lenguaje claro y las limitaciones

SEGURIDAD: se niega a procesar un CSV con la columna "dato_de_prueba" (datos inventados), salvo con
--permitir-prueba; en ese caso escribe "DATOS DE PRUEBA" en cada gráfico y en el informe.
"""
import argparse
import glob
import os
import sys

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
        plt.gcf().text(0.99, 0.012, "DATOS DE PRUEBA", ha="right", va="bottom", color="#e0a070", fontsize=11, fontweight="bold")


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


def main():
    ap = argparse.ArgumentParser(description="Análisis de resultados de ECOS")
    ap.add_argument("rutas", nargs="+", help="CSV o carpetas con CSV de ECOS_resultados")
    ap.add_argument("--salida", default=os.path.join(RAIZ, "docs", "analisis"), help="carpeta de salida")
    ap.add_argument("--permitir-prueba", action="store_true", help="acepta CSV de datos de prueba (NO reales)")
    args = ap.parse_args()

    df, archivos = leer_csvs(args.rutas)
    es_prueba = "dato_de_prueba" in df.columns
    if es_prueba and not args.permitir_prueba:
        print("=" * 70)
        print("AVISO: este CSV tiene la columna 'dato_de_prueba': son datos INVENTADOS, no reales.")
        print("No se procesa para que no se mezclen por error con resultados de personas.")
        print("Si solo quieres probar el script, usa --permitir-prueba.")
        print("=" * 70)
        sys.exit(2)

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

    # --- informe.md ---
    escribir_informe(args.salida, resumen, preguntas, emociones, n, excluidos, repetidos, archivos, es_prueba, avisos)

    print("Participantes analizados: %d (excluidos por datos incompletos: %d; ids repetidos: %d)" % (n, excluidos, repetidos))
    for a in avisos:
        print("AVISO:", a)
    print("Resultados escritos en:", args.salida)


def fmt_p(p):
    if np.isnan(p):
        return "no calculado"
    return "p < 0,001" if p < 0.001 else ("p = %.3f" % p).replace(".", ",")


def coma(x, dec=2):
    return (("%." + str(dec) + "f") % x).replace(".", ",") if not np.isnan(x) else "—"


def escribir_informe(salida, resumen, preguntas, emociones, n, excluidos, repetidos, archivos, es_prueba, avisos):
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
    L += ["## Cómo leer estos números", "",
          "El valor p de Wilcoxon indica si la diferencia entre el antes y el después es mayor de lo que se esperaría solo por azar; "
          "un valor p pequeño apoya la idea de un cambio, pero no dice por qué ocurrió ni lo grande que es. "
          "La ganancia normalizada dice qué parte del margen de mejora posible se aprovechó (0 = nada, 1 = todo).", "",
          "## Limitaciones", "",
          "- **Muestra pequeña:** con pocos participantes los resultados son frágiles y las pruebas estadísticas tienen poca potencia.",
          "- **Mismos cuestionarios antes y después:** quienes participan pueden recordar sus respuestas anteriores.",
          "- **Autoinforme:** las situaciones y las escalas dependen de lo que cada persona dice de sí misma, no de lo que hace.",
          "- **Sin grupo de control:** no se puede saber cuánto del cambio se debe al juego y cuánto a otras causas (por ejemplo, haber hecho las preguntas antes).",
          "- **No es una medición psicológica validada:** las preguntas son una herramienta educativa de este proyecto, no un test psicológico ni dan diagnósticos.", ""]
    with open(os.path.join(salida, "informe.md"), "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(L))


if __name__ == "__main__":
    main()
