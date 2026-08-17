#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
04d — L'emprise du bâtiment dans la parcelle.

    python3 QGIS/scripts/04d_emprises_batiments.py --blanc   # ne rien écrire
    python3 QGIS/scripts/04d_emprises_batiments.py           # écrire la couche
    python3 QGIS/scripts/04d_emprises_batiments.py copie.gpkg

Écrit une couche `batiments` : une empreinte au sol par parcelle bâtie.

POURQUOI CE SCRIPT EXISTE

L'empreinte était déjà calculée — mais dans `07_exporter_godot.py`, au moment
de fabriquer la 3D. Trois conséquences, et ce sont elles qui ont motivé le
déplacement :

  · l'emprise n'existait NULLE PART sur la carte, donc elle ne se jugeait
    qu'en 3D, en bout de chaîne ;
  · elle se recalculait à chaque export, alors que la parcelle est l'entité
    persistante (décision 35) — ce qui la porte doit être ÉCRIT une fois ;
  · rien d'autre ne pouvait s'en servir : ni la surface de toit de l'énergie,
    ni l'ombrage, ni une mesure de densité.

Ce que ce script AJOUTE aux règles de `07` : une distance aux limites
latérales ET de fond (`07` ne connaissait qu'un `jeu` au voisin), un plafond
d'emprise au sol par tissu, et la maison détachée ramenée à un rectangle.

⚠ LA CHAÎNE DEVIENT 02 → 03 → 04 → 04b → 04c → 04d.
   Idempotent : on le relance, il refait la couche.

Se lance sans QGIS : sqlite3 seul, et le lecteur WKB d'apercu_carte.
"""

import math
import os
import sqlite3
import sys
from importlib import import_module

ICI = os.path.dirname(os.path.abspath(__file__))
RACINE = os.path.dirname(os.path.dirname(ICI))
sys.path.insert(0, ICI)

from apercu_carte import gpkg_vers_wkb, lire_wkb, dedans  # noqa: E402

D4B = import_module("04b_emprises_baties")   # `retracter`, le décalage d'arêtes
D4C = import_module("04c_parcelles")         # `couper`, la coupe par une droite

BLANC = "--blanc" in sys.argv

_ARGS = [a for a in sys.argv[1:] if not a.startswith("--")]
GPKG = _ARGS[0] if _ARGS else os.path.join(RACINE, "QGIS", "data",
                                           "travail", "wehrau.gpkg")
SRS = 25832


# --- LA TABLE ------------------------------------------------------------
# 🎨 C'EST ELLE, ET PAS LE CODE, qui décide de quoi la ville a l'air. Une
# ligne changée, on relance, on regarde. Six nombres par tissu :
#
#   recul       façade ↔ limite sur rue. 0 = SUR l'alignement, la forme des
#               tissus anciens. Le bâtiment est toujours plaqué contre son
#               recul, jamais centré dans la parcelle : c'est ce qui creuse le
#               jardin DERRIÈRE au lieu de tout autour.
#   lateral     distance aux limites latérales. 🔴 0 = MITOYEN, et le mitoyen
#               est alors exact : les deux parcelles partagent déjà l'arête
#               (décision 61), donc les deux murs tombent dessus au millimètre.
#   fond        distance à la limite de fond — celle qui donne sur le cœur
#               d'îlot ou sur la rangée d'en face. N'existait pas avant ce
#               script : la profondeur du bâtiment tenait lieu de règle, donc
#               une parcelle courte donnait un bâtiment collé au fond.
#   facade      largeur visée du rectangle, pour les tissus DÉTACHÉS seulement.
#               Sans objet en mitoyen, où la largeur est celle de la parcelle.
#   profondeur  🔴 mesurée DEPUIS LA FAÇADE, pas depuis la rue. Au-delà, ce
#               n'est plus la maison, c'est la cour ou le jardin.
#   emprise     part de la parcelle que le bâtiment a le droit de couvrir.
#               🔴 C'est ce nombre qui commande la SURFACE DE TOIT, donc le
#               potentiel solaire en attente d'arbitrage.
#
# Et une famille de forme, qui est le vrai choix de dessin (voir `empreinte`).
MITOYEN, DETACHE, BOITE = "mitoyen", "detache", "boite"

TISSU = {
    # sous_type            recul  lat  fond  facade  prof  emprise  famille
    "coeur_ancien":        (0.0,  0.0,  0.0,  None,  None,  1.00, MITOYEN),
    "maisons_de_ville":    (1.5,  0.0,  6.0,  None,  None,  1.00, MITOYEN),
    "front_commercant":    (0.0,  0.0,  3.0,  None,  None,  0.75, MITOYEN),
    "pavillonnaire":       (4.0,  3.0,  3.0,   9.0,  10.0,  0.35, DETACHE),
    "barre_1970":          (6.0,  5.0,  5.0,  None,  13.0,  1.00, BOITE),
    "equipement":          (4.0,  3.0,  3.0,  20.0,  22.0,  0.45, DETACHE),
    "dalle_commerciale":   (2.0,  2.0,  2.0,  None,  53.0,  0.65, BOITE),
    "friche_industrielle": (3.0,  2.5,  2.5,  None,  35.0,  0.55, BOITE),
}

# 🔴 `profondeur = None` VEUT DIRE « AUCUNE RÈGLE DE PROFONDEUR » — 2026-08-17,
# demandé devant l'image. Deux tissus l'ont demandé, pour deux raisons :
#
#   · `maisons_de_ville` — « profondeur variable, pas de règle de limite à la
#     profondeur ». Le bâtiment va du recul jusqu'au retrait de fond, donc sa
#     profondeur est celle que la parcelle lui laisse. C'est aussi ce qui
#     répare LES COINS : une parcelle d'angle est profonde d'un côté et courte
#     de l'autre, et une profondeur unique comptée depuis une seule façade y
#     coupait de travers.
#   · `coeur_ancien` — « parcelles = bâtiment, avec quelques petites
#     exceptions ». Tous ses retraits sont nuls, donc l'empreinte EST la
#     parcelle. Les exceptions sont plus bas (`COUR_*`) : sans elles, un cœur
#     ancien n'a plus une seule cour, et une ville sans cour n'existe pas.
#
# Le plafond d'emprise vaut alors 1,00 : un plafond qui rabote la profondeur
# serait une règle de profondeur déguisée, c'est-à-dire l'inverse du réglage.

# ☕ LES EXCEPTIONS DU CŒUR ANCIEN. Une parcelle sur quatre, au-dessus de
# COUR_AIRE, garde une cour derrière son bâtiment. Le tirage vient de la
# position (35), donc la même parcelle garde sa cour d'une exécution à l'autre.
#
# 🔄 2026-08-17 — la cour était d'abord une PROFONDEUR (bâtiment sur les 12
# premiers mètres). C'était faux au sens de la règle : sur une parcelle
# d'angle, « les 12 premiers mètres depuis la façade » laisse le vide le long
# de l'autre rue. La cour est donc une BANDE ARRIÈRE, comme tous les autres
# vides du fichier.
COUR_PART = 0.25
COUR_AIRE = 110.0          # sous cette taille, une cour ne laisse plus de maison
COUR_FOND = 5.0

# Les origines de parcelle qui ne portent pas de bâtiment. Un cœur d'îlot est
# une cour, un chemin est une venelle : ni l'un ni l'autre ne se bâtit.
ORIGINES_NUES = {"coeur", "chemin"}

# --- LES RÉGLAGES DE BORD ------------------------------------------------

# Une arête est « sur rue » si son milieu tombe sur le bord de l'emprise.
# Même tolérance que `07` : les parcelles SONT des morceaux de l'emprise, donc
# l'écart théorique est nul et 30 cm sert seulement à rater bruyamment.
TOL_RUE = 0.30

# En dessous, une arête de parcelle ne porte ni rue, ni mur, ni retrait : c'est
# un résidu de découpe. `04c` en laisse — l'anneau de la parcelle 238 se ferme
# sur un doublon à quelques millimètres près.
LONGUEUR_ARETE_MIN = 0.50

# Le creux toléré le long d'une rue, au-delà du recul. `ecorner` remplace un
# angle aigu par un pan coupé de PAN_COUPE_M, et ce pan laisse forcément un
# triangle de terrain devant lui : c'est un pan coupé d'angle, pas un défaut.
CREUX_TOLERE = 1.5

# Part de la profondeur disponible qu'un retrait de fond a le droit de prendre.
PART_FOND_MAX = 0.40

# Une limite qui n'est pas sur rue est LATÉRALE ou DE FOND, et c'est son angle
# avec la façade qui tranche. Au-delà de ce cosinus l'arête est parallèle à la
# rue, donc c'est du fond. 0,60 = 53° : un trapèze reste du latéral, une arête
# franchement en travers est du fond.
COS_FOND = 0.60

# 🚶 Une venelle (67) n'est pas une rue : deux murs posés sur limite de part et
# d'autre d'un passage de 3 m font un couloir, pas une sente. Le recul y a donc
# un plancher, même dans les tissus qui bâtissent sur l'alignement.
RECUL_VENELLE_MIN = 1.0

# R5 — quand la parcelle est trop étroite pour la règle, les retraits se
# réduisent ENSEMBLE, dans cet ordre, jusqu'à un plancher. Ce qui est protégé :
# une rangée où une maison sur cinq manque se lit comme un bug, pas comme du
# tissu. Ce qui ne l'est pas : le mitoyen, qui vaut 0 et le reste.
FACTEURS = (1.0, 0.75, 0.5, 0.35)
PLANCHER_LATERAL = 1.5
PLANCHER_FOND = 2.0

# En dessous, il n'y a pas de bâtiment : la parcelle repart au jardin. Un cœur
# d'îlot un peu plus grand vaut mieux qu'une maison qui ment.
LARGEUR_MIN = 3.0          # la largeur du mur qui reste, pas l'aire

# 🔴 X, LE SEUIL DEMANDÉ LE 2026-08-17 : « si le bâtiment est < X m², alors
# parcelle vide ». Il valait 25, ce qui laissait passer des cabanes — mesuré
# avant relèvement : 14 empreintes entre 25 et 35 m², dont une de 25,0 m² large
# de 4,6 m sur la parcelle 501, et deux triangles de 25 et 30 m² (parcelles 503
# et 495). Le balayage, sur les 831 empreintes de la ville :
#
#     X (m²)   perdus   toit restant
#       25          0      10,27 ha
#       35         14      10,22 ha
#       40         20      10,20 ha     ← retenu
#       45         33      10,15 ha
#       60         78       9,91 ha
#
# 40 parce que c'est là que le mot change de sens : au-dessus on peut discuter
# d'un petit logement, en dessous c'est un appentis. Et ça ne coûte presque rien
# au toit (−0,07 ha, 0,7 %) — ce qui se perd n'avait pas de surface, il avait
# une forme. Monter à 60 commencerait à vider des rangées entières.
AIRE_MIN = 40.0

# 🔴 LA FORME BIZARRE, même demande : « si il contient trop de coins ET a une
# forme cheloue, alors parcelle vide aussi ». Les deux conditions ENSEMBLE, et
# c'est ce qui les rend justes séparément :
#
#   · beaucoup de coins tout seul ne prouve rien — un rectangle avec deux pans
#     coupés d'angle en a huit, et ces pans sont voulus (`ecorner`) ;
#   · une rectangularité basse toute seule ne prouve rien non plus — un
#     parallélogramme est légitime dès qu'une rue n'est pas perpendiculaire à sa
#     voisine (voir `04c.rectangularite`).
#
# Ce que la conjonction attrape, c'est le seul cas qui n'a pas d'excuse : une
# empreinte qui a beaucoup de coins ET qui ne remplit pas la boîte dans laquelle
# elle tient, donc un bâtiment en escalier ou en équerre tordue.
#
# ⚠️ CE CRITÈRE NE PEUT TOUCHER QUE LE MITOYEN, et c'est mesuré, pas espéré :
# les familles DETACHE et BOITE sortent d'un rectangle inscrit, donc toutes
# leurs empreintes font 4 sommets et 1,00 de rectangularité. Le pavillonnaire ne
# risque rien ici.
#
# Le croisement mesuré sur la ville (nombre d'empreintes concernées) :
#
#     coins >     rect<0,50   rect<0,60   rect<0,70
#       5              3           7          16
#       6              2           4           8
#       7              2           4           7
#
# Retenu 5 et 0,60 : les 7 attrapées ont entre 6 et 8 coins pour 0,31 à 0,59 de
# remplissage (les pires : parcelle 456 à 0,31, parcelle 105 à 0,49). Descendre
# à 0,70 en prendrait 16, dont des équerres franches qui se lisent très bien.
SOMMETS_MAX = 5
RECT_MIN = 0.60

# Les deux motifs de refus portent un texte FIXE parce que le tableau final
# compte par motif : un motif qui porterait ses chiffres sortirait en sept
# lignes de 1. Les chiffres se lisent dans le bloc de contrôle et `--pourquoi`.
MOTIF_PETIT = "sous %.0f m²" % AIRE_MIN
MOTIF_FORME = "trop de coins, mal rempli"

# Le rectangle détaché accepte de rétrécir jusqu'à cette part de la taille
# visée. En dessous, ce n'est plus la maison du tissu, donc rien.
PART_MIN = 0.65

# De combien le rectangle détaché a le droit de reculer pour trouver sa place
# quand la limite de rue est oblique. Au-delà, la maison n'est plus « proche de
# la route » (R2) et il vaut mieux ne rien bâtir.
GLISSE_MAX = 3.0

# ✂️ Les pointes, reprises de `07` : un angle rentrant du parcellaire donne des
# empreintes en lame de couteau. On coupe aussi loin qu'il le faut pour que le
# pan coupé fasse PAN_COUPE_M — ce qu'on vise n'est pas une longueur de coupe,
# c'est la largeur du mur qui reste.
ANGLE_MIN_DEG = 70.0
PAN_COUPE_M = 4.5
PART_COTE_MAX = 0.45

# R6 — l'irrégularité, tirée de la POSITION de la parcelle et non d'un rang
# (décision 35) : changer une ligne de la table ne doit pas rebattre toute la
# ville. Sans elle une rangée de lotissement est au cordeau, ce qui ne ressemble
# à rien de bâti.
JEU_RECUL = 0.4
JEU_FACADE = 0.5

PAS_RASTER = 0.4           # la maille du rectangle inscrit, en mètres

# Ce qui se compte en passant et s'imprime à la fin. Une exception qui ne se
# compte pas devient une règle sans qu'on s'en aperçoive.
COMPTE = {"cour": 0, "fond_cede": 0, "creux_garde": 0,
          "pire_coins": 0, "pire_rect": 1.0}


# ------------------------------------------------------------------ géométrie

def ccw(anneau):
    """L'anneau dans le sens trigonométrique. Tout le reste du fichier suppose
    que l'intérieur est à GAUCHE du parcours — c'est ce qui donne le signe de
    la normale rentrante, donc le sens des retraits."""
    return anneau if D4C.aire_signee(anneau) > 0 else anneau[::-1]


def graine(anneau):
    cx = sum(p[0] for p in anneau) / len(anneau)
    cy = sum(p[1] for p in anneau) / len(anneau)
    return abs((int(round(cx * 100.0)) * 73856093)
               ^ (int(round(cy * 100.0)) * 19349663))


def sans_doublons(anneau, tol=0.05):
    """Deux sommets à moins de 5 cm sont le même sommet. `04c` ferme certains
    anneaux sur un doublon à quelques millimètres près, et ce doublon fabrique
    une arête sans direction — voir le garde-fou de `enveloppe`."""
    net = []
    for p in anneau:
        if not net or math.hypot(p[0] - net[-1][0], p[1] - net[-1][1]) > tol:
            net.append(p)
    while len(net) > 2 and math.hypot(net[0][0] - net[-1][0],
                                      net[0][1] - net[-1][1]) <= tol:
        net.pop()
    return net


def jeu(g, sel, ampleur):
    """Un écart reproductible dans [-ampleur, +ampleur], tiré de la graine."""
    return ((((g >> sel) & 1023) / 1023.0) * 2.0 - 1.0) * ampleur


def touche_les_rues(poly, ring, rues, retraits, marge=0.35):
    """Le bâtiment est-il encore posé sur CHACUNE de ses limites sur rue ?

    On échantillonne trois points par arête de rue, décalés vers l'intérieur du
    recul plus une marge, et on demande qu'ils soient dans le bâtiment. Trois
    et pas un : un seul point au milieu laisse passer un coin tranché en biais,
    qui est justement le défaut qu'on traque.

    ⚠️ LES DEUX BOUTS DE L'ARÊTE NE SE MESURENT PAS, et ce n'est pas de la
    complaisance. Au coin de deux rues, le recul de l'une interdit à lui seul
    d'être au recul de l'autre : le bâtiment y a un pan coupé nécessaire, large
    du recul. Mesurer à 20 % de l'arête accusait 40 bâtiments qui n'avaient
    rien fait — on s'écarte donc des extrémités du recul plus un mètre."""
    n = len(ring)
    for i in range(n):
        if not rues[i]:
            continue
        a, b = ring[i], ring[(i + 1) % n]
        dx, dy = b[0] - a[0], b[1] - a[1]
        L = math.hypot(dx, dy)
        if L < 1.0:                          # une arête d'un mètre ne porte rien
            continue
        nx, ny = -dy / L, dx / L
        d = retraits[i] + marge
        bord = min((retraits[i] + 1.0) / L, 0.34)
        for t in (bord, 0.5, 1.0 - bord):
            p = (a[0] + dx * t + nx * d, a[1] + dy * t + ny * d)
            if dans(ring, p) and not dans(poly, p):
                return False
    return True


def _portee(ring, i):
    """Jusqu'où la parcelle s'étend devant l'arête i, perpendiculairement à
    elle. C'est la profondeur que cette arête a en face d'elle."""
    a, b = ring[i], ring[(i + 1) % len(ring)]
    dx, dy = b[0] - a[0], b[1] - a[1]
    L = math.hypot(dx, dy)
    if L < 1e-9:
        return 0.0
    nx, ny = -dy / L, dx / L
    return max((p[0] - a[0]) * nx + (p[1] - a[1]) * ny for p in ring)


def creux_sur_rue(poly, ring, rues, retraits):
    """De combien le bâtiment recule-t-il de sa rue, au-delà de son recul ?

    Le contrôle de R2 bis. `touche_les_rues` répond oui ou non et sert à
    décider une coupe ; ici on veut la PROFONDEUR du creux, parce que tous les
    creux ne se valent pas : le pan coupé d'un angle aigu (`ecorner`) en
    fabrique un de la taille du pan, et c'en est un qu'on veut. Un bâtiment
    reculé de six mètres sur toute sa façade, non."""
    pire = 0.0
    n = len(ring)
    for i in range(n):
        if not rues[i]:
            continue
        a, b = ring[i], ring[(i + 1) % n]
        dx, dy = b[0] - a[0], b[1] - a[1]
        L = math.hypot(dx, dy)
        if L < 2.0:
            continue
        nx, ny = -dy / L, dx / L
        bord = min((retraits[i] + 1.0) / L, 0.34)
        for t in (bord, 0.5, 1.0 - bord):
            base = (a[0] + dx * t, a[1] + dy * t)
            for k in range(1, 60):
                q = (base[0] + nx * 0.25 * k, base[1] + ny * 0.25 * k)
                if not dans(ring, q):
                    break                    # la parcelle s'arrête là
                if dans(poly, q):
                    pire = max(pire, 0.25 * k - retraits[i])
                    break
    return pire


def enveloppe(ring, retraits, rues):
    """La parcelle rétrécie de ses retraits — pour les tissus MITOYENS, dont
    l'empreinte suit la forme de la parcelle.

    🔴 POURQUOI CE N'EST PAS `04b.retracter`, qui fait pourtant le même geste.
    `retracter` décale chaque arête puis reconstruit les sommets par
    intersection des droites décalées : sur un sommet RENTRANT les deux droites
    divergent, la limite de mitre remplace le pic par un biseau, et ce biseau
    RESSORT de la parcelle. C'est le défaut connu du 2026-08-12 — 18 bâtiments
    qui mordent sur la rue, jusqu'à 4,8 m — et R0 dit qu'il ne doit plus
    exister. Mesuré ici avant correction : 116 bâtiments dehors, jusqu'à 7,4 m.

    Ici on part de la PARCELLE et on la coupe par les droites décalées
    (Sutherland–Hodgman). Couper ne fait que retirer, donc le résultat est
    contenu dans la parcelle par construction, et non par mesure.

    🔴 ET ON NE COUPE QUE LES ARÊTES QUI DEMANDENT UN RETRAIT. Couper aussi par
    celles à 0 fabriquerait l'intersection de tous les demi-plans, c'est-à-dire
    le NOYAU du polygone : sur une parcelle concave il est minuscule, parfois
    vide. Mesuré en essayant : la dalle commerciale de l'îlot 45 (5 919 m²)
    sortait « trop petite », et 145 parcelles perdaient leur bâtiment. Comme
    les trois tissus mitoyens ont un latéral nul, il ne reste à couper que la
    rue et le fond — une ou deux arêtes, donc presque rien à perdre.

    🔴 R2 BIS — LE VIDE EST TOUJOURS DERRIÈRE, JAMAIS LE LONG D'UNE RUE.
    2026-08-17, désigné sur l'image aux QUATRE COINS de l'îlot 15. La cause est
    ici : une droite est infinie. Le retrait de fond d'une arête arrière,
    prolongé, traverse la parcelle en biais et tranche un morceau qui, lui,
    touchait la rue — donc le bâtiment recule du trottoir, et il reste une
    bande de terrain nu entre lui et la chaussée. Sur un îlot ordinaire ça ne
    se voit pas ; sur une parcelle D'ANGLE, où l'arrière de la rangée est la
    rue de l'autre rangée, ça se voit à tous les coins.

    Le remède est une règle, pas un rattrapage : **le retrait de fond cède
    devant la rue**. Après chaque coupe on vérifie que le bâtiment touche
    encore chacune de ses limites sur rue ; s'il en a perdu une, la coupe est
    annulée. Le fond, lui, n'a rien à céder : il n'est bordé par personne."""
    poly = list(ring)
    n = len(ring)
    for i in range(n):
        if retraits[i] <= 1e-6:
            continue
        a, b = ring[i], ring[(i + 1) % n]
        dx, dy = b[0] - a[0], b[1] - a[1]
        L = math.hypot(dx, dy)
        # 🔴 UNE ARÊTE MINUSCULE N'A PAS DE DIRECTION, ELLE A DU BRUIT — et une
        # droite tirée d'un bruit coupe n'importe où. Mesuré le 2026-08-17 sur
        # la parcelle 238 de l'îlot 24 : une arête de quelques MILLIMÈTRES,
        # reste de la fermeture de l'anneau, a emporté 78 m² sur 108 et laissé
        # un bâtiment de 32 m² au fond d'une parcelle de 177. C'était la cause
        # des plus gros vides sur rue, pas la géométrie des coins.
        if L < LONGUEUR_ARETE_MIN:
            continue
        nx, ny = -dy / L, dx / L            # rentrant : anneau ccw
        c = (a[0] * nx + a[1] * ny) + retraits[i]
        suivant = []
        m = len(poly)
        for k in range(m):
            p, q = poly[k], poly[(k + 1) % m]
            dp = p[0] * nx + p[1] * ny - c
            dq = q[0] * nx + q[1] * ny - c
            if dp >= -1e-9:
                suivant.append(p)
            if (dp > 1e-9) != (dq > 1e-9) and abs(dq - dp) > 1e-12:
                t = dp / (dp - dq)
                suivant.append((p[0] + t * (q[0] - p[0]),
                                p[1] + t * (q[1] - p[1])))
        if not rues[i] and len(suivant) >= 3 \
                and not touche_les_rues(suivant, ring, rues, retraits):
            COMPTE["fond_cede"] += 1
            continue                        # cette coupe mangeait une rue
        poly = suivant
        if len(poly) < 3:
            return []
    return D4C.nettoyer(poly)


def dans(anneau_uv, p):
    """Point dans un anneau OUVERT. `apercu_carte.dedans` veut un anneau fermé
    et saute la dernière arête sinon : ici les anneaux sont ouverts partout."""
    x, y = p
    d = False
    n = len(anneau_uv)
    for i in range(n):
        x1, y1 = anneau_uv[i]
        x2, y2 = anneau_uv[(i + 1) % n]
        if (y1 > y) != (y2 > y) and x < x1 + (y - y1) * (x2 - x1) / (y2 - y1):
            d = not d
    return d


def convexe(anneau, tol=1e-7):
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


def direction_ilot(anneaux):
    """La direction de l'îlot : celle de la plus longue arête de son emprise.

    C'est ce qui met deux barres du même îlot dans la MÊME disposition. Prendre
    l'axe d'inertie donnerait la même chose sur un îlot allongé et n'importe
    quoi sur un îlot carré ; la plus longue arête est toujours une rue, donc
    toujours une direction que le joueur voit."""
    best, bl = None, 0.0
    for anneau in anneaux:
        n = len(anneau)
        for i in range(n):
            a, b = anneau[i], anneau[(i + 1) % n]
            L = math.hypot(b[0] - a[0], b[1] - a[1])
            if L > bl:
                bl, best = L, ((b[0] - a[0]) / L, (b[1] - a[1]) / L)
    return best


def index_bord(anneaux, grille=1.0):
    """Index de grille des arêtes devant lesquelles une parcelle a une adresse :
    le bord de l'emprise, et les deux parois de chaque venelle."""
    idx = {}
    for anneau in anneaux:
        n = len(anneau)
        for i in range(n):
            a, b = anneau[i], anneau[(i + 1) % n]
            x0, x1 = int(min(a[0], b[0]) // grille), int(max(a[0], b[0]) // grille)
            y0, y1 = int(min(a[1], b[1]) // grille), int(max(a[1], b[1]) // grille)
            for cx in range(x0, x1 + 1):
                for cy in range(y0, y1 + 1):
                    idx.setdefault((cx, cy), []).append((a, b))
    return idx


def sur_index(milieu, idx):
    mx, my = milieu
    cx, cy = int(mx // 1.0), int(my // 1.0)
    for dx in (-1, 0, 1):
        for dy in (-1, 0, 1):
            for (p, q) in idx.get((cx + dx, cy + dy), ()):
                if D4C.dist_pt_seg((mx, my), p, q) <= TOL_RUE:
                    return True
    return False


def ecorner(anneau):
    """Couper les pointes : `\\_/` au lieu de `\\/`. Un sommet CONVEXE sous
    ANGLE_MIN_DEG devient une arête franche ; un sommet concave n'est jamais
    touché, et une empreinte convexe le reste — les toits à deux pentes ne se
    perdent donc pas en route."""
    n = len(anneau)
    if n < 3:
        return anneau, 0
    cos_seuil = math.cos(math.radians(ANGLE_MIN_DEG))
    out, coupes = [], 0
    for i in range(n):
        p0, p, p1 = anneau[(i - 1) % n], anneau[i], anneau[(i + 1) % n]
        ax, ay = p0[0] - p[0], p0[1] - p[1]
        bx, by = p1[0] - p[0], p1[1] - p[1]
        la, lb = math.hypot(ax, ay), math.hypot(bx, by)
        if la < 1e-9 or lb < 1e-9:
            out.append(p)
            continue
        cr = ((p[0] - p0[0]) * (p1[1] - p[1]) - (p[1] - p0[1]) * (p1[0] - p[0]))
        cosang = (ax * bx + ay * by) / (la * lb)
        if cr <= 0.0 or cosang < cos_seuil:
            out.append(p)
            continue
        demi = math.acos(max(-1.0, min(1.0, cosang))) / 2.0
        d = min(PAN_COUPE_M / (2.0 * max(math.sin(demi), 1e-3)),
                PART_COTE_MAX * la, PART_COTE_MAX * lb)
        if d < 0.15:
            out.append(p)
            continue
        out.append((p[0] + ax / la * d, p[1] + ay / la * d))
        out.append((p[0] + bx / lb * d, p[1] + by / lb * d))
        coupes += 1
    if not coupes:
        return anneau, 0
    net = D4C.nettoyer(out)
    if len(net) < 3 or abs(D4C.aire_signee(net)) < AIRE_MIN:
        return anneau, 0               # la coupe mangeait tout : on renonce
    return net, coupes


def largeur_min(anneau):
    """La distance entre les deux droites parallèles les plus serrées qui
    enferment l'empreinte. Un bâtiment ne se juge pas sur son aire : un coin de
    40 m de long et 2 m de large en fait 40, ce qui passe tous les seuils
    d'aire et se voit comme une lame posée à plat."""
    best = None
    n = len(anneau)
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
    return best or 0.0


def forme(anneau):
    """(nombre de coins, rectangularité) de l'empreinte.

    🔴 LES COINS SE COMPTENT SUR L'ANNEAU NETTOYÉ, sinon le compte est du bruit :
    `enveloppe` coupe la parcelle par des droites décalées et laisse à chaque
    coupe un sommet aligné sur le précédent, qui ne se voit nulle part mais
    compte pour un coin. Mesuré sans nettoyage, la même empreinte passait de 5 à
    9 coins selon le nombre de retraits — donc selon la table, pas selon sa
    forme.

    La rectangularité vient de `04c` : c'est celle qui a servi à recoller les
    deux triangles de l'îlot 13 (aire ÷ aire du rectangle englobant ORIENTÉ,
    pas de la boîte nord-sud)."""
    net = D4C.nettoyer(anneau)
    return len(net), D4C.rectangularite(net)


def dist_bord(p, anneau):
    n = len(anneau)
    return min(D4C.dist_pt_seg(p, anneau[i], anneau[(i + 1) % n])
               for i in range(n))


# ------------------------------------------------- le rectangle dans la forme

def eroder(uv, retraits, u0, u1, v0, v1, pas):
    """La grille des cellules où le bâtiment a le droit d'être — pour les
    tissus DÉTACHÉS et les BOÎTES.

    Une cellule est gardée si elle est dans la parcelle ET à plus de son
    retrait de CHAQUE limite. La distance se mesure au SEGMENT et pas à la
    droite : c'est ce qui distingue l'érosion vraie du noyau convexe, et c'est
    ce qui rend la règle lisible telle qu'elle est écrite — « au moins 3 m de
    toute limite latérale » veut dire ça, exactement ça.

    La marge d'une demi-diagonale de cellule fait que la cellule est
    ENTIÈREMENT dedans, pas seulement son centre : sans elle, le rectangle
    débordait d'une demi-maille et le pavillonnaire sortait à 1,28 m d'une
    limite où la table en demande 3."""
    nu = max(1, int((u1 - u0) / pas))
    nv = max(1, int((v1 - v0) / pas))
    du, dv = (u1 - u0) / nu, (v1 - v0) / nv
    marge = 0.5 * math.hypot(du, dv)
    n = len(uv)
    aretes = [(uv[i], uv[(i + 1) % n], retraits[i] + marge) for i in range(n)]
    grille = []
    for j in range(nv):
        yc = v0 + (j + 0.5) * dv
        # Les arêtes trop loin de la ligne ne peuvent contraindre aucune de ses
        # cellules : sans ce tri, chaque cellule teste toutes les arêtes et le
        # script passe de 3 à 12 secondes sur la ville.
        proches = [(a, b, r) for (a, b, r) in aretes
                   if min(a[1], b[1]) - r <= yc <= max(a[1], b[1]) + r]
        ligne = []
        for i in range(nu):
            p = (u0 + (i + 0.5) * du, yc)
            ok = dans(uv, p)
            if ok:
                for (a, b, r) in proches:
                    if D4C.dist_pt_seg(p, a, b) < r:
                        ok = False
                        break
            ligne.append(ok)
        grille.append(ligne)
    return grille, du, dv, nu, nv


def rect_ancre(grille, du, dv, nu, nv, u0, v0, facade, prof):
    """Le rectangle de la MAISON DÉTACHÉE : plaqué contre la façade, centré
    entre les deux voisins, de la taille voulue si elle tient.

    🔴 CE QUI SE PASSE QUAND ELLE NE TIENT PAS, et c'est la moitié de la règle :
    on garde la PROFONDEUR et on rogne la façade, jusqu'à PART_MIN. Une maison
    moins large reste une maison ; une maison moins profonde qu'une véranda,
    non. Renvoie (U0, U1, V0, V1) dans le repère de la façade, ou None."""
    # Le devant de l'enveloppe : la première ligne qui a de la matière. Sur une
    # parcelle dont la limite de rue est oblique, ce n'est pas la ligne 0 —
    # sans ça le rectangle serait refusé pour une pointe de vide de 20 cm.
    j0 = next((j for j in range(nv) if any(grille[j])), None)
    if j0 is None:
        return None

    # 🔴 LE RECTANGLE A LE DROIT DE RECULER UN PEU, et sans ça un tiers des
    # pavillons manquait. Une limite de rue OBLIQUE ne donne qu'une poignée de
    # cellules pleines sur sa première ligne : exiger que le rectangle parte de
    # là le coince à cette largeur. On essaie donc plusieurs lignes de départ,
    # de la plus proche de la rue à GLISSE_MAX derrière, et on garde la
    # première qui tient la taille visée — la maison reste devant, elle se
    # contente de suivre le biais de la rue.
    for js in range(j0, min(nv, j0 + int(GLISSE_MAX / dv) + 1)):
        r = _ancre_depuis(grille, js, nu, nv, du, dv, u0, v0, facade, prof)
        if r is not None:
            return r
    return None


def _ancre_depuis(grille, js, nu, nv, du, dv, u0, v0, facade, prof):
    profs = []
    haut = [0] * nu
    for j in range(js, nv):
        for i in range(nu):
            haut[i] = haut[i] + 1 if grille[j][i] else 0
        plein = [h >= (j - js + 1) for h in haut]   # plein depuis la façade
        meilleur, debut, courant, d0 = 0, 0, 0, 0
        for i in range(nu + 1):
            if i < nu and plein[i]:
                if courant == 0:
                    d0 = i
                courant += 1
            else:
                if courant > meilleur:
                    meilleur, debut = courant, d0
                courant = 0
        profs.append(((j - js + 1) * dv, meilleur * du, debut, meilleur))
        if (j - js + 1) * dv >= prof:
            break

    # De la profondeur visée vers la moins profonde acceptable : on garde la
    # PROFONDEUR et on rogne la façade. Une maison moins large reste une
    # maison ; une maison moins profonde qu'une véranda, non.
    for (h, w, debut, ncol) in reversed(profs):
        if h < PART_MIN * prof:
            break
        if w < PART_MIN * facade:
            continue
        larg = min(w, facade)
        centre = u0 + (debut + ncol / 2.0) * du
        b0 = v0 + js * dv
        return (centre - larg / 2.0, centre + larg / 2.0, b0, b0 + h)
    return None


def rect_max(grille, du, dv, nu, nv, u0, v0, prof):
    """Le plus grand rectangle qui TIENT DEDANS — la barre, le hangar, la halle.

    🔴 LE PIÈGE, mesuré et corrigé le 2026-08-12 dans `07` : prendre le
    rectangle ENGLOBANT est immédiat à écrire et faux. Une parcelle en L ou en
    biais a un englobant qui déborde très loin d'elle — 44,5 m mesurés.

    🔴 ET LA PROFONDEUR EST UN PLAFOND — 2026-08-17, demandé devant l'image :
    « la barre, pas plus de 13 m de profondeur ». Sans lui, le plus grand
    rectangle d'une parcelle de 5 579 m² est un BLOC de 2 850 m² : c'est un
    centre commercial, pas une barre. Le plafond se pose sur la hauteur de
    l'histogramme, donc le rectangle reste le plus LONG possible à 13 m."""
    jmax = max(1, int(prof / dv))
    haut = [0] * nu
    best = (0, 0, -1, 0, -1)
    for j in range(nv):
        for i in range(nu):
            haut[i] = min(haut[i] + 1, jmax) if grille[j][i] else 0
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
    return (u0 + best[1] * du, u0 + (best[2] + 1) * du,
            v0 + best[3] * dv, v0 + (best[4] + 1) * dv)


# --------------------------------------------------------------- l'empreinte

def empreinte(parcelle, st, idx_bord, idx_venelle, dir_ilot=None):
    """La parcelle devient une empreinte de bâtiment.

    Les gestes, dans l'ordre, et chacun répond à une règle :
      R1  chaque limite prend le retrait de son RÔLE — rue, venelle, latéral, fond
      R2  la plus longue arête sur rue donne la façade, le bâtiment y est plaqué
      R3  mitoyen : suit la parcelle · détaché : un rectangle · boîte : la
          direction de l'ÎLOT, pas celle de la parcelle
      R5  si rien ne tient, les retraits se réduisent, puis on renonce
      R8  le plafond d'emprise au sol rabote la profondeur, quand il y en a une

    Renvoie (empreinte, motif). `motif` dit pourquoi il n'y a pas de bâtiment —
    c'est lui qui s'imprime, une raison vaut mieux qu'un compte."""
    recul0, lat0, fond0, facade, prof0, part_max, famille = TISSU[st]
    ring = ccw(sans_doublons(D4C.ouvrir(parcelle)))
    n = len(ring)
    if n < 3:
        return None, "dégénérée", [], []

    # R1 — le rôle de chaque limite. La rue d'abord, la venelle ensuite : une
    # paroi de venelle EST du bord d'emprise pour `04c`, donc les deux tests
    # répondent oui, et c'est le second qui doit gagner.
    rues, venelles = [], []
    for i in range(n):
        a, b = ring[i], ring[(i + 1) % n]
        m = ((a[0] + b[0]) / 2.0, (a[1] + b[1]) / 2.0)
        rues.append(sur_index(m, idx_bord))
        venelles.append(sur_index(m, idx_venelle) if idx_venelle else False)
    if not any(rues):
        return None, "enclavée", rues, []

    # R2 — la façade est la plus longue arête sur rue. C'est elle qui donne
    # l'orientation de tout ce qui suit, y compris du faîtage en 3D.
    meilleur, best_L = None, 0.0
    for i in range(n):
        if not rues[i]:
            continue
        a, b = ring[i], ring[(i + 1) % n]
        L = math.hypot(b[0] - a[0], b[1] - a[1])
        if L > best_L:
            best_L, meilleur = L, i
    if meilleur is None or best_L < 1e-9:
        return None, "sans façade", rues, []
    a = ring[meilleur]
    b = ring[(meilleur + 1) % n]
    L = math.hypot(b[0] - a[0], b[1] - a[1])
    u = ((b[0] - a[0]) / L, (b[1] - a[1]) / L)      # le long de la rue
    nrm = (-u[1], u[0])                            # rentrant : anneau ccw

    g = graine(ring)
    recul = max(0.0, recul0 + jeu(g, 3, JEU_RECUL))
    prof = prof0
    aire_parcelle = abs(D4C.aire_signee(ring))
    if facade is not None:
        facade = max(3.0, facade + jeu(g, 13, JEU_FACADE))

    # ☕ L'exception du cœur ancien : cette parcelle-ci garde une cour derrière.
    cour = (st == "coeur_ancien" and aire_parcelle >= COUR_AIRE
            and ((g >> 7) & 1023) / 1023.0 < COUR_PART)
    if cour:
        fond0 = COUR_FOND
        COMPTE["cour"] += 1

    # 📦 La boîte se pose dans la direction de l'ÎLOT et non de sa parcelle —
    # « les deux barres doivent être dans la même disposition », 2026-08-17.
    # Deux barres voisines tirent leur direction de deux parcelles différentes,
    # donc de deux rues différentes : sur l'îlot 32 elles sortaient à 9° l'une
    # de l'autre, ce qu'aucun plan-masse de 1970 n'a jamais dessiné.
    if famille == BOITE and dir_ilot is not None:
        cadre = (dir_ilot, (-dir_ilot[1], dir_ilot[0]))
    else:
        cadre = (u, nrm)

    # R8 — le plafond d'emprise au sol se paye en profondeur. On le règle par
    # essais successifs plutôt que par une formule : la profondeur ne commande
    # l'aire de façon proportionnelle que sur un rectangle, et la moitié des
    # tissus n'en sont pas. Sans règle de profondeur, il n'y a rien à raboter.
    for essai in range(7):
        emp, motif, retraits = _poser(ring, rues, venelles, u, nrm, cadre, a,
                                      st, famille, recul, lat0, fond0,
                                      facade, prof)
        if emp is None:
            return None, motif, rues, retraits
        if prof is None or part_max >= 1.0 or essai == 6:
            break
        if abs(D4C.aire_signee(emp)) <= part_max * aire_parcelle:
            break
        prof *= 0.88
    return emp, None, rues, retraits


def _poser(ring, rues, venelles, u, nrm, cadre, a, st, famille,
           recul, lat0, fond0, facade, prof):
    """Un essai de pose, à retraits donnés. Rendu séparé parce que R5 le
    rejoue en réduisant les retraits : c'est la seule boucle du fichier où
    l'échec est une étape normale."""
    n = len(ring)
    dernier = "trop petite"
    secours = None
    # La pire forme vue pendant les essais. Ne se reporte dans COMPTE qu'au
    # moment où la parcelle est DÉFINITIVEMENT refusée : un essai raté puis
    # rattrapé par R5 ne doit pas figurer dans les contrôles comme un rejet.
    pire = None
    for f in FACTEURS:
        lat = 0.0 if lat0 <= 0.0 else max(PLANCHER_LATERAL, lat0 * f)
        fond = 0.0 if fond0 <= 0.0 else max(PLANCHER_FOND, fond0 * f)
        retraits = []
        for i in range(n):
            if rues[i] or venelles[i]:
                r = max(recul, RECUL_VENELLE_MIN) if venelles[i] else recul
            else:
                p, q = ring[i], ring[(i + 1) % n]
                dl = math.hypot(q[0] - p[0], q[1] - p[1])
                cos = abs(((q[0] - p[0]) * u[0] + (q[1] - p[1]) * u[1]) / dl) \
                    if dl > 1e-9 else 0.0
                if cos >= COS_FOND:
                    # 🔴 UN RETRAIT DE FOND NE PREND JAMAIS PLUS DE 40 % DE CE
                    # QUE LA PARCELLE A DEVANT LUI. Sans ce plafond, les 6 m du
                    # jardin de maisons de ville s'appliquent tels quels à une
                    # lanière de 6 m de large — il ne reste rien, et le peu qui
                    # reste est loin de la rue. C'est la deuxième cause des
                    # creux sur rue, après l'arête parasite.
                    r = min(fond, PART_FOND_MAX * _portee(ring, i))
                else:
                    r = lat
            retraits.append(r)

        if famille == MITOYEN:
            env = enveloppe(ring, retraits, rues)
            if len(env) < 3 or abs(D4C.aire_signee(env)) < AIRE_MIN:
                # Même motif que le refus d'en bas, et ce n'est pas de la
                # paresse : les deux disent « il n'y a pas la place pour un
                # bâtiment de AIRE_MIN ». Séparés, ils sortaient en deux lignes
                # du tableau des refus dont l'une s'appelait « trop petite » —
                # deux fois le même chiffre sous deux noms différents.
                dernier = MOTIF_PETIT
                continue
            emp = _forme(ccw(env), retraits, cadre, a, famille,
                         facade, prof, recul, nrm)
        else:
            # La forme rectangulaire travaille sur la PARCELLE et ses retraits,
            # pas sur une enveloppe : l'érosion y est exacte, là où découper la
            # parcelle par ses propres droites la réduirait à son noyau.
            emp = _forme(ring, retraits, cadre, a, famille,
                         facade, prof, recul, nrm)
        if emp is None:
            dernier = "aucune forme ne tient"
            continue
        emp = ccw(D4C.nettoyer(emp))
        if len(emp) < 3:
            continue
        if famille == MITOYEN:
            emp = ecorner(emp)[0]
        if abs(D4C.aire_signee(emp)) < AIRE_MIN:
            dernier = MOTIF_PETIT
            continue
        if largeur_min(emp) < LARGEUR_MIN:
            dernier = "plus mince que %.1f m" % LARGEUR_MIN
            continue

        # 🔴 TROP DE COINS **ET** MAL REMPLI : la parcelle repart au jardin.
        # Le refus est un `continue` et pas un abandon parce que le tour suivant
        # de R5 réduit les retraits, donc coupe moins la parcelle — une empreinte
        # en escalier peut redevenir une équerre franche. Mesuré : sur les 7
        # empreintes attrapées, aucune ne se rattrape ainsi, mais l'ordre des
        # essais reste celui du reste du fichier.
        coins, rect = forme(emp)
        if coins > SOMMETS_MAX and rect < RECT_MIN:
            if pire is None or rect < pire[1]:
                pire = (coins, rect)
            # Motif à texte FIXE : le tableau des refus compte par motif, donc un
            # motif qui porte ses chiffres sort en sept lignes de 1. Les chiffres
            # se lisent dans le bloc de contrôle et dans `--pourquoi`.
            dernier = MOTIF_FORME
            continue

        # R2 bis, deuxième garde-fou. Annuler une coupe suffit quand une seule
        # arête est en cause ; il reste les parcelles étroites bordées de rue
        # sur trois côtés, où le retrait de fond ne peut PAS tenir sans creuser
        # une rue. Là, c'est le retrait qui plie : on redescend d'un cran et on
        # reprend. Le meilleur essai est gardé au cas où aucun ne serait net.
        if famille == MITOYEN:
            creux = creux_sur_rue(emp, ring, rues, retraits)
            if creux > CREUX_TOLERE:
                if secours is None or creux < secours[0]:
                    secours = (creux, emp, retraits)
                dernier = "creux de %.1f m sur rue" % creux
                continue
        return emp, None, retraits

    if secours is not None:
        COMPTE["creux_garde"] += 1
        return secours[1], None, secours[2]
    if pire is not None and dernier == MOTIF_FORME:
        COMPTE["pire_coins"] = max(COMPTE["pire_coins"], pire[0])
        COMPTE["pire_rect"] = min(COMPTE["pire_rect"], pire[1])
    return None, dernier, retraits


def _forme(env, retraits, cadre, a, famille, facade, prof, recul, nrm):
    """R3 — les trois familles.

    En mitoyen, `env` est l'enveloppe déjà rétrécie et il ne reste qu'à couper
    la profondeur — quand il y en a une. Dans les deux autres, `env` est la
    PARCELLE : c'est l'érosion qui tient les distances, et le rectangle se
    cherche dedans, dans le repère `cadre`."""
    if famille == MITOYEN:
        # 🔴 Pas de règle de profondeur : l'enveloppe EST le bâtiment. C'est le
        # cas du cœur ancien (parcelle = bâtiment) et des maisons de ville
        # (profondeur variable), demandé le 2026-08-17.
        if prof is None:
            return env
        # Sinon on coupe ce qui dépasse, et on garde le côté rue.
        p0 = (a[0] + nrm[0] * (recul + prof), a[1] + nrm[1] * (recul + prof))
        garde = []
        for m in D4C.couper(env, p0, (-nrm[0], -nrm[1])):
            if len(m) < 3:
                continue
            cx = sum(p[0] for p in m) / len(m)
            cy = sum(p[1] for p in m) / len(m)
            if (cx - p0[0]) * (-nrm[0]) + (cy - p0[1]) * (-nrm[1]) > -0.01 \
                    and abs(D4C.aire_signee(m)) > 6.0:
                garde.append(m)
        if not garde:
            return env
        return max(garde, key=lambda m: abs(D4C.aire_signee(m)))

    # Les deux familles de rectangle travaillent dans un repère : U le long de
    # la rue pour la maison détachée, le long de l'ÎLOT pour la boîte.
    u, w = cadre
    uv = [((p[0] - a[0]) * u[0] + (p[1] - a[1]) * u[1],
           (p[0] - a[0]) * w[0] + (p[1] - a[1]) * w[1]) for p in env]
    u0 = min(p[0] for p in uv) - 0.5
    u1 = max(p[0] for p in uv) + 0.5
    v0 = min(p[1] for p in uv) - 0.5
    v1 = max(p[1] for p in uv) + 0.5
    if u1 - u0 < 2.0 or v1 - v0 < 2.0:
        return None
    if famille == DETACHE:
        # Inutile de rastériser le fond du jardin : la maison ne va pas plus
        # loin que son recul plus sa profondeur, et la grille coûte au m².
        v1 = min(v1, recul + prof + GLISSE_MAX + 1.0)

    grille, du, dv, nu, nv = eroder(uv, retraits, u0, u1, v0, v1, PAS_RASTER)
    if famille == DETACHE:
        r = rect_ancre(grille, du, dv, nu, nv, u0, v0, facade, prof)
    else:
        r = rect_max(grille, du, dv, nu, nv, u0, v0, prof)
    if r is None:
        return None
    a0, a1, b0, b1 = r
    if a1 - a0 < LARGEUR_MIN or b1 - b0 < LARGEUR_MIN:
        return None

    def pt(x, y):
        return (a[0] + x * u[0] + y * w[0], a[1] + x * u[1] + y * w[1])

    return [pt(a0, b0), pt(a1, b0), pt(a1, b1), pt(a0, b1)]


# --------------------------------------------------------------------- lire

def lire(con):
    parcelles = []
    for fid, fid_ilot, st, origine, geom in con.execute(
        "SELECT fid, fid_ilot, sous_type, origine, geom FROM parcelles"
        " ORDER BY fid"
    ):
        anneaux, _ = lire_wkb(gpkg_vers_wkb(geom))
        parcelles.append({"fid": fid, "ilot": fid_ilot, "st": st,
                          "origine": origine, "anneau": D4C.ouvrir(anneaux[0])})
    emprises = {}
    for fid_ilot, geom in con.execute("SELECT fid_ilot, geom FROM emprises"):
        emprises.setdefault(fid_ilot, []).append(
            D4C.ouvrir(lire_wkb(gpkg_vers_wkb(geom))[0][0]))
    return parcelles, emprises


# --------------------------------------------------------------------- main

def main():
    if not os.path.exists(GPKG):
        sys.exit("Introuvable : %s — lancer 02 → 03 → 04 → 04b → 04c d'abord."
                 % GPKG)
    con = sqlite3.connect("file:%s?mode=ro" % GPKG.replace("\\", "/"), uri=True)
    parcelles, emprises = lire(con)
    con.close()

    print("=" * 74)
    print("EMPRISES DES BÂTIMENTS%s"
          % ("   [--blanc : rien n'est écrit]" if BLANC else ""))
    print("  %d parcelles, %d îlots" % (len(parcelles), len(emprises)))

    # Les parois des venelles sont une adresse au même titre que la rue, mais
    # avec un recul plancher : elles se rangent donc à part.
    par_ilot = {}
    for p in parcelles:
        par_ilot.setdefault(p["ilot"], []).append(p)
    idx_bord = {f: index_bord(a) for f, a in emprises.items()}
    idx_venelle = {}
    for f, lot in par_ilot.items():
        vens = [p["anneau"] for p in lot if p["origine"] == "chemin"]
        if vens:
            idx_venelle[f] = index_bord(vens)
    dirs = {f: direction_ilot(a) for f, a in emprises.items()}

    resultats, refus, detail = [], {}, []
    for p in parcelles:
        st = p["st"]
        if p["origine"] in ORIGINES_NUES or st not in TISSU:
            motif = p["origine"] if p["origine"] in ORIGINES_NUES \
                else "sol non bâti"
            refus[motif] = refus.get(motif, 0) + 1
            continue
        emp, motif, rues, retraits = empreinte(p["anneau"], st,
                                               idx_bord.get(p["ilot"], {}),
                                               idx_venelle.get(p["ilot"]),
                                               dirs.get(p["ilot"]))
        if emp is None:
            refus[motif] = refus.get(motif, 0) + 1
            detail.append((p, motif))
            continue
        resultats.append({"parcelle": p, "emp": emp, "rues": rues,
                          "retraits": retraits})

    controles(resultats, parcelles, refus)
    if "--pourquoi" in sys.argv:
        pourquoi(detail)

    if BLANC:
        print("\nrien écrit (--blanc)")
        return
    ecrire(resultats)
    print("\n→ couche `batiments` (%d) écrite dans %s"
          % (len(resultats), os.path.basename(GPKG)))


def controles(resultats, parcelles, refus):
    """🔴 LE SEUL ENDROIT OÙ UNE ERREUR PEUT SE VOIR sans lancer la 3D. Les
    trois lignes qui comptent : aucun bâtiment ne sort de sa parcelle (R0), la
    distance mesurée aux limites tient la table (R1/R4), et la surface de toit
    — celle qui rejoint l'énergie."""
    par_st = {}
    for r in resultats:
        st = r["parcelle"]["st"]
        emp = r["emp"]
        ring = r["parcelle"]["anneau"]
        # ⚠️ `dedans` parcourt len-1 arêtes : il lui faut un anneau FERMÉ, sinon
        # la dernière arête manque et le test répond au hasard près d'elle.
        ferme = list(ring) + [ring[0]]
        aire = abs(D4C.aire_signee(emp))
        ap = abs(D4C.aire_signee(ring))
        dmin = min(dist_bord(q, ring) for q in emp)
        dehors = max((dist_bord(q, ring) for q in emp if not dedans(ferme, q)),
                     default=0.0)
        d = par_st.setdefault(st, {"n": 0, "aire": 0.0, "part": 0.0,
                                   "dmin": 9e9, "dehors": 0.0, "n_dehors": 0,
                                   "larg": 9e9, "vide_rue": 0,
                                   "creux": 0.0, "aire_min": 9e9,
                                   "coins": 0, "rect": 1.0, "bizarre": 0})
        d["n"] += 1
        coins, rect = forme(emp)
        d["aire_min"] = min(d["aire_min"], aire)
        d["coins"] = max(d["coins"], coins)
        d["rect"] = min(d["rect"], rect)
        # 🔴 LES DEUX EXTRÊMES NE SUFFISENT PAS À JUGER, et l'oublier fait crier
        # au loup : le bâtiment qui a le plus de coins n'est presque jamais celui
        # qui remplit le moins. Le critère porte sur UN bâtiment, donc il se
        # compte bâtiment par bâtiment.
        if coins > SOMMETS_MAX and rect < RECT_MIN:
            d["bizarre"] += 1
        # Le même anneau nettoyé que celui sur lequel `rues` et `retraits` ont
        # été calculés — sinon les index ne désignent pas les mêmes arêtes.
        if TISSU[st][6] == MITOYEN:
            creux = creux_sur_rue(emp, ccw(sans_doublons(ring)), r["rues"],
                                  r["retraits"])
            if creux > CREUX_TOLERE:
                d["vide_rue"] += 1
                d["creux"] = max(d["creux"], creux)
        d["aire"] += aire
        d["part"] += aire / ap if ap else 0.0
        d["dmin"] = min(d["dmin"], dmin)
        d["larg"] = min(d["larg"], largeur_min(emp))
        if dehors > 0.05:
            d["dehors"] = max(d["dehors"], dehors)
            d["n_dehors"] += 1

    print("\n  %-21s %6s %9s %9s %9s %8s"
          % ("sous_type", "bâtis", "aire moy", "emprise", "plafond",
             "larg. min"))
    print("  " + "-" * 68)
    total, toit = 0, 0.0
    for st in sorted(par_st, key=lambda s: -par_st[s]["n"]):
        d = par_st[st]
        print("  %-21s %6d %9.0f %9.2f %9.2f %8.1f"
              % (st, d["n"], d["aire"] / d["n"], d["part"] / d["n"],
                 TISSU[st][5], d["larg"]))
        total += d["n"]
        toit += d["aire"]
    print("  " + "-" * 68)
    print("  %-21s %6d %9.0f" % ("total", total, toit / max(total, 1)))

    print("\n  🔴 BÂTIMENTS SORTANT DE LEUR PARCELLE (R0)")
    hors = [(st, d) for st, d in par_st.items() if d["n_dehors"]]
    if not hors:
        print("     ✅ aucun — 0 sur %d." % total)
    else:
        for st, d in hors:
            print("     ⚠️ %-21s %d bâtiment(s), jusqu'à %.2f m dehors"
                  % (st, d["n_dehors"], d["dehors"]))

    print("\n  🛣️  LE VIDE EST DERRIÈRE, JAMAIS LE LONG D'UNE RUE (R2 bis)")
    print("     Au-delà de %.1f m de creux : le pan coupé d'un angle aigu est"
          " voulu, une façade reculée non." % CREUX_TOLERE)
    vides = [(st, d) for st, d in par_st.items() if d["vide_rue"]]
    if not vides:
        print("     ✅ aucun bâtiment mitoyen ne laisse de terrain nu sur rue.")
    else:
        for st, d in sorted(vides, key=lambda x: -x[1]["vide_rue"]):
            print("     ⚠️ %-21s %d bâtiment(s) reculés, creux jusqu'à %.1f m"
                  % (st, d["vide_rue"], d["creux"]))
    print("     %d retraits de fond annulés parce qu'ils mangeaient une rue."
          % COMPTE["fond_cede"])

    print("\n  🧱 CE QUI RESTE DEBOUT TIENT LES DEUX SEUILS (2026-08-17)")
    print("     Un bâtiment sous %.0f m², ou qui a plus de %d coins ET moins de"
          " %.2f de" % (AIRE_MIN, SOMMETS_MAX, RECT_MIN))
    print("     remplissage, n'est pas bâti : la parcelle repart au jardin.")
    print("     %-21s %9s %7s %7s %8s"
          % ("sous_type", "aire mini", "coins", "rempl.", "bizarres"))
    for st in sorted(par_st, key=lambda s: -par_st[s]["n"]):
        d = par_st[st]
        alerte = "⚠️" if (d["aire_min"] < AIRE_MIN - 0.01
                          or d["bizarre"]) else "✅"
        print("     %-21s %9.0f %7d %7.2f %8d  %s"
              % (st, d["aire_min"], d["coins"], d["rect"], d["bizarre"],
                 alerte))
    print("     Refusés : %d trop petits, %d trop de coins mal remplis"
          % (refus.get(MOTIF_PETIT, 0), refus.get(MOTIF_FORME, 0)))
    if refus.get(MOTIF_FORME, 0):
        print("     La pire forme écartée : %d coins pour %.2f de remplissage."
              % (COMPTE["pire_coins"], COMPTE["pire_rect"]))

    print("\n  📏 DISTANCE MESURÉE AUX LIMITES (R1/R4) — un tissu mitoyen doit")
    print("     donner 0,00, un tissu détaché doit tenir la valeur de la table.")
    for st in sorted(par_st):
        lat, fond = TISSU[st][1], TISSU[st][2]
        d = par_st[st]
        if lat <= 0.0:
            etat = "✅ mitoyen" if d["dmin"] < 0.05 else "⚠️ décollé"
        else:
            plancher = min(PLANCHER_LATERAL, PLANCHER_FOND)
            etat = ("✅" if d["dmin"] >= min(lat, fond) - 0.01
                    else "↘ réduit (R5)" if d["dmin"] >= plancher - 0.01
                    else "⚠️")
        print("     %-21s mesuré %5.2f m   table %.1f / %.1f   %s"
              % (st, d["dmin"], lat, fond, etat))

    print("\n  🌞 SURFACE DE TOIT — le chiffre qui rejoint l'énergie")
    print("     %.2f ha sur %d bâtiments." % (toit / 1e4, total))

    n_coeur = par_st.get("coeur_ancien", {}).get("n", 0)
    if n_coeur:
        print("\n  ☕ LES EXCEPTIONS DU CŒUR ANCIEN — ailleurs, parcelle = bâtiment")
        print("     %d cours sur %d parcelles (%.0f %%), au-dessus de %d m²."
              % (COMPTE["cour"], n_coeur, 100.0 * COMPTE["cour"] / n_coeur,
                 COUR_AIRE))

    print("\n  🌿 LES PARCELLES SANS BÂTIMENT, et pourquoi")
    for motif, k in sorted(refus.items(), key=lambda x: -x[1]):
        print("     %-28s %4d" % (motif, k))
    print("     %-28s %4d" % ("→ bâties", total))
    print("=" * 74)


def pourquoi(detail):
    """`--pourquoi` : les parcelles refusées, une par ligne. Un compte de refus
    ne se corrige pas — il faut savoir LESQUELLES, sur quel îlot, et si elles
    sont concaves : c'est la différence entre régler la table et regarder le
    peigne de `04c`."""
    print("\n  🔎 LES %d PARCELLES REFUSÉES, de la plus grande à la plus petite"
          % len(detail))
    print("     ⚠️ aire, façade, coins et remplissage sont ceux de LA PARCELLE ;")
    print("     le motif dit pourquoi LE BÂTIMENT n'a pas tenu dedans. Une")
    print("     parcelle de 350 m² refusée « sous %.0f m² » est donc une parcelle"
          % AIRE_MIN)
    print("     tordue dont les retraits ne laissent presque rien.")
    print("     %-6s %-6s %-20s %8s %6s %6s %5s %6s  %s"
          % ("parc.", "îlot", "sous_type", "aire", "façade", "convex",
             "coins", "rempl.", "motif"))
    for p, motif in sorted(detail,
                           key=lambda x: -abs(D4C.aire_signee(x[0]["anneau"]))):
        ring = ccw(D4C.ouvrir(p["anneau"]))
        # Les coins et le remplissage de LA PARCELLE, pas de l'empreinte : quand
        # le refus vient de la forme, c'est la parcelle qu'il faut aller voir
        # dans `04c`, l'empreinte n'a fait que la suivre.
        coins, rect = forme(ring)
        print("     %-6d %-6d %-20s %8.0f %6.1f %6s %5d %6.2f  %s"
              % (p["fid"], p["ilot"], p["st"], abs(D4C.aire_signee(ring)),
                 largeur_min(ring), "oui" if convexe(ring) else "NON",
                 coins, rect, motif))


def ecrire(resultats):
    """🔴 UNE SEULE COUCHE, `batiments`. La couche `jardins` a existé une demi-
    journée le 2026-08-17 et a été retirée le jour même : sans règle de
    profondeur (cœur ancien, maisons de ville), le fond de parcelle n'est plus
    « ce qui est derrière une ligne » mais « la parcelle moins le bâtiment »,
    et ça demande une vraie différence de polygones que rien ne consomme
    encore. Écrire une couche à moitié juste vaut moins que ne pas l'écrire."""
    con = sqlite3.connect(GPKG)
    cur = con.cursor()
    cur.execute("DROP TABLE IF EXISTS batiments")
    for t in ("gpkg_contents", "gpkg_geometry_columns", "gpkg_ogr_contents"):
        cur.execute("DELETE FROM %s WHERE table_name = 'batiments'" % t)
    cur.execute("""
        CREATE TABLE "batiments" (
            "fid" INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
            "geom" POLYGON,
            fid_parcelle INTEGER,
            fid_ilot INTEGER,
            sous_type TEXT,
            famille TEXT,
            surface_m2 REAL,
            part_parcelle REAL)""")

    xs, ys, n = [], [], 0
    for r in resultats:
        p = r["parcelle"]
        ap = abs(D4C.aire_signee(p["anneau"]))
        aire = abs(D4C.aire_signee(r["emp"]))
        cur.execute(
            "INSERT INTO batiments (geom, fid_parcelle, fid_ilot, sous_type,"
            " famille, surface_m2, part_parcelle) VALUES (?,?,?,?,?,?,?)",
            (D4B.blob_gpkg(D4B.wkb_polygone([r["emp"]])), p["fid"], p["ilot"],
             p["st"], TISSU[p["st"]][6], round(aire, 1),
             round(aire / ap, 3) if ap else 0.0))
        for x, y in r["emp"]:
            xs.append(x)
            ys.append(y)
        n += 1

    cur.execute(
        "INSERT INTO gpkg_contents (table_name, data_type, identifier,"
        " description, last_change, min_x, min_y, max_x, max_y, srs_id)"
        " VALUES ('batiments','features','batiments',?,"
        " strftime('%Y-%m-%dT%H:%M:%fZ','now'),?,?,?,?,?)",
        ("Emprise au sol des batiments (04d)",
         min(xs), min(ys), max(xs), max(ys), SRS))
    cur.execute(
        "INSERT INTO gpkg_geometry_columns (table_name, column_name,"
        " geometry_type_name, srs_id, z, m)"
        " VALUES ('batiments','geom','POLYGON',?,0,0)", (SRS,))
    # GDAL tient un cache du nombre d'entités ; sans cette ligne QGIS peut
    # afficher une couche vide.
    cur.execute("INSERT INTO gpkg_ogr_contents (table_name, feature_count)"
                " VALUES ('batiments',?)", (n,))
    con.commit()
    con.close()


if __name__ == "__main__":
    for flux in (sys.stdout, sys.stderr):
        try:
            flux.reconfigure(encoding="utf-8", errors="replace")
        except (AttributeError, OSError):
            pass
    main()
