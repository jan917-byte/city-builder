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

═══════════════════════════════════════════════════════════════════════════
DEUX MANIÈRES DE DÉCOUPER, ET CELLE QUI COMMANDE
═══════════════════════════════════════════════════════════════════════════

D'après Vanegas, Kelly, Weber, Halatsch, Aliaga et Müller, *Procedural
Generation of Parcels in Urban Modeling*, Eurographics 2012. Le papier montre
qu'un îlot réel se découpe de deux façons, et en donne une par variété.

  LE PEIGNE (§4.2 du papier — « skeleton subdivision »).
       On longe la rue, on prend une bande aussi profonde que le tissu le
       demande, et on la débite en dents perpendiculaires à la rue, larges
       comme la façade visée. Ce qu'aucune rue n'a réclamé est le CŒUR
       D'ÎLOT. C'est la méthode qui commande les tissus de rue.
       → Ce qu'elle donne gratuitement : toute parcelle a sa façade sur rue
         (l'« egress » du papier), et son grand axe lui est perpendiculaire.
         Une lanière, pas un carré.

  LA BOÎTE (§4.3 — « OBB subdivision »).
       On coupe le morceau en deux selon sa boîte englobante, et on
       recommence. C'était la SEULE méthode ici jusqu'au 2026-08-13 ; elle
       garde deux rôles, exactement ceux que le papier lui laisse : les
       tissus à un ou deux gros objets par îlot, et le REMPLISSAGE DU CŒUR.

🎯 Ce que le peigne a corrigé, mesuré sur les mêmes 53 emprises. La boîte
   respectait l'AIRE de la table et rien d'autre : un cœur ancien tombait à
   111,7 m² pour 112 visés, mais sous la forme d'un carré de 10,6 m de côté
   au lieu d'une lanière de 7 × 16. Une parcelle sur deux tournait le dos à
   la rue, et 30 % n'avaient aucune façade.

     élancement (profondeur ÷ façade)   avant   après   visé
       coeur_ancien                      1,59    2,19   2,29
       maisons_de_ville                  1,46    2,44   2,50
       pavillonnaire                     1,51    2,09   2,07
       front_commercant                  1,59    1,64   1,64
     parcelles sans façade sur rue        30 %     7 %

⚠️ Ce qu'on n'a PAS repris du papier, et pourquoi :
  · le squelette droit exact (le papier passe par CGAL) — inutile ici, la
    bande d'une rue s'obtient par trois coupes en demi-plan que `couper` sait
    déjà faire. L'arbitrage des coins, que le papier règle par des
    bissectrices (§4.2.2), se règle ici par **la rue la plus longue passe en
    premier et prend le coin** — c'est son schéma `StreetLength` ;
  · la persistance sous édition (§5, coordonnées barycentriques) — sans
    objet : la découpe est calculée une fois et écrite, et la décision 35 est
    déjà tenue par la graine géométrique de `graine_de`.

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
#   profondeur  profondeur de la bande prise le long de la rue. C'est elle qui
#               décide de ce qu'il reste au milieu : au-delà de deux fois cette
#               valeur, les bandes des deux rives ne se rejoignent pas et un
#               CŒUR D'ÎLOT apparaît.
#   style       `peigne` ou `boite`, les deux méthodes du papier (voir en-tête).
#               Le peigne pour les tissus de rue ; la boîte pour les tissus à
#               un ou deux gros objets par îlot, où le peigne n'a rien à dire.
#
# 🔴 DEPUIS LE PEIGNE, LES DEUX PREMIÈRES COLONNES DISENT ENFIN CE QU'ELLES
# DISENT. La boîte ne respectait que leur PRODUIT — 7 × 16 et 11 × 10 lui
# étaient la même consigne. Maintenant `facade` est la largeur sur rue et
# `profondeur` est le fond derrière : changer l'une sans l'autre change la
# forme des parcelles, plus seulement leur nombre.
#
# ⚠️ Ces chiffres sont une PROPOSITION, à corriger devant l'image. Le contrôle
# à faire n'est pas « est-ce que le nombre est juste » mais « est-ce que le
# cœur ancien ressemble à un cœur ancien ».
TISSU = {
    #  sous_type              facade  profondeur  style
    "coeur_ancien":            (7.0,   16.0,   "peigne"),  # fin, très mitoyen
    "maisons_de_ville":        (8.0,   20.0,   "peigne"),  # le tissu majoritaire
    "front_commercant":       (11.0,   18.0,   "peigne"),  # vitrines en rez-de-ch.
    # 🔄 2026-08-12 : 18 m de façade donnaient des pavillons trop larges et trop
    # peu nombreux — une rangée de gros blocs, pas un lotissement. À 12,5 m on
    # a une maison par parcelle et le jardin derrière a la place d'exister.
    "pavillonnaire":          (13.5,   28.0,   "peigne"),  # détaché, jardins
    # La barre se couche le long de la rue : 60 m de façade pour 15 m de fond,
    # c'est une barre vue de la rue, et le peigne la pose dans le bon sens.
    "barre_1970":             (60.0,   15.0,   "peigne"),
    "equipement":             (45.0,   35.0,   "boite"),   # un ou deux objets
    "dalle_commercial":       (80.0,   60.0,   "boite"),   # (alias, voir plus bas)
    "dalle_commerciale":      (80.0,   60.0,   "boite"),   # un hangar
    "friche_industrielle":    (55.0,   45.0,   "boite"),   # des halles
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
# (C'est l'« irrégularité de coupe » ω du papier, §4.1.)
JEU = 0.25

# Une arête d'îlot plus courte que ça ne porte pas de rue : c'est un biseau de
# coin, un reste de la limite de mitre de 04b. Lui donner une bande fabrique
# des parcelles en pointe pour rien.
LONGUEUR_MIN_RUE = 6.0

# Une dent du peigne ne descend jamais sous cette part de la façade visée. Sans
# ce plancher, une bande de 9 m avec 8 m de façade se couperait en deux dents
# de 4,5 m — deux demi-maisons au lieu d'une maison un peu large.
DENT_MIN = 0.45

# Et elle ne dépasse jamais ce multiple de l'aire visée : au-delà, on ajoute des
# dents. C'est le garde-fou `Amax` du papier (§4.2.3, deuxième cas).
DENT_MAX = 2.0

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


# ------------------------------------------------------------------ le peigne

def _bande(reste, a, b, u, nrm, prof, L):
    """La bande de rue de l'arête (a→b), prise dans ce qui reste de l'îlot.

    Trois coupes en demi-plan, et rien d'autre : la PROFONDEUR, puis les deux
    BOUTS de l'arête. Ce qui en sort est borné dans les deux sens, donc une rue
    ne peut pas réclamer la façade de la rue d'à côté.

    C'est ce qui remplace le squelette droit du papier. Là où il pose une
    bissectrice au coin, on pose une perpendiculaire — mais DÉBORDANTE.

    🔴 Le débordement n'est pas un ajustement, c'est ce qui fait tenir la
    méthode. Arrêter la bande pile au bout de l'arête laisse le coin de l'îlot
    orphelin : ni cette rue ni la suivante ne le réclame, et il finit en éclats
    au cœur — mesuré, l'îlot 35 sortait 82 morceaux de cœur pour 1 243 m², dont
    63 sous 20 m². En laissant la bande mordre de `prof` au-delà de chaque bout,
    LA PREMIÈRE ARÊTE SERVIE — donc la plus longue — PREND LE COIN. C'est le
    schéma `StreetLength` du papier (§4.2.2), obtenu sans squelette. Et `prof`
    n'est pas un réglage : à un angle droit, la bissectrice du squelette monte
    à 45°, donc elle atteint exactement `prof` au fond de la bande.

    Renvoie (les morceaux de la bande, les morceaux rendus au reste).
    """
    debord = prof
    a0 = (a[0] - u[0] * debord, a[1] - u[1] * debord)
    b0 = (b[0] + u[0] * debord, b[1] + u[1] * debord)

    # 🔴 ON NE COUPE QUE CE QUI TOUCHE LA RUE. Une coupe traverse tout le plan :
    # sans ce tri, les trois droites de CHAQUE arête viennent tailler le cœur de
    # l'îlot, qui est pourtant à l'autre bout. Après vingt arêtes le cœur
    # ressortait en confettis — mesuré, 236 morceaux pour 32 îlots là où il en
    # faut un par îlot.
    # Le tri est exact, pas prudent : une parcelle de la bande a forcément un
    # bout de son bord SUR l'arête, donc un sommet dessus. Un morceau qui n'y
    # touche pas ne peut pas en faire partie — il n'a pas de façade, il
    # appartient au cœur. Il traverse sans être coupé, donc rien n'est perdu et
    # la décision 61 tient toujours.
    morceaux, intacts = [], []
    for m in reste:
        if any(dist_pt_seg(p, a, b) <= 0.05 for p in m):
            morceaux.append(m)
        else:
            intacts.append(m)

    for p0, n in (((a[0] + nrm[0] * prof, a[1] + nrm[1] * prof), nrm),
                  (a0, u), (b0, u)):
        suite = []
        for m in morceaux:
            suite += couper(m, p0, n)
        morceaux = suite

    bande, loin = [], list(intacts)
    for m in morceaux:
        if len(m) < 3 or abs(aire_signee(m)) <= 1e-6:
            continue
        cx = sum(p[0] for p in m) / len(m)
        cy = sum(p[1] for p in m) / len(m)
        dn = (cx - a[0]) * nrm[0] + (cy - a[1]) * nrm[1]      # vers l'intérieur
        dt = (cx - a[0]) * u[0] + (cy - a[1]) * u[1]          # le long de la rue
        dedans = ((-EPS <= dn <= prof + EPS)
                  and (-debord - EPS <= dt <= L + debord + EPS))
        (bande if dedans else loin).append(m)
    return bande, loin


def _dents(bande, a, u, facade, prof):
    """La bande se débite en dents perpendiculaires à la rue.

    Le nombre de dents vient de la LARGEUR sur rue, pas de l'aire : c'est toute
    la différence avec `subdiviser`, et c'est ce qui fait que `facade` veut
    enfin dire façade. Trois bornes l'encadrent, dans cet ordre :
      · la façade visée décide du nombre ;
      · une dent trop lourde en fait ajouter une (le `Amax` du papier) ;
      · une dent trop étroite en fait retirer une (le plancher `DENT_MIN`),
        ce qui évite de fabriquer un éclat qu'il faudrait recoller après coup.
    """
    ds = sorted((p[0] - a[0]) * u[0] + (p[1] - a[1]) * u[1] for p in bande)
    span = ds[-1] - ds[0]
    aire = abs(aire_signee(bande))
    if span < EPS:
        return [bande]

    k = max(1, int(round(span / facade)))
    k = max(k, int(math.ceil(aire / (DENT_MAX * facade * prof))))
    k = min(k, max(1, int(span / (facade * DENT_MIN))),
               max(1, int(aire / AIRE_MIN)))
    k = max(1, k)

    def debiter(k):
        pieces = [bande]
        for j in range(1, k):
            t = ds[0] + span * j / k
            # Le décalage se tire de la POSITION de la coupe, pas de son rang :
            # la décision 35, appliquée à la coupe et pas qu'à la parcelle.
            g = graine_de([(a[0] + u[0] * t, a[1] + u[1] * t)])
            t += ((g % 1000) / 1000.0 - 0.5) * 2.0 * JEU * span / k
            p0 = (a[0] + u[0] * t, a[1] + u[1] * t)
            suite = []
            for m in pieces:
                suite += couper(m, p0, u)
            pieces = suite
        return [p for p in pieces if len(p) >= 3 and abs(aire_signee(p)) > 1e-6]

    # Une dent trop maigre ne se rattrape pas après coup : on refait la bande
    # avec une dent de moins. C'est le troisième cas du papier (§4.2.3) — il
    # recolle les éclats à leur voisine, on préfère ne pas les fabriquer, ce
    # qui revient au même et garde la partition intacte.
    for essai in range(4):
        pieces = debiter(max(1, k - essai))
        if k - essai <= 1 or all(abs(aire_signee(p)) >= AIRE_MIN for p in pieces):
            return pieces
    return pieces


def peigne(anneau, facade, prof):
    """Découpe un îlot depuis ses rues. Renvoie (parcelles sur rue, cœur).

    Les arêtes sont servies de la plus longue à la plus courte. Chacune prend
    sa bande dans ce qui reste, et la débite. Ce qu'aucune n'a réclamé est le
    cœur d'îlot — un seul morceau en général, et c'est le but.

    Aucun morceau n'est jeté en route : tout ce qui sort d'une coupe part soit
    dans les dents, soit dans le reste. C'est ce qui fait tenir la décision 61
    sans avoir à la rattraper.
    """
    ring = ouvrir(anneau)
    n = len(ring)
    reste = [ring]
    rue = []

    def longueur(i):
        a, b = ring[i], ring[(i + 1) % n]
        return math.hypot(b[0] - a[0], b[1] - a[1])

    # À longueur égale, l'indice départage : deux arêtes jumelles ne doivent
    # pas changer d'ordre d'une exécution à l'autre.
    for i in sorted(range(n), key=lambda i: (-longueur(i), i)):
        if not reste:
            break
        a, b = ring[i], ring[(i + 1) % n]
        L = longueur(i)
        if L < LONGUEUR_MIN_RUE:
            continue
        u = ((b[0] - a[0]) / L, (b[1] - a[1]) / L)
        nrm = (-u[1], u[0])          # `ouvrir` rend l'anneau trigo : à gauche
        bande, loin = _bande(reste, a, b, u, nrm, prof, L)
        for m in bande:
            rue += _dents(m, a, u, facade, prof)
        reste = loin

    return rue, [m for m in reste if len(m) >= 3 and abs(aire_signee(m)) > 1e-6]


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
    replis = []
    coeurs = []

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

        facade, prof, style = TISSU[st]
        ext = d["ext"]
        aire0 = abs(aire_signee(ext))

        if style == "peigne":
            rue, coeur = peigne(ext, facade, prof)
            # 🌳 LE CŒUR REPASSE PAR LA BOÎTE. C'est le rôle que le papier lui
            # laisse (§4.3, dernier paragraphe) : la région intérieure se
            # remplit par une découpe récursive. Sans ça le cœur ressort d'un
            # seul tenant, et le tirage cour pavée / jardin planté de 07 se
            # ferait sur trente objets au lieu de plusieurs centaines — la
            # proportion de gris de la décision 42c y perdrait son grain.
            parcelles = [(p, "rue") for p in rue]
            for c in coeur:
                parcelles += [(p, "coeur") for p in subdiviser(c, facade, prof)]
            aire_coeur = sum(abs(aire_signee(c)) for c in coeur)

            # Le filet : si le peigne rate sa propre partition, l'îlot repart
            # ENTIER dans la boîte et le contrôle le nomme. 43 des 69 emprises
            # sont concaves — le peigne n'en a fait tomber aucune, mais on ne
            # livre pas une méthode géométrique sans son repli.
            somme = sum(abs(aire_signee(p)) for p, _ in parcelles)
            if not parcelles or (aire0 and abs(somme - aire0) > 1e-5 * aire0):
                replis.append((fid, st, len(parcelles)))
                parcelles = [(p, "boite") for p in subdiviser(ext, facade, prof)]
            else:
                coeurs.append((fid, st, len(coeur), aire_coeur,
                               sum(1 for _, o in parcelles if o == "coeur")))
        else:
            parcelles = [(p, "boite") for p in subdiviser(ext, facade, prof)]

        # 🔴 LE CONTRÔLE QUI COMMANDE TOUT LE FICHIER (décision 61).
        somme = sum(abs(aire_signee(p)) for p, _ in parcelles)
        ecarts.append((abs(somme - aire0) / aire0 if aire0 else 0.0, fid, st,
                       len(parcelles), aire0, somme))

        idx = indexer_bord(ext)
        for p, origine in parcelles:
            per = perimetre(p)
            fac = facade_de(p, idx)
            g = graine_de(p)
            _, _, long_axe, court_axe, _ = rectangle_englobant(p)
            # ± JEU_NIVEAUX autour de la hauteur de l'îlot, tiré de la graine
            # de la parcelle : deux parcelles voisines ne montent pas pareil,
            # et une parcelle garde sa hauteur quand sa voisine change.
            niv = d["haut"] + ((g >> 5) % (2 * JEU_NIVEAUX + 1)) - JEU_NIVEAUX
            resultats.append({
                "fid_ilot": fid, "st": st, "anneau": p,
                "aire": abs(aire_signee(p)), "perim": per, "facade": fac,
                "mitoyen": max(0.0, per - fac), "graine": g,
                "niveaux": max(1.0, niv), "origine": origine,
                "elan": long_axe / max(court_axe, 0.01),
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

    # ── ce que la table demande, et ce que la carte rend ───────────────────
    print("  🎯 LA TABLE EST-ELLE HONORÉE ? Façade et élancement, par tissu.")
    print("     L'élancement est le rapport du grand axe au petit. Sa cible est")
    print("     profondeur ÷ façade : c'est lui qui dit si on a une lanière")
    print("     tournée vers la rue, ou un carré. C'est LE nombre à regarder.")
    print()
    print("  %-22s %-7s %9s %9s %9s %9s" % ("sous_type", "style", "façade",
                                            "visée", "élancem.", "visé"))
    print("  " + "-" * 70)
    for st in sorted(par_st, key=lambda k: -sum(n for _, n, _ in par_st[k])):
        lot = [r for r in resultats if r["st"] == st and r["origine"] != "coeur"]
        if not lot:
            continue
        fc, pr, style = TISSU[st]
        sur_rue = [r for r in lot if r["facade"] > 0.5]
        fm = (sum(r["facade"] for r in sur_rue) / len(sur_rue)) if sur_rue else 0.0
        el = sorted(r["elan"] for r in lot)[len(lot) // 2]
        # L'élancement est un rapport du GRAND au petit axe : il ne descend
        # jamais sous 1. Sa cible se lit donc dans le même sens, sinon les
        # tissus plus larges que profonds — la barre, la dalle — seraient
        # comparés à 0,25 et le contrôle mentirait sur eux.
        cible = max(fc, pr) / min(fc, pr)
        marque = "  ✅" if abs(el - cible) <= 0.15 * cible else "  ⚠️"
        print("  %-22s %-7s %7.1f m %7.1f m %9.2f %9.2f%s"
              % (st, style, fm, fc, el, cible, marque))
    print("  " + "-" * 70)
    print("     ⚠️ La façade mesurée compte TOUS les mètres sur le bord de")
    print("     l'îlot : une parcelle d'angle en a sur deux rues, donc la")
    print("     moyenne sort au-dessus de la visée sans que rien soit faux.")
    print()

    # ── l'accès à la rue : le critère d'egress du papier ───────────────────
    print("  🚪 L'ACCÈS À LA RUE. Une parcelle sans façade n'est pas bâtie par")
    print("     `07_exporter_godot.py` : elle repart au jardin. C'est ce qui")
    print("     décide du nombre de bâtiments de la ville.")
    print()
    print("  %-22s %9s %9s %9s" % ("sous_type", "sur rue", "enclavées", "part"))
    print("  " + "-" * 56)
    n_rue = n_enc = 0
    for st in sorted(par_st, key=lambda k: -sum(n for _, n, _ in par_st[k])):
        lot = [r for r in resultats if r["st"] == st and r["origine"] != "coeur"]
        if not lot:
            continue
        e = sum(1 for r in lot if r["facade"] <= 0.5)
        n_rue += len(lot) - e
        n_enc += e
        marque = "  ✅" if e <= 0.10 * len(lot) else "  ⚠️"
        print("  %-22s %9d %9d %8.0f %%%s"
              % (st, len(lot) - e, e, 100.0 * e / len(lot), marque))
    print("  " + "-" * 56)
    print("  %-22s %9d %9d %8.0f %%"
          % ("TOTAL", n_rue, n_enc, 100.0 * n_enc / max(n_rue + n_enc, 1)))
    # ⚠️ Ce tableau ne compte QUE les parcelles de rue : les parcelles de cœur
    # n'ont pas de façade par construction, les compter ici ferait passer un
    # résultat voulu pour un défaut. Mais l'image, elle, les montre — d'où
    # cette ligne, qui réconcilie les deux nombres.
    tous = len(resultats)
    tous_enc = sum(1 for r in resultats if r["facade"] <= 0.5)
    print()
    print("     Sur les %d parcelles de la ville, cœurs compris, %d n'ont pas"
          " de façade" % (tous, tous_enc))
    print("     (%.0f %%) : %d de cœur, voulues, et %d de rue, qui sont le"
          " vrai reliquat." % (100.0 * tous_enc / max(tous, 1),
                               tous_enc - n_enc, n_enc))
    print("     %d parcelles porteront une maison." % (tous - tous_enc))
    print()

    # ── les cœurs d'îlot ──────────────────────────────────────────────────
    n_c = sum(1 for _, _, nc, _, _ in coeurs if nc)
    if coeurs:
        aire_c = sum(a for _, _, _, a, _ in coeurs)
        parts_c = sum(n for _, _, _, _, n in coeurs)
        morceaux_c = sum(nc for _, _, nc, _, _ in coeurs)
        print("  🌳 LES CŒURS D'ÎLOT — ce qu'aucune rue n'a réclamé.")
        print("     %d îlots sur %d en ont un, %.2f ha en tout, en %d morceau(x)"
              % (n_c, len(coeurs), aire_c / 1e4, morceaux_c))
        print("     redécoupés par la boîte en %d parcelles de fond, qui"
              " deviendront cours et jardins" % parts_c)
        sans = [f for f, _, nc, _, _ in coeurs if not nc]
        if sans:
            print("     %d îlots sans cœur — trop peu profonds, les bandes des"
                  " deux rives se rejoignent : %s"
                  % (len(sans), ", ".join(str(f) for f in sans[:12])))
        print()

    if replis:
        print("  ⚠️  %d ÎLOT(S) REPASSÉ(S) À LA BOÎTE — le peigne y a perdu de la"
              " surface, le filet a joué :" % len(replis))
        for fid, st, n in replis:
            print("        îlot %-3d %-20s" % (fid, st))
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
            graine INTEGER,
            origine TEXT)""")

    xs, ys, n = [], [], 0
    for r in resultats:
        if len(r["anneau"]) < 3:
            continue
        for p in r["anneau"]:
            xs.append(p[0])
            ys.append(p[1])
        cur.execute(
            "INSERT INTO parcelles (geom, fid_ilot, sous_type, surface_m2,"
            " facade_m, mitoyen_m, niveaux, graine, origine)"
            " VALUES (?,?,?,?,?,?,?,?,?)",
            (blob_gpkg(wkb_polygone([r["anneau"]])), r["fid_ilot"], r["st"],
             round(r["aire"], 1), round(r["facade"], 2),
             round(r["mitoyen"], 2), r["niveaux"], r["graine"], r["origine"]))
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
