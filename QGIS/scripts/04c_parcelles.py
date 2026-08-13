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
    # 🔄 2026-08-14 : 8,0 × 20,0 → 9,5 × 22,0, demandé par l'auteur devant
    # l'image — « les parcelles de maisons de ville sont encore un peu trop
    # petites/étroites ». 160 m² deviennent 209, et la façade passe au-dessus
    # de la largeur d'une maison mitoyenne réelle (8 m était un minimum, pas
    # une moyenne). L'élancement visé descend de 2,50 à 2,32 : moins de lanière,
    # plus de terrain.
    "maisons_de_ville":        (9.5,   22.0,   "peigne"),  # le tissu majoritaire
    "front_commercant":       (11.0,   18.0,   "peigne"),  # vitrines en rez-de-ch.
    # 🔄 2026-08-12 : 18 m de façade donnaient des pavillons trop larges et trop
    # peu nombreux — une rangée de gros blocs, pas un lotissement. À 12,5 m on
    # a une maison par parcelle et le jardin derrière a la place d'exister.
    "pavillonnaire":          (13.5,   28.0,   "peigne"),  # détaché, jardins
    # 🔄 2026-08-14 : LA BARRE NE SE PEIGNE PLUS, demandé par l'auteur devant
    # l'image. Le peigne la traitait comme un tissu de rue — il en sortait un
    # anneau de parcelles le long des rues et un grand cœur vide au milieu,
    # c'est-à-dire l'inverse exact de ce qu'a fait l'urbanisme de 1970 : la
    # barre se pose au MILIEU de l'îlot, en travers, sans égard pour l'
    # alignement sur rue. La boîte ne connaît pas les rues, donc elle donne ça.
    # 80 × 70 = 5 600 m², soit la moitié des 11 158 m² de l'îlot 32 — le seul
    # îlot de barre de Wehrau — donc DEUX objets, comme l'auteur les a comptés.
    "barre_1970":             (80.0,   70.0,   "boite"),
    "equipement":             (45.0,   35.0,   "boite"),   # un ou deux objets
    "dalle_commercial":       (80.0,   60.0,   "boite"),   # (alias, voir plus bas)
    "dalle_commerciale":      (80.0,   60.0,   "boite"),   # un hangar
    "friche_industrielle":    (55.0,   45.0,   "boite"),   # des halles
}
# Les quatre sous-types SANS bâti ne se découpent pas : ils restent des sols.
# `riviere` non plus, évidemment.
SANS_DECOUPE = {"place_minerale", "parc", "champ", "jardins_familiaux",
                "riviere"}

# 🏡 LES TISSUS QUI N'ONT PAS DE CŒUR D'ÎLOT — 🔄 2026-08-14, demandé par
# l'auteur devant l'image : « le résidentiel ne devrait pas avoir de cœur
# d'îlot, la parcelle comprend la maison ET le jardin, et va jusqu'à la
# prochaine parcelle ».
#
# C'est la description exacte d'un lotissement : deux rangées dos à dos, la
# limite de fond de jardin est la limite de propriété, et il n'y a RIEN entre
# elles. Le cœur d'îlot est une figure de ville dense — la cour du cœur ancien,
# l'arrière-cour des maisons de ville — pas de pavillonnaire.
#
# Ce que ça change dans la mécanique : la profondeur visée cesse d'être un
# PLAFOND pour ces tissus. Chaque rive prend la moitié du fond quelle qu'elle
# soit (et tout le fond quand personne n'est en face), donc les deux bandes se
# rejoignent exactement au milieu et il ne reste rien. Ce qui survit malgré
# tout — un coin, un biseau — est RENDU aux parcelles de rue au lieu de
# devenir un jardin sans façade.
SANS_COEUR = {"pavillonnaire"}

# 🌳 CE QUI FAIT UN VRAI CŒUR D'ÎLOT — 🔄 2026-08-14, DEUXIÈME ÉCRITURE DE LA
# JOURNÉE, et c'est celle de l'auteur : « pour les grands îlots, les parcelles
# vont seulement une certaine profondeur jusqu'au centre ; la surface qui reste
# est un cœur d'îlot. »
#
# 🔴 CE QUI A ÉTÉ ESSAYÉ LE MATIN ET QUI ÉTAIT TROP SÉVÈRE, à ne pas refaire :
# un morceau devait être à la fois large ET sans pointe (`COEUR_ANGLE_MIN`,
# 30°) pour compter comme cour. Le reste partait en « rendu », donc recollé aux
# parcelles de rue. Sur l'image ça donnait exactement le défaut suivant que
# l'auteur a entouré — « les cœurs d'îlots sont fusionnés avec les parcelles » :
# le cœur de l'îlot 33 (741 m², 20,8 m de large, mais une pointe à 16°) partait
# en entier dans UNE parcelle de 651 m², trois fois l'aire visée du tissu. Onze
# parcelles dépassaient ainsi le double de leur aire visée, sur les îlots 10,
# 26, 33, 34, 47, 49, 50, 63, 66 — les mêmes qu'il a entourés.
#
# LA RÈGLE EST DONC LA LARGEUR, ET ELLE SEULE. Un cœur peut être pointu : une
# pointe au fond d'un îlot en éventail, c'est de la ville, pas un défaut de
# découpe. Ce qui n'est pas un cœur, c'est ce qui est trop MINCE pour qu'on y
# tienne — la lamelle de 5 m entre deux rangées, qui ressortait en jardin sans
# façade au milieu des maisons. Celle-là est toujours rendue.
#
# 🔄 Et le seuil descend de 10 à 8 m, mesuré : les restes des îlots 10 (9,8 m),
# 49 (9,6 et 8,1) et 50 (9,2) tombaient JUSTE en dessous de 10 et gonflaient
# une parcelle de rue chacun. Ce qui reste rendu à 8 m tient sous 110 m² —
# îlots 12, 14, 23, 34 et un morceau de 49 — donc s'absorbe sans se voir.
COEUR_MIN_LARGE = 8.0      # petit côté de la boîte englobante, en mètres
COEUR_ANGLE_MIN = 0.0      # 🔴 éteint : un cœur a le droit d'être pointu

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
#
# 🔄 2026-08-13 : 0,45 → 0,60. À 0,45 le plancher ne tenait QUE la moyenne, et
# le jeu de coupe (`JEU`) rapprochait deux coupes voisines de 0,25 chacune —
# donc la dent la plus étroite tombait à 0,225 × façade, soit 3 m en
# pavillonnaire pour 13,5 visés. Le jeu est maintenant borné par ce plancher
# (voir `_dents`), et le plancher vaut pour CHAQUE dent, plus pour la moyenne.
DENT_MIN = 0.60

# 🔴 QUAND L'ÎLOT N'EST PAS ASSEZ PROFOND POUR DEUX RANGÉES, ON N'EN FAIT
# QU'UNE, QUI TRAVERSE. En dessous de ce multiple de la profondeur visée, la
# première rue servie prend TOUT le fond et les parcelles donnent sur les deux
# rues à la fois. Au-dessus, les deux rives se partagent la profondeur en deux
# parts égales — la coupe tombe au milieu.
#
# Ce que ça remplace : la première rue servie prenait ses `profondeur` mètres
# quoi qu'il arrive, et celle d'en face se contentait du reste. Sur l'îlot 64,
# un côté sortait à 28 m et l'autre à 11.
#
#   à 1,2 · profondeur, en pavillonnaire (28 m) : un îlot de moins de 33 m de
#   fond fait des parcelles traversantes ; au-delà, deux rangées d'au moins
#   16,8 m chacune.
TRAVERSANT = 1.2

# Et elle ne dépasse jamais ce multiple de l'aire visée : au-delà, on ajoute des
# dents. C'est le garde-fou `Amax` du papier (§4.2.3, deuxième cas).
DENT_MAX = 2.0

# 🔺 LA POINTE — sommet de parcelle plus aigu que ça, en degrés. Une parcelle
# qui en porte un est réunie à sa voisine, comme un éclat ou une lamelle.
#
# 🔴 À ZÉRO, DONC ÉTEINT, ET C'EST UN CHOIX MESURÉ — pas un oubli. Le remède
# coûte plus cher que le mal, parce qu'une pointe réunie à sa voisine en
# refabrique souvent une autre :
#
#   seuil   parcelles   de rue   triangles   pointues   réunions
#     0°        1031      993        41         56         85
#    20°         958      923        36         31        158
#    30°         909      877        23         13        207
#    35°         892      861        14          3        224
#
# Lire la ligne 35° : pour faire tomber 53 pointes on perd 132 parcelles de rue,
# soit 14 % des maisons de la ville — et 14 triangles restent quand même. Or ce
# sont les toits qui portent la décision solaire en attente : on ne paie pas ça
# pour une gêne de tracé. Et `07_exporter_godot.py` coupe DÉJÀ la pointe du
# BÂTIMENT (`ANGLE_MIN_DEG = 70`), donc une parcelle en pointe ne donne pas
# forcément une maison en pointe : le vrai juge est la 3D, pas cette carte.
#
# Le mettre à 30 ou 35 si l'image en 3D donne tort à ce raisonnement.
ANGLE_MIN_PARCELLE = 0.0

# Variation de hauteur d'une parcelle autour de celle de son îlot, en niveaux.
# ± 1 suffit à casser le bloc plein sans contredire la donnée.
JEU_NIVEAUX = 1

# ==========================================================================
# 🚶 LE CHEMIN — 🔄 2026-08-14, tranché par l'auteur
# ==========================================================================
#
# LE PROBLÈME QU'IL RÈGLE. Le peigne ne sait pas découper un îlot en L : un L
# n'a pas de fond. Chaque aile est servie par la rue qui la longe, et le coude
# reste une masse que personne ne réclame — elle ressort en cœur qui n'en est
# pas un, ou en parcelle deux fois trop profonde.
#
# 🔴 CE QU'ON N'A PAS FAIT, ET POURQUOI. L'autre remède était de COUPER l'îlot
# en deux. Il a été écarté : l'îlot est l'unité de DÉCISION du jeu — le clic,
# la teinte des calques, l'arbitrage du joueur sont à l'îlot, et `07` met déjà
# toutes les parcelles d'un îlot dans le même groupe pour ça. Couper fabrique
# deux décisions là où il y en a une, renumérote, et fait repasser `03` sur les
# adjacences. Le chemin ne touche à rien de tout ça : 70 îlots restent 70.
#
# CE QUE C'EST, EXACTEMENT :
#   · une LIGNE, dessinée par l'auteur dans la couche `chemins` (level design,
#     comme les listes de `fid` de `02` et la table `TISSU` ci-dessus) ;
#   · PAS un tronçon de route — elle n'entre dans aucun réseau, ni `03`, ni le
#     trafic, ni la hiérarchie. Une venelle n'est pas une rue ;
#   · un COULOIR retiré de l'emprise AVANT le peigne. L'emprise sort alors en
#     deux morceaux, chacun peigné pour son compte, et les deux gardent le même
#     `fid_ilot`. Le couloir lui-même reste une parcelle, d'origine `chemin`.
#
# 🎯 CE QUE ÇA DONNE GRATUITEMENT, ET QUI EST TOUT L'INTÉRÊT : les deux parois
# du couloir sont maintenant du BORD D'EMPRISE, donc `facade_de` les compte
# comme façade et le peigne les sert comme n'importe quelle rue. Le coude a un
# devant et un derrière. Aucune ligne du peigne n'a eu à changer.
#
# ⚠️ CE QUE ÇA COÛTE, ET QU'IL FAUT DIRE : un chemin de 4 m sur 80 prend
# ~320 m² à l'îlot, soit 3 %. La surface de toit baisse d'autant, donc le
# potentiel solaire aussi — marginalement, mais c'est le chiffre en attente.

# La largeur PAR DÉFAUT, quand l'auteur n'en donne pas dans la couche. Elle
# varie de 3 à 5 m — l'auteur a demandé une largeur variable, pas un gabarit —
# et ce qui la fait varier est ce que le chemin dessert :
#   3,0 m  une SENTE entre deux murs de jardin, on y passe à pied
#   5,0 m  une VENELLE où un véhicule de service passe
# Le tissu décide, parce que c'est lui qui dit à quoi ressemble le fond de
# parcelle des deux côtés. La colonne `largeur_m` de la couche prime toujours :
# c'est là que l'auteur corrige, chemin par chemin.
LARGEUR_CHEMIN = {
    "coeur_ancien":       3.0,   # sente entre deux murs, la ville d'avant
    "maisons_de_ville":   3.5,
    "front_commercant":   4.0,   # passage de service derrière les vitrines
    "pavillonnaire":      5.0,   # desserte de lotissement, une voiture passe
}
LARGEUR_CHEMIN_DEFAUT = 4.0

# De combien le couloir déborde au-delà des deux bouts de la ligne.
# 🔴 CE N'EST PAS UNE MARGE DE CONFORT, C'EST CE QUI FAIT QUE LE CHEMIN
# TRAVERSE. L'auteur dessine sur la couche `ilots`, mais la découpe se fait sur
# l'EMPRISE, qui a reculé de la demi-largeur de rue (04b) — donc un bout posé
# sur le bord de l'îlot tombe déjà bien à l'extérieur de l'emprise. Le
# débordement ne sert qu'au cas inverse : un bout posé au jugé un peu EN DEÇÀ
# du bord. Sans lui il resterait une pellicule de terrain devant le chemin, et
# les deux rives ne seraient pas séparées.
# Corollaire à ne pas perdre : un chemin volontairement en CUL-DE-SAC marche
# aussi — il s'arrête où l'auteur l'a arrêté, à un mètre près.
MARGE_CHEMIN = 1.0

# Les origines de parcelle qui ne portent PAS de bâtiment. Elles sortent des
# tableaux de contrôle qui parlent de maisons — sans quoi un chemin de 3 m
# compterait comme une parcelle trop mince, et un cœur d'îlot comme une
# parcelle sans façade.
HORS_BATI = {"coeur", "chemin"}


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
    """Renvoie (liste d'anneaux OU de lignes, offset).

    Polygon/MultiPolygon pour `emprises`, et depuis le 2026-08-14
    LineString/MultiLineString pour `chemins` — une venelle est une ligne, pas
    un anneau. Les deux familles sortent sous la même forme (une liste de
    listes de points) : l'appelant sait ce qu'il a demandé."""
    o = "<" if buf[off] == 1 else ">"
    off += 1
    typ, off = _e(buf, off, o)
    typ %= 1000
    if typ == 2:
        n, off = _e(buf, off, o)
        pts, off = _p(buf, off, o, n)
        return [pts], off
    if typ == 3:
        n, off = _e(buf, off, o)
        anneaux = []
        for _ in range(n):
            m, off = _e(buf, off, o)
            pts, off = _p(buf, off, o, m)
            anneaux.append(pts)
        return anneaux, off
    if typ in (5, 6):                    # Multi- : on met tout à plat
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


# ------------------------------------------- réunir deux parcelles voisines

def _cle(p, grille=1e-4):
    """Clé de sommet au dixième de millimètre. Deux parcelles issues d'une même
    coupe partagent leurs sommets EXACTEMENT (c'est la décision 61) ; la grille
    n'est là que pour absorber le dernier bit du flottant."""
    return (round(p[0] / grille), round(p[1] / grille))


def _aretes_orientees(anneau):
    n = len(anneau)
    return {(_cle(anneau[i]), _cle(anneau[(i + 1) % n])): (anneau[i],
                                                           anneau[(i + 1) % n])
            for i in range(n)}


def _densifier(a, b, tol=1e-6):
    """Insère dans `a` les sommets de `b` qui tombent sur une de ses arêtes.

    🔴 SANS ÇA, LA RÉUNION ÉCHOUE UNE FOIS SUR DEUX, et pas pour la raison
    qu'on croit. Deux voisines partagent bien le même bord, mais pas forcément
    le même nombre de sommets dessus : `nettoyer` retire un sommet aligné d'un
    côté et pas de l'autre, et une coupe peut tomber au milieu de l'arête d'en
    face. Il reste un T — un sommet posé sur une arête sans en être un sommet.
    L'arête ne trouve alors pas son inverse, le bord commun ne s'annule pas, et
    `fusionner` refuse. Mesuré : 26 éclats survivants, dont 18 avaient pourtant
    une voisine franche. On remet donc les sommets manquants des deux côtés
    avant de comparer.
    """
    out = []
    n = len(a)
    for i in range(n):
        p, q = a[i], a[(i + 1) % n]
        out.append(p)
        dx, dy = q[0] - p[0], q[1] - p[1]
        L2 = dx * dx + dy * dy
        if L2 < EPS:
            continue
        sur = []
        for r in b:
            t = ((r[0] - p[0]) * dx + (r[1] - p[1]) * dy) / L2
            if 1e-9 < t < 1.0 - 1e-9 and dist_pt_seg(r, p, q) <= tol:
                sur.append((t, r))
        for _, r in sorted(sur, key=lambda x: x[0]):
            if math.hypot(r[0] - out[-1][0], r[1] - out[-1][1]) > tol:
                out.append(r)
    return out


def _appariees(a, b):
    """Les deux anneaux, chacun densifié des sommets de l'autre."""
    return _densifier(a, b), _densifier(b, a)


def bord_partage(a, b):
    """Longueur du bord que deux parcelles ont en commun.

    Deux voisines le parcourent en sens INVERSE — l'une le descend quand
    l'autre le monte. C'est ce qui permet de les reconnaître sans test
    géométrique : une arête de `a` est partagée si son inverse est dans `b`."""
    a, b = _appariees(a, b)
    eb = _aretes_orientees(b)
    total = 0.0
    for (kp, kq), (p, q) in _aretes_orientees(a).items():
        if (kq, kp) in eb:
            total += math.hypot(q[0] - p[0], q[1] - p[1])
    return total


def fusionner(a, b):
    """Réunit deux parcelles qui partagent un bord. Renvoie None si le résultat
    n'est pas un anneau simple, ou si l'aire ne se conserve pas.

    La méthode : on met bout à bout les arêtes orientées des deux anneaux, on
    ANNULE celles qui vont par paires inverses — c'est le bord commun, qui
    disparaît — et on recoud ce qui reste. Aucune bibliothèque géométrique :
    c'est la même idée que `couper`, prise à l'envers.

    🔴 Le contrôle d'aire à la fin n'est pas une politesse. Si le bord commun
    ne s'annule pas — un T que `_densifier` n'aurait pas rattrapé — le tracé
    ressort faux, l'aire ne tombe pas juste, on renvoie None, et l'appelant
    garde ses deux parcelles séparées. La décision 61 ne peut donc pas tomber
    ici : au pire un éclat survit, et le contrôle le dit.
    """
    a, b = _appariees(a, b)
    aretes = {}
    for anneau in (a, b):
        aretes.update(_aretes_orientees(anneau))

    sortantes = {}
    for (kp, kq), (p, q) in aretes.items():
        if (kq, kp) in aretes:
            continue                       # bord commun : il s'annule
        sortantes.setdefault(kp, []).append((kq, p))
    if not sortantes or any(len(v) != 1 for v in sortantes.values()):
        return None                        # bord commun non contigu

    depart = min(sortantes)
    anneau, k = [], depart
    for _ in range(len(a) + len(b) + 2):
        suite = sortantes.get(k)
        if not suite:
            return None
        kq, p = suite[0]
        anneau.append(p)
        k = kq
        if k == depart:
            break
    else:
        return None
    if k != depart or len(anneau) < 3:
        return None
    if len(anneau) != len(sortantes):
        return None                        # un deuxième anneau traîne

    fusion = nettoyer(anneau)
    if len(fusion) < 3:
        return None
    # ⚠️ LE SEUIL SE LIT EN CENTIMÈTRES CARRÉS, ET C'EST VOULU. Une aire
    # calculée sur des coordonnées à six chiffres (EPSG:25832) porte un bruit
    # de flottant d'environ 2,4·10⁻⁴ m² — mesuré, et reconnaissable : c'est
    # exactement 2⁻¹². Un seuil relatif serré tombait dessus et refusait onze
    # réunions parfaitement justes. Ce qu'on veut attraper ici est un tracé
    # FAUX, qui se trompe d'au moins l'aire de l'éclat, soit des m². Un
    # centimètre carré sépare les deux de deux ordres de grandeur de chaque
    # côté.
    attendu = abs(aire_signee(a)) + abs(aire_signee(b))
    if abs(abs(aire_signee(fusion)) - attendu) > max(1e-2, 1e-7 * attendu):
        return None
    return ouvrir(fusion)


# ------------------------------------------- retirer le couloir d'un chemin

def _cote(morceau, p0, nrm):
    """De quel côté de la droite tombe ce morceau.

    On lit le sommet le plus LOIN de la droite, pas le premier venu : un
    morceau sorti de `couper` a la plupart de ses sommets POSÉS sur la droite,
    et ceux-là ne disent rien. Il est tout entier d'un seul côté, donc le
    sommet le plus éloigné suffit à trancher."""
    d = [(p[0] - p0[0]) * nrm[0] + (p[1] - p0[1]) * nrm[1] for p in morceau]
    return max(d, key=abs) if d else 0.0


def _soustraire_convexe(anneau, demi_plans):
    """Retire d'un anneau l'INTERSECTION de plusieurs demi-plans. Renvoie
    (ce qui reste, la part retirée).

    Le procédé n'a besoin de rien d'autre que `couper`, donc pas d'une
    bibliothèque géométrique : on retranche les demi-plans un par un, et à
    chaque tour ce qui tombe DEHORS est définitivement hors de la région et se
    met de côté. Ce qui survit à tous les demi-plans est l'intersection
    elle-même. La partition (61) tient à chaque étape, puisque `couper` la
    tient.

    Chaque demi-plan est (point, normale), la normale pointant vers
    l'INTÉRIEUR de la région à retirer."""
    dedans = [anneau]
    dehors = []
    for p0, nrm in demi_plans:
        suite = []
        for m in dedans:
            for piece in couper(m, p0, nrm):
                (suite if _cote(piece, p0, nrm) >= 0.0
                 else dehors).append(piece)
        dedans = suite
        if not dedans:
            break
    return dehors, dedans


def _mitre(p, v, q, demi):
    """De combien prolonger les deux tronçons d'un COUDE pour qu'aucun coin ne
    reste entre eux.

    Deux couloirs qui se rejoignent à un angle laissent un triangle non couvert
    du côté extérieur du coude. La pointe de ce triangle est à `demi·tan(φ/2)`
    du sommet le long de chaque tronçon, φ étant l'angle dont la ligne tourne.
    On prolonge donc de ça — le recouvrement des deux couloirs est sans
    conséquence, un morceau déjà retiré ne se retire pas deux fois, alors qu'un
    trou, lui, laisserait un éclat de terrain au milieu de la venelle.

    Le plafond à 4·demi borne le cas du demi-tour, où la formule part à
    l'infini. Un chemin qui se replie à ce point est un défaut de tracé, et le
    contrôle le nomme."""
    ax, ay = v[0] - p[0], v[1] - p[1]
    bx, by = q[0] - v[0], q[1] - v[1]
    na, nb = math.hypot(ax, ay), math.hypot(bx, by)
    if na < EPS or nb < EPS:
        return demi
    cos = max(-1.0, min(1.0, (ax * bx + ay * by) / (na * nb)))
    return min(demi * math.tan(math.acos(cos) / 2.0), 4.0 * demi)


def soustraire_chemin(anneau, ligne, largeur):
    """Retire de `anneau` le couloir de `largeur` centré sur la polyligne
    `ligne`. Renvoie (les morceaux restants, les morceaux du couloir).

    Un tronçon à la fois : son couloir est l'intersection de quatre demi-plans
    (deux parois, deux bouts), donc `_soustraire_convexe` sait le retirer. Ce
    qui reste passe au tronçon suivant."""
    demi = largeur / 2.0
    restants, couloirs = [anneau], []
    n = len(ligne)
    for k in range(n - 1):
        a, b = ligne[k], ligne[k + 1]
        dx, dy = b[0] - a[0], b[1] - a[1]
        L = math.hypot(dx, dy)
        if L < EPS:
            continue
        u = (dx / L, dy / L)
        nrm = (-u[1], u[0])
        # Aux deux extrémités de la LIGNE on déborde de `MARGE_CHEMIN` ; à un
        # coude, de la mitre du coude.
        e0 = MARGE_CHEMIN if k == 0 else _mitre(ligne[k - 1], a, b, demi)
        e1 = (MARGE_CHEMIN if k == n - 2
              else _mitre(a, b, ligne[k + 2], demi))
        hp = [
            ((a[0] + nrm[0] * demi, a[1] + nrm[1] * demi), (-nrm[0], -nrm[1])),
            ((a[0] - nrm[0] * demi, a[1] - nrm[1] * demi), (nrm[0], nrm[1])),
            ((a[0] - u[0] * e0, a[1] - u[1] * e0), u),
            ((b[0] + u[0] * e1, b[1] + u[1] * e1), (-u[0], -u[1])),
        ]
        suite = []
        for m in restants:
            dehors, dedans = _soustraire_convexe(m, hp)
            suite += dehors
            couloirs += dedans
        restants = suite
    return restants, couloirs


def reunir_voisins(morceaux):
    """Recolle les morceaux qui partagent un bord.

    Nécessaire APRÈS le retrait d'un couloir, et pour un seul cas : un chemin
    qui s'arrête AVANT le bord de l'îlot (cul-de-sac) ou qui fait un coude
    laisse derrière son bout un morceau que la coupe du bouchon a séparé, alors
    que le terrain, lui, fait le tour. Sans ce recollage il partirait au peigne
    tout seul et sortirait en éclats.

    Un chemin qui traverse de part en part ne déclenche rien ici : ses deux
    rives ne se touchent nulle part, `bord_partage` vaut zéro, et la boucle ne
    fait qu'un tour à vide."""
    out = [list(m) for m in morceaux]
    change = True
    while change and len(out) > 1:
        change = False
        for i in range(len(out)):
            for j in range(i + 1, len(out)):
                if bord_partage(out[i], out[j]) <= 1e-6:
                    continue
                f = fusionner(out[i], out[j])
                if f is None:
                    continue
                out[i] = f
                del out[j]
                change = True
                break
            if change:
                break
    return out


def retirer_chemins(ext, chemins):
    """L'emprise moins tous ses chemins. Renvoie (morceaux, couloirs).

    Sans chemin, renvoie ([ext], []) — c'est le cas des 70 îlots d'avant le
    2026-08-14, et il ne coûte rien."""
    morceaux, couloirs = [ext], []
    for ligne, largeur in chemins:
        reste = []
        for m in morceaux:
            r, c = soustraire_chemin(m, ligne, largeur)
            reste += r
            couloirs += c
        morceaux = reunir_voisins(reste)
    return morceaux, reunir_voisins(couloirs)


def angle_le_plus_aigu(anneau):
    """Le plus petit angle intérieur de l'anneau, en degrés.

    Se lit sur l'anneau NETTOYÉ : sans ça, deux sommets à trois millimètres l'un
    de l'autre — une coupe en produit à chaque passage — donnent un angle de
    quelques degrés qui n'est pas une pointe, juste du bruit de découpe.
    """
    an = nettoyer(anneau)
    if len(an) < 3:
        return 180.0
    n = len(an)
    pire = 180.0
    for i in range(n):
        p, c, s = an[(i - 1) % n], an[i], an[(i + 1) % n]
        v1 = (p[0] - c[0], p[1] - c[1])
        v2 = (s[0] - c[0], s[1] - c[1])
        n1, n2 = math.hypot(*v1), math.hypot(*v2)
        if n1 < 1e-9 or n2 < 1e-9:
            continue
        cos = max(-1.0, min(1.0, (v1[0] * v2[0] + v1[1] * v2[1]) / (n1 * n2)))
        pire = min(pire, math.degrees(math.acos(cos)))
    return pire


def est_une_cour(anneau):
    """Ce morceau de cœur est-il une COUR, ou une lamelle de découpe ?

    Une seule mesure depuis le 2026-08-14 : LA LARGEUR (voir
    `COEUR_MIN_LARGE`). Assez large pour qu'on y tienne, et la forme ne
    regarde personne — un cœur pointu au fond d'un îlot en éventail est de la
    ville. Ce qui est plus mince que le seuil est rendu aux parcelles de rue au
    lieu de finir en jardin sans façade au milieu des maisons.

    `COEUR_ANGLE_MIN` reste lisible et à zéro : le critère d'angle a existé une
    demi-journée et fabriquait des parcelles de rue trois fois trop grandes."""
    _, _, _, court, _ = rectangle_englobant(anneau)
    return (court >= COEUR_MIN_LARGE
            and (COEUR_ANGLE_MIN <= 0.0
                 or angle_le_plus_aigu(anneau) >= COEUR_ANGLE_MIN))


def trop_petite(anneau, aire_min, largeur_min, angle_min=0.0):
    """Ce qui n'est pas une parcelle : trop peu de surface, trop étroit, OU EN
    POINTE.

    🔴 LE DEUXIÈME CRITÈRE A ÉTÉ AJOUTÉ LE 2026-08-13, ET IL MANQUAIT. Le seuil
    d'aire seul laissait passer les LAMELLES : un reste de bande de 2,2 m de
    large sur 28 m de fond fait 45 m² pile, donc il franchissait `AIRE_MIN` et
    survivait. Ce n'est pas une parcelle, c'est le bout de bande qu'aucune dent
    n'a pu prendre — mesuré, 15 en ville, dont une de 2,2 m.

    La largeur se lit sur le PETIT CÔTÉ de la boîte englobante, et se compare à
    la plus petite des deux consignes du tissu. Sur le petit côté et pas sur la
    façade : une barre de 1970 fait 60 m de rue pour 15 m de fond, son petit
    côté est sa profondeur, et elle est juste.

    🔺 LE TROISIÈME CRITÈRE A ÉTÉ AJOUTÉ LE 2026-08-14, et il manquait aussi.
    Les deux premiers laissent passer LES POINTES : un triangle de 12 × 25 m
    fait 150 m² et son petit côté vaut 12 m, donc il franchit l'aire ET la
    largeur — et c'est quand même un triangle. Mesuré avant correction : 41
    parcelles à trois côtés et 56 portant un angle sous 35°, sur 1 031.
    """
    if abs(aire_signee(anneau)) < aire_min:
        return True
    if largeur_min > 0.0:
        _, _, _, court, _ = rectangle_englobant(anneau)
        if court < largeur_min:
            return True
    return angle_min > 0.0 and angle_le_plus_aigu(anneau) < angle_min


def absorber(parcelles, aire_min, largeur_min=0.0, angle_min=0.0, rendues=()):
    """Les parcelles trop petites sont réunies à une voisine, jusqu'à ce qu'il
    n'en reste plus — c'est le troisième cas du papier (§4.2.3).

    🔄 2026-08-14 : `rendues` est la liste des ORIGINES qu'on réunit quelle que
    soit leur taille. Elle sert aux restes de cœur qui n'en sont pas — le coin
    pointu entre deux rangées non parallèles, et tout ce qui survit dans un
    tissu `SANS_COEUR`. Ces morceaux-là ne sont pas trop petits, ils sont AU
    MAUVAIS ENDROIT : ils repartaient en jardin sans façade au milieu des
    maisons. Réunis, ils allongent le fond de la parcelle de rue voisine.
    Conséquence sur l'origine : une parcelle rendue prend TOUJOURS celle de sa
    voisine, jamais l'inverse — sinon un gros reste avalerait la rangée.

    `parcelles` est une liste de (anneau, origine). On prend la plus petite,
    on cherche la voisine avec qui elle partage LE PLUS LONG BORD (le critère
    du papier : c'est celle contre laquelle elle est le plus franchement
    collée, donc celle avec qui la réunion a la meilleure forme), et on les
    réunit. La parcelle réunie garde l'origine de la plus grande des deux.

    Une petite qu'on ne sait pas réunir est mise de côté et n'est plus
    réessayée : sans ça la boucle tourne sans fin sur le même cas.

    🔴 2026-08-14, DEUXIÈME PASSAGE — UNE PARCELLE NE REÇOIT QU'UN SEUL RESTE.
    Sans ce garde-fou, réunir les restes s'emballait tout seul : la parcelle qui
    venait d'en avaler un devenait plus grande, donc son bord partagé avec le
    reste suivant devenait le plus long, donc elle gagnait encore. Un cœur rendu
    de 741 m² (îlot 33) partait ainsi en entier dans UNE parcelle de 651 m², au
    lieu de s'étaler sur la rangée — trois fois l'aire visée du tissu, et ça se
    voyait sur l'image comme « le cœur d'îlot fusionné avec la parcelle ».
    Mesuré avant : 11 parcelles au-delà de 2× l'aire visée, jusqu'à 3,1×, sur
    les îlots 10, 26, 33, 34, 47, 49, 50, 63, 66 — exactement ceux que l'auteur
    a entourés. Une parcelle déjà servie n'est donc plus candidate tant qu'il en
    reste une qui ne l'est pas."""
    parcelles = list(parcelles)
    renonce = set()
    servies = set()
    fusions = 0
    for _ in range(2 * len(parcelles) + 8):
        petites = [i for i, (p, o) in enumerate(parcelles)
                   if i not in renonce
                   and (o in rendues
                        or trop_petite(p, aire_min, largeur_min, angle_min))]
        if not petites:
            break
        i = min(petites, key=lambda i: abs(aire_signee(parcelles[i][0])))
        rendue = parcelles[i][1] in rendues
        # 🔺 Une parcelle EN POINTE cherche d'abord le cœur d'îlot : « un
        # bâtiment ne peut pas avoir cette forme », donc le biseau repart au
        # jardin plutôt que de gonfler la maison d'à côté. Le cœur absorbe, il
        # ne se fait pas absorber : l'union garde l'origine `coeur`.
        pointue = (not rendue and angle_min > 0.0
                   and angle_le_plus_aigu(parcelles[i][0]) < angle_min)

        def chercher(candidats):
            voisine, meilleur = None, 0.0
            for j in candidats:
                if j == i:
                    continue
                L = bord_partage(parcelles[i][0], parcelles[j][0])
                # à bord égal, on préfère une voisine de même origine : une
                # lanière de rue ne doit pas devenir un bout de jardin.
                if L > meilleur + 1e-9 or (abs(L - meilleur) <= 1e-9 and voisine
                                           is not None
                                           and parcelles[j][1] == parcelles[i][1]):
                    if L > 1e-9:
                        voisine, meilleur = j, L
            return voisine

        # 🔄 Un morceau RENDU cherche d'abord une voisine qui n'en est pas un :
        # le but est qu'il finisse dans une parcelle bâtie, pas qu'il forme un
        # gros paquet de restes entre eux.
        voisine = None
        if rendue:
            # ↓ d'abord celles qui n'ont encore rien reçu : c'est ce qui étale
            # le reste sur la rangée au lieu de le concentrer.
            voisine = chercher([j for j, (_, o) in enumerate(parcelles)
                                if o not in rendues and j not in servies])
            if voisine is None:
                voisine = chercher([j for j, (_, o) in enumerate(parcelles)
                                    if o not in rendues])
        elif pointue:
            voisine = chercher([j for j, (_, o) in enumerate(parcelles)
                                if o == "coeur"])
        if voisine is None:
            voisine = chercher(range(len(parcelles)))
        fusion = fusionner(parcelles[i][0], parcelles[voisine][0]) \
            if voisine is not None else None
        if fusion is None:
            renonce.add(i)
            continue
        if rendue or (pointue and parcelles[voisine][1] == "coeur"):
            origine = parcelles[voisine][1]      # la rendue ne s'impose jamais
        else:
            grande = voisine if abs(aire_signee(parcelles[voisine][0])) \
                >= abs(aire_signee(parcelles[i][0])) else i
            origine = parcelles[grande][1]
        parcelles[voisine] = (fusion, origine)
        if rendue:
            servies.add(voisine)
        del parcelles[i]
        renonce = {r - 1 if r > i else r for r in renonce if r != i}
        servies = {s - 1 if s > i else s for s in servies if s != i}
        fusions += 1
    return parcelles, fusions


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

    ⚠️ MODULER CE DÉBORDEMENT SELON L'ANGLE DU COIN A ÉTÉ ESSAYÉ LE 2026-08-14,
    ET MESURÉ MOINS BON. L'idée était que le forfait `prof` n'est juste qu'au
    coin droit, et qu'au coin RENTRANT la bande déboule à travers le repli en
    taillant la région de l'arête suivante en biseau. C'est vrai, et ça se voit
    sur l'îlot 24 — mais le remède coûte plus qu'il ne rapporte :
      · à la bissectrice exacte, `prof / tan(θ/2)`, les coins obtus ne sont plus
        réclamés par personne : le cœur passe de 72 à 137 morceaux ;
      · en ne coupant qu'aux coins rentrants, les triangles ne reculent PAS
        (41 → 44 à mi-débordement, 47 à zéro) et le cœur passe à 86 morceaux.
    La raison de fond : une bande est ici une intersection de demi-plans, pas
    une cellule de squelette, et deux demi-plans ne se rejoignent pas d'eux-
    mêmes. Les pointes se traitent donc en aval, dans `trop_petite`.

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


def _rayon(ring, p, dirn):
    """Du point `p`, en allant vers `dirn`, la distance au premier bord de
    l'îlot rencontré et l'indice de l'arête touchée. (None, None) si le rayon
    ne sort jamais — impossible sur un anneau fermé, mais le flottant a ses
    jours."""
    n = len(ring)
    meilleur, jbest = None, None
    for j in range(n):
        c, e = ring[j], ring[(j + 1) % n]
        ex, ey = e[0] - c[0], e[1] - c[1]
        den = dirn[0] * ey - dirn[1] * ex
        if abs(den) < 1e-12:
            continue                          # rayon parallèle à l'arête
        wx, wy = c[0] - p[0], c[1] - p[1]
        t = (wx * ey - wy * ex) / den         # le long du rayon
        s = (wx * dirn[1] - wy * dirn[0]) / den   # le long de l'arête
        if t > 1e-6 and -1e-9 <= s <= 1.0 + 1e-9:
            if meilleur is None or t < meilleur:
                meilleur, jbest = t, j
    return meilleur, jbest


def profondeur_utile(ring, a, b, u, nrm, prof, longueurs, sans_coeur=False):
    """De combien de fond cette rue a le droit, sachant ce qu'il y a en face.

    🔴 C'EST LA RÈGLE QUI RÉPARE LES ÎLOTS PEU PROFONDS. On tire une dizaine
    de rayons vers l'intérieur, depuis l'arête, et on regarde où ils ressortent
    et sur quoi :

      · en face, une autre rue, et l'îlot fait moins de `TRAVERSANT` fois la
        profondeur visée → LA PARCELLE TRAVERSE. Cette rue prend tout le fond,
        celle d'en face ne prendra rien, et les parcelles ont deux façades ;
      · en face, une autre rue, et l'îlot est plus profond → ON COUPE AU
        MILIEU : chaque rive prend la moitié, plafonnée à la profondeur visée.
        Au-delà de deux fois la profondeur, le plafond joue et il reste un cœur
        d'îlot, comme avant ;
      · en face, pas de rue (un biseau de coin, une arête trop courte) → cette
        rue prend tout ce qu'elle peut, jusqu'à la profondeur visée.

    🏡 ET SI LE TISSU EST DANS `SANS_COEUR`, LA PROFONDEUR VISÉE N'EST PLUS UN
    PLAFOND. La moitié se prend telle quelle, même si elle dépasse la consigne,
    et l'absence de rue en face donne tout le fond : les deux bandes se
    rejoignent au milieu et aucun cœur n'apparaît. C'est le lotissement — le
    fond du jardin touche le fond du jardin d'en face.

    Les deux rives d'un même îlot mesurent la MÊME distance, puisqu'on la prend
    sur l'anneau d'origine et non sur ce qui reste. Elles tombent donc sur la
    même moitié, et leurs bandes se rejoignent exactement au milieu.

    On prend la MÉDIANE des rayons : sur un îlot en éventail la profondeur
    varie d'un bout à l'autre de la rue, et la médiane évite qu'un seul rayon
    parti de travers commande toute la bande.

    Renvoie (profondeur, mode), le mode étant celui du rayon médian.
    """
    vals = []
    for k in range(9):
        t = 0.15 + 0.70 * k / 8.0
        p = (a[0] + (b[0] - a[0]) * t + nrm[0] * 1e-6,
             a[1] + (b[1] - a[1]) * t + nrm[1] * 1e-6)
        d, j = _rayon(ring, p, nrm)
        if d is None or d <= EPS:
            continue
        en_face_une_rue = longueurs[j] >= LONGUEUR_MIN_RUE
        if en_face_une_rue and d < TRAVERSANT * prof:
            vals.append((d, "traversante"))       # on prend tout le fond
        elif en_face_une_rue and (sans_coeur or d / 2.0 < prof):
            vals.append((d / 2.0, "moitie"))      # on coupe au milieu
        elif sans_coeur:
            vals.append((d, "pleine"))            # personne en face : tout
        else:
            vals.append((min(prof, d), "pleine")) # la profondeur visée suffit
    if not vals:
        return prof, "pleine"
    return sorted(vals)[len(vals) // 2]


def _dents(morceaux, a, u, facade, prof):
    """La bande se débite en dents perpendiculaires à la rue.

    Le nombre de dents vient de la LARGEUR sur rue, pas de l'aire : c'est toute
    la différence avec `subdiviser`, et c'est ce qui fait que `facade` veut
    enfin dire façade. Trois bornes l'encadrent, dans cet ordre :
      · la façade visée décide du nombre ;
      · une dent trop lourde en fait ajouter une (le `Amax` du papier) ;
      · une dent trop étroite en fait retirer une (le plancher `DENT_MIN`),
        ce qui évite de fabriquer un éclat qu'il faudrait recoller après coup.

    🔴 2026-08-14 — UNE SEULE GRILLE DE DENTS POUR TOUTE LA BANDE, demandé par
    l'auteur devant l'îlot 63 redessiné à la main. Une bande sort souvent en
    PLUSIEURS morceaux (l'emprise est concave, un repli la coupe en deux), et
    chaque morceau était débité pour son compte : un morceau de 12 m recevait
    une dent, celui de 40 m en recevait trois, et la rangée sortait en dents de
    scie — des parcelles deux fois trop larges à côté de parcelles justes. Les
    coupes se calculent maintenant sur la LONGUEUR TOTALE de la bande, puis
    s'appliquent à tous les morceaux : le rythme des façades est le même d'un
    bout à l'autre de la rue, comme sur le dessin de l'auteur.
    """
    morceaux = [m for m in morceaux if len(m) >= 3]
    if not morceaux:
        return []
    ds = sorted((p[0] - a[0]) * u[0] + (p[1] - a[1]) * u[1]
                for m in morceaux for p in m)
    span = ds[-1] - ds[0]
    aire = sum(abs(aire_signee(m)) for m in morceaux)
    if span < EPS:
        return list(morceaux)

    k = max(1, int(round(span / facade)))
    k = max(k, int(math.ceil(aire / (DENT_MAX * facade * prof))))
    k = min(k, max(1, int(span / (facade * DENT_MIN))),
               max(1, int(aire / AIRE_MIN)))
    k = max(1, k)

    def debiter(k):
        # 🔴 LE JEU DE COUPE EST BORNÉ PAR LE PLANCHER DE LARGEUR. Deux coupes
        # voisines se décalent indépendamment : sans borne, elles peuvent se
        # rapprocher de deux fois le jeu et fabriquer une dent deux fois trop
        # étroite. Mesuré avant correction : 2,2 m de large en pavillonnaire
        # pour 13,5 visés. On limite donc l'amplitude à la moitié de ce qui
        # dépasse du plancher — chaque dent reste alors au-dessus.
        pas = span / k
        plancher = min(pas * 0.999, facade * DENT_MIN)
        ampl = min(JEU * pas, max(0.0, (pas - plancher) / 2.0))
        pieces = list(morceaux)
        for j in range(1, k):
            t = ds[0] + span * j / k
            # Le décalage se tire de la POSITION de la coupe, pas de son rang :
            # la décision 35, appliquée à la coupe et pas qu'à la parcelle.
            g = graine_de([(a[0] + u[0] * t, a[1] + u[1] * t)])
            t += ((g % 1000) / 1000.0 - 0.5) * 2.0 * ampl
            p0 = (a[0] + u[0] * t, a[1] + u[1] * t)
            suite = []
            for m in pieces:
                suite += couper(m, p0, u)
            pieces = suite
        return [p for p in pieces if len(p) >= 3 and abs(aire_signee(p)) > 1e-6]

    # Une dent trop maigre se rattrape en amont quand c'est possible : on
    # refait la bande avec une dent de moins, ce qui vaut mieux que de la
    # fabriquer puis de la recoller. Ce qui survit à ça part dans `absorber`.
    #
    # 🔴 2026-08-14 — LE CRITÈRE SE LIT EN SURFACE, PLUS « AUCUNE DENT MAIGRE ».
    # Depuis que la grille est commune à toute la bande, une coupe tombe parfois
    # au bout d'un morceau et y laisse un éclat : exiger que TOUTES les dents
    # passent faisait alors retirer trois dents à la rangée entière pour un
    # éclat de 20 m². Mesuré sur l'îlot 63 : 18 parcelles au lieu de 26, dont
    # des pavillons de 1 200 m². On accepte donc tant que les éclats pèsent
    # moins d'un vingtième de la bande — `absorber` les recolle ensuite, et le
    # contrôle « aucun ne survit » le prouve.
    for essai in range(4):
        pieces = debiter(max(1, k - essai))
        maigre = sum(abs(aire_signee(p)) for p in pieces
                     if abs(aire_signee(p)) < AIRE_MIN)
        if k - essai <= 1 or maigre <= 0.05 * aire:
            return pieces
    return pieces


def peigne(anneau, facade, prof, sans_coeur=False):
    """Découpe un îlot depuis ses rues. Renvoie (parcelles sur rue, cœur,
    le compte rendu des bandes).

    Les arêtes sont servies de la plus longue à la plus courte. Chacune
    demande d'abord DE QUELLE PROFONDEUR ELLE A LE DROIT (`profondeur_utile`,
    la règle du traversant), prend sa bande dans ce qui reste, et la débite.
    Ce qu'aucune n'a réclamé est le cœur d'îlot — un seul morceau en général,
    et c'est le but.

    Aucun morceau n'est jeté en route : tout ce qui sort d'une coupe part soit
    dans les dents, soit dans le reste. C'est ce qui fait tenir la décision 61
    sans avoir à la rattraper.
    """
    ring = ouvrir(anneau)
    n = len(ring)
    reste = [ring]
    rue = []
    bandes = []

    longueurs = [math.hypot(ring[(i + 1) % n][0] - ring[i][0],
                            ring[(i + 1) % n][1] - ring[i][1]) for i in range(n)]

    # À longueur égale, l'indice départage : deux arêtes jumelles ne doivent
    # pas changer d'ordre d'une exécution à l'autre.
    for i in sorted(range(n), key=lambda i: (-longueurs[i], i)):
        if not reste:
            break
        a, b = ring[i], ring[(i + 1) % n]
        L = longueurs[i]
        if L < LONGUEUR_MIN_RUE:
            continue
        u = ((b[0] - a[0]) / L, (b[1] - a[1]) / L)
        nrm = (-u[1], u[0])          # `ouvrir` rend l'anneau trigo : à gauche
        pe, mode = profondeur_utile(ring, a, b, u, nrm, prof, longueurs,
                                    sans_coeur)
        if pe < AIRE_MIN / max(L, 1.0):
            continue                 # il ne reste rien de bâtissable en face
        bande, loin = _bande(reste, a, b, u, nrm, pe, L)
        d = _dents(bande, a, u, facade, pe)
        rue += d
        nd = len(d)
        if nd:
            bandes.append((L, pe, mode, nd))
        reste = loin

    return (rue,
            [m for m in reste if len(m) >= 3 and abs(aire_signee(m)) > 1e-6],
            bandes)


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

def decouper_ilot(ext, st, chemins=()):
    """L'emprise d'un îlot → ses parcelles. LE CŒUR DU FICHIER.

    Renvoie (parcelles, compte rendu). Chaque parcelle est un triplet
    (anneau, origine, index de bord) — l'index est celui du MORCEAU d'emprise
    dont elle sort, et c'est lui qui décide de ce qui compte comme façade.

    🔄 2026-08-14 : extrait de `main`, et pas pour la beauté du geste.
    `tracer_chemins.py` a besoin de découper le MÊME îlot deux fois — avec et
    sans un tracé candidat — pour dire si la venelle rend les parcelles plus
    rectangulaires ou non. Deux découpes qui ne seraient pas rigoureusement le
    même code ne prouveraient rien.
    """
    facade, prof, style = TISSU[st]
    sans_coeur = st in SANS_COEUR
    cr_rives = {}
    n_fusions = 0
    # 🚶 LE CHEMIN PASSE AVANT TOUT LE RESTE. Le couloir sort de l'emprise,
    # et l'îlot part au peigne en DEUX MORCEAUX au lieu d'un. Chaque
    # morceau est peigné pour son compte — donc les parois du couloir sont
    # du bord d'emprise pour lui, donc elles portent des façades — et les
    # deux gardent le même `fid_ilot` : un seul îlot, une seule décision.
    # Sans chemin, `morceaux` vaut [ext] et rien ne change.
    morceaux, couloirs = retirer_chemins(ext, chemins)

    parcelles_ilot = []
    rive_ilot = {}
    n_cours = n_parts_coeur = n_rendus = n_replis = 0
    aire_coeur = 0.0

  # ↓ un tour par morceau d'emprise — un seul quand l'îlot n'a pas de chemin
    for ext_m in morceaux:
        sans_coeur = st in SANS_COEUR
        if style == "peigne":
            rue, coeur, bandes = peigne(ext_m, facade, prof, sans_coeur)
            # ⚠️ 2026-08-14 — CE QUI A ÉTÉ ESSAYÉ ICI ET RETIRÉ, pour ne pas le
            # réintroduire : quand aucun morceau n'était une cour, on
            # repeignait l'îlot SANS plafond de profondeur, comme un
            # lotissement, pour que les deux rives se rejoignent au milieu et
            # qu'il ne reste rien. L'image était propre — et c'était l'inverse
            # de ce que l'auteur a demandé le jour même : « pour les grands
            # îlots, les parcelles vont seulement une certaine profondeur
            # jusqu'au centre ; la surface qui reste est un cœur d'îlot ». Le
            # plafond de profondeur reste donc un plafond, et ce qui reste
            # derrière les parcelles reste un cœur.
            for L, pe, mode, nd in bandes:
                r = cr_rives.setdefault(mode, [0, 0, 0.0])
                r[0] += 1
                r[1] += nd
                r[2] += pe * nd
                rive_ilot[mode] = rive_ilot.get(mode, 0) + 1
            # 🌳 UN CŒUR D'ÎLOT NE SE DÉCOUPE PAS, ET IL PEUT AVOIR N'IMPORTE
            # QUELLE FORME — 🔄 2026-08-14, tranché par l'auteur. Il sort
            # d'un seul tenant, tel que le peigne l'a laissé.
            #
            # 🔴 Ce que ça retire, et qu'il faut assumer : le cœur repassait
            # par la boîte, et `07` tirait ensuite cour pavée / jardin planté
            # morceau par morceau. Un cœur entier se tire donc EN UNE FOIS —
            # une cour est toute pavée ou toute plantée, plus de damier. La
            # proportion de gris de 42c reste tenue par le nombre de cœurs et
            # par les fonds de parcelle, qui sont bien plus nombreux qu'eux.
            #
            # 🔄 Et TOUT MORCEAU DE CŒUR N'EST PAS UN CŒUR. Deux cas le
            # disqualifient, et il repart alors en « rendu » — un morceau
            # qu'`absorber` recollera à la parcelle de rue voisine :
            #   · le tissu est dans `SANS_COEUR` (le pavillonnaire) : il ne
            #     doit RIEN rester entre les deux rangées ;
            #   · le morceau est plus mince que `COEUR_MIN_LARGE` : c'est le
            #     coin pointu entre deux rangées non parallèles, pas une
            #     cour.
            # Celui-là, en revanche, est BIEN redécoupé avant d'être rendu :
            # un long reste doit se redistribuer sur plusieurs parcelles de
            # rue au lieu d'en gonfler une seule.
            parcelles = [(p, "rue") for p in rue]
            for c in coeur:
                if sans_coeur or not est_une_cour(c):
                    bouts = subdiviser(c, facade, prof)
                    parcelles += [(p, "rendu") for p in bouts]
                    n_rendus += len(bouts)
                else:
                    parcelles.append((ouvrir(c), "coeur"))
                    aire_coeur += abs(aire_signee(c))
                    n_cours += 1
                    n_parts_coeur += 1

            # Le filet : si le peigne rate sa propre partition, le morceau
            # repart ENTIER dans la boîte et le contrôle le nomme. 43 des
            # 69 emprises sont concaves — le peigne n'en a fait tomber
            # aucune, mais on ne livre pas une méthode géométrique sans son
            # repli.
            aire_m = abs(aire_signee(ext_m))
            somme = sum(abs(aire_signee(p)) for p, _ in parcelles)
            if not parcelles or (aire_m
                                 and abs(somme - aire_m) > 1e-5 * aire_m):
                n_replis += 1
                parcelles = [(p, "boite")
                             for p in subdiviser(ext_m, facade, prof)]
        else:
            parcelles = [(p, "boite")
                         for p in subdiviser(ext_m, facade, prof)]

        # ✂️ LES TROP PETITES SONT RÉUNIES À UNE VOISINE (papier §4.2.3).
        # Après le peigne comme après la boîte : un éclat de 4 m² n'est pas
        # une parcelle, et il donnerait une maison impossible ou un jardin
        # invisible. La largeur plancher se lit sur la plus PETITE des deux
        # consignes du tissu : c'est le côté court de la parcelle voulue, et
        # une parcelle plus mince que ça est une lamelle, pas un terrain.
        # 🔺 Et la POINTE est réunie de la même façon : c'est le troisième
        # critère de `trop_petite`, ajouté le 2026-08-14.
        # 🔄 Et les morceaux « rendu » sont réunis quelle que soit leur
        # taille : ce ne sont pas des éclats, ce sont des restes de cœur qui
        # n'avaient rien à faire là (`SANS_COEUR`, `COEUR_MIN_LARGE`).
        largeur_min = DENT_MIN * min(facade, prof)
        parcelles, n_f = absorber(parcelles, AIRE_MIN, largeur_min,
                                  ANGLE_MIN_PARCELLE, rendues={"rendu"})
        n_fusions += n_f

        # 🚪 DEUXIÈME PASSE — 🔄 2026-08-14, ET C'EST ELLE QUI EFFACE LE
        # VERT QUI RESTAIT ENTRE LES MAISONS.
        #
        # Une parcelle de bande peut se retrouver DERRIÈRE une autre : la
        # bande est bornée par trois demi-plans, pas par la rue elle-même,
        # donc le fond d'une bande profonde peut sortir en morceau séparé
        # qui ne touche plus le bord de l'îlot. Elle n'est ni un éclat
        # (532 m² sur l'îlot 63) ni un cœur — c'est un fond de jardin
        # orphelin, et `07` en ferait un jardin au milieu d'une rangée de
        # maisons.
        #
        # La règle se lit maintenant sur le résultat et non sur
        # l'intention : toute parcelle qui n'est pas de cœur et qui n'a
        # AUCUNE façade est rendue à sa voisine. On recommence tant qu'il en
        # apparaît, trois fois au plus — une réunion peut en démasquer une
        # autre.
        #
        # 🚶 L'index se lit sur `ext_m`, LE MORCEAU, et pas sur l'emprise
        # entière : c'est ce qui fait qu'une paroi de chemin compte comme
        # une façade. Sans ça toute la rangée qui donne sur la venelle
        # serait déclarée enclavée, puis rendue, puis avalée.
        idx = indexer_bord(ext_m)
        for _ in range(3):
            marquees = [(p, "rendu" if o != "coeur"
                         and facade_de(p, idx) <= 0.5 else o)
                        for p, o in parcelles]
            if not any(o == "rendu" for _, o in marquees):
                break
            marquees, n_f = absorber(marquees, AIRE_MIN, largeur_min,
                                     ANGLE_MIN_PARCELLE, rendues={"rendu"})
            n_fusions += n_f
            parcelles = marquees
            if not n_f:
                break

        # Ce qui n'a jamais trouvé de voisine reste un fond sans façade : on
        # le range avec les cœurs, et le contrôle plus bas le compte comme
        # un reliquat, pas comme un résultat.
        parcelles = [(p, "coeur" if o == "rendu" else o)
                     for p, o in parcelles]
        parcelles_ilot += [(p, o, idx) for p, o in parcelles]

    # ← fin du tour par morceau : l'îlot se recompose ici

    # Le couloir n'est pas un déchet : il RESTE dans la partition, en
    # parcelle d'origine `chemin`. Deux raisons, et la seconde compte plus
    # que la première : `07` a besoin de sa géométrie pour poser le pavé au
    # sol, et le contrôle de partition (61) reste une égalité à 100 % de
    # l'emprise au lieu de devenir « 100 % moins ce qu'on a enlevé » — un
    # contrôle qu'on affaiblit est un contrôle qui ne prouve plus rien.
    idx_ilot = indexer_bord(ext)
    parcelles_ilot += [(c, "chemin", idx_ilot) for c in couloirs]
    return parcelles_ilot, {
        "morceaux": morceaux, "couloirs": couloirs, "rives": cr_rives,
        "modes": rive_ilot, "cours": n_cours, "parts_coeur": n_parts_coeur,
        "aire_coeur": aire_coeur, "rendus": n_rendus, "replis": n_replis,
        "fusions": n_fusions,
    }



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


def lire_chemins(con, ilots):
    """Les venelles dessinées dans les îlots. Renvoie {fid_ilot: [(ligne,
    largeur), …]}.

    🔴 LA COUCHE EST FACULTATIVE, et ce n'est pas une politesse : elle vit dans
    `Vallmar2.gpkg`, la source que l'auteur édite dans QGIS, et elle arrive ici
    par la copie que fait `02`. Une carte sans chemin doit sortir exactement
    comme avant le 2026-08-14.

    La largeur vient de la couche quand l'auteur l'a fixée ; sinon de
    `LARGEUR_CHEMIN`, par tissu. Une largeur hors de [3, 5] est gardée telle
    quelle — c'est du level design, pas une erreur — mais le contrôle la
    signale."""
    if con.execute("SELECT count(*) FROM sqlite_master WHERE type='table'"
                   " AND name='chemins'").fetchone()[0] == 0:
        return {}
    cols = {r[1] for r in con.execute("PRAGMA table_info(chemins)")}
    if "fid_ilot" not in cols:
        raise SystemExit("la couche `chemins` n'a pas de colonne `fid_ilot` —"
                         " chaque chemin doit dire à quel îlot il appartient")
    larg_col = "largeur_m" if "largeur_m" in cols else "NULL"
    out = {}
    orphelins = []
    for fid, larg, geom in con.execute(
        "SELECT fid_ilot, %s, geom FROM chemins ORDER BY fid" % larg_col
    ):
        if geom is None:
            continue
        if fid not in ilots:
            # ⚠️ LE PIÈGE QUI ARRIVERA UN JOUR : `00_decouper_ilots.py` donne
            # un numéro NEUF à la plus petite moitié d'un îlot coupé. Un chemin
            # dessiné avant ce découpage garde l'ancien numéro et se retrouve
            # orphelin. Il serait alors ignoré en silence, et personne ne
            # comprendrait pourquoi la venelle a disparu de la carte.
            orphelins.append(fid)
            continue
        st = ilots[fid]["st"]
        if not larg or larg <= 0.0:
            larg = LARGEUR_CHEMIN.get(st, LARGEUR_CHEMIN_DEFAUT)
        for ligne in lire_wkb(gpkg_vers_wkb(geom))[0]:
            if len(ligne) >= 2:
                out.setdefault(fid, []).append((ligne, float(larg)))
    if orphelins:
        print("  ⚠️  %d chemin(s) désignent un îlot qui n'existe pas : %s"
              % (len(orphelins), ", ".join(str(f) for f in sorted(
                  set(orphelins)))))
        print("      → le découpage des îlots a bougé depuis le tracé."
              " Corriger `fid_ilot` dans la couche `chemins`.")
        print()
    return out


def main():
    if not os.path.exists(GPKG):
        raise SystemExit("introuvable : %s" % GPKG)
    con = sqlite3.connect("file:%s?mode=ro" % GPKG.replace("\\", "/"), uri=True)
    ilots = lire(con)
    chemins = lire_chemins(con, ilots)
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
    rendus = []
    rives = {}
    traversants = []
    traces = []                 # 🚶 un par îlot qui porte un chemin
    n_fusions = 0

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

        # 🚶 LE CHEMIN PASSE AVANT TOUT LE RESTE. Le couloir sort de
        # l'emprise, et l'îlot part au peigne en DEUX MORCEAUX au lieu d'un.
        # Les deux gardent le même `fid_ilot` : un seul îlot, une seule
        # décision pour le joueur. Toute la mécanique est dans
        # `decouper_ilot`, pour que `tracer_chemins.py` la rejoue à
        # l'identique quand il évalue un tracé candidat.
        parcelles_ilot, cr = decouper_ilot(ext, st, chemins.get(fid, ()))
        if fid in chemins:
            traces.append((fid, st, chemins[fid], cr["morceaux"],
                           cr["couloirs"]))
        for mode, v in cr["rives"].items():
            r = rives.setdefault(st, {}).setdefault(mode, [0, 0, 0.0])
            r[0] += v[0]
            r[1] += v[1]
            r[2] += v[2]
        n_fusions += cr["fusions"]

        if cr["modes"]:
            traversants.append((fid, st,
                                max(cr["modes"], key=lambda k: cr["modes"][k])))
        if cr["rendus"]:
            rendus.append((fid, st, cr["rendus"]))
        if cr["replis"]:
            replis.append((fid, st, cr["replis"]))
        elif style == "peigne":
            coeurs.append((fid, st, cr["cours"], cr["aire_coeur"],
                           cr["parts_coeur"]))

        # 🔴 LE CONTRÔLE QUI COMMANDE TOUT LE FICHIER (décision 61).
        somme = sum(abs(aire_signee(p)) for p, _, _ in parcelles_ilot)
        ecarts.append((abs(somme - aire0) / aire0 if aire0 else 0.0, fid, st,
                       len(parcelles_ilot), aire0, somme))

        for p, origine, idx in parcelles_ilot:
            per = perimetre(p)
            fac = facade_de(p, idx)
            g = graine_de(p)
            _, _, long_axe, court_axe, _ = rectangle_englobant(p)
            # ± JEU_NIVEAUX autour de la hauteur de l'îlot, tiré de la graine
            # de la parcelle : deux parcelles voisines ne montent pas pareil,
            # et une parcelle garde sa hauteur quand sa voisine change.
            # Un chemin ne monte pas : c'est un sol.
            niv = d["haut"] + ((g >> 5) % (2 * JEU_NIVEAUX + 1)) - JEU_NIVEAUX
            resultats.append({
                "fid_ilot": fid, "st": st, "anneau": p,
                "aire": abs(aire_signee(p)), "perim": per, "facade": fac,
                "mitoyen": max(0.0, per - fac), "graine": g,
                "niveaux": 0.0 if origine == "chemin" else max(1.0, niv),
                "origine": origine,
                "elan": long_axe / max(court_axe, 0.01), "large": court_axe,
            })
        par_st.setdefault(st, []).append(
            (fid, sum(1 for _, o, _ in parcelles_ilot if o != "chemin"), aire0))

    # ------------------------------------------------------------- contrôles
    print("  LE DÉCOUPAGE, PAR TISSU")
    print("  %-22s %5s %8s %9s %9s %8s" % ("sous_type", "îlots", "parcelles",
                                           "aire moy", "façade moy", "mitoyen"))
    print("  " + "-" * 70)
    total = 0
    for st in sorted(par_st, key=lambda k: -sum(n for _, n, _ in par_st[k])):
        # 🚶 les chemins sortent de ce tableau : ils ont leur bloc à eux plus
        # bas, et une venelle de 3 m tirerait l'aire moyenne vers le bas comme
        # si le tissu avait changé.
        lot = [r for r in resultats
               if r["st"] == st and r["origine"] != "chemin"]
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
        lot = [r for r in resultats
               if r["st"] == st and r["origine"] not in HORS_BATI]
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
        lot = [r for r in resultats
               if r["st"] == st and r["origine"] not in HORS_BATI]
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
    bati = [r for r in resultats if r["origine"] != "chemin"]
    tous = len(bati)
    tous_enc = sum(1 for r in bati if r["facade"] <= 0.5)
    print()
    print("     Sur les %d parcelles de la ville, cœurs compris, %d n'ont pas"
          " de façade" % (tous, tous_enc))
    print("     (%.0f %%) : %d de cœur, voulues, et %d de rue, qui sont le"
          " vrai reliquat." % (100.0 * tous_enc / max(tous, 1),
                               tous_enc - n_enc, n_enc))
    print("     %d parcelles porteront une maison." % (tous - tous_enc))
    print()

    # ── la règle du traversant ────────────────────────────────────────────
    if rives:
        print("  ↔️  LA PROFONDEUR, RIVE PAR RIVE. Chaque rue demande d'abord de")
        print("     quel fond elle a le droit, selon ce qu'il y a en face :")
        print("       pleine      la profondeur visée tient, il restera un cœur")
        print("       moitié      une rue en face et pas la place de deux rangées")
        print("                   pleines : chacune prend la moitié du fond")
        print("       traversante l'îlot est trop mince pour deux rangées : une")
        print("                   seule, qui donne sur les DEUX rues")
        print()
        print("  %-20s %-12s %6s %9s %10s %8s" % ("sous_type", "mode", "rives",
                                                  "parcelles", "prof. moy",
                                                  "visée"))
        print("  " + "-" * 70)
        for st in sorted(rives, key=lambda k: -sum(v[1] for v in rives[k].values())):
            fc, pr, _ = TISSU[st]
            for mode in ("pleine", "moitie", "traversante"):
                if mode not in rives[st]:
                    continue
                nb, np_, sp = rives[st][mode]
                print("  %-20s %-12s %6d %9d %8.1f m %6.1f m"
                      % (st, mode, nb, np_, sp / max(np_, 1), pr))
        print("  " + "-" * 70)
        tr = [f for f, _, m in traversants if m == "traversante"]
        mo = [f for f, _, m in traversants if m == "moitie"]
        print("     %d îlot(s) surtout traversant(s)%s"
              % (len(tr), (" : " + ", ".join(str(f) for f in tr[:14])) if tr else ""))
        print("     %d îlot(s) surtout coupé(s) au milieu%s"
              % (len(mo), (" : " + ", ".join(str(f) for f in mo[:14])) if mo else ""))
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
        print("     laissés d'un seul tenant, tels que le peigne les a")
        print("     découpés — un cœur peut avoir n'importe quelle forme,")
        print("     il ne se reparcelle pas (tranché le 2026-08-14)")
        sans = [f for f, _, nc, _, _ in coeurs if not nc]
        if sans:
            print("     %d îlots sans cœur — soit un tissu SANS_COEUR, soit des"
                  " bandes qui se rejoignent : %s"
                  % (len(sans), ", ".join(str(f) for f in sans[:12])))
        print()

    if rendus:
        print("  🏡 LES RESTES RENDUS AUX PARCELLES DE RUE — ce qui aurait fini")
        print("     en jardin sans façade au milieu des maisons, et qui allonge")
        print("     maintenant le fond de la parcelle voisine.")
        print("       · tissu SANS_COEUR (%s) : rien ne doit rester entre les"
              % ", ".join(sorted(SANS_COEUR)))
        print("         deux rangées, la parcelle va d'une rue au fond du jardin")
        print("       · morceau plus mince que %.0f m (`COEUR_MIN_LARGE`) ou"
              % COEUR_MIN_LARGE)
        print("         pointant sous %.0f° (`COEUR_ANGLE_MIN`) : ce n'est pas"
              % COEUR_ANGLE_MIN)
        print("         une cour, c'est le coin entre deux rangées non parallèles")
        print()
        par = {}
        for fid, st, n in rendus:
            e = par.setdefault(st, [0, 0])
            e[0] += 1
            e[1] += n
        print("  %-22s %8s %10s" % ("sous_type", "îlots", "morceaux"))
        print("  " + "-" * 44)
        for st in sorted(par, key=lambda k: -par[k][1]):
            print("  %-22s %8d %10d" % (st, par[st][0], par[st][1]))
        print("  " + "-" * 44)
        print()

    # ── les chemins ───────────────────────────────────────────────────────
    if traces:
        print("  🚶 LES CHEMINS — la venelle dessinée DANS l'îlot.")
        print("     Elle n'est pas un tronçon de route : elle n'entre dans")
        print("     aucun réseau, ni `03`, ni le trafic. Elle coupe l'emprise")
        print("     en deux morceaux qui gardent le MÊME numéro d'îlot — un")
        print("     seul îlot, une seule décision pour le joueur.")
        print("     Ce qu'elle achète : ses deux parois sont du bord")
        print("     d'emprise, donc le peigne les sert comme une rue. Le coude")
        print("     d'un îlot en L a enfin un devant et un derrière.")
        print()
        print("  %-5s %-20s %5s %7s %8s %9s %6s %8s"
              % ("îlot", "sous_type", "trait", "long.", "largeur", "surface",
                 "part", "morceaux"))
        print("  " + "-" * 74)
        aire_tot = long_tot = 0.0
        for fid, st, lignes, morceaux, couloirs in traces:
            long_c = sum(math.hypot(l[k + 1][0] - l[k][0], l[k + 1][1] - l[k][1])
                         for l, _ in lignes for k in range(len(l) - 1))
            aire_c = sum(abs(aire_signee(c)) for c in couloirs)
            aire_i = aire_c + sum(abs(aire_signee(m)) for m in morceaux)
            largs = sorted({round(w, 1) for _, w in lignes})
            aire_tot += aire_c
            long_tot += long_c
            # ⚠️ un chemin qui ne coupe rien laisse UN seul morceau : le tracé
            # ne traverse pas l'emprise, ou il longe un bord au lieu de le
            # franchir. C'est un défaut de level design, pas de code.
            marque = "" if len(morceaux) >= 2 else "  ⚠️ ne coupe pas"
            print("  %-5d %-20s %5d %6.0f m %6s m %7.0f m² %5.1f %% %6d%s"
                  % (fid, st, len(lignes), long_c,
                     "/".join("%.1f" % w for w in largs), aire_c,
                     100.0 * aire_c / max(aire_i, 1.0), len(morceaux), marque))
        print("  " + "-" * 74)
        print("     %d chemin(s) sur %d îlot(s), %.0f m en tout, %.0f m² pris"
              " à la ville" % (sum(len(l) for _, _, l, _, _ in traces),
                               len(traces), long_tot, aire_tot))
        print("     — soit %.2f ha de toit en moins pour le solaire."
              % (aire_tot / 1e4))
        hors = sorted({round(w, 1) for _, _, l, _, _ in traces for _, w in l
                       if w < 3.0 or w > 5.0})
        if hors:
            print("     ⚠️ largeur(s) hors de la fourchette 3–5 m : %s"
                  % ", ".join("%.1f m" % w for w in hors))
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

    # 🚶 un chemin est plus mince que n'importe quel plancher de parcelle — 3 m
    # là où le cœur ancien en demande 4,2 — et c'est voulu : ce n'est pas une
    # parcelle. Il sort de ce contrôle, sinon il s'y compte en éclat survivant.
    eclats = [r for r in resultats
              if r["origine"] != "chemin"
              and (r["aire"] < AIRE_MIN or r["large"] < DENT_MIN
                   * min(TISSU[r["st"]][0], TISSU[r["st"]][1]))]
    print("  ✂️  LES ÉCLATS ET LES LAMELLES — sous %.0f m² (`AIRE_MIN`), ou plus"
          " minces que" % AIRE_MIN)
    print("     %.0f %% du petit côté voulu (`DENT_MIN`) : ni l'un ni l'autre"
          " n'est une parcelle." % (100 * DENT_MIN))
    print("     %d ont été réunies à leur voisine de plus long bord, comme le"
          " veut le papier (§4.2.3)." % n_fusions)
    if not eclats:
        print("     ✅ aucune ne survit.")
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
