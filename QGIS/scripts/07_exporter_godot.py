#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
07 — La carte vers Godot, en un seul JSON.

    python3 QGIS/scripts/07_exporter_godot.py
    python3 QGIS/scripts/07_exporter_godot.py une_copie.gpkg

Sort Godot/data/wehrau.json : le terrain, les 69 îlots, la voirie, les arbres,
la palette. Recentré sur le milieu de l'emprise, prêt à empaqueter.

CE QUE CE FICHIER ASSUME, ET POURQUOI

Toute la géométrie est calculée ICI, en Python, et pas en GDScript. Deux
raisons, toutes deux dans `Vault/Technique/Moteur et architecture.md` :

  « Les boucles géométriques lourdes en GDScript vont goulotter »      (l.16)
  vibe coding ❌ pour « GDScript spécifiquement »                       (l.32)

Godot ne prend donc aucune décision géométrique : il lit des tableaux et les
passe à `ArrayMesh`. Et c'est ça, l'« interface propre pour basculer en C# »
de la ligne 18 — pas une hiérarchie de classes, le contrat JSON.

LE CRITÈRE QUI DÉCIDE SI TOUT CECI A SERVI  — `Plan 3 mois.md:58`
« est-ce que la 3D m'a montré quelque chose que la page HTML ne montrait pas ? »
Si la réponse est non, la 3D s'arrête et le classeur reprend. Ce sera un bon
résultat, pas un échec.

Lecture seule. Se lance sans QGIS : sqlite3 et le lecteur WKB d'apercu_carte.
"""

import json
import math
import os
import random
import sqlite3
import sys

ICI = os.path.dirname(os.path.abspath(__file__))
RACINE = os.path.dirname(os.path.dirname(ICI))
sys.path.insert(0, ICI)

from apercu_carte import gpkg_vers_wkb, lire_wkb, dedans  # noqa: E402
import palette as PAL                                      # noqa: E402

# ⚠ L'import lit `sys.argv` au niveau module (04:52-57) : si on lance
# `07 une_copie.gpkg`, le module 04 croira travailler sur cette copie. Sans
# conséquence — on ne lui prend que des constantes — mais autant le savoir.
from importlib import import_module                        # noqa: E402
D4 = import_module("04_deriver_attributs")
D4B = import_module("04b_emprises_baties")   # `retracter`, le décalage d'arêtes
D4C = import_module("04c_parcelles")         # `couper`, la coupe par une droite

_ARGS = [a for a in sys.argv[1:] if not a.startswith("--")]
GPKG = _ARGS[0] if _ARGS else os.path.join(RACINE, "QGIS", "data",
                                           "Prototype_qualifie.gpkg")
SORTIE = os.path.join(RACINE, "Godot", "data", "wehrau.json")

# --- les constantes de la maquette ---------------------------------------
ETAGE_M = 3.0              # `hauteur` est en ÉTAGES, pas en mètres
PAS_TERRAIN = 8.0          # grille du champ d'altitude. 4 m si ça facette
MARGE_TERRAIN = 24.0       # déborde l'emprise, sinon falaise au bord
# Arête maximale d'un triangle drapé. Les caps de sol tolèrent plus large :
# les champs sont sur le plateau, où l'altitude est plafonnée à ALT_MAX et donc
# constante. Les rubans, eux, traversent la pente et la suivent de plus près.
SUBDIV_SOL = 32.0
SUBDIV_RUBAN = 20.0
ENFOUISSEMENT = 0.5        # de combien la base d'une masse plonge sous le sol

# Un ordre vertical explicite : aucun z-fighting, et rien ne dépend du
# réglage de la caméra.
Y_TERRAIN = -0.10
Y_CHAUSSEE = -0.05
Y_SOL = 0.05

# L'occlusion ambiante bakée en couleur de sommet. « Une occlusion ambiante
# marquée — c'est elle, et pas la géométrie, qui donne la profondeur »
# (Direction artistique l.21). C'est elle qui POSE les volumes au sol.
AO_MIN = 0.62
AO_HAUTEUR = 6.0

M2_PAR_ARBRE = 40.0        # une couronne de ~3,5 m de rayon
ESPACEMENT_ALIGNEMENT = 8.0
GRAINE = 20260811          # le semis doit être le même à chaque export

COLS_ILOTS = [
    "fid", "fonction", "sous_type", "surface_m2", "hauteur", "impermeabilise",
    "canopee", "stationnement", "altitude_relative", "alea",
    "position_fil_eau", "rive", "densite", "logements", "emplois", "riverain",
    "desserte_tc",
]
COLS_ROUTES = ["fid", "hierarchie", "largeur_m", "emprise_libre_m", "charge",
               "canopee", "stationnement"]

# Ce qui part dans `objets` : la fiche qu'on lit en cliquant, et l'état de
# départ du noyau. Tout ce qui n'est pas là ne peut ni s'afficher ni évoluer.
FICHE_ILOTS = [c for c in COLS_ILOTS if c != "fid"]
FICHE_ROUTES = [c for c in COLS_ROUTES if c != "fid"] + ["longueur_m"]

# La canopée d'un tronçon PLANTÉ DE BOUT EN BOUT — un arbre tous les
# ESPACEMENT_ALIGNEMENT mètres. C'est l'échelle de lecture de `routes.canopee`,
# et elle ne vaut PAS 1,0 : dans les données, la canopée de rue plafonne à
# 0,18, sa médiane est 0,10, et aucun tronçon ne dépasse 0,20. Une rue n'est
# pas un bois.
#
# ⚠️ Constante de RENDU, pas de design : elle ne change aucun chiffre de la
# simulation, seulement le nombre d'arbres qu'on voit pour une canopée donnée.
# À 0,40, une rue à 0,10 montre un arbre tous les 32 m (Wehrau aujourd'hui) et
# la même rue après D07 (+0,25) en montre un tous les 9 m — un vrai alignement.
# Le chiffre qui mérite l'œil de l'auteur, lui, est le +0,25 de `effets.csv`.
CANOPEE_ALIGNEMENT_MAX = 0.40


# --- LE BÂTI SUR LA PARCELLE ----------------------------------------------
# Ce qui transforme une parcelle (un morceau de sol) en bâtiment (un volume).
# Trois nombres par tissu, et ce sont eux qui font qu'un cœur ancien ressemble
# à un cœur ancien et un lotissement à un lotissement.
#
#   recul       distance entre la façade et la rue, en mètres. 0 = la maison
#               est SUR l'alignement, ce qui est la forme des tissus anciens.
#   jeu         distance entre la maison et sa voisine. 🔴 0 = MITOYEN, et le
#               mitoyen est alors exact : les deux parcelles partagent déjà
#               l'arête (décision 61), donc les deux murs tombent dessus au
#               millimètre. C'est le seul réglage qui fait basculer tout le
#               tissu, et c'est aussi celui qui est réversible dans un seul
#               sens — écarter est facile, recoller demanderait de tout
#               réécrire.
#   profondeur  au-delà, ce n'est plus la maison, c'est la cour ou le jardin.
#               C'est ce nombre qui creuse les cœurs d'îlot.
#
# ⚠️ PROPOSITION, à corriger devant l'image. Le contrôle n'est pas « est-ce que
# le nombre est juste » mais « est-ce qu'on croirait y habiter ».
BATI = {
    #  sous_type              recul   jeu  profondeur
    "coeur_ancien":            (0.0,  0.0,   11.0),   # sur rue, mitoyen, cour derrière
    "maisons_de_ville":        (1.5,  0.0,   11.0),   # mitoyen, petit jardin
    "front_commercant":        (0.0,  0.0,   13.0),   # sur rue, vitrines
    "pavillonnaire":           (5.0,  2.8,   10.0),   # détaché, jardin devant et derrière
    "barre_1970":              (6.0,  5.0,   13.0),   # posée dans son espace libre
    "equipement":              (4.0,  3.0,   26.0),
    "dalle_commerciale":       (2.0,  2.0,   55.0),   # un hangar, pas une maison
    "friche_industrielle":     (3.0,  2.5,   38.0),   # des halles
}
BATI_DEFAUT = (2.0, 1.0, 14.0)

# Une arête de parcelle dont le milieu est à moins de ça du bord de l'emprise
# donne sur la rue. Tout le reste est partagé avec une parcelle voisine — la
# partition (61) garantit qu'il n'y a pas de troisième cas.
TOL_RUE = 0.40


def verifier_colonnes(con, table, cols):
    """Un message clair plutôt qu'un « no such column » de sqlite."""
    presentes = {r[1] for r in con.execute("PRAGMA table_info(%s)" % table)}
    manque = [c for c in cols if c not in presentes]
    if manque:
        raise SystemExit(
            "Colonnes absentes de `%s` : %s\n"
            "Relancer d'abord :  python3 QGIS/scripts/04_deriver_attributs.py"
            % (table, ", ".join(manque)))


def verifier_couche(con, table, script):
    presentes = {r[0] for r in con.execute(
        "SELECT name FROM sqlite_master WHERE type='table'")}
    if table not in presentes:
        raise SystemExit(
            "Couche `%s` absente du GeoPackage.\n"
            "Relancer d'abord :  python3 QGIS/scripts/%s" % (table, script))


# =========================================================== le champ d'altitude

class Terrain(object):
    """Le relief, rejoué depuis la règle de `04`, échantillonnable partout.

    `04` évalue l'altitude AU CENTROÏDE de chaque îlot : une valeur par îlot.
    Extruder chacun depuis la sienne donnerait un terrain en escalier — une
    marche à chaque limite, invisible en 2D et criante en 3D. On rejoue donc
    la règle elle-même (`Génération procédurale.md:29-33`), ce qui garantit
    que le terrain et les données ne peuvent pas diverger : les constantes
    sont importées de 04, jamais recopiées.
    """

    def __init__(self, anneaux_riviere):
        self.rivieres = [list(a) + [a[0]] for a in anneaux_riviere]
        self.segs = []
        ys = []
        for a in anneaux_riviere:
            for i in range(len(a)):
                p, q = a[i], a[(i + 1) % len(a)]
                if math.hypot(q[0] - p[0], q[1] - p[1]) > 1e-9:
                    self.segs.append((p, q))
                ys.append(p[1])
        self.ynord, self.ysud = max(ys), min(ys)
        # Index en cellules : 16 000 points de grille × ~200 segments de berge
        # en force brute, c'est lent pour rien.
        self.pas = 40.0
        self.idx = {}
        for k, (p, q) in enumerate(self.segs):
            x0 = int(min(p[0], q[0]) // self.pas)
            x1 = int(max(p[0], q[0]) // self.pas)
            y0 = int(min(p[1], q[1]) // self.pas)
            y1 = int(max(p[1], q[1]) // self.pas)
            for cx in range(x0, x1 + 1):
                for cy in range(y0, y1 + 1):
                    self.idx.setdefault((cx, cy), []).append(k)

    def dist_eau(self, x, y):
        cx, cy = int(x // self.pas), int(y // self.pas)
        best = None
        r = 1
        while best is None or best > (r - 1) * self.pas:
            cand = []
            for ix in range(cx - r, cx + r + 1):
                for iy in range(cy - r, cy + r + 1):
                    cand.extend(self.idx.get((ix, iy), ()))
            for k in cand:
                p, q = self.segs[k]
                d = D4.dist_pt_seg((x, y), p, q)
                if best is None or d < best:
                    best = d
            r += 2
            if r > 60:
                break
        if best is None:                       # aucun segment : hors de tout
            best = min(D4.dist_pt_seg((x, y), p, q) for p, q in self.segs)
        return best

    def alt(self, x, y):
        # 🔴 LA SEULE DIVERGENCE ASSUMÉE AVEC 04, et elle est nécessaire.
        # `04:453` force `dist_eau = 0` par un test `sous_type == 'riviere'`,
        # qui est un cas particulier PAR ÎLOT. Appliquée telle quelle à un
        # champ continu, la formule fait REMONTER le terrain au milieu de
        # l'Ilse — une crête sous le plan d'eau. Le test d'appartenance
        # ci-dessous est la transposition correcte de ce cas particulier.
        for r in self.rivieres:
            if dedans(r, (x, y)):
                return 0.0
        fil = D4.borne((self.ynord - y) / (self.ynord - self.ysud))
        pente = D4.PENTE_AMONT + (D4.PENTE_AVAL - D4.PENTE_AMONT) * fil
        return min(pente * self.dist_eau(x, y), D4.ALT_MAX)


# ================================================================== géométrie

def aire_signee(anneau):
    s = 0.0
    n = len(anneau)
    for i in range(n):
        x1, y1 = anneau[i]
        x2, y2 = anneau[(i + 1) % n]
        s += x1 * y2 - x2 * y1
    return s / 2.0


def trianguler(anneau):
    """Découpage en oreilles d'un polygone simple. Retourne des triplets
    d'indices dans `anneau`.

    Les 69 anneaux sont simples (contrôlé par 04b : 69/69), donc pas besoin
    d'un algorithme robuste aux auto-intersections."""
    n = len(anneau)
    if n < 3:
        return []
    idx = list(range(n))
    if aire_signee(anneau) < 0:                # on travaille en trigonométrique
        idx.reverse()
    tris = []
    garde = 0
    while len(idx) > 3 and garde < 4 * n:
        garde += 1
        coupe = False
        for k in range(len(idx)):
            ia = idx[(k - 1) % len(idx)]
            ib = idx[k]
            ic = idx[(k + 1) % len(idx)]
            a, b, c = anneau[ia], anneau[ib], anneau[ic]
            aire2 = ((b[0] - a[0]) * (c[1] - a[1])
                     - (c[0] - a[0]) * (b[1] - a[1]))
            if aire2 <= 1e-9:                  # sommet réflexe ou plat
                continue
            if any(_dans_triangle(anneau[i], a, b, c)
                   for i in idx if i not in (ia, ib, ic)):
                continue
            tris.append((ia, ib, ic))
            idx.pop(k)
            coupe = True
            break
        if not coupe:
            break
    if len(idx) == 3:
        tris.append(tuple(idx))
    return tris


def _dans_triangle(p, a, b, c):
    d1 = (p[0] - b[0]) * (a[1] - b[1]) - (a[0] - b[0]) * (p[1] - b[1])
    d2 = (p[0] - c[0]) * (b[1] - c[1]) - (b[0] - c[0]) * (p[1] - c[1])
    d3 = (p[0] - a[0]) * (c[1] - a[1]) - (c[0] - a[0]) * (p[1] - a[1])
    neg = (d1 < -1e-12) or (d2 < -1e-12) or (d3 < -1e-12)
    pos = (d1 > 1e-12) or (d2 > 1e-12) or (d3 > 1e-12)
    return not (neg and pos)


def subdiviser(tris, pts, seuil):
    """Coupe récursivement l'arête la plus longue tant qu'elle dépasse le
    seuil. Sans ça, le cap d'un champ de 384 m de côté traverserait la
    colline qu'il est censé recouvrir."""
    pts = list(pts)
    milieux = {}

    def milieu(i, j):
        k = (i, j) if i < j else (j, i)
        if k not in milieux:
            pts.append(((pts[i][0] + pts[j][0]) / 2.0,
                        (pts[i][1] + pts[j][1]) / 2.0))
            milieux[k] = len(pts) - 1
        return milieux[k]

    pile = list(tris)
    sortie = []
    garde = 0
    while pile and garde < 400000:
        garde += 1
        a, b, c = pile.pop()
        lab = math.hypot(pts[b][0] - pts[a][0], pts[b][1] - pts[a][1])
        lbc = math.hypot(pts[c][0] - pts[b][0], pts[c][1] - pts[b][1])
        lca = math.hypot(pts[a][0] - pts[c][0], pts[a][1] - pts[c][1])
        m = max(lab, lbc, lca)
        if m <= seuil:
            sortie.append((a, b, c))
            continue
        if m == lab:
            d = milieu(a, b)
            pile.append((a, d, c))
            pile.append((d, b, c))
        elif m == lbc:
            d = milieu(b, c)
            pile.append((b, d, a))
            pile.append((d, c, a))
        else:
            d = milieu(c, a)
            pile.append((c, d, b))
            pile.append((d, a, b))
    return sortie, pts


def normale(p, q, r):
    ux, uy, uz = q[0] - p[0], q[1] - p[1], q[2] - p[2]
    vx, vy, vz = r[0] - p[0], r[1] - p[1], r[2] - p[2]
    nx, ny, nz = uy * vz - uz * vy, uz * vx - ux * vz, ux * vy - uy * vx
    L = math.sqrt(nx * nx + ny * ny + nz * nz)
    if L < 1e-12:
        return (0.0, 1.0, 0.0)
    return (nx / L, ny / L, nz / L)


class Maillage(object):
    """Un tas de triangles à plat : sommets, normales, couleurs, indices.
    Godot le recopie tel quel dans un `ArrayMesh`."""

    def __init__(self):
        self.v = []
        self.n = []
        self.c = []
        self.i = []
        # Les plages d'indices, un groupe par objet. Godot en refait un nœud
        # par îlot et par tronçon — c'est ce qui rend la ville CLIQUABLE, et
        # c'est aussi ce qui permet de la teinter objet par objet.
        self.groupes = []
        self._fid = None
        self._debut = 0

    def marque(self, fid):
        """Ouvre un groupe. Les triangles émis jusqu'au prochain `marque()`
        appartiennent à `fid`. Les triangles émis SANS groupe ouvert n'en ont
        aucun — ils resteront dans le maillage fusionné, sans être cliquables."""
        self.fermer()
        self._fid = fid
        self._debut = len(self.i)

    def fermer(self):
        if self._fid is not None and len(self.i) > self._debut:
            self.groupes.append([self._fid, self._debut,
                                 len(self.i) - self._debut])
        self._fid = None

    def triangle(self, p, q, r, coul, ao=(1.0, 1.0, 1.0)):
        """Émet un triangle dont la normale main droite est celle de (p, q, r).

        ⚠ MAIS LES SOMMETS SORTENT DANS L'ORDRE p, r, q.

        Godot considère les faces AVANT en sens HORAIRE — l'inverse de la
        convention main droite. Émis dans l'ordre naturel, tout ce qui regarde
        la caméra est pris pour du dos et disparaît : mesuré, les toits et le
        terrain entier étaient cullés, et les bâtiments ne se voyaient plus que
        par leurs murs. La normale, elle, reste celle de (p, q, r) : c'est elle
        qui éclaire, et elle est juste."""
        nn = normale(p, q, r)
        base = len(self.v)
        for s, f in ((p, ao[0]), (r, ao[2]), (q, ao[1])):
            self.v.append(s)
            self.n.append(nn)
            # RGB = la teinte déjà occluse ; ALPHA = l'occlusion seule.
            # Garder le facteur séparément coûte un float par sommet et permet
            # de repeindre un objet en calque thématique sans perdre ce qui le
            # POSE au sol — l'AO bakée est la fondation, pas un décor
            # (Direction artistique l.21). Aucun matériau du projet n'active la
            # transparence : ce canal est libre.
            self.c.append((coul[0] * f, coul[1] * f, coul[2] * f, f))
        self.i.extend((base, base + 1, base + 2))

    def json(self, prec=2):
        self.fermer()
        return {
            "v": [[round(c, prec) for c in s] for s in self.v],
            "n": [[round(c, 3) for c in s] for s in self.n],
            "c": [[round(c, 3) for c in s] for s in self.c],
            "i": self.i,
            "g": self.groupes,
        }

    def __len__(self):
        return len(self.i) // 3


# ===================================================================== lecture

def lire(con):
    verifier_colonnes(con, "ilots", COLS_ILOTS)
    verifier_colonnes(con, "routes", COLS_ROUTES)
    verifier_couche(con, "emprises", "04b_emprises_baties.py")

    ilots = {}
    for r in con.execute("SELECT %s FROM ilots ORDER BY fid" % ",".join(COLS_ILOTS)):
        d = dict(zip(COLS_ILOTS, r))
        ilots[d["fid"]] = d

    def anneau_ouvert(geom):
        """Anneau ouvert et orienté dans le sens TRIGONOMÉTRIQUE.

        Les 69 anneaux sources sont horaires, mais on ne le suppose pas : on
        force le sens ici, une fois. Tout le reste du fichier en dépend —
        c'est lui qui décide du côté visible des murs. Une fois passé dans
        `G()`, qui inverse Z, un anneau trigonométrique donne des normales de
        toit vers le haut et des murs tournés vers l'extérieur."""
        an, _ = lire_wkb(gpkg_vers_wkb(geom))
        a = list(an[0])
        while len(a) > 1 and a[0] == a[-1]:
            a.pop()
        if aire_signee(a) < 0:
            a.reverse()
        return a

    for fid, geom in con.execute("SELECT fid_ilot, geom FROM emprises"):
        ilots[fid]["anneau"] = anneau_ouvert(geom)

    for fid, geom in con.execute("SELECT fid, geom FROM ilots"):
        ilots[fid]["brut"] = anneau_ouvert(geom)

    orphelins = [f for f, d in ilots.items() if "anneau" not in d]
    if orphelins:
        raise SystemExit("îlots sans emprise : %s — relancer 04b"
                         % ", ".join(str(f) for f in orphelins))

    # Les PARCELLES. Facultatives : sans elles, chaque îlot bâti ressort en un
    # seul pâté plein, comme avant le 2026-08-12. C'est le repli, pas une
    # erreur — mais il doit se dire dans la console, pas se deviner à l'écran.
    for d in ilots.values():
        d["parcelles"] = []
    a_parcelles = con.execute(
        "SELECT count(*) FROM sqlite_master WHERE type='table'"
        " AND name='parcelles'").fetchone()[0] > 0
    if a_parcelles:
        for fid_i, niv, geom in con.execute(
            "SELECT fid_ilot, niveaux, geom FROM parcelles ORDER BY fid"
        ):
            if fid_i in ilots:
                ilots[fid_i]["parcelles"].append(
                    {"anneau": anneau_ouvert(geom), "niveaux": niv or 0.0})

    routes = []
    for r in con.execute("SELECT %s, geom FROM routes ORDER BY fid"
                         % ",".join(COLS_ROUTES)):
        d = dict(zip(COLS_ROUTES, r[:-1]))
        d["parts"] = lire_wkb(gpkg_vers_wkb(r[-1]))[0]
        routes.append(d)
    return ilots, routes


# ==================================================================== la sortie

def main():
    if not os.path.exists(GPKG):
        sys.exit("Introuvable : %s — lancer 02 → 03 → 04 → 04b d'abord." % GPKG)
    con = sqlite3.connect("file:%s?mode=ro" % GPKG.replace("\\", "/"), uri=True)
    ilots, routes = lire(con)
    con.close()

    print("EXPORT GODOT — %s" % os.path.basename(GPKG))
    print("  %d îlots, %d tronçons" % (len(ilots), len(routes)))

    routes_par_fid = {d["fid"]: d for d in routes}
    for d in routes:
        d["longueur_m"] = round(sum(
            math.hypot(b[0] - a[0], b[1] - a[1])
            for part in d["parts"] for a, b in zip(part, part[1:])), 1)

    # Le lien tronçon → îlots riverains. Il n'est dans AUCUNE table :
    # `adjacences` est îlot↔îlot. Sans lui, une décision de voirie ne peut pas
    # retomber sur les îlots qu'elle borde — donc pas de canopée qui monte
    # autour d'un alignement planté.
    # Emprunté à 08_jouer.py plutôt que réécrit : c'est le même critère
    # géométrique que 04b, déjà éprouvé (178/178, zéro orphelin).
    J8 = import_module("08_jouer")
    r2i, _ = J8.lier_routes_ilots(
        {f: [d["brut"]] for f, d in ilots.items()},
        {d["fid"]: d["parts"] for d in routes})
    orphelins = [d["fid"] for d in routes if d["fid"] not in r2i]
    print("  riverains : %d tronçons sur %d ont au moins un îlot (%d orphelins)"
          % (len(r2i), len(routes), len(orphelins)))
    if orphelins:
        print("    ⚠️  %s" % ", ".join(str(f) for f in orphelins[:12]))

    # ------------------------------------------------------- le recentrage
    xs = [p[0] for d in ilots.values() for p in d["brut"]]
    ys = [p[1] for d in ilots.values() for p in d["brut"]]
    for d in routes:
        for part in d["parts"]:
            xs.extend(p[0] for p in part)
            ys.extend(p[1] for p in part)
    minx, maxx, miny, maxy = min(xs), max(xs), min(ys), max(ys)
    cx, cy = (minx + maxx) / 2.0, (miny + maxy) / 2.0
    print("  emprise %.1f × %.1f m, centre (%.3f, %.3f)"
          % (maxx - minx, maxy - miny, cx, cy))

    # Repère Godot : Y en haut, Z vers le sud. Le signe sur Z garde le nord
    # au nord — et inverse la chiralité, ce dont la triangulation tient compte.
    def G(x, y, alt):
        return (x - cx, alt, -(y - cy))

    terrain = Terrain([d["brut"] for d in ilots.values()
                       if d["sous_type"] == "riviere"])
    print("  berges : %d segments, fil de l'eau de %.1f à %.1f"
          % (len(terrain.segs), terrain.ysud, terrain.ynord))

    # --------------------------------------------------------- le heightfield
    x0 = minx - MARGE_TERRAIN
    y0 = miny - MARGE_TERRAIN
    nx = int((maxx - minx + 2 * MARGE_TERRAIN) / PAS_TERRAIN) + 2
    nz = int((maxy - miny + 2 * MARGE_TERRAIN) / PAS_TERRAIN) + 2
    alt = []
    for j in range(nz):
        for i in range(nx):
            alt.append(terrain.alt(x0 + i * PAS_TERRAIN, y0 + j * PAS_TERRAIN))
    print("  terrain : grille %d × %d au pas de %.0f m (%d sommets), "
          "altitude %.2f à %.2f m"
          % (nx, nz, PAS_TERRAIN, nx * nz, min(alt), max(alt)))

    # ------------------------------------------------------------ les îlots
    masses, sols, eau = Maillage(), Maillage(), Maillage()
    rng = random.Random(GRAINE)
    arbres = []
    n_masse = n_sol = n_eau = 0
    n_parc = n_vol = n_pate = 0
    canopee_perdue = 0.0
    murs_ok = murs_tot = toits_ok = toits_tot = 0

    for fid in sorted(ilots):
        d = ilots[fid]
        an = d["anneau"]
        st = d["sous_type"]
        haut = d["hauteur"] or 0.0
        # En espace LINÉAIRE : Godot interprète les couleurs de sommet
        # comme telles. En sRGB, toute la maquette ressort délavée.
        coul = PAL.vers_lineaire(
            PAL.couleur_ilot(st, haut, d["impermeabilise"]))

        if len(an) < 3:
            continue

        if st == "riviere":
            n_eau += 1
            eau.marque(fid)
            _cap_plat(eau, an, 0.0, coul, G)
            continue

        if haut > 0.0:
            n_masse += 1
            masses.marque(fid)
            # ⚠️ TOUTES les parcelles d'un îlot tombent dans LE MÊME groupe.
            # C'est ce qui permet d'avoir mille bâtiments sans passer de 237 à
            # 1 200 nœuds cliquables : la géométrie descend à la parcelle, la
            # SÉLECTION reste à l'îlot — et la décision aussi. La parcelle est
            # l'entité persistante des données (35), pas celle du clic.
            volumes = []
            if d["parcelles"]:
                idx = _index_bord(an)
                for p in d["parcelles"]:
                    for emp in _empreinte_batie(p["anneau"], st, idx):
                        volumes.append((emp, p["niveaux"]))
                n_parc += len(d["parcelles"])
                n_vol += len(volumes)
            if not volumes:
                volumes = [(an, haut)]        # repli : le pâté plein d'avant
                n_pate += 1
            for emp, niv in volumes:
                a, b, c, e = _masse(masses, emp, d, terrain, coul, G, niv)
                murs_ok += a
                murs_tot += b
                toits_ok += c
                toits_tot += e
            # La canopée d'un îlot bâti n'est pas représentable dans une
            # maquette de masses : le pâté est plein, il n'y a pas de sol
            # visible dessous. On la compte pour le dire, pas pour la cacher.
            canopee_perdue += (d["canopee"] or 0.0) * (d["surface_m2"] or 0.0)
        else:
            n_sol += 1
            sols.marque(fid)
            _sol(sols, an, terrain, coul, G)
            arbres.extend(_semer(an, d, terrain, rng))

    print("  masses %d · sols %d · eau %d" % (n_masse, n_sol, n_eau))
    if n_parc:
        print("  parcelles %d → %d volumes bâtis  (%d enclavées : cour ou jardin)"
              % (n_parc, n_vol, n_parc - n_vol))
    if n_pate:
        print("  ⚠️  %d îlots ressortent en pâté plein — pas de parcelle, ou"
              " aucune n'a produit de volume" % n_pate)
    print("  triangles : masses %d, sols %d, eau %d"
          % (len(masses), len(sols), len(eau)))
    print("  sens des faces : murs vers l'extérieur %d/%d · toits vers le haut %d/%d"
          % (murs_ok, murs_tot, toits_ok, toits_tot))
    if murs_ok != murs_tot or toits_ok != toits_tot:
        raise SystemExit(
            "Faces mal orientées : le culling les ferait disparaître.\n"
            "L'inversion de Z change la chiralité — vérifier `anneau_ouvert`.")

    # ----------------------------------------------------------- la voirie
    voirie = Maillage()
    coul_ch = PAL.vers_lineaire(PAL.MINERAL)
    n_seg = 0
    alignements = {}
    for d in routes:
        h = d["hierarchie"]
        larg = d["largeur_m"] or 0.0
        ch = D4.EMPRISE_CIRCULATION.get(h, 8.5)
        if larg <= 0.0:
            continue                            # 4 tronçons `rive` à 0 m
        ch = min(ch, larg)
        voirie.marque(d["fid"])
        for part in d["parts"]:
            for a, b in zip(part, part[1:]):
                if math.hypot(b[0] - a[0], b[1] - a[1]) < 1e-9:
                    continue                    # un segment de longueur nulle
                _ruban(voirie, a, b, ch, terrain, coul_ch, G)
                n_seg += 1
        emplacements = _alignement(d, terrain, rng)
        if emplacements:
            alignements[str(d["fid"])] = emplacements
    n_align = sum(len(v) for v in alignements.values())
    plantes_t0 = sum(1 for f, v in alignements.items()
                     for a in v
                     if a[5] <= (routes_par_fid[int(f)]["canopee"] or 0.0))
    print("  voirie : %d segments, %d triangles" % (n_seg, len(voirie)))
    print("  arbres : %d semés dans les îlots" % len(arbres))
    print("  alignements : %d emplacements sur %d tronçons plantables, "
          "%d occupés à t0"
          % (n_align, len(alignements), plantes_t0))
    print("  canopée non représentable (îlots bâtis) : %.1f ha"
          % (canopee_perdue / 1e4))

    # -------------------------------------------------------------- écrire
    for m in (masses, sols, eau, voirie):
        m.fermer()
    n_groupes = sum(len(m.groupes) for m in (masses, sols, eau, voirie))
    n_gi = len(masses.groupes) + len(sols.groupes) + len(eau.groupes)
    print("  groupes cliquables : %d îlots sur %d, %d tronçons sur %d"
          % (n_gi, len(ilots), len(voirie.groupes), len(routes)))
    if n_gi != len(ilots):
        print("    ⚠️  des îlots ne seront pas cliquables — anneau dégénéré ?")

    doc = {
        "meta": {
            "source": os.path.basename(GPKG),
            "crs": "EPSG:%d" % 25832,
            "centre": [round(cx, 3), round(cy, 3)],
            "emprise_m": [round(maxx - minx, 1), round(maxy - miny, 1)],
            "etage_m": ETAGE_M,
            "y_terrain": Y_TERRAIN,
        },
        "palette": PAL.pour_json(),
        "terrain": {
            "x0": round(x0 - cx, 3), "z0": round(-(y0 - cy), 3),
            "pas": PAS_TERRAIN, "nx": nx, "nz": nz,
            # Le terrain descend de Y_TERRAIN : la chaussée (−0,05) doit
            # passer AU-DESSUS de lui, et les caps de sol (+0,05)
            # au-dessus des deux. Un ordre explicite, aucun z-fighting.
            "alt": [round(a + Y_TERRAIN, 2) for a in alt],
        },
        "masses": masses.json(),
        "sols": sols.json(),
        "eau": eau.json(),
        "voirie": voirie.json(),
        # Déjà en repère Godot : [x, y, z, échelle, lacet]. Godot ne fait
        # aucune conversion de coordonnées, c'est la règle du contrat.
        "arbres": [[round(c, 2) for c in G(a[0], a[1], a[2])]
                   + [round(a[3], 3), round(a[4], 3)] for a in arbres],
        # Les emplacements d'alignement, avec leur seuil de canopée. Godot en
        # fait UN MultiMesh et n'affiche que ceux dont le seuil est atteint —
        # c'est là que le temps se voit sans lire un chiffre.
        "alignements": {
            f: [[round(c, 2) for c in G(a[0], a[1], a[2])]
                + [round(a[3], 3), round(a[4], 3), round(a[5], 4)] for a in v]
            for f, v in alignements.items()
        },
        # La fiche qu'on lit en cliquant, et l'état de départ du noyau.
        "objets": {
            "ilots": {str(f): {c: d[c] for c in FICHE_ILOTS}
                      for f, d in ilots.items()},
            "routes": {str(d["fid"]): {c: d[c] for c in FICHE_ROUTES}
                       for d in routes},
        },
        "riverains": {str(f): sorted(v) for f, v in r2i.items()},
        "reperes": _reperes(ilots, routes, cx, cy),
        "controles": {
            "ilots": len(ilots), "routes": len(routes),
            "masses": n_masse, "sols": n_sol, "eau": n_eau,
            "triangles": len(masses) + len(sols) + len(eau) + len(voirie),
            "arbres": len(arbres),
            "alignements": n_align,
            "groupes": n_groupes,
        },
    }

    os.makedirs(os.path.dirname(SORTIE), exist_ok=True)
    with open(SORTIE, "w", encoding="utf-8", newline="\n") as f:
        json.dump(doc, f, ensure_ascii=False, separators=(",", ":"))
    ko = os.path.getsize(SORTIE) / 1024.0
    print("\n→ %s  (%.0f Ko)" % (os.path.relpath(SORTIE, RACINE), ko))


def _cap_plat(m, anneau, y, coul, G):
    for ia, ib, ic in trianguler(anneau):
        a, b, c = anneau[ia], anneau[ib], anneau[ic]
        m.triangle(G(a[0], a[1], y), G(b[0], b[1], y), G(c[0], c[1], y), coul)


def _sol(m, anneau, terrain, coul, G):
    """Un cap drapé sur le relief, SANS AUCUN MUR — donc impossible à lire
    comme un bâtiment raté. Les seize îlots à hauteur nulle sont des
    surfaces : champs, parc, jardins, et la place du marché."""
    tris, pts = subdiviser(trianguler(anneau), anneau, SUBDIV_SOL)
    ys = [terrain.alt(p[0], p[1]) + Y_SOL for p in pts]
    for ia, ib, ic in tris:
        m.triangle(G(pts[ia][0], pts[ia][1], ys[ia]),
                   G(pts[ib][0], pts[ib][1], ys[ib]),
                   G(pts[ic][0], pts[ic][1], ys[ic]), coul)


def _index_bord(anneau, grille=1.0):
    """Index de grille des arêtes de l'emprise. Sans lui, tester « cette arête
    donne-t-elle sur la rue » serait quadratique — 968 parcelles contre 53
    emprises, ça se sent."""
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


def _masse(m, anneau, d, terrain, coul, G, niveaux=None):
    """Un prisme à deux plans horizontaux, base enterrée.

    `y_haut` réutilise `altitude_relative`, déjà dans la base : le toit est à
    l'altitude que les données annoncent, zéro nouvelle règle. `y_bas` plonge
    sous le point le plus bas du terrain sous l'anneau — en amont le prisme
    est enterré et le terrain l'occlut. Le flottement serait laid, pas
    l'enfouissement : entre les deux erreurs, on choisit celle qui ne se voit
    pas. Aucune jupe, aucune face inférieure : elles ne sont jamais vues.

    `niveaux` permet de donner à CHAQUE parcelle sa propre hauteur, tirée de
    sa graine (35). Sans lui, mille bâtiments arasés au même plan ne valent
    pas mieux qu'un pâté plein.
    """
    if niveaux is None:
        niveaux = d["hauteur"] or 0.0
    y_haut = (d["altitude_relative"] or 0.0) + niveaux * ETAGE_M
    sous = [terrain.alt(p[0], p[1]) for p in anneau]
    y_bas = min(sous) - ENFOUISSEMENT

    def ao(y):
        return AO_MIN + (1.0 - AO_MIN) * min(1.0, max(0.0, (y - y_bas) / AO_HAUTEUR))

    n = len(anneau)
    ok = 0
    for i in range(n):
        a = anneau[i]
        b = anneau[(i + 1) % n]
        pa_b = G(a[0], a[1], y_bas)
        pb_b = G(b[0], b[1], y_bas)
        pa_h = G(a[0], a[1], y_haut)
        pb_h = G(b[0], b[1], y_haut)
        fb, fh = ao(y_bas), ao(y_haut)
        m.triangle(pa_b, pb_b, pb_h, coul, (fb, fb, fh))
        m.triangle(pa_b, pb_h, pa_h, coul, (fb, fh, fh))
        # Contrôle du sens des faces. On ne parie pas sur la chiralité après
        # l'inversion de Z, on la mesure — mais avec le bon test : sur un
        # polygone CONCAVE (43 des 69 le sont), « la normale s'éloigne du
        # centroïde » est faux aux sommets réflexes.
        #
        # Anneau trigonométrique ⇒ l'intérieur est à gauche du parcours, donc
        # la normale extérieure en source vaut (dy, −dx). Le passage en
        # repère Godot envoie un vecteur horizontal (vx, vy) sur (vx, −vy),
        # d'où l'attendu en XZ : (dy, dx).
        dx, dy = b[0] - a[0], b[1] - a[1]
        L = math.hypot(dx, dy)
        nn = normale(pa_b, pb_b, pb_h)
        if L > 1e-9 and (nn[0] * dy + nn[2] * dx) / L > 0.9:
            ok += 1

    haut_ok = 0
    tris = trianguler(anneau)
    for ia, ib, ic in tris:
        a, b, c = anneau[ia], anneau[ib], anneau[ic]
        pa = G(a[0], a[1], y_haut)
        pb = G(b[0], b[1], y_haut)
        pc = G(c[0], c[1], y_haut)
        m.triangle(pa, pb, pc, coul)
        if normale(pa, pb, pc)[1] > 0.0:
            haut_ok += 1
    return ok, n, haut_ok, len(tris)


def _sur_rue(parcelle, idx_bord):
    """Pour chaque arête de la parcelle : donne-t-elle sur la rue ?

    Une parcelle est un morceau de l'emprise ; ses arêtes sont donc soit sur
    le bord de l'emprise (la rue), soit issues d'une coupe et partagées avec
    une voisine. Ce test décide lesquelles reculent et lesquelles restent
    collées — c'est lui qui produit le mitoyen."""
    out = []
    n = len(parcelle)
    for i in range(n):
        a, b = parcelle[i], parcelle[(i + 1) % n]
        mx, my = (a[0] + b[0]) / 2.0, (a[1] + b[1]) / 2.0
        cx, cy = int(mx // 1.0), int(my // 1.0)
        rue = False
        for dx in (-1, 0, 1):
            for dy in (-1, 0, 1):
                for (p, q) in idx_bord.get((cx + dx, cy + dy), ()):
                    if D4C.dist_pt_seg((mx, my), p, q) <= TOL_RUE:
                        rue = True
                        break
                if rue:
                    break
            if rue:
                break
        out.append(rue)
    return out


def _empreinte_batie(parcelle, st, idx_bord):
    """La parcelle devient une empreinte de bâtiment.

    Trois gestes, dans cet ordre, et chacun répond à un des trois nombres de
    `BATI` : on recule de la rue, on s'écarte (ou pas) de la voisine, puis on
    coupe ce qui dépasse en profondeur — le reste est la cour ou le jardin.

    Renvoie [] quand il ne reste rien : une parcelle enclavée, sans aucune
    arête sur rue, n'est pas bâtie. C'est comme ça que les cœurs d'îlot se
    creusent, sans qu'on ait à les dessiner."""
    recul, jeu, prof = BATI.get(st, BATI_DEFAUT)
    rues = _sur_rue(parcelle, idx_bord)
    if not any(rues):
        return []                     # enclavée : cour, jardin, pas de maison

    retraits = [recul if r else jeu for r in rues]
    emp = D4B.retracter(parcelle, retraits)
    # `reparer` retire les boucles que tout offset à distance variable finit
    # par fabriquer sur un angle rentrant. Il renvoie (anneau, réparations,
    # plafond) — seul le premier nous intéresse ici.
    emp = D4B.reparer(emp)[0] if len(emp) >= 3 else []
    if len(emp) < 3 or abs(D4C.aire_signee(emp)) < 6.0:
        return []
    emp = D4C.ouvrir(emp)

    # La coupe en profondeur, depuis la plus longue arête sur rue. Sans elle,
    # deux rangées dos à dos donnent un bloc plein de 32 m et le cœur d'îlot
    # n'existe pas.
    n = len(parcelle)
    meilleur, best_L = None, 0.0
    for i in range(n):
        if not rues[i]:
            continue
        a, b = parcelle[i], parcelle[(i + 1) % n]
        L = math.hypot(b[0] - a[0], b[1] - a[1])
        if L > best_L:
            best_L, meilleur = L, (a, b)
    if meilleur is None:
        return [emp]
    a, b = meilleur
    dx, dy = b[0] - a[0], b[1] - a[1]
    L = math.hypot(dx, dy)
    if L < 1e-9:
        return [emp]
    # Anneau trigonométrique : l'intérieur est à GAUCHE du parcours, donc la
    # normale rentrante vaut (−dy, dx). On garde le côté rue, c'est-à-dire le
    # côté négatif de cette normale.
    nx, ny = -dy / L, dx / L
    p0 = (a[0] + nx * prof, a[1] + ny * prof)
    morceaux = D4C.couper(emp, p0, (-nx, -ny))
    garde = []
    for m in morceaux:
        if len(m) < 3:
            continue
        cx = sum(p[0] for p in m) / len(m)
        cy = sum(p[1] for p in m) / len(m)
        if (cx - p0[0]) * (-nx) + (cy - p0[1]) * (-ny) > -0.01 \
                and abs(D4C.aire_signee(m)) > 6.0:
            garde.append(D4C.ouvrir(m))
    return garde if garde else [emp]


def _ruban(m, a, b, larg, terrain, coul, G):
    """La chaussée, drapée. Prolongée d'une demi-largeur à chaque bout pour
    que les carrefours se remplissent au lieu d'afficher une croix pâle — on
    assume le recouvrement, tout est dans un seul plan et d'une seule couleur,
    donc il est invisible par construction."""
    dx, dy = b[0] - a[0], b[1] - a[1]
    L = math.hypot(dx, dy)
    if L < 1e-9:
        return
    ux, uy = dx / L, dy / L
    px, py = -uy * larg / 2.0, ux * larg / 2.0
    ax, ay = a[0] - ux * larg / 2.0, a[1] - uy * larg / 2.0
    total = L + larg
    n = max(1, int(total / SUBDIV_RUBAN) + 1)
    prev = None
    for k in range(n + 1):
        t = total * k / n
        mx, my = ax + ux * t, ay + uy * t
        g = (mx - px, my - py)
        dt = (mx + px, my + py)
        pg = G(g[0], g[1], terrain.alt(g[0], g[1]) + Y_CHAUSSEE)
        pd = G(dt[0], dt[1], terrain.alt(dt[0], dt[1]) + Y_CHAUSSEE)
        if prev is not None:
            m.triangle(prev[0], prev[1], pd, coul)
            m.triangle(prev[0], pd, pg, coul)
        prev = (pg, pd)


def _semer(anneau, d, terrain, rng):
    """Le semis d'arbres d'un îlot de sol. Densité dérivée de `canopee`,
    graine fixe : le même export donne toujours la même forêt."""
    surf = abs(aire_signee(anneau))
    n = int(round((d["canopee"] or 0.0) * surf / M2_PAR_ARBRE))
    if n <= 0:
        return []
    xs = [p[0] for p in anneau]
    ys = [p[1] for p in anneau]
    ferme = list(anneau) + [anneau[0]]
    out = []
    essais = 0
    while len(out) < n and essais < n * 40:
        essais += 1
        x = rng.uniform(min(xs), max(xs))
        y = rng.uniform(min(ys), max(ys))
        if not dedans(ferme, (x, y)):
            continue
        out.append([x, y, terrain.alt(x, y),
                    rng.uniform(0.75, 1.35), rng.uniform(0.0, 6.2832)])
    return out


def _alignement(d, terrain, rng):
    """TOUS les emplacements d'alignement d'un tronçon — ceux qui existeraient
    si on plantait — chacun avec le **seuil de canopée** à partir duquel il est
    occupé. Sortie : [x, y, alt, échelle, lacet, seuil].

    ⚠ Ce n'est plus ce que faisait cette fonction. Avant, elle ne sortait que
    les arbres de t0 et leur POSITION dépendait de la densité
    (`t = L·(k+0,5)/n`) : faire monter la canopée redistribuait tout, rien ne
    poussait, l'alignement sautait d'un endroit à l'autre. Maintenant les
    positions sont fixes et seul le seuil décide — un arbre planté reste où il
    est, et les suivants se glissent entre.

    Un tronçon n'est plantable que s'il reste au moins 1 m entre la chaussée et
    la limite d'emprise. Les ruelles du cœur ancien ne le sont jamais : l'effet
    est spatialement inégal par construction, et c'est le sujet."""
    larg = d["largeur_m"] or 0.0
    if larg <= 0.0:
        return []
    ch = min(D4.EMPRISE_CIRCULATION.get(d["hierarchie"], 8.5), larg)
    marge = (larg - ch) / 2.0
    if marge < 1.0:
        return []                               # pas la place d'un arbre
    out = []
    for part in d["parts"]:
        for a, b in zip(part, part[1:]):
            dx, dy = b[0] - a[0], b[1] - a[1]
            L = math.hypot(dx, dy)
            if L < 1e-9:
                continue
            ux, uy = dx / L, dy / L
            # Le nombre d'EMPLACEMENTS est la densité maximale — un arbre tous
            # les ESPACEMENT_ALIGNEMENT mètres — et ne dépend d'aucune canopée.
            # C'est le SEUIL, plus bas, qui décide lesquels sont occupés.
            n = int(L / ESPACEMENT_ALIGNEMENT)
            for k in range(n):
                t = L * (k + 0.5) / max(1, n)
                cote = 1.0 if rng.random() < 0.5 else -1.0
                ox = -uy * cote * (ch / 2.0 + marge / 2.0)
                oy = ux * cote * (ch / 2.0 + marge / 2.0)
                x, y = a[0] + ux * t + ox, a[1] + uy * t + oy
                # Seuil uniforme sur [0, CANOPEE_ALIGNEMENT_MAX] : à canopée
                # `c`, la part occupée vaut `c / MAX`. À MAX, tout est planté.
                out.append([x, y, terrain.alt(x, y),
                            rng.uniform(0.8, 1.2), rng.uniform(0.0, 6.2832),
                            rng.uniform(0.0, CANOPEE_ALIGNEMENT_MAX)])
    return out


def _reperes(ilots, routes, cx, cy):
    """Les points de vue du clavier. Une touche par critère de réussite :
    on ne juge pas de mémoire (`Plan 3 mois.md:48`)."""
    def centre(fid):
        a = ilots[fid]["brut"]
        return [round(sum(p[0] for p in a) / len(a) - cx, 2),
                round(-(sum(p[1] for p in a) / len(a) - cy), 2)]

    quai = [d for d in routes if (d["largeur_m"] or 0) >= 20.0]
    qp = [0.0, 0.0]
    if quai:
        pts = [p for d in quai for part in d["parts"] for p in part]
        qp = [round(sum(p[0] for p in pts) / len(pts) - cx, 2),
              round(-(sum(p[1] for p in pts) / len(pts) - cy), 2)]
    return {
        "vallee": {"cible": [0.0, 0.0], "taille": 1200.0,
                   "libelle": "La vallee"},
        "barre": {"cible": centre(32), "taille": 220.0,
                  "libelle": "La barre de 1974 (ilot 32)"},
        "quai": {"cible": qp, "taille": 160.0,
                 "libelle": "Les rues a 20 et 22 m"},
    }


if __name__ == "__main__":
    for flux in (sys.stdout, sys.stderr):
        try:
            flux.reconfigure(encoding="utf-8", errors="replace")
        except (AttributeError, OSError):
            pass
    main()
