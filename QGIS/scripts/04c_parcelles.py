# -*- coding: utf-8 -*-
"""04c — la subdivision de l'îlot en parcelles.

Ce que ça fait, en une phrase : l'emprise bâtie de chaque îlot (couche
`emprises`, écrite par 04b) est **découpée** récursivement en parcelles, et le
résultat part dans une nouvelle couche `parcelles` du GeoPackage.

═══════════════════════════════════════════════════════════════════════════
LES DEUX DÉCISIONS QUI COMMANDENT CE FICHIER, ET CE QU'ELLES INTERDISENT
═══════════════════════════════════════════════════════════════════════════

  61 · LA PARCELLE EST UNE PARTITION DE L'EMPRISE.
       Le générateur DÉCOUPE, il ne pose pas des formes dans un vide. Deux
       parcelles voisines partagent une arête EXACTEMENT, parce qu'elles sont
       les deux moitiés d'une même coupe. Le mitoyen n'est pas un raccord à
       faire après coup, c'est une propriété de la méthode.
       → Le contrôle qui le prouve, et qui ne se négocie pas : la somme des
         aires des parcelles d'un îlot vaut 100,00 % de l'aire de son emprise.

  35 · LA PARCELLE EST L'ENTITÉ PERSISTANTE, SEEDÉE INDIVIDUELLEMENT.
       Chaque parcelle porte sa propre graine, dérivée de sa position et non
       de son rang. Conséquence : régénérer le bâtiment d'UNE parcelle ne
       touche aucune autre.
       → ⚠️ Le piège nommé par 61 : la partition ne doit JAMAIS se rejouer
         quand une seule parcelle change. C'est pour ça qu'elle est calculée
         ici, une fois, et écrite dans le `.gpkg` — pas recalculée au moment
         de l'affichage. Si un jour quelqu'un déplace ce calcul dans Godot,
         il ré-effondre le voisinage à chaque clic (ce qu'on reproche à
         Townscaper, 42b) et 35 tombe avec.

La découpe est DÉTERMINISTE : deux exécutions donnent exactement la même
carte. Aucun `random` non seedé, et la graine de chaque coupe se dérive des
coordonnées du morceau qu'on coupe — pas d'un compteur, qui décalerait tout
dès qu'on change une ligne de la table ci-dessous.

Usage :
    python QGIS/scripts/04c_parcelles.py            écrit dans le .gpkg
    python QGIS/scripts/04c_parcelles.py --blanc    calcule, affiche, n'écrit rien
    python QGIS/scripts/04c_parcelles.py chemin.gpkg   sur une copie
"""

import math
import os
import struct
import sqlite3
import sys
import zlib

ICI = os.path.dirname(os.path.abspath(__file__))
RACINE = os.path.dirname(os.path.dirname(ICI))

BLANC = "--blanc" in sys.argv           # passe à blanc : calcule et affiche
_ARGS = [a for a in sys.argv[1:] if not a.startswith("--")]
GPKG = _ARGS[0] if _ARGS else os.path.join(RACINE, "QGIS", "data",
                                           "Prototype_qualifie.gpkg")
SRS = 25832                             # EPSG:25832 — décision 31


# ==========================================================================
# LE LEVEL DESIGN — les treize lignes qu'on règle, et rien d'autre
# ==========================================================================
#
# Même forme que la table `TISSU` de `04_deriver_attributs.py`, et au même
# endroit dans le fichier : en haut, avant toute mécanique.
#
#   facade      largeur de rue visée pour une parcelle, en mètres. C'est ELLE
#               qui décide du grain du tissu — 7 m fait un peigne de maisons
#               étroites, 18 m fait des pavillons détachés.
#   profondeur  profondeur visée. Au-delà de deux fois cette valeur, l'îlot
#               est d'abord coupé en deux dans sa longueur : c'est le
#               dos-à-dos, et c'est ce qui fait apparaître les cœurs d'îlot.
#
# ⚠️ Ces chiffres sont une PROPOSITION, à corriger devant l'image. Le contrôle
# à faire n'est pas « est-ce que le nombre est juste » mais « est-ce que le
# cœur ancien ressemble à un cœur ancien ».
TISSU = {
    #  sous_type              facade  profondeur
    "coeur_ancien":            (7.0,   16.0),   # parcellaire fin, très mitoyen
    "maisons_de_ville":        (8.0,   20.0),   # le tissu majoritaire de Wehrau
    "front_commercant":       (11.0,   18.0),   # vitrines en rez-de-chaussée
    "pavillonnaire":          (18.0,   25.0),   # détaché, jardins
    "barre_1970":             (60.0,   15.0),   # des barres longues et minces
    "equipement":             (45.0,   35.0),   # un ou deux objets par îlot
    "dalle_commercial":       (80.0,   60.0),   # (alias, voir plus bas)
    "dalle_commerciale":      (80.0,   60.0),   # un hangar, pas un lotissement
    "friche_industrielle":    (55.0,   45.0),   # des halles
}
# Les quatre sous-types SANS bâti ne se découpent pas : ils restent des sols.
# `riviere` non plus, évidemment.
SANS_DECOUPE = {"place_minerale", "parc", "champ", "jardins_familiaux",
                "riviere"}

# En dessous, on ne coupe plus : une parcelle de 30 m² n'est pas une parcelle,
# c'est un éclat de découpe. Sert de garde-fou, pas de règle de dessin.
AIRE_MIN = 45.0

# De combien la coupe peut se décaler de sa position idéale, en part de
# l'écart entre deux coupes. Sans ce jeu, tout le tissu est au cordeau et se
# voit ; à 0,25 il respire sans qu'aucune parcelle ne devienne aberrante.
JEU = 0.25

# Variation de hauteur d'une parcelle autour de celle de son îlot, en niveaux.
# ± 1 suffit à casser le bloc plein sans contredire la donnée.
JEU_NIVEAUX = 1


# ==========================================================================
# mécanique — rien à régler en dessous
# ==========================================================================

EPS = 1e-9


# ------------------------------------------------------------------ lecture

def gpkg_vers_wkb(blob):
    tailles = {0: 0, 1: 32, 2: 48, 3: 48, 4: 64}
    return blob[8 + tailles[(blob[3] >> 1) & 0x07]:]


def _e(buf, off, o):
    return struct.unpack_from(o + "I", buf, off)[0], off + 4


def _p(buf, off, o, n):
    pts = list(struct.unpack_from(o + "%dd" % (2 * n), buf, off))
    return [(pts[i], pts[i + 1]) for i in range(0, len(pts), 2)], off + 16 * n


def lire_wkb(buf, off=0):
    """Renvoie (liste d'anneaux, offset). Ne lit que Polygon et MultiPolygon —
    c'est tout ce que la couche `emprises` contient."""
    o = "<" if buf[off] == 1 else ">"
    off += 1
    typ, off = _e(buf, off, o)
    typ %= 1000
    if typ == 3:
        n, off = _e(buf, off, o)
        anneaux = []
        for _ in range(n):
            m, off = _e(buf, off, o)
            pts, off = _p(buf, off, o, m)
            anneaux.append(pts)
        return anneaux, off
    if typ == 6:
        n, off = _e(buf, off, o)
        tout = []
        for _ in range(n):
            a, off = lire_wkb(buf, off)
            tout += a
        return tout, off
    raise ValueError("type WKB inattendu : %d" % typ)


# ----------------------------------------------------------------- géométrie

def aire_signee(anneau):
    s = 0.0
    n = len(anneau)
    for i in range(n):
        x1, y1 = anneau[i]
        x2, y2 = anneau[(i + 1) % n]
        s += x1 * y2 - x2 * y1
    return s / 2.0


def perimetre(anneau):
    n = len(anneau)
    return sum(math.hypot(anneau[(i + 1) % n][0] - anneau[i][0],
                          anneau[(i + 1) % n][1] - anneau[i][1])
               for i in range(n))


def ouvrir(anneau):
    """Anneau OUVERT, orienté dans le sens trigonométrique. Tout le fichier en
    dépend : le sens décide de quel côté d'une coupe est l'intérieur."""
    a = list(anneau)
    while len(a) > 1 and a[0] == a[-1]:
        a.pop()
    if aire_signee(a) < 0:
        a.reverse()
    return a


def nettoyer(anneau, tol=1e-7):
    """Retire les sommets doublons et les sommets alignés. Une coupe en
    produit à chaque passage, et sans ce ménage l'anneau enfle de récursion en
    récursion jusqu'à faire ramer la triangulation."""
    out = []
    for p in anneau:
        if not out or math.hypot(p[0] - out[-1][0], p[1] - out[-1][1]) > tol:
            out.append(p)
    while len(out) > 1 and math.hypot(out[0][0] - out[-1][0],
                                      out[0][1] - out[-1][1]) <= tol:
        out.pop()
    if len(out) < 3:
        return out
    garde = []
    n = len(out)
    for i in range(n):
        a, b, c = out[(i - 1) % n], out[i], out[(i + 1) % n]
        # produit vectoriel : si les trois sont alignés, `b` ne sert à rien
        cr = (b[0] - a[0]) * (c[1] - a[1]) - (b[1] - a[1]) * (c[0] - a[0])
        if abs(cr) > 1e-6:
            garde.append(b)
    return garde if len(garde) >= 3 else out


def enveloppe_convexe(pts):
    """Chaîne monotone d'Andrew. Sert uniquement au rectangle englobant."""
    p = sorted(set(pts))
    if len(p) < 3:
        return p

    def demi(seq):
        h = []
        for q in seq:
            while len(h) >= 2:
                a, b = h[-2], h[-1]
                if (b[0] - a[0]) * (q[1] - a[1]) - (b[1] - a[1]) * (q[0] - a[0]) <= 0:
                    h.pop()
                else:
                    break
            h.append(q)
        return h

    return demi(p)[:-1] + demi(reversed(p))[:-1]


def rectangle_englobant(anneau):
    """Le rectangle d'aire minimale qui contient l'anneau, par la méthode des
    calipers : le rectangle optimal a forcément un côté sur une arête de
    l'enveloppe convexe. Renvoie (axe long, axe court, longueur, profondeur,
    centre projeté)."""
    h = enveloppe_convexe(anneau)
    if len(h) < 3:
        h = anneau
    meilleur = None
    n = len(h)
    for i in range(n):
        a, b = h[i], h[(i + 1) % n]
        dx, dy = b[0] - a[0], b[1] - a[1]
        L = math.hypot(dx, dy)
        if L < EPS:
            continue
        ux, uy = dx / L, dy / L
        vx, vy = -uy, ux
        us = [p[0] * ux + p[1] * uy for p in h]
        vs = [p[0] * vx + p[1] * vy for p in h]
        w, d = max(us) - min(us), max(vs) - min(vs)
        if meilleur is None or w * d < meilleur[0] - 1e-9:
            meilleur = (w * d, (ux, uy), (vx, vy), w, d,
                        ((min(us) + max(us)) / 2.0, (min(vs) + max(vs)) / 2.0))
    _, u, v, w, d, c = meilleur
    if w >= d:
        return u, v, w, d, c
    return v, u, d, w, (c[1], c[0])


def couper(anneau, p0, nrm):
    """Coupe un anneau simple par la droite passant par `p0` de normale `nrm`.

    Renvoie la liste de TOUS les morceaux, des deux côtés. Un polygone concave
    peut donner plus de deux morceaux — c'est le cas qu'une simple découpe à la
    Sutherland-Hodgman raterait, en fabriquant un anneau replié sur lui-même
    d'aire juste mais de géométrie fausse.

    La méthode : on augmente l'anneau des points d'intersection, on extrait les
    chaînes maximales de chaque côté, puis on les recoud le long de la droite
    dans l'ordre où elles s'y présentent. C'est ce recousage qui garantit 61 —
    deux morceaux voisins partagent l'arête EXACTE qu'on vient de calculer, pas
    deux arêtes approchantes.
    """
    n = len(anneau)
    d = [(p[0] - p0[0]) * nrm[0] + (p[1] - p0[1]) * nrm[1] for p in anneau]
    if all(x >= -EPS for x in d) or all(x <= EPS for x in d):
        return [anneau]                       # la droite ne traverse pas

    aug = []
    for i in range(n):
        a, da = anneau[i], d[i]
        b, db = anneau[(i + 1) % n], d[(i + 1) % n]
        aug.append((a, 0.0 if abs(da) <= EPS else da))
        if (da > EPS and db < -EPS) or (da < -EPS and db > EPS):
            t = da / (da - db)
            aug.append(((a[0] + t * (b[0] - a[0]),
                         a[1] + t * (b[1] - a[1])), 0.0))

    # Direction de parcours SUR la droite pour que l'intérieur reste à gauche.
    # Pour le côté `signe`, l'intérieur pointe vers `signe * nrm`, et « à
    # gauche de u » vaut (−u.y, u.x) : d'où u = signe * (nrm.y, −nrm.x).
    morceaux = []
    for signe in (1.0, -1.0):
        chaines = _chaines(aug, signe)
        if not chaines:
            continue
        ux, uy = signe * nrm[1], -signe * nrm[0]

        def t_de(p):
            return (p[0] - p0[0]) * ux + (p[1] - p0[1]) * uy

        # Chaque chaîne va d'une entrée à une sortie, toutes deux sur la
        # droite. On repart d'une sortie vers l'entrée suivante en avançant.
        entrees = sorted(range(len(chaines)), key=lambda k: t_de(chaines[k][0]))
        restant = set(range(len(chaines)))
        while restant:
            depart = min(restant)
            anneau_out = []
            k = depart
            while True:
                restant.discard(k)
                anneau_out += chaines[k]
                fin = chaines[k][-1]
                tf = t_de(fin)
                suivant = None
                for j in entrees:
                    if j in restant and t_de(chaines[j][0]) >= tf - 1e-7:
                        suivant = j
                        break
                if suivant is None or suivant == depart:
                    break
                k = suivant
            anneau_out = nettoyer(anneau_out)
            if len(anneau_out) >= 3 and abs(aire_signee(anneau_out)) > 1e-6:
                morceaux.append(ouvrir(anneau_out))
    return morceaux if morceaux else [anneau]


def _chaines(aug, signe):
    """Les suites maximales de sommets du côté `signe`, chacune bornée par deux
    points posés sur la droite."""
    m = len(aug)
    garde = [signe * dd >= -EPS for _, dd in aug]
    if all(garde):
        return [[p for p, _ in aug]]
    if not any(garde):
        return []
    depart = next(i for i in range(m) if garde[i] and not garde[(i - 1) % m])
    chaines, courante = [], []
    for k in range(m):
        i = (depart + k) % m
        if garde[i]:
            courante.append(aug[i][0])
        elif courante:
            chaines.append(courante)
            courante = []
    if courante:
        chaines.append(courante)
    # Une chaîne qui ne commence ni ne finit sur la droite est un contact
    # ponctuel : elle ne borde aucune surface, on la jette.
    return [c for c in chaines if len(c) >= 2]


def aire_demi_plan(anneau, p0, nrm):
    """L'aire de la part d'anneau située du côté positif de la droite.

    Découpe de Sutherland-Hodgman : sur un anneau concave elle fabrique des
    passerelles de largeur nulle, donc une géométrie fausse — mais une AIRE
    juste, parce que les passerelles sont parcourues deux fois en sens
    contraire et s'annulent. C'est tout ce qu'on lui demande ici ; la vraie
    découpe, elle, passe par `couper`."""
    out = []
    n = len(anneau)
    for i in range(n):
        a, b = anneau[i], anneau[(i + 1) % n]
        da = (a[0] - p0[0]) * nrm[0] + (a[1] - p0[1]) * nrm[1]
        db = (b[0] - p0[0]) * nrm[0] + (b[1] - p0[1]) * nrm[1]
        if da >= 0.0:
            out.append(a)
        if (da > 0.0 and db < 0.0) or (da < 0.0 and db > 0.0):
            t = da / (da - db)
            out.append((a[0] + t * (b[0] - a[0]), a[1] + t * (b[1] - a[1])))
    return abs(aire_signee(out)) if len(out) >= 3 else 0.0


def coupe_par_aire(anneau, nrm, part):
    """Où poser la droite de normale `nrm` pour que `part` de l'aire tombe du
    côté positif. Dichotomie sur la position, vingt-huit tours.

    🔴 C'EST LA CORRECTION QUI FAIT TENIR LE COMPTE DE PARCELLES. Couper au
    milieu GÉOMÉTRIQUE du rectangle englobant paraissait naturel et donnait
    n'importe quoi : l'îlot 34 ne remplit que 67 % de son rectangle, donc la
    coupe médiane le partageait en 927 et 1 685 m². Le gros morceau se
    redécoupait une fois de trop, et le tissu sortait deux à trois fois trop
    fin — 49 m² de parcelle au cœur ancien pour une cible de 112.

    Couper par l'AIRE donne en prime des parcelles de tailles voisines, ce
    qui est aussi ce à quoi ressemble un vrai parcellaire."""
    ds = sorted((p[0] - anneau[0][0]) * nrm[0] + (p[1] - anneau[0][1]) * nrm[1]
                for p in anneau)
    lo, hi = ds[0], ds[-1]
    total = abs(aire_signee(anneau))
    cible = part * total
    base = anneau[0]
    for _ in range(28):
        mi = (lo + hi) / 2.0
        p0 = (base[0] + nrm[0] * mi, base[1] + nrm[1] * mi)
        if aire_demi_plan(anneau, p0, nrm) > cible:
            lo = mi                       # trop de surface au-dessus : monter
        else:
            hi = mi
    mi = (lo + hi) / 2.0
    return (base[0] + nrm[0] * mi, base[1] + nrm[1] * mi)


def graine_de(pts):
    """Une graine stable, dérivée de la GÉOMÉTRIE et non d'un compteur.

    C'est la décision 35 prise au sérieux : si la graine venait d'un rang, il
    suffirait d'ajouter une parcelle quelque part pour redistribuer toutes les
    suivantes. Là, une parcelle qui n'a pas bougé garde sa graine, même si sa
    voisine a été redécoupée."""
    cx = sum(p[0] for p in pts) / len(pts)
    cy = sum(p[1] for p in pts) / len(pts)
    return zlib.crc32(("%.2f|%.2f" % (cx, cy)).encode("utf-8"))


# ------------------------------------------------------------ la subdivision

def subdiviser(anneau, facade, prof, n_cible=None, garde=0):
    """Découpe récursive d'une emprise. Renvoie la liste des parcelles.

    Le nombre de parcelles est décidé UNE FOIS, en haut, par l'aire :
    `aire ÷ (façade × profondeur)`. La récursion ne fait plus que répartir ce
    nombre. C'est ce qui rend le résultat prévisible — on lit la table du haut
    et on sait combien de parcelles vont sortir.

    Deux coupes possibles, et l'ordre compte :
      · le DOS-À-DOS quand le morceau est plus profond qu'une fois et demie la
        profondeur visée. C'est lui qui fait apparaître les cœurs d'îlot ;
      · le DÉBIT EN LANIÈRES sinon, perpendiculairement à la longueur.
    """
    aire = abs(aire_signee(anneau))
    if n_cible is None:
        n_cible = max(1, int(round(aire / (facade * prof))))
    if n_cible <= 1 or aire < AIRE_MIN * 1.6 or garde > 20:
        return [anneau]

    u, v, L, P, _ = rectangle_englobant(anneau)
    # On dégrossit la profondeur d'abord, tant qu'elle dépasse la cible — mais
    # jamais sur un morceau déjà plus profond que long, sinon on débite dans le
    # mauvais sens et les parcelles tournent le dos à la rue.
    if P >= prof * 1.5 and P >= L * 0.34:
        axe = v
    else:
        axe = u

    k = n_cible // 2
    rng = graine_de(anneau)
    jeu = ((rng % 1000) / 1000.0 - 0.5) * 2.0 * JEU / n_cible
    part = min(0.85, max(0.15, k / float(n_cible) + jeu))

    p0 = coupe_par_aire(anneau, axe, part)
    morceaux = [m for m in couper(anneau, p0, axe)
                if abs(aire_signee(m)) > 1e-6]
    if len(morceaux) < 2:
        return [anneau]                # la coupe n'a rien coupé : on s'arrête

    # Chaque morceau reçoit sa part du nombre visé, au prorata de son aire.
    # Le reliquat va au plus gros : sans ça la somme dérive et le compte final
    # ne correspond plus à la table.
    aires = [abs(aire_signee(m)) for m in morceaux]
    tot = sum(aires)
    parts = [max(1, int(round(n_cible * a / tot))) for a in aires]
    while sum(parts) != n_cible:
        i = aires.index(max(aires)) if sum(parts) < n_cible \
            else parts.index(max(parts))
        parts[i] += 1 if sum(parts) < n_cible else -1
        if parts[i] < 1:
            parts[i] = 1
            break

    out = []
    for m, np_ in zip(morceaux, parts):
        out += subdiviser(m, facade, prof, np_, garde + 1)
    return out


def facade_de(parcelle, bord_idx, grille=1.0, tol=0.35):
    """Les mètres de la parcelle qui donnent sur la rue.

    Critère : un point milieu d'arête posé sur le bord de l'emprise d'origine.
    Le reste du périmètre est forcément partagé avec une parcelle voisine —
    c'est la partition (61) qui le garantit, il n'y a pas de troisième cas."""
    tot = 0.0
    n = len(parcelle)
    for i in range(n):
        a, b = parcelle[i], parcelle[(i + 1) % n]
        m = ((a[0] + b[0]) / 2.0, (a[1] + b[1]) / 2.0)
        cx, cy = int(m[0] // grille), int(m[1] // grille)
        proche = False
        for dx in (-1, 0, 1):
            for dy in (-1, 0, 1):
                for (p, q) in bord_idx.get((cx + dx, cy + dy), ()):
                    if dist_pt_seg(m, p, q) <= tol:
                        proche = True
                        break
                if proche:
                    break
            if proche:
                break
        if proche:
            tot += math.hypot(b[0] - a[0], b[1] - a[1])
    return tot


def dist_pt_seg(p, a, b):
    dx, dy = b[0] - a[0], b[1] - a[1]
    L2 = dx * dx + dy * dy
    if L2 < EPS:
        return math.hypot(p[0] - a[0], p[1] - a[1])
    t = max(0.0, min(1.0, ((p[0] - a[0]) * dx + (p[1] - a[1]) * dy) / L2))
    return math.hypot(p[0] - a[0] - t * dx, p[1] - a[1] - t * dy)


def indexer_bord(anneau, grille=1.0):
    """Index de grille des arêtes de l'emprise, pour que `facade_de` ne soit
    pas quadratique. 53 emprises × ~1 500 parcelles, ça compte."""
    idx = {}
    n = len(anneau)
    for i in range(n):
        a, b = anneau[i], anneau[(i + 1) % n]
        x0, x1 = int(min(a[0], b[0]) // grille), int(max(a[0], b[0]) // grille)
        y0, y1 = int(min(a[1], b[1]) // grille), int(max(a[1], b[1]) // grille)
        for cx in range(x0, x1 + 1):
            for cy in range(y0, y1 + 1):
                idx.setdefault((cx, cy), []).append((a, b))
    return idx


# ----------------------------------------------------------------- encodage

def wkb_polygone(anneaux):
    out = [struct.pack("<BII", 1, 3, len(anneaux))]
    for a in anneaux:
        pts = list(a)
        if pts[0] != pts[-1]:
            pts.append(pts[0])
        out.append(struct.pack("<I", len(pts)))
        for x, y in pts:
            out.append(struct.pack("<dd", x, y))
    return b"".join(out)


def blob_gpkg(wkb):
    return struct.pack("<2sBBi", b"GP", 0, 0x01, SRS) + wkb


# --------------------------------------------------------------------- main

def lire(con):
    manque = con.execute(
        "SELECT count(*) FROM sqlite_master WHERE type='table' AND name='emprises'"
    ).fetchone()[0] == 0
    if manque:
        raise SystemExit("la couche `emprises` n'existe pas — lancer d'abord "
                         "04b_emprises_baties.py")

    ilots = {}
    for fid, st, haut, logts in con.execute(
        "SELECT fid, sous_type, hauteur, logements FROM ilots ORDER BY fid"
    ):
        ilots[fid] = {"st": st, "haut": haut or 0.0, "log": logts or 0}
    for fid, geom in con.execute("SELECT fid_ilot, geom FROM emprises"):
        if fid in ilots:
            ilots[fid]["ext"] = ouvrir(lire_wkb(gpkg_vers_wkb(geom))[0][0])
    return ilots


def main():
    if not os.path.exists(GPKG):
        raise SystemExit("introuvable : %s" % GPKG)
    con = sqlite3.connect("file:%s?mode=ro" % GPKG.replace("\\", "/"), uri=True)
    ilots = lire(con)
    con.close()

    print("=" * 74)
    print("PARCELLES — %s%s" % (os.path.basename(GPKG),
                                "   (passe à blanc, rien n'est écrit)" if BLANC else ""))
    print()

    resultats = []
    ecarts = []
    par_st = {}
    saute = []

    for fid in sorted(ilots):
        d = ilots[fid]
        st = d["st"]
        if st in SANS_DECOUPE or "ext" not in d or d["haut"] <= 0.0:
            saute.append((fid, st))
            continue
        if st not in TISSU:
            print("  ⚠️  sous_type absent de TISSU, îlot laissé entier : %s (îlot %d)"
                  % (st, fid))
            saute.append((fid, st))
            continue

        facade, prof = TISSU[st]
        ext = d["ext"]
        aire0 = abs(aire_signee(ext))
        parcelles = subdiviser(ext, facade, prof)

        # 🔴 LE CONTRÔLE QUI COMMANDE TOUT LE FICHIER (décision 61).
        somme = sum(abs(aire_signee(p)) for p in parcelles)
        ecarts.append((abs(somme - aire0) / aire0 if aire0 else 0.0, fid, st,
                       len(parcelles), aire0, somme))

        idx = indexer_bord(ext)
        for p in parcelles:
            per = perimetre(p)
            fac = facade_de(p, idx)
            g = graine_de(p)
            # ± JEU_NIVEAUX autour de la hauteur de l'îlot, tiré de la graine
            # de la parcelle : deux parcelles voisines ne montent pas pareil,
            # et une parcelle garde sa hauteur quand sa voisine change.
            niv = d["haut"] + ((g >> 5) % (2 * JEU_NIVEAUX + 1)) - JEU_NIVEAUX
            resultats.append({
                "fid_ilot": fid, "st": st, "anneau": p,
                "aire": abs(aire_signee(p)), "perim": per, "facade": fac,
                "mitoyen": max(0.0, per - fac), "graine": g,
                "niveaux": max(1.0, niv),
            })
        par_st.setdefault(st, []).append((fid, len(parcelles), aire0))

    # ------------------------------------------------------------- contrôles
    print("  LE DÉCOUPAGE, PAR TISSU")
    print("  %-22s %5s %8s %9s %9s %8s" % ("sous_type", "îlots", "parcelles",
                                           "aire moy", "façade moy", "mitoyen"))
    print("  " + "-" * 70)
    total = 0
    for st in sorted(par_st, key=lambda k: -sum(n for _, n, _ in par_st[k])):
        lot = [r for r in resultats if r["st"] == st]
        n = len(lot)
        total += n
        am = sum(r["aire"] for r in lot) / n
        fm = sum(r["facade"] for r in lot) / n
        mi = sum(r["mitoyen"] for r in lot) / sum(r["perim"] for r in lot)
        print("  %-22s %5d %8d %8.0f m² %8.1f m %7.0f %%"
              % (st, len(par_st[st]), n, am, fm, 100.0 * mi))
    print("  " + "-" * 70)
    print("  %-22s %5d %8d" % ("TOTAL", sum(len(v) for v in par_st.values()), total))
    print()
    print("  %d îlots laissés entiers (sols, rivière, hauteur nulle)" % len(saute))
    print()

    print("  🔴 LA PARTITION — décision 61. Chaque îlot doit tomber sur 100,00 %.")
    pires = sorted(ecarts, reverse=True)[:5]
    # Le seuil est à un cent-millième de l'aire, soit ~0,03 m² sur un îlot de
    # 3 000 : au-delà c'est une vraie perte de surface, en dessous c'est le
    # bruit de la virgule flottante sur des coordonnées à sept chiffres.
    faux = [e for e in ecarts if e[0] > 1e-5]
    if not faux:
        print("     ✅ %d îlots sur %d, écart maximal %.2e — la découpe est une"
              " partition." % (len(ecarts), len(ecarts), pires[0][0] if pires else 0.0))
    else:
        print("     ❌ %d îlots perdent ou gagnent de la surface :" % len(faux))
        for e, fid, st, n, a0, s in pires:
            print("        îlot %-3d %-20s %d parcelles  %.1f → %.1f m²  (%.4f %%)"
                  % (fid, st, n, a0, s, 100.0 * e))
    print()

    eclats = [r for r in resultats if r["aire"] < 20.0]
    print("  LES ÉCLATS — parcelles sous 20 m², qui ne sont pas des parcelles")
    if not eclats:
        print("     ✅ aucune")
    else:
        ou = {}
        for r in eclats:
            ou[r["fid_ilot"]] = ou.get(r["fid_ilot"], 0) + 1
        print("     ⚠️  %d sur %d parcelles, sur %d îlots : %s"
              % (len(eclats), total, len(ou),
                 ", ".join("%d (×%d)" % (f, n)
                           for f, n in sorted(ou.items(), key=lambda x: -x[1])[:8])))
    print()

    print("  LE VOISINAGE — part du périmètre partagée avec une autre parcelle")
    print("     ⚠️ Ce n'est PAS la mitoyenneté des maisons, et il ne faut pas")
    print("     le lire comme ça. Une partition (61) fait que toute parcelle")
    print("     touche ses voisines, y compris en pavillonnaire : ce sont les")
    print("     JARDINS qui se touchent, pas les murs. Ce chiffre mesure la")
    print("     découpe du sol, et il doit être haut partout.")
    print("     Le mitoyen des BÂTIMENTS, lui, se règle ailleurs — c'est le")
    print("     `jeu` de la table BATI, en haut de `07_exporter_godot.py` :")
    print("     0 m colle les maisons, 2,8 m les détache.")
    print()

    if BLANC:
        print("  (passe à blanc — la couche `parcelles` n'a pas été écrite)")
    else:
        ecrire(resultats)
        print("→ couche `parcelles` écrite dans %s  (%d lignes)"
              % (os.path.basename(GPKG), len(resultats)))
    print("=" * 74)


def ecrire(resultats):
    con = sqlite3.connect(GPKG)
    cur = con.cursor()
    cur.execute("DROP TABLE IF EXISTS parcelles")
    for t in ("gpkg_contents", "gpkg_geometry_columns", "gpkg_ogr_contents"):
        cur.execute("DELETE FROM %s WHERE table_name = 'parcelles'" % t)
    cur.execute("""
        CREATE TABLE "parcelles" (
            "fid" INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
            "geom" POLYGON,
            fid_ilot INTEGER,
            sous_type TEXT,
            surface_m2 REAL,
            facade_m REAL,
            mitoyen_m REAL,
            niveaux REAL,
            graine INTEGER)""")

    xs, ys, n = [], [], 0
    for r in resultats:
        if len(r["anneau"]) < 3:
            continue
        for p in r["anneau"]:
            xs.append(p[0])
            ys.append(p[1])
        cur.execute(
            "INSERT INTO parcelles (geom, fid_ilot, sous_type, surface_m2,"
            " facade_m, mitoyen_m, niveaux, graine) VALUES (?,?,?,?,?,?,?,?)",
            (blob_gpkg(wkb_polygone([r["anneau"]])), r["fid_ilot"], r["st"],
             round(r["aire"], 1), round(r["facade"], 2),
             round(r["mitoyen"], 2), r["niveaux"], r["graine"]))
        n += 1

    cur.execute(
        "INSERT INTO gpkg_contents (table_name, data_type, identifier,"
        " description, last_change, min_x, min_y, max_x, max_y, srs_id)"
        " VALUES ('parcelles','features','parcelles',?,"
        " strftime('%Y-%m-%dT%H:%M:%fZ','now'),?,?,?,?,?)",
        ("Partition de l'emprise batie en parcelles (04c) - decisions 61 et 35",
         min(xs), min(ys), max(xs), max(ys), SRS))
    cur.execute(
        "INSERT INTO gpkg_geometry_columns (table_name, column_name,"
        " geometry_type_name, srs_id, z, m)"
        " VALUES ('parcelles','geom','POLYGON',?,0,0)", (SRS,))
    cur.execute("INSERT INTO gpkg_ogr_contents (table_name, feature_count)"
                " VALUES ('parcelles',?)", (n,))
    con.commit()
    con.close()


if __name__ == "__main__":
    for flux in (sys.stdout, sys.stderr):
        try:
            flux.reconfigure(encoding="utf-8", errors="replace")
        except (AttributeError, OSError):
            pass
    main()
