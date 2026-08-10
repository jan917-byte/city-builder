# -*- coding: utf-8 -*-
"""
Aperçu PNG de Vallmar2.gpkg — la boucle « je dessine dans QGIS → on regarde ».

Lecture seule. N'écrit jamais dans le GeoPackage : il est ouvert en mode `ro`,
et le PNG sort à côté. Peut tourner pendant que QGIS est ouvert.

    python apercu_carte.py

Coloriage des îlots, par ordre de priorité :
  1. le champ `fonction` de la couche `ilots`, s'il existe (source de vérité)
  2. sinon `classification.json`, à éditer à la main en attendant

Dépendance : Pillow.  →  pip install pillow
"""

import json
import math
import os
import sqlite3
import struct
import sys

# La console Windows est en cp1252 : sans ça, un simple « é » fait planter le
# script à l'affichage. Voir CLAUDE.md, section « pièges de cet environnement ».
for flux in (sys.stdout, sys.stderr):
    try:
        flux.reconfigure(encoding="utf-8", errors="replace")
    except (AttributeError, OSError):
        pass

ICI = os.path.dirname(os.path.abspath(__file__))
DATA = os.path.join(os.path.dirname(ICI), "data")
RENDUS = os.path.join(os.path.dirname(ICI), "rendus")
# `python apercu_carte.py autre_fichier.gpkg` pour regarder une autre version
# `python apercu_carte.py fichier.gpkg --adjacences` pour voir le graphe
ARGS = [a for a in sys.argv[1:] if not a.startswith("--")]
MODE_ADJ = "--adjacences" in sys.argv
# `--calque alea` : n'importe quel attribut numérique, en dégradé sur la carte.
# Les attributs de rue (charge, emprise_libre_m…) colorent les traits.
CALQUE = next((a.split("=", 1)[1] for a in sys.argv
               if a.startswith("--calque=")), None)
GPKG = os.path.abspath(ARGS[0]) if ARGS else os.path.join(DATA, "Vallmar2.gpkg")
CLASSIF = os.path.join(ICI, "classification.json")
SORTIE = os.path.join(RENDUS, "apercu_%s%s.png"
                      % (os.path.splitext(os.path.basename(GPKG))[0].lower(),
                         "_adjacences" if MODE_ADJ
                         else ("_" + CALQUE if CALQUE else "")))

# Dégradé des calques : du froid « rien » au chaud « beaucoup ».
RAMPE = [(232, 237, 240), (168, 198, 206), (232, 206, 128),
         (222, 138, 74), (176, 48, 44)]

LARGEUR_PX = 2200          # largeur de l'image, hors marge
TOL_NOEUD = 0.5            # m — tolérance de raccord entre deux extrémités

# Palette. Volontairement plate et lisible, ce n'est pas la DA du jeu.
# Les `sous_type` priment sur les `fonction` : c'est là qu'est le level design.
COULEURS = {
    # fonctions
    "riviere":    (108, 156, 184),
    "freiraum":   (168, 190, 140),
    "habitation": (214, 205, 188),
    "industrie":  (176, 158, 146),
    "mixte":      (206, 190, 160),
    # sous-types
    "champ":               (156, 176, 122),
    "parc":                (122, 162, 104),
    "jardins_familiaux":   (176, 190, 126),
    "place_minerale":      (196, 128, 108),   # la plaie : la place-parking
    "coeur_ancien":        (208, 186, 150),
    "front_commercant":    (226, 176, 106),
    "dalle_commerciale":   (168, 106, 96),    # la plaie : la galerie de 1971
    "quai_voie_rapide":    (188, 124, 112),   # la plaie : la berge en voie rapide
    "equipement":          (170, 158, 196),
    "maisons_de_ville":    (214, 198, 172),
    "pavillonnaire":       (238, 232, 214),
    "barre_1970":          (192, 176, 190),
    "friche_industrielle": (150, 132, 122),
    None:                  (222, 216, 204),   # non qualifié
}
COUL_FOND = (247, 244, 237)
COUL_TRAIT = (120, 110, 92)
COUL_RUE = (70, 64, 56)
COUL_ALERTE = (214, 62, 50)

# Épaisseur du trait par hiérarchie. La clé est comparée en minuscules.
EPAISSEUR = {
    "autoroute": 9, "boulevard": 6, "rue": 3, "ruelle": 2,
    "rive": 2, "voie ferree": 3, "voie ferrée": 3,
}
COUL_HIER = {
    "autoroute": (150, 60, 45), "boulevard": (196, 92, 62),
    "rive": (108, 156, 184), "voie ferree": (110, 100, 90),
    "voie ferrée": (110, 100, 90),
}


# --------------------------------------------------------------- géométrie

def gpkg_vers_wkb(blob):
    """Retire l'en-tête GeoPackage pour ne garder que le WKB."""
    if blob[0:2] != b"GP":
        raise ValueError("blob non GeoPackage")
    indicateur = (blob[3] >> 1) & 0x07
    tailles = {0: 0, 1: 32, 2: 48, 3: 48, 4: 64}
    return blob[8 + tailles[indicateur]:]


def _entier(buf, off, ordre):
    return struct.unpack_from(ordre + "I", buf, off)[0], off + 4


def _points(buf, off, ordre, n):
    c = struct.unpack_from(ordre + "%dd" % (2 * n), buf, off)
    return [(c[i], c[i + 1]) for i in range(0, 2 * n, 2)], off + 16 * n


def lire_wkb(buf, off=0):
    """→ (parts, off). Une part = une liste de points (anneau ou polyligne)."""
    ordre = "<" if buf[off] == 1 else ">"
    off += 1
    gtype, off = _entier(buf, off, ordre)
    base = gtype % 1000
    if base == 2:                                    # LineString
        n, off = _entier(buf, off, ordre)
        pts, off = _points(buf, off, ordre, n)
        return [pts], off
    if base == 3:                                    # Polygon
        na, off = _entier(buf, off, ordre)
        anneaux = []
        for _ in range(na):
            n, off = _entier(buf, off, ordre)
            pts, off = _points(buf, off, ordre, n)
            anneaux.append(pts)
        return anneaux, off
    if base in (5, 6):                               # Multi*
        ng, off = _entier(buf, off, ordre)
        tout = []
        for _ in range(ng):
            p, off = lire_wkb(buf, off)
            tout.extend(p)
        return tout, off
    raise ValueError("type WKB non géré : %d" % base)


def aire(anneau):
    s = 0.0
    for i in range(len(anneau) - 1):
        s += anneau[i][0] * anneau[i + 1][1] - anneau[i + 1][0] * anneau[i][1]
    return abs(s) / 2.0


def dedans(anneau, p):
    x, y = p
    d = False
    for i in range(len(anneau) - 1):
        x1, y1 = anneau[i]
        x2, y2 = anneau[i + 1]
        if (y1 > y) != (y2 > y) and x < x1 + (y - y1) * (x2 - x1) / (y2 - y1):
            d = not d
    return d


def point_interieur(anneau):
    """Un point où poser l'étiquette, garanti dans le polygone."""
    cx = cy = a = 0.0
    for i in range(len(anneau) - 1):
        x1, y1 = anneau[i]
        x2, y2 = anneau[i + 1]
        cr = x1 * y2 - x2 * y1
        a += cr
        cx += (x1 + x2) * cr
        cy += (y1 + y2) * cr
    if a != 0:
        c = (cx / (3 * a), cy / (3 * a))
        if dedans(anneau, c):
            return c
    # repli : le plus large segment horizontal à mi-hauteur
    ys = sorted(p[1] for p in anneau)
    for frac in (0.5, 0.4, 0.6, 0.3, 0.7):
        y = ys[max(0, int(len(ys) * frac) - 1)]
        xs = []
        for i in range(len(anneau) - 1):
            x1, y1 = anneau[i]
            x2, y2 = anneau[i + 1]
            if (y1 > y) != (y2 > y):
                xs.append(x1 + (y - y1) * (x2 - x1) / (y2 - y1))
        xs.sort()
        meilleur = None
        for i in range(0, len(xs) - 1, 2):
            large = xs[i + 1] - xs[i]
            if meilleur is None or large > meilleur[0]:
                meilleur = (large, (xs[i] + xs[i + 1]) / 2, y)
        if meilleur and meilleur[0] > 1:
            return (meilleur[1], meilleur[2])
    return anneau[0]


def dist_point_segment(p, a, b):
    px, py = p
    ax, ay = a
    bx, by = b
    dx, dy = bx - ax, by - ay
    L2 = dx * dx + dy * dy
    if L2 == 0:
        return math.hypot(px - ax, py - ay)
    t = max(0.0, min(1.0, ((px - ax) * dx + (py - ay) * dy) / L2))
    return math.hypot(px - (ax + t * dx), py - (ay + t * dy))


# ------------------------------------------------------------------ lecture

def colonnes(cur, table):
    return [r[1] for r in cur.execute('PRAGMA table_info("%s")' % table)]


def charger():
    con = sqlite3.connect("file:%s?mode=ro" % GPKG.replace("\\", "/"), uri=True)
    cur = con.cursor()
    tables = [r[0] for r in cur.execute(
        "SELECT table_name FROM gpkg_geometry_columns")]

    t_ilots = "ilots" if "ilots" in tables else None
    t_rues = "rues" if "rues" in tables else ("routes" if "routes" in tables else None)
    if not t_ilots or not t_rues:
        raise SystemExit("couches attendues introuvables : %s" % tables)

    ci = colonnes(cur, t_ilots)
    cr = colonnes(cur, t_rues)
    if CALQUE and CALQUE not in ci and CALQUE not in cr:
        raise SystemExit("champ « %s » introuvable.\n  îlots : %s\n  rues  : %s"
                         % (CALQUE, ", ".join(ci), ", ".join(cr)))
    calque_ilot = CALQUE if CALQUE in ci else None
    calque_rue = CALQUE if (CALQUE and CALQUE not in ci and CALQUE in cr) else None

    # on colorie d'après `sous_type` s'il existe, sinon `fonction`
    champ_fonction = "sous_type" if "sous_type" in ci else (
        "fonction" if "fonction" in ci else None)
    sel = "fid, geom" + (", %s" % champ_fonction if champ_fonction else "") \
        + (", %s" % calque_ilot if calque_ilot else "")
    ilots = []
    for r in cur.execute("SELECT %s FROM %s" % (sel, t_ilots)):
        anneaux, _ = lire_wkb(gpkg_vers_wkb(r[1]))
        a = aire(anneaux[0]) - sum(aire(x) for x in anneaux[1:])
        ilots.append({"fid": r[0], "anneaux": anneaux, "aire": a,
                      "fonction": (r[2] if champ_fonction else None),
                      "val": (r[-1] if calque_ilot else None)})

    champ_hier = "hierarchie" if "hierarchie" in cr else (
        "hierarchy" if "hierarchy" in cr else None)
    a_largeur = "largeur_m" in cr
    sel = "fid, geom" + (", %s" % champ_hier if champ_hier else "") \
        + (", largeur_m" if a_largeur else "") \
        + (", %s" % calque_rue if calque_rue else "")
    rues = []
    for r in cur.execute("SELECT %s FROM %s" % (sel, t_rues)):
        parts, _ = lire_wkb(gpkg_vers_wkb(r[1]))
        lg = sum(math.hypot(p[i + 1][0] - p[i][0], p[i + 1][1] - p[i][1])
                 for p in parts for i in range(len(p) - 1))
        h = (r[2] if champ_hier else None)
        n = 2 + (1 if champ_hier else 0)
        rues.append({"fid": r[0], "parts": parts, "long": lg,
                     "hier": (h or "").strip().lower() or None,
                     "largeur": (r[n] if a_largeur else None),
                     "val": (r[-1] if calque_rue else None)})
    adj = []
    try:
        adj = list(cur.execute("SELECT id_a, id_b, hierarchie_separatrice, "
                               "longueur_m, permeabilite FROM adjacences"))
    except sqlite3.OperationalError:
        pass

    con.close()
    return ilots, rues, t_rues, champ_fonction, champ_hier, adj, calque_rue


def brins_morts(rues):
    """Extrémités qui ne touchent aucune autre ligne, ni en bout ni en T."""
    from collections import Counter
    def cle(p):
        return (round(p[0] / TOL_NOEUD), round(p[1] / TOL_NOEUD))

    compte = Counter()
    for r in rues:
        for p in r["parts"]:
            compte[cle(p[0])] += 1
            compte[cle(p[-1])] += 1
    libres = {k for k, v in compte.items() if v == 1}

    segments = [(r["fid"], p[i], p[i + 1])
                for r in rues for p in r["parts"] for i in range(len(p) - 1)]
    trouves = []
    for r in rues:
        for p in r["parts"]:
            for e in (p[0], p[-1]):
                if cle(e) not in libres:
                    continue
                d_min = min((dist_point_segment(e, a, b)
                             for f, a, b in segments if f != r["fid"]),
                            default=1e9)
                if d_min > TOL_NOEUD:
                    trouves.append((r["fid"], e, d_min))
    return trouves


# ------------------------------------------------------------------- rendu

def couleur_perm(p):
    """Rouge = coupure, vert = on passe. C'est la lecture du graphe."""
    p = 0.0 if p is None else max(0.0, min(1.0, p))
    coupe = (198, 62, 48)
    passe = (74, 142, 96)
    return tuple(int(coupe[i] + (passe[i] - coupe[i]) * p) for i in range(3))


def couleur_rampe(t):
    """0 → froid, 1 → chaud. Interpolation linéaire dans RAMPE."""
    t = max(0.0, min(1.0, t)) * (len(RAMPE) - 1)
    i = min(int(t), len(RAMPE) - 2)
    f = t - i
    a, b = RAMPE[i], RAMPE[i + 1]
    return tuple(int(a[k] + (b[k] - a[k]) * f) for k in range(3))


def rendre(ilots, rues, morts, fonctions, titre, adj, calque_rue):
    from PIL import Image, ImageDraw, ImageFont

    xs = [p[0] for i in ilots for a in i["anneaux"] for p in a]
    ys = [p[1] for i in ilots for a in i["anneaux"] for p in a]
    minx, maxx, miny, maxy = min(xs), max(xs), min(ys), max(ys)
    L, H = maxx - minx, maxy - miny
    MARGE = 60
    S = LARGEUR_PX / L

    im = Image.new("RGB", (int(L * S) + 2 * MARGE, int(H * S) + 2 * MARGE),
                   COUL_FOND)
    d = ImageDraw.Draw(im)
    try:
        petite = ImageFont.truetype("consola.ttf", 15)
        grande = ImageFont.truetype("arial.ttf", 22)
        titre_f = ImageFont.truetype("arialbd.ttf", 28)
    except OSError:
        petite = grande = titre_f = ImageFont.load_default()

    def T(p):
        return (MARGE + (p[0] - minx) * S, MARGE + (maxy - p[1]) * S)

    def melange(c, k):
        return tuple(int(v + (247 - v) * k) for v in c)

    k = 0.72 if MODE_ADJ else 0.0          # en mode graphe, la carte s'efface

    # bornes du calque, pour normaliser le dégradé
    vals = [x["val"] for x in (rues if calque_rue else ilots)
            if x.get("val") is not None]
    vmin, vmax = (min(vals), max(vals)) if vals else (0.0, 1.0)
    ecart = (vmax - vmin) or 1.0

    for i in ilots:
        f = i["fonction"] or fonctions.get(i["fid"])
        if CALQUE and not calque_rue:
            c = couleur_rampe((i["val"] - vmin) / ecart) \
                if i["val"] is not None else (238, 236, 232)
        elif CALQUE:
            c = melange(COULEURS.get(f, COULEURS[None]), 0.55)
        else:
            c = melange(COULEURS.get(f, COULEURS[None]), k)
        d.polygon([T(p) for p in i["anneaux"][0]],
                  fill=c, outline=melange(COUL_TRAIT, k))

    for r in rues:
        h = r["hier"]
        if calque_rue:
            coul = couleur_rampe((r["val"] - vmin) / ecart) \
                if r["val"] is not None else (200, 198, 194)
            ep = EPAISSEUR.get(h, 3) + 3
        elif CALQUE:
            coul, ep = (86, 80, 72), max(2, EPAISSEUR.get(h, 3) - 1)
        else:
            coul, ep = melange(COUL_HIER.get(h, COUL_RUE), k), EPAISSEUR.get(h, 3)
        for part in r["parts"]:
            d.line([T(p) for p in part], fill=coul, width=ep, joint="curve")

    if MODE_ADJ:
        centres = {i["fid"]: T(point_interieur(i["anneaux"][0])) for i in ilots}
        # du plus coupant au moins coupant, pour que les coupures restent visibles
        for a, b, h, L, p in sorted(adj, key=lambda r: -(r[4] or 0)):
            if a not in centres or b not in centres:
                continue
            c = couleur_perm(p)
            d.line([centres[a], centres[b]], fill=c,
                   width=max(2, int(2 + 7 * (p or 0))))
        for f, (x, y) in centres.items():
            d.ellipse([x - 6, y - 6, x + 6, y + 6], fill=(40, 34, 26))

    for i in ilots:
        x, y = T(point_interieur(i["anneaux"][0]))
        t = str(i["fid"])
        bb = d.textbbox((0, 0), t, font=petite)
        if MODE_ADJ:
            y -= 20
        d.text((x - (bb[2] - bb[0]) / 2, y - (bb[3] - bb[1]) / 2), t,
               fill=(40, 34, 26), font=petite)

    if not MODE_ADJ:
        for fid, e, _dm in morts:
            x, y = T(e)
            d.ellipse([x - 11, y - 11, x + 11, y + 11],
                      outline=COUL_ALERTE, width=4)

    # ---- légende, posée sur la carte, dans le coin le plus vide
    compte = {}
    for i in ilots:
        f = i["fonction"] or fonctions.get(i["fid"])
        if f:
            compte[f] = compte.get(f, 0) + 1
    labels = sorted(compte, key=lambda k: -compte[k])

    hier_presentes = {}
    for r in rues:
        if r["hier"]:
            hier_presentes.setdefault(r["hier"], []).append(r.get("largeur"))

    if MODE_ADJ:
        par_h = {}
        for a, b, h, L, p in adj:
            e = par_h.setdefault(h, [0, 0.0])
            e[0] += 1
            e[1] += p or 0
        labels = []
        hier_presentes = {}

    if CALQUE:
        labels, hier_presentes = [], {}

    LH = 30
    lignes = 3 + len(labels) + 2 + len(hier_presentes) + 2
    if MODE_ADJ:
        lignes = 5 + len(par_h) + 3
    if CALQUE:
        lignes = 9
    LARG = 460
    HAUT = lignes * LH
    bx, by = MARGE + 18, MARGE + 18

    fond = Image.new("RGBA", (LARG, HAUT), (247, 244, 237, 232))
    im.paste(fond, (bx, by), fond)
    d.rectangle([bx, by, bx + LARG, by + HAUT], outline=COUL_TRAIT, width=2)

    y = by + 16
    d.text((bx + 18, y), titre, fill=(30, 26, 20), font=titre_f)
    y += LH + 6

    if MODE_ADJ:
        d.text((bx + 18, y), "ADJACENCES  (%d paires)" % len(adj),
               fill=(90, 82, 68), font=grande)
        y += LH + 4
        for i in range(0, 220):
            p = i / 219.0
            d.line([(bx + 18 + i, y + 4), (bx + 18 + i, y + 20)],
                   fill=couleur_perm(p))
        d.rectangle([bx + 18, y + 4, bx + 237, y + 20], outline=COUL_TRAIT)
        d.text((bx + 18, y + 26), "coupure", fill=(40, 34, 26), font=grande)
        d.text((bx + 150, y + 26), "on passe", fill=(40, 34, 26), font=grande)
        y += LH + 34
        d.text((bx + 18, y), "perméabilité moyenne par séparateur",
               fill=(90, 82, 68), font=grande)
        y += LH
        for h in sorted(par_h, key=lambda k: -par_h[k][0]):
            n, sp = par_h[h]
            moy = sp / n
            d.line([(bx + 18, y + 12), (bx + 44, y + 12)],
                   fill=couleur_perm(moy), width=max(2, int(2 + 7 * moy)))
            d.text((bx + 56, y), "%s  (%d)   %.2f" % (h, n, moy),
                   fill=(40, 34, 26), font=grande)
            y += LH
        y += 14
        d.line([(bx + 18, y + 12), (bx + 18 + 100 * S, y + 12)],
               fill=(40, 34, 26), width=4)
        d.text((bx + 28 + 100 * S, y), "100 m", fill=(40, 34, 26), font=grande)
        im.save(SORTIE)
        return im.size

    if CALQUE:
        d.text((bx + 18, y), "%s  (%s)" % (CALQUE, "rues" if calque_rue else "îlots"),
               fill=(90, 82, 68), font=grande)
        y += LH + 8
        for i in range(0, 300):
            d.line([(bx + 18 + i, y), (bx + 18 + i, y + 24)],
                   fill=couleur_rampe(i / 299.0))
        d.rectangle([bx + 18, y, bx + 317, y + 24], outline=COUL_TRAIT)
        y += 30
        d.text((bx + 18, y), "%g" % round(vmin, 2), fill=(40, 34, 26), font=grande)
        t = "%g" % round(vmax, 2)
        bb = d.textbbox((0, 0), t, font=grande)
        d.text((bx + 317 - (bb[2] - bb[0]), y), t, fill=(40, 34, 26), font=grande)
        y += LH + 4
        n = len(vals)
        med = sorted(vals)[n // 2] if n else 0
        d.text((bx + 18, y), "%d valeurs · médiane %g" % (n, round(med, 2)),
               fill=(90, 82, 68), font=grande)
        y += LH + 14
        d.line([(bx + 18, y + 12), (bx + 18 + 100 * S, y + 12)],
               fill=(40, 34, 26), width=4)
        d.text((bx + 28 + 100 * S, y), "100 m", fill=(40, 34, 26), font=grande)
        im.save(SORTIE)
        return im.size

    d.text((bx + 18, y), "ÎLOTS", fill=(90, 82, 68), font=grande)
    y += LH
    for lab in labels:
        d.rectangle([bx + 18, y + 2, bx + 44, y + 22],
                    fill=COULEURS.get(lab, COULEURS[None]), outline=COUL_TRAIT)
        d.text((bx + 56, y), "%s  (%d)" % (lab, compte[lab]),
               fill=(40, 34, 26), font=grande)
        y += LH
    y += 10
    d.text((bx + 18, y), "RUES", fill=(90, 82, 68), font=grande)
    y += LH
    for h in sorted(hier_presentes, key=lambda k: -EPAISSEUR.get(k, 3)):
        lg = [w for w in hier_presentes[h] if w]
        d.line([(bx + 18, y + 12), (bx + 44, y + 12)],
               fill=COUL_HIER.get(h, COUL_RUE), width=EPAISSEUR.get(h, 3))
        t = "%s  (%d)" % (h, len(hier_presentes[h]))
        if lg:
            t += "   %g–%g m" % (min(lg), max(lg)) if min(lg) != max(lg) \
                else "   %g m" % lg[0]
        d.text((bx + 56, y), t, fill=(40, 34, 26), font=grande)
        y += LH

    # échelle, sous la légende
    y += 14
    d.line([(bx + 18, y + 12), (bx + 18 + 100 * S, y + 12)],
           fill=(40, 34, 26), width=4)
    d.line([(bx + 18, y + 6), (bx + 18, y + 18)], fill=(40, 34, 26), width=3)
    d.line([(bx + 18 + 100 * S, y + 6), (bx + 18 + 100 * S, y + 18)],
           fill=(40, 34, 26), width=3)
    d.text((bx + 28 + 100 * S, y), "100 m", fill=(40, 34, 26), font=grande)

    im.save(SORTIE)
    return im.size


# -------------------------------------------------------------------- main

def main():
    ilots, rues, nom_rues, champ_fonction, champ_hier, adj, calque_rue = charger()

    fonctions = {}
    if not champ_fonction and os.path.exists(CLASSIF):
        brut = json.load(open(CLASSIF, encoding="utf-8"))
        for nom, liste in brut.items():
            for fid in liste:
                fonctions[fid] = nom

    morts = brins_morts(rues)
    titre = os.path.splitext(os.path.basename(GPKG))[0]
    if CALQUE:
        titre = CALQUE
    taille = rendre(ilots, rues, morts, fonctions, titre, adj, calque_rue)

    aires = sorted(i["aire"] for i in ilots)
    n_qual = sum(1 for i in ilots if (i["fonction"] or fonctions.get(i["fid"])))
    n_hier = sum(1 for r in rues if r["hier"])

    print("ÎLOTS  %d   |  %.1f ha  |  médiane %.0f m²  |  max %.0f m²"
          % (len(ilots), sum(aires) / 1e4, aires[len(aires) // 2], aires[-1]))
    print("       qualifiés (fonction) : %d / %d   [source : %s]"
          % (n_qual, len(ilots), champ_fonction or "classification.json"))
    print("RUES   %d tronçons  |  %.2f km  |  médiane %.0f m"
          % (len(rues), sum(r["long"] for r in rues) / 1000,
             sorted(r["long"] for r in rues)[len(rues) // 2]))
    print("       hiérarchie renseignée : %d / %d   [couche : %s, champ : %s]"
          % (n_hier, len(rues), nom_rues, champ_hier or "aucun"))
    if morts:
        print("BRINS MORTS  %d  → tronçons %s"
              % (len(morts), sorted({m[0] for m in morts})))
    else:
        print("BRINS MORTS  aucun ✅")
    print("PNG    %dx%d  →  %s" % (taille[0], taille[1], SORTIE))


if __name__ == "__main__":
    main()
