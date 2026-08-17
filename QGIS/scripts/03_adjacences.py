# -*- coding: utf-8 -*-
"""
Construit la table `adjacences` : quel type de rue sépare quels îlots.

C'est l'étape qui rend la carte non décorative. Deux îlots collés séparés
par une voie rapide ne sont pas voisins. → vault, [[Géométrie et données]]

Travaille sur la carte de travail `QGIS/data/travail/wehrau.gpkg` (celle que
bâtit 02_qualifier.py). Ne touche pas à la source. Les géométries ne sont
jamais modifiées.

    python 03_adjacences.py

Sortie : table `adjacences` dans le GeoPackage
    id_a · id_b · hierarchie_separatrice · longueur_m · permeabilite
plus une colonne `bord_carte_m` sur `ilots`.
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
GPKG = os.path.join(DATA, "travail", "wehrau.gpkg")

TOL = 0.5          # m — distance max entre une frontière et la rue qui la porte

# ==========================================================================
# LE DESIGN : ce qu'une rue laisse passer entre deux îlots
# ==========================================================================
# 0 = coupure totale, 1 = les deux îlots se comportent comme un seul.
# C'est ici qu'est encodée la coupure urbaine, et c'est du design, pas de
# la mesure : ces sept nombres décident du comportement de toute la carte.
PERMEABILITE = {
    "ruelle":      1.00,   # on traverse sans y penser
    "rue":         0.80,
    "boulevard":   0.40,   # on traverse, mais on y pense
    "voie ferree": 0.10,
    "rive":        0.10,   # la berge : on longe l'eau, on ne la franchit pas
    "autoroute":   0.05,   # la coupure franche
    "sans_rue":    0.90,   # frontière sans voirie : deux arrières qui se touchent
}

# La voie rapide de berge est un boulevard de 22 m. Une rue large coupe plus
# qu'une rue étroite : au-delà de ce seuil, la perméabilité est divisée.
LARGEUR_SEUIL = 20.0
PENALITE_LARGE = 0.5


# ==========================================================================

def gpkg_vers_wkb(blob):
    return blob[8 + {0: 0, 1: 32, 2: 48, 3: 48, 4: 64}[(blob[3] >> 1) & 0x07]:]


def _e(buf, off, o):
    return struct.unpack_from(o + "I", buf, off)[0], off + 4


def _p(buf, off, o, n):
    c = struct.unpack_from(o + "%dd" % (2 * n), buf, off)
    return [(c[i], c[i + 1]) for i in range(0, 2 * n, 2)], off + 16 * n


def lire_wkb(buf, off=0):
    o = "<" if buf[off] == 1 else ">"
    off += 1
    g, off = _e(buf, off, o)
    base = g % 1000
    if base == 2:
        n, off = _e(buf, off, o)
        pts, off = _p(buf, off, o, n)
        return [pts], off
    if base == 3:
        na, off = _e(buf, off, o)
        r = []
        for _ in range(na):
            n, off = _e(buf, off, o)
            pts, off = _p(buf, off, o, n)
            r.append(pts)
        return r, off
    if base in (5, 6):
        ng, off = _e(buf, off, o)
        t = []
        for _ in range(ng):
            p, off = lire_wkb(buf, off)
            t.extend(p)
        return t, off
    raise ValueError("WKB %d" % base)


def enveloppe(blob):
    ind = (blob[3] >> 1) & 0x07
    if ind in (1, 2, 3, 4):
        return struct.unpack_from(("<" if blob[3] & 1 else ">") + "4d", blob, 8)
    parts, _ = lire_wkb(gpkg_vers_wkb(blob))
    xs = [p[0] for pa in parts for p in pa]
    ys = [p[1] for pa in parts for p in pa]
    return (min(xs), max(xs), min(ys), max(ys))


def brancher_fonctions_spatiales(con):
    con.create_function("ST_IsEmpty", 1, lambda b: 0 if b else 1)
    for i, nom in enumerate(("ST_MinX", "ST_MaxX", "ST_MinY", "ST_MaxY")):
        con.create_function(
            nom, 1, (lambda k: lambda b: enveloppe(b)[k] if b else None)(i))


GRILLE = 0.25


def cle_seg(a, b):
    ka = (round(a[0] / GRILLE), round(a[1] / GRILLE))
    kb = (round(b[0] / GRILLE), round(b[1] / GRILLE))
    return (ka, kb) if ka <= kb else (kb, ka)


def dist_pt_seg(p, a, b):
    px, py = p
    ax, ay = a
    bx, by = b
    dx, dy = bx - ax, by - ay
    L2 = dx * dx + dy * dy
    if L2 == 0:
        return math.hypot(px - ax, py - ay)
    t = max(0.0, min(1.0, ((px - ax) * dx + (py - ay) * dy) / L2))
    return math.hypot(px - (ax + t * dx), py - (ay + t * dy))


def main():
    if not os.path.exists(GPKG):
        raise SystemExit("introuvable : %s\nLancer 02_qualifier.py d'abord." % GPKG)
    con = sqlite3.connect(GPKG)
    brancher_fonctions_spatiales(con)
    cur = con.cursor()

    ilots = {}
    for fid, blob, st in cur.execute("SELECT fid, geom, sous_type FROM ilots"):
        anneaux, _ = lire_wkb(gpkg_vers_wkb(blob))
        ilots[fid] = {"anneaux": anneaux, "sous_type": st}

    # segments de rue, indexés par cellule pour ne pas tout comparer à tout
    CELL = 25.0
    grille = {}
    for fid, blob, h, w in cur.execute(
            "SELECT fid, geom, hierarchie, largeur_m FROM routes"):
        parts, _ = lire_wkb(gpkg_vers_wkb(blob))
        for p in parts:
            for i in range(len(p) - 1):
                a, b = p[i], p[i + 1]
                seg = (a, b, (h or "").strip().lower(), w or 0.0)
                x0, x1 = sorted((a[0], b[0]))
                y0, y1 = sorted((a[1], b[1]))
                for cx in range(int(x0 // CELL), int(x1 // CELL) + 1):
                    for cy in range(int(y0 // CELL), int(y1 // CELL) + 1):
                        grille.setdefault((cx, cy), []).append(seg)

    def rue_sous(p):
        """La rue qui porte ce point de frontière, ou None."""
        cx, cy = int(p[0] // CELL), int(p[1] // CELL)
        best = (TOL, None)
        for dx in (-1, 0, 1):
            for dy in (-1, 0, 1):
                for a, b, h, w in grille.get((cx + dx, cy + dy), ()):
                    d = dist_pt_seg(p, a, b)
                    if d < best[0]:
                        best = (d, (h, w))
        return best[1]

    # --- qui possède quel segment de frontière
    possede = {}
    for fid, d in ilots.items():
        for anneau in d["anneaux"]:
            for i in range(len(anneau) - 1):
                a, b = anneau[i], anneau[i + 1]
                possede.setdefault(cle_seg(a, b), []).append((fid, a, b))

    paires = {}
    bord = {}
    for k, lst in possede.items():
        (f1, a, b) = lst[0]
        L = math.hypot(b[0] - a[0], b[1] - a[1])
        if len(lst) == 1:
            bord[f1] = bord.get(f1, 0.0) + L        # frontière sans voisin
            continue
        if len(lst) != 2:
            continue                                # cas dégénéré, ignoré
        f2 = lst[1][0]
        mil = ((a[0] + b[0]) / 2, (a[1] + b[1]) / 2)
        r = rue_sous(mil)
        h = r[0] if r else "sans_rue"
        w = r[1] if r else 0.0
        cle = (min(f1, f2), max(f1, f2))
        paires.setdefault(cle, []).append((h, w, L))

    # --- une ligne par paire
    lignes = []
    for (a, b), morceaux in sorted(paires.items()):
        total = sum(m[2] for m in morceaux)
        # perméabilité : moyenne pondérée par la longueur de chaque morceau
        perm = 0.0
        par_h = {}
        for h, w, L in morceaux:
            p = PERMEABILITE.get(h, PERMEABILITE["sans_rue"])
            if w and w >= LARGEUR_SEUIL:
                p *= PENALITE_LARGE
            perm += p * L
            par_h[h] = par_h.get(h, 0.0) + L
        perm /= total
        # hiérarchie affichée : celle qui tient le plus de linéaire
        dominante = max(par_h, key=lambda k: par_h[k])
        lignes.append((a, b, dominante, round(total, 1), round(perm, 3)))

    cur.execute("DROP TABLE IF EXISTS adjacences")
    cur.execute("""CREATE TABLE adjacences (
        id_a INTEGER NOT NULL, id_b INTEGER NOT NULL,
        hierarchie_separatrice TEXT, longueur_m REAL, permeabilite REAL,
        PRIMARY KEY (id_a, id_b))""")
    cur.executemany("INSERT INTO adjacences VALUES (?,?,?,?,?)", lignes)
    # déclarer la table au GeoPackage, sinon QGIS ne la voit pas
    cur.execute("INSERT OR REPLACE INTO gpkg_contents "
                "(table_name, data_type, identifier) VALUES "
                "('adjacences', 'attributes', 'adjacences')")

    try:
        cur.execute("ALTER TABLE ilots ADD COLUMN bord_carte_m REAL")
    except sqlite3.OperationalError:
        pass
    for fid in ilots:
        cur.execute("UPDATE ilots SET bord_carte_m=? WHERE fid=?",
                    (round(bord.get(fid, 0.0), 1), fid))
    con.commit()

    # ---------------- compte rendu
    print("=" * 64)
    print("ADJACENCES  %d paires  |  %.2f km de frontières partagées"
          % (len(lignes), sum(l[3] for l in lignes) / 1000))
    par_h = {}
    for _, _, h, L, p in lignes:
        e = par_h.setdefault(h, [0, 0.0, 0.0])
        e[0] += 1
        e[1] += L
        e[2] += p
    print("\n  séparateur     paires   linéaire   perméabilité moyenne")
    for h in sorted(par_h, key=lambda k: -par_h[k][0]):
        n, L, sp = par_h[h]
        print("  %-13s %5d   %7.0f m   %.2f" % (h, n, L, sp / n))

    print("\n  voisins par îlot : min %d · médiane %d · max %d"
          % tuple(_stats([sum(1 for l in lignes if fid in (l[0], l[1]))
                          for fid in ilots])))
    nb = sum(1 for f, v in bord.items() if v > 1)
    print("  îlots touchant le bord de carte : %d (%.0f m au total)"
          % (nb, sum(bord.values())))

    # ---------------- contrôle : est-ce que la rivière coupe vraiment ?
    riv = {f for f, d in ilots.items() if d["sous_type"] == "riviere"}
    champ = {f for f, d in ilots.items() if d["sous_type"] == "champ"}
    ville = set(ilots) - riv - champ
    comp = _composantes(ville, lignes)
    print("\n  CONTRÔLE — la ville privée de la rivière et des champs :")
    print("    %d morceau(x) : %s" % (len(comp), [len(c) for c in comp]))
    if len(comp) >= 2:
        print("    ✅ la rivière coupe. Les deux rives ne communiquent que")
        print("       par les ponts — la coupure est dans la géométrie.")
    else:
        print("    ⚠️ la ville reste d'un seul tenant : quelque part, deux")
        print("       îlots se touchent par-dessus l'eau. À vérifier.")

    print("\n→ table `adjacences` écrite dans %s" % os.path.basename(GPKG))
    print("=" * 64)
    con.close()


def _stats(v):
    v = sorted(v)
    return v[0], v[len(v) // 2], v[-1]


def _composantes(noeuds, lignes):
    """Composantes connexes du sous-graphe restreint à `noeuds`."""
    vois = {n: set() for n in noeuds}
    for a, b, _h, _L, _p in lignes:
        if a in vois and b in vois:
            vois[a].add(b)
            vois[b].add(a)
    vus = set()
    out = []
    for n in noeuds:
        if n in vus:
            continue
        pile, comp = [n], []
        vus.add(n)
        while pile:
            x = pile.pop()
            comp.append(x)
            for y in vois[x]:
                if y not in vus:
                    vus.add(y)
                    pile.append(y)
        out.append(comp)
    return sorted(out, key=len, reverse=True)


if __name__ == "__main__":
    main()
