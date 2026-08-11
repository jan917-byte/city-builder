#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
04b — L'emprise bâtie : les îlots reculent, la rue devient le négatif.

    python3 QGIS/scripts/04b_emprises_baties.py --blanc   # ne rien écrire
    python3 QGIS/scripts/04b_emprises_baties.py           # écrire la couche

Écrit une nouvelle couche `emprises` dans le GeoPackage : l'empreinte de chaque
îlot après retrait. S'ouvre dans QGIS par-dessus `ilots`.

POURQUOI CE SCRIPT EXISTE

Les 69 îlots pavent l'emprise : 927 684 m² d'îlots pour 929 992 m² de carte,
soit 99,75 %. Et les axes de rue tombent EXACTEMENT sur les bords d'îlots —
0,0000 m d'écart, mesuré. Autrement dit `largeur_m` est un attribut pur, sans
support géométrique : la rue est un nombre, pas un lieu.

Conséquence en 3D : extruder les empreintes brutes donne un bloc plein de 93 ha
où aucune rue n'est visible. La barre de 1974 serait collée à ses voisines, et
« trouver monstrueuses les rues à 20 et 22 m » deviendrait inobservable.

La sortie est de faire reculer chaque bord d'îlot de la demi-largeur de la rue
qui le longe. La rue devient le NÉGATIF — l'espace que les îlots cèdent. C'est
un alignement, au sens urbanistique exact.

Effet de bord décisif : ça dissout le problème des carrefours, que
`Génération procédurale.md:58` classe « le plus dur de tous » et met hors phase.
Il n'y a plus de rubans à raccorder, il y a un vide qui se referme tout seul.

⚠ LA CHAÎNE DEVIENT 02 → 03 → 04 → 04b.
   `02_qualifier.py` fait un `shutil.copy2` qui écrase le GeoPackage entier :
   relancer 02 détruit cette couche. Ce script est idempotent, on le relance.

Se lance sans QGIS : sqlite3 seul, et le lecteur WKB d'apercu_carte.
"""

import math
import os
import sqlite3
import struct
import sys

ICI = os.path.dirname(os.path.abspath(__file__))
RACINE = os.path.dirname(os.path.dirname(ICI))
sys.path.insert(0, ICI)

from apercu_carte import gpkg_vers_wkb, lire_wkb  # noqa: E402  (même lecteur WKB)

BLANC = "--blanc" in sys.argv          # dry-run : calcule et affiche, n'écrit pas

# `python3 04b_emprises_baties.py une_copie.gpkg` pour travailler sur une copie
_ARGS = [a for a in sys.argv[1:] if not a.startswith("--")]
GPKG = _ARGS[0] if _ARGS else os.path.join(RACINE, "QGIS", "data",
                                           "Prototype_qualifie.gpkg")
SRS = 25832                            # EPSG:25832 — décision 31

# --- les tolérances -------------------------------------------------------
# Une arête d'îlot « porte » une route si le milieu de l'arête est sur un
# segment de route. Mesuré : l'écart est de 0,0000 m, donc 30 cm est déjà
# dix fois trop généreux — c'est voulu, on veut rater bruyamment, pas de peu.
TOL_ROUTE = 0.30
COS_MIN = 0.85                         # et il faut que ce soit parallèle
GRILLE = 25.0                          # index spatial, en cellules de 25 m
CLE = 0.25                             # grille de clé des sommets (comme 03)

# Au-delà, on considère que l'anneau est détruit et on le signale.
PERTE_ALERTE = 0.35                    # part de surface perdue qui mérite l'œil

# Un sommet reculé ne doit pas s'éloigner du sommet d'origine de plus de
# LIMITE_MITRE fois le retrait appliqué. Au-delà, biseau. (SVG utilise 4 par
# défaut pour le même problème ; 3 est un peu plus sévère, et ici on préfère
# un coin coupé à un pic.)
LIMITE_MITRE = 3.0


# ------------------------------------------------------------------ géométrie

def aire_signee(anneau):
    """Aire signée d'un anneau OUVERT (le dernier point ne répète pas le
    premier). Positive = sens trigonométrique.

    `apercu_carte.aire` renvoie une valeur ABSOLUE sur un anneau FERMÉ : elle
    ne peut pas servir ici, où le signe EST l'information (il donne le côté
    intérieur, donc le sens du retrait)."""
    s = 0.0
    n = len(anneau)
    for i in range(n):
        x1, y1 = anneau[i]
        x2, y2 = anneau[(i + 1) % n]
        s += x1 * y2 - x2 * y1
    return s / 2.0


def cle_arete(a, b):
    """Clé d'une arête, indépendante du sens de parcours. Deux îlots voisins
    partagent leurs sommets à l'identique (polygonisation d'une même couche
    ligne) : la clé les rapproche."""
    ka = (round(a[0] / CLE), round(a[1] / CLE))
    kb = (round(b[0] / CLE), round(b[1] / CLE))
    return (ka, kb) if ka <= kb else (kb, ka)


def dist_pt_seg(p, a, b):
    px, py = p
    ax, ay = a
    bx, by = b
    dx, dy = bx - ax, by - ay
    L2 = dx * dx + dy * dy
    if L2 == 0.0:
        return math.hypot(px - ax, py - ay)
    t = max(0.0, min(1.0, ((px - ax) * dx + (py - ay) * dy) / L2))
    return math.hypot(px - (ax + t * dx), py - (ay + t * dy))


def croisement(p1, p2, p3, p4):
    """Intersection PROPRE de deux segments (strictement à l'intérieur des
    deux), ou None. L'exclusion des extrémités évite de signaler le sommet
    que deux arêtes consécutives partagent légitimement."""
    d1x, d1y = p2[0] - p1[0], p2[1] - p1[1]
    d2x, d2y = p4[0] - p3[0], p4[1] - p3[1]
    den = d1x * d2y - d1y * d2x
    if abs(den) < 1e-12:
        return None
    ex, ey = p3[0] - p1[0], p3[1] - p1[1]
    t = (ex * d2y - ey * d2x) / den
    u = (ex * d1y - ey * d1x) / den
    e = 1e-9
    if e < t < 1.0 - e and e < u < 1.0 - e:
        return (p1[0] + t * d1x, p1[1] + t * d1y)
    return None


def reparer(anneau, cap=60):
    """Rend un anneau simple en retirant ses boucles.

    Un offset à distance VARIABLE s'auto-intersecte dès que l'îlot est concave
    et que deux rues voisines n'ont pas la même largeur. Les deux remèdes
    classiques ont été mesurés et écartés :

      · la limite de mitre FABRIQUE des croisements au lieu d'en retirer
      · le back-off uniforme détruit le retrait de 22 m du quai, c'est-à-dire
        exactement l'image que la maquette doit produire

    Ce qui marche : couper au premier croisement et garder le plus gros
    morceau. Déterministe, et ça préserve les grands retraits.
    """
    pts = list(anneau)
    n_rep = 0
    for _ in range(cap):
        n = len(pts)
        if n < 4:
            return pts, n_rep, True
        trouve = None
        for i in range(n):
            a1, a2 = pts[i], pts[(i + 1) % n]
            for j in range(i + 2, n):
                if i == 0 and j == n - 1:
                    continue                     # adjacentes par le bouclage
                X = croisement(a1, a2, pts[j], pts[(j + 1) % n])
                if X:
                    trouve = (i, j, X)
                    break
            if trouve:
                break
        if trouve is None:
            return pts, n_rep, False
        i, j, X = trouve
        a = pts[:i + 1] + [X] + pts[j + 1:]
        b = [X] + pts[i + 1:j + 1]
        pts = a if abs(aire_signee(a)) >= abs(aire_signee(b)) else b
        n_rep += 1
    return pts, n_rep, True                      # plafond atteint : à signaler


def retracter(anneau, retraits):
    """Décale chaque arête vers l'intérieur de son propre retrait, puis
    reconstruit les sommets par intersection des droites décalées.

    `retraits[i]` s'applique à l'arête (anneau[i] → anneau[i+1])."""
    n = len(anneau)
    sens = 1.0 if aire_signee(anneau) > 0 else -1.0
    lignes = []
    for i in range(n):
        a = anneau[i]
        b = anneau[(i + 1) % n]
        dx, dy = b[0] - a[0], b[1] - a[1]
        L = math.hypot(dx, dy)
        if L < 1e-9:                             # arête dégénérée
            lignes.append(None)
            continue
        ux, uy = dx / L, dy / L
        # Normale intérieure : à gauche si l'anneau est trigonométrique,
        # à droite s'il est horaire. Les 69 anneaux sources sont horaires,
        # mais on ne le suppose pas — on le lit dans le signe de l'aire.
        nx, ny = -uy * sens, ux * sens
        d = retraits[i]
        lignes.append(((a[0] + nx * d, a[1] + ny * d), (ux, uy), (nx, ny), d))

    sortie = []
    for i in range(n):
        prec = lignes[(i - 1) % n]
        cour = lignes[i]
        if prec is None or cour is None:
            continue
        (px, py), (pux, puy), (pnx, pny), pd = prec
        (cx, cy), (cux, cuy), (cnx, cny), cd = cour
        vx, vy = anneau[i]                       # le sommet d'origine
        den = pux * cuy - puy * cux
        if abs(den) < 1e-9:                      # arêtes parallèles
            sortie.append((cx, cy))
            continue
        t = ((cx - px) * cuy - (cy - py) * cux) / den
        mx, my = px + pux * t, py + puy * t

        # LIMITE DE MITRE. À un sommet réflexe, les deux droites décalées
        # divergent et leur intersection part à l'infini : mesuré, un sommet
        # de l'îlot 43 filait à 258 m — un bâtiment qui traverse la carte.
        # Au-delà de la limite, on remplace le pic par un biseau : le sommet
        # décalé perpendiculairement à chacune des deux arêtes. Les rares
        # croisements que le biseau introduit sont nettoyés par `reparer`.
        dmax = max(pd, cd)
        if dmax > 1e-9 and math.hypot(mx - vx, my - vy) > LIMITE_MITRE * dmax:
            sortie.append((vx + pnx * pd, vy + pny * pd))
            sortie.append((vx + cnx * cd, vy + cny * cd))
        else:
            sortie.append((mx, my))

    # Dédoublonnage : deux sommets à moins de 5 cm sont le même.
    net = []
    for p in sortie:
        if not net or math.hypot(p[0] - net[-1][0], p[1] - net[-1][1]) > 0.05:
            net.append(p)
    while len(net) > 1 and math.hypot(net[0][0] - net[-1][0],
                                      net[0][1] - net[-1][1]) <= 0.05:
        net.pop()
    return net


# ----------------------------------------------------------------- encodage

def wkb_polygone(anneaux):
    """WKB little-endian d'un Polygon. Symétrie exacte de `lire_wkb`."""
    out = [struct.pack("<BII", 1, 3, len(anneaux))]
    for a in anneaux:
        pts = list(a)
        if pts[0] != pts[-1]:
            pts.append(pts[0])               # le WKB veut un anneau fermé
        out.append(struct.pack("<I", len(pts)))
        for x, y in pts:
            out.append(struct.pack("<dd", x, y))
    return b"".join(out)


def blob_gpkg(wkb):
    """En-tête GeoPackage + WKB. Symétrie exacte de `gpkg_vers_wkb` :
    magic 'GP', version 0, drapeaux 0x01 (little-endian, aucune enveloppe →
    indicateur 0 → le WKB commence à l'octet 8), puis le srs_id."""
    return struct.pack("<2sBBi", b"GP", 0, 0x01, SRS) + wkb


# --------------------------------------------------------------------- lire

def lire(con):
    ilots = {}
    for fid, st, surf, geom in con.execute(
        "SELECT fid, sous_type, surface_m2, geom FROM ilots ORDER BY fid"
    ):
        anneaux, _ = lire_wkb(gpkg_vers_wkb(geom))
        ext = list(anneaux[0])
        while len(ext) > 1 and ext[0] == ext[-1]:
            ext.pop()                        # on travaille en anneau OUVERT
        ilots[fid] = {"st": st, "surf": surf, "ext": ext}

    segs = []
    for fid, h, larg, geom in con.execute(
        "SELECT fid, hierarchie, largeur_m, geom FROM routes ORDER BY fid"
    ):
        for part in lire_wkb(gpkg_vers_wkb(geom))[0]:
            for a, b in zip(part, part[1:]):
                if math.hypot(b[0] - a[0], b[1] - a[1]) < 1e-9:
                    continue                 # 2 tronçons `rive` ont un segment nul
                segs.append((a, b, larg or 0.0, h))
    return ilots, segs


def indexer(segs):
    idx = {}
    for k, (a, b, larg, h) in enumerate(segs):
        x0 = int(min(a[0], b[0]) // GRILLE)
        x1 = int(max(a[0], b[0]) // GRILLE)
        y0 = int(min(a[1], b[1]) // GRILLE)
        y1 = int(max(a[1], b[1]) // GRILLE)
        for cx in range(x0, x1 + 1):
            for cy in range(y0, y1 + 1):
                idx.setdefault((cx, cy), []).append(k)
    return idx


def largeur_sur(arete, segs, idx):
    """La largeur de la route qui longe cette arête, ou 0."""
    a, b = arete
    mx, my = (a[0] + b[0]) / 2.0, (a[1] + b[1]) / 2.0
    dx, dy = b[0] - a[0], b[1] - a[1]
    L = math.hypot(dx, dy)
    if L < 1e-9:
        return 0.0
    ux, uy = dx / L, dy / L
    cx, cy = int(mx // GRILLE), int(my // GRILLE)
    best, best_d = 0.0, TOL_ROUTE
    for ix in (cx - 1, cx, cx + 1):
        for iy in (cy - 1, cy, cy + 1):
            for k in idx.get((ix, iy), ()):
                sa, sb, larg, _ = segs[k]
                sdx, sdy = sb[0] - sa[0], sb[1] - sa[1]
                sl = math.hypot(sdx, sdy)
                if sl < 1e-9:
                    continue
                if abs((sdx / sl) * ux + (sdy / sl) * uy) < COS_MIN:
                    continue                 # perpendiculaire : ce n'est pas elle
                d = dist_pt_seg((mx, my), sa, sb)
                if d < best_d:
                    best, best_d = larg, d
    return best


# --------------------------------------------------------------------- main

def main():
    if not os.path.exists(GPKG):
        sys.exit("Introuvable : %s — lancer 02 → 03 → 04 d'abord." % GPKG)
    con = sqlite3.connect("file:%s?mode=ro" % GPKG.replace("\\", "/"), uri=True)
    ilots, segs = lire(con)
    con.close()
    idx = indexer(segs)

    print("EMPRISES BÂTIES%s" % ("   [--blanc : rien n'est écrit]" if BLANC else ""))
    print("  %d îlots, %d segments de voirie" % (len(ilots), len(segs)))

    # Qui est de l'autre côté de chaque arête ? Les îlots voisins partagent
    # leurs sommets, donc la clé d'arête suffit — pas besoin d'un test spatial.
    proprio = {}
    for fid, d in ilots.items():
        e = d["ext"]
        for i in range(len(e)):
            proprio.setdefault(cle_arete(e[i], e[(i + 1) % len(e)]), []).append(fid)
    partagees = sum(1 for v in proprio.values() if len(v) == 2)
    print("  %d arêtes distinctes, dont %d partagées par exactement 2 îlots"
          % (len(proprio), partagees))

    # ------------------------------------------------------------ le retrait
    n_avec_route = 0
    resultats = []
    for fid, d in ilots.items():
        e = d["ext"]
        n = len(e)
        retraits = []
        for i in range(n):
            a, b = e[i], e[(i + 1) % n]
            larg = largeur_sur((a, b), segs, idx)
            if larg > 0.0:
                n_avec_route += 1
            if d["st"] == "riviere":
                r = 0.0                       # l'eau ne recule jamais
            elif larg <= 0.0:
                r = 0.0
            else:
                voisins = [f for f in proprio[cle_arete(a, b)] if f != fid]
                bord_eau = any(ilots[f]["st"] == "riviere" for f in voisins)
                # Le quai est entièrement sur la terre : sans cette règle, la
                # voie rapide de berge à 22 m mangerait 11 m d'Ilse.
                r = larg if bord_eau else larg / 2.0
            retraits.append(r)

        if d["st"] == "riviere":
            anneau, n_rep, cap = list(e), 0, False
        else:
            anneau = retracter(e, retraits)
            anneau, n_rep, cap = reparer(anneau)

        surf = abs(aire_signee(anneau)) if len(anneau) >= 3 else 0.0
        resultats.append({
            "fid": fid, "st": d["st"], "anneau": anneau,
            "surf0": d["surf"] or 0.0, "surf": surf,
            "rmax": max(retraits) if retraits else 0.0,
            "rep": n_rep, "cap": cap,
        })

    print("  %d arêtes portent une route" % n_avec_route)

    # ------------------------------------------------------------- contrôles
    casses = [r for r in resultats if r["cap"] or len(r["anneau"]) < 3]
    repares = [r for r in resultats if r["rep"] > 0]
    s0 = sum(r["surf0"] for r in resultats)
    s1 = sum(r["surf"] for r in resultats)

    print("\n  anneaux simples          : %d / %d" % (len(resultats) - len(casses),
                                                      len(resultats)))
    print("  aire bâtie               : %.1f ha  (avant : %.1f ha)"
          % (s1 / 1e4, s0 / 1e4))
    print("  voirie dégagée           : %.1f ha  = %.1f %% de la carte"
          % ((s0 - s1) / 1e4, 100.0 * (s0 - s1) / s0))

    if repares:
        print("\n  réparations de boucle (%d îlots)" % len(repares))
        print("    %-5s %-20s %9s %9s %8s %s" % ("fid", "sous_type", "avant",
                                                 "après", "perte", "coupes"))
        for r in sorted(repares, key=lambda r: r["surf"] - r["surf0"]):
            perte = r["surf0"] - r["surf"]
            marque = "  ← à regarder" if perte > PERTE_ALERTE * r["surf0"] else ""
            print("    %-5d %-20s %9.0f %9.0f %8.0f %6d%s"
                  % (r["fid"], r["st"], r["surf0"], r["surf"], perte,
                     r["rep"], marque))

    if casses:
        print("\n  ⚠ %d anneau(x) non réparés : %s"
              % (len(casses), ", ".join(str(r["fid"]) for r in casses)))

    gros = [r for r in resultats
            if r["st"] != "riviere" and r["surf0"] > 0
            and (r["surf0"] - r["surf"]) > PERTE_ALERTE * r["surf0"]]
    if gros:
        print("\n  îlots ayant perdu plus de %d %% de leur surface"
              % int(PERTE_ALERTE * 100))
        for r in sorted(gros, key=lambda r: -(r["surf0"] - r["surf"])):
            print("    %-5d %-20s %8.0f → %8.0f m²   retrait max %5.1f m"
                  % (r["fid"], r["st"], r["surf0"], r["surf"], r["rmax"]))

    if BLANC:
        print("\nrien écrit (--blanc)")
        return

    ecrire(resultats)
    print("\n→ couche `emprises` écrite dans %s" % os.path.basename(GPKG))


def ecrire(resultats):
    con = sqlite3.connect(GPKG)
    cur = con.cursor()
    # Idempotent : on efface la couche et ses métadonnées avant de recréer.
    cur.execute("DROP TABLE IF EXISTS emprises")
    for t in ("gpkg_contents", "gpkg_geometry_columns", "gpkg_ogr_contents"):
        cur.execute("DELETE FROM %s WHERE table_name = 'emprises'" % t)
    cur.execute("""
        CREATE TABLE "emprises" (
            "fid" INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
            "geom" POLYGON,
            fid_ilot INTEGER,
            sous_type TEXT,
            retrait_max_m REAL,
            surface_batie_m2 REAL,
            perte_m2 REAL,
            repare INTEGER)""")

    xs, ys, n = [], [], 0
    for r in resultats:
        if len(r["anneau"]) < 3:
            continue
        for p in r["anneau"]:
            xs.append(p[0])
            ys.append(p[1])
        cur.execute(
            "INSERT INTO emprises (geom, fid_ilot, sous_type, retrait_max_m,"
            " surface_batie_m2, perte_m2, repare) VALUES (?,?,?,?,?,?,?)",
            (blob_gpkg(wkb_polygone([r["anneau"]])), r["fid"], r["st"],
             round(r["rmax"], 2), round(r["surf"], 1),
             round(r["surf0"] - r["surf"], 1), r["rep"]))
        n += 1

    cur.execute(
        "INSERT INTO gpkg_contents (table_name, data_type, identifier,"
        " description, last_change, min_x, min_y, max_x, max_y, srs_id)"
        " VALUES ('emprises','features','emprises',?,"
        " strftime('%Y-%m-%dT%H:%M:%fZ','now'),?,?,?,?,?)",
        ("Emprise batie apres retrait de la demi-largeur de voirie (04b)",
         min(xs), min(ys), max(xs), max(ys), SRS))
    cur.execute(
        "INSERT INTO gpkg_geometry_columns (table_name, column_name,"
        " geometry_type_name, srs_id, z, m)"
        " VALUES ('emprises','geom','POLYGON',?,0,0)", (SRS,))
    # GDAL tient un cache du nombre d'entités ; sans cette ligne QGIS peut
    # afficher une couche vide.
    cur.execute("INSERT INTO gpkg_ogr_contents (table_name, feature_count)"
                " VALUES ('emprises',?)", (n,))
    con.commit()
    con.close()


if __name__ == "__main__":
    for flux in (sys.stdout, sys.stderr):
        try:
            flux.reconfigure(encoding="utf-8", errors="replace")
        except (AttributeError, OSError):
            pass
    main()
