#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
04d — L'emprise du bâtiment dans la parcelle.

    python3 QGIS/scripts/04d_emprises_batiments.py --blanc   # ne rien écrire
    python3 QGIS/scripts/04d_emprises_batiments.py           # écrire la couche
    python3 QGIS/scripts/04d_emprises_batiments.py copie.gpkg

Écrit une couche `batiments` : les empreintes au sol des parcelles bâties. Une
par parcelle en général, DEUX sur une parcelle traversante (voir `bande_sur_rue`).

🔴 LA RÈGLE MÈRE, DEPUIS LE 2026-08-17 : LE BÂTIMENT N'EST PAS LA PARCELLE.
C'est une BANDE mesurée depuis chaque limite sur rue, d'une profondeur donnée par
le tissu (10 à 16 m en cœur ancien), et tout ce qui reste derrière est cour ou
jardin. Avant, l'empreinte d'un tissu mitoyen était la parcelle moins ses
retraits : le cœur ancien couvrait 96 % de son terrain, et la ville se lisait
comme une mosaïque de polygones extrudés. Elle en couvre 76 %, et chaque îlot
dense a maintenant un cœur qui se voit. → `TISSU`, `bande_sur_rue`

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
d'emprise au sol par tissu, la maison détachée ramenée à un rectangle, et la
bande constructible ci-dessus.

✅ LA CHAÎNE EST 02 → 03 → 04 → 04b → 04c → 04d, et `chaine.py` la tient.
   Idempotent : on le relance, il refait la couche.

✅ Depuis le 2026-08-17, `07_exporter_godot.py` lit cette couche directement :
l'aperçu 2D et Godot montrent les mêmes empreintes. 07 retrouve la plus longue
façade de la parcelle pour orienter le faîtage, et dessine la parcelle sous les
volumes pour que sa part non bâtie reste visible en cour ou jardin. Sa vieille
recette géométrique reste nommée comme retour en arrière, mais n'est plus appelée.

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
    "coeur_ancien":        (0.5,  0.0,  0.0,  None,  13.0,  0.80, MITOYEN),
    "maisons_de_ville":    (1.5,  0.0,  5.0,  None,  11.5,  0.65, MITOYEN),
    "front_commercant":    (0.0,  0.0,  3.0,  None,  16.0,  0.85, MITOYEN),
    "pavillonnaire":       (4.0,  3.0,  3.0,   9.0,  10.0,  0.35, DETACHE),
    "barre_1970":          (6.0,  5.0,  5.0,  None,  13.0,  1.00, BOITE),
    "equipement":          (4.0,  3.0,  3.0,  20.0,  22.0,  0.60, DETACHE),
    "friche_industrielle": (3.0,  2.5,  2.5,  None,  35.0,  0.55, BOITE),
}

# ⛪ L'église de l'îlot 16 est un équipement PROTÉGÉ (décision 71), mais sa
# parcelle ne fait que 22,9 m de façade après retrait de la voirie. La recette
# générale des équipements demande 20 m de façade + 3 m de chaque côté : rien
# ne pouvait tenir, donc « pas de panneaux sur l'église » portait sur un toit
# qui n'existait pas. Même famille détachée, mêmes plafonds ; seules les
# dimensions descendent à l'échelle de cette église de village.
TISSU_ILOT = {
    16: (1.5, 1.5, 1.5, 15.0, 18.0, 0.60, DETACHE),
}
TISSU_ILOT_SOUS_TYPE = {16: "equipement"}

# 🔴 CE QUE CETTE TABLE VIENT DE CHANGER, ET POURQUOI — 2026-08-17, désigné sur
# `parcelles_ilot_14.png` : « les bâtiments ressemblent trop aux parcelles ».
# Mesuré sur cette image : le cœur ancien couvrait 0,96 de sa parcelle et le
# front commerçant 0,86 — donc pas de jardin, pas de cour, pas d'arrière. Une
# mosaïque de polygones extrudés, pas du tissu urbain.
#
# 🔄 CE QU'IL Y AVAIT AVANT, ET IL NE FAUT PAS Y REVENIR : `profondeur = None`
# pour le cœur ancien et les maisons de ville, c'est-à-dire « aucune règle de
# profondeur, l'empreinte EST la parcelle ». Ça venait d'une demande juste — les
# maisons de ville ont une profondeur variable, et une profondeur unique comptée
# depuis UNE SEULE façade coupait de travers les parcelles d'angle. Mais le
# remède a supprimé la profondeur au lieu de réparer les coins.
#
# La profondeur est revenue parce que le coin est réparé ailleurs, dans
# `bande_sur_rue` : la bande constructible se mesure depuis CHAQUE limite sur
# rue, et le bâtiment est la RÉUNION de ces bandes. Une parcelle d'angle porte
# donc un bâtiment en L qui suit les deux rues — ce que fait un immeuble d'angle
# réel — au lieu d'être tranchée en biais par la profondeur de l'autre rue.
#
# Les plages viennent de l'auteur (2026-08-17) et la colonne `emprise` est le
# HAUT de la plage, parce que c'est un plafond et non une cible :
#
#     tissu               recul      profondeur   emprise visée
#     pavillonnaire       3–7 m        8–12 m       20–35 %
#     maisons de ville    0–3 m        9–14 m       40–65 %
#     cœur ancien         0–1 m       10–16 m       55–80 %
#     front commerçant    0 m         12–20 m       60–85 %
#     équipement          variable    variable      25–60 %
#
# Ce que le plafond garantit en retour : « conserver au minimum 15 à 30 % de la
# parcelle comme cour ou jardin ». 0,80 sur le cœur ancien, c'est 20 % de cour.
#
# ⚠️ LE RECUL DU PAVILLONNAIRE RESTE À 4 m ET IL NE FAUT PAS LE POUSSER. La plage
# de l'auteur va de 3 à 7 m, mais le milieu de la plage coûte des maisons —
# mesuré, en faisant varier ce seul nombre :
#
#     recul   pavillons bâtis   refusés « aucune forme ne tient »
#      4,0 m        174                    73
#      4,5 m        166                    81
#      5,0 m        163                    84
#
# La cause n'est pas le recul mais ce qu'il révèle : `rect_ancre` cherche un
# rectangle de 9 × 10 m, et sur une parcelle de lotissement de 14 m de façade il
# n'y a que 8,4 m entre les deux retraits latéraux. Reculer d'un mètre de plus le
# fait sortir de la partie utile de la parcelle. 🔴 LES 73 REFUS RESTANTS SONT UN
# DÉFAUT ANTÉRIEUR, pas une conséquence de la bande : des parcelles de 240 à
# 530 m² avec 9 à 28 m de façade, où un pavillon devrait entrer sans effort.
# → à traiter séparément, c'est la table `pavillonnaire` et `rect_ancre`.

# La variation demandée sur les plages, ±15 % : sans elle une rangée entière a
# la même profondeur au centimètre, ce qui ne ressemble à rien de bâti. Tirée de
# la POSITION comme tout le reste (35), donc stable d'une exécution à l'autre.
JEU_PROF = 0.15

# 🔴 R8 BIS — UNE PARCELLE ÉTROITE CREUSE AU LIEU DE RENONCER. La profondeur
# typologique appliquée telle quelle à une parcelle de 5 m de façade donne 60 m²,
# donc parfois moins que AIRE_MIN, donc un TROU dans le front de rue. Or c'est
# l'inverse de ce qu'on veut : « conserver une façade bâtie presque continue sur
# les rues ». Une maison à façade étroite est profonde, dans toutes les villes
# anciennes. La profondeur a donc le droit de monter jusqu'à ce multiple de la
# valeur du tissu avant qu'on renonce à bâtir.
PROF_ETROITE_MAX = 2.0

# ☕ LES EXCEPTIONS DU CŒUR ANCIEN. Une parcelle sur quatre, au-dessus de
# COUR_AIRE, garde une cour derrière son bâtiment. Le tirage vient de la
# position (35), donc la même parcelle garde sa cour d'une exécution à l'autre.
#
# 🔄 2026-08-17 — la cour était d'abord une PROFONDEUR (bâtiment sur les 12
# premiers mètres). C'était faux au sens de la règle : sur une parcelle
# d'angle, « les 12 premiers mètres depuis la façade » laisse le vide le long
# de l'autre rue. La cour est donc une BANDE ARRIÈRE, comme tous les autres
# vides du fichier.
#
# ⚠️ CETTE EXCEPTION A CHANGÉ DE MÉTIER LE MÊME JOUR. Quand l'empreinte était la
# parcelle, elle était le SEUL vide du cœur ancien. Maintenant que la profondeur
# creuse un arrière partout, elle ne sert plus qu'à en creuser un PLUS GRAND sur
# une parcelle sur quatre — d'où un fond plus profond que le retrait ordinaire,
# et pas un fond là où il n'y en avait aucun.
COUR_PART = 0.25
COUR_AIRE = 110.0          # sous cette taille, une cour ne laisse plus de maison
COUR_FOND = 5.0

# 🕳️ L'OUVERTURE MINIMALE D'UNE COUR — 2026-08-17. Part de son contour qui doit
# être du bord de parcelle et non du mur du bâtiment. En dessous, ce n'est plus
# une cour derrière la maison, c'est une poche creusée dans la masse : le
# bâtiment en fait le tour et sort en C. Voir `bande_sur_rue`.
#
# ⚠️ UN SEUIL DE LARGEUR A ÉTÉ ESSAYÉ EN PLUS, ET RETIRÉ LE JOUR MÊME. L'idée
# était qu'une cour de moins de trois mètres est une fente, pas une cour. Mesuré :
# 434 cours sur 701 tombaient dessous et repartaient en bâtiment — la cour
# médiane du cœur ancien fait 22 m² derrière une parcelle de 9,5 m, donc 2,3 m de
# profondeur. Le seuil aurait annulé la correction de la veille (« le bâtiment
# n'est plus la parcelle ») en une ligne. La fente qui se voit encore sur l'îlot
# 41 est un DOIGT de la cour qui rentre dans la masse, pas une cour séparée :
# elle se traiterait par une ouverture morphologique, pas par un seuil.
COUR_OUVERTURE = 0.40
# Le doigt : une tranche plus étroite que ça et moins ouverte que ça n'est pas
# une cour, c'est une fente que le bâtiment referme presque.
COUR_LARGEUR_MIN = 3.0
COUR_DOIGT = 0.50

# 🏚️ L'AILE ARRIÈRE — « avec une probabilité de 20 à 35 %, ajouter une aile
# arrière de 4 à 7 m de largeur » (2026-08-17). Ce qu'elle répare est nommé dans
# la même demande : « ajouter quelques ailes arrière pour éviter une cour trop
# régulière ». Sans elle, toutes les empreintes s'arrêtent sur la même ligne et
# le cœur d'îlot sort en rectangle de gestionnaire.
#
# L'aile se pose CONTRE une limite latérale, jamais au milieu : une aile
# arrière réelle longe le mur mitoyen, c'est ce qui la distingue d'un appentis.
AILE_PART = 0.28           # dans la plage 20–35 % demandée
# 🔴 L'AILE SE PAYE SUR LA PROFONDEUR DE LA BANDE, ELLE NE S'AJOUTE PAS.
# Première version : l'aile était posée EN PLUS, dans la cour. Mesuré, ça ne
# marchait jamais — la cour laissée derrière la bande fait 22 m² en médiane, donc
# l'aile n'y entrait pas ; et quand elle y entrait, elle poussait l'emprise
# au-dessus du plafond, que le rabot rendait aussitôt en raccourcissant TOUT le
# bâtiment. On avait payé une façade pour un ressaut.
# Le bâtiment à aile a donc une bande plus courte de ce facteur : même surface
# bâtie, cour en L au lieu de cour en bande — ce qui est exactement la demande,
# « éviter une cour trop régulière ».
AILE_ECHANGE = 0.18
# Le front commerçant en est exclu : son plafond d'emprise est déjà à 0,85, donc
# une aile y serait aussitôt reprise par le rabot de R8 — l'aile pousserait le
# bâtiment au-dessus du plafond, et le plafond raboterait la profondeur de TOUT
# le bâtiment pour la rendre. On aurait payé une façade pour un ressaut.
AILE_TISSUS = {"coeur_ancien", "maisons_de_ville"}
AILE_LARGEUR = (4.0, 7.0)
AILE_PROFONDEUR = (3.0, 6.0)
AILE_AIRE_MIN = 15.0       # sous ça, ce n'est plus une aile, c'est un ressaut
# Sous cette cour, pas d'aile : il faut qu'il reste un arrière APRÈS l'aile,
# sinon on a rendu la parcelle pleine par un autre chemin.
AILE_COUR_MIN = 30.0
# 🔴 ADOSSÉE, ET C'EST VÉRIFIÉ DEPUIS LE 2026-08-17 (2). La docstring de
# `aile_arriere` promettait « adossée à une limite LATÉRALE et jamais posée au
# milieu » depuis le premier jour — mais rien ne le contrôlait : l'aile se posait
# à un BOUT DE LA COUR mesuré le long de la façade, et sur une parcelle d'angle
# ce bout-là est le mur de l'autre bande, pas une limite de parcelle. D'où la
# dent qui pend dans la cour et l'escalier que l'auteur a entourés sur l'îlot 41.
#
# Mesuré, en éteignant l'aile pour isoler sa part : les poches à bouche étroite
# (≤ 8 m, ≥ 3 m²) passent de 57 à 14, et celles à bouche ≤ 6 m de 18 à 1. L'aile
# faisait donc les trois quarts des ressauts du fichier.
#
# Le contrôle : la part du contour de l'aile posée sur la limite de la PARCELLE.
# Une aile vraiment adossée y met une de ses deux joues, soit 3 à 6 m sur un
# contour de 17 à 26 m — le seuil est bas exprès, il ne sépare pas « beaucoup »
# de « peu » mais « une joue » de « rien du tout ».
AILE_ADOS = 0.15

# ✂️ LA POINTE N'EST PLUS BÂTIE PAR DÉFAUT — 2026-08-17 : « les pointes et
# angles aigus sont presque toujours bâtis. Or dans la réalité ces endroits
# deviennent souvent un jardinet, une cour, un passage. Les bâtiments très
# pointus sont possibles, mais devraient rester des exceptions remarquables. »
#
# `ecorner` ne suffit pas : il coupe la pointe DU BÂTIMENT, donc il transforme
# un couteau en coin tronqué, mais il bâtit quand même la pointe de l'îlot. Ici
# c'est la parcelle qui est jugée, avant tout dessin.
#
# Le tirage garde une exception sur six — le bâtiment d'angle pointu existe, il
# doit juste être rare. Et il n'y a pas de règle sans compte : les deux nombres
# s'impriment.
ANGLE_POINTE_DEG = 30.0
POINTE_PART = 0.17

# 🌿 LA PARCELLE SANS RUE EST UNE CATÉGORIE, PAS UN RÉSIDU — 2026-08-17 : « le
# problème n'est pas leur existence, mais le fait qu'elles semblent être des
# erreurs résiduelles plutôt qu'une catégorie urbaine assumée ».
#
# 🔴 MESURÉ AVANT D'ÉCRIRE QUOI QUE CE SOIT, et ça a annulé le travail prévu :
# les 15 parcelles sans façade de Wehrau sont EXACTEMENT les 15 cœurs d'îlot,
# `origine = 'coeur'`. Il n'existe aucune parcelle enclavée par accident — c'est
# le « zéro reliquat enclavé » du 2026-08-17. Elles sont donc déjà une catégorie
# assumée, écartées en amont par ORIGINES_NUES et dessinées en vert.
#
# Ce qui les faisait LIRE comme un résidu n'était pas leur statut, c'était leur
# FORME : la pointe verte de l'îlot 59, désignée sur l'image. C'est la règle de
# la pointe, juste au-dessus, qui y répond — et une remise au fond d'une cour
# aurait été du code pour un cas qui n'existe pas.

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

# 🕳️ L'ENCOCHE — 2026-08-17 (2). Une empreinte a droit à UN décrochement
# rentrant, pas deux. Voir `fermer_encoches` pour le pourquoi ; ici les nombres.
#
# Mesuré avant d'écrire la règle, sur les 701 empreintes de la ville :
#
#     sommets rentrants   empreintes   ce que c'est
#            0                542      la barre, le rectangle
#            1                131      l'équerre : immeuble d'angle, aile arrière
#            2                 26      l'escalier, le U
#            3                  2      le C
#
# ⚠️ ET UN SEUIL DE LARGEUR NE SAIT PAS LES SÉPARER, c'est mesuré aussi : les
# poches à bouche ≤ 8 m passent de 14 à 57 quand on rallume l'aile arrière, qui
# est pourtant la forme la plus VOULUE du fichier. La bouche d'une équerre juste
# et celle d'un ressaut font la même largeur ; c'est leur NOMBRE qui diffère.
ENCOCHE_RENTRANTS = 1
# Au-delà, la poche n'est plus une encoche : c'est la cour que l'équerre
# entoure, et la combler rendrait la parcelle pleine. 45 m² = la cour médiane du
# cœur ancien (22 m²) doublée, donc large.
ENCOCHE_AIRE_MAX = 45.0
ENCOCHE_PASSES = 4         # trois décrochements au pire, plus un tour de garde
# Ce qui compte comme un décrochement plutôt que comme du bruit de découpe.
RENTRANT_AIRE_MIN = 0.5    # produit vectoriel, donc deux fois l'aire du coin
RENTRANT_ARETE_MIN = 0.5   # m — sous ça l'arête n'a pas de direction

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
          "pire_coins": 0, "pire_rect": 1.0,
          "aile": 0, "aile_ratee": 0, "aile_flottante": 0,
          "creuse": 0, "rabote": 0,
          "pointe_nue": 0, "pointe_gardee": 0, "traversante": 0,
          "morceau_jete": 0, "poche_comblee": 0,
          "encoche": 0, "encoche_bat": 0}


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


def creux_sur_rue(polys, ring, rues, retraits):
    """De combien le bâti recule-t-il de sa rue, au-delà de son recul ?

    Le contrôle de R2 bis. `touche_les_rues` répond oui ou non et sert à
    décider une coupe ; ici on veut la PROFONDEUR du creux, parce que tous les
    creux ne se valent pas : le pan coupé d'un angle aigu (`ecorner`) en
    fabrique un de la taille du pan, et c'en est un qu'on veut. Un bâtiment
    reculé de six mètres sur toute sa façade, non.

    ⚠️ PREND LA LISTE DES BÂTIMENTS DE LA PARCELLE, pas un seul. Une parcelle
    traversante en porte deux, un par rue ; mesurer le bâtiment de devant contre
    la rue de derrière l'accuserait d'un creux de toute la profondeur du jardin,
    qui est justement ce qu'on veut voir exister."""
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
                if any(dans(poly, q) for poly in polys):
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
    vide. Mesuré avant la restructuration du 2026-08-18 : l'ancienne galerie
    de l'îlot 45 (5 919 m²) sortait « trop petite », et 145 parcelles perdaient
    leur bâtiment. Comme
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


# ------------------------------------------------- la bande depuis la façade

def part(g, sel):
    """Une fraction reproductible dans [0, 1], tirée de la graine de position."""
    return ((g >> sel) & 1023) / 1023.0


def entre(g, sel, plage):
    bas, haut = plage
    return bas + (haut - bas) * part(g, sel)


def part_sur_bord(morceau, contour, tol=0.15):
    """La part du périmètre de `morceau` posée sur le contour de `contour`.

    Tout ce qui n'y est pas est une coupe, donc un mur de bâtiment : c'est ce
    qui distingue une cour ouverte d'une poche creusée dans la masse."""
    n, m = len(morceau), len(contour)
    if n < 3 or m < 3:
        return 1.0
    total = dessus = 0.0
    for i in range(n):
        p, q = morceau[i], morceau[(i + 1) % n]
        L = math.hypot(q[0] - p[0], q[1] - p[1])
        if L < 1e-9:
            continue
        total += L
        mid = ((p[0] + q[0]) / 2.0, (p[1] + q[1]) / 2.0)
        if any(D4C.dist_pt_seg(mid, contour[k], contour[(k + 1) % m]) <= tol
               for k in range(m)):
            dessus += L
    return dessus / total if total > 1e-9 else 1.0


def bande_sur_rue(env, ring, rues, retraits, prof):
    """L'enveloppe réduite à la BANDE CONSTRUCTIBLE. Renvoie (bâtiments, cour).

    🔴 C'EST LA CORRECTION DU 2026-08-17, ET ELLE COMMANDE TOUT LE RESTE DU
    FICHIER. Avant, l'empreinte d'un tissu mitoyen était la parcelle moins ses
    retraits — donc « les bâtiments ressemblent trop aux parcelles » : des corps
    de 30 m de profondeur, aucun jardin, aucune cour, aucun arrière. La règle
    est maintenant celle d'une ville réelle : le front de rue peut être continu,
    mais le bâtiment reste une BANDE de 10 à 16 m comptée depuis sa façade, et
    la parcelle continue derrière lui.

    🔴 ET LA BANDE SE MESURE DEPUIS CHAQUE LIMITE SUR RUE, PAS DEPUIS LA PLUS
    LONGUE. C'est ce qui répare les parcelles d'angle, et c'est la raison pour
    laquelle la règle de profondeur avait été SUPPRIMÉE le matin même au lieu
    d'être réparée : une profondeur comptée depuis une seule façade laisse le
    vide le long de l'autre rue, et sur un îlot ancien ça se voit à tous les
    coins. Ici la bande de chaque rue est un demi-plan, le bâtiment est leur
    RÉUNION, et une parcelle d'angle porte donc un immeuble en L qui suit ses
    deux rues.

    Le procédé n'a besoin d'aucune bibliothèque géométrique : la réunion des
    bandes est le complément de l'INTERSECTION des arrières, et `04c` sait déjà
    retirer une intersection de demi-plans d'un anneau (`_soustraire_convexe`,
    écrit pour les venelles). La partition tient donc à l'arête près (61) :
    le mur arrière du bâtiment et le bord de la cour sont la même arête.

    🔴 ET LA PARCELLE A LE DROIT DE PORTER PLUSIEURS BÂTIMENTS. Mesuré ici, et
    c'était d'abord pris pour un défaut : sur 25 parcelles la bande sort en DEUX
    morceaux qui ne se touchent nulle part (`bord_partage` = 0, vérifié). Ce sont
    les parcelles TRAVERSANTES — une rue devant, une rue derrière — et deux
    morceaux disjoints y sont la bonne réponse : une maison sur chaque rue, le
    jardin entre les deux. La première version n'en gardait que le plus grand et
    jetait jusqu'à 87 m², ce qui reculait la façade de l'autre rue de toute la
    profondeur du jardin — le défaut R2 bis, réintroduit par la correction."""
    if prof is None:
        return [env], []
    hp = []
    n = len(ring)
    for i in range(n):
        if not rues[i]:
            continue
        a, b = ring[i], ring[(i + 1) % n]
        dx, dy = b[0] - a[0], b[1] - a[1]
        L = math.hypot(dx, dy)
        # Même garde-fou que dans `enveloppe` : une arête de quelques
        # millimètres n'a pas de direction, elle a du bruit, et la bande qu'elle
        # dicterait traverserait la parcelle n'importe comment.
        if L < LONGUEUR_ARETE_MIN:
            continue
        nx, ny = -dy / L, dx / L            # rentrant : anneau ccw
        d = retraits[i] + prof              # 🔴 depuis la FAÇADE, pas la rue
        hp.append(((a[0] + nx * d, a[1] + ny * d), (nx, ny)))
    if not hp:
        return [env], []
    devant, arriere = D4C._soustraire_convexe(env, hp)
    if not devant:
        return [env], []                    # la parcelle est moins profonde que
                                            # la bande : elle est bâtie entière

    # Les morceaux qui SE TOUCHENT se recollent — une parcelle d'angle en donne
    # deux qui partagent l'arête de la coupe, et c'est un immeuble en L, pas deux
    # bâtiments. Ceux qui ne se touchent pas restent séparés : voir plus haut.
    morceaux = D4C.reunir_voisins(devant)

    # 🕳️ UNE COUR N'EST PAS UN TROU — 🔄 2026-08-17, désigné par l'auteur sur les
    # coins des îlots 40, 41 et 59, avec le tracé de l'emprise voulue par-dessus
    # l'image : le bâtiment y sortait en C, une cour creusée EN PLEIN MILIEU de
    # la masse au lieu d'être derrière elle.
    #
    # La cause est géométrique et non réglable. Sur une parcelle d'ANGLE, ce qui
    # reste derrière les deux bandes est un coin dont la pointe vise le coin de
    # rue : le bâtiment fait le tour de cette pointe, donc un C. Sur un angle
    # droit ordinaire le même reste est un rectangle collé au fond, et c'est une
    # cour normale.
    #
    # Le partage se lit sur l'OUVERTURE de la cour : la part de son contour qui
    # est du bord de parcelle et non du mur du bâtiment. Une cour de fond est
    # bordée par le fond et les deux côtés (0,5 et plus) ; une poche entre deux
    # ailes n'a qu'un côté (0,25 et moins). Ce qui n'est pas ouvert repart au
    # bâtiment — donc le vide reste DERRIÈRE, jamais dedans.
    #
    # 🔴 SAUF SUR UNE PARCELLE TRAVERSANTE, ET C'EST LA MOITIÉ DE LA RÈGLE. Là,
    # le vide est pris en sandwich entre les deux maisons — une par rue — donc il
    # est fermé par du mur des deux côtés et son ouverture est basse elle aussi.
    # Le combler rendrait la parcelle pleine et reculerait la façade de la rue
    # d'en face de toute la profondeur du jardin : c'est R2 bis, réintroduit une
    # troisième fois. Le test est déjà fait juste au-dessus — deux morceaux de
    # bande qui ne se touchent nulle part —, on s'en sert.
    if len(morceaux) == 1:
        # ⚠️ ON JUGE CHAQUE TRANCHE, ET RECOLLER LES TRANCHES D'ABORD A ÉTÉ
        # ESSAYÉ PUIS RETIRÉ. `_soustraire_convexe` retranche les demi-plans un
        # par un, donc l'arrière ressort en tranches — et c'est la bonne unité :
        # une tranche est une région de l'arrangement des demi-plans, donc soit
        # elle est derrière le bâtiment, soit elle est dedans. Recollées, la
        # poche du coin fusionne avec la cour de fond, l'ouverture de l'ensemble
        # repasse au-dessus du seuil, et le C de l'îlot 40 revient tel quel.
        ouvertes, poches = [], []
        for m in arriere:
            # Une poche est CREUSÉE dans la masse, donc elle la touche. Un
            # morceau qui ne touche pas le bâtiment est un fond de parcelle
            # séparé : le combler ajouterait un second bâtiment posé dans le
            # jardin, ce qui est l'inverse du but.
            ouv = part_sur_bord(m, env)
            # Deux façons d'être une poche :
            #   · la tranche est ENFERMÉE par le bâtiment (le C du coin) ;
            #   · elle est un DOIGT — assez étroite pour qu'on n'y habite pas,
            #     et à moitié bordée de mur. C'est la fente beige que l'auteur
            #     a entourée sur l'îlot 41. ⚠️ Le seuil de largeur ne vaut
            #     JAMAIS seul : la cour de fond du cœur ancien fait 22 m² pour
            #     9,5 m de façade, donc 2,3 m de profondeur, et un seuil de
            #     largeur seul en rebâtissait 434 sur 701.
            poche = ((ouv < COUR_OUVERTURE
                      or (largeur_min(m) < COUR_LARGEUR_MIN
                          and ouv < COUR_DOIGT))
                     and D4C.bord_partage(morceaux[0], m) > 1e-6)
            (poches if poche else ouvertes).append(m)
        if poches:
            # 🔴 ET ON NE GARDE LE COMBLEMENT QUE S'IL RECOLLE VRAIMENT.
            # `fusionner` renonce quand le bord commun n'est pas contigu, et le
            # morceau ressortirait alors en SECOND bâtiment posé dans la cour —
            # exactement le contraire du geste. Mesuré sans ce repli : cinq
            # parcelles de plus comptées « traversantes » sans l'être.
            recolle = D4C.reunir_voisins(morceaux + poches)
            if len(recolle) == 1:
                COMPTE["poche_comblee"] += 1
                morceaux = recolle
                arriere = ouvertes

    morceaux.sort(key=lambda m: -abs(D4C.aire_signee(m)))
    if len(morceaux) > 1:
        COMPTE["traversante"] += 1
    return morceaux, list(arriere)


def aile_arriere(bande, cour, a, u, nrm, d_fond, g, ring):
    """Le bâtiment prolongé d'une aile arrière, ou tel quel. Renvoie (anneau,
    posée ?).

    L'aile est adossée à une limite LATÉRALE et jamais posée au milieu : une
    aile arrière réelle longe le mur mitoyen, c'est ce qui la distingue d'un
    appentis au fond du jardin. Le côté est tiré de la position (35).

    🔴 ET C'EST MAINTENANT VÉRIFIÉ AU LIEU D'ÊTRE ESPÉRÉ — 2026-08-17 (2).
    L'aile se pose à un BOUT DE LA COUR mesuré le long de la façade. Sur une
    parcelle de rangée ce bout-là est bien la limite mitoyenne ; sur une
    parcelle d'ANGLE, dont le bâtiment est déjà la réunion de deux bandes, c'est
    le mur de l'autre bande. L'aile s'y adossait donc à son propre bâtiment, au
    milieu de la cour : la dent qui pend et l'escalier que l'auteur a entourés
    sur l'îlot 41. On essaie donc les deux bouts, le tiré d'abord, et on ne
    garde que celui qui pose vraiment une joue sur la limite de la parcelle.

    ⚠️ ELLE PEUT ÉCHOUER SANS QUE CE SOIT UNE ERREUR, et l'échec se compte.
    L'aile et la bande se recollent par leur arête commune ; si la cour a déjà
    été rongée ailleurs, ou si le recollage ne rend pas un anneau unique, on
    rend la bande seule. Une aile qui flotte à côté de sa maison serait pire
    qu'une maison sans aile."""
    if not cour:
        return bande, False
    piece = max(cour, key=lambda m: abs(D4C.aire_signee(m)))
    if abs(D4C.aire_signee(piece)) < AILE_COUR_MIN:
        return bande, False

    larg = entre(g, 17, AILE_LARGEUR)
    prof_a = entre(g, 23, AILE_PROFONDEUR)
    tus = [(p[0] - a[0]) * u[0] + (p[1] - a[1]) * u[1] for p in piece]
    # Les deux bouts de la cour, le tiré de la position en premier (35) : le
    # second n'est essayé que si le premier n'est adossé à rien.
    bouts = [min(tus), max(tus) - larg]
    if not (g >> 29) & 1:
        bouts.reverse()

    flottante = False
    for t0 in bouts:
        hp = [
            # le fond de l'aile : au-delà, on est de nouveau dans la cour
            ((a[0] + nrm[0] * (d_fond + prof_a),
              a[1] + nrm[1] * (d_fond + prof_a)), (-nrm[0], -nrm[1])),
            # les deux joues, mesurées le long de la façade
            ((a[0] + u[0] * t0, a[1] + u[1] * t0), u),
            ((a[0] + u[0] * (t0 + larg), a[1] + u[1] * (t0 + larg)),
             (-u[0], -u[1])),
        ]
        _, dedans = D4C._soustraire_convexe(piece, hp)
        if not dedans:
            continue
        aile = max(dedans, key=lambda m: abs(D4C.aire_signee(m)))
        if abs(D4C.aire_signee(aile)) < AILE_AIRE_MIN:
            continue
        # 🔴 LE CONTRÔLE QUI MANQUAIT : une joue sur la limite de la PARCELLE.
        # `ring` et non l'enveloppe : en mitoyen le retrait latéral vaut 0, donc
        # les deux se confondent, mais c'est la limite de propriété qui donne
        # son sens au mot « adossée ».
        if part_sur_bord(aile, ring) < AILE_ADOS:
            flottante = True
            continue
        fusion = D4C.reunir_voisins([bande, aile])
        if len(fusion) != 1:
            COMPTE["aile_ratee"] += 1
            continue
        return fusion[0], True
    if flottante:
        COMPTE["aile_flottante"] += 1
    return bande, False


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


def _rentrants(anneau):
    """Les indices des sommets RENTRANTS qui sont de vrais décrochements.

    Le filtre sur les deux arêtes n'est pas de la coquetterie : `04c` laisse des
    sommets à quelques centimètres l'un de l'autre (l'anneau de la parcelle 238
    se ferme sur un doublon), et un tel sommet compte pour un décrochement alors
    qu'il n'est que du bruit de découpe."""
    n = len(anneau)
    out = []
    for i in range(n):
        p, q, r = anneau[(i - 1) % n], anneau[i], anneau[(i + 1) % n]
        cr = (q[0] - p[0]) * (r[1] - q[1]) - (q[1] - p[1]) * (r[0] - q[0])
        if cr >= -RENTRANT_AIRE_MIN:
            continue
        if min(math.hypot(q[0] - p[0], q[1] - p[1]),
               math.hypot(r[0] - q[0], r[1] - q[1])) < RENTRANT_ARETE_MIN:
            continue
        out.append(i)
    return out


def _enveloppe_convexe(anneau):
    """Les indices des sommets de l'anneau qui portent son enveloppe convexe.

    Rendus en indices et non en points : deux sommets d'une empreinte peuvent
    tomber au même endroit (une arête de longueur nulle), et un test
    d'appartenance par coordonnées les confondrait."""
    n = len(anneau)
    if n < 3:
        return list(range(n))
    ordre = sorted(range(n), key=lambda i: (anneau[i][0], anneau[i][1]))

    def demi(seq):
        h = []
        for i in seq:
            while len(h) >= 2:
                a, b, c = anneau[h[-2]], anneau[h[-1]], anneau[i]
                if (b[0] - a[0]) * (c[1] - a[1]) - (b[1] - a[1]) * (c[0] - a[0]) > 0:
                    break
                h.pop()
            h.append(i)
        return h
    return sorted(set(demi(ordre)[:-1] + demi(ordre[::-1])[:-1]))


def fermer_encoches(anneau, env):
    """L'empreinte n'a plus qu'UN décrochement rentrant : l'équerre, pas
    l'escalier. Renvoie (anneau, nombre d'encoches refermées).

    🕳️ 2026-08-17 (2), désigné par l'auteur sur les îlots 40 et 41 : « des
    formes de bâtiment pas réalistes », « des coins encore à corriger ». La note
    de la veille annonçait déjà le remède sans l'écrire — « ça demanderait une
    OUVERTURE MORPHOLOGIQUE de la cour, pas un seuil de plus ». C'est ce que
    fait cette passe, du côté du bâtiment : elle referme les poches étroites du
    contour, ce qui revient à ouvrir la cour.

    🔴 LE CRITÈRE EST LE NOMBRE DE DÉCROCHEMENTS, PAS UNE LARGEUR. Mesuré sur
    les 701 empreintes : 542 n'ont aucun sommet rentrant, 131 en ont UN, 28 en
    ont deux ou trois. Un sommet rentrant, c'est une équerre — l'immeuble
    d'angle qui suit ses deux rues, ou la maison prolongée de son aile arrière ;
    les deux sont voulus et se lisent très bien. DEUX, c'est un escalier ou un
    U, et aucune de ces 28 empreintes n'a d'excuse. Un seuil de largeur, lui,
    n'aurait pas su séparer les deux : la poche d'une équerre légitime fait 7 à
    9 m de bouche, exactement comme celle d'un ressaut.

    On referme la plus PETITE poche d'abord : sur une parcelle d'angle, la
    grande poche est la cour que l'équerre entoure — celle qu'il faut garder —
    et la petite est la dent qui pend dedans."""
    fermees = 0
    for _ in range(ENCOCHE_PASSES):
        an = anneau
        if len(_rentrants(an)) <= ENCOCHE_RENTRANTS:
            break
        hull = _enveloppe_convexe(an)
        if len(hull) < 3:
            break
        n = len(an)
        poches = []
        for k in range(len(hull)):
            i, j = hull[k], hull[(k + 1) % len(hull)]
            sub = an[i:j + 1] if j > i else an[i:] + an[:j + 1]
            if len(sub) < 3:
                continue
            aire = abs(D4C.aire_signee(sub))
            if aire < 1.0 or aire > ENCOCHE_AIRE_MAX:
                continue
            # 🔴 LA POCHE COMBLÉE DOIT RESTER DANS LA PARCELLE. Elle y est
            # presque toujours — derrière ses parois il y a la cour, donc du
            # terrain à soi — mais une parcelle en équerre peut refermer une
            # poche par-dessus la voisine, et R0 ne pardonne pas.
            if not _tient_dans(an[i], an[j], sub, env):
                continue
            poches.append((aire, i, j))
        if not poches:
            break
        _, i, j = min(poches)
        anneau = (an[:i + 1] + an[j:]) if j > i else an[j:i + 1]
        anneau = D4C.nettoyer(anneau)
        if len(anneau) < 3:
            return an, fermees
        fermees += 1
    return anneau, fermees


def _tient_dans(p, q, poche, env):
    """La corde qui referme `poche` reste-t-elle dans `env` ?

    🔴 ON TESTE DES POINTS DÉCALÉS VERS L'INTÉRIEUR DE LA POCHE, ET C'EST
    OBLIGATOIRE, PAS UNE PRÉCAUTION. Les deux bouts de la corde sont des sommets
    du bâtiment, donc en tissu mitoyen ils sont posés SUR la limite de parcelle
    (le retrait latéral y vaut 0) : testés tels quels, ils tombent du mauvais
    côté du test de parité et toutes les encoches se refusaient — 12 refermées
    au lieu de 28, mesuré."""
    cx = sum(r[0] for r in poche) / len(poche)
    cy = sum(r[1] for r in poche) / len(poche)
    L = math.hypot(q[0] - p[0], q[1] - p[1])
    k = max(3, int(L / 1.0) + 1)
    for t in range(k):
        f = t / (k - 1.0)
        x = p[0] + (q[0] - p[0]) * f
        y = p[1] + (q[1] - p[1]) * f
        dx, dy = cx - x, cy - y
        d = math.hypot(dx, dy)
        if d < 1e-9:
            continue
        if not dans(env, (x + dx / d * 0.10, y + dy / d * 0.10)):
            return False
    return True


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

def empreinte(parcelle, st, idx_bord, idx_venelle, dir_ilot=None, fid_ilot=None):
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
    recul0, lat0, fond0, facade, prof0, part_max, famille = \
        TISSU_ILOT.get(fid_ilot, TISSU[st])
    ring = ccw(sans_doublons(D4C.ouvrir(parcelle)))
    n = len(ring)
    if n < 3:
        return None, "dégénérée", [], [], {}

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
        # 🌿 Le motif porte le NOM de la catégorie et pas celui d'un échec : sur
        # Wehrau ce cas ne se présente jamais (les 15 parcelles sans façade sont
        # les 15 cœurs d'îlot, écartés en amont), donc c'est un garde-fou pour le
        # jour où `04c` en laisserait une. Mieux vaut qu'elle sorte nommée.
        return None, "jardin intérieur (sans rue)", rues, [], {}

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
        return None, "sans façade", rues, [], {}
    a = ring[meilleur]
    b = ring[(meilleur + 1) % n]
    L = math.hypot(b[0] - a[0], b[1] - a[1])
    u = ((b[0] - a[0]) / L, (b[1] - a[1]) / L)      # le long de la rue
    nrm = (-u[1], u[0])                            # rentrant : anneau ccw

    g = graine(ring)
    recul = max(0.0, recul0 + jeu(g, 3, JEU_RECUL))
    # ±15 % sur la profondeur : « ce sont des plages, pas des valeurs fixes ».
    prof = None if prof0 is None else prof0 * (1.0 + jeu(g, 21, JEU_PROF))
    prof0 = prof
    aire_parcelle = abs(D4C.aire_signee(ring))
    if facade is not None:
        facade = max(3.0, facade + jeu(g, 13, JEU_FACADE))

    # ✂️ LA POINTE REPART AU JARDIN, sauf exception. Le test porte sur LA
    # PARCELLE et non sur l'empreinte : `ecorner` sait tronquer la pointe d'un
    # bâtiment, mais il bâtit quand même le bout pointu de l'îlot, et c'est le
    # bout de l'îlot que l'auteur a désigné (« la pointe gauche de l'îlot 59 »).
    # Le tirage laisse passer une pointe sur six, parce que l'immeuble d'angle
    # aigu existe — il doit seulement rester une exception remarquable.
    if famille == MITOYEN \
            and D4C.angle_le_plus_aigu(ring) < ANGLE_POINTE_DEG:
        if part(g, 5) >= POINTE_PART:
            COMPTE["pointe_nue"] += 1
            return None, "pointe rendue au jardin", rues, [], {}
        COMPTE["pointe_gardee"] += 1

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

    # R8 BIS — LA PARCELLE ÉTROITE CREUSE. D'abord, parce qu'il ne sert à rien
    # de raboter une empreinte qui n'existe pas encore. Une façade de 5 m sur
    # 13 m de profondeur fait 65 m² ; la même après retraits peut tomber sous
    # AIRE_MIN, et le refus ferait un TROU dans le front de rue — l'inverse de
    # « conserver une façade bâtie presque continue ». Une maison à façade
    # étroite est profonde : c'est la règle, pas le rattrapage.
    # 🏚️ L'AILE SE DÉCIDE ICI, AVANT LA BANDE, parce qu'elle se paye sur la
    # profondeur de celle-ci (voir AILE_ECHANGE). Décidée dans `_poser`, elle
    # arrivait après que la bande avait déjà pris toute la place.
    veut_aile = (st in AILE_TISSUS and prof is not None
                 and part(g, 31) < AILE_PART)
    if veut_aile:
        prof *= 1.0 - AILE_ECHANGE

    # ⚠️ CES DEUX COMPTEURS SE PRENNENT DANS LES BOUCLES D'ESSAI, DONC ILS
    # MENTENT SI ON NE LES PLIE PAS. `enveloppe` et le garde-fou du creux
    # s'incrémentent à chaque tour ; entre R5 (4 tours), R8 bis (4) et le rabot
    # (6), une seule parcelle pouvait en compter vingt — mesuré : 837 « retraits
    # de fond annulés » pour 790 bâtiments, un chiffre que personne ne peut lire.
    # On les ramène donc à « nombre de PARCELLES concernées », qui est la seule
    # lecture utile.
    avant = {"fond_cede": COMPTE["fond_cede"],
             "creux_garde": COMPTE["creux_garde"]}

    def par_parcelle():
        for cle, v in avant.items():
            if COMPTE[cle] > v:
                COMPTE[cle] = v + 1

    emps = motif = None
    retraits, note = [], {}
    creuse = False
    for _ in range(4):
        emps, motif, retraits, note = _poser(ring, rues, venelles, u, nrm,
                                             cadre, a, st, famille, recul,
                                             lat0, fond0, facade, prof, g,
                                             veut_aile)
        if emps or prof is None or motif != MOTIF_PETIT:
            break
        if prof >= PROF_ETROITE_MAX * prof0:
            break
        prof = min(prof * 1.35, PROF_ETROITE_MAX * prof0)
        creuse = True
    if not emps:
        par_parcelle()
        return None, motif, rues, retraits, note
    if creuse:
        COMPTE["creuse"] += 1

    # R8 — le plafond d'emprise au sol se paye en profondeur. On le règle par
    # essais successifs plutôt que par une formule : la profondeur ne commande
    # l'aire de façon proportionnelle que sur un rectangle, et la moitié des
    # tissus n'en sont pas. Sans règle de profondeur, il n'y a rien à raboter.
    #
    # 🔴 LE RABOT NE DÉTRUIT JAMAIS UN BÂTIMENT QUI TENAIT. Le plafond et
    # AIRE_MIN se contredisent sur une petite parcelle (0,80 × 50 m² = 40 m²,
    # soit AIRE_MIN pile) : si le tour suivant ne rend rien, on garde le tour
    # d'avant. Un bâtiment un peu trop gras vaut mieux qu'un trou.
    def couvert(liste):
        return sum(abs(D4C.aire_signee(m)) for m in liste)

    if prof is not None and part_max < 1.0:
        rabote = False
        for _ in range(6):
            if couvert(emps) <= part_max * aire_parcelle:
                break
            prof *= 0.88
            e2, _m2, r2, n2 = _poser(ring, rues, venelles, u, nrm, cadre, a,
                                     st, famille, recul, lat0, fond0,
                                     facade, prof, g, veut_aile)
            if not e2:
                break
            emps, retraits, note = e2, r2, n2
            rabote = True
        if rabote:
            COMPTE["rabote"] += 1
    par_parcelle()
    return emps, None, rues, retraits, note


def _poser(ring, rues, venelles, u, nrm, cadre, a, st, famille,
           recul, lat0, fond0, facade, prof, g, veut_aile):
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

        note = {"cour": []}
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
            emp = _forme(ccw(env), ring, rues, retraits, cadre, a, famille,
                         facade, prof, recul, nrm, note)
        else:
            # La forme rectangulaire travaille sur la PARCELLE et ses retraits,
            # pas sur une enveloppe : l'érosion y est exacte, là où découper la
            # parcelle par ses propres droites la réduirait à son noyau.
            emp = _forme(ring, ring, rues, retraits, cadre, a, famille,
                         facade, prof, recul, nrm, note)
        if not emp:
            dernier = "aucune forme ne tient"
            continue

        # 🔴 CHAQUE MORCEAU SE JUGE SÉPARÉMENT, ET LES RECALÉS REPARTENT AU
        # JARDIN SANS ENTRAÎNER LES AUTRES. C'est ce que la parcelle traversante
        # impose : elle porte une maison sur chaque rue, et il arrive que l'une
        # tienne et l'autre non — la refuser en bloc rouvrirait un trou dans une
        # des deux rues, ce qui est le défaut qu'on corrige.
        garde, motif_local = [], None
        for m in emp:
            m = ccw(D4C.nettoyer(m))
            if len(m) < 3:
                continue
            if famille == MITOYEN:
                m = ecorner(m)[0]
            if abs(D4C.aire_signee(m)) < AIRE_MIN:
                motif_local = MOTIF_PETIT
                continue
            if largeur_min(m) < LARGEUR_MIN:
                motif_local = "plus mince que %.1f m" % LARGEUR_MIN
                continue

            # 🔴 TROP DE COINS **ET** MAL REMPLI : le morceau repart au jardin.
            # Le refus est un `continue` et pas un abandon parce que le tour
            # suivant de R5 réduit les retraits, donc coupe moins la parcelle —
            # une empreinte en escalier peut redevenir une équerre franche.
            coins, rect = forme(m)
            if coins > SOMMETS_MAX and rect < RECT_MIN:
                if pire is None or rect < pire[1]:
                    pire = (coins, rect)
                # Motif à texte FIXE : le tableau des refus compte par motif,
                # donc un motif qui porte ses chiffres sort en sept lignes de 1.
                motif_local = MOTIF_FORME
                continue
            garde.append(m)
        if not garde:
            dernier = motif_local or "aucune forme ne tient"
            continue
        if len(garde) < len(emp):
            COMPTE["morceau_jete"] += 1

        # R2 bis, deuxième garde-fou. Annuler une coupe suffit quand une seule
        # arête est en cause ; il reste les parcelles étroites bordées de rue
        # sur trois côtés, où le retrait de fond ne peut PAS tenir sans creuser
        # une rue. Là, c'est le retrait qui plie : on redescend d'un cran et on
        # reprend. Le meilleur essai est gardé au cas où aucun ne serait net.
        if famille == MITOYEN:
            creux = creux_sur_rue(garde, ring, rues, retraits)
            if creux > CREUX_TOLERE:
                if secours is None or creux < secours[0]:
                    secours = (creux, garde, retraits)
                dernier = "creux de %.1f m sur rue" % creux
                continue

        # 🏚️ L'AILE ARRIÈRE SE POSE ICI, ET L'ENDROIT EST LA MOITIÉ DE LA RÈGLE.
        # Après tous les contrôles de forme, parce qu'une aile fait justement un
        # bâtiment en L : six à huit coins pour 0,55 de remplissage, c'est-à-dire
        # exactement ce que « trop de coins, mal rempli » écarte. Ce critère
        # attrape les escaliers de découpe, qui n'ont pas d'excuse ; une équerre
        # VOULUE en a une, et elle se compte au lieu de se juger.
        # L'aile s'accroche au PLUS GRAND morceau : sur une parcelle traversante,
        # c'est la maison de devant qui a une cour derrière elle ; celle de
        # derrière a la même cour devant, et une aile y serait sur la rue.
        if veut_aile:
            garde.sort(key=lambda m: -abs(D4C.aire_signee(m)))
            emp2, posee = aile_arriere(garde[0], note["cour"], a, u, nrm,
                                       recul + prof, g, ring)
            if posee:
                garde[0] = ccw(D4C.nettoyer(emp2))
                note["aile"] = True
                COMPTE["aile"] += 1

        # 🕳️ ET L'ENCOCHE SE REFERME EN DERNIER, APRÈS L'AILE. L'ordre est la
        # moitié de la règle : l'aile fabrique volontairement un décrochement,
        # donc juger la forme avant elle ne verrait pas l'escalier qu'elle
        # produit sur une parcelle d'angle — un bâtiment qui tourne déjà la rue
        # en a alors deux. C'est la dent que l'auteur a entourée sur l'îlot 41.
        for k, m in enumerate(garde):
            m2, nf = fermer_encoches(m, ring)
            if nf:
                garde[k] = ccw(D4C.nettoyer(m2))
                COMPTE["encoche"] += nf
                COMPTE["encoche_bat"] += 1
        return garde, None, retraits, note

    if secours is not None:
        COMPTE["creux_garde"] += 1
        return secours[1], None, secours[2], {"cour": []}
    if pire is not None and dernier == MOTIF_FORME:
        COMPTE["pire_coins"] = max(COMPTE["pire_coins"], pire[0])
        COMPTE["pire_rect"] = min(COMPTE["pire_rect"], pire[1])
    return None, dernier, retraits, {"cour": []}


def _forme(env, ring, rues, retraits, cadre, a, famille, facade, prof, recul,
           nrm, note):
    """R3 — les trois familles.

    En mitoyen, `env` est l'enveloppe déjà rétrécie et il ne reste qu'à en
    garder la bande constructible. Dans les deux autres, `env` est la
    PARCELLE : c'est l'érosion qui tient les distances, et le rectangle se
    cherche dedans, dans le repère `cadre`.

    Renvoie une LISTE d'empreintes, ou None. La liste a plus d'un élément sur une
    parcelle traversante (voir `bande_sur_rue`) ; les deux familles de rectangle
    n'en rendent jamais qu'une.

    `note` recueille ce que l'appelant ne peut pas recalculer : la cour laissée
    derrière la bande, dont `_poser` a besoin pour l'aile arrière."""
    if famille == MITOYEN:
        # 🔄 IL Y AVAIT ICI UNE COUPE PAR UNE SEULE DROITE — celle de la plus
        # longue arête sur rue — et c'est elle qui a été remplacée le
        # 2026-08-17. Elle avait deux défauts qui n'en font qu'un : sur une
        # parcelle d'angle elle tranchait en biais (d'où la suppression de la
        # règle de profondeur, le matin même), et elle ne rendait pas la cour,
        # donc rien n'existait derrière le bâtiment.
        bandes, cour = bande_sur_rue(env, ring, rues, retraits, prof)
        note["cour"] = cour
        return bandes

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

    return [[pt(a0, b0), pt(a1, b0), pt(a1, b1), pt(a0, b1)]]


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
        emps, motif, rues, retraits, note = empreinte(
            p["anneau"], st, idx_bord.get(p["ilot"], {}),
            idx_venelle.get(p["ilot"]), dirs.get(p["ilot"]), p["ilot"])
        if not emps:
            refus[motif] = refus.get(motif, 0) + 1
            detail.append((p, motif))
            continue
        resultats.append({"parcelle": p, "emps": emps, "rues": rues,
                          "retraits": retraits, "note": note})

    controles(resultats, parcelles, refus)
    if "--pourquoi" in sys.argv:
        pourquoi(detail)

    if BLANC:
        print("\nrien écrit (--blanc)")
        return
    n = ecrire(resultats)
    print("\n→ couche `batiments` (%d) écrite dans %s"
          % (n, os.path.basename(GPKG)))


def controles(resultats, parcelles, refus):
    """🔴 LE SEUL ENDROIT OÙ UNE ERREUR PEUT SE VOIR sans lancer la 3D. Les
    trois lignes qui comptent : aucun bâtiment ne sort de sa parcelle (R0), la
    distance mesurée aux limites tient la table (R1/R4), et la surface de toit
    — celle qui rejoint l'énergie."""
    par_st = {}
    for r in resultats:
        st = r["parcelle"]["st"]
        emps = r["emps"]
        ring = r["parcelle"]["anneau"]
        # ⚠️ `dedans` parcourt len-1 arêtes : il lui faut un anneau FERMÉ, sinon
        # la dernière arête manque et le test répond au hasard près d'elle.
        ferme = list(ring) + [ring[0]]
        ap = abs(D4C.aire_signee(ring))
        d = par_st.setdefault(st, {"n": 0, "n_parc": 0, "aire": 0.0,
                                   "part": 0.0, "dmin": 9e9, "dehors": 0.0,
                                   "n_dehors": 0, "larg": 9e9, "vide_rue": 0,
                                   "creux": 0.0, "aire_min": 9e9,
                                   "coins": 0, "rect": 1.0, "bizarre": 0,
                                   "cour": 0.0, "aile": 0})
        d["n_parc"] += 1
        # 🔴 L'EMPRISE SE LIT PAR PARCELLE, LA FORME PAR BÂTIMENT. Depuis qu'une
        # parcelle traversante en porte deux, les deux ne se comptent plus dans
        # la même unité : l'emprise est ce que la parcelle a de bâti — donc la
        # SOMME — et c'est ce nombre que le plafond de la table contraint.
        couvert = sum(abs(D4C.aire_signee(m)) for m in emps)
        d["part"] += couvert / ap if ap else 0.0
        d["cour"] += (1.0 - couvert / ap) if ap else 0.0
        if r["note"].get("aile"):
            d["aile"] += 1
        if TISSU[st][6] == MITOYEN:
            # Le même anneau nettoyé que celui sur lequel `rues` et `retraits`
            # ont été calculés — sinon les index ne désignent pas les mêmes
            # arêtes. Et sur la LISTE : voir `creux_sur_rue`.
            creux = creux_sur_rue(emps, ccw(sans_doublons(ring)), r["rues"],
                                  r["retraits"])
            if creux > CREUX_TOLERE:
                d["vide_rue"] += 1
                d["creux"] = max(d["creux"], creux)
        for emp in emps:
            aire = abs(D4C.aire_signee(emp))
            d["n"] += 1
            d["aire"] += aire
            coins, rect = forme(emp)
            d["aire_min"] = min(d["aire_min"], aire)
            d["coins"] = max(d["coins"], coins)
            d["rect"] = min(d["rect"], rect)
            # 🔴 LES DEUX EXTRÊMES NE SUFFISENT PAS À JUGER, et l'oublier fait
            # crier au loup : le bâtiment qui a le plus de coins n'est presque
            # jamais celui qui remplit le moins. Le critère porte sur UN
            # bâtiment, donc il se compte bâtiment par bâtiment.
            if coins > SOMMETS_MAX and rect < RECT_MIN \
                    and not r["note"].get("aile"):
                d["bizarre"] += 1
            d["dmin"] = min(d["dmin"], min(dist_bord(q, ring) for q in emp))
            d["larg"] = min(d["larg"], largeur_min(emp))
            dehors = max((dist_bord(q, ring) for q in emp
                          if not dedans(ferme, q)), default=0.0)
            if dehors > 0.05:
                d["dehors"] = max(d["dehors"], dehors)
                d["n_dehors"] += 1

    print("\n  %-21s %6s %9s %8s %8s %8s %8s"
          % ("sous_type", "bâtis", "aire moy", "emprise", "plafond",
             "cour %", "larg.min"))
    print("  " + "-" * 74)
    total, toit, n_parc = 0, 0.0, 0
    for st in sorted(par_st, key=lambda s: -par_st[s]["n"]):
        d = par_st[st]
        print("  %-21s %6d %9.0f %8.2f %8.2f %7.0f%% %8.1f"
              % (st, d["n"], d["aire"] / d["n"], d["part"] / d["n_parc"],
                 TISSU[st][5], 100.0 * d["cour"] / d["n_parc"], d["larg"]))
        total += d["n"]
        n_parc += d["n_parc"]
        toit += d["aire"]
    print("  " + "-" * 74)
    print("  %-21s %6d %9.0f  sur %d parcelles bâties"
          % ("total", total, toit / max(total, 1), n_parc))
    print("\n  🌿 LA COLONNE `cour %` EST LA CORRECTION DU 2026-08-17 : c'est la")
    print("     part de la parcelle qui n'est PAS bâtie. Elle valait 4 % sur le")
    print("     cœur ancien — d'où « les bâtiments ressemblent trop aux")
    print("     parcelles ». La consigne demande d'en garder 15 à 30 %.")

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
    print("     %d parcelles où le retrait de fond a cédé devant la rue, %d où"
          " le creux a été gardé faute de mieux."
          % (COMPTE["fond_cede"], COMPTE["creux_garde"]))

    print("\n  🏗️  CE QUE LA RÈGLE DE PROFONDEUR A FABRIQUÉ (2026-08-17)")
    print("     Le bâtiment n'est plus la parcelle : c'est une bande mesurée")
    print("     depuis chaque limite sur rue, et le reste est cour ou jardin.")
    print("     %-44s %5d" % ("parcelles traversantes, deux bâtiments",
                              COMPTE["traversante"]))
    # 🕳️ À lire avec le compte des coins soudés de `04c` : les deux règles
    # visent le même défaut par les deux bouts, la parcelle et l'empreinte.
    print("     %-44s %5d" % ("poches comblées (cour ouverte < %.0f %%)"
                              % (100 * COUR_OUVERTURE),
                              COMPTE["poche_comblee"]))
    print("     %-44s %5d" % ("ailes arrière posées (%.0f %% visés)"
                              % (100 * AILE_PART), COMPTE["aile"]))
    if COMPTE["aile_ratee"]:
        print("     %-44s %5d" % ("  … dont recollages abandonnés",
                                  COMPTE["aile_ratee"]))
    if COMPTE["aile_flottante"]:
        print("     %-44s %5d" % ("  … refusées, adossées à rien",
                                  COMPTE["aile_flottante"]))
    print("     %-44s %5d" % ("encoches refermées (au plus %d rentrant)"
                              % ENCOCHE_RENTRANTS, COMPTE["encoche"]))
    print("     %-44s %5d" % ("  … sur combien de bâtiments",
                              COMPTE["encoche_bat"]))
    print("     %-44s %5d" % ("parcelles étroites qui ont creusé (R8 bis)",
                              COMPTE["creuse"]))
    print("     %-44s %5d" % ("parcelles rabotées par le plafond (R8)",
                              COMPTE["rabote"]))
    print("     %-44s %5d" % ("pointes rendues au jardin (< %.0f°)"
                              % ANGLE_POINTE_DEG, COMPTE["pointe_nue"]))
    print("     %-44s %5d" % ("  … gardées, exception remarquable",
                              COMPTE["pointe_gardee"]))
    if COMPTE["morceau_jete"]:
        print("     %-44s %5d" % ("parcelles ayant perdu un de leurs morceaux",
                                  COMPTE["morceau_jete"]))

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
        regles = [TISSU[st]] + [r for fid, r in TISSU_ILOT.items()
                                if TISSU_ILOT_SOUS_TYPE[fid] == st]
        # Le contrôle agrège un tissu : son plancher est donc la plus petite
        # consigne réellement appliquée à l'un de ses îlots.
        lat = min(r[1] for r in regles)
        fond = min(r[2] for r in regles)
        d = par_st[st]
        if lat <= 0.0:
            etat = "✅ mitoyen" if d["dmin"] < 0.05 else "⚠️ décollé"
        else:
            plancher = min(PLANCHER_LATERAL, PLANCHER_FOND)
            etat = ("✅" if d["dmin"] >= min(lat, fond) - 0.10
                    else "↘ réduit (R5)" if d["dmin"] >= plancher - 0.01
                    else "⚠️")
        print("     %-21s mesuré %5.2f m   table %.1f / %.1f   %s"
              % (st, d["dmin"], lat, fond, etat))

    print("\n  🌞 SURFACE DE TOIT — le chiffre qui rejoint l'énergie")
    print("     %.2f ha sur %d bâtiments." % (toit / 1e4, total))

    n_coeur = par_st.get("coeur_ancien", {}).get("n_parc", 0)
    if n_coeur:
        print("\n  ☕ LES GRANDES COURS DU CŒUR ANCIEN — en plus de l'arrière que")
        print("     la profondeur creuse partout, une parcelle sur quatre garde")
        print("     une cour PLUS PROFONDE.")
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
        # ⚠️ `part_parcelle` EST CELLE DE LA PARCELLE ENTIÈRE, la même sur les
        # deux lignes d'une parcelle traversante : c'est le nombre que le plafond
        # de la table contraint, et le lire par bâtiment donnerait deux moitiés
        # dont aucune ne se compare à quoi que ce soit.
        couvert = sum(abs(D4C.aire_signee(m)) for m in r["emps"])
        for emp in r["emps"]:
            cur.execute(
                "INSERT INTO batiments (geom, fid_parcelle, fid_ilot,"
                " sous_type, famille, surface_m2, part_parcelle)"
                " VALUES (?,?,?,?,?,?,?)",
                (D4B.blob_gpkg(D4B.wkb_polygone([emp])), p["fid"], p["ilot"],
                 p["st"], TISSU[p["st"]][6],
                 round(abs(D4C.aire_signee(emp)), 1),
                 round(couvert / ap, 3) if ap else 0.0))
            for x, y in emp:
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
    return n


if __name__ == "__main__":
    for flux in (sys.stdout, sys.stderr):
        try:
            flux.reconfigure(encoding="utf-8", errors="replace")
        except (AttributeError, OSError):
            pass
    main()
