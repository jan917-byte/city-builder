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
# 🔄 LA CARTE EST PLATE depuis le 2026-08-12, à la demande de l'auteur. Le sol
# est à 0 partout ; il n'y a plus de champ d'altitude, plus de vallée, plus
# d'exagération verticale. Le seul relief de Wehrau est le CHENAL de l'Ilse.
#
# Ce que ça a retiré, et qu'il faut savoir pour le remettre : une classe
# `Terrain` qui rejouait la règle de pente de `04` (3,2 % en amont, 1,3 % en
# aval, plafond à 9 m) et l'échantillonnait sur une grille de 4 m. 9 m de
# relief sur 898 m de large ne se lisaient à AUCUNE des quatre exagérations —
# la vallée coûtait un champ d'altitude et ne se voyait pas.
#
# La grille ne sert donc plus qu'à découper une plaque plate : elle peut être
# grossière. Les mailles que la berge traverse sont, elles, coupées à l'exact.
PAS_TERRAIN = 16.0         # maille de la plaque de sol
MARGE_TERRAIN = 24.0       # déborde l'emprise, sinon falaise au bord
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

# 🌊 L'ILSE EST UN CHENAL, pas une flaque. La carte étant plate, c'est le seul
# accident du terrain — et il est franc : deux murs VERTICAUX et un fond plat.
#
#     sol ─────┐              ┌───── sol            0,00 m
#              │██████████████│                    −1,00 m  le plan d'eau
#              └──────────────┘                    −2,00 m  le fond
#
# Ce que ça change par rapport à la berge en pente de la veille : on voit un
# mètre de mur au-dessus de l'eau, sur toute la longueur. Une berge qui remonte
# en pente douce sur 12 m se lisait comme un talus, donc comme rien.
FOND_ILSE = -2.0           # le fond du chenal
NAPPE_ILSE = -1.0          # le plan d'eau
# ⚠️ La VOIRIE reste à 0, comme tout le reste : les trois franchissements
# passent donc au-dessus du chenal sans qu'aucune ligne de code ne parle de
# pont. C'est le creusement qui fabrique le pont, pas un tablier dessiné.

# ⏸️ `altitude_relative` et `alea` ne sont plus exportés : la carte est plate et
# la crue sort du prototype (2026-08-12). Les colonnes existent toujours dans le
# GeoPackage, à 0 — les remettre ici est une ligne. `position_fil_eau` et
# `rive`, eux, restent : ce sont des positions le long de l'eau, pas des
# risques, et c'est `position_fil_eau` qui porte la portée « aval ».
COLS_ILOTS = [
    "fid", "fonction", "sous_type", "surface_m2", "hauteur", "impermeabilise",
    "canopee", "stationnement",
    "position_fil_eau", "rive", "densite", "logements", "emplois", "riverain",
    "desserte_tc",
]
COLS_ROUTES = ["fid", "hierarchie", "largeur_m", "emprise_libre_m", "charge",
               "canopee", "stationnement"]

# Ce qui part dans `objets` : la fiche qu'on lit en cliquant, et l'état de
# départ du noyau. Tout ce qui n'est pas là ne peut ni s'afficher ni évoluer.
FICHE_ILOTS = [c for c in COLS_ILOTS if c != "fid"]
# 🔗 L'interface du toit (41 · 64), calculée et non lue dans le `.gpkg` :
# surface réelle, pente, et le drapeau « toit plat ». L'ombrage, lui, est déjà
# là — c'est `canopee`.
TOIT_ILOTS = ["toit_m2", "toit_pente", "toit_plat"]
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
#   profondeur  🔴 LA PROFONDEUR DU BÂTIMENT, mesurée DEPUIS SA FAÇADE — pas
#               depuis la rue. Le 2026-08-12 elle était comptée depuis la rue,
#               donc le recul était pris SUR la maison : avec 5,5 m de recul et
#               10 m de profondeur, le pavillon faisait 3,5 m de creux. Toute
#               une rangée de cloisons debout, et le nombre de la table ne
#               décrivait rien qu'on puisse regarder. Au-delà de cette
#               profondeur, ce n'est plus la maison, c'est la cour ou le
#               jardin — c'est ce nombre qui creuse les cœurs d'îlot.
#   pente       du toit, en montée par mètre d'avancée. 0 = TOIT PLAT.
#               Le faîtage court PARALLÈLEMENT À LA RUE, jamais selon l'axe
#               long de l'empreinte : sur une maison de ville plus profonde
#               que large, l'axe long est perpendiculaire à la rue et le toit
#               partirait de travers.
#
# ⚠️ PROPOSITION, à corriger devant l'image. Le contrôle n'est pas « est-ce que
# le nombre est juste » mais « est-ce qu'on croirait y habiter ».
BATI = {
    #  sous_type              recul   jeu  profondeur  pente
    "coeur_ancien":            (0.0,  0.0,   11.0,     1.00),  # sur rue, mitoyen, cour derrière
    "maisons_de_ville":        (1.5,  0.0,   10.0,     0.85),  # mitoyen, petit jardin
    "front_commercant":        (0.0,  0.0,   13.0,     0.70),  # sur rue, vitrines
    "pavillonnaire":           (5.5,  2.5,   10.0,     0.60),  # détaché, jardin derrière
    "barre_1970":              (6.0,  5.0,   13.0,     0.00),  # toit plat, 1974
    "equipement":              (4.0,  3.0,   22.0,     0.25),
    "dalle_commerciale":       (2.0,  2.0,   53.0,     0.00),  # un hangar
    "friche_industrielle":     (3.0,  2.5,   35.0,     0.00),  # des halles
}
BATI_DEFAUT = (2.0, 1.0, 12.0, 0.50)

# 📦 LES VOLUMES QUI SE SIMPLIFIENT EN RECTANGLE, alignés sur la rue.
# Une barre, un hangar, une halle : ce sont des boîtes. Les faire suivre le
# découpage parcellaire leur donnait des biais et des pointes qu'aucun béton
# des années 1970 n'a jamais eus. On garde l'emprise au sol — le rectangle est
# celui de la parcelle bâtie, pas une taille inventée.
RECTANGULAIRE = {"barre_1970", "dalle_commerciale", "friche_industrielle"}

# ✂️ LES POINTES. Un angle rentrant du parcellaire donne des empreintes en lame
# de couteau : un coin à 20° est un mur de trois centimètres d'épaisseur vu de
# face, et ça n'existe dans aucune ville. On COUPE la pointe — `\_/` au lieu de
# `\/`. Le pan coupé est franc et court, il se lit comme un pan coupé d'angle.
#
# 🔴 CE QUI A RATÉ AU PREMIER ESSAI, et qui vaut d'être gardé : couper 2,5 m sur
# chaque côté d'une pointe à 15° laisse un mur de 65 cm — c'est encore une lame,
# juste une lame tronquée. Ce qu'on vise n'est pas une longueur de coupe, c'est
# la LARGEUR DU MUR QUI RESTE. On coupe donc aussi loin qu'il le faut pour que
# le pan coupé fasse `PAN_COUPE_M`, borné par la longueur des côtés voisins.
ANGLE_MIN_DEG = 70.0       # en dessous, le sommet est remplacé par une arête
PAN_COUPE_M = 4.5          # largeur visée du mur qui remplace la pointe
PART_COTE_MAX = 0.45       # jamais plus que ça de chaque côté adjacent

# 🔪 ET LES EMPREINTES QUI SONT UNE POINTE DE BOUT EN BOUT. Couper un sommet ne
# sauve pas un bâtiment qui est un coin de 40 m de long et 2 m de large : il
# reste une lame posée à plat. En dessous de cette largeur, le volume n'est pas
# construit du tout — la parcelle repart au jardin, ce qui est la seule chose
# honnête à en faire.
LARGEUR_MIN_BATI = 3.0

# 🌳 LA VERDURE DES CŒURS D'ÎLOT — part des espaces libres qui sont plantés.
# « pas tous » est le sujet : une cour de cœur ancien est pavée, un jardin de
# pavillonnaire est vert. C'est ce contraste qui fait lire le tissu d'en haut,
# pas la couleur des façades.
VERDURE = {
    "coeur_ancien":          0.30,   # des cours, surtout minérales
    "front_commercant":      0.20,   # arrière-cours de livraison
    "maisons_de_ville":      0.65,   # petits jardins de ville
    "pavillonnaire":         0.92,   # le jardin EST le tissu
    "barre_1970":            0.75,   # l'espace vert de dalle, hérité de 1974
    "equipement":            0.45,   # cour de récréation ou pelouse
    "dalle_commerciale":     0.05,   # un parking, pas un jardin
    "friche_industrielle":   0.20,   # des friches, pas des prés
}
VERDURE_DEFAUT = 0.40
AIRE_JARDIN_MIN = 12.0     # en dessous, c'est un délaissé, pas un jardin
M2_PAR_ARBRE_JARDIN = 120.0
PART_JARDINS_ARBORES = 0.55   # parmi les jardins verts, ceux qui ont un arbre

# Un faîtage ne monte jamais plus haut que ça, quelle que soit la pente. Sans
# ce plafond, une empreinte profonde se coiffe d'un chapeau de dix mètres qui
# écrase tout le reste.
FAITAGE_MAX = 5.5

# 🔄 IL Y AVAIT ICI UNE RÈGLE DE REPLI — « quand l'empreinte ne sait pas porter
# un toit propre, toit plat » — et elle a été RETIRÉE le 2026-08-12, le jour
# même, après l'avoir regardée à l'écran : l'auteur a préféré l'image d'avant.
#
# Ce qu'elle faisait, pour qui voudrait la refaire (elle est dans git, commit
# « Toit plat quand l'empreinte ne sait pas porter deux pentes ») : elle
# mesurait le PLI d'un pan de toit — l'écart entre les deux diagonales du
# quadrilatère, nul dès que le pan est plan — et posait un toit plat au-delà
# d'un seuil. À 0,35 m, 381 bâtiments sur 702 basculaient au toit plat ; la
# médiane du pli était de 55 cm, le 9e décile de 1,89 m, le pire de 2,59 m.
# La distribution est CONTINUE, sans décrochement : il n'y avait pas de seuil
# à trouver, seulement un curseur entre une ville qui a des toits et une ville
# dont les toits sont propres. L'auteur a choisi la première.
#
# Deux choses valent d'être gardées de cet essai :
#   · la bonne mesure du pli est l'écart entre les DEUX DIAGONALES. « La
#     distance du 4e sommet au plan des trois autres » est fausse : sur un
#     pignon, les deux sommets du faîtage se confondent presque, le plan de
#     base est une lame, et 574 bâtiments sur 702 se déclaraient vrillés ;
#   · le critère « angle trop aigu » ne se déclenchait JAMAIS. `_ecorner` coupe
#     déjà tout ce qui passe sous 70°, et le plus petit angle de la ville est
#     70,2°. Le problème des pointes était réglé en amont.

# Combien de pans de toit ont dû être retournés à l'émission. Ce n'est pas une
# erreur — c'est la mesure de à quel point la recette du faîtage doit être
# corrigée après coup. Si ce nombre s'envole, c'est la recette qu'il faut
# revoir, pas le compteur.
retournes = [0]

# Les deux autres compteurs de la même famille : ce que la simplification des
# empreintes a effectivement changé, à imprimer plutôt qu'à supposer.
pointes = [0, 0]        # [sommets coupés, empreintes touchées]
rectangles = [0]        # volumes ramenés à une boîte
minces = [0]            # empreintes trop fines, rendues au jardin

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


# ================================================================== le chenal

class Chenal(object):
    """L'Ilse creusée dans une carte plate — et la plaque de sol qu'elle troue.

    Il n'y a plus de champ d'altitude : le sol est à 0 partout, et le seul
    relief est ce chenal à murs verticaux. Cette classe ne sait donc faire que
    deux choses, et c'est le but :
      · dire quelles ARÊTES sont des berges (les autres sont les coupures entre
        deux îlots de rivière, au milieu de l'eau — il ne faut pas y bâtir un
        mur) ;
      · DÉCOUPER la plaque de sol le long de ces berges, à l'exact.

    ⚠️ Le découpage, et c'est le seul endroit un peu retors : une maille que la
    berge traverse est coupée par la DROITE de chaque arête de berge qui la
    traverse, puis on ne garde que les morceaux dont le centre est hors de
    l'eau. La coupe ne fait que subdiviser — c'est le test d'appartenance qui
    décide, jamais la droite. Une droite qui mord trop loin ne peut donc pas
    manger du sol : le morceau qu'elle détache est simplement gardé.
    """

    def __init__(self, anneaux_riviere):
        self.rivieres = [list(a) + [a[0]] for a in anneaux_riviere]
        # Les arêtes qui apparaissent DEUX FOIS sont des limites entre deux
        # îlots de rivière : elles traversent l'eau, elles ne sont pas des
        # berges. Six îlots d'eau bout à bout en produisent cinq.
        compte = {}
        brut = []
        for a in anneaux_riviere:
            for i in range(len(a)):
                p, q = a[i], a[(i + 1) % len(a)]
                if math.hypot(q[0] - p[0], q[1] - p[1]) < 1e-9:
                    continue
                cle = tuple(sorted((_cle(p), _cle(q))))
                compte[cle] = compte.get(cle, 0) + 1
                brut.append((p, q, cle))
        self.cles_berges = {c for c, k in compte.items() if k == 1}
        self.berges = [(p, q) for p, q, c in brut if compte[c] == 1]
        self.internes = len(brut) - len(self.berges)
        # Index par maille : sans lui, chaque maille de la plaque teste les
        # ~200 arêtes de berge une par une.
        self.pas = 40.0
        self.idx = {}
        for k, (p, q) in enumerate(self.berges):
            for cx in range(int(min(p[0], q[0]) // self.pas),
                            int(max(p[0], q[0]) // self.pas) + 1):
                for cy in range(int(min(p[1], q[1]) // self.pas),
                                int(max(p[1], q[1]) // self.pas) + 1):
                    self.idx.setdefault((cx, cy), []).append(k)

    def dans_eau(self, p):
        return any(dedans(r, p) for r in self.rivieres)

    def est_berge(self, a, b):
        return tuple(sorted((_cle(a), _cle(b)))) in self.cles_berges

    def berges_autour(self, x0, y0, x1, y1):
        """Les arêtes de berge qui peuvent traverser la maille."""
        vus = set()
        for cx in range(int(x0 // self.pas), int(x1 // self.pas) + 1):
            for cy in range(int(y0 // self.pas), int(y1 // self.pas) + 1):
                vus.update(self.idx.get((cx, cy), ()))
        return [self.berges[k] for k in vus]

    def plaque(self, x0, y0, x1, y1, pas):
        """Le sol : des morceaux plats à 0, troués là où passe le chenal."""
        out = []
        approx = 0
        nx = int(math.ceil((x1 - x0) / pas))
        ny = int(math.ceil((y1 - y0) / pas))
        for j in range(ny):
            for i in range(nx):
                ax, ay = x0 + i * pas, y0 + j * pas
                bx, by = min(ax + pas, x1), min(ay + pas, y1)
                maille = [(ax, ay), (bx, ay), (bx, by), (ax, by)]
                proches = [s for s in self.berges_autour(ax, ay, bx, by)
                           if _coupe_boite(s, ax, ay, bx, by)]
                if not proches:
                    if not self.dans_eau(((ax + bx) / 2.0, (ay + by) / 2.0)):
                        out.append(maille)
                    continue
                if len(proches) > 1:
                    approx += 1
                morceaux = [maille]
                for (p, q) in proches:
                    nrm = (q[1] - p[1], -(q[0] - p[0]))
                    suite = []
                    for mo in morceaux:
                        suite.extend(D4C.couper(mo, p, nrm))
                    morceaux = suite
                for mo in morceaux:
                    if len(mo) < 3:
                        continue
                    c = (sum(p[0] for p in mo) / len(mo),
                         sum(p[1] for p in mo) / len(mo))
                    if not self.dans_eau(c):
                        out.append(mo)
        return out, approx


def _cle(p):
    return (round(p[0], 4), round(p[1], 4))


def _coupe_boite(seg, x0, y0, x1, y1):
    """L'arête passe-t-elle dans la maille ? Test de boîtes, volontairement
    large : une arête gardée pour rien ne coûte qu'une coupe sans effet."""
    (px, py), (qx, qy) = seg
    return not (max(px, qx) < x0 or min(px, qx) > x1
                or max(py, qy) < y0 or min(py, qy) > y1)


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
        # 🚶 `origine` dit ce qu'est la parcelle. Une seule valeur intéresse ce
        # fichier : `chemin` — la venelle que 04c a retirée de l'emprise. Elle
        # ne se bâtit pas, elle se pave. Sans cette colonne on lui poserait une
        # maison de 3 m de large en travers de l'îlot.
        col_org = "origine" if "origine" in {
            r[1] for r in con.execute("PRAGMA table_info(parcelles)")} else "NULL"
        for fid_i, niv, org, geom in con.execute(
            "SELECT fid_ilot, niveaux, %s, geom FROM parcelles ORDER BY fid"
            % col_org
        ):
            if fid_i in ilots:
                ilots[fid_i]["parcelles"].append(
                    {"anneau": anneau_ouvert(geom), "niveaux": niv or 0.0,
                     "origine": org})

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

    chenal = Chenal([d["brut"] for d in ilots.values()
                     if d["sous_type"] == "riviere"])
    print("  chenal : %d arêtes de berge (%d arêtes internes à l'eau écartées)"
          % (len(chenal.berges), chenal.internes))

    # ------------------------------------------------------ la plaque de sol
    # La carte est PLATE : le sol est un plan à 0, troué par le chenal. Plus de
    # champ d'altitude, plus de vallée, plus d'exagération verticale.
    terre = Maillage()
    coul_terre = PAL.vers_lineaire(PAL.MINERAL_CLAIR)
    x0 = minx - MARGE_TERRAIN
    y0 = miny - MARGE_TERRAIN
    x1 = maxx + MARGE_TERRAIN
    y1 = maxy + MARGE_TERRAIN
    morceaux, approx = chenal.plaque(x0, y0, x1, y1, PAS_TERRAIN)
    for mo in morceaux:
        _cap_plat(terre, mo, Y_TERRAIN, coul_terre, G)
    print("  sol : plan à 0,00 m — %d morceaux de plaque au pas de %.0f m"
          % (len(morceaux), PAS_TERRAIN))
    if approx:
        print("        dont %d mailles coupées par plusieurs arêtes de berge"
              % approx)

    # ------------------------------------------------------------ les îlots
    masses, sols, eau = Maillage(), Maillage(), Maillage()
    rng = random.Random(GRAINE)
    arbres = []
    n_masse = n_sol = n_eau = 0
    n_parc = n_vol = n_pate = 0
    n_pentu = n_plat_force = 0
    n_deborde = 0
    deb_max = 0.0
    toit_total = 0.0
    canopee_perdue = 0.0
    murs_ok = murs_tot = toits_ok = toits_tot = 0
    quais_ok = quais_tot = 0
    # Le mur de quai : le minéral de la ville, un peu assombri — un quai est à
    # l'ombre de sa propre berge une bonne partie de la journée.
    coul_quai = tuple(c * 0.86 for c in PAL.vers_lineaire(PAL.MINERAL_CLAIR))
    n_jardin = n_vert = n_arbre_jardin = 0
    aire_jardin = aire_verte = 0.0
    # Un vert de jardin, légèrement assombri : un cœur d'îlot est en partie à
    # l'ombre des volumes qui l'entourent, et rien ici ne calcule d'ombre
    # portée sur le sol.
    coul_jardin = PAL.vers_lineaire(PAL.couleur_sol("jardins_familiaux", 0.10))
    coul_jardin = tuple(c * 0.92 for c in coul_jardin)
    # 🚶 Le pavé de la venelle : le minéral CLAIR, celui du sol nu, et non le
    # minéral de la chaussée. Vue d'en haut, la différence dit tout ce qu'il y
    # a à dire — on passe du noir de l'asphalte au gris du pavé, donc d'une rue
    # à un passage. Assombri d'un cheveu : une venelle de 3 m entre deux murs
    # ne voit pas beaucoup de ciel.
    coul_chemin = tuple(c * 0.94 for c in PAL.vers_lineaire(PAL.MINERAL_CLAIR))
    n_chemin = 0
    aire_chemin = 0.0

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
            # 🌊 Sur l'anneau BRUT, pas sur l'emprise : l'emprise est retirée
            # de la voirie, et le chenal doit tomber exactement sur la limite
            # de l'îlot d'eau, sinon un liseré de sol flotte au-dessus du vide.
            a, b = _chenal_eau(eau, terre, d["brut"], chenal, coul, coul_quai, G)
            quais_ok += a
            quais_tot += b
            continue

        if haut > 0.0:
            n_masse += 1
            masses.marque(fid)
            # ⚠️ TOUTES les parcelles d'un îlot tombent dans LE MÊME groupe.
            # C'est ce qui permet d'avoir mille bâtiments sans passer de 237 à
            # 1 200 nœuds cliquables : la géométrie descend à la parcelle, la
            # SÉLECTION reste à l'îlot — et la décision aussi. La parcelle est
            # l'entité persistante des données (35), pas celle du clic.
            pente = BATI.get(st, BATI_DEFAUT)[3]
            toit_ilot = 0.0
            volumes = []
            jardins = []
            # 🚶 LA VENELLE NE SE BÂTIT PAS, ET ELLE EST UNE ADRESSE. Deux
            # choses en découlent, et il faut les deux : elle sort de la liste
            # des parcelles à bâtir — ses deux bouts touchent le bord de
            # l'îlot, donc elle a une façade et `_empreinte_batie` y poserait
            # une lame de bâtiment de 3 m en travers — et ses parois entrent
            # dans l'index du bord, sinon toute la rangée qui donne dessus
            # sortirait enclavée.
            chemins_ilot = [p["anneau"] for p in d["parcelles"]
                            if p.get("origine") == "chemin"]
            if d["parcelles"]:
                idx = _index_bord([an] + chemins_ilot)
                for p in d["parcelles"]:
                    if p.get("origine") == "chemin":
                        continue
                    vols, jard = _empreinte_batie(p["anneau"], st, idx)
                    for emp, faite in vols:
                        volumes.append((emp, p["niveaux"], faite))
                    jardins.extend(jard)
                n_parc += len(d["parcelles"]) - len(chemins_ilot)
                n_vol += len(volumes)
                n_chemin += len(chemins_ilot)
            if not volumes:
                volumes = [(an, haut, None)]   # repli : le pâté plein d'avant
                n_pate += 1
                pente = 0.0
            for emp, niv, faite in volumes:
                # ⚠️ TOIT À DEUX PENTES SUR EMPREINTE CONVEXE SEULEMENT, et
                # c'est une limite du procédé, pas une préférence. Sur une
                # empreinte concave, une arête d'égout peut repartir en arrière
                # dans un renfoncement et le versant qu'elle porte se retourne.
                pente_v = 0.0
                if pente > 0.0:
                    if faite is not None and _convexe(emp):
                        pente_v = pente
                        n_pentu += 1
                    else:
                        n_plat_force += 1
                # La surface de toit se compte VOLUME PAR VOLUME, avec la pente
                # de ce volume-là : un toit plat ne porte pas les 1,4 m² de
                # couverture par m² d'emprise d'un toit à 45°. C'est ce nombre
                # que l'énergie viendra lire (41 · 64).
                toit_ilot += abs(D4C.aire_signee(emp)) * math.hypot(1.0, pente_v)
                # ⚠️ Les chemins sont ÉCARTÉS de ce contrôle : un bâtiment qui
                # mord sur la venelle est exactement le défaut qu'on cherche à
                # voir, et le compter « dans une parcelle » le masquerait.
                deb = _debordement(emp, [p for p in d["parcelles"]
                                         if p.get("origine") != "chemin"])
                if deb > 0.5:
                    n_deborde += 1
                    deb_max = max(deb_max, deb)
                a, b, c, e = _masse(masses, emp, d, coul, G, niv,
                                    pente_v, faite)
                murs_ok += a
                murs_tot += b
                toits_ok += c
                toits_tot += e

            # 🌳 LES CŒURS D'ÎLOT. Les fonds de parcelle étaient calculés puis
            # jetés : le cœur d'un pâté ressortait en terrain nu, donc gris.
            # Ils sont maintenant DESSINÉS — mais pas tous verts, et c'est le
            # sujet. Une cour de cœur ancien est pavée, un jardin de
            # pavillonnaire est planté ; ce contraste-là fait lire le tissu vu
            # d'en haut mieux que la couleur des façades.
            #
            # Ils partent dans le maillage des MASSES, dans le groupe de
            # l'îlot : le cœur d'îlot appartient à l'îlot, donc il se clique
            # avec lui et se teinte avec lui quand un calque s'allume.
            # 🚶 LA VENELLE, AU SOL. Elle passe dans le maillage des MASSES,
            # donc dans le groupe de son îlot : elle appartient à l'îlot, elle
            # se clique avec lui et se teinte avec lui quand un calque
            # s'allume. C'est la traduction en 3D de la seule chose qui compte
            # ici — le chemin n'a pas fabriqué une deuxième décision.
            # Elle est PAVÉE et jamais plantée : un tirage cour/jardin lui
            # mettrait des arbres au milieu d'un passage.
            for c in chemins_ilot:
                if len(c) >= 3:
                    aire_chemin += abs(D4C.aire_signee(c))
                    _sol(masses, c, coul_chemin, G)

            part_verte = VERDURE.get(st, VERDURE_DEFAUT)
            for j in jardins:
                aire_j = abs(D4C.aire_signee(j))
                if aire_j < AIRE_JARDIN_MIN or len(j) < 3:
                    continue
                n_jardin += 1
                aire_jardin += aire_j
                if random.Random(_graine_lieu(j)).random() > part_verte:
                    continue                  # une cour, pas un jardin
                n_vert += 1
                aire_verte += aire_j
                _sol(masses, j, coul_jardin, G)
                arbres_jardin = _semer_jardin(j, aire_j)
                arbres.extend(arbres_jardin)
                n_arbre_jardin += len(arbres_jardin)

            # 🔗 L'INTERFACE DU TOIT — décisions 41 et 64.
            # Un objet bâti expose quatre nombres : surface de toit, pente,
            # orientation, ombrage. Aujourd'hui c'est le générateur de
            # parcelles qui les produit ; avant lui, une table de coefficients
            # par `sous_type` en tenait lieu. 🔴 Le code d'énergie ne doit
            # jamais savoir lequel des deux parle — c'est ce qui fait que
            # l'énergie n'attend pas la 3D (64b).
            #   `toit_m2` est la surface RÉELLE, pente comprise : un toit à
            #   45° porte 1,41 fois l'emprise qu'il couvre, et c'est cette
            #   surface-là qu'on couvrirait de panneaux. Elle est sommée
            #   VOLUME PAR VOLUME : un bâtiment tombé au toit plat compte pour
            #   son emprise, pas pour l'emprise étirée du tissu.
            d["toit_m2"] = round(toit_ilot, 1)
            d["toit_pente"] = round(pente, 2)
            d["toit_plat"] = 1 if pente <= 0.0 else 0
            toit_total += toit_ilot
            # La canopée d'un îlot bâti n'est pas représentable dans une
            # maquette de masses : le pâté est plein, il n'y a pas de sol
            # visible dessous. On la compte pour le dire, pas pour la cacher.
            canopee_perdue += (d["canopee"] or 0.0) * (d["surface_m2"] or 0.0)
        else:
            n_sol += 1
            sols.marque(fid)
            _sol(sols, an, coul, G)
            arbres.extend(_semer(an, d, rng))

    print("  masses %d · sols %d · eau %d" % (n_masse, n_sol, n_eau))
    if n_parc:
        print("  parcelles %d → %d volumes bâtis  (%d enclavées : cour ou jardin)"
              % (n_parc, n_vol, n_parc - n_vol))
        if n_chemin:
            print("  chemins %d → %.0f m² de venelle pavée, dans le groupe de"
                  " leur îlot" % (n_chemin, aire_chemin))
        # 🔗 Ce que l'énergie viendra lire. À imprimer maintenant, parce que
        # c'est le seul moment où on peut encore dire « ce chiffre est faux »
        # avant qu'une décision de jeu s'appuie dessus.
        print("  toits : %.1f ha de surface réelle (pente comprise)"
              % (toit_total / 1e4))
        print("        %d à deux pentes · %d plats par dessin (le tissu les"
              " veut plats) · %d plats faute d'empreinte convexe"
              % (n_pentu, n_vol - n_pentu - n_plat_force, n_plat_force))
        if n_deborde:
            print("        ⚠️  %d bâtiments sur %d débordent de leur parcelle,"
                  " jusqu'à %.1f m" % (n_deborde, n_vol, deb_max))
            print("           pic de mitre sur angle rentrant — borné par le recul"
                  " du tissu, à reprendre")
        plats = [f for f, x in ilots.items() if x.get("toit_plat")]
        print("        dont %d îlots à toit plat — barre, dalle, friches"
              % len(plats))
        # 📦 Les boîtes et ✂️ les pointes coupées. Deux chiffres à regarder :
        # si les rectangles font monter le débordement ci-dessus, c'est que la
        # boîte sort de la parcelle et il faut la rentrer.
        print("  simplification : %d volumes ramenés à un rectangle (barre,"
              " dalle, friche)" % rectangles[0])
        print("        %d pointes coupées sur %d empreintes — `\\_/` au lieu de"
              " `\\/`, sous %.0f°" % (pointes[0], pointes[1], ANGLE_MIN_DEG))
        # 🌳 Les cœurs d'îlot. « pas tous » est le chiffre qui compte : à 100 %
        # de vert, le contraste entre une cour pavée et un jardin disparaît.
        print("  cœurs d'îlot : %d espaces libres (%.1f ha), dont %d plantés"
              " (%.0f %%, %.1f ha) et %d arbres"
              % (n_jardin, aire_jardin / 1e4, n_vert,
                 100.0 * n_vert / max(n_jardin, 1), aire_verte / 1e4,
                 n_arbre_jardin))
    if n_pate:
        print("  ⚠️  %d îlots ressortent en pâté plein — pas de parcelle, ou"
              " aucune n'a produit de volume" % n_pate)
    print("  chenal : %d murs de quai, tous tournés vers l'eau  %s"
          % (quais_tot, "✅" if quais_ok == quais_tot
             else "❌ %d à l'envers" % (quais_tot - quais_ok)))
    print("  triangles : plaque %d, masses %d, sols %d, eau %d"
          % (len(terre), len(masses), len(sols), len(eau)))
    print("  sens des faces : murs vers l'extérieur %d/%d · toits dehors %d/%d"
          % (murs_ok, murs_tot, toits_ok, toits_tot))
    # ⚠️ Les deux colonnes ne se lisent PAS de la même façon, et il faut le
    # savoir pour ne pas se rassurer à bon compte. Pour les MURS, le sens vient
    # du parcours de l'anneau : le contrôle est réel, et 3 005 sur 3 005 veut
    # dire quelque chose. Pour les TOITS, l'orientation est calculée à
    # l'émission, donc la colonne est vraie par construction et ne prouve rien.
    # Le chiffre qui informe est celui-ci : combien de pans ont dû être
    # retournés. S'il s'envole, c'est la recette du faîtage qu'il faut revoir.
    if retournes[0]:
        print("        %d pans de toit réorientés à l'émission (%.0f %% des toits)"
              % (retournes[0], 100.0 * retournes[0] / max(toits_tot, 1)))
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
                _ruban(voirie, a, b, ch, coul_ch, G)
                n_seg += 1
        emplacements = _alignement(d, rng)
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
        # 🔄 C'ÉTAIT UN CHAMP D'ALTITUDE (`x0, z0, pas, nx, nz, alt`) que Godot
        # dépliait en grille. La carte étant plate, c'est un maillage comme les
        # autres : Godot n'a plus qu'UNE façon de lire de la géométrie.
        "terrain": terre.json(),
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
            "ilots": {str(f): dict({c: d[c] for c in FICHE_ILOTS},
                                   **{c: d[c] for c in TOIT_ILOTS if c in d})
                      for f, d in ilots.items()},
            "routes": {str(d["fid"]): {c: d[c] for c in FICHE_ROUTES}
                       for d in routes},
        },
        "riverains": {str(f): sorted(v) for f, v in r2i.items()},
        "reperes": _reperes(ilots, routes, cx, cy),
        "controles": {
            "ilots": len(ilots), "routes": len(routes),
            "masses": n_masse, "sols": n_sol, "eau": n_eau,
            "triangles": (len(terre) + len(masses) + len(sols) + len(eau)
                          + len(voirie)),
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


def _chenal_eau(m_eau, m_dur, anneau, chenal, coul_eau, coul_mur, G):
    """Un îlot d'eau : le fond du chenal, la nappe, et les murs de berge.

    ⚠️ Deux maillages, et ce n'est pas un détail : la NAPPE part dans le
    maillage d'eau, qui a un matériau lisse et une couleur unique ; le FOND et
    les MURS partent avec le sol, dont le matériau lit la couleur des sommets.
    Mis dans l'eau, un mur de quai serait bleu et brillant.

    Les murs ne sont posés que sur les arêtes qui SÉPARENT l'eau de la ville.
    Six îlots d'eau bout à bout partagent cinq arêtes en travers du courant :
    y bâtir un mur mettrait cinq barrages dans la rivière.

    Renvoie (murs émis, murs qui regardent bien vers l'eau) — un mur de quai
    tourné vers la ville serait invisible, et ça ne se devine pas."""
    m = m_dur
    _cap_plat(m_dur, anneau, FOND_ILSE, coul_mur, G)      # le fond
    _cap_plat(m_eau, anneau, NAPPE_ILSE, coul_eau, G)     # la nappe

    ok = tot = 0
    n = len(anneau)
    for i in range(n):
        a, b = anneau[i], anneau[(i + 1) % n]
        if not chenal.est_berge(a, b):
            continue
        # Le mur regarde l'EAU, pas la ville : on parcourt l'arête à l'envers
        # de ce que fait un mur de bâtiment, ce qui retourne la face.
        pa_h, pb_h = G(a[0], a[1], Y_TERRAIN), G(b[0], b[1], Y_TERRAIN)
        pa_b, pb_b = G(a[0], a[1], FOND_ILSE), G(b[0], b[1], FOND_ILSE)
        m.triangle(pb_b, pa_b, pa_h, coul_mur)
        m.triangle(pb_b, pa_h, pb_h, coul_mur)
        tot += 1
        dx, dy = b[0] - a[0], b[1] - a[1]
        L = math.hypot(dx, dy)
        nn = normale(pb_b, pa_b, pa_h)
        if L > 1e-9 and (nn[0] * dy + nn[2] * dx) / L < -0.9:
            ok += 1
    return ok, tot


def _sol(m, anneau, coul, G):
    """Un cap posé sur la plaque, SANS AUCUN MUR — donc impossible à lire
    comme un bâtiment raté. Les seize îlots à hauteur nulle sont des
    surfaces : champs, parc, jardins, et la place du marché.

    🔄 Il était SUBDIVISÉ pour suivre le relief. La carte étant plate, la
    subdivision ne servirait plus qu'à multiplier les triangles."""
    for ia, ib, ic in trianguler(anneau):
        a, b, c = anneau[ia], anneau[ib], anneau[ic]
        m.triangle(G(a[0], a[1], Y_SOL), G(b[0], b[1], Y_SOL),
                   G(c[0], c[1], Y_SOL), coul)


def _index_bord(anneaux, grille=1.0):
    """Index de grille des arêtes devant lesquelles une parcelle est « sur
    rue ». Sans lui, tester « cette arête donne-t-elle sur la rue » serait
    quadratique — 968 parcelles contre 53 emprises, ça se sent.

    🚶 Prend une LISTE d'anneaux depuis le 2026-08-14, et c'est ce qui fait
    tenir le chemin de bout en bout. Le bord de l'emprise ne suffit plus :
    les deux parois de la venelle sont aussi une adresse. `04c` le sait déjà
    — il peigne chaque morceau d'emprise pour son compte, donc pour lui la
    paroi EST du bord. Si `07` ne l'apprend pas, toutes les parcelles qui
    donnent sur la venelle sortent enclavées et repartent au jardin : mesuré
    avant correction, 879 volumes bâtis sans chemin contre 855 avec, alors
    que la découpe en annonçait soixante de plus."""
    idx = {}
    for anneau in anneaux:
        n = len(anneau)
        for i in range(n):
            a, b = anneau[i], anneau[(i + 1) % n]
            x0 = int(min(a[0], b[0]) // grille)
            x1 = int(max(a[0], b[0]) // grille)
            y0 = int(min(a[1], b[1]) // grille)
            y1 = int(max(a[1], b[1]) // grille)
            for cx in range(x0, x1 + 1):
                for cy in range(y0, y1 + 1):
                    idx.setdefault((cx, cy), []).append((a, b))
    return idx


def _masse(m, anneau, d, coul, G, niveaux=None, pente=0.0, faitage=None):
    """Un prisme à deux plans horizontaux, base enterrée.

    🔄 `y_haut` ajoutait `altitude_relative` — le bâtiment se posait sur le
    relief que les données annonçaient. La carte est plate depuis le
    2026-08-12 : tout part de 0, et un bâtiment ne fait plus que sa hauteur.
    `y_bas` plonge sous le sol pour qu'aucun volume ne flotte. Aucune jupe,
    aucune face inférieure : elles ne sont jamais vues.

    `niveaux` permet de donner à CHAQUE parcelle sa propre hauteur, tirée de
    sa graine (35). Sans lui, mille bâtiments arasés au même plan ne valent
    pas mieux qu'un pâté plein.
    """
    if niveaux is None:
        niveaux = d["hauteur"] or 0.0
    y_haut = niveaux * ETAGE_M
    y_bas = -ENFOUISSEMENT

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

    # ⚠️ TOIT PENTU SUR EMPREINTE CONVEXE SEULEMENT. Mesuré : 93 % des
    # empreintes le sont, les 7 % restantes prennent un toit plat et le compte
    # s'imprime. La pente est mise à 0 en amont pour les mêmes empreintes, donc
    # les deux tests disent la même chose — celui-ci est la ceinture.
    if pente and pente > 0.0 and faitage is not None and _convexe(anneau):
        h, t = _toit(m, anneau, y_haut, pente, faitage, coul, G)
        return ok, n, h, t

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


def _toit(m, anneau, y_egout, pente, faitage, coul, G):
    """Un toit à deux pentes, sans un seul asset.

    LA RECETTE, et c'est tout : on pose une DROITE DE FAÎTAGE au milieu de
    l'empreinte, parallèle à la rue, puis chaque sommet de l'égout est relié à
    sa propre projection sur cette droite.

    Ce que ça produit tout seul, sans cas particulier :
      · les deux arêtes le long de la rue donnent les deux versants ;
      · les deux arêtes de bout donnent des pignons VERTICAUX, parce que leurs
        deux sommets se projettent au même endroit du faîtage et que le quad
        s'écrase en triangle ;
      · deux maisons mitoyennes ont donc deux pignons dans le MÊME plan, celui
        du mur qu'elles partagent déjà (61) — le joint en toiture entre deux
        hauteurs différentes se fait tout seul, en décrochement franc. C'est
        exactement ce que 61 laissait à faire, et ça n'a demandé aucun code.

    ⚠️ Le faîtage est parallèle à la RUE, pas à l'axe long de l'empreinte. Sur
    une maison de ville plus profonde que large, l'axe long est perpendiculaire
    à la rue : le toit partirait de travers, et toute une rangée avec.
    """
    ux, uy = faitage
    vx, vy = -uy, ux                        # perpendiculaire, vers la profondeur
    cx = sum(p[0] for p in anneau) / len(anneau)
    cy = sum(p[1] for p in anneau) / len(anneau)
    vs = [(p[0] - cx) * vx + (p[1] - cy) * vy for p in anneau]
    demi = (max(vs) - min(vs)) / 2.0
    y_fait = y_egout + min(FAITAGE_MAX, pente * demi)
    # Le faîtage passe par le milieu de la profondeur, pas par le centroïde :
    # sur une empreinte de travers le centroïde décentre le toit.
    mv = (max(vs) + min(vs)) / 2.0
    ox, oy = cx + vx * mv, cy + vy * mv

    def sur_faitage(p):
        t = (p[0] - ox) * ux + (p[1] - oy) * uy
        return (ox + ux * t, oy + uy * t)

    # 🔴 FENDRE L'ANNEAU SUR LA LIGNE DE FAÎTAGE, avant tout le reste.
    # Une arête d'égout qui TRAVERSE le faîtage donne un quadrilatère plié en
    # deux : la moitié qui est du bon côté regarde le ciel, l'autre regarde le
    # sol et disparaît au culling. Mesuré : 519 triangles sur 5 615, soit 9 %
    # des toits, tous sur des empreintes non rectangulaires. En posant un
    # sommet à la traversée, plus aucune arête ne chevauche les deux versants.
    fendu = []
    n = len(anneau)
    for i in range(n):
        a, b = anneau[i], anneau[(i + 1) % n]
        sa = (a[0] - ox) * vx + (a[1] - oy) * vy
        sb = (b[0] - ox) * vx + (b[1] - oy) * vy
        fendu.append(a)
        if (sa > 1e-9 and sb < -1e-9) or (sa < -1e-9 and sb > 1e-9):
            t = sa / (sa - sb)
            fendu.append((a[0] + t * (b[0] - a[0]), a[1] + t * (b[1] - a[1])))
    anneau = fendu

    # Le contrôle d'orientation d'un toit ne peut pas se faire par cas — un
    # versant regarde le ciel, un pignon regarde de côté, et entre les deux il
    # y a tout le reste. Le seul critère qui vaut pour les trois : la face
    # tourne-t-elle le dos au CŒUR du bâtiment ? On prend ce cœur au milieu de
    # la hauteur du toit, et on demande que la normale s'en éloigne.
    coeur = G(ox, oy, (y_egout + y_fait) / 2.0)

    ok = tot = 0
    n = len(anneau)
    for i in range(n):
        a, b = anneau[i], anneau[(i + 1) % n]
        ra, rb = sur_faitage(a), sur_faitage(b)
        pa = G(a[0], a[1], y_egout)
        pb = G(b[0], b[1], y_egout)
        qa = G(ra[0], ra[1], y_fait)
        qb = G(rb[0], rb[1], y_fait)
        for tri in _decouper_quad(pa, pb, qb, qa, coeur):
            # 🔴 L'ORIENTATION EST CALCULÉE, PAS DÉDUITE — et c'est la leçon de
            # la soirée. Pour un MUR, le sens du parcours de l'anneau décide de
            # l'extérieur, et le vérifier a du sens. Pour un TOIT, non : un
            # pignon n'est pas un versant, une arête presque perpendiculaire au
            # faîtage a un sens de parcours arbitraire, et trois recettes
            # successives ont échoué à le deviner. Le critère « la face tourne
            # le dos au cœur du bâtiment », lui, est vrai dans tous les cas et
            # se calcule directement. On l'applique au lieu de l'espérer.
            if not _vers_dehors(tri, coeur):
                tri = (tri[0], tri[2], tri[1])
                retournes[0] += 1
            m.triangle(tri[0], tri[1], tri[2], coul)
            tot += 1
            ok += 1
    return ok, tot


def _vers_dehors(tri, coeur):
    nn = normale(tri[0], tri[1], tri[2])
    gx = (tri[0][0] + tri[1][0] + tri[2][0]) / 3.0 - coeur[0]
    gy = (tri[0][1] + tri[1][1] + tri[2][1]) / 3.0 - coeur[1]
    gz = (tri[0][2] + tri[1][2] + tri[2][2]) / 3.0 - coeur[2]
    return nn[0] * gx + nn[1] * gy + nn[2] * gz > 0.0


def _decouper_quad(pa, pb, qb, qa, coeur):
    """Un pan de toit en triangles, sans jamais en retourner un.

    🔴 Le cas qui a coûté la soirée : un pignon dont l'arête n'est pas
    EXACTEMENT perpendiculaire au faîtage donne un quadrilatère VRILLÉ — ses
    quatre sommets ne sont pas dans un plan. Coupé en diagonale, une de ses
    deux moitiés bascule vers le bas et disparaît au culling. Mesuré : 992
    triangles sur 7 500, et les rectangles n'étaient gauchis que de treize
    centimètres.

    La sortie : on coupe la diagonale seulement si les deux moitiés tiennent.
    Sinon on éclate le quadrilatère en quatre triangles autour de son centre —
    plus cher d'un triangle, mais un éventail autour d'un point ne peut pas se
    retourner tout seul."""
    diag = [t for t in ((pa, pb, qb), (pa, qb, qa)) if not _degenere(t)]
    # Deux moitiés qui ne regardent pas du même côté = le quadrilatère est
    # VRILLÉ, ses quatre sommets ne sont pas dans un plan. La diagonale
    # trancherait alors dans le pli ; l'éventail autour du centre, non.
    if len(diag) == 2 and _vers_dehors(diag[0], coeur) == _vers_dehors(diag[1], coeur):
        return diag
    c = tuple(sum(p[k] for p in (pa, pb, qb, qa)) / 4.0 for k in range(3))
    return [t for t in ((pa, pb, c), (pb, qb, c), (qb, qa, c), (qa, pa, c))
            if not _degenere(t)]


def _debordement(emprise, parcelles):
    """De combien le bâtiment sort-il de la parcelle qui le porte ?

    🔴 LE DÉFAUT CONNU DU 2026-08-12, et il faut le voir plutôt que le
    deviner. `retracter` décale chaque arête vers l'intérieur ; sur un angle
    RENTRANT les deux droites décalées divergent, la limite de mitre remplace
    le pic par un biseau, et ce biseau peut ressortir du côté de la rue. Le
    dépassement est borné par le recul du tissu — 5 m en pavillonnaire, 6 m
    sur la barre — donc sans commune mesure avec les 258 m de la session 9,
    mais un bâtiment qui mord sur la chaussée reste un bâtiment qui ment.

    On mesure sur la parcelle la PLUS PROCHE : associer chaque empreinte à sa
    parcelle d'origine demanderait de la traîner dans toute la chaîne, alors
    que la mesure du pire cas suffit à dire si ça empire."""
    pire = 0.0
    for q in emprise:
        d = min((min(D4C.dist_pt_seg(q, p["anneau"][i],
                                     p["anneau"][(i + 1) % len(p["anneau"])])
                     for i in range(len(p["anneau"]))))
                for p in parcelles) if parcelles else 0.0
        if d > pire and not any(dedans(p["anneau"], q) for p in parcelles):
            pire = d
    return pire


def _convexe(anneau, tol=1e-6):
    """Tous les virages tournent-ils dans le même sens ?"""
    n = len(anneau)
    signe = 0
    for i in range(n):
        a, b, c = anneau[i], anneau[(i + 1) % n], anneau[(i + 2) % n]
        cr = (b[0] - a[0]) * (c[1] - b[1]) - (b[1] - a[1]) * (c[0] - b[0])
        if abs(cr) < tol:
            continue
        s = 1 if cr > 0 else -1
        if signe == 0:
            signe = s
        elif s != signe:
            return False
    return True


def _degenere(tri, seuil=1e-7):
    (ax, ay, az), (bx, by, bz), (cx, cy, cz) = tri
    ux, uy, uz = bx - ax, by - ay, bz - az
    vx, vy, vz = cx - ax, cy - ay, cz - az
    nx = uy * vz - uz * vy
    ny = uz * vx - ux * vz
    nz = ux * vy - uy * vx
    return (nx * nx + ny * ny + nz * nz) < seuil


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


def _ecorner(anneau):
    """Couper les pointes : `\\_/` au lieu de `\\/`.

    Un sommet CONVEXE dont l'angle intérieur passe sous ANGLE_MIN_DEG est
    remplacé par deux sommets et une petite arête franche. Ces pointes ne
    viennent pas du parcellaire mais du rétrécissement : sur un angle rentrant
    de l'emprise, deux arêtes décalées se rejoignent très loin et fabriquent
    une lame de couteau — un mur de trois centimètres vu de face.

    Ce que ça ne casse pas : chanfreiner un sommet convexe laisse une
    empreinte convexe convexe, donc les toits à deux pentes ne se perdent pas
    en route. Et un sommet concave n'est jamais touché."""
    n = len(anneau)
    if n < 3:
        return anneau
    cos_seuil = math.cos(math.radians(ANGLE_MIN_DEG))
    out = []
    coupes = 0
    for i in range(n):
        p0 = anneau[(i - 1) % n]
        p = anneau[i]
        p1 = anneau[(i + 1) % n]
        ax, ay = p0[0] - p[0], p0[1] - p[1]
        bx, by = p1[0] - p[0], p1[1] - p[1]
        la = math.hypot(ax, ay)
        lb = math.hypot(bx, by)
        if la < 1e-9 or lb < 1e-9:
            out.append(p)
            continue
        # Anneau trigonométrique : le sommet est CONVEXE quand le produit
        # vectoriel des deux arêtes est positif.
        cr = ((p[0] - p0[0]) * (p1[1] - p[1])
              - (p[1] - p0[1]) * (p1[0] - p[0]))
        cosang = (ax * bx + ay * by) / (la * lb)   # cos de l'angle intérieur
        if cr <= 0.0 or cosang < cos_seuil:
            out.append(p)
            continue
        # Le pan coupé mesure 2·d·sin(θ/2) : on inverse pour viser PAN_COUPE_M.
        demi = math.acos(max(-1.0, min(1.0, cosang))) / 2.0
        vise = PAN_COUPE_M / (2.0 * max(math.sin(demi), 1e-3))
        d = min(vise, PART_COTE_MAX * la, PART_COTE_MAX * lb)
        if d < 0.15:
            out.append(p)
            continue
        out.append((p[0] + ax / la * d, p[1] + ay / la * d))
        out.append((p[0] + bx / lb * d, p[1] + by / lb * d))
        coupes += 1
    if not coupes:
        return anneau
    net = D4C.nettoyer(out)
    if len(net) < 3 or abs(D4C.aire_signee(net)) < 6.0:
        return anneau                 # la coupe mangeait tout : on renonce
    pointes[0] += coupes
    pointes[1] += 1
    return net


def _largeur_min(anneau):
    """La plus petite largeur de l'empreinte : la distance entre les deux
    droites parallèles les plus serrées qui l'enferment.

    Un bâtiment n'est pas jugé sur son aire — un coin de 40 m de long et 2 m de
    large en fait 40, ce qui passe tous les seuils d'aire, et se voit comme une
    lame posée à plat. C'est la LARGEUR qui dit si on croirait y habiter."""
    n = len(anneau)
    best = None
    for i in range(n):
        a, b = anneau[i], anneau[(i + 1) % n]
        dx, dy = b[0] - a[0], b[1] - a[1]
        L = math.hypot(dx, dy)
        if L < 1e-9:
            continue
        nx, ny = -dy / L, dx / L
        ds = [(p[0] - a[0]) * nx + (p[1] - a[1]) * ny for p in anneau]
        w = max(ds) - min(ds)
        if best is None or w < best:
            best = w
    return best if best is not None else 0.0


def _garder(volumes, parcelle):
    """Le filtre des lames. Ce qui ne survit pas rend sa parcelle au jardin —
    un cœur d'îlot un peu plus grand vaut mieux qu'un bâtiment qui ment."""
    out = []
    for emp, faite in volumes:
        if len(emp) >= 3 and _largeur_min(emp) >= LARGEUR_MIN_BATI:
            out.append((emp, faite))
        else:
            minces[0] += 1
    if not out:
        return [], [D4C.ouvrir(parcelle)]
    return out, None


def _rectangle(emp, u, w, w_max):
    """L'empreinte ramenée à une BOÎTE alignée sur la rue.

    Une barre de 1974, un hangar, une halle : ce sont des rectangles, et les
    faire suivre le découpage parcellaire leur donne des biais qu'ils n'ont
    jamais eus.

    🔴 LE PIÈGE, mesuré et corrigé le 2026-08-12 : prendre le RECTANGLE
    ENGLOBANT de l'empreinte est immédiat à écrire et faux. Une parcelle en L
    ou en biais a un englobant qui déborde très loin d'elle — 44,5 m mesurés,
    contre 4,8 m de débordement maximal avant. On cherche donc le plus grand
    rectangle qui TIENT DEDANS : on rastérise l'empreinte par balayage de
    lignes, puis on prend le plus grand rectangle de cellules pleines. C'est
    l'emprise au sol, pas une taille inventée, et ça ne peut pas sortir de la
    parcelle."""
    ux, uy = u
    wx, wy = w
    pts = [(p[0] * ux + p[1] * uy, p[0] * wx + p[1] * wy) for p in emp]
    u0 = min(p[0] for p in pts)
    u1 = max(p[0] for p in pts)
    v0 = min(p[1] for p in pts)
    v1 = min(max(p[1] for p in pts), w_max)
    if u1 - u0 < 2.0 or v1 - v0 < 2.0:
        return None

    pas = max(0.5, min(u1 - u0, v1 - v0) / 60.0)
    nu = max(1, int((u1 - u0) / pas))
    nv = max(1, int((v1 - v0) / pas))
    du = (u1 - u0) / nu
    dv = (v1 - v0) / nv

    # Rastérisation par balayage : pour chaque ligne, les abscisses où le bord
    # est traversé, deux à deux, donnent les segments pleins.
    n = len(pts)
    grille = []
    for j in range(nv):
        yc = v0 + (j + 0.5) * dv
        xs = []
        for i in range(n):
            a, b = pts[i], pts[(i + 1) % n]
            if (a[1] <= yc) != (b[1] <= yc):
                t = (yc - a[1]) / (b[1] - a[1])
                xs.append(a[0] + t * (b[0] - a[0]))
        xs.sort()
        ligne = [False] * nu
        for k in range(0, len(xs) - 1, 2):
            ka = max(0, int(math.ceil((xs[k] - u0) / du - 0.5)))
            kb = min(nu - 1, int(math.floor((xs[k + 1] - u0) / du - 0.5)))
            for c in range(ka, kb + 1):
                ligne[c] = True
        grille.append(ligne)

    # Le plus grand rectangle de cellules pleines — méthode de l'histogramme,
    # une pile par ligne.
    haut = [0] * nu
    best = (0, 0, -1, 0, -1)          # cellules, i0, i1, j0, j1
    for j in range(nv):
        for i in range(nu):
            haut[i] = haut[i] + 1 if grille[j][i] else 0
        pile = []
        for i in range(nu + 1):
            h = haut[i] if i < nu else 0
            debut = i
            while pile and pile[-1][1] >= h:
                d0, h0 = pile.pop()
                if h0 * (i - d0) > best[0]:
                    best = (h0 * (i - d0), d0, i - 1, j - h0 + 1, j)
                debut = d0
            pile.append((debut, h))
    if best[0] <= 0:
        return None

    a0 = u0 + best[1] * du
    a1 = u0 + (best[2] + 1) * du
    b0 = v0 + best[3] * dv
    b1 = v0 + (best[4] + 1) * dv
    if a1 - a0 < 2.0 or b1 - b0 < 2.0:
        return None

    def pt(a, b):
        return (a * ux + b * wx, a * uy + b * wy)

    rect = D4C.ouvrir([pt(a0, b0), pt(a1, b0), pt(a1, b1), pt(a0, b1)])
    rectangles[0] += 1
    return rect


def _empreinte_batie(parcelle, st, idx_bord):
    """La parcelle devient une empreinte de bâtiment ET un fond de parcelle.

    Trois gestes, dans cet ordre, et chacun répond à un des trois nombres de
    `BATI` : on recule de la rue, on s'écarte (ou pas) de la voisine, puis on
    coupe ce qui dépasse en profondeur.

    Renvoie DEUX listes : les volumes, et ce qui reste derrière eux — la cour
    ou le jardin. C'est ce deuxième retour qui est neuf : le fond de parcelle
    était calculé puis jeté, donc les cœurs d'îlot étaient du terrain nu. Une
    parcelle enclavée, sans aucune arête sur rue, n'est pas bâtie du tout : elle
    part entière au jardin."""
    recul, jeu, prof, _pente = BATI.get(st, BATI_DEFAUT)
    rues = _sur_rue(parcelle, idx_bord)
    if not any(rues):
        # enclavée : cour ou jardin, pas de maison. Elle était déjà creusée,
        # elle est maintenant DESSINÉE.
        return [], [D4C.ouvrir(parcelle)]

    retraits = [recul if r else jeu for r in rues]
    emp = D4B.retracter(parcelle, retraits)
    # `reparer` retire les boucles que tout offset à distance variable finit
    # par fabriquer sur un angle rentrant. Il renvoie (anneau, réparations,
    # plafond) — seul le premier nous intéresse ici.
    emp = D4B.reparer(emp)[0] if len(emp) >= 3 else []
    if len(emp) < 3 or abs(D4C.aire_signee(emp)) < 6.0:
        return [], [D4C.ouvrir(parcelle)]
    emp = D4C.ouvrir(emp)
    emp = D4C.nettoyer(emp)
    if len(emp) < 3:
        return [], [D4C.ouvrir(parcelle)]

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
        v, j = _garder([(_ecorner(emp), None)], parcelle)
        return v, (j if j is not None else [])
    a, b = meilleur
    dx, dy = b[0] - a[0], b[1] - a[1]
    L = math.hypot(dx, dy)
    if L < 1e-9:
        v, j = _garder([(_ecorner(emp), None)], parcelle)
        return v, (j if j is not None else [])
    rue_dir = (dx / L, dy / L)         # la direction du faîtage
    # Anneau trigonométrique : l'intérieur est à GAUCHE du parcours, donc la
    # normale rentrante vaut (−dy, dx). On garde le côté rue, c'est-à-dire le
    # côté négatif de cette normale.
    nx, ny = -dy / L, dx / L
    # `recul + prof` et pas `prof` : la façade est déjà en retrait de `recul`,
    # donc c'est de là qu'il faut compter la profondeur du bâtiment.
    fond = recul + prof
    p0 = (a[0] + nx * fond, a[1] + ny * fond)

    # Ce qui est DERRIÈRE la ligne de profondeur, découpé dans la parcelle
    # elle-même et non dans l'emprise rétrécie : les bandes latérales du jeu au
    # voisin y restent, et la partition (61) tient toujours — deux jardins
    # voisins partagent l'arête exacte de leur coupe commune.
    jardins = []
    for m in D4C.couper(parcelle, p0, (nx, ny)):
        if len(m) < 3:
            continue
        cx = sum(p[0] for p in m) / len(m)
        cy = sum(p[1] for p in m) / len(m)
        if (cx - p0[0]) * nx + (cy - p0[1]) * ny > 0.01 \
                and abs(D4C.aire_signee(m)) > AIRE_JARDIN_MIN:
            jardins.append(D4C.ouvrir(m))

    # Les boîtes : barre, hangar, halle. Elles sautent la coupe polygonale et
    # l'écornage — un rectangle n'a pas de pointe.
    if st in RECTANGULAIRE:
        rect = _rectangle(emp, rue_dir, (nx, ny),
                          (p0[0] * nx + p0[1] * ny))
        if rect is not None:
            v, j = _garder([(rect, rue_dir)], parcelle)
            return v, (j if j is not None else jardins)

    morceaux = D4C.couper(emp, p0, (-nx, -ny))
    garde = []
    for m in morceaux:
        if len(m) < 3:
            continue
        cx = sum(p[0] for p in m) / len(m)
        cy = sum(p[1] for p in m) / len(m)
        if (cx - p0[0]) * (-nx) + (cy - p0[1]) * (-ny) > -0.01 \
                and abs(D4C.aire_signee(m)) > 6.0:
            garde.append((_ecorner(D4C.ouvrir(m)), rue_dir))
    if not garde:
        garde = [(_ecorner(emp), rue_dir)]
    v, j = _garder(garde, parcelle)
    return v, (j if j is not None else jardins)


def _graine_lieu(anneau):
    """Une graine tirée de la POSITION, pas d'un rang — décision 35. Déplacer
    une ligne de la table `BATI` ne doit pas rebattre toute la ville."""
    cx = sum(p[0] for p in anneau) / len(anneau)
    cy = sum(p[1] for p in anneau) / len(anneau)
    return abs((int(round(cx * 100.0)) * 73856093)
               ^ (int(round(cy * 100.0)) * 19349663))


def _semer_jardin(anneau, aire):
    """Les arbres d'un jardin. Tous les jardins verts n'en ont pas : c'est le
    « pas tous » de la consigne, et c'est ce qui empêche le cœur d'îlot de
    ressembler à un tapis."""
    r = random.Random(_graine_lieu(anneau) ^ 0x5EED)
    if r.random() > PART_JARDINS_ARBORES:
        return []
    n = max(1, int(aire / M2_PAR_ARBRE_JARDIN))
    xs = [p[0] for p in anneau]
    ys = [p[1] for p in anneau]
    ferme = list(anneau) + [anneau[0]]
    out = []
    essais = 0
    while len(out) < n and essais < n * 40:
        essais += 1
        x = r.uniform(min(xs), max(xs))
        y = r.uniform(min(ys), max(ys))
        if not dedans(ferme, (x, y)):
            continue
        out.append([x, y, 0.0,
                    r.uniform(0.55, 0.95), r.uniform(0.0, 6.2832)])
    return out


def _ruban(m, a, b, larg, coul, G):
    """La chaussée : UN quadrilatère par segment. Prolongée d'une demi-largeur
    à chaque bout pour que les carrefours se remplissent au lieu d'afficher une
    croix pâle — on assume le recouvrement, tout est dans un seul plan et d'une
    seule couleur, donc il est invisible par construction.

    🔄 Elle était découpée tous les 20 m pour suivre la pente. La carte étant
    plate, elle reste à 0 sur toute sa longueur — et au-dessus du chenal, elle
    passe donc au-dessus du vide. C'est ça, le pont : aucune ligne de code du
    projet ne parle de tablier."""
    dx, dy = b[0] - a[0], b[1] - a[1]
    L = math.hypot(dx, dy)
    if L < 1e-9:
        return
    ux, uy = dx / L, dy / L
    px, py = -uy * larg / 2.0, ux * larg / 2.0
    ax, ay = a[0] - ux * larg / 2.0, a[1] - uy * larg / 2.0
    bx, by = b[0] + ux * larg / 2.0, b[1] + uy * larg / 2.0
    pg = G(ax - px, ay - py, Y_CHAUSSEE)
    pd = G(ax + px, ay + py, Y_CHAUSSEE)
    qg = G(bx - px, by - py, Y_CHAUSSEE)
    qd = G(bx + px, by + py, Y_CHAUSSEE)
    m.triangle(pg, pd, qd, coul)
    m.triangle(pg, qd, qg, coul)


def _semer(anneau, d, rng):
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
        out.append([x, y, 0.0,
                    rng.uniform(0.75, 1.35), rng.uniform(0.0, 6.2832)])
    return out


def _alignement(d, rng):
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
                out.append([x, y, 0.0,
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

    # 🌊 Le point de vue sur l'Ilse. C'est là que le chenal se juge : un mètre
    # de mur au-dessus de l'eau sur toute la longueur, et le tablier des trois
    # franchissements qui passe au-dessus sans y plonger.
    eau_pts = [p for x in ilots.values() if x["sous_type"] == "riviere"
               for p in x["brut"]]
    ip = [0.0, 0.0]
    if eau_pts:
        ip = [round(sum(p[0] for p in eau_pts) / len(eau_pts) - cx, 2),
              round(-(sum(p[1] for p in eau_pts) / len(eau_pts) - cy), 2)]
    return {
        # 🔄 C'était « la vallée ». Il n'y a plus de vallée : la carte est
        # plate. Le point de vue, lui, sert toujours — c'est la ville entière.
        "ville": {"cible": [0.0, 0.0], "taille": 1200.0,
                  "libelle": "Wehrau en entier"},
        "barre": {"cible": centre(32), "taille": 220.0,
                  "libelle": "La barre de 1974 (ilot 32)"},
        "quai": {"cible": qp, "taille": 160.0,
                 "libelle": "Les rues a 20 et 22 m"},
        "ilse": {"cible": ip, "taille": 260.0,
                 "libelle": "L'Ilse canalisee et les ponts"},
    }


if __name__ == "__main__":
    for flux in (sys.stdout, sys.stderr):
        try:
            flux.reconfigure(encoding="utf-8", errors="replace")
        except (AttributeError, OSError):
            pass
    main()
