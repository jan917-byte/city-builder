# -*- coding: utf-8 -*-
"""
Mise à l'échelle du dessin source — `Vallmar2.gpkg`.

Le dessin de Wehrau a été fait sans échelle : la géométrie a reçu ses mètres
après coup, au calage. Ce script change ce facteur de calage, et lui seul.

    python 00b_mettre_a_echelle.py 1.2 --blanc     ← calcule, n'écrit rien
    python 00b_mettre_a_echelle.py 1.2             ← écrit dans Vallmar2.gpkg

Ce qui grandit : la géométrie, donc les îlots, les distances entre rues, les
longueurs de tronçons. Chaque sommet s'éloigne du centre de la carte du
facteur demandé. Une carte multipliée par 1,2 occupe 1,44 fois plus de sol.

Ce qui NE grandit PAS : la largeur des rues. `largeur_m` est un attribut posé
par `02_qualifier.py` à partir de la hiérarchie (boulevard 18 m, rue 13 m,
ruelle 5 m, quai 22 m) — il ne sort pas de la géométrie, donc il ne bouge pas.
Même chose pour les cibles de parcellaire de `04c` (façade et profondeur en
mètres) et pour le retrait de `04b` (la demi-largeur de la rue). Résultat
voulu : les îlots grandissent, les rues et les parcelles gardent leur taille.

⚠ Le script est CUMULATIF : le relancer avec 1.2 sur une carte déjà agrandie
donne 1.44. Il imprime l'étendue avant et après — c'est là qu'on le voit.

⚠ Il écrit dans la SOURCE. Toute la chaîne est à relancer derrière :
    02 → 03 → 04 → 04b → 04c, puis 07.
"""

import math
import os
import sqlite3
import struct
import sys

for flux in (sys.stdout, sys.stderr):
    try:
        flux.reconfigure(encoding="utf-8", errors="replace")
    except (AttributeError, OSError):
        pass

ICI = os.path.dirname(os.path.abspath(__file__))
DATA = os.path.join(os.path.dirname(ICI), "data")

BLANC = "--blanc" in sys.argv
_ARGS = [a for a in sys.argv[1:] if not a.startswith("--")]
if not _ARGS:
    raise SystemExit("Usage : python 00b_mettre_a_echelle.py <facteur> [chemin.gpkg] [--blanc]")
FACTEUR = float(_ARGS[0])
GPKG = _ARGS[1] if len(_ARGS) > 1 else os.path.join(DATA, "Vallmar2.gpkg")

TAILLE_ENVELOPPE = {0: 0, 1: 32, 2: 48, 3: 48, 4: 64}


# ==========================================================================
# Lire les coordonnées d'un blob GeoPackage sans les recopier
# ==========================================================================
# On ne reconstruit pas la géométrie : chaque couple (x, y) est réécrit sur
# place. Ni le type, ni l'ordre des anneaux, ni l'en-tête ne bougent.

def entete(blob):
    """(taille de l'en-tête, ordre des octets de l'enveloppe, taille env.)"""
    if blob[:2] != b"GP":
        raise ValueError("blob sans magie GP")
    drapeaux = blob[3]
    env = (drapeaux >> 1) & 0x07
    if env not in TAILLE_ENVELOPPE:
        raise ValueError("code d'enveloppe inconnu : %d" % env)
    ordre = "<" if (drapeaux & 0x01) else ">"
    return 8 + TAILLE_ENVELOPPE[env], ordre, TAILLE_ENVELOPPE[env]


def positions(buf, off, sorties):
    """Empile (position, ordre) pour chaque point, et rend la position d'après."""
    ordre = "<" if buf[off] == 1 else ">"
    off += 1
    brut = struct.unpack_from(ordre + "I", buf, off)[0]
    off += 4
    type_ = brut % 1000
    dims = brut // 1000            # 0 XY · 1 XYZ · 2 XYM · 3 XYZM
    par_point = 16 + (8 if dims in (1, 2) else 16 if dims == 3 else 0)

    if type_ == 1:                                    # point
        sorties.append((off, ordre))
        return off + par_point
    if type_ == 2:                                    # ligne
        n = struct.unpack_from(ordre + "I", buf, off)[0]
        off += 4
        for _ in range(n):
            sorties.append((off, ordre))
            off += par_point
        return off
    if type_ == 3:                                    # polygone
        na = struct.unpack_from(ordre + "I", buf, off)[0]
        off += 4
        for _ in range(na):
            n = struct.unpack_from(ordre + "I", buf, off)[0]
            off += 4
            for _ in range(n):
                sorties.append((off, ordre))
                off += par_point
        return off
    if type_ in (4, 5, 6, 7):                         # multi· et collection
        n = struct.unpack_from(ordre + "I", buf, off)[0]
        off += 4
        for _ in range(n):
            off = positions(buf, off, sorties)
        return off
    raise ValueError("type de géométrie non géré : %d" % type_)


def points_de(blob):
    debut, _, _ = entete(blob)
    sorties = []
    positions(blob, debut, sorties)
    return sorties


# ==========================================================================
# Le travail
# ==========================================================================

def couches(con):
    return [r[0] for r in con.execute(
        "SELECT table_name FROM gpkg_geometry_columns ORDER BY table_name")]


def etendue(con, tables):
    minx = miny = float("inf")
    maxx = maxy = float("-inf")
    for t in tables:
        for (blob,) in con.execute('SELECT geom FROM "%s"' % t):
            if blob is None:
                continue
            for pos, ordre in points_de(blob):
                x, y = struct.unpack_from(ordre + "dd", blob, pos)
                minx = min(minx, x); maxx = max(maxx, x)
                miny = min(miny, y); maxy = max(maxy, y)
    return minx, miny, maxx, maxy


def aire_polygone(blob):
    """Aire du premier anneau — sert au contrôle, pas au calcul."""
    debut, _, _ = entete(blob)
    sorties = []
    positions(blob, debut, sorties)
    pts = [struct.unpack_from(o + "dd", blob, p) for p, o in sorties]
    s = 0.0
    for i in range(len(pts) - 1):
        s += pts[i][0] * pts[i + 1][1] - pts[i + 1][0] * pts[i][1]
    return abs(s) / 2.0


def transformer(blob, cx, cy, k):
    """Renvoie un blob neuf, sommets mis à l'échelle et enveloppe refaite."""
    buf = bytearray(blob)
    debut, ordre_env, taille_env = entete(buf)
    minx = miny = float("inf")
    maxx = maxy = float("-inf")
    sorties = []
    positions(buf, debut, sorties)
    for pos, ordre in sorties:
        x, y = struct.unpack_from(ordre + "dd", buf, pos)
        x = cx + (x - cx) * k
        y = cy + (y - cy) * k
        struct.pack_into(ordre + "dd", buf, pos, x, y)
        minx = min(minx, x); maxx = max(maxx, x)
        miny = min(miny, y); maxy = max(maxy, y)
    if taille_env >= 32:
        struct.pack_into(ordre_env + "dddd", buf, 8, minx, maxx, miny, maxy)
    return bytes(buf), (minx, miny, maxx, maxy)


def tableau(titre, entetes, lignes):
    print()
    print(titre)
    larg = [max([len(str(entetes[i]))] + [len(str(l[i])) for l in lignes])
            for i in range(len(entetes))]
    print("  " + " | ".join(str(e).ljust(larg[i]) for i, e in enumerate(entetes)))
    print("  " + "-+-".join("-" * w for w in larg))
    for l in lignes:
        print("  " + " | ".join(str(v).ljust(larg[i]) for i, v in enumerate(l)))


def main():
    if not os.path.exists(GPKG):
        raise SystemExit("introuvable : %s" % GPKG)
    if FACTEUR <= 0:
        raise SystemExit("le facteur doit être positif")

    con = sqlite3.connect(GPKG)
    tables = couches(con)
    print("Carte  : %s" % os.path.basename(GPKG))
    print("Couches: %s" % ", ".join(tables))
    print("Facteur: x%.4f  (les surfaces sont multipliées par %.4f)"
          % (FACTEUR, FACTEUR ** 2))
    if BLANC:
        print("Mode   : PASSE À BLANC — rien ne sera écrit")

    minx, miny, maxx, maxy = etendue(con, tables)
    cx, cy = (minx + maxx) / 2.0, (miny + maxy) / 2.0
    print("Centre : %.2f, %.2f  (le point qui ne bouge pas)" % (cx, cy))

    # --- contrôle avant : quelques îlots témoins
    temoins = []
    if "ilots" in tables:
        for fid, blob in con.execute("SELECT fid, geom FROM ilots ORDER BY fid LIMIT 5"):
            temoins.append([fid, "%.0f" % aire_polygone(blob)])

    # --- la transformation
    neuf = {}
    total_pts = 0
    gminx = gminy = float("inf")
    gmaxx = gmaxy = float("-inf")
    for t in tables:
        neuf[t] = []
        for fid, blob in con.execute('SELECT fid, geom FROM "%s"' % t):
            if blob is None:
                continue
            b2, boite = transformer(blob, cx, cy, FACTEUR)
            total_pts += len(points_de(blob))
            gminx = min(gminx, boite[0]); gminy = min(gminy, boite[1])
            gmaxx = max(gmaxx, boite[2]); gmaxy = max(gmaxy, boite[3])
            neuf[t].append((fid, b2, boite))

    tableau("Étendue de la carte", ["mesure", "avant", "après", "écart"], [
        ["largeur est-ouest", "%.0f m" % (maxx - minx), "%.0f m" % (gmaxx - gminx),
         "x%.3f" % ((gmaxx - gminx) / (maxx - minx))],
        ["hauteur nord-sud", "%.0f m" % (maxy - miny), "%.0f m" % (gmaxy - gminy),
         "x%.3f" % ((gmaxy - gminy) / (maxy - miny))],
        ["boîte englobante", "%.3f km²" % ((maxx - minx) * (maxy - miny) / 1e6),
         "%.3f km²" % ((gmaxx - gminx) * (gmaxy - gminy) / 1e6),
         "x%.3f" % (FACTEUR ** 2)],
    ])

    if temoins:
        lignes = []
        apres = {fid: b for fid, b, _ in neuf["ilots"]}
        for fid, avant in temoins:
            a2 = aire_polygone(apres[fid])
            lignes.append([fid, avant, "%.0f" % a2, "x%.4f" % (a2 / float(avant))])
        tableau("Contrôle sur cinq îlots (aire en m²)",
                ["fid", "avant", "après", "rapport — doit valoir x%.4f" % (FACTEUR ** 2)],
                lignes)

    print()
    print("Sommets déplacés : %d, sur %d objets."
          % (total_pts, sum(len(v) for v in neuf.values())))
    print("Largeur des rues : inchangée — `largeur_m` est écrit par 02 à partir")
    print("                   de la hiérarchie, pas mesuré sur la géométrie.")

    if BLANC:
        print()
        print("Passe à blanc terminée. Rien n'a été écrit.")
        return

    cur = con.cursor()
    cur.execute("BEGIN")   # tout ou rien, y compris le retrait des déclencheurs

    # ⚠️ Les déclencheurs d'index spatial de QGIS appellent ST_IsEmpty(), que
    # le sqlite3 de Python ne connaît pas : toute écriture sur `geom` échoue.
    # Retirés le temps de l'opération, puis remis mot pour mot — leur texte est
    # relu dans le fichier, pas réécrit ici.
    declencheurs = [
        (n, s) for n, s in cur.execute(
            "SELECT name, sql FROM sqlite_master WHERE type='trigger' "
            "AND name LIKE 'rtree_%'").fetchall() if s]
    for nom, _ in declencheurs:
        cur.execute('DROP TRIGGER "%s"' % nom)

    for t in tables:
        for fid, blob, _ in neuf[t]:
            cur.execute('UPDATE "%s" SET geom = ? WHERE fid = ?' % t, (blob, fid))
        cur.execute(
            "UPDATE gpkg_contents SET min_x=?, min_y=?, max_x=?, max_y=? "
            "WHERE table_name=?", (gminx, gminy, gmaxx, gmaxy, t))
        # Boîtes calculées sur les SOMMETS, pas relues dans l'en-tête : cinq
        # objets n'ont pas d'enveloppe (code 0) et donneraient du bruit.
        rtree = "rtree_%s_geom" % t
        existe = cur.execute(
            "SELECT count(*) FROM sqlite_master WHERE name=?", (rtree,)).fetchone()[0]
        if existe:
            cur.execute('DELETE FROM "%s"' % rtree)
            for fid, _, (a, b, c, d) in neuf[t]:
                cur.execute('INSERT INTO "%s" VALUES (?,?,?,?,?)' % rtree,
                            (fid, a, c, b, d))   # id, minx, maxx, miny, maxy

    for _, sql in declencheurs:
        cur.execute(sql)
    con.commit()

    # contrôle : l'index spatial doit contenir autant de lignes que la couche
    for t in tables:
        rtree = "rtree_%s_geom" % t
        n_t = con.execute('SELECT count(*) FROM "%s"' % t).fetchone()[0]
        n_r = con.execute('SELECT count(*) FROM "%s"' % rtree).fetchone()[0]
        etat = "ok" if n_t == n_r else "⚠ ÉCART"
        print("  index spatial %-22s %d objets / %d lignes   %s" % (t, n_t, n_r, etat))
    print("  déclencheurs remis : %d" % len(declencheurs))

    print()
    print("Écrit dans %s." % os.path.basename(GPKG))
    print("À relancer, dans l'ordre : 02 → 03 → 04 → 04b → 04c, puis 07.")


if __name__ == "__main__":
    main()
