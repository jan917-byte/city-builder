#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
07 — La carte vers Godot, en un seul JSON.

    python3 QGIS/scripts/07_exporter_godot.py
    python3 QGIS/scripts/07_exporter_godot.py une_copie.gpkg

Sort Godot/data/wehrau.json : le terrain, les 69 îlots, la voirie, les arbres,
la palette. Recentré sur le milieu de l'emprise, prêt à empaqueter.

CE QUE CE FICHIER ASSUME, ET POURQUOI

Toute la géométrie du maillage est calculée en Python, pas en GDScript. Les
empreintes de bâtiments, elles, viennent directement de la couche `batiments`
écrite par 04d : l'export les extrude et leur pose un toit sans les redessiner.
Deux raisons, toutes deux dans `Vault/Technique/Moteur et architecture.md` :

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
                                           "travail", "wehrau.gpkg")
SORTIE = os.path.join(RACINE, "Godot", "data", "wehrau.json")

# --- les constantes de la maquette ---------------------------------------
ETAGE_M = 2.7              # `hauteur` est en ÉTAGES, pas en mètres
# 🔄 2026-08-18 : 3,0 → 2,7 m, demandé par l'auteur — « c'est trop haut » à
# l'écran. C'est LE seul levier global de hauteur : il multiplie tout le bâti
# d'un coup (−10 %) sans toucher à la table TISSU de `04`, qui est du level
# design et commande aussi la densité affichée. Le toit, lui, ne bouge pas :
# sa flèche vient de la PENTE et de la largeur de l'empreinte, pas des étages.
# En dessous de ~2,5 m un étage cesse d'être crédible ; c'est le plancher.
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
Y_CHAUSSEE = -0.02
Y_SOL = 0.05
HAUTEUR_BORDURE = 0.14     # la marche : mesure réelle d'une bordure de rue
Y_TROTTOIR = Y_CHAUSSEE + HAUTEUR_BORDURE
# 🔄 LE TROTTOIR EST PASSÉ AU-DESSUS DE LA CHAUSSÉE, le 2026-08-18. Il était
# EN DESSOUS, à 3 cm, et l'ancien commentaire justifiait ainsi cet ordre à
# l'envers du monde réel : « les deux sont des quadrilatères PLEINS, pas des
# anneaux ; le trottoir étant le plus large, s'il passait au-dessus il
# recouvrirait la chaussée entière et on ne verrait plus que du béton ».
# C'était vrai tant que le trottoir était un ruban plus LARGE glissé sous la
# rue. Il ne l'est plus : c'est maintenant un anneau qui longe la limite de
# parcelle, il ne recouvre plus rien, et il peut donc monter — ce qui est le
# seul moyen d'avoir une bordure. La même ligne disait aussi qu'une bordure
# modélisée « coûterait deux quads par arête pour un résultat sous le pixel » :
# à 14 cm elle en coûte deux, et elle ne passe pas sous le pixel.

# L'occlusion ambiante bakée en couleur de sommet. « Une occlusion ambiante
# marquée — c'est elle, et pas la géométrie, qui donne la profondeur »
# (Direction artistique l.21). C'est elle qui POSE les volumes au sol.
# 🔄 0,62 → 0,74 le 2026-08-18. À 0,62 le bas de chaque façade tombait à
# 62 % de sa valeur : sur des murs COLORÉS ça passait pour de l'ombre, sur
# des enduits clairs ça les ramenait tous au même gris et la variation de
# teinte entre deux maisons voisines disparaissait. Le SSAO reste là pour
# le contact au sol, qui est le vrai rôle de cette ombre.
AO_MIN = 0.74
AO_HAUTEUR = 6.0

M2_PAR_ARBRE = 40.0        # une couronne de ~3,5 m de rayon
ESPACEMENT_ALIGNEMENT = 8.0
GRAINE = 20260811          # le semis doit être le même à chaque export
# Le tronc d'un alignement fait 0,30 m de rayon, avec une échelle qui monte à
# 1,20 : 0,36 m au maximum. Les 4 cm restants absorbent l'arrondi des données
# exportées au centimètre ; le tronc entier, pas seulement son centre, doit
# rester hors de l'asphalte.
MARGE_TRONC_CHAUSSEE = 0.40

# 🌊 L'ILSE COULE 2 M SOUS LA VILLE — demandé par l'auteur le 2026-08-18, avec
# une coupe dessinée : la ville reste plate, l'eau descend de 2 m, et les
# CHAMPS qui bordent l'eau perdent leur bord franc au profit d'un talus.
#
#   champ 0 m ────┐                              ┌──── champ 0 m
#                  \___                      ___/          la pente, sur 10 m
#     ville 0 m ─┐      │██████████████│     /
#      le quai   │      └──────────────┘             −2,00 m  le plan d'eau
#                └──────────────────────             −2,60 m  le lit
#
# Donc DEUX bords d'eau et non plus un seul, et c'est la même ligne de code qui
# fait les deux : le mur de quai monte jusqu'au SOL, et le sol, lui, descend là
# où c'est un champ. Là où la ville tient la rive, le sol est à 0 et le mur
# fait 2,6 m ; là où c'est un champ, le sol est déjà au ras de l'eau et il ne
# reste du mur qu'une lèvre de 45 cm, noyée.
#
# 🔄 CE QUI A CHANGÉ, et pourquoi l'argument d'avant ne tient plus. Le commentaire
# de la veille disait : « une berge qui remonte en pente douce sur 12 m se
# lisait comme un talus, donc comme rien » — c'était vrai avec 1 m de creux
# (8 %). À 2,2 m sur 10 m la pente est à 22 %, et surtout elle ne remplace plus
# le mur PARTOUT : le contraste entre le quai droit de la ville et le talus des
# champs est ce qui fait lire les deux.
FOND_ILSE = -2.6           # le lit, sous l'eau, jamais vu
NAPPE_ILSE = -2.0          # le plan d'eau : 2 m sous la ville
# La crue se lit aussi dans la coupe de ville : le faubourg touché, rive
# gauche, est 1 m plus bas ; la terrasse intacte, rive droite, 1 m plus haut.
RIVE_GAUCHE_Y = -1.0
RIVE_DROITE_Y = 1.0
# ⚠️ La VOIRIE reste à 0, comme tout le reste : les trois franchissements
# passent donc au-dessus du chenal sans qu'aucune ligne de code ne parle de
# pont. C'est le creusement qui fabrique le pont, pas un tablier dessiné. Le
# talus ne change rien à ça — il s'écarte tout seul des routes, voir `Relief`.

# --- le talus des champs --------------------------------------------------
# TALUS_BAS est l'altitude que le SOL atteint au bord de l'eau : 15 cm SOUS la
# nappe, et pas à son niveau. Ces 15 cm sont ce qui évite une lèvre de terre
# affleurant l'eau sur tout le linéaire — le trait d'eau tombe ainsi ~70 cm en
# amont du bord du polygone, dans la pente, comme une vraie rive.
TALUS_BAS = -2.15
TALUS_LARGEUR = 10.0       # la course horizontale de la pente → 22 %
# Le pas de débit du talus. La pente est linéaire, donc ce pas ne sert qu'à
# deux choses : la cassure du HAUT (sinon elle se lisse sur 15 m) et le fondu
# près des autres bords du champ.
TALUS_PAS = 3.0
# De combien la plaque de sol s'enfonce SOUS le talus, en proportion du creux.
# Elle est invisible là-dessous (le champ la couvre) ; ce qu'on achète, c'est
# de ne jamais avoir à faire coïncider deux découpages différents. Sans cette
# marge, la plaque ressort par la cassure du haut, là où deux interpolations
# linéaires du même relief s'écartent de ~15 cm.
TALUS_DESSOUS = 0.25

# ================= LE BORD DE L'EAU : LE QUAI PORTÉ ET LE PONT (2026-08-18) ==
# 🌊 DEMANDÉ PAR L'AUTEUR, le jour même du creusement : « les routes au bord de
# la rivière volent sur l'eau. Fais en sorte qu'il y ait un mur entre l'eau et
# la route ; le mur peut dépasser de 1 m pour faire une barrière. Les routes qui
# passent sur l'eau doivent être transformées en pont. »
#
# CE QUI VOLAIT, MESURÉ AVANT DE TOUCHER À QUOI QUE CE SOIT : 7 212 m²
# d'asphalte au-dessus du chenal, sur 42 tronçons. Deux causes, et il faut les
# séparer parce qu'elles ne se réparent pas de la même façon :
#
#   ① la voie de berge est tracée SUR la ligne d'eau. Son bord côté rivière
#      dépasse la berge de 3,25 m (une voie `rive`) à 7,00 m (le boulevard de
#      quai). Elle ne traverse rien, elle LONGE.        → un QUAI PORTÉ
#   ② trois tronçons (145, 168, 169) traversent vraiment le chenal, sur 35 à
#      40 m, leurs DEUX bords au-dessus de l'eau.        → un PONT
#
# 🔴 LA RÈGLE QUI SÉPARE LES DEUX NE NOMME AUCUNE RUE, et c'est tout l'intérêt :
# on regarde, station par station le long de la chaussée, si l'eau est sous UN
# bord (on longe) ou sous LES DEUX (on traverse). Changer le tracé d'un quai
# dans la source refait son mur ; ajouter un franchissement fabrique son pont.
#
#   longer                              traverser
#   ─────────────┬──┐                  ┌──────────────┐  parapet
#     chaussée   │  │ +1,00             │   chaussée   │  ══════════ 0,05
#   ═════════════╪══╪ 0,05              ├──────────────┤  tablier −0,65
#         (vide) ║  ║                   └──────────────┘
#   - - - - - - -║  ║ −2,00 nappe          ║  pile  ║      - - - - - -  −2,00
#   ─────────────╨──╨ −2,60 fond        ─────╨────────╨──
#
# 🔄 LE PARAPET EST LE MÊME MURET DANS LES DEUX CAS — c'est ce qui fait qu'un
# bord de pont et un bord de quai se ressemblent, comme dans une vraie ville.
# Ce qui change, c'est ce qu'il surmonte : le tablier du pont, ou le mur de
# quai qui descend au fond du chenal. Et ils se PARTAGENT la rive : le muret du
# pont s'arrête au nu du quai, celui du quai s'interrompt sous le tablier. Les
# deux se rejoignent en équerre au coin de la culée, et aucun ne monte sur la
# chaussée de l'autre (2026-08-19, voir `_bord_eau`).
# ⏸️ « UNE SEULE LIGNE DE MUR SUIT LA ROUTE » était la règle du 2026-08-18, et
# elle ne tient plus : le pont suit la route, le quai suit la BERGE. Voir plus
# bas, à `QUAI_PENTE`, pourquoi — et à quoi ça ressemblait avant.
BANDE_QUAI = 1.10          # de l'asphalte au nu extérieur du mur
PARAPET_H = 1.00           # le mètre demandé par l'auteur
PARAPET_EP = 0.40
# Au-delà de cette distance entre le bord de la chaussée et le bord de l'eau,
# la rue n'est plus au bord de l'eau : elle passe derrière quelque chose, et
# poser une barrière à 6 m d'elle ne voudrait rien dire. 4 m, c'est la largeur
# d'un trottoir plus sa bande libre.
QUAI_PORTEE = 4.00
QUAI_PAS = 2.00            # le débit de la ligne de mur
# 🔄 LE MUR SUIT LA BERGE, PAS LA ROUTE — refait le 2026-08-19 devant l'image.
# L'auteur : « les murs au bord des routes au bord du fleuve ne fonctionnent pas
# bien, ils doivent seulement longer le fleuve. » Jusqu'ici le mur était un
# DÉCALÉ DE LA CHAUSSÉE : on prenait son axe rallongé, on l'écartait de la
# demi-largeur plus la bande, et on rabattait sur la berge. Trois défauts, et
# tous les trois viennent de là, pas d'un réglage :
#   ① le mur héritait des ÉVASEMENTS de la chaussée aux carrefours, donc un
#      bout de mur en travers du débouché de chaque rue perpendiculaire — c'est
#      ce qu'on voit à l'écran au pied des trois ponts ;
#   ② il se coupait à chaque bout de tronçon : 21 morceaux, 21 paires de bouts
#      francs, dont un de 3,2 m tout seul au milieu de l'eau ;
#   ③ il s'écartait jusqu'à 47° de la direction de la berge — il zigzaguait
#      dans une rivière qui, elle, est droite.
# La règle d'aujourd'hui tient en une phrase : LE MUR SUIT LA BERGE. Il ne
# s'avance sur l'eau que là où l'asphalte y déborde, et d'autant — donc il
# porte toujours la rue, sans jamais quitter le fil du fleuve.
QUAI_SONDE = 0.35          # le pas de sonde qui cherche le bord de l'asphalte
# Au-delà, ce n'est plus un débord de quai : c'est un franchissement, et il a
# déjà son tablier. Sans ce plafond, la sonde traverserait l'Ilse en entier au
# droit d'un pont et le quai se mettrait à porter le pont.
QUAI_DEBORD_MAX = 14.0
# De combien le nu du mur a le droit de s'écarter d'une station à la suivante
# (2 m). C'est ce qui transforme la marche brutale d'un débouché de rue en un
# épaulement à 27° : le mur s'écarte, passe le carrefour, revient. Un simple
# maximum glissant aurait donné la même largeur avec des angles droits.
QUAI_PENTE = 1.00
# Le sinus maximal entre la berge et la chaussée pour que celle-ci compte comme
# LONGEANT le fleuve : 45°. Au-delà, la rue traverse, et une rue qui traverse ne
# déplace pas le bord de l'eau. C'est le même arbitrage que l'ancien `QUAI_COS`,
# mais posé au bon endroit : sur ce que la sonde a le droit de trouver, et non
# sur ce que la rue a le droit d'émettre.
QUAI_LONGE_SIN = 0.70
PONT_MIN = 8.0             # plus court que ça, ce n'est pas un ouvrage
PONT_CULEE = 2.5           # de combien le tablier mord sur la terre
TABLIER_EP = 0.70
TABLIER_TRAVEE = 20.0      # au-delà, une pile — 40 m d'un seul jet, non
PILE_COTE = 2.20           # l'épaisseur de la pile dans le sens du courant
PILE_RETRAIT = 0.80        # de combien elle est plus étroite que le tablier
Y_TABLIER = Y_SOL - TABLIER_EP
# ⚠️ LE DESSUS DU QUAI EST UN CENTIMÈTRE SOUS LE SOL, et ce centimètre est du
# travail en moins ailleurs. Le couronnement va du bord de l'asphalte au nu du
# mur : entre les deux il recouvre un bout de plaque de sol, et deux surfaces au
# même millimètre se battraient en duel sur tout le linéaire. Un centimètre plus
# bas, c'est le sol qui gagne et la bande reste invisible dessous. Elle est
# toujours 6 cm AU-DESSUS de l'asphalte, qui est le seul voisin qu'elle ne doit
# pas laisser passer devant — et 1 cm SOUS le tablier d'un pont, ce qui permet
# au quai de glisser dessous sans ressortir par la chaussée.
Y_QUAI = Y_SOL - 0.01

# 🌊 LA CRUE, CÔTÉ RENDU (04e · décision 23b). Deux constantes, et elles ne
# décident rien du jeu : `04e` dit QUI est ruiné, celles-ci disent à quoi ça
# ressemble.
# 🔄 REPRIS EN ENTIER le 2026-08-21. Une ruine était un rez-de-chaussée arasé
# à plat sous une dalle claire : cent bâtiments traités pareil sortaient en
# lotissement de toits plats, et l'auteur ne voyait AUCUNE destruction. Ce qui
# fait lire une ruine en axonométrie est sa CRÊTE CASSÉE et le trou sombre
# qu'elle laisse voir — pas sa teinte.
# 🔴 LES DEUX NOMBRES QUI PERMETTENT DE RECONSTRUIRE SANS RIEN EFFACER. Une
# ruine tient tout entière SOUS le bâtiment neuf qui la remplacera : sa crête
# reste sous 2,70 m (le rez le plus bas de la ville) et son emprise rentre de
# 5 cm. Montrer le maillage « réparé » suffit donc à faire disparaître la
# ruine — aucun nœud à retirer, aucune géométrie à reconstruire à l'exécution.
# ⚠️ Monter RUINE_PANS au-delà de 0,95 fait ressortir des bouts de mur cassé
# À TRAVERS les maisons reconstruites.
RUINE_PANS = (0.10, 0.36, 0.64, 0.88)   # hauteurs de pan de mur, en rez
RUINE_PAN_ARETES = (1, 3)               # arêtes consécutives à la même hauteur
RUINE_RETRAIT = 0.05                    # de combien la ruine rentre sous le neuf
RUINE_DALLE_Y = 0.08                    # le plancher éventré, au ras du sol
# 🌳 Au-dessus de cette hauteur d'eau, on ne plante plus rien : ni jardin, ni
# alignement. Ce n'est pas de la botanique — c'est ce qui fait que le faubourg
# CESSE D'ÊTRE VERT. Une rangée de tilleuls intacts au-dessus d'une rue de
# limon annulait à elle seule tout le reste.
CRUE_ARBRE_NOYE_M = 1.20
# De combien la coupure d'un pont emporté déborde de part et d'autre de l'eau.
# Assez pour que le vide se voie depuis la vue d'ensemble (touche V), pas assez
# pour manger la culée — sinon la route s'arrête au milieu du quai, ce qui se
# lit comme un bug de la chaîne et non comme un ouvrage détruit.
PONT_COUPE_MARGE = 3.0
PONT_RUINE_BOUT = 6.0      # moignon gardé depuis chaque culée
PONT_RUINE_CHUTE = 0.65    # affaissement du bord cassé

# 🔄 `alea` EST DE RETOUR (04e, décision 23b) : la crue rentre dans le prototype
# et l'îlot doit pouvoir dire ce qu'il a pris et ce qu'il risque. Il vient avec
# les quatre chiffres de dégât de `04e`. `altitude_relative` reste dehors — la
# carte est plate, et le profil de terrain de `04e` est un profil de CALCUL qui
# ne remonte aucune géométrie.
COLS_ILOTS = [
    "fid", "fonction", "sous_type", "surface_m2", "solaire_possible",
    "hauteur", "impermeabilise",
    "canopee", "stationnement",
    "position_fil_eau", "rive", "densite", "logements", "emplois", "riverain",
    "desserte_tc",
    "alea", "hauteur_eau_max", "part_ruinee", "part_ruinee_apres",
    "part_sinistree", "logements_sinistres",
    # 🔧 CE QUE LA RÉPARATION COÛTE, calculé par `04e` et jamais ici : le prix
    # est du level design, il vit avec les sept nombres de la crue.
    "batiments_ruines", "cout_reparation_ke",
]
COLS_ROUTES = ["fid", "hierarchie", "largeur_m", "emprise_libre_m", "charge",
               "canopee", "stationnement", "etat_crue", "hauteur_eau",
               "cout_reparation_ke"]

# Ce qui part dans `objets` : la fiche qu'on lit en cliquant, et l'état de
# départ du noyau. Tout ce qui n'est pas là ne peut ni s'afficher ni évoluer.
FICHE_ILOTS = [c for c in COLS_ILOTS if c != "fid"]
# 🔗 L'interface du toit (41 · 64), calculée et non lue dans le `.gpkg` :
# surface réelle, pente, et le drapeau « toit plat ». L'ombrage, lui, est déjà
# là — c'est `canopee`.
TOIT_ILOTS = ["toit_m2", "toit_pente", "toit_plat", "toit_m2_neuf"]
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


# --- LA RECETTE HISTORIQUE DU BÂTI ----------------------------------------
# 🔄 Depuis le 2026-08-17, 04d transforme la parcelle en empreinte et 07 lit
# cette couche. Cette table ne commande plus la forme : seule sa colonne
# `pente` reste consommée pour plier le toit. Les anciens auxiliaires sont
# encore présents plus bas pour rendre le retour en arrière lisible, mais le
# chemin principal ne les appelle plus.
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
    "collectif_1995":          (5.0,  4.0,   13.0,     0.55),  # deux pentes, plus plates qu'en ville ancienne
    "ilot_compact":            (1.0,  0.0,   12.0,     0.12),  # quasi plat : du panneau, pas du comble
    "equipement":              (4.0,  3.0,   22.0,     0.25),
    "friche_industrielle":     (3.0,  2.5,   35.0,     0.00),  # des halles
}
BATI_DEFAUT = (2.0, 1.0, 12.0, 0.50)

# 📦 LES VOLUMES QUI SE SIMPLIFIENT EN RECTANGLE, alignés sur la rue.
# Une barre, un hangar, une halle : ce sont des boîtes. Les faire suivre le
# découpage parcellaire leur donnait des biais et des pointes qu'aucun béton
# des années 1970 n'a jamais eus. On garde l'emprise au sol — le rectangle est
# celui de la parcelle bâtie, pas une taille inventée.
RECTANGULAIRE = {"barre_1970", "friche_industrielle"}

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
    "collectif_1995":        0.45,   # pelouse tondue, et le reste en places
    "ilot_compact":          0.85,   # la cour EST plantée, c'est tout le sujet
    "equipement":            0.45,   # cour de récréation ou pelouse
    "friche_industrielle":   0.20,   # des friches, pas des prés
}
VERDURE_DEFAUT = 0.40
AIRE_JARDIN_MIN = 12.0     # en dessous, c'est un délaissé, pas un jardin
M2_PAR_ARBRE_JARDIN = 120.0
PART_JARDINS_ARBORES = 0.55   # parmi les jardins verts, ceux qui ont un arbre

# 🌿 LES HAIES ET L'ACCÈS DU PAVILLONNAIRE. La haie fait maintenant tout
# le tour de chaque parcelle bâtie, rue comprise, et ne s'ouvre qu'au droit du
# chemin de la maison. Le chemin est le plus court parmi ceux qui arrivent
# PERPENDICULAIREMENT à une limite sur rue : ce n'est donc ni une diagonale
# choisie à l'œil, ni un objet posé à la main. Une limite partagée n'est
# émise qu'une fois, sinon deux prismes superposés clignoteraient à l'écran.
HAIE_LARGEUR = 0.55
HAIE_HAUTEUR = 1.15
HAIE_SEGMENT_MIN = 1.5
ACCES_LARGEUR = 1.40
ACCES_OUVERTURE = ACCES_LARGEUR + HAIE_LARGEUR

# Un faîtage ne monte jamais plus haut que ça, quelle que soit la pente. Sans
# ce plafond, une empreinte profonde se coiffe d'un chapeau de dix mètres qui
# écrase tout le reste.
FAITAGE_MAX = 5.5

# ============================ LE RELIEF DU TOIT (2026-08-18) ==============
# 🏠 LE DÉBORD, et c'est LA ligne qui fait qu'un volume cesse d'être une boîte.
# Jusqu'ici le toit s'arrêtait exactement sur le mur : aucune ombre portée sur
# la façade, aucune épaisseur, donc un solide monolithique qu'on lisait comme
# du plastique. Un vrai toit dépasse de 30 à 60 cm, et cette bande d'ombre est
# le premier signal que l'œil reçoit d'une maison vue d'en haut.
#
#          ┌───────────────┐   ← le toit, décalé vers l'extérieur
#        ══╧══           ══╧══ ← la rive : la tranche visible, EPAISSEUR_TOIT
#          │ mur           │
#
# ⚠️ Le toit est monté de EPAISSEUR_TOIT au lieu d'être posé au ras du mur :
# sinon on voit SOUS le débord dès que la caméra descend (10° est une vue
# offerte par la maquette), et sous le débord il n'y a rien — les faces
# arrière sont cullées, donc on voit à travers la maison.
DEBORD_TOIT = 0.40
EPAISSEUR_TOIT = 0.26

# 🧱 L'ACROTÈRE — le muret qui borde un toit plat. Sans lui, la barre de 1974
# et les halles sont des boîtes rases, et rien ne dit que leur dessus est une
# toiture plutôt qu'une tranche. Émis EN DOUBLE FACE (deux quads opposés par
# arête) : ça revient moins cher qu'un vrai muret d'épaisseur, et à 45 cm de
# haut la tranche du dessus ne se voit à aucun zoom du jeu.
ACROTERE = 0.45

# 🔥 LES SOUCHES DE CHEMINÉE. Le seul détail de ce lot qui soit un OBJET et
# non une règle de surface — et il vaut son coût : vue d'en haut, c'est ce qui
# distingue un toit habité d'un couvercle. 0,8 m de côté est la taille réelle
# d'une souche de maison ancienne ; en dessous, le volume passe sous le pixel
# à la vue par défaut et se met à scintiller.
CHEMINEE_COTE = 0.8
CHEMINEE_HAUT = 1.3
CHEMINEE_AIRE_MIN = 45.0   # une remise de fond de cour n'a pas de cheminée
PART_CHEMINEES = 0.80      # pas toutes : une rangée régulière serait un peigne

# ============================ LES FENÊTRES (2026-08-18) ==================
# 🪟 DEMANDÉES PAR L'AUTEUR le 2026-08-18, juste après le lot toits + sol. La
# note d'étape disait « pas les fenêtres » ; elle ne le dit plus.
#
# 🔴 AUCUNE FENÊTRE N'EST UN TRIANGLE. Elles sont dessinées par le shader de
# `Godot/scripts/materiaux.gd`, comme les rangs de tuile et les panneaux
# solaires — « le détail va dans le matériau, jamais dans le maillage ». Deux
# quads par fenêtre sur les 700 volumes coûteraient ~40 000 triangles pour un
# détail qui, à la vue par défaut, tient sur deux pixels.
#
# CE QUE PYTHON DÉCIDE, ET CE QU'IL PASSE. Le shader ne sait rien de Wehrau :
# il reçoit quatre nombres par sommet de mur, et rien d'autre.
#
#   uv  = (u, L)        u : mètres le long de la façade depuis son coin
#                       L : longueur totale de CETTE façade
#   uv2 = (genre, alea) genre : la recette de percement, ci-dessous
#                       alea  : le tirage du bâtiment (35), le même sur ses
#                               quatre murs — donc un rythme par maison
#
# ⚠️ `L` EST CE QUI CENTRE LES TRAVÉES, et ce n'est pas un raffinement. Sans
# lui le shader poserait une trame de pas fixe sur une grille mondiale : un
# mur de 7,2 m et son voisin de 11,8 m sortiraient avec des demi-fenêtres
# dans les angles. C'est la faute exacte que la grille de panneaux a coûté à
# corriger le 2026-08-17 — on ne la refait pas.
FACADE_AVEUGLE = 0    # mitoyen, ou trop court pour porter une travée
FACADE_LOGEMENT = 1   # des fenêtres, rien d'autre
FACADE_PORTE = 2      # + une porte au rez : c'est l'entrée du bâtiment
FACADE_VITRINE = 3    # un rez commerçant vitré, du logement au-dessus
FACADE_BANDEAU = 4    # une bande vitrée filante : la barre et les halles

# (ce qu'on met sur la rue, ce qu'on met ailleurs). L'arrière n'a jamais
# d'entrée : une maison à deux portes se voit tout de suite et ne s'explique
# pas. Le front commerçant est le seul tissu où le REZ change de nature.
FACADE_TISSU = {
    "coeur_ancien":        (FACADE_PORTE,   FACADE_LOGEMENT),
    "front_commercant":    (FACADE_VITRINE, FACADE_LOGEMENT),
    "maisons_de_ville":    (FACADE_PORTE,   FACADE_LOGEMENT),
    "pavillonnaire":       (FACADE_PORTE,   FACADE_LOGEMENT),
    "equipement":          (FACADE_PORTE,   FACADE_LOGEMENT),
    "barre_1970":          (FACADE_BANDEAU, FACADE_BANDEAU),
    "friche_industrielle": (FACADE_BANDEAU, FACADE_BANDEAU),
}
FACADE_TISSU_DEFAUT = (FACADE_PORTE, FACADE_LOGEMENT)

# En dessous, le mur est un pan coupé d'angle ou un décrochement : une travée
# n'y tient pas, et une demi-fenêtre au coin est pire que rien. C'est aussi le
# seuil qui sépare `uv` d'un mur de `uv` d'un toit — voir `Maillage.triangle`.
FACADE_MIN = 2.0

# 🧱 LE MUR MITOYEN EST AVEUGLE, et c'est ce qui fait la rangée du cœur
# ancien : deux façades percées sur rue et sur cour, deux pignons pleins. Un
# mur est mitoyen si les trois quarts de sa longueur longent, à moins de
# MITOYEN_JEU, une arête presque parallèle d'un AUTRE bâtiment du même îlot.
# Le test se fait en trois points : un seul point suffirait à déclarer
# mitoyen un mur qui ne fait qu'effleurer le coin du voisin.
MITOYEN_JEU = 0.30
MITOYEN_SINUS = 0.30       # ~17° : au-delà, les deux murs se croisent

# 🚪 CE QUI DÉCIDE QU'UN MUR DONNE SUR LA RUE. Trois conditions, et il faut
# les trois : le mur est PARALLÈLE à une limite sur rue de sa parcelle, il en
# est à moins de RETRAIT_MAX, et cette limite est DU CÔTÉ DE SON DEHORS.
#
# 🔄 RETOUR EN ARRIÈRE SIGNALÉ. La première version mesurait si un pas d'un
# mètre vers le dehors RAPPROCHAIT de la rue. C'est faux dès que le bâtiment
# est bâti à l'alignement — la distance vaut alors 0, tout pas l'augmente, et
# la façade la plus commerçante de la ville sortait « arrière ». Mesuré : 2
# vitrines pour 49 volumes de front commerçant. On regarde donc le SIGNE et
# non la variation : une rue à distance nulle est du bon côté.
RETRAIT_MAX = 12.0         # au-delà, le bâtiment est en fond de parcelle
RUE_SINUS = 0.40           # ~24° : une façade oblique adresse encore la rue
RUE_DERRIERE = 0.20        # ce qu'on tolère de rue « derrière » le mur

# Le compte rendu des façades, par genre — même famille que `cheminees`.
facades = [0, 0, 0, 0, 0]
facades_m = [0.0, 0.0, 0.0, 0.0, 0.0]

# 🚶 LE TROTTOIR. Il se prend toujours sur les mètres LIBRES du tronçon
# (`largeur_m` moins l'emprise de circulation), donc il n'existe que là où la
# donnée en laisse la place — une ruelle de 5 m n'en a pas, et c'est juste.
# 🔄 Mais il a changé de PLACE le 2026-08-18 : il longe désormais la limite de
# parcelle et tourne les coins de rue. Le détail est dans `_trottoirs`.
LARGEUR_TROTTOIR = 2.0
# 🔲 Ce qu'on ajoute à `largeur_m` pour décrire le COULOIR d'un tronçon — la
# bande façade à façade dont Godot fait la silhouette de sélection. C'est la
# tolérance de `_rue_le_long` (0,75 m de chaque côté) : un trottoir peut être
# posé jusque-là, et un couloir plus étroit que son propre trottoir ferait un
# trait qui coupe le trottoir en deux.
MARGE_COULOIR = 1.5
TROTTOIR_MIN = 0.8         # en dessous, pas de trottoir du tout : un liseré de
                           # 40 cm ne se lit pas, il salit la rue
JEU_CHAUSSEE = 0.10        # le trottoir ne touche jamais l'asphalte
LIMITE_MITRE_TROTTOIR = 2.5

# 🛣️ LES COURBES. Un tronçon est une polyligne : à chaque sommet intérieur la
# chaussée cassait à angle vif. Ce sont ces 89 coudes INTERNES qui
# s'arrondissent ; les 110 nœuds à trois branches ou plus sont des CARREFOURS
# et gardent leur angle — demandé par l'auteur, et c'est aussi ce qui garde un
# carrefour lisible. Le rayon retenu n'est pas un réglage mais le résultat de
# quatre plafonds mesurés : voir `_rayon_coude`, c'est là que tout se joue.
COUDE_MIN_DEG = 20.0       # en dessous, l'œil ne voit pas la cassure
RAYON_MAX = 25.0           # le confort : au-delà, une rue de ville serpente
RAYON_MIN = 5.0            # plus court, l'arc ne se distingue plus de l'angle
ELARGISSEMENT_MAX = 3.0    # ce que le trottoir extérieur a le droit de gagner
JEU_COUDE = 0.5            # ce qui doit rester de trottoir intérieur
PAS_ARC_DEG = 6.0          # 6° : à 12° l'arc se lit comme un pan coupé

# 🎨 LE MARQUAGE AU SOL — lignes blanches et passages piétons.
#
# 🔴 AUCUN TRAIT N'EST PLACÉ À LA MAIN. Ce qui suit est une petite voirie :
# sept règles qui lisent la largeur de chaussée, la hiérarchie du tronçon, le
# nombre de branches à chaque nœud et la courbure de l'axe. Changer une rue
# dans la source rebâtit son marquage sans qu'on y revienne — c'est la seule
# façon de tenir 180 tronçons à un contre un.
#
#   ① ligne d'axe        chaussée ≥ AXE_MIN_CHAUSSEE (deux voies)
#   ② axe continu        là où la direction tourne de CONTINUE_ANGLE en moins
#                        de CONTINUE_FENETRE m — on ne double pas dans un virage
#   ③ ligne de rive      boulevard et voie de berge seulement
#   ④ rien au carrefour  le marquage longitudinal s'arrête à la zone d'échange
#   ⑤ passage piéton     sur chaque branche de carrefour QUI A UN TROTTOIR
#   ⑥ traversée de plus  si un tronçon reste plus de ESPACEMENT_TRAVERSEE sans
#                        passage, on en pose un au milieu
#   ⑦ jamais sur l'eau   un passage piéton ne se peint pas sur un pont
#
# ⚠️ La règle ⑤ est celle qui exclut TOUTE LA VOIRIE ÉTROITE sans qu'on ait à
# la nommer : une ruelle de 5 m n'a pas la place d'un trottoir (§ TROTTOIR_MIN),
# donc elle n'a pas de passage piéton. C'est le même test que `_largeur_trottoir`,
# pas une seconde liste.
Y_MARQUAGE = Y_CHAUSSEE + 0.01   # 1 cm de peinture au-dessus de l'asphalte
LARGEUR_LIGNE = 0.15             # la largeur réglementaire d'une ligne urbaine
AXE_MIN_CHAUSSEE = 5.5           # en dessous, une seule voie : pas d'axe
AXE_TRAIT = 3.0                  # discontinue urbaine : 3 m de trait…
AXE_VIDE = 6.0                   # …et 6 m de vide. Hors agglo ce serait 3/10.
CONTINUE_ANGLE = 30.0            # le virage à partir duquel l'axe devient plein
CONTINUE_FENETRE = 30.0          # sur quelle longueur on cumule ce changement
CONTINUE_PORTEE = 12.0           # ce que le trait plein déborde de part et d'autre
RIVE_RETRAIT = 0.35              # la ligne de rive, comptée depuis le bord
HIER_LIGNE_RIVE = ("boulevard", "rive")
PASSAGE_BANDE = 0.50             # bande de 50 cm…
PASSAGE_ECART = 0.50             # …et 50 cm entre deux : la trame réelle
PASSAGE_PROFONDEUR = 2.50        # la profondeur de traversée, minimum réel
PASSAGE_JEU_BORD = 0.30          # la trame ne touche pas le bord de chaussée
PASSAGE_RECUL = 0.80             # ce qui sépare le passage de la zone d'échange
ESPACEMENT_TRAVERSEE = 120.0     # au-delà, un piéton traverse n'importe où
JEU_MARQUAGE = 0.60              # le blanc laissé autour d'une zone interdite

# 🅿️ LA TRAME DE STATIONNEMENT DE LA PLACE-PARKING.
#
# 🔴 AUCUNE PLACE N'EST PLACÉE À LA MAIN, et aucune n'est comptée à la main
# non plus : `04` annonce 127 places sur l'îlot 19 (sa surface × la part de
# parking du tissu ÷ SURFACE_PAR_PLACE). Jusqu'ici ce nombre n'existait que
# dans la fiche — la place était un aplat gris. Ce qui suit le DESSINE, et le
# compte qu'on imprime est celui des places réellement rangées : c'est le
# premier endroit du projet où le chiffre du tableur peut être contredit par
# la géométrie.
#
#   ① la direction   la plus longue arête de l'emprise. Sur une emprise, une
#                    arête est une façade sur rue : la plus longue est la
#                    façade principale, et c'est parallèlement à elle qu'un
#                    parking se range.
#   ② le module      allée + deux rangées dos à dos = 16 m, répété en travers
#   ③ le glissement  la trame glisse (16 crans en travers, 5 le long) et on
#                    garde la position qui range le plus de voitures — c'est
#                    ce que fait un géomètre avec son calque
#   ④ la place tient dans l'emprise retirée du bord, ses quatre coins compris
#   ⑤ l'accès        3 m d'allée DEVANT elle, sinon elle est enclavée derrière
#                    une autre rangée et personne n'y accède
#
# ⚠️ Le retrait de bord n'est pas une marge de dessin : c'est ce qui reste de
# sol nu tout autour, par où on entre et on ressort. À 0,5 m la trame monte à
# 153 places et vient buter contre le trottoir ; à 6 m elle tombe à 96 et la
# place se vide. 3 m donne 24,9 m² par place — la valeur même que `04` prend
# pour SURFACE_PAR_PLACE, alors que les deux ne se sont jamais parlé.
PLACE_LARGEUR = 2.50             # une place : 2,50 m…
PLACE_LONGUEUR = 5.00            # …sur 5,00 m
ALLEE_PARKING = 6.00             # l'allée de desserte : ressortir en une manœuvre
MODULE_PARKING = ALLEE_PARKING + 2 * PLACE_LONGUEUR
BORD_PARKING = 3.00              # ce que la trame laisse tout autour
ACCES_PARKING = 3.00             # l'allée exigée devant une place
GLISSEMENT_V = 16                # les crans d'essai de la trame, en travers…
GLISSEMENT_U = 5                 # …et le long
# La peinture de la place est 1 cm au-dessus du SOL de l'îlot, et non au-dessus
# de la chaussée : Y_MARQUAGE (−0,01) passerait 6 cm SOUS la place, qui est un
# cap d'îlot à Y_SOL. Le marquage serait invisible et rien ne le dirait.
Y_MARQUAGE_SOL = Y_SOL + 0.01

# 🌾 LES BANDES DE FAUCHE. Un champ était un aplat de 3 ha ; c'est la plus
# grande surface unie de l'image et elle sonne faux. On le coupe en bandes
# alternées à ±5,5 % de valeur — l'écart d'une fauche, pas d'une culture
# différente. À 0,12 on lit un damier ; à 0,02 on ne lit rien.
BANDE_CHAMP = 15.0
BANDE_ECART = 0.055

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
cheminees = [0]         # souches posées — 2026-08-18

# La brique enduite de la souche, une fois pour toutes : convertie à l'import
# plutôt qu'à chaque bâtiment, et posée ici pour qu'aucun appel de `_toit`
# n'ait à la traîner depuis `main()`.
COUL_CHEMINEE = PAL.vers_lineaire(PAL.CHEMINEE)

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
        self._coupes_rive = {}
        ys = [p[1] for a in self.rivieres for p in a]
        self._y_rive = (min(ys), max(ys)) if ys else (0.0, 0.0)
        for k, (p, q) in enumerate(self.berges):
            for cx in range(int(min(p[0], q[0]) // self.pas),
                            int(max(p[0], q[0]) // self.pas) + 1):
                for cy in range(int(min(p[1], q[1]) // self.pas),
                                int(max(p[1], q[1]) // self.pas) + 1):
                    self.idx.setdefault((cx, cy), []).append(k)

    def dans_eau(self, p):
        return any(dedans(r, p) for r in self.rivieres)

    def niveau_rive(self, x, y, eau_plate=True):
        """Décalage vertical des deux rives ; l'eau reste horizontale.

        L'Ilse coule vers le sud : face à l'aval, sa rive gauche est à l'est.
        Une coupe horizontale donne son milieu local même dans le grand S.
        """
        cle = int(round(y * 4.0))
        coupe = self._coupes_rive.get(cle)
        if coupe is None:
            yc = min(max(cle / 4.0, self._y_rive[0] + 1e-4),
                     self._y_rive[1] - 1e-4)
            xs = []
            for a in self.rivieres:
                for p, q in zip(a, a[1:]):
                    if (p[1] <= yc < q[1]) or (q[1] <= yc < p[1]):
                        t = (yc - p[1]) / (q[1] - p[1])
                        xs.append(p[0] + (q[0] - p[0]) * t)
            coupe = (min(xs), max(xs)) if len(xs) >= 2 else (x, x)
            self._coupes_rive[cle] = coupe
        gauche_x, droite_x = coupe
        if eau_plate and gauche_x < x < droite_x:
            return 0.0
        milieu = (gauche_x + droite_x) / 2.0
        return RIVE_GAUCHE_Y if x > milieu else RIVE_DROITE_Y

    def est_berge(self, a, b):
        return tuple(sorted((_cle(a), _cle(b)))) in self.cles_berges

    def berges_autour(self, x0, y0, x1, y1):
        """Les arêtes de berge qui peuvent traverser la maille."""
        vus = set()
        for cx in range(int(x0 // self.pas), int(x1 // self.pas) + 1):
            for cy in range(int(y0 // self.pas), int(y1 // self.pas) + 1):
                vus.update(self.idx.get((cx, cy), ()))
        return [self.berges[k] for k in vus]

    def plaque(self, x0, y0, x1, y1, pas, relief=None):
        """Le sol : des morceaux plats à 0, troués là où passe le chenal.

        `relief` ne creuse rien ici — il dit seulement OÙ la maille de 16 m est
        trop grossière. Sous un talus elle est redébitée sur la grille absolue
        de `TALUS_PAS` : c'est la même grille que celle du talus lui-même, donc
        les deux surfaces tombent sur les mêmes sommets et l'une ne peut pas
        ressortir de l'autre.
        """
        out = []
        approx = 0
        nx = int(math.ceil((x1 - x0) / pas))
        ny = int(math.ceil((y1 - y0) / pas))
        for j in range(ny):
            for i in range(nx):
                ax, ay = x0 + i * pas, y0 + j * pas
                bx, by = min(ax + pas, x1), min(ay + pas, y1)
                maille = [(ax, ay), (bx, ay), (bx, by), (ax, by)]
                if relief is not None and relief.boite_active(ax, ay, bx, by):
                    cellules = _grille(maille, TALUS_PAS)
                else:
                    cellules = [maille]
                for cel in cellules:
                    cx0 = min(p[0] for p in cel)
                    cy0 = min(p[1] for p in cel)
                    cx1 = max(p[0] for p in cel)
                    cy1 = max(p[1] for p in cel)
                    proches = [s for s in self.berges_autour(cx0, cy0, cx1, cy1)
                               if _coupe_boite(s, cx0, cy0, cx1, cy1)]
                    if not proches:
                        c = (sum(p[0] for p in cel) / len(cel),
                             sum(p[1] for p in cel) / len(cel))
                        if not self.dans_eau(c):
                            out.append(cel)
                        continue
                    if len(proches) > 1:
                        approx += 1
                    morceaux = [cel]
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


# ============================================================ le talus des champs

# Une arête d'emprise est « riveraine » si elle est POSÉE sur la berge. Mesuré
# le 2026-08-18 : les 4 champs riverains ont bien leurs arêtes à 0,00 m de
# l'eau (04b ne les recule pas — `larg` y est nul), mais leurs SOMMETS ne
# coïncident pas avec ceux du polygone d'eau : le retrait des arêtes voisines
# les a fait glisser le long de la rive. D'où un test de distance, et non
# d'égalité de clés — l'égalité ne trouvait que 6 arêtes sur 10.
BORD_EAU_TOL = 0.5


class Relief(object):
    """La descente des champs vers l'Ilse — la seule chose qui ne soit pas
    plate sur la carte, avec le chenal lui-même.

    UNE SEULE FONCTION, `z(x, y)`, et tout ce qui touche le sol la lit : la
    plaque, le champ, ses bandes de fauche, ses arbres, et le haut du mur de
    quai. C'est ce qui garantit qu'aucune de ces surfaces ne peut se fendre
    sur une autre — elles partagent la même vérité, pas une recopie.

        z = CREUX · f(distance à l'eau) · g(distance aux autres bords)

    · `f` descend de 1 au bord de l'eau à 0 à `TALUS_LARGEUR` : c'est la pente
      dessinée par l'auteur, droite, avec sa cassure en haut.
    · `g` la REMONTE à 0 dès qu'on approche d'un autre bord du champ, sur la
      même distance. C'est elle qui fait tout le travail difficile, et sans
      elle il aurait fallu trois cas particuliers :
        — au raccord ville/champ, le talus se relève sur 10 m et le mur de
          quai sort du sol tout seul, au lieu d'une marche de 2 m ;
        — un pont qui traverse un champ garde sa terre à 0 de part et d'autre :
          la route est un couloir DEHORS de l'emprise, donc `g` s'y annule ;
        — rien ne déborde jamais de l'emprise du champ, donc ni la voirie ni
          les trottoirs n'ont à savoir que le relief existe.

    ⚠️ Le creux est mesuré depuis `Y_SOL`, pas depuis 0 : la surface du champ
    est ce qui doit toucher l'eau, pas le plan de référence.
    """

    CREUX = TALUS_BAS - Y_SOL          # −2,20 m

    def __init__(self, chenal, champs):
        """`champs` : {fid: anneau d'emprise ouvert} des îlots `champ`."""
        self.zones = {}
        for fid in sorted(champs):
            an = list(champs[fid])
            n = len(an)
            riv, autres = [], []
            for i in range(n):
                a, b = an[i], an[(i + 1) % n]
                if math.hypot(b[0] - a[0], b[1] - a[1]) < 1e-9:
                    continue
                (riv if _sur_la_berge(a, b, chenal) else autres).append((a, b))
            if not riv:
                continue
            sens = 1.0 if aire_signee(an) > 0.0 else -1.0
            lignes = []
            for (a, b) in riv:
                dx, dy = b[0] - a[0], b[1] - a[1]
                L = math.hypot(dx, dy)
                # Normale INTÉRIEURE : à gauche de a→b si l'anneau est
                # trigonométrique. On mesure le sens au lieu de le supposer —
                # une normale retournée mettrait le talus dans la rivière.
                nx, ny = sens * (-dy / L), sens * (dx / L)
                lignes.append(((a[0] + nx * TALUS_LARGEUR,
                                a[1] + ny * TALUS_LARGEUR), (nx, ny)))
            xs = [p[0] for p in an]
            ys = [p[1] for p in an]
            self.zones[fid] = {
                "ferme": an + [an[0]],
                "riv": riv, "autres": autres, "lignes": lignes,
                "boite": (min(xs), min(ys), max(xs), max(ys)),
                "longueur": sum(math.hypot(b[0] - a[0], b[1] - a[1])
                                for a, b in riv),
            }

    # -- lecture -----------------------------------------------------------

    def z(self, x, y):
        """Le creusement au point, ≤ 0. Hors d'un champ riverain : 0,0 pile."""
        if not self.zones:
            return 0.0
        p = (x, y)
        val = 0.0
        for z in self.zones.values():
            bx0, by0, bx1, by1 = z["boite"]
            if x < bx0 or x > bx1 or y < by0 or y > by1:
                continue
            d = _d_segments(p, z["riv"])
            if d >= TALUS_LARGEUR:
                continue
            # 🔴 PIÈGE PAYÉ LE 2026-08-18, et il se voyait à l'écran : un point
            # POSÉ SUR la rive n'est ni dedans ni dehors pour `dedans()`, et il
            # ressortait à 0 pendant que ses voisins descendaient à −2,20. La
            # plaque et le talus sont justement coupés SUR cette ligne : la
            # berge se hérissait de dents grises d'un mètre, une par sommet.
            # Le bord de l'eau appartient au champ, point.
            if d > 0.05 and not dedans(z["ferme"], p):
                continue
            f = 1.0 - d / TALUS_LARGEUR
            g = 1.0
            if z["autres"]:
                g = min(1.0, _d_segments(p, z["autres"]) / TALUS_LARGEUR)
            val = min(val, self.CREUX * f * g)
        return val

    def boite_active(self, x0, y0, x1, y1):
        """La boîte touche-t-elle un talus ? Sert à décider d'un débit fin,
        jamais à décider d'une altitude.

        ⚠️ VRAIE DISTANCE au segment, et pas recouvrement de boîtes. Mesuré le
        2026-08-18 : le test par boîtes faisait passer la plaque de 8 000 à
        28 000 triangles, parce que la rive du champ 3 est une diagonale de
        266 m dont la boîte englobante couvre un quart de la carte."""
        for z in self.zones.values():
            bx0, by0, bx1, by1 = z["boite"]
            # La boîte du CHAMP en plus de la distance à sa rive : sans elle on
            # débitait aussi la plaque au milieu de l'eau et sur le quai d'en
            # face, où le relief vaut 0 — 3 000 triangles pour rien.
            if x1 < bx0 or x0 > bx1 or y1 < by0 or y0 > by1:
                continue
            for (a, b) in z["riv"]:
                if _d_boite_segment(x0, y0, x1, y1, a, b) < TALUS_LARGEUR:
                    return True
        return False

    # -- découpe -----------------------------------------------------------

    def trier(self, fid, morceau):
        """Coupe un morceau de champ par les droites de haut de talus et rend
        [(morceau, en_pente)]. Les deux familles sortent de LA MÊME découpe :
        elles pavent le champ exactement, sans recouvrement ni fente."""
        z = self.zones.get(fid)
        if z is None:
            return [(morceau, False)]
        morceaux = [morceau]
        for (p0, nrm) in z["lignes"]:
            suite = []
            for mo in morceaux:
                suite.extend(D4C.couper(mo, p0, nrm))
            morceaux = suite
        out = []
        for mo in morceaux:
            if len(mo) < 3:
                continue
            c = (sum(p[0] for p in mo) / len(mo),
                 sum(p[1] for p in mo) / len(mo))
            out.append((mo, _d_segments(c, z["riv"]) < TALUS_LARGEUR))
        return out

    def mesures(self):
        return (len(self.zones),
                sum(z["longueur"] for z in self.zones.values()))


def _sur_la_berge(a, b, chenal):
    """L'arête (a, b) est-elle posée sur la berge ? Les trois points testés —
    les deux bouts ET le milieu — évitent qu'une arête qui touche la rive par
    un seul sommet passe pour une rive entière."""
    x0, x1 = min(a[0], b[0]) - 1.0, max(a[0], b[0]) + 1.0
    y0, y1 = min(a[1], b[1]) - 1.0, max(a[1], b[1]) + 1.0
    proches = chenal.berges_autour(x0, y0, x1, y1)
    if not proches:
        return False
    m = ((a[0] + b[0]) / 2.0, (a[1] + b[1]) / 2.0)
    return all(_d_segments(p, proches) < BORD_EAU_TOL for p in (a, b, m))


def _d_segments(p, segs):
    return min(_d_point_seg(p, a, b) for a, b in segs)


def _d_boite_segment(x0, y0, x1, y1, a, b):
    """Distance d'une boîte à un segment. 0 s'ils se coupent — testé par les
    quatre côtés de la boîte, sans quoi un segment qui la traverse de part en
    part passerait pour lointain (aucun de ses bouts n'est dedans, et les coins
    peuvent être plus loin que le seuil)."""
    coins = [(x0, y0), (x1, y0), (x1, y1), (x0, y1)]
    for k in range(4):
        if _se_croisent(a, b, coins[k], coins[(k + 1) % 4]):
            return 0.0
    d = min(_d_point_seg(c, a, b) for c in coins)
    for p in (a, b):
        d = min(d, math.hypot(max(x0 - p[0], 0.0, p[0] - x1),
                              max(y0 - p[1], 0.0, p[1] - y1)))
    return d


def _se_croisent(a, b, c, d):
    def cote(p, q, r):
        v = (q[0] - p[0]) * (r[1] - p[1]) - (q[1] - p[1]) * (r[0] - p[0])
        return (v > 1e-12) - (v < -1e-12)
    return (cote(a, b, c) * cote(a, b, d) <= 0
            and cote(c, d, a) * cote(c, d, b) <= 0)


def _d_point_seg(p, a, b):
    ax, ay = b[0] - a[0], b[1] - a[1]
    ll = ax * ax + ay * ay
    u = 0.0 if ll < 1e-12 else max(0.0, min(
        1.0, ((p[0] - a[0]) * ax + (p[1] - a[1]) * ay) / ll))
    return math.hypot(p[0] - (a[0] + u * ax), p[1] - (a[1] + u * ay))


def _grille(anneau, pas):
    """Débite un morceau sur la grille ABSOLUE de `pas` mètres.

    ⚠️ ABSOLUE, et c'est tout l'intérêt : la plaque et le talus ne sont pas
    coupés par les mêmes droites (l'un par les berges, l'autre par les hauts
    de talus), mais leurs sommets tombent sur les mêmes lignes. Une grille
    relative au morceau ferait deux échantillonnages décalés du même relief,
    et l'un ressortirait de l'autre à la cassure du haut.
    """
    morceaux = [anneau]
    for axe in (0, 1):
        vals = [p[axe] for p in anneau]
        for k in range(int(math.floor(min(vals) / pas)) + 1,
                       int(math.ceil(max(vals) / pas))):
            s = k * pas
            p0 = (s, 0.0) if axe == 0 else (0.0, s)
            nrm = (1.0, 0.0) if axe == 0 else (0.0, 1.0)
            suite = []
            for mo in morceaux:
                suite.extend(D4C.couper(mo, p0, nrm))
            morceaux = suite
    return [m for m in morceaux if len(m) >= 3]


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
        self.uv = []
        # 🪟 UV2 ne sert qu'aux MURS, et seulement depuis le 2026-08-18 : il
        # porte (genre de percement, tirage du bâtiment). Il n'est écrit dans
        # le JSON que si un mur l'a rempli — sans ça le terrain, les sols et
        # la voirie traîneraient chacun un tableau de zéros.
        self.uv2 = []
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

    def triangle(self, p, q, r, coul, ao=(1.0, 1.0, 1.0), axe_toit=None,
                 facade=None, genre=None):
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
        # ⚠ L'ordre de sortie est p, r, q (voir ci-dessus) : `facade` est
        # donnée dans l'ordre NATUREL p, q, r, d'où l'indice porté ici. Sans
        # lui, un mur sortirait avec ses coordonnées de façade permutées et
        # les travées partiraient de travers.
        for s, f, k in ((p, ao[0], 0), (r, ao[2], 2), (q, ao[1], 1)):
            self.v.append(s)
            self.n.append(nn)
            # RGB = la teinte déjà occluse ; ALPHA = l'occlusion seule.
            # Garder le facteur séparément coûte un float par sommet et permet
            # de repeindre un objet en calque thématique sans perdre ce qui le
            # POSE au sol — l'AO bakée est la fondation, pas un décor
            # (Direction artistique l.21). Aucun matériau du projet n'active la
            # transparence : ce canal est libre.
            self.c.append((coul[0] * f, coul[1] * f, coul[2] * f, f))
            # UV ne porte pas une texture : sur les seules faces de toiture,
            # il porte l'axe du bâtiment en XZ Godot. Le shader peut ainsi
            # aligner sa recette de panneaux sur le faîtage et reconnaître
            # qu'il travaille bien pan par pan. (0, 0) signifie « pas un toit ».
            # UV ne porte pas une texture. Deux usages, exclusifs :
            #   toit → l'axe du bâtiment en XZ Godot, un vecteur UNITAIRE ;
            #   mur  → (u, L) : mètres le long de la façade depuis son coin,
            #          et longueur totale de CETTE façade.
            # C'est la longueur qui sépare les deux dans le shader : aucune
            # composante d'un vecteur unitaire ne passe 1, et 07 refuse de
            # percer une façade de moins de FACADE_MIN (2 m).
            if facade is not None:
                self.uv.append(facade[k])
            else:
                self.uv.append((0.0, 0.0) if axe_toit is None else axe_toit)
            self.uv2.append((0.0, 0.0) if genre is None else genre)
        self.i.extend((base, base + 1, base + 2))

    def json(self, prec=2):
        self.fermer()
        d = {
            "v": [[round(c, prec) for c in s] for s in self.v],
            "n": [[round(c, 3) for c in s] for s in self.n],
            "c": [[round(c, 3) for c in s] for s in self.c],
            "uv": [[round(c, 4) for c in s] for s in self.uv],
            "i": self.i,
            "g": self.groupes,
        }
        # Un maillage sans un seul mur percé n'emporte pas la colonne : Godot
        # laisse alors UV2 à zéro, ce qui est exactement « pas une façade ».
        if any(g[0] for g in self.uv2):
            d["uv2"] = [[round(c, 3) for c in s] for s in self.uv2]
        return d

    def __len__(self):
        return len(self.i) // 3


# ===================================================================== lecture

def lire(con):
    verifier_colonnes(con, "ilots", COLS_ILOTS)
    verifier_colonnes(con, "routes", COLS_ROUTES)
    verifier_couche(con, "emprises", "04b_emprises_baties.py")
    verifier_couche(con, "parcelles", "04c_parcelles.py")
    verifier_couche(con, "batiments", "04d_emprises_batiments.py")

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

    # Les PARCELLES portent le niveau et le fond non bâti ; les BÂTIMENTS sont
    # désormais lus tels que 04d les a dessinés. Avant le 2026-08-17, 07
    # recalculait ici une seconde empreinte avec une seconde table de règles :
    # l'aperçu 2D et Godot montraient donc deux villes différentes.
    for d in ilots.values():
        d["parcelles"] = []
        d["batiments"] = []
    parcelles = {}
    for fid, fid_i, niv, org, geom in con.execute(
        "SELECT fid, fid_ilot, niveaux, origine, geom"
        " FROM parcelles ORDER BY fid"
    ):
        if fid_i not in ilots:
            continue
        p = {"fid": fid, "anneau": anneau_ouvert(geom),
             "niveaux": niv or 0.0, "origine": org}
        parcelles[fid] = p
        ilots[fid_i]["parcelles"].append(p)

    # 🌊 `etat_crue` et `hauteur_eau` viennent de `04e` et ne servent QU'AU
    # RENDU ici : c'est la seule chose que la 3D sait de la crue. Le nombre qui
    # compte pour le jeu (`alea`, les parts sinistrées) reste sur l'îlot.
    for fid_p, fid_i, geom, etat, h in con.execute(
        "SELECT fid_parcelle, fid_ilot, geom, etat_crue, hauteur_eau"
        " FROM batiments ORDER BY fid"
    ):
        if fid_i in ilots and fid_p in parcelles:
            ilots[fid_i]["batiments"].append(
                {"anneau": anneau_ouvert(geom), "parcelle": parcelles[fid_p],
                 "crue": etat or "intact", "eau": h or 0.0})

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
    def G_eau(x, y, alt):
        return (x - cx, alt, -(y - cy))

    chenal = Chenal([d["brut"] for d in ilots.values()
                     if d["sous_type"] == "riviere"])
    print("  chenal : %d arêtes de berge (%d arêtes internes à l'eau écartées)"
          % (len(chenal.berges), chenal.internes))

    def G(x, y, alt):
        return G_eau(x, y, alt + chenal.niveau_rive(x, y))

    # ------------------------------------------------- le talus, puis la plaque
    # LA VILLE RESTE PLATE. Le seul relief est la descente des champs vers
    # l'eau — construite AVANT la plaque, parce que c'est elle qui dit où la
    # maille de 16 m est trop grossière.
    relief = Relief(chenal, {f: d["anneau"] for f, d in ilots.items()
                             if d["sous_type"] == "champ"})
    n_zones, m_rive = relief.mesures()
    print("  talus : %d champs riverains, %.0f m de rive en pente sur %.0f m"
          " (%.2f m de creux)"
          % (n_zones, m_rive, TALUS_LARGEUR, -Relief.CREUX))

    terre = Maillage()
    coul_terre = PAL.vers_lineaire(PAL.MINERAL_CLAIR)
    x0 = minx - MARGE_TERRAIN
    y0 = miny - MARGE_TERRAIN
    x1 = maxx + MARGE_TERRAIN
    y1 = maxy + MARGE_TERRAIN
    morceaux, approx = chenal.plaque(x0, y0, x1, y1, PAS_TERRAIN, relief)
    for mo in morceaux:
        # La plaque plonge un quart plus bas que le talus : elle est invisible
        # sous le champ, et cette marge est ce qui dispense de faire coïncider
        # deux découpages différents du même relief.
        _cap_plat(terre, mo, Y_TERRAIN, coul_terre, G,
                  relief, 1.0 + TALUS_DESSOUS)
    # Mesuré ICI et pas à la fin : `terre` recevra ensuite le lit du chenal et
    # les murs de quai, qui descendent bien plus bas et masqueraient la seule
    # chose qu'on veut contrôler — jusqu'où la PLAQUE plonge sous le talus.
    bas_plaque = min(p[1] for p in terre.v)
    print("  sol : plan à 0,00 m sauf les berges — %d morceaux de plaque"
          " au pas de %.0f m" % (len(morceaux), PAS_TERRAIN))
    if approx:
        print("        dont %d mailles coupées par plusieurs arêtes de berge"
              % approx)

    # ------------------------------------------------------------ les îlots
    masses, sols, eau = Maillage(), Maillage(), Maillage()
    # 🔧 LE MAILLAGE DE LA RÉPARATION. Les mêmes bâtiments, intacts, groupés
    # par îlot — jamais affichés au chargement. Godot en montre le groupe d'un
    # îlot le jour où le joueur paie sa reconstruction ; la ruine, qui tient
    # dessous, disparaît d'elle-même. Voir RUINE_RETRAIT.
    repare = Maillage()
    # 🔧 LA VOIRIE RÉPARÉE, un groupe par tronçon : le tablier neuf d'un
    # franchissement emporté, la chaussée lavée d'une rue envasée. Cachée au
    # chargement, comme le bâti réparé — et posée 2 cm plus haut que ce qu'elle
    # recouvre, sans quoi deux surfaces coplanaires se battraient en duel.
    repare_voirie = Maillage()
    RELEVE = 0.02
    n_tablier_neuf = 0
    n_pont_ruine = 0
    rng = random.Random(GRAINE)
    arbres = []
    emprises = {}
    n_masse = n_sol = n_eau = 0
    n_parc = n_parc_batie = n_vol = 0
    n_pentu = n_plat_force = 0
    n_deborde = 0
    n_ruine = n_sali = 0
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
    n_parcelle_haie = n_haie = n_acces = n_pav_vert = 0
    longueur_haie = 0.0
    longueur_acces = 0.0
    ecart_perpendiculaire = 0.0
    # Un vert de jardin, légèrement assombri : un cœur d'îlot est en partie à
    # l'ombre des volumes qui l'entourent, et rien ici ne calcule d'ombre
    # portée sur le sol.
    coul_jardin = PAL.vers_lineaire(PAL.couleur_sol("jardins_familiaux", 0.10))
    coul_jardin = tuple(c * 0.92 for c in coul_jardin)
    # Plus sombre que la pelouse : à la distance de jeu, c'est le contraste
    # vertical qui doit dessiner la limite, pas une nouvelle teinte de palette.
    coul_haie = tuple(c * 0.68 for c in coul_jardin)
    # Le chemin privé reste clair sur le jardin, sans prendre le noir de la
    # chaussée : gravier ou dalles, pas une route miniature.
    coul_acces = tuple(c * 1.03 for c in PAL.vers_lineaire(PAL.MINERAL_CLAIR))
    # 🚶 Le pavé de la venelle : le minéral CLAIR, celui du sol nu, et non le
    # minéral de la chaussée. Vue d'en haut, la différence dit tout ce qu'il y
    # a à dire — on passe du noir de l'asphalte au gris du pavé, donc d'une rue
    # à un passage. Assombri d'un cheveu : une venelle de 3 m entre deux murs
    # ne voit pas beaucoup de ciel.
    coul_chemin = tuple(c * 0.94 for c in PAL.vers_lineaire(PAL.MINERAL_CLAIR))
    # 🅿️ La même peinture usée que la voirie, et c'est le point : une place de
    # parc et une ligne d'axe sont le MÊME objet du monde. Deux blancs
    # différents diraient qu'il s'agit de deux choses.
    coul_marq_sol = PAL.vers_lineaire(PAL.MARQUAGE)
    parkings = []
    n_tri_parc = 0
    n_chemin = 0
    aire_chemin = 0.0
    n_champ = n_bande = n_maille_talus = 0
    n_neuf = 0                 # bâtiments préparés pour la reconstruction

    for fid in sorted(ilots):
        d = ilots[fid]
        an = d["anneau"]
        st = d["sous_type"]
        haut = d["hauteur"] or 0.0
        # 🌊 LE LIMON, ET IL EST L'EMPRISE DE LA CRUE. Les ruines disent la
        # violence, le sol dit l'ÉTENDUE — vu d'en haut, c'est la seule chose
        # qui trace la limite de ce que l'eau a pris. Il vient de l'îlot et non
        # du bâtiment : `hauteur_eau_max` est le maximum de ses volumes, donc
        # un îlot dont un coin a bu se salit en entier, ce qui est le cas.
        brut_ilot = PAL.salir(PAL.couleur_ilot(st, haut, d["impermeabilise"]),
                              d["hauteur_eau_max"] or 0.0, 0.26, 0.86)
        # En espace LINÉAIRE : Godot interprète les couleurs de sommet
        # comme telles. En sRGB, toute la maquette ressort délavée.
        coul = PAL.vers_lineaire(brut_ilot)

        if len(an) < 3:
            continue

        if st == "riviere":
            n_eau += 1
            eau.marque(fid)
            # 🌊 Sur l'anneau BRUT, pas sur l'emprise : l'emprise est retirée
            # de la voirie, et le chenal doit tomber exactement sur la limite
            # de l'îlot d'eau, sinon un liseré de sol flotte au-dessus du vide.
            a, b = _chenal_eau(
                eau, terre, d["brut"], chenal, coul, coul_quai, G_eau, relief,
                lambda x, y: chenal.niveau_rive(x, y, False))
            quais_ok += a
            quais_tot += b
            continue

        # 🔲 L'EMPRISE AU SOL, ET ELLE NE SERT QU'À LA SÉLECTION.
        #
        # 🔄 RETOUR EN ARRIÈRE PARTIEL, signalé — 2026-08-18, le soir même.
        # Le matin, l'export de `contours` était parti d'ici : Godot en faisait
        # un ruban blanc posé au sol, et ce ruban n'entourait que l'emprise
        # alors qu'on sélectionne l'îlot ENTIER — les bâtiments dépassaient du
        # trait. Le trait est depuis tiré de la silhouette RENDUE, et ça, ça
        # reste.
        # Ce qui manquait : une silhouette rendue ne connaît que ce qui est
        # DESSINÉ, et un îlot bâti ne dessine pas son sol — sous une barre de
        # 1970 il n'y a que la plaque de terrain, qui n'appartient à personne.
        # La sélection sortait donc trouée : le trait collait aux bâtiments et
        # laissait dehors le gris qui les entoure.
        # Ce qui repart d'ici n'est donc PAS l'ancien ruban, c'est une DEUXIÈME
        # pièce du masque, réunie à la silhouette dans la vue à part. Le trait
        # suit l'union des deux : l'emprise au sol, et tout ce qui la dépasse
        # en hauteur.
        # ⚠️ Ce n'est pas de la géométrie affichable et ça ne doit jamais le
        # devenir : rien de tout ça n'entre dans le monde, seulement dans le
        # masque (`maquette.gd`, `_batir_contour`).
        # Chaque point porte SON altitude : sur un champ en pente, une emprise
        # plate décollerait du talus et le trait flotterait au-dessus du bord.
        emprises[str(fid)] = [
            [round(c, 2) for c in G(p[0], p[1], Y_SOL + relief.z(p[0], p[1]))]
            for p in an]

        if haut > 0.0:
            n_masse += 1
            masses.marque(fid)
            # 🌊 Le jardin et la cour prennent le limon comme le reste : c'est
            # la plus grande surface de SOL visible d'un îlot bâti, donc celle
            # qui dit jusqu'où l'eau est montée à l'intérieur du pâté.
            eau_ilot = d["hauteur_eau_max"] or 0.0
            # 🌊 La haie suit le jardin : une bordure verte VIF autour d'une
            # parcelle de vase annulait à elle seule tout le reste de la passe.
            coul_jardin_i = coul_jardin
            if eau_ilot > 0.10:
                coul_jardin_i = PAL.vers_lineaire(PAL.salir(
                    PAL.couleur_sol("jardins_familiaux", 0.10), eau_ilot,
                    0.26, 0.88))
            coul_haie_i = tuple(c * 0.68 for c in coul_jardin_i)
            # ⚠️ TOUTES les parcelles d'un îlot tombent dans LE MÊME groupe.
            # C'est ce qui permet d'avoir mille bâtiments sans passer de 237 à
            # 1 200 nœuds cliquables : la géométrie descend à la parcelle, la
            # SÉLECTION reste à l'îlot — et la décision aussi. La parcelle est
            # l'entité persistante des données (35), pas celle du clic.
            repare.marque(fid)
            pente = BATI.get(st, BATI_DEFAUT)[3]
            toit_ilot = 0.0
            toit_neuf_ilot = 0.0
            volumes = []
            batiments_par_parcelle = {}
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
                for b in d["batiments"]:
                    p = b["parcelle"]
                    emp = b["anneau"]
                    faite = _direction_faitage(p["anneau"], idx)
                    # 🌊 LA HAUTEUR ET LE FAÎTAGE RESTENT CEUX DU BÂTIMENT
                    # INTACT, même pour une ruine : ce sont eux que le maillage
                    # « réparé » emploiera. Ce qu'une ruine perd — toit, étages,
                    # percements — est perdu à l'ÉMISSION, pas ici.
                    if b["crue"] == "ruine":
                        n_ruine += 1
                    else:
                        n_sali += b["crue"] != "intact"
                    volumes.append((emp, p["niveaux"], faite, p,
                                    b["crue"], b["eau"]))
                    batiments_par_parcelle.setdefault(p["fid"], []).append(emp)
                n_parc += len(d["parcelles"]) - len(chemins_ilot)
                n_parc_batie += len(batiments_par_parcelle)
                n_vol += len(volumes)
                n_chemin += len(chemins_ilot)
            # 🪟 L'index des murs de TOUT l'îlot, bâti une fois : c'est lui
            # qui dira, mur par mur, lesquels sont mitoyens — donc aveugles.
            idx_murs = _index_murs([v[0] for v in volumes])
            for k_vol, (emp, niv, faite, parcelle, crue, eau_m) in \
                    enumerate(volumes):
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
                # 🌊 UNE RUINE N'A PLUS DE TOIT, DONC PLUS DE PANNEAUX. C'est
                # la seule chose que « reconstruire » RAPPORTE aujourd'hui :
                # `toit_m2` est ce qu'on peut équiper maintenant, `toit_m2_neuf`
                # ce qu'on pourrait équiper une fois l'îlot relevé.
                aire_toit = abs(D4C.aire_signee(emp)) * math.hypot(1.0, pente_v)
                toit_neuf_ilot += aire_toit
                if crue != "ruine":
                    toit_ilot += aire_toit
                # ⚠️ Les chemins sont ÉCARTÉS de ce contrôle : un bâtiment qui
                # mord sur la venelle est exactement le défaut qu'on cherche à
                # voir, et le compter « dans une parcelle » le masquerait.
                deb = _debordement(emp, parcelle)
                if deb > 0.5:
                    n_deborde += 1
                    deb_max = max(deb_max, deb)
                # 🎨 UN BÂTIMENT = DEUX MATÉRIAUX, TIRÉS DE SA POSITION (35).
                # C'est ici que la ville cesse d'être coloriée par typologie :
                # deux maisons mitoyennes du même tissu n'ont plus la même
                # façade, et le toit ne suit plus le mur. La graine vient de
                # l'empreinte, donc bouger une ligne de table ne rebat pas
                # toute la ville.
                gr = _graine_lieu(emp)
                mur_neuf = PAL.couleur_mur(st, gr)
                toit_neuf = PAL.couleur_toit(st, gr)
                mur, toit = mur_neuf, toit_neuf
                # 🌊 CE QUE LA CRUE A LAISSÉ. Les teintes se MÉLANGENT à celles
                # du bâtiment, elles ne les remplacent pas : la couleur dit
                # l'époque depuis le 2026-08-18, et un faubourg gris uni
                # effacerait le tissu. Une ruine, elle, a bien perdu son enduit.
                if crue == "ruine":
                    # 🔄 0,72 → 0,88 le 2026-08-21 : une ruine A perdu son
                    # enduit, elle n'a pas à garder la couleur de son époque.
                    # C'est la seule exception au rendu par matériau du
                    # 2026-08-18, et elle vaut pour 68 bâtiments sur 757.
                    mur = PAL.melanger(mur, PAL.RUINE_MUR, 0.88)
                elif crue != "intact":
                    mur = PAL.salir(mur, eau_m)
                    toit = PAL.salir(toit, eau_m, 0.05)  # le toit n'a pas bu
                c_mur = PAL.vers_lineaire(mur)
                c_toit = PAL.vers_lineaire(toit)
                # 🪟 Le percement des murs, mur par mur, et le tirage qui
                # donne à CE bâtiment son entraxe de travées. Le tirage vient
                # de la même graine de lieu que ses deux teintes : bouger une
                # ligne de table ne rebat pas les fenêtres de la ville.
                genres = _facades(k_vol, emp, parcelle["anneau"], idx,
                                  idx_murs, st)
                alea = random.Random(gr ^ 0xFE4E).random()
                if crue == "ruine":
                    a, b, c, e = _ruine(masses, emp, c_mur,
                                        PAL.vers_lineaire(PAL.GRAVATS), G,
                                        random.Random(gr ^ 0x9C21))
                    # 🔧 ET LE MÊME BÂTIMENT NEUF, dans un maillage à part que
                    # Godot garde CACHÉ jusqu'à ce que la décision tombe. C'est
                    # tout ce que « reconstruire » demande à la 3D : la maquette
                    # bâtit sa géométrie une fois, elle ne sait pas en fabriquer
                    # en cours de partie.
                    n_neuf += 1
                    _masse(repare, emp, d, PAL.vers_lineaire(mur_neuf), G, niv,
                           pente_v, faite, PAL.vers_lineaire(toit_neuf),
                           genres, alea)
                else:
                    a, b, c, e = _masse(masses, emp, d, c_mur, G, niv,
                                        pente_v, faite, c_toit, genres, alea)
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
            limites_haie = set()
            for p in d["parcelles"]:
                if p.get("origine") == "chemin":
                    continue
                j = p["anneau"]
                emps = batiments_par_parcelle.get(p["fid"], [])
                if st == "pavillonnaire" and emps:
                    haie_posee = False
                    rues = _sur_rue(j, idx)
                    acces = _acces_pavillonnaire(j, emps, rues)
                    if acces is not None:
                        _ruban(masses, [acces["maison"], acces["route"]],
                               ACCES_LARGEUR, coul_acces, G,
                               y=Y_SOL + 0.015, bouts=False)
                        n_acces += 1
                        longueur_acces += acces["longueur"]
                        ecart_perpendiculaire = max(
                            ecart_perpendiculaire, acces["ecart_angle"])
                    for k, sur_rue in enumerate(rues):
                        a, b = j[k], j[(k + 1) % len(j)]
                        morceaux = [(a, b)]
                        if acces is not None and k == acces["arete"]:
                            morceaux = _ouvrir_segment(
                                a, b, acces["route"], ACCES_OUVERTURE)
                        cle = tuple(sorted((_cle(a), _cle(b))))
                        if not sur_rue and cle in limites_haie:
                            # La voisine l'a déjà dessinée : cette parcelle
                            # est bien bordée elle aussi, sans second prisme.
                            haie_posee = True
                            continue
                        dessine = 0.0
                        for debut, fin in morceaux:
                            longueur = _haie(
                                masses, debut, fin, coul_haie_i, G)
                            if longueur > 0.0:
                                n_haie += 1
                                longueur_haie += longueur
                                dessine += longueur
                        if dessine > 0.0:
                            limites_haie.add(cle)
                            haie_posee = True
                    if haie_posee:
                        n_parcelle_haie += 1
                aire_j = max(0.0, abs(D4C.aire_signee(j)) - sum(
                    abs(D4C.aire_signee(emp)) for emp in emps))
                # Le pavillonnaire BÂTI est toujours vert. Avant, `part_verte`
                # valait 0,92 : le tirage laissait donc 8 % des maisons sur une
                # parcelle grise, sans que la simulation ne l'explique.
                vert_force = st == "pavillonnaire" and bool(emps)
                if vert_force:
                    _sol(masses, j, coul_jardin_i, G)
                    n_pav_vert += 1
                if aire_j < AIRE_JARDIN_MIN or len(j) < 3:
                    continue
                n_jardin += 1
                aire_jardin += aire_j
                if not vert_force and \
                        random.Random(_graine_lieu(j)).random() > part_verte:
                    continue                  # une cour, pas un jardin
                n_vert += 1
                aire_verte += aire_j
                # Le sol vert couvre la parcelle entière, mais les volumes
                # opaques posés dessus cachent exactement leur empreinte : ce
                # qui reste visible est donc la différence parcelle − bâti,
                # sans introduire un second moteur de géométrie dans 07.
                if not vert_force:
                    _sol(masses, j, coul_jardin_i, G)
                if eau_ilot >= CRUE_ARBRE_NOYE_M:
                    continue                  # jardin noyé : plus un arbre
                arbres_jardin = _semer_jardin(j, aire_j, emps)
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
            # Ce que l'îlot porterait une fois relevé. Égal à `toit_m2` partout
            # où la crue n'a rien pris : c'est l'écart entre les deux qui donne
            # à « reconstruire » son seul rendement mesurable.
            d["toit_m2_neuf"] = round(toit_neuf_ilot, 1)
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
            # 🌾 Le champ n'est plus un aplat : sa teinte est tirée de sa
            # position (blé, prairie, chaume, labour) et il est coupé en
            # bandes de fauche. C'est la plus grande surface unie de l'image,
            # donc celle qui trahissait le plus la maquette.
            if st == "champ":
                # 🌊 Le champ riverain est l'EXPANSION DE CRUE : il boit avant
                # tout le monde, donc il se salit comme le reste. Sans cette
                # ligne, l'emprise de l'eau s'arrêtait pile au dernier îlot
                # bâti et la crue avait l'air de respecter le cadastre.
                brut_champ = PAL.salir(
                    PAL.couleur_champ(_graine_lieu(an), d["impermeabilise"]),
                    d["hauteur_eau_max"] or 0.0, 0.24, 0.72)
                coul = PAL.vers_lineaire(brut_champ)
                # 🌊 La berge n'est ni fauchée ni cultivée : on ne descend pas
                # une moissonneuse à 22 %. Sa teinte part de celle du champ et
                # va aux deux tiers vers le vert du parc — donc deux champs
                # voisins ont encore deux berges différentes, et la cassure du
                # haut de talus se lit même à contre-jour, où la pente seule ne
                # se voit pas.
                coul_berge = PAL.vers_lineaire(
                    PAL.melanger(brut_champ, PAL.SOLS["parc"], 0.65))
                for mo, tint in _bandes_de_fauche(an, coul):
                    if len(mo) < 3:
                        continue
                    n_bande += 1
                    for piece, en_pente in relief.trier(fid, mo):
                        if not en_pente:
                            _sol(sols, piece, tint, G, relief)
                            continue
                        for cel in _grille(piece, TALUS_PAS):
                            _sol(sols, cel, coul_berge, G, relief)
                            n_maille_talus += 1
                n_champ += 1
            else:
                _sol(sols, an, coul, G)
            # 🅿️ LA PLACE-PARKING SE DESSINE. Le test ne nomme aucun îlot et
            # aucun sous-type : un îlot de SOL qui porte des places, c'est la
            # place minérale et rien d'autre — la barre et l'équipement en
            # portent aussi, mais ils ont une hauteur et sont partis plus haut.
            # Le jour où le level design pose une deuxième place, elle se
            # dessinera sans qu'on revienne ici.
            interdit = None
            if (d["stationnement"] or 0) > 0:
                n_pl, traits, trame_pl = _places_de_parc(an)
                # Les places entrent dans le maillage des SOLS, donc dans le
                # groupe de leur îlot : cliquer une place ouvre la fiche de la
                # place. Elles ne sont pas de la voirie — le jeu ne les
                # sélectionne pas une par une.
                for p_, q_ in traits:
                    n_tri_parc += _ruban(sols, [p_, q_], LARGEUR_LIGNE,
                                         coul_marq_sol, G, y=Y_MARQUAGE_SOL,
                                         bouts=False)
                # 🌳 ET LES ARBRES TIENNENT LE BORD. Sans ça, un arbre sur deux
                # de la place pousse au milieu d'une place peinte : le semis
                # tire au hasard dans l'anneau et ne sait rien de la trame.
                # C'est le même mécanisme que le rejet hors de l'anneau, avec
                # un anneau de plus — pas une position corrigée à la main.
                if trame_pl is not None:
                    interdit = list(trame_pl) + [trame_pl[0]]
            plantes = [] if (d["hauteur_eau_max"] or 0.0) >= CRUE_ARBRE_NOYE_M                 else _semer(an, d, rng, relief, interdit)
            arbres.extend(plantes)
            if interdit is not None:
                # Le compte est MESURÉ sur les arbres rendus, pas déduit du
                # rejet : c'est ce qui prouve que le rejet a bien tourné.
                parkings.append((fid, n_pl, len(traits), d["stationnement"],
                                 len(plantes),
                                 sum(1 for t in plantes
                                     if dedans(interdit, (t[0], t[1])))))

    print("  masses %d · sols %d · eau %d" % (n_masse, n_sol, n_eau))
    print("        emprises de sélection : %d îlots, %d sommets"
          " (jamais affichées, c'est le masque du trait)"
          % (len(emprises), sum(len(v) for v in emprises.values())))
    if n_parc:
        print("  couche `batiments` : %d volumes sur %d parcelles bâties"
              " (%d parcelles non bâties)"
              % (n_vol, n_parc_batie, n_parc - n_parc_batie))
        if n_chemin:
            print("  chemins %d → %.0f m² de venelle pavée, dans le groupe de"
                  " leur îlot" % (n_chemin, aire_chemin))
        # 🔗 Ce que l'énergie viendra lire. À imprimer maintenant, parce que
        # c'est le seul moment où on peut encore dire « ce chiffre est faux »
        # avant qu'une décision de jeu s'appuie dessus.
        print("  toits : %.1f ha de surface réelle (pente comprise)"
              % (toit_total / 1e4))
        print("  haies : %d parcelles bâties, %d tronçons, %.2f km en"
              " pavillonnaire" %
              (n_parcelle_haie, n_haie, longueur_haie / 1000.0))
        print("  accès pavillonnaires : %d chemins, %.1f m en tout, écart"
              " maximal à la perpendiculaire %.4f°"
              % (n_acces, longueur_acces, ecart_perpendiculaire))
        print("        %d parcelles pavillonnaires bâties vertes sur %d"
              % (n_pav_vert, n_parcelle_haie))
        print("        %d à deux pentes · %d plats par dessin (le tissu les"
              " veut plats) · %d plats faute d'empreinte convexe"
              % (n_pentu, n_vol - n_pentu - n_plat_force, n_plat_force))
        if n_deborde:
            print("        ⚠️  %d bâtiments sur %d débordent de leur parcelle,"
                  " jusqu'à %.1f m" % (n_deborde, n_vol, deb_max))
            print("           pic de mitre sur angle rentrant — borné par le recul"
                  " du tissu, à reprendre")
        plats = [f for f, x in ilots.items() if x.get("toit_plat")]
        print("        dont %d îlots à toit plat — barre et friches"
              % len(plats))
        print("  empreintes : lues directement dans 04d, aucune forme recalculée"
              " par l'export Godot")
        # 🌊 CE QUE LA CRUE DOIT AVOIR CHANGÉ À L'ÉCRAN. Deux nombres, et ils
        # se contrôlent à l'œil : les ruines sont des murs sans toit, le reste
        # du faubourg est sali. À zéro ruine, `04e` n'est pas passé.
        coupes = [r["fid"] for r in routes
                  if (r.get("etat_crue") or "") == "coupe"]
        print("  crue : %d ruines à ciel ouvert, %d bâtiments salis,"
              " %d franchissement(s) emporté(s) %s"
              % (n_ruine, n_sali, len(coupes), sorted(coupes)))
        print("        crêtes tirées dans %s × 2,70 m — si elles sortent"
              " toutes pareilles, la ruine se lit comme un toit plat"
              % (RUINE_PANS,))
        print("  réparation : %d bâtiments neufs en attente sur %d îlots"
              % (n_neuf, len(repare.groupes)))
        if not n_ruine:
            print("        ⚠️ aucune ruine — relancer `04e_crue.py`, ou la table"
                  " de `04e` ne ruine plus personne")
        # 🎨 LE RENDU RÉALISTE (2026-08-18). Ces quatre lignes sont le compte
        # rendu de la passe : elles disent ce que l'auteur doit RETROUVER à
        # l'écran, et ce qui manquerait si un des trois volets était muet.
        print("  matériaux : toit et mur séparés, tirés de la position du"
              " bâtiment (35)")
        print("        îlots couverts en tuile %d · ardoise %d · étanchéité %d"
              " · bac acier %d"
              % tuple(sum(1 for f, x in ilots.items()
                          if PAL.TOIT_TISSU.get(x["sous_type"]) == fam
                          and (x["hauteur"] or 0.0) > 0.0)
                      for fam in ("tuile", "ardoise", "etancheite",
                                  "bac_acier")))
        print("        débord de toit %.2f m sur les %d volumes à deux pentes,"
              " acrotère de %.2f m sur les toits plats"
              % (DEBORD_TOIT, n_pentu, ACROTERE))
        print("        %d souches de cheminée (%.0f %% des toits pentus)"
              % (cheminees[0], 100.0 * cheminees[0] / max(n_pentu, 1)))
        # 🪟 LES FAÇADES. Ce tableau est le seul endroit où le percement se
        # vérifie sans lancer Godot : il dit ce que l'export a DÉCIDÉ, pas ce
        # que le shader dessine. Le dessin, lui, se juge à l'écran (§3 bis).
        # Ce qu'on y lit : « aveugle » doit rester la part des pignons du
        # tissu mitoyen — s'il monte, c'est `_mitoyen` qui mord trop large ;
        # « porte » doit valoir à peu près un bâtiment sur un.
        noms = ["aveugle", "fenêtres", "+ porte", "vitrine", "bandeau"]
        print("  façades : %d murs percés sur %d (%.2f km de façade)"
              % (sum(facades[1:]), sum(facades),
                 sum(facades_m[1:]) / 1000.0))
        for g, nom in enumerate(noms):
            if facades[g]:
                print("        %-9s %5d murs  %7.0f m  %4.0f %%"
                      % (nom, facades[g], facades_m[g],
                         100.0 * facades[g] / max(sum(facades), 1)))
        if facades[FACADE_PORTE] > n_vol:
            raise SystemExit(
                "%d portes pour %d bâtiments : `_facades` en pose plus d'une "
                "par volume." % (facades[FACADE_PORTE], n_vol))
        # 🌳 Les cœurs d'îlot. « pas tous » est le chiffre qui compte : à 100 %
        # de vert, le contraste entre une cour pavée et un jardin disparaît.
        print("  cœurs d'îlot : %d espaces libres (%.1f ha), dont %d plantés"
              " (%.0f %%, %.1f ha) et %d arbres"
              % (n_jardin, aire_jardin / 1e4, n_vert,
                 100.0 * n_vert / max(n_jardin, 1), aire_verte / 1e4,
                 n_arbre_jardin))
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
    coul_tr = PAL.vers_lineaire(PAL.TROTTOIR)
    # La bordure est le trottoir assombri, pas une couleur de plus : c'est une
    # tranche de la même dalle, et l'œil ne doit y lire qu'une ombre d'arête.
    coul_bord = PAL.vers_lineaire(PAL.melanger(PAL.TROTTOIR, "#000000", 0.22))
    coul_marq = PAL.vers_lineaire(PAL.MARQUAGE)
    coudes, (n_coude, n_marque, n_rond) = _coudes(routes)
    axes_voirie, chaussees = _index_chaussees(routes, coudes)
    # 🌊 LE PONT EMPORTÉ (04e · 23b). On ampute son axe UNE FOIS, ici, et tout
    # ce qui le lit ensuite — chaussée, tablier, parapet, pile, marquage — ne
    # voit qu'un axe qui s'arrête au bord de l'eau. Aucune de ces cinq recettes
    # n'a été touchée : c'est ce qui rend la chose réversible en une ligne de
    # `04e` et ce qui évite d'ouvrir `_bord_eau`.
    # ⚠️ Un axe amputé rend une LISTE de morceaux, jamais un axe.
    morceaux_voirie = {}
    for d in routes:
        coupe = (d.get("etat_crue") or "") == "coupe"
        morceaux_voirie[d["fid"]] = [
            _axe_ampute(a, chenal) if coupe else [a]
            for a in axes_voirie.get(d["fid"], ())]
    # Les arbres semés lisent les îlots, qui devraient déjà s'arrêter au bord
    # des rues. On les contrôle quand même ici : c'est le filet qui montrera
    # immédiatement une future régression du découpage de la carte.
    arbres_ecartes_chaussee = sum(
        1 for a in arbres
        if _dans_chaussee((a[0], a[1]), chaussees,
                          MARGE_TRONC_CHAUSSEE))
    arbres = [a for a in arbres
              if not _dans_chaussee((a[0], a[1]), chaussees,
                                     MARGE_TRONC_CHAUSSEE)]
    trot, st_tr = _trottoirs(ilots, routes, coudes)
    # 🎨 Les nœuds du marquage : combien de branches à chaque bout de
    # tronçon. C'est plus riche que le `noeuds` d'à côté (qui ne sert qu'à
    # compter les carrefours) — il faut aussi savoir LEUR LARGEUR.
    nd_marq = _noeuds_voirie(routes)
    st_marq = {"passages": 0, "bandes": 0, "traits": 0, "pleins": 0,
               "rives": 0, "tri": 0, "sur_eau": 0, "sans_trottoir": 0}
    # 🌊 Le bord de l'eau. `coul_quai` est LA MÊME variable que celle des murs
    # de berge du chenal, et ce n'est pas une économie : le mur qui porte un
    # quai et celui qui tient la rive sont le même ouvrage, souvent bout à bout.
    # Deux teintes proches se verraient comme un défaut de raccord.
    coul_chap = PAL.vers_lineaire(PAL.TROTTOIR)
    st_bord = {"pont": 0, "pont_m": 0.0, "pile": 0, "quai_m": 0.0,
               "parapet_m": 0.0, "parapet_coupe_m": 0.0, "sur_quai": 0.0,
               "bouts": 0, "tri": 0}
    plateformes = []
    ponts_vus = []
    murs_eau = []
    noeuds = set()
    for d in routes:
        for part in d["parts"]:
            for p in (part[0], part[-1]):
                noeuds.add((round(p[0] / 0.25), round(p[1] / 0.25)))
    # 🌊 LE QUAI SE PLANIFIE AVANT D'Être ÉMIS, et il lui faut deux choses
    # qu'aucun tronçon ne connaît tout seul : l'asphalte de TOUTE la ville
    # (sinon le débouché d'une rue perpendiculaire passe pour de l'eau) et les
    # tabliers (sinon un muret pousse sous un pont). Il s'émet ensuite dans la
    # boucle, tronçon par tronçon, pour tomber dans le bon groupe cliquable.
    tabliers = []
    for d in routes:
        if not (d["largeur_m"] or 0.0) > 0.0:
            continue
        ch = min(D4.EMPRISE_CIRCULATION.get(d["hierarchie"], 8.5),
                 d["largeur_m"])
        for ip in range(len(d["parts"])):
            for axe_ in morceaux_voirie[d["fid"]][ip]:
                tabliers.extend(_tabliers(axe_, ch, chenal, relief))
    plan_quai, st_quai, plat_quai, murs_quai = _quais(
        chenal, relief, GrilleChaussee(chaussees), tabliers)
    plateformes.extend(plat_quai)
    murs_eau.extend(murs_quai)
    # Le pont a besoin du quai pour savoir ou finir son parapet ; le quai a
    # besoin des tabliers pour ne pas pousser dessous. L'ordre est donc :
    # tabliers (geometrie seule) -> quais -> emission des ponts.
    boites_quai = _boites(plat_quai)

    n_seg = 0
    n_tri_tr = 0
    # 🔲 LE COULOIR DE CHAQUE TRONÇON, pour la silhouette de sélection.
    #
    # Un tronçon n'est PAS une surface : c'est la chaussée, plus les mètres
    # libres, plus un bout de trottoir par îlot riverain — trois choses
    # disjointes, séparées de 2,6 m sur le tronçon 120. Godot entourait donc
    # chacune, et une rue choisie ressortait en bandes parallèles.
    #
    # Ce qu'on exporte ici est ce qui les réunit : l'axe (le même que la
    # chaussée, coudes arrondis compris) et la largeur FAÇADE À FAÇADE. Godot
    # en fait un ruban plat, invisible, qui ne sert qu'à être détouré.
    couloirs = {}
    par_fid = {d["fid"]: d for d in routes}
    n_align_eau = 0
    n_align_chaussee = 0
    n_align_chaussee_t0 = 0
    alignements = {}
    for d in routes:
        larg = d["largeur_m"] or 0.0
        if larg <= 0.0:
            continue                            # 4 tronçons `rive` à 0 m
        ch = min(D4.EMPRISE_CIRCULATION.get(d["hierarchie"], 8.5), larg)
        voirie.marque(d["fid"])
        axes = []
        # 🌊 Un pont FRAGILE (04e) garde toute sa géométrie et prend le limon :
        # il passe encore, et il se voit qu'il a bu. Le pont EMPORTÉ, lui, a
        # déjà perdu ses morceaux au-dessus de l'eau.
        etat_crue = d.get("etat_crue") or "intact"
        if etat_crue == "coupe":
            repare_voirie.marque(d["fid"])
            for axe_entier in axes_voirie.get(d["fid"], ()):
                manque = _axe_manque(axe_entier, chenal)
                if manque:
                    n_pont_ruine += _pont_ruine(
                        voirie, manque, larg, ch,
                        PAL.vers_lineaire(PAL.GRAVATS), coul_ch, coul_quai, G)
                    n_tablier_neuf += _pont_neuf(
                        repare_voirie, manque, larg, ch,
                        PAL.vers_lineaire(PAL.melanger(PAL.TROTTOIR,
                                                       "#FFFFFF", 0.10)),
                        coul_ch, coul_quai, G)
        # 🌊 LE LIMON SUR LA CHAUSSÉE, ET C'EST LUI QUI DESSINE L'EMPRISE. Vue
        # de dessus, la ville est un tapis de toits : le sol des îlots ne se
        # voit presque pas, le RÉSEAU si. Sans cette ligne, la crue ne se
        # lisait que de trois quarts, sur les toits manquants.
        # ⚠️ Une seule hauteur par tronçon (04e) : la limite de l'emprise
        # tombe donc sur un carrefour, jamais au milieu d'une rue.
        eau_rue = d.get("hauteur_eau") or 0.0
        # 🔧 UNE RUE ENVASÉE SE DÉBLAIE, UN PONT EMPORTÉ SE REBÂTIT : deux
        # décisions, jamais les deux sur le même tronçon. `04e` ne met de prix
        # de déblaiement que sur les rues qui ne sont pas coupées.
        lavage = (d.get("hauteur_eau") or 0.0) > 0.10 and etat_crue != "coupe"
        if lavage:
            repare_voirie.marque(d["fid"])
        if etat_crue == "fragile":
            eau_rue = max(eau_rue, 2.0)     # le tablier a bu, quoi qu'il arrive
        # 🔄 Plafond monté de 0,62 à 0,72 le 2026-08-21 : sous 3,80 m d'eau une
        # chaussée n'est plus « un peu sale ». Pas plus haut, et c'est mesuré à
        # l'écran : à 0,84 la rue prenait exactement la teinte du sol des îlots,
        # le faubourg devenait un aplat et on ne lisait plus le réseau — or le
        # réseau est ce qui montre que la ville continue SOUS le limon.
        coul_ch_d = (PAL.vers_lineaire(PAL.salir(PAL.MINERAL, eau_rue, 0.22, 0.72))
                     if eau_rue > 0.10 else coul_ch)
        coul_tr_d = (PAL.vers_lineaire(PAL.salir(PAL.TROTTOIR, eau_rue, 0.22, 0.80))
                     if eau_rue > 0.10 else coul_tr)
        # 🎨 ET LA PEINTURE SE SALIT AVEC. Un passage piéton blanc pur au milieu
        # d'une rue de vase disait « rue en service » plus fort que tout le
        # reste ne disait « rue emportée ». La peinture RESTE — elle ne se
        # décolle pas — mais elle est sous 4 m de limon comme le reste.
        coul_marq_d = (PAL.vers_lineaire(PAL.salir(PAL.MARQUAGE, eau_rue, 0.22, 0.78))
                       if eau_rue > 0.10 else coul_marq)
        for ip, part in enumerate(d["parts"]):
            axe = axes_voirie[d["fid"]][ip]
            for axe_ in morceaux_voirie[d["fid"]][ip]:
                _ruban(voirie, axe_, ch, coul_ch_d, G)
                n_seg += len(axe_) - 1
                # 🔧 LA MÊME RUE, LAVÉE, dans le maillage caché. Elle ne coûte
                # que sur les 36 tronçons envasés — ailleurs `lavage` est faux
                # et rien n'est émis.
                if lavage:
                    _ruban(repare_voirie, axe_, ch, coul_ch, G,
                           y=Y_CHAUSSEE + RELEVE)
                    _marquage(repare_voirie, d, axe_, ip, ch, nd_marq,
                              chenal, coul_marq, G, dy=RELEVE)
                # 🎨 Le marquage se pose SUR la chaussée qu'on vient d'émettre,
                # et dans le même groupe : cliquer une ligne blanche ouvre la
                # fiche de la rue, comme cliquer son trottoir.
                # ⚠️ Sur un pont emporté il tombe de lui-même : le marquage se
                # cale sur l'axe REÇU, et cet axe s'arrête au bord de l'eau.
                for k_, v_ in _marquage(voirie, d, axe_, ip, ch, nd_marq,
                                        chenal, coul_marq_d, G).items():
                    st_marq[k_] += v_
                # 🌊 Le mur de quai et le pont, dans le GROUPE DU TRONÇON :
                # cliquer un parapet ou un tablier ouvre la fiche de la rue,
                # comme cliquer son trottoir. Un pont n'est pas un objet du jeu,
                # c'est un état de la route — et c'est déjà ce que dit le
                # creusement du chenal.
                k_, pl_, po_, mu_ = _bord_eau(voirie, axe_, ch, chenal, relief,
                                              coul_quai, coul_chap, G,
                                              boites_quai)
                for nom, v_ in k_.items():
                    st_bord[nom] += v_
                plateformes.extend(pl_)
                ponts_vus.extend(po_)
                murs_eau.extend(mu_)
            # ⚠️ Le COULOIR de sélection reste celui de l'axe ENTIER : on doit
            # pouvoir cliquer un pont détruit pour lire sa fiche.
            plat = []
            for pt in axe:
                g = G(pt[0], pt[1], 0.0)
                plat.append(round(g[0], 2))
                plat.append(round(g[2], 2))
            axes.append(plat)
        # 🌊 Le quai de CE tronçon, dans SON groupe : le parapet se clique et
        # se repeint comme son trottoir. La ligne, elle, a été taillée d'un
        # seul tenant le long de la berge — le découpage ne se voit pas.
        st_bord["tri"] += _emettre_quai(voirie, plan_quai.get(d["fid"], ()),
                                        coul_quai, coul_chap, G)
        couloirs[str(d["fid"])] = [round(larg + MARGE_COULOIR, 2), axes]
        # 🚶 Le trottoir de ce tronçon a été fabriqué par les ÎLOTS qui le
        # bordent, pas par lui — mais il est rangé sous SON fid, dans son
        # groupe : cliquer un trottoir ouvre la fiche de la rue.
        for f in trot.get(d["fid"], ()):
            if f[0] == "plat":
                n_tri_tr += _dessus_trottoir(voirie, f[1], coul_tr_d, G)
                if lavage:
                    _dessus_trottoir(repare_voirie, f[1], coul_tr, G, RELEVE)
            else:
                n_tri_tr += _bordure(voirie, f[1], f[2], f[3], coul_bord, G)
                if lavage:
                    _bordure(repare_voirie, f[1], f[2], f[3], coul_bord, G,
                             RELEVE)
        emplacements = [] if (d["hauteur_eau"] or 0.0) >= CRUE_ARBRE_NOYE_M             else _alignement(d, rng)
        # 🌊 Un franchissement reste une route pour la voirie, mais sa bande
        # plantable traverse le chenal. Avant ce filtre, le décalage latéral des
        # arbres de pont posait leurs troncs dans l'eau. On retire aussi les
        # emplacements futurs : augmenter la canopée ne doit jamais faire
        # apparaître un arbre dans l'Ilse.
        align_eau = [a for a in emplacements
                     if chenal.dans_eau((a[0], a[1]))]
        n_align_eau += len(align_eau)
        emplacements = [a for a in emplacements
                        if not chenal.dans_eau((a[0], a[1]))]
        # Un arbre est placé dans la bande libre de SON tronçon. Au carrefour,
        # cette bande peut pourtant être coupée par la chaussée d'UNE AUTRE
        # rue ; dans un coude, l'axe arrondi peut aussi la rattraper. Le filtre
        # porte donc sur toutes les chaussées affichées, et sur tous les
        # emplacements futurs : faire pousser la canopée ne doit pas révéler
        # plus tard un arbre au milieu de l'asphalte.
        align_chaussee = [a for a in emplacements
                          if _dans_chaussee((a[0], a[1]), chaussees,
                                           MARGE_TRONC_CHAUSSEE)]
        n_align_chaussee += len(align_chaussee)
        n_align_chaussee_t0 += sum(
            1 for a in align_chaussee
            if a[5] <= (d["canopee"] or 0.0))
        emplacements = [a for a in emplacements
                        if not _dans_chaussee((a[0], a[1]), chaussees,
                                             MARGE_TRONC_CHAUSSEE)]
        # Le pied suit le talus, comme celui des arbres semés. Un alignement
        # passe au ras d'un champ riverain : le décalage latéral suffit à
        # poser un tronc dans la pente, et il y flotterait.
        for a in emplacements:
            a[2] = relief.z(a[0], a[1])
        if emplacements:
            alignements[str(d["fid"])] = emplacements
    n_align = sum(len(v) for v in alignements.values())
    plantes_t0 = sum(1 for f, v in alignements.items()
                     for a in v
                     if a[5] <= (routes_par_fid[int(f)]["canopee"] or 0.0))
    # 🔧 CE QUE LA RÉPARATION TIENT PRÊT CÔTÉ VOIRIE. À zéro tablier neuf avec
    # un pont coupé, la décision « rebâtir » existerait sans rien à montrer.
    print("  ponts emportés : %d moignons de tablier visibles"
          " · rives gauche %.0f m / droite +%.0f m"
          % (n_pont_ruine, RIVE_GAUCHE_Y, RIVE_DROITE_Y))
    print("  réparation : %d tronçons lavés, %d tablier(s) neuf(s) prêt(s)"
          % (sum(1 for g in repare_voirie.groupes
                 if (par_fid.get(g[0], {}).get("etat_crue") or "") != "coupe"),
             sum(1 for g in repare_voirie.groupes
                 if (par_fid.get(g[0], {}).get("etat_crue") or "") == "coupe")))
    print("  voirie : %d segments de chaussée, %d triangles"
          % (n_seg, len(voirie)))
    print("        couloirs de sélection : %d tronçons, %.1f m de large en"
          " moyenne (largeur_m + %.1f)"
          % (len(couloirs),
             sum(v[0] for v in couloirs.values()) / max(len(couloirs), 1),
             MARGE_COULOIR))
    print("        courbes : %d coudes internes, %d marqués (≥ %.0f°),"
          " %d arrondis — les %d carrefours gardent leur angle"
          % (n_coude, n_marque, COUDE_MIN_DEG, n_rond, len(noeuds)))
    print("        trottoir : %d îlots bordés, %.2f km de bordure,"
          " marche de %.0f cm, %d triangles"
          % (st_tr["ilots"], st_tr["long"] / 1000.0,
             HAUTEUR_BORDURE * 100.0, n_tri_tr))
    print("        %d arêtes d'emprise sur %d longent une rue, %d ont la place"
          " d'un trottoir de %.1f m"
          % (st_tr["avec_rue"], st_tr["aretes"], st_tr["avec_trottoir"],
             LARGEUR_TROTTOIR))
    print("        %d coins de trottoir, dont %d arrondis — %d coudes le sont"
          " des DEUX bords, donc à largeur de rue constante"
          % (st_tr["coins"], st_tr["arrondis"], st_tr["coudes_entiers"]))
    print("        marquage : %d passages piétons (%d bandes de %.2f m),"
          " %d traits d'axe, %d pleins de virage, %d lignes de rive"
          % (st_marq["passages"], st_marq["bandes"], PASSAGE_BANDE,
             st_marq["traits"], st_marq["pleins"], st_marq["rives"]))
    print("        %d tronçons trop étroits pour un trottoir, donc sans"
          " passage · %d passages refusés au-dessus de l'Ilse · %d triangles"
          % (st_marq["sans_trottoir"], st_marq["sur_eau"],
             st_marq["tri"]))
    # 🌊 LE BORD DE L'EAU. Le compte rendu tient en trois lignes parce que la
    # règle tient en trois lignes : qui traverse prend un pont, qui longe prend
    # un mur, et le contrôle dit combien d'asphalte reste en l'air.
    aire_eau, aire_cache, aire_dela, depasse = _asphalte_en_lair(
        routes, coudes, chenal, plateformes, murs_eau, morceaux_voirie)
    print("  bord de l'eau : %d ponts (%.0f m de tablier, %d piles),"
          " %.2f km de quai porté en %d longueurs"
          % (st_bord["pont"], st_bord["pont_m"], st_bord["pile"],
             st_quai["quai_m"] / 1000.0, st_quai["runs"]))
    print("        parapet de %.2f m : %.2f km · mur avancé sur l'eau :"
          " %.2f km · %d morceaux cliquables, sans joint visible"
          % (PARAPET_H,
             (st_bord["parapet_m"] + st_quai["parapet_m"]) / 1000.0,
             st_quai["avance_m"] / 1000.0, st_quai["morceaux"]))
    # 🌉 CE QUI A ÉTÉ COUPÉ AUX PONTS, ET C'EST LE CONTRÔLE DU 2026-08-19 :
    # le parapet d'un pont ne doit border que l'eau libre. Ce qui est retiré
    # ici est ce qui montait sur la terre ou sur le quai — donc en travers de
    # la voie de berge. Le compte de bouts dit qu'il en reste UN par joue :
    # deux, et le muret se serait coupé au milieu d'une travée.
    print("        parapet de pont : %.0f m gardés sur l'eau en %d bouts"
          " (%d attendus) · retirés : %.0f m sur le quai, %.0f m sur la terre"
          "  %s"
          % (st_bord["parapet_m"], st_bord["bouts"], 2 * st_bord["pont"],
             st_bord["sur_quai"],
             st_bord["parapet_coupe_m"] - st_bord["sur_quai"],
             "✅" if st_bord["bouts"] == 2 * st_bord["pont"]
             else "❌ un muret coupé en deux"))
    # 🔴 LE CHIFFRE QUI PROUVE QUE LE MUR LONGE LE FLEUVE : il est bâti À
    # PARTIR de la berge, donc son écart à elle EST son avancée sur l'eau, et
    # rien d'autre. Avant le 2026-08-19 le mur était un décalé de la route et
    # cet écart dérivait jusqu'à 8,1 m sans que personne puisse le dire.
    print("        berge : %.0f m de rive suivie · refusé : %d stations"
          " (%.0f m) de talus de champ, %d (%.0f m) sans chaussée à %.0f m,"
          " %d (%.0f m) sous un tablier"
          % (st_quai["quai_m"],
             st_quai["talus"], st_quai["talus"] * QUAI_PAS,
             st_quai["campagne"], st_quai["campagne"] * QUAI_PAS,
             QUAI_PORTEE,
             st_quai["tablier"], st_quai["tablier"] * QUAI_PAS))
    print("        asphalte au-dessus du chenal : %.0f m², porté à %.1f %% ·"
          " %.0f m² masqués derrière un parapet · %.0f m² au-delà"
          " (dépassement max %.2f m)  %s"
          % (aire_eau,
             100.0 * (aire_eau - aire_cache - aire_dela) / max(aire_eau, 1e-9),
             aire_cache, aire_dela, depasse,
             "✅" if aire_dela <= 0.002 * aire_eau else "❌ à regarder"))
    print("        %d triangles" % st_bord["tri"])
    if n_champ:
        print("  champs : %d îlots, chacun sa teinte, découpés en %d bandes"
              " de fauche de %.0f m" % (n_champ, n_bande, BANDE_CHAMP))
    if n_maille_talus:
        # Deux choses à prouver, et une seule ligne pour les deux : que le sol
        # des champs DESCEND SOUS l'eau (sans quoi il n'y a pas de trait de
        # rive, juste une lèvre de terre qui affleure), et que la plaque reste
        # dessous (sans quoi elle ressort par la pente).
        bas_sol = min(p[1] for p in sols.v)
        print("        talus : %d mailles, le sol descend à %.2f m — sous la"
              " nappe (%.2f m) %s, plaque dessous à %.2f m %s"
              % (n_maille_talus, bas_sol, NAPPE_ILSE,
                 "✅" if bas_sol < NAPPE_ILSE else "❌",
                 bas_plaque, "✅" if bas_plaque < bas_sol else "❌"))
    # 🅿️ LE SEUL CONTRÔLE QUI CONFRONTE DEUX CHAÎNES. Partout ailleurs, ce
    # qu'on imprime est mesuré sur ce qu'on vient de dessiner. Ici, la
    # géométrie répond à un nombre calculé par `04` sans elle, et l'écart est
    # un vrai résultat : au-delà de ~10 %, c'est que l'un des deux ment.
    for f_, n_pl_, n_tr_, annonce, n_arb, n_dedans in parkings:
        ecart = 100.0 * (n_pl_ - annonce) / max(annonce, 1)
        print("  place-parking (îlot %d) : %d places rangées, %d annoncées"
              " par 04 — écart %+.0f %% %s"
              % (f_, n_pl_, annonce, ecart,
                 "✅" if abs(ecart) <= 10.0 else "❌ à regarder"))
        print("        trame parallèle à la plus longue façade · module"
              " %.0f m (allée %.0f + deux rangées de %.0f) · place %.2f × %.2f m"
              % (MODULE_PARKING, ALLEE_PARKING, PLACE_LONGUEUR,
                 PLACE_LARGEUR, PLACE_LONGUEUR))
        print("        %d traits peints, %d triangles, %.0f m de retrait au"
              " bord — le sol nu par où on entre"
              % (n_tr_, n_tri_parc, BORD_PARKING))
        print("        %d arbres plantés sur la place, dont %d sur la trame %s"
              % (n_arb, n_dedans, "✅" if n_dedans == 0 else "❌ à regarder"))
    print("  arbres : %d semés dans les îlots" % len(arbres))
    print("  alignements : %d emplacements sur %d tronçons plantables, "
          "%d occupés à t0"
          % (n_align, len(alignements), plantes_t0))
    arbres_dans_chaussee = sum(
        1 for a in arbres
        if _dans_chaussee((a[0], a[1]), chaussees,
                          MARGE_TRONC_CHAUSSEE))
    align_dans_chaussee = sum(
        1 for v in alignements.values() for a in v
        if _dans_chaussee((a[0], a[1]), chaussees,
                          MARGE_TRONC_CHAUSSEE))
    print("        chaussée : %d arbres semés + %d emplacements écartés"
          " (dont %d visibles à t0) · arbres restants : %d  %s"
          % (arbres_ecartes_chaussee, n_align_chaussee,
             n_align_chaussee_t0,
             arbres_dans_chaussee + align_dans_chaussee,
             "✅" if arbres_dans_chaussee + align_dans_chaussee == 0
             else "❌"))
    if arbres_dans_chaussee or align_dans_chaussee:
        raise SystemExit("Des arbres restent dans la chaussée.")
    arbres_dans_eau = sum(1 for a in arbres
                          if chenal.dans_eau((a[0], a[1])))
    align_dans_eau = sum(1 for v in alignements.values() for a in v
                         if chenal.dans_eau((a[0], a[1])))
    print("        %d emplacements de pont écartés · arbres dans l'eau : %d  %s"
          % (n_align_eau, arbres_dans_eau + align_dans_eau,
             "✅" if arbres_dans_eau + align_dans_eau == 0 else "❌"))
    if arbres_dans_eau or align_dans_eau:
        raise SystemExit("Des arbres restent dans le polygone de la rivière.")
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
        # 🔧 LA VILLE RÉPARÉE, groupe par groupe, jamais montrée au chargement.
        # Le bâti neuf d'un îlot ruiné, et le tablier neuf d'un franchissement
        # emporté : les deux seules géométries qui apparaissent en cours de
        # partie, et elles sont calculées ici comme tout le reste.
        "repare": repare.json(),
        "repare_voirie": repare_voirie.json(),
        "sols": sols.json(),
        "eau": eau.json(),
        "voirie": voirie.json(),
        # Déjà en repère Godot : [x, y, z, échelle, lacet]. Godot ne fait
        # aucune conversion de coordonnées, c'est la règle du contrat.
        "arbres": [[round(c, 2) for c in G(a[0], a[1], a[2])]
                   + [round(a[3], 3), round(a[4], 3), int(a[5])]
                   for a in arbres],
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
        # L'axe et la largeur façade à façade de chaque tronçon, déjà en
        # repère Godot : [largeur, [[x, z, x, z…], …]]. Godot n'en fait pas une
        # route — il en fait la SILHOUETTE qu'il détoure quand on la choisit.
        "couloirs": couloirs,
        # L'emprise au sol de chaque îlot, déjà en repère Godot : [[x, y, z], …],
        # anneau OUVERT. Jamais affichée — c'est la moitié basse du masque de
        # sélection, celle que la silhouette rendue ne peut pas donner.
        "emprises": emprises,
        "riverains": {str(f): sorted(v) for f, v in r2i.items()},
        "reperes": _reperes(ilots, routes, cx, cy, relief, ponts_vus),
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


def _cap_plat(m, anneau, y, coul, G, relief=None, facteur=1.0):
    """Un cap horizontal — ou suivant le talus si `relief` est donné.

    `facteur` enfonce la surface en proportion du creux : c'est ce que la
    plaque de sol utilise pour rester sous le champ sans qu'il faille faire
    coïncider deux découpages."""
    if relief is None:
        alt = lambda p: y                                  # noqa: E731
    else:
        alt = lambda p: y + relief.z(p[0], p[1]) * facteur  # noqa: E731
    for ia, ib, ic in trianguler(anneau):
        a, b, c = anneau[ia], anneau[ib], anneau[ic]
        m.triangle(G(a[0], a[1], alt(a)), G(b[0], b[1], alt(b)),
                   G(c[0], c[1], alt(c)), coul)


def _chenal_eau(m_eau, m_dur, anneau, chenal, coul_eau, coul_mur, G,
                relief=None, niveau_rive=None):
    """Un îlot d'eau : le fond du chenal, la nappe, et les murs de berge.

    ⚠️ Deux maillages, et ce n'est pas un détail : la NAPPE part dans le
    maillage d'eau, qui a un matériau lisse et une couleur unique ; le FOND et
    les MURS partent avec le sol, dont le matériau lit la couleur des sommets.
    Mis dans l'eau, un mur de quai serait bleu et brillant.

    Les murs ne sont posés que sur les arêtes qui SÉPARENT l'eau de la ville.
    Six îlots d'eau bout à bout partagent cinq arêtes en travers du courant :
    y bâtir un mur mettrait cinq barrages dans la rivière.

    Renvoie (murs émis, murs qui regardent bien vers l'eau) — un mur de quai
    tourné vers la ville serait invisible, et ça ne se devine pas.

    🔄 LE HAUT DU MUR SUIT LE SOL depuis le 2026-08-18, au lieu d'être posé à
    `Y_TERRAIN`. Une seule règle — *le mur monte jusqu'à la surface du sol* —
    et elle fait les deux bords d'eau que l'auteur a dessinés : 2,6 m de quai
    droit là où la ville tient la rive, une lèvre noyée de 45 cm là où le champ
    descend déjà au ras de l'eau. Elle répare aussi une fente qui existait
    avant le talus : le haut du mur était 15 cm SOUS les caps d'îlot et 8 cm
    sous l'asphalte, donc une rue de quai surplombait le vide."""
    m = m_dur
    _cap_plat(m_dur, anneau, FOND_ILSE, coul_mur, G)      # le fond
    _cap_plat(m_eau, anneau, NAPPE_ILSE, coul_eau, G)     # la nappe

    ok = tot = 0
    n = len(anneau)
    for i in range(n):
        a, b = anneau[i], anneau[(i + 1) % n]
        if not chenal.est_berge(a, b):
            continue
        dx, dy = b[0] - a[0], b[1] - a[1]
        L = math.hypot(dx, dy)
        if L < 1e-9:
            continue
        tot += 1
        # Une arête droite ne se débite que si un talus la longe : ailleurs le
        # haut est horizontal et deux triangles suffisent.
        k = 1
        if relief is not None and relief.boite_active(
                min(a[0], b[0]), min(a[1], b[1]),
                max(a[0], b[0]), max(a[1], b[1])):
            k = max(1, int(math.ceil(L / TALUS_PAS)))
        for j in range(k):
            p = (a[0] + dx * j / k, a[1] + dy * j / k)
            q = (a[0] + dx * (j + 1) / k, a[1] + dy * (j + 1) / k)
            # Pris SUR la ligne de berge, sans écart vers la terre : c'est
            # exactement là que le sol du champ s'arrête, donc le haut du mur
            # et le bord du talus tombent au même millimètre.
            hp = hq = Y_SOL
            if relief is not None:
                hp += relief.z(p[0], p[1])
                hq += relief.z(q[0], q[1])
            if niveau_rive is not None:
                niveau = niveau_rive((p[0] + q[0]) / 2.0,
                                     (p[1] + q[1]) / 2.0)
                hp += niveau
                hq += niveau
            # Le mur regarde l'EAU, pas la ville : on parcourt l'arête à
            # l'envers de ce que fait un mur de bâtiment, ce qui retourne
            # la face.
            pa_h, pb_h = G(p[0], p[1], hp), G(q[0], q[1], hq)
            pa_b, pb_b = G(p[0], p[1], FOND_ILSE), G(q[0], q[1], FOND_ILSE)
            m.triangle(pb_b, pa_b, pa_h, coul_mur)
            m.triangle(pb_b, pa_h, pb_h, coul_mur)
            if j == 0:
                nn = normale(pb_b, pa_b, pa_h)
                if (nn[0] * dy + nn[2] * dx) / L < -0.9:
                    ok += 1
    return ok, tot


def _sol(m, anneau, coul, G, relief=None):
    """Un cap posé sur la plaque, SANS AUCUN MUR — donc impossible à lire
    comme un bâtiment raté. Les seize îlots à hauteur nulle sont des
    surfaces : champs, parc, jardins, et la place du marché.

    🔄 Il était SUBDIVISÉ pour suivre un champ d'altitude, puis strictement
    plat une fois la carte aplatie. Il redevient échantillonné — mais sur le
    seul relief qui reste, et seulement là où il existe : `relief.z` vaut 0,0
    pile partout ailleurs, donc la ville ne bouge pas d'un millimètre."""
    for ia, ib, ic in trianguler(anneau):
        a, b, c = anneau[ia], anneau[ib], anneau[ic]
        ya = yb = yc = Y_SOL
        if relief is not None:
            ya += relief.z(a[0], a[1])
            yb += relief.z(b[0], b[1])
            yc += relief.z(c[0], c[1])
        m.triangle(G(a[0], a[1], ya), G(b[0], b[1], yb),
                   G(c[0], c[1], yc), coul)


def _acces_pavillonnaire(parcelle, emprises, rues):
    """Le plus court trajet maison→rue contraint à l'angle droit.

    Pour chaque limite sur rue, on exprime chaque arête du bâtiment dans le
    repère de cette limite : `t` le long de la rue, `n` en profondeur. Les
    deux bouts qui partagent le même `t` forment donc, par construction, un
    chemin perpendiculaire. Parmi tous ces chemins possibles, on garde le plus
    court ; une égalité se départage vers le milieu de la façade pour éviter
    qu'un long mur parallèle reçoive systématiquement son accès dans un coin.
    """
    meilleur = None
    marge = ACCES_OUVERTURE / 2.0 + HAIE_LARGEUR
    for k, sur_rue in enumerate(rues):
        if not sur_rue:
            continue
        a, b = parcelle[k], parcelle[(k + 1) % len(parcelle)]
        dx, dy = b[0] - a[0], b[1] - a[1]
        longueur = math.hypot(dx, dy)
        if longueur < ACCES_OUVERTURE + 2.0 * HAIE_LARGEUR:
            continue
        ux, uy = dx / longueur, dy / longueur
        nx, ny = -uy, ux
        tmin, tmax = marge, longueur - marge
        for emp in emprises:
            for i in range(len(emp)):
                p, q = emp[i], emp[(i + 1) % len(emp)]
                px, py = p[0] - a[0], p[1] - a[1]
                qx, qy = q[0] - a[0], q[1] - a[1]
                t0, t1 = px * ux + py * uy, qx * ux + qy * uy
                n0, n1 = px * nx + py * ny, qx * nx + qy * ny
                dt = t1 - t0
                if abs(dt) < 1e-9:
                    if t0 < tmin or t0 > tmax:
                        continue
                    lo, hi = 0.0, 1.0
                else:
                    z0, z1 = (tmin - t0) / dt, (tmax - t0) / dt
                    lo, hi = max(0.0, min(z0, z1)), min(1.0, max(z0, z1))
                    if lo > hi:
                        continue
                essais = [lo, hi, (lo + hi) / 2.0]
                dn = n1 - n0
                if abs(dn) > 1e-9:
                    racine = -n0 / dn
                    if lo <= racine <= hi:
                        essais.append(racine)
                for lam in essais:
                    t = t0 + dt * lam
                    n = n0 + dn * lam
                    maison = (p[0] + (q[0] - p[0]) * lam,
                               p[1] + (q[1] - p[1]) * lam)
                    route = (a[0] + ux * t, a[1] + uy * t)
                    distance = abs(n)
                    if distance < 0.25:
                        continue
                    cle = (round(distance, 9), abs(t - longueur / 2.0))
                    if meilleur is None or cle < meilleur[0]:
                        vx, vy = route[0] - maison[0], route[1] - maison[1]
                        lv = math.hypot(vx, vy)
                        # `asin(dot)` mesure l'écart à 90°, pas l'angle
                        # lui-même. Il doit rester nul à l'arrondi près.
                        ecart = math.degrees(math.asin(min(
                            1.0, abs((vx * ux + vy * uy) / lv))))
                        meilleur = (cle, {"arete": k, "maison": maison,
                                          "route": route,
                                          "longueur": distance,
                                          "ecart_angle": ecart})
    return None if meilleur is None else meilleur[1]


def _ouvrir_segment(a, b, centre, largeur):
    """Les deux morceaux d'une limite après l'ouverture du chemin."""
    dx, dy = b[0] - a[0], b[1] - a[1]
    longueur = math.hypot(dx, dy)
    if longueur < 1e-9:
        return []
    ux, uy = dx / longueur, dy / longueur
    t = max(0.0, min(longueur,
                     (centre[0] - a[0]) * ux + (centre[1] - a[1]) * uy))
    demi = largeur / 2.0
    avant = (a[0] + ux * max(0.0, t - demi),
             a[1] + uy * max(0.0, t - demi))
    apres = (a[0] + ux * min(longueur, t + demi),
             a[1] + uy * min(longueur, t + demi))
    return [(a, avant), (apres, b)]


def _haie(m, a, b, coul, G):
    """Un petit prisme le long d'une limite de parcelle.

    Le segment est raccourci d'une demi-largeur à chaque bout : deux limites
    qui se rencontrent au coin peuvent se toucher, jamais se dépasser. Renvoie
    la longueur visible pour que le contrôle imprimé mesure ce qui est dessiné.
    """
    dx, dy = b[0] - a[0], b[1] - a[1]
    longueur = math.hypot(dx, dy)
    if longueur < HAIE_SEGMENT_MIN:
        return 0.0
    ux, uy = dx / longueur, dy / longueur
    vx, vy = -uy, ux
    demi = HAIE_LARGEUR / 2.0
    a = (a[0] + ux * demi, a[1] + uy * demi)
    b = (b[0] - ux * demi, b[1] - uy * demi)
    anneau = [
        (a[0] + vx * demi, a[1] + vy * demi),
        (a[0] - vx * demi, a[1] - vy * demi),
        (b[0] - vx * demi, b[1] - vy * demi),
        (b[0] + vx * demi, b[1] + vy * demi),
    ]
    y0, y1 = Y_SOL, Y_SOL + HAIE_HAUTEUR
    for k in range(4):
        p, q = anneau[k], anneau[(k + 1) % 4]
        m.triangle(G(p[0], p[1], y0), G(q[0], q[1], y0),
                   G(q[0], q[1], y1), coul, (0.76, 0.76, 1.0))
        m.triangle(G(p[0], p[1], y0), G(q[0], q[1], y1),
                   G(p[0], p[1], y1), coul, (0.76, 1.0, 1.0))
    for ia, ib, ic in trianguler(anneau):
        p, q, r = anneau[ia], anneau[ib], anneau[ic]
        m.triangle(G(p[0], p[1], y1), G(q[0], q[1], y1),
                   G(r[0], r[1], y1), tuple(c * 1.06 for c in coul))
    return longueur - HAIE_LARGEUR


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


def _decaler(anneau, dist):
    """L'anneau décalé de `dist` mètres vers l'EXTÉRIEUR, coin par coin.

    Le décalage se fait sur la bissectrice des deux normales sortantes, donc
    la longueur du décalage à un coin vaut `dist / sin(θ/2)` : c'est ce qui
    fait que les deux pans se rejoignent exactement sur l'arête, sans fente ni
    recouvrement. La formule tenue ici est `(n0 + n1) / (1 + n0·n1)`.

    ⚠️ LE PLAFOND N'EST PAS DÉCORATIF. Sur un coin très fermé, `1 + n0·n1`
    tend vers zéro et le sommet part à l'infini — un seul coin suffirait à
    envoyer un triangle à l'autre bout de la ville. `_ecorner` borne déjà les
    angles à 70,2° en amont (soit un décalage de 1,74·dist), mais ce code ne
    doit pas dépendre d'un réglage fait ailleurs.
    """
    n = len(anneau)
    # 🔴 LE SENS DU PARCOURS SE MESURE, il ne se suppose pas. Un anneau horaire
    # décalé avec la normale d'un anneau trigonométrique rentre au lieu de
    # sortir : le toit passerait SOUS le mur, et le défaut serait invisible sur
    # les 95 % de bâtiments dont l'anneau est dans le bon sens.
    signe = 1.0 if aire_signee(anneau) > 0.0 else -1.0
    nrm = []
    for i in range(n):
        a, b = anneau[i], anneau[(i + 1) % n]
        dx, dy = b[0] - a[0], b[1] - a[1]
        L = math.hypot(dx, dy)
        nrm.append(None if L < 1e-9
                   else (signe * dy / L, -signe * dx / L))
    if all(v is None for v in nrm):
        return list(anneau)
    for i in range(n):                     # une arête nulle hérite du voisin
        if nrm[i] is None:
            nrm[i] = next(nrm[(i + k) % n] for k in range(1, n + 1)
                          if nrm[(i + k) % n] is not None)

    out = []
    for i in range(n):
        n0 = nrm[(i - 1) % n]              # l'arête qui arrive
        n1 = nrm[i]                        # l'arête qui repart
        k = 1.0 + n0[0] * n1[0] + n0[1] * n1[1]
        mx, my = n0[0] + n1[0], n0[1] + n1[1]
        if k > 0.32:
            mx, my = mx / k, my / k
        else:
            L = math.hypot(mx, my)         # coin fermé : on borne à 2,5·dist
            mx, my = (n1[0] * 2.5, n1[1] * 2.5) if L < 1e-9 \
                else (mx / L * 2.5, my / L * 2.5)
        out.append((anneau[i][0] + dist * mx, anneau[i][1] + dist * my))
    return out


def _rive(m, anneau, y_haut, epaisseur, coul, G):
    """La tranche verticale du débord de toit. C'est elle qu'on voit d'en
    haut comme un liseré sombre autour de chaque maison, et c'est elle qui
    reçoit l'ombre portée du toit sur la façade."""
    for i in range(len(anneau)):
        a, b = anneau[i], anneau[(i + 1) % len(anneau)]
        pa_b = G(a[0], a[1], y_haut)
        pb_b = G(b[0], b[1], y_haut)
        pa_h = G(a[0], a[1], y_haut + epaisseur)
        pb_h = G(b[0], b[1], y_haut + epaisseur)
        m.triangle(pa_b, pb_b, pb_h, coul)
        m.triangle(pa_b, pb_h, pa_h, coul)


def _acrotere(m, anneau, y_haut, coul, G):
    """Le muret d'un toit plat, ÉMIS EN DOUBLE FACE — deux quads opposés par
    arête, donc visible du dedans comme du dehors sans épaisseur réelle. Le
    dessus du toit reste à `y_haut` : c'est le retrait de 45 cm qui fait lire
    « toiture » et non « tranche de boîte »."""
    for i in range(len(anneau)):
        a, b = anneau[i], anneau[(i + 1) % len(anneau)]
        pa_b = G(a[0], a[1], y_haut)
        pb_b = G(b[0], b[1], y_haut)
        pa_h = G(a[0], a[1], y_haut + ACROTERE)
        pb_h = G(b[0], b[1], y_haut + ACROTERE)
        m.triangle(pa_b, pb_b, pb_h, coul)
        m.triangle(pa_b, pb_h, pa_h, coul)
        m.triangle(pb_b, pa_b, pa_h, coul)
        m.triangle(pb_b, pa_h, pb_h, coul)


def _cheminee(m, x, y, y_bas, y_haut, u, coul, G):
    """Une souche : quatre murs et un chapeau, alignés sur le faîtage `u`.

    Elle part de `y_bas` (sous la couverture) et non du faîtage : à mi-pente,
    une souche posée sur le plan du toit flotterait au-dessus du versant.

    🔄 Le 2026-08-18, la boîte orientée est sortie d'ici dans `_boite` : la pile
    d'un pont est la même forme, à la taille près."""
    return _boite(m, (x, y), u, CHEMINEE_COTE, CHEMINEE_COTE,
                  y_bas, y_haut, coul, G)


def _bandes_de_fauche(anneau, coul):
    """Un champ coupé en bandes alternées, comme une parcelle fauchée.

    Le sens de la fauche est tiré de la POSITION du champ (35) : deux champs
    voisins ne se fauchent pas dans le même sens, et c'est ce qui fait qu'on
    lit des parcelles agricoles et non une trame posée sur la ville.

    Renvoie une liste de (morceau, couleur). Si le champ est trop petit pour
    deux bandes, il ressort tel quel — un seul morceau, sa couleur d'origine.
    """
    r = random.Random(_graine_lieu(anneau) ^ 0x8A17)
    ang = r.uniform(0.0, math.pi)
    nx, ny = math.cos(ang), math.sin(ang)
    proj = [p[0] * nx + p[1] * ny for p in anneau]
    s0, s1 = min(proj), max(proj)
    if s1 - s0 < BANDE_CHAMP * 1.6:
        return [(anneau, coul)]

    out, reste = [], [anneau]
    rang = 0
    s = s0 + BANDE_CHAMP
    # Le plafond de rangs borne le cas pathologique d'un champ démesuré ; à
    # 15 m de bande, 80 rangs couvrent 1,2 km, soit plus que Wehrau entière.
    while s < s1 - 0.5 and rang < 80 and reste:
        suivant = []
        for mo in reste:
            for piece in D4C.couper(mo, (nx * s, ny * s), (nx, ny)):
                cx = sum(p[0] for p in piece) / len(piece)
                cy = sum(p[1] for p in piece) / len(piece)
                # `couper` rend les morceaux des DEUX côtés sans dire lequel :
                # le centroïde tranche, et il est fiable ici parce que chaque
                # morceau est entièrement d'un côté de la droite.
                if cx * nx + cy * ny < s:
                    out.append((piece, rang))
                else:
                    suivant.append(piece)
        reste = suivant
        rang += 1
        s += BANDE_CHAMP
    out.extend((mo, rang) for mo in reste)
    return [(mo, tuple(c * (1.0 + (BANDE_ECART if k % 2 else -BANDE_ECART))
                       for c in coul)) for mo, k in out]


def _index_murs(empreintes, grille=2.0):
    """Index de grille des murs de TOUS les bâtiments d'un îlot.

    Chaque arête y entre avec le rang de son bâtiment : c'est ce rang qui
    permet ensuite d'ignorer le bâtiment lui-même. Sans index, chercher le
    voisin de chaque mur serait quadratique — jusqu'à 40 volumes par îlot.

    ⚠️ L'arête est semée LE LONG DU SEGMENT, pas dans sa boîte
    englobante — la même différence qu'entre un trait et le rectangle qui
    le contient. Une arête de barre de 100 m en diagonale occupe 50 cases
    le long de sa ligne, contre 2 500 dans sa boîte : autant de faux
    voisins à écarter pour chaque mur. La passe entière (index +
    mitoyenneté + façades sur rue) coûte 0,2 s sur les 11 s de l'export,
    mesuré le 2026-08-18.

    ⚠️ `_index_bord`, plus haut, a gardé la boîte englobante : ses
    anneaux d'îlot n'ont que des arêtes courtes, et rien n'a montré que
    ça le gênait. Ne pas « uniformiser » sans mesurer d'abord."""
    idx = {}
    for k, emp in enumerate(empreintes):
        n = len(emp)
        for i in range(n):
            a, b = emp[i], emp[(i + 1) % n]
            L = math.hypot(b[0] - a[0], b[1] - a[1])
            # Un pas de demi-case : aucune case traversée ne peut être sautée.
            pas = max(1, int(L / (grille * 0.5)) + 1)
            vues = set()
            for j in range(pas + 1):
                t = float(j) / pas
                c = (int((a[0] + t * (b[0] - a[0])) // grille),
                     int((a[1] + t * (b[1] - a[1])) // grille))
                if c in vues:
                    continue
                vues.add(c)
                idx.setdefault(c, []).append((k, a, b))
    return idx


def _mitoyen(k, a, b, idx, grille=2.0):
    """Ce mur du bâtiment `k` est-il collé à un autre bâtiment ?"""
    dx, dy = b[0] - a[0], b[1] - a[1]
    L = math.hypot(dx, dy)
    if L < 1e-9:
        return False
    ux, uy = dx / L, dy / L
    # Trois points de contrôle plutôt qu'un : un mur n'est mitoyen que s'il
    # l'est sur toute sa longueur. Effleurer le coin du voisin ne compte pas.
    for t in (0.25, 0.5, 0.75):
        p = (a[0] + ux * L * t, a[1] + uy * L * t)
        cx, cy = int(p[0] // grille), int(p[1] // grille)
        touche = False
        for ddx in (-1, 0, 1):
            for ddy in (-1, 0, 1):
                for (j, c, e) in idx.get((cx + ddx, cy + ddy), ()):
                    if j == k:
                        continue
                    vx, vy = e[0] - c[0], e[1] - c[1]
                    M = math.hypot(vx, vy)
                    if M < 1e-9:
                        continue
                    if abs(ux * vy - uy * vx) / M > MITOYEN_SINUS:
                        continue
                    if D4C.dist_pt_seg(p, c, e) <= MITOYEN_JEU:
                        touche = True
                        break
                if touche:
                    break
            if touche:
                break
        if not touche:
            return False
    return True


def _segments_rue(parcelle, idx_bord):
    """Les arêtes de la parcelle qui donnent sur la rue, en segments."""
    n = len(parcelle)
    return [(parcelle[i], parcelle[(i + 1) % n])
            for i, r in enumerate(_sur_rue(parcelle, idx_bord)) if r]


def _point_proche(p, a, b):
    """Le point du segment [a, b] le plus proche de `p`."""
    dx, dy = b[0] - a[0], b[1] - a[1]
    L2 = dx * dx + dy * dy
    if L2 < 1e-18:
        return a
    t = ((p[0] - a[0]) * dx + (p[1] - a[1]) * dy) / L2
    t = max(0.0, min(1.0, t))
    return (a[0] + t * dx, a[1] + t * dy)


def _devant_rue(a, b, segs):
    """Ce mur regarde-t-il une limite sur rue de sa propre parcelle ?"""
    dx, dy = b[0] - a[0], b[1] - a[1]
    L = math.hypot(dx, dy)
    if L < 1e-9:
        return False
    ux, uy = dx / L, dy / L
    # Anneau TRIGONOMÉTRIQUE (forcé par `anneau_ouvert`) ⇒ l'intérieur est à
    # gauche du parcours, donc le dehors est (dy, −dx). Le même raisonnement
    # que le contrôle de sens des murs dans `_masse`, à un repère près.
    mx, my = (a[0] + b[0]) / 2.0, (a[1] + b[1]) / 2.0
    nx, ny = uy, -ux
    for (c, e) in segs:
        vx, vy = e[0] - c[0], e[1] - c[1]
        M = math.hypot(vx, vy)
        if M < 1e-9:
            continue
        if abs(ux * vy - uy * vx) / M > RUE_SINUS:
            continue
        q = _point_proche((mx, my), c, e)
        if math.hypot(q[0] - mx, q[1] - my) > RETRAIT_MAX:
            continue
        # La rue est-elle DEVANT ce mur ? C'est ce test-là, et lui seul, qui
        # écarte la façade arrière — elle est parallèle à la rue et, sur une
        # parcelle courte, presque aussi près.
        if (q[0] - mx) * nx + (q[1] - my) * ny >= -RUE_DERRIERE:
            return True
    return False


def _facades(k, emp, parcelle, idx_bord, idx_murs, st):
    """Le genre de percement de CHAQUE mur de l'empreinte, arête par arête.

    Trois questions dans cet ordre, et c'est tout :
      · le mur est-il mitoyen ? alors il est aveugle ;
      · donne-t-il sur la rue ? alors il porte le rez qui s'ouvre — vitrine
        pour le front commerçant, porte ailleurs ;
      · sinon c'est une façade arrière : des fenêtres, pas d'entrée.
    """
    sur_rue, ailleurs = FACADE_TISSU.get(st, FACADE_TISSU_DEFAUT)
    segs = _segments_rue(parcelle, idx_bord)
    n = len(emp)

    def longueur(i):
        a, b = emp[i], emp[(i + 1) % n]
        return math.hypot(b[0] - a[0], b[1] - a[1])

    out = []
    for i in range(n):
        a, b = emp[i], emp[(i + 1) % n]
        if longueur(i) < FACADE_MIN or _mitoyen(k, a, b, idx_murs):
            out.append(FACADE_AVEUGLE)
        elif _devant_rue(a, b, segs):
            out.append(sur_rue)
        else:
            out.append(ailleurs)

    # ⚠️ UNE SEULE PORTE PAR BÂTIMENT, sur sa plus longue façade sur rue. Un
    # pavillon d'angle a deux façades sur rue et n'a pas deux entrées.
    if sur_rue == FACADE_PORTE:
        candidats = [i for i, g in enumerate(out) if g == FACADE_PORTE]
        if candidats:
            garde = max(candidats, key=longueur)
            for i in candidats:
                if i != garde:
                    out[i] = FACADE_LOGEMENT

    for i, g in enumerate(out):
        facades[g] += 1
        facades_m[g] += longueur(i)
    return out


def _masse(m, anneau, d, coul, G, niveaux=None, pente=0.0, faitage=None,
           coul_toit=None, genres=None, alea=0.0):
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
        # 🪟 LES COORDONNÉES DE FAÇADE. `u` court de 0 au coin `a` jusqu'à
        # `L` au coin `b`, et `L` est répété sur les quatre sommets : c'est
        # lui qui permet au shader de centrer les travées sur CE mur-là.
        # Un mur aveugle n'en porte aucune — il sort comme avant le
        # 2026-08-18, donc en enduit plein.
        g = FACADE_AVEUGLE if genres is None else genres[i]
        genre = None
        pied = tete = None
        if g != FACADE_AVEUGLE:
            Lm = math.hypot(b[0] - a[0], b[1] - a[1])
            pied, tete = (0.0, Lm), (Lm, Lm)
            genre = (float(g), alea)
        m.triangle(pa_b, pb_b, pb_h, coul, (fb, fb, fh),
                   facade=None if genre is None else (pied, tete, tete),
                   genre=genre)
        m.triangle(pa_b, pb_h, pa_h, coul, (fb, fh, fh),
                   facade=None if genre is None else (pied, tete, pied),
                   genre=genre)
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

    # 🔄 `coul` ne peint plus que les MURS depuis le 2026-08-18. Le toit a son
    # propre matériau ; `coul_toit` absent veut dire « l'ancien rendu », où les
    # deux étaient la même teinte.
    if coul_toit is None:
        coul_toit = coul

    # La direction de rue commande déjà le faîtage. Les rares volumes sans
    # adresse reprennent leur plus longue arête : même dans ce repli, les
    # panneaux suivent donc le bâtiment et jamais une grille mondiale.
    axe_toit = faitage
    if axe_toit is None:
        a, b = max(((anneau[i], anneau[(i + 1) % len(anneau)])
                    for i in range(len(anneau))),
                   key=lambda e: math.hypot(e[1][0] - e[0][0],
                                            e[1][1] - e[0][1]))
        L = math.hypot(b[0] - a[0], b[1] - a[1])
        axe_toit = ((b[0] - a[0]) / L, (b[1] - a[1]) / L)
    # Un vecteur source (x, y) devient (x, -y) dans le plan XZ de Godot.
    axe_uv = (axe_toit[0], -axe_toit[1])

    # ⚠️ TOIT PENTU SUR EMPREINTE CONVEXE SEULEMENT. Mesuré : 93 % des
    # empreintes le sont, les 7 % restantes prennent un toit plat et le compte
    # s'imprime. La pente est mise à 0 en amont pour les mêmes empreintes, donc
    # les deux tests disent la même chose — celui-ci est la ceinture.
    if pente and pente > 0.0 and faitage is not None and _convexe(anneau):
        bord = _decaler(anneau, DEBORD_TOIT)
        # La rive est la MÊME couverture, franchement assombrie : c'est une
        # tranche, elle ne reçoit jamais le soleil de face. C'est ce contraste
        # qui dessine le contour de chaque maison vue d'en haut.
        _rive(m, bord, y_haut, EPAISSEUR_TOIT,
              tuple(c * 0.70 for c in coul_toit), G)
        h, t = _toit(m, bord, y_haut + EPAISSEUR_TOIT, pente, axe_toit,
                     coul_toit, G, y_haut)
        return ok, n, h, t

    haut_ok = 0
    tris = trianguler(anneau)
    for ia, ib, ic in tris:
        a, b, c = anneau[ia], anneau[ib], anneau[ic]
        pa = G(a[0], a[1], y_haut)
        pb = G(b[0], b[1], y_haut)
        pc = G(c[0], c[1], y_haut)
        m.triangle(pa, pb, pc, coul_toit, axe_toit=axe_uv)
        if normale(pa, pb, pc)[1] > 0.0:
            haut_ok += 1
    # L'acrotère est posé sur TOUS les toits plats, y compris les 159 qui le
    # sont faute d'empreinte convexe. Ce n'est pas idéal — ces bâtiments-là
    # devraient avoir deux pentes — mais un dessus rasé se lit comme une boîte
    # coupée, alors qu'un dessus bordé se lit comme une toiture ratée. Entre
    # les deux erreurs, celle-ci coûte moins cher à l'image.
    if abs(aire_signee(anneau)) >= 20.0:
        _acrotere(m, anneau, y_haut, tuple(c * 0.88 for c in coul), G)
    return ok, n, haut_ok, len(tris)


def _ruine(m, anneau, coul_mur, coul_gravats, G, rng):
    """Un bâtiment que la crue a emporté : des pans de mur cassés à des
    hauteurs différentes, et le plancher du rez à nu entre eux.

    🔴 LA CRÊTE FAIT LA RUINE, PAS LA COULEUR. Arasés au même plan, cent
    bâtiments sortent en lotissement de toits plats. Chaque arête porte donc sa
    hauteur, tirée par PAQUETS de une à trois arêtes : arête par arête on
    obtient une dentelure régulière, qui se lit comme un motif et non comme une
    casse.

    Aucune couverture, aucun acrotère, aucun percement : le dessus est OUVERT.
    Les murs étant à face unique, ceux du fond sont cullés et on voit le sol
    sombre entre ceux de devant — c'est le seul trou noir de la ville.
    """
    anneau = _decaler(anneau, -RUINE_RETRAIT)
    n = len(anneau)
    y_bas = -ENFOUISSEMENT
    hauteurs = []
    while len(hauteurs) < n:
        h = rng.choice(RUINE_PANS) * ETAGE_M
        hauteurs += [h] * rng.randint(*RUINE_PAN_ARETES)

    def ao(y):
        return AO_MIN + (1.0 - AO_MIN) * min(1.0, max(0.0, (y - y_bas) / AO_HAUTEUR))

    ok = 0
    for i in range(n):
        a, b = anneau[i], anneau[(i + 1) % n]
        y_haut = hauteurs[i]
        pa_b = G(a[0], a[1], y_bas)
        pb_b = G(b[0], b[1], y_bas)
        pa_h = G(a[0], a[1], y_haut)
        pb_h = G(b[0], b[1], y_haut)
        fb, fh = ao(y_bas), ao(y_haut)
        m.triangle(pa_b, pb_b, pb_h, coul_mur, (fb, fb, fh))
        m.triangle(pa_b, pb_h, pa_h, coul_mur, (fb, fh, fh))
        # Le même contrôle de chiralité que `_masse` : on ne parie pas sur le
        # sens des faces après l'inversion de Z, on le mesure.
        dx, dy = b[0] - a[0], b[1] - a[1]
        L = math.hypot(dx, dy)
        nn = normale(pa_b, pb_b, pb_h)
        if L > 1e-9 and (nn[0] * dy + nn[2] * dx) / L > 0.9:
            ok += 1

    tris = trianguler(anneau)
    f = ao(RUINE_DALLE_Y)
    for ia, ib, ic in tris:
        pa = G(anneau[ia][0], anneau[ia][1], RUINE_DALLE_Y)
        pb = G(anneau[ib][0], anneau[ib][1], RUINE_DALLE_Y)
        pc = G(anneau[ic][0], anneau[ic][1], RUINE_DALLE_Y)
        m.triangle(pa, pb, pc, coul_gravats, (f, f, f))
    return ok, n, len(tris), len(tris)


def _toit(m, anneau, y_egout, pente, faitage, coul, G, y_mur=None):
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
    axe_uv = (ux, -uy)
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
            m.triangle(tri[0], tri[1], tri[2], coul, axe_toit=axe_uv)
            tot += 1
            ok += 1

    # 🔥 LA SOUCHE, posée sur la ligne de faîtage — donc forcément à l'intérieur
    # de l'empreinte, sans avoir à tester quoi que ce soit. Sa position le long
    # du faîtage et son existence sont tirées du LIEU (35) : la même ville
    # ressort toujours avec les mêmes cheminées aux mêmes endroits.
    if y_mur is not None and abs(aire_signee(anneau)) >= CHEMINEE_AIRE_MIN:
        r = random.Random(_graine_lieu(anneau) ^ 0xC17E)
        if r.random() <= PART_CHEMINEES:
            ts = [(p[0] - ox) * ux + (p[1] - oy) * uy for p in anneau]
            f = r.uniform(0.22, 0.78)
            t = min(ts) + f * (max(ts) - min(ts))
            cheminees[0] += 1
            _cheminee(m, ox + ux * t, oy + uy * t,
                      y_mur, y_fait + CHEMINEE_HAUT, (ux, uy),
                      COUL_CHEMINEE, G)
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


def _debordement(emprise, parcelle):
    """De combien le bâtiment sort-il de la parcelle qui le porte ?

    🔴 LE DÉFAUT CONNU DU 2026-08-12, et il faut le voir plutôt que le
    deviner. `retracter` décale chaque arête vers l'intérieur ; sur un angle
    RENTRANT les deux droites décalées divergent, la limite de mitre remplace
    le pic par un biseau, et ce biseau peut ressortir du côté de la rue. Le
    dépassement est borné par le recul du tissu — 5 m en pavillonnaire, 6 m
    sur la barre — donc sans commune mesure avec les 258 m de la session 9,
    mais un bâtiment qui mord sur la chaussée reste un bâtiment qui ment.

    Depuis que 07 lit `batiments`, l'association à la parcelle d'origine est
    explicite. L'anneau doit être fermé pour `dedans` : l'ancien contrôle
    oubliait sa dernière arête et annonçait encore 38 faux débordements."""
    parcelles = [parcelle]
    parcelle_fermee = dict(parcelle)
    parcelle_fermee["anneau"] = list(parcelle["anneau"]) + [parcelle["anneau"][0]]
    pire = 0.0
    for q in emprise:
        d = min((min(D4C.dist_pt_seg(q, p["anneau"][i],
                                     p["anneau"][(i + 1) % len(p["anneau"])])
                     for i in range(len(p["anneau"]))))
                for p in parcelles) if parcelles else 0.0
        if d > pire and not dedans(parcelle_fermee["anneau"], q):
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


def _direction_faitage(parcelle, idx_bord):
    """La plus longue façade sur rue, même règle R2 que 04d.

    04d produit l'empreinte ; 07 ne choisit plus sa forme. Cette direction ne
    sert qu'à plier son toit, parallèlement à la rue qui l'adresse. Les boîtes
    ont un toit plat, donc leur direction de plan-masse n'entre pas ici.
    """
    rues = _sur_rue(parcelle, idx_bord)
    meilleur = None
    longueur = 0.0
    for i, rue in enumerate(rues):
        if not rue:
            continue
        a, b = parcelle[i], parcelle[(i + 1) % len(parcelle)]
        dx, dy = b[0] - a[0], b[1] - a[1]
        L = math.hypot(dx, dy)
        if L > longueur:
            longueur = L
            meilleur = (dx / L, dy / L)
    return meilleur


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


def _semer_jardin(anneau, aire, batiments=()):
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
        if any(dedans(list(emp) + [emp[0]], (x, y)) for emp in batiments):
            continue
        # 🌲 Le 6e nombre est l'ESSENCE : 0 feuillu, 1 conifère. Un jardin de
        # ville en compte peu — un thuya, un sapin planté trop près du mur.
        out.append([x, y, 0.0,
                    r.uniform(0.55, 0.95), r.uniform(0.0, 6.2832),
                    1 if r.random() < 0.12 else 0])
    return out


# ================================================ la voirie : courbes et bordures

GRILLE_VOIRIE = 25.0        # l'index spatial des segments de rue, en cellules
LIMITE_MITRE_RUBAN = 2.0    # au-dela, l'onglet part en pointe : on l'ecrete


def _unite(a, b):
    dx, dy = b[0] - a[0], b[1] - a[1]
    L = math.hypot(dx, dy)
    return None if L < 1e-9 else (dx / L, dy / L)


def _aire_xy(poly):
    s = 0.0
    for i in range(len(poly)):
        x1, y1 = poly[i]
        x2, y2 = poly[(i + 1) % len(poly)]
        s += x1 * y2 - x2 * y1
    return s / 2.0


def _index_voirie(routes):
    """Tous les segments de rue, plus une grille pour les retrouver.

    Chaque segment porte de quoi poser un trottoir — la largeur du corridor,
    l'emprise de circulation — ET SON IDENTITÉ (fid, part, rang). C'est
    l'identité qui dit, plus loin, si deux arêtes d'îlot consécutives longent
    LE MÊME coude d'une même rue (à arrondir) ou deux rues différentes (un
    carrefour : on n'y touche pas)."""
    segs, idx = [], {}
    for d in routes:
        larg = d["largeur_m"] or 0.0
        if larg <= 0.0:
            continue                            # les 4 tronçons `rive` à 0 m
        ch = min(D4.EMPRISE_CIRCULATION.get(d["hierarchie"], 8.5), larg)
        for ip, part in enumerate(d["parts"]):
            for k in range(len(part) - 1):
                a, b = part[k], part[k + 1]
                if math.hypot(b[0] - a[0], b[1] - a[1]) < 1e-9:
                    continue
                j = len(segs)
                segs.append((a, b, larg, ch, d["fid"], ip, k))
                for cx in range(int(min(a[0], b[0]) // GRILLE_VOIRIE),
                                int(max(a[0], b[0]) // GRILLE_VOIRIE) + 1):
                    for cy in range(int(min(a[1], b[1]) // GRILLE_VOIRIE),
                                    int(max(a[1], b[1]) // GRILLE_VOIRIE) + 1):
                        idx.setdefault((cx, cy), []).append(j)
    return segs, idx


def _rue_le_long(a, b, nout, segs, idx):
    """La rue que longe cette arête d'emprise : (distance à l'axe, largeur,
    emprise de circulation, fid, part, rang) — ou None.

    ⚠️ ON NE RECALCULE PAS LE RETRAIT DE 04b, ON LE RETROUVE. L'arête d'une
    emprise a été reculée de la demi-largeur de sa rue — ou de la largeur
    ENTIÈRE au bord de l'eau, pour que le quai de 22 m tienne sur la terre.
    Recopier cette règle ici en ferait une seconde source de vérité, qui
    dériverait le jour où 04b changerait. On cherche donc, DANS LA DIRECTION
    DU DEHORS, un segment parallèle, et on MESURE la distance au lieu de la
    supposer. Ce qui ne retombe sur aucune rue — bord de carte, berge, arête
    biseautée par la limite de mitre — n'a pas de trottoir, et c'est juste."""
    mx, my = (a[0] + b[0]) / 2.0, (a[1] + b[1]) / 2.0
    u = _unite(a, b)
    if u is None:
        return None
    cx, cy = int(mx // GRILLE_VOIRIE), int(my // GRILLE_VOIRIE)
    best = None
    for ix in (cx - 1, cx, cx + 1):
        for iy in (cy - 1, cy, cy + 1):
            for j in idx.get((ix, iy), ()):
                sa, sb, larg, ch, fid, ip, k = segs[j]
                us = _unite(sa, sb)
                if us is None or abs(us[0] * u[0] + us[1] * u[1]) < 0.85:
                    continue                    # perpendiculaire : pas elle
                dd = abs((mx - sa[0]) * us[1] - (my - sa[1]) * us[0])
                if dd < ch / 2.0 or dd > larg + 0.75:
                    continue
                # Le test qui fait tout le travail : la rue doit être DEVANT,
                # du côté du dehors. Sans lui, une arête prend la rue qui
                # longe l'AUTRE bord de son îlot dès que l'îlot est mince.
                if D4B.dist_pt_seg((mx + nout[0] * dd, my + nout[1] * dd),
                                   sa, sb) > 0.60:
                    continue
                if best is None or dd < best[0]:
                    best = (dd, larg, ch, fid, ip, k)
    return best


def _largeur_trottoir(dd, ch):
    """Ce qui reste pour un trottoir entre la limite de parcelle et la
    chaussée. Le trottoir ne touche jamais l'asphalte : les derniers
    centimètres restent du sol nu, comme les mètres libres."""
    w = min(LARGEUR_TROTTOIR, dd - ch / 2.0 - JEU_CHAUSSEE)
    return w if w >= TROTTOIR_MIN else 0.0


def _rayon_coude(theta, demi, marge, L1, L2):
    """Le rayon que LE CORRIDOR accepte à ce coude, ou 0.

    ⚠️ Le rayon n'est pas un goût. Arrondir un tracé le pousse vers
    l'intérieur du virage : le trottoir extérieur gonfle d'autant, et le
    trottoir intérieur maigrit. Quatre plafonds, mesurés sur la géométrie du
    coude :

      ① le confort (RAYON_MAX) ;
      ② tenir dans les deux segments voisins — la tangente ne doit pas manger
         plus de la moitié du plus court, sinon deux coudes se chevauchent ;
      ③ l'élargissement du trottoir EXTÉRIEUR reste sous ELARGISSEMENT_MAX ;
      ④ il reste JEU_COUDE de trottoir INTÉRIEUR au sommet du coude.

    🔴 CONSÉQUENCE ASSUMÉE : les coudes très serrés — au-delà de ~70° dans une
    rue ordinaire — ne s'arrondissent PAS. Ce n'est pas un renoncement : dans
    une rue de 13 m bordée de façades, un virage à 90° est un angle DU TISSU.
    Les maisons y font l'angle ; la chaussée le fait aussi. L'adoucir
    demanderait de bouger les parcelles, donc de rouvrir l'étape 2."""
    t = math.tan(math.radians(theta) / 2.0)
    c = 1.0 / math.cos(math.radians(theta) / 2.0) - 1.0
    if t < 1e-6 or c < 1e-9:
        return 0.0
    R = min(RAYON_MAX,
            0.45 * min(L1, L2) / t,
            ELARGISSEMENT_MAX / c - demi,
            (marge - JEU_COUDE) / c + demi)
    return R if R >= RAYON_MIN else 0.0


def _coudes(routes):
    """Le rayon retenu à chaque coude INTERNE de la voirie.

    Clé : (fid, part, rang du sommet). Un coude interne est un sommet au
    milieu d'un tronçon ; les 110 nœuds à trois branches ou plus sont, eux,
    des CARREFOURS et gardent leur angle — c'est ce que l'auteur a demandé, et
    c'est aussi ce qui garde un carrefour lisible."""
    out = {}
    total = marques = arrondis = 0
    for d in routes:
        larg = d["largeur_m"] or 0.0
        if larg <= 0.0:
            continue
        ch = min(D4.EMPRISE_CIRCULATION.get(d["hierarchie"], 8.5), larg)
        demi = larg / 2.0
        libre = demi - ch / 2.0
        w = _largeur_trottoir(demi, ch)
        # Sans trottoir, c'est la CHAUSSÉE qui ne doit pas sortir du corridor :
        # la marge à préserver est alors tous les mètres libres.
        marge = w if w > 0.0 else libre
        for ip, part in enumerate(d["parts"]):
            for iv in range(1, len(part) - 1):
                A, V, B = part[iv - 1], part[iv], part[iv + 1]
                u1, u2 = _unite(A, V), _unite(V, B)
                if u1 is None or u2 is None:
                    continue
                total += 1
                pv = max(-1.0, min(1.0, u1[0] * u2[0] + u1[1] * u2[1]))
                theta = math.degrees(math.acos(pv))
                if theta < COUDE_MIN_DEG:
                    continue                    # l'œil ne voit pas la cassure
                marques += 1
                R = _rayon_coude(
                    theta, demi, marge,
                    math.hypot(V[0] - A[0], V[1] - A[1]),
                    math.hypot(B[0] - V[0], B[1] - V[1]))
                if R <= 0.0:
                    continue
                sens = 1.0 if (u1[0] * u2[1] - u1[1] * u2[0]) > 0 else -1.0
                # Normales tournées vers l'INTÉRIEUR du virage : c'est de ce
                # côté qu'est le centre de l'arc, et c'est le signe de `sens`
                # qui le dit — pas une supposition sur le sens de la rue.
                n1 = (-u1[1] * sens, u1[0] * sens)
                n2 = (-u2[1] * sens, u2[0] * sens)
                bx, by = n1[0] + n2[0], n1[1] + n2[1]
                bl = math.hypot(bx, by)
                dC = R / math.cos(math.radians(theta) / 2.0)
                out[(d["fid"], ip, iv)] = {
                    "R": R, "theta": theta, "sens": sens, "u1": u1, "u2": u2,
                    "n1": n1, "n2": n2,
                    "C": (V[0] + bx / bl * dC, V[1] + by / bl * dC)}
                arrondis += 1
    return out, (total, marques, arrondis)


def _arc(C, r, p1, p2):
    """Les points de l'arc de centre C et de rayon r, par le plus court chemin
    entre les deux directions. Bornes comprises."""
    a1 = math.atan2(p1[1] - C[1], p1[0] - C[0])
    a2 = math.atan2(p2[1] - C[1], p2[0] - C[0])
    da = a2 - a1
    while da > math.pi:
        da -= 2.0 * math.pi
    while da < -math.pi:
        da += 2.0 * math.pi
    n = max(2, int(math.ceil(abs(math.degrees(da)) / PAS_ARC_DEG)))
    return [(C[0] + r * math.cos(a1 + da * k / n),
             C[1] + r * math.sin(a1 + da * k / n)) for k in range(n + 1)]


def _axe_arrondi(part, fid, ip, coudes):
    """La polyligne d'un tronçon, ses coudes retenus remplacés par des arcs."""
    pts = [part[0]]
    for iv in range(1, len(part) - 1):
        cd = coudes.get((fid, ip, iv))
        if cd is None:
            pts.append(part[iv])
            continue
        C, R = cd["C"], cd["R"]
        pts.extend(_arc(C, R,
                        (C[0] - cd["n1"][0] * R, C[1] - cd["n1"][1] * R),
                        (C[0] - cd["n2"][0] * R, C[1] - cd["n2"][1] * R)))
    pts.append(part[-1])
    return pts


def _axe_ruban(pts, demi_largeur, bouts=True):
    """L'axe net réellement couvert par un ruban.

    Les chaussées prolongent leurs deux bouts d'une demi-largeur pour fermer
    les carrefours. Le contrôle des arbres doit lire exactement ces mêmes
    bouts, sinon il protège le segment source tout en laissant un tronc dans
    le carré d'asphalte ajouté à l'intersection.
    """
    net = [pts[0]]
    for p in pts[1:]:
        if math.hypot(p[0] - net[-1][0], p[1] - net[-1][1]) > 1e-6:
            net.append(p)
    if len(net) < 2:
        return []
    if bouts:
        u0, u1 = _unite(net[0], net[1]), _unite(net[-2], net[-1])
        net[0] = (net[0][0] - u0[0] * demi_largeur,
                  net[0][1] - u0[1] * demi_largeur)
        net[-1] = (net[-1][0] + u1[0] * demi_largeur,
                   net[-1][1] + u1[1] * demi_largeur)
    return net


def _index_chaussees(routes, coudes):
    """Les axes affichés et leurs demi-largeurs, pour exclure les troncs."""
    axes, index = {}, []
    for d in routes:
        larg = d["largeur_m"] or 0.0
        if larg <= 0.0:
            continue
        ch = min(D4.EMPRISE_CIRCULATION.get(d["hierarchie"], 8.5), larg)
        morceaux = []
        for ip, part in enumerate(d["parts"]):
            axe = _axe_arrondi(part, d["fid"], ip, coudes)
            morceaux.append(axe)
            net = _axe_ruban(axe, ch / 2.0)
            if net:
                index.append((d["fid"], ch / 2.0, net))
        axes[d["fid"]] = morceaux
    return axes, index


def _dans_chaussee(p, index, marge=0.0):
    """Vrai si le point — marge comprise — tombe dans une chaussée."""
    for _, demi, axe in index:
        if any(D4C.dist_pt_seg(p, a, b) <= demi + marge
               for a, b in zip(axe, axe[1:])):
            return True
    return False


def _onglets(net):
    """Les vecteurs d'ONGLET d'une polyligne : le point à la distance latérale
    `w` du sommet `i` est `net[i] + onglets[i] * w`, et deux arêtes voisines
    décalées de `w` se rejoignent dessus au lieu de se croiser.

    Sa longueur vaut 1/cos(demi-angle), donc il s'envole quand la cassure
    approche 180° — d'où l'écrêtage. Les arcs, eux, ne cassent que de
    PAS_ARC_DEG.

    🔄 SORTI DE `_ruban` LE 2026-08-18, quand le mur de quai est arrivé. Le mur
    doit s'appuyer exactement sur le bord de l'asphalte ; un second calcul de
    décalage aurait dérivé au premier changement, et une fente de deux
    centimètres entre une chaussée et son mur, c'est un trait de vide sur toute
    la longueur du quai."""
    n = len(net)
    dec = []
    for i in range(n):
        ua = _unite(net[i - 1], net[i]) if i > 0 else None
        ub = _unite(net[i], net[i + 1]) if i < n - 1 else None
        ua = ua or ub
        ub = ub or ua
        na, nb = (-ua[1], ua[0]), (-ub[1], ub[0])
        d = 1.0 + na[0] * nb[0] + na[1] * nb[1]
        if d < 1e-6:
            mx, my = na
        else:
            mx, my = (na[0] + nb[0]) / d, (na[1] + nb[1]) / d
            L = math.hypot(mx, my)
            if L > LIMITE_MITRE_RUBAN:
                mx, my = mx / L * LIMITE_MITRE_RUBAN, my / L * LIMITE_MITRE_RUBAN
        dec.append((mx, my))
    return dec


def _ruban(m, pts, larg, coul, G, y=None, decal=0.0, bouts=True):
    """Un ruban le long d'une polyligne, joints en ONGLET.

    La chaussée s'en sert, et depuis le 2026-08-18 le MARQUAGE aussi :
    une ligne blanche est un ruban de 15 cm, une bande de passage piéton
    un ruban de 50 cm. `decal` la pousse latéralement (ligne de rive),
    `bouts` désactive la rallonge de remplissage des carrefours — une
    ligne qui se rallongerait toute seule déborderait dans le carrefour
    qu'on vient justement de lui interdire.

    🔄 ELLE ÉMETTAIT UN QUADRILATÈRE PAR SEGMENT, chacun rallongé d'une
    demi-largeur pour que les carrefours se remplissent au lieu d'afficher une
    croix pâle. Sur une droite c'est exactement la même chose ; sur un ARC,
    les rallonges débordaient de la courbe et le bord sortait en dents de
    scie. Les deux BOUTS gardent la rallonge — c'est elle qui remplit les
    carrefours, et là on la veut.

    🔄 ET ELLE ÉTAIT ÉCLAIRÉE À L'ENVERS. Toutes ses normales pointaient vers
    le BAS — mesuré : 3 060 triangles sur 3 060 —, donc la ville roulait sur
    un asphalte qui ne recevait que la lumière ambiante. Le sol des îlots,
    lui, était dans le bon sens depuis toujours : d'où l'écart de valeur entre
    une rue et une cour, qu'on prenait pour un choix de palette.

    🔄 Elle était aussi découpée tous les 20 m pour suivre la pente. La carte
    étant plate, elle reste à 0 sur toute sa longueur — et au-dessus du chenal
    elle passe donc au-dessus du vide. C'est ça, le pont : aucune ligne de
    code du projet ne parle de tablier."""
    h = larg / 2.0
    if y is None:
        y = Y_CHAUSSEE
    net = _axe_ruban(pts, h, bouts)
    if len(net) < 2:
        return 0

    n = len(net)
    dec = _onglets(net)

    # `dec` est l'ONGLET UNITAIRE : le bord gauche est à `decal - h` le long de
    # lui, le droit à `decal + h`. Sans décalage on retombe sur ±h, donc sur la
    # chaussée centrée d'avant.
    for i in range(n - 1):
        g0 = (net[i][0] + dec[i][0] * (decal - h),
              net[i][1] + dec[i][1] * (decal - h))
        d0 = (net[i][0] + dec[i][0] * (decal + h),
              net[i][1] + dec[i][1] * (decal + h))
        g1 = (net[i + 1][0] + dec[i + 1][0] * (decal - h),
              net[i + 1][1] + dec[i + 1][1] * (decal - h))
        d1 = (net[i + 1][0] + dec[i + 1][0] * (decal + h),
              net[i + 1][1] + dec[i + 1][1] * (decal + h))
        # Sens TRIGONOMÉTRIQUE dans le repère source : après G(), qui inverse
        # Z, il donne une normale vers le HAUT. C'est ce que `_sol` fait
        # depuis toujours, et c'est ce que la chaussée ne faisait pas.
        m.triangle(G(g0[0], g0[1], y), G(g1[0], g1[1], y),
                   G(d1[0], d1[1], y), coul)
        m.triangle(G(g0[0], g0[1], y), G(d1[0], d1[1], y),
                   G(d0[0], d0[1], y), coul)
    return 2 * (n - 1)


# --------------------------------- le bord de l'eau : le quai porté et le pont

def _densifier(pts, pas):
    """La même polyligne, avec un sommet au moins tous les `pas` mètres.

    Le mur de quai a besoin d'un débit plus fin que la chaussée : sa distance à
    l'axe CHANGE le long de la rue (il colle à la berge là où elle est dehors,
    au bord de l'asphalte là où elle est dessous), et une variation ne peut se
    lire qu'entre deux sommets."""
    out = [pts[0]]
    for a, b in zip(pts, pts[1:]):
        L = math.hypot(b[0] - a[0], b[1] - a[1])
        k = max(1, int(math.ceil(L / pas)))
        for j in range(1, k + 1):
            out.append((a[0] + (b[0] - a[0]) * j / k,
                        a[1] + (b[1] - a[1]) * j / k))
    return out


def _stations_eau(net, dec, h, chenal, relief=None):
    """Le bord de l'asphalte est-il au-dessus de l'eau, à gauche et à droite ?

    Une seule question, et elle suffit : c'est elle qui dit qui TRAVERSE. Sous
    les deux bords, la rue franchit et prend un pont ; sous un seul, elle longe
    — et ce cas-là ne se décide plus ici depuis le 2026-08-19, mais dans
    `_quais`, à partir de la berge.

    ⏸️ CETTE FONCTION FAISAIT SIX FOIS PLUS. Elle tirait un rayon vers la
    rivière (`_ray_berge`), cherchait la berge la plus proche du bon côté
    (`_berge_proche`), mesurait l'écart latéral à l'eau, l'angle de la rue à la
    berge (`QUAI_COS`), et comptait les rives vues mais non bordées
    (`QUAI_VUE`). Tout cela servait à poser un mur DEPUIS LA ROUTE ; le mur
    part maintenant de la berge, où aucune de ces approximations n'est
    nécessaire — la berge, elle, sait où elle est. `relief` reste dans la
    signature pour ne pas changer les deux appels ; il ne sert plus."""
    return [{"p": p, "dec": dec[i],
             "cotes": {cote: {"mouille": chenal.dans_eau(
                 (p[0] + dec[i][0] * cote * h, p[1] + dec[i][1] * cote * h))}
                 for cote in (1, -1)}}
            for i, p in enumerate(net)]


def _plages(drapeaux):
    """Les plages [i0, i1] où le drapeau est vrai, bornes comprises."""
    out, i, n = [], 0, len(drapeaux)
    while i < n:
        if not drapeaux[i]:
            i += 1
            continue
        j = i
        while j + 1 < n and drapeaux[j + 1]:
            j += 1
        out.append((i, j))
        i = j + 1
    return out


def _combler(drapeaux):
    """Rebouche les trous d'UNE seule station. Un rayon peut manquer la berge au
    sommet exact où deux arêtes se rejoignent : sans ce rebouchage, le mur se
    coupe en deux sur deux mètres et il faut aller chercher pourquoi à l'écran."""
    for i in range(1, len(drapeaux) - 1):
        if drapeaux[i - 1] and drapeaux[i + 1]:
            drapeaux[i] = True
    return drapeaux


def _longueur(net, i0, i1):
    return sum(math.hypot(net[i + 1][0] - net[i][0], net[i + 1][1] - net[i][1])
               for i in range(i0, i1))


def _etendre(net, i0, i1, marge):
    """La plage allongée de `marge` mètres de chaque côté, sans sortir."""
    a = i0
    while a > 0 and _longueur(net, a - 1, i0) <= marge:
        a -= 1
    b = i1
    while b < len(net) - 1 and _longueur(net, i1, b + 1) <= marge:
        b += 1
    return a, b


def _bande3d(m, A, B, coul, G, vers):
    """La surface réglée entre deux polylignes de même longueur, en (x, y, alt).

    ⚠️ LE SENS DE PARCOURS EST MESURÉ, PAS SUPPOSÉ. Le mur d'un quai de rive
    gauche se parcourt à l'envers de celui d'une rive droite, et une face à
    l'envers est cullée : le mur disparaît, et le trou ne se voit qu'à l'écran.
    On calcule donc la normale du premier quad et on retourne toute la bande si
    elle ne regarde pas où on lui demande.

    `vers` est donné dans le repère GODOT : l'inversion de Z change la
    chiralité, donc raisonner dans le repère source se paierait deux fois."""
    quads = []
    for i in range(len(A) - 1):
        a0, a1, b1, b0 = A[i], A[i + 1], B[i + 1], B[i]
        # Un quad écrasé arrive pour de bon : la bande de quai est de largeur
        # nulle là où la berge est déjà dehors. Deux triangles d'aire nulle
        # donnent une normale arbitraire et une arête qui scintille.
        if (math.hypot(a0[0] - b0[0], a0[1] - b0[1]) < 0.02
                and math.hypot(a1[0] - b1[0], a1[1] - b1[1]) < 0.02
                and abs(a0[2] - b0[2]) < 0.02 and abs(a1[2] - b1[2]) < 0.02):
            continue
        if (math.hypot(a0[0] - a1[0], a0[1] - a1[1]) < 1e-6
                and math.hypot(b0[0] - b1[0], b0[1] - b1[1]) < 1e-6):
            continue
        quads.append((a0, a1, b1, b0))
    if not quads:
        return 0
    a0, a1, b1, b0 = quads[0]
    nn = normale(G(*a0), G(*a1), G(*b1))
    if nn[0] * vers[0] + nn[1] * vers[1] + nn[2] * vers[2] < 0.0:
        quads = [(q[3], q[2], q[1], q[0]) for q in quads]
    for a0, a1, b1, b0 in quads:
        m.triangle(G(*a0), G(*a1), G(*b1), coul)
        m.triangle(G(*a0), G(*b1), G(*b0), coul)
    return 2 * len(quads)


def _boite(m, c, u, long_u, long_v, y_bas, y_haut, coul, G):
    """Une boîte posée à plat, alignée sur `u` : quatre murs et un chapeau.

    C'est la forme d'une souche de cheminée comme d'une pile de pont — un
    parallélépipède orienté. `_cheminee` s'en sert avec sa taille à elle."""
    ux, uy = u
    vx, vy = -uy, ux
    a, b = long_u / 2.0, long_v / 2.0
    coins = [(c[0] + ux * sa * a + vx * sb * b,
              c[1] + uy * sa * a + vy * sb * b)
             for sa, sb in ((-1, -1), (1, -1), (1, 1), (-1, 1))]
    if aire_signee(coins) < 0.0:
        coins.reverse()
    n = 0
    for i in range(4):
        p, q = coins[i], coins[(i + 1) % 4]
        m.triangle(G(p[0], p[1], y_bas), G(q[0], q[1], y_bas),
                   G(q[0], q[1], y_haut), coul)
        m.triangle(G(p[0], p[1], y_bas), G(q[0], q[1], y_haut),
                   G(p[0], p[1], y_haut), coul)
        n += 2
    for ia, ib, ic in trianguler(coins):
        p, q, r = coins[ia], coins[ib], coins[ic]
        m.triangle(G(p[0], p[1], y_haut), G(q[0], q[1], y_haut),
                   G(r[0], r[1], y_haut), coul)
        n += 1
    return n


def _parapet(m, ext, inte, dehors, coul, coul_chap, G, y_bas=Y_SOL):
    """LE MURET DE 1 M ENTRE LA ROUTE ET L'EAU — le mur que l'auteur a demandé.

    Trois surfaces, et une seule recette pour le quai comme pour le pont : la
    face extérieure, le chaperon, la face intérieure. Ses deux bouts sont
    fermés — 40 cm sur 1 m, c'est peu, mais un parapet de pont finit en l'air
    sur sa culée et on verrait le jour à travers.

    Le chaperon est plus clair que le corps : vu d'en haut, c'est LUI qui dit
    qu'il y a une barrière. Un muret d'une seule teinte se confond avec le mur
    de quai qu'il surmonte, et la ville retrouve un bord d'eau franc — ce qu'on
    est justement en train de corriger."""
    y_h = y_bas + PARAPET_H
    n = _bande3d(m, [(p[0], p[1], y_h) for p in ext],
                 [(p[0], p[1], y_bas) for p in ext], coul, G, dehors)
    n += _bande3d(m, [(p[0], p[1], y_h) for p in inte],
                  [(p[0], p[1], y_bas) for p in inte], coul, G,
                  (-dehors[0], -dehors[1], -dehors[2]))
    n += _bande3d(m, [(p[0], p[1], y_h) for p in ext],
                  [(p[0], p[1], y_h) for p in inte], coul_chap, G, (0.0, 1.0, 0.0))
    for k in (0, -1):
        u = _unite(ext[1], ext[0]) if k == 0 else _unite(ext[-2], ext[-1])
        if u is None:
            continue
        n += _bande3d(m, [(ext[k][0], ext[k][1], y_h),
                          (inte[k][0], inte[k][1], y_h)],
                      [(ext[k][0], ext[k][1], y_bas),
                       (inte[k][0], inte[k][1], y_bas)],
                      coul, G, (u[0], 0.0, -u[1]))
    return n


def _axe_ampute(axe, chenal, marge=PONT_COUPE_MARGE):
    """L'axe d'un pont EMPORTÉ (04e) : ce qu'il en reste de part et d'autre.

    On retire le trajet au-dessus de l'eau, plus `marge` de chaque côté, et on
    rend les morceaux. Un axe amputé n'a plus ses deux bords mouillés en même
    temps, donc `_plages_pont` n'y voit plus d'ouvrage : ni tablier, ni parapet,
    ni pile ne sortent — le vide est celui du tablier, pas seulement de
    l'asphalte. C'est ce qui économise toute chirurgie dans `_bord_eau`.

    ⚠️ Rend une liste, pas un axe : appelé partout où l'axe entier l'était,
    donc TOUJOURS dans une boucle. Un morceau de moins de deux points est jeté.
    """
    dense = _densifier(list(axe), 1.0)
    mouille = [chenal.dans_eau(p) for p in dense]
    if not any(mouille):
        return [list(axe)]
    cum = _cumul(dense)
    s0 = min(cum[k] for k in range(len(dense)) if mouille[k]) - marge
    s1 = max(cum[k] for k in range(len(dense)) if mouille[k]) + marge
    out = []
    for a, b in ((0.0, s0), (s1, cum[-1])):
        if b - a < 1.0:
            continue
        bout = _tronquer(dense, cum, max(0.0, a), min(cum[-1], b))
        if len(bout) >= 2:
            out.append(bout)
    return out


def _axe_manque(axe, chenal, marge=PONT_COUPE_MARGE):
    """Le morceau que `_axe_ampute` a retiré — donc exactement ce qu'il faudra
    rebâtir. Les deux lisent la MÊME marge : sinon le tablier neuf ne
    retomberait pas sur les deux bouts de chaussée qui l'attendent."""
    dense = _densifier(list(axe), 1.0)
    mouille = [chenal.dans_eau(p) for p in dense]
    if not any(mouille):
        return []
    cum = _cumul(dense)
    s0 = min(cum[k] for k in range(len(dense)) if mouille[k]) - marge
    s1 = max(cum[k] for k in range(len(dense)) if mouille[k]) + marge
    bout = _tronquer(dense, cum, max(0.0, s0), min(cum[-1], s1))
    return bout if len(bout) >= 2 else []


def _pont_neuf(m, axe, larg, ch, coul_tab, coul_ch, coul_par, G):
    """LE TABLIER QU'ON REBÂTIT : une dalle, sa chaussée, deux parapets pleins.

    C'est la seule géométrie du projet qui apparaisse EN COURS DE PARTIE, et
    elle est volontairement simple — ce n'est pas le pont d'avant, c'est un
    ouvrage neuf, et ça se voit. Les deux autres franchissements tiennent leur
    muret de `_bord_eau`, qui travaille sur la berge et ne sait rien
    reconstruire au-dessus du vide.
    """
    n = _ruban(m, axe, larg, coul_tab, G, y=Y_CHAUSSEE)
    # 2 cm plus haut, pas au même millimètre : deux surfaces coplanaires se
    # battent en duel sur toute la longueur du tablier.
    n += _ruban(m, axe, ch, coul_ch, G, y=Y_CHAUSSEE + 0.02)
    demi = larg / 2.0 - PARAPET_EP / 2.0
    for k in range(len(axe) - 1):
        a, b = axe[k], axe[k + 1]
        dx, dy = b[0] - a[0], b[1] - a[1]
        L = math.hypot(dx, dy)
        if L < 0.5:
            continue
        u = (dx / L, dy / L)
        for signe in (-1.0, 1.0):
            c = ((a[0] + b[0]) / 2.0 - u[1] * signe * demi,
                 (a[1] + b[1]) / 2.0 + u[0] * signe * demi)
            n += _boite(m, c, u, L, PARAPET_EP, Y_CHAUSSEE,
                        Y_CHAUSSEE + PARAPET_H, coul_par, G)
    return n


def _pont_ruine(m, axe, larg, ch, coul_tab, coul_ch, coul_par, G):
    """Ce que le courant laisse : un moignon affaissé depuis chaque culée."""
    cum = _cumul(axe)
    if not cum or cum[-1] < 2.0:
        return 0
    bout = min(PONT_RUINE_BOUT, cum[-1] / 3.0)
    n = 0
    for a, b, casse_fin in ((0.0, bout, True),
                            (cum[-1] - bout, cum[-1], False)):
        morceau = _tronquer(axe, cum, a, b)
        casse = morceau[-1] if casse_fin else morceau[0]

        def G_casse(x, y, alt):
            d = math.hypot(x - casse[0], y - casse[1])
            chute = PONT_RUINE_CHUTE * max(0.0, 1.0 - d / 2.5)
            return G(x, y, alt - chute)

        n += _pont_neuf(m, morceau, larg, ch, coul_tab, coul_ch,
                        coul_par, G_casse)
    return 2


def _plages_pont(net, st):
    """Les plages [a, b, i0, i1] où la chaussée TRAVERSE vraiment : les deux
    bords au-dessus de l'eau, sur au moins `PONT_MIN`, étendues des culées.

    🔴 SORTIE DE `_bord_eau` LE 2026-08-19, et ce n'est pas du rangement : le
    quai a besoin de savoir où sont les tabliers AVANT que la boucle des routes
    ne commence à émettre, pour ne pas bâtir un muret sous un pont. Deux copies
    de cette décision auraient dérivé dès le premier réglage."""
    pont = _combler([c["cotes"][1]["mouille"] and c["cotes"][-1]["mouille"]
                     for c in st])
    plages = []
    for i0, i1 in _plages(pont):
        if _longueur(net, i0, i1) < PONT_MIN:
            continue                    # une amorce de rue, pas un ouvrage
        a, b = _etendre(net, i0, i1, PONT_CULEE)
        plages.append((a, b, i0, i1))
    return plages


def _tabliers(axe, ch, chenal, relief):
    """Les emprises des tabliers de cette part de tronçon, sans rien émettre.

    Mêmes polygones que ceux que `_bord_eau` rangera dans `plateformes` — c'est
    la même recette lue deux fois, pas deux recettes."""
    h = ch / 2.0
    net = _densifier(_axe_ruban(axe, h, True), QUAI_PAS)
    if len(net) < 2:
        return []
    dec = _onglets(net)
    st = _stations_eau(net, dec, h, chenal, relief)
    out = []
    for a, b, _i0, _i1 in _plages_pont(net, st):
        cotes = {}
        for cote in (1, -1):
            cotes[cote] = [(net[k][0] + dec[k][0] * cote * (h + BANDE_QUAI),
                            net[k][1] + dec[k][1] * cote * (h + BANDE_QUAI))
                           for k in range(a, b + 1)]
        out.append(list(cotes[1]) + list(reversed(cotes[-1])) + [cotes[1][0]])
    return out


def _chaines_berge(chenal):
    """Les arêtes de berge recousues en polylignes continues, dans le sens de
    l'anneau d'îlot dont elles sortent — donc **l'eau est toujours à gauche**.

    C'est la seule chose que `Chenal` ne savait pas faire : il donne un SAC
    d'arêtes, indexé pour la recherche par boîte, et un sac ne se longe pas.
    Sans ce recousage, un mur de quai ne peut être que le décalé d'autre chose
    — et c'est exactement le défaut qu'on répare.

    ⚠️ LE SENS EST HÉRITÉ, PAS DEVINÉ. `_chenal_eau` prouve déjà que la normale
    à gauche du parcours regarde l'eau (contrôle « murs de quai, tous tournés
    vers l'eau »). On ne le recalcule donc pas ici : on garde l'ordre des
    arêtes tel que l'anneau les a produites."""
    par_debut = {}
    for k, (a, _b) in enumerate(chenal.berges):
        par_debut.setdefault(_cle(a), []).append(k)
    # Un sommet où AUCUNE arête n'arrive est un vrai début de chaîne : la rive
    # y bute sur le bord de la carte, ou sur une arête interne à l'eau qui a
    # été écartée. Les prendre d'abord évite de couper une rive en deux au
    # milieu, ce qui remettrait un bout franc là où il n'y a rien.
    fins = {_cle(b) for (_a, b) in chenal.berges}
    depart = [k for k, (a, _b) in enumerate(chenal.berges)
              if _cle(a) not in fins]
    libre = set(range(len(chenal.berges)))
    chaines = []
    for k0 in depart + list(range(len(chenal.berges))):
        if k0 not in libre:
            continue
        libre.discard(k0)
        a, b = chenal.berges[k0]
        chaine = [a, b]
        while True:
            suite = [k for k in par_debut.get(_cle(chaine[-1]), ())
                     if k in libre]
            if not suite:
                break
            libre.discard(suite[0])
            chaine.append(chenal.berges[suite[0]][1])
        chaines.append(chaine)
    return chaines


class GrilleChaussee(object):
    """Les segments de chaussée rangés en cases de 8 m, pour répondre vite à
    « y a-t-il de l'asphalte ici, et à quel tronçon ».

    `_dans_chaussee` balaie les 430 rubans à chaque appel : la sonde du mur de
    quai en fait ~75 000, et sans grille l'export y passerait plus de temps
    qu'à tout le reste."""

    PAS = 8.0

    def __init__(self, index):
        self.seg = []
        self.idx = {}
        for fid, demi, axe in index:
            for a, b in zip(axe, axe[1:]):
                k = len(self.seg)
                self.seg.append((fid, demi, a, b))
                for cx in range(int((min(a[0], b[0]) - demi) // self.PAS),
                                int((max(a[0], b[0]) + demi) // self.PAS) + 1):
                    for cy in range(int((min(a[1], b[1]) - demi) // self.PAS),
                                    int((max(a[1], b[1]) + demi) // self.PAS) + 1):
                        self.idx.setdefault((cx, cy), []).append(k)

    def dessus(self, p, long_de=None):
        """Le `fid` de la chaussée sous `p`, ou None.

        🔴 `long_de` EST TOUT L'INTÉRÊT DE CETTE MÉTHODE, et c'est lui qui
        empêche le quai de festonner. Au carrefour, la chaussée d'une rue
        PERPENDICULAIRE se rallonge d'une demi-largeur pour remplir le
        croisement, et ce carré d'asphalte de 7 m passe au-dessus de l'eau. Sans
        ce filtre, la sonde le trouve, le mur s'avance pour le porter, et le
        quai part en festons dans la rivière — vu à l'écran le 2026-08-19, en
        pire que le défaut qu'on réparait. Une rue qui TRAVERSE n'a pas à
        déplacer le bord de l'eau : son amorce reste derrière le parapet du
        quai, comme avant, et le contrôle de l'asphalte en l'air le dit."""
        for k in self.idx.get((int(p[0] // self.PAS), int(p[1] // self.PAS)), ()):
            fid, demi, a, b = self.seg[k]
            if D4C.dist_pt_seg(p, a, b) > demi:
                continue
            if long_de is not None:
                u = _unite(a, b)
                if u is None or abs(u[0] * long_de[1]
                                    - u[1] * long_de[0]) > QUAI_LONGE_SIN:
                    continue
            return fid
        return None


def _debord_asphalte(p, w, t, grille):
    """(débord, tronçon) à cette station de berge — le débord compté DEPUIS LA
    BERGE, positif vers l'eau.

    Trois réponses possibles, et ce sont elles qui décident de tout :
      · un nombre POSITIF — l'asphalte déborde sur l'eau. Le mur devra s'avancer
        d'autant pour le porter ;
      · un nombre NÉGATIF — la chaussée s'arrête en deçà de la berge. Le mur se
        pose sur la berge, et il n'y a rien à porter ;
      · None — aucune chaussée à `QUAI_PORTEE` de là. Ce n'est pas un quai :
        c'est une rive de campagne, et elle n'a que faire d'un muret.

    ⚠️ ON SONDE CÔTÉ EAU D'ABORD, ET ON S'ARRÊTE AU PREMIER TROU. Prendre le
    point le plus loin sans exiger la continuité ferait mordre le quai sur la
    chaussée d'en face, à travers la rivière."""
    d, debord, fid = 0.0, None, None
    while d <= QUAI_DEBORD_MAX:
        f = grille.dessus((p[0] + w[0] * d, p[1] + w[1] * d), t)
        if f is None:
            break
        debord, fid = d, f
        d += QUAI_SONDE
    if debord is not None:
        return debord, fid
    # 🔴 LE REPLI ACCEPTE N'IMPORTE QUELLE RUE, et il le faut. Au débouché
    # d'une perpendiculaire, la rue de quai s'arrête et c'est l'amorce de
    # l'autre qui touche l'eau : avec le filtre « longe » ici aussi, le mur se
    # coupait à chaque carrefour — un trou de parapet tous les 60 m, et
    # l'asphalte de l'amorce par-dessus. Ce qui décide de l'AVANCÉE du mur doit
    # longer ; ce qui décide qu'il y a un QUAI ici, non.
    d = 0.0
    while d <= QUAI_PORTEE:
        f = grille.dessus((p[0] - w[0] * d, p[1] - w[1] * d))
        if f is not None:
            return -d, f
        d += QUAI_SONDE
    return None, None


def _boites(polys):
    """Chaque polygone avec sa boîte englobante. Le test d'appartenance sert
    deux fois (le quai cherche les tabliers, le pont cherche les quais) et
    `dedans` coûte un parcours complet de l'anneau : la boîte élimine 99 % des
    candidats en quatre comparaisons."""
    return [(min(q[0] for q in poly), min(q[1] for q in poly),
             max(q[0] for q in poly), max(q[1] for q in poly), poly)
            for poly in polys]


def _dans_boites(p, boites):
    return any(x0 <= p[0] <= x1 and y0 <= p[1] <= y1 and dedans(poly, p)
               for x0, y0, x1, y1, poly in boites)


def _bascule(pa, pb, test, tours=6):
    """La fraction de [pa, pb] où `test` cesse d'être vrai — `test(pa)` vrai,
    `test(pb)` faux. Six dichotomies ramènent l'erreur à 1/64 du pas.

    ⚠️ SANS ELLE, LE BOUT DU PARAPET D'UN PONT TOMBE À LA STATION, donc à 2 m
    près : ou bien il s'arrête 2 m avant le nu du quai et il reste un trou au
    coin, ou bien il le dépasse de 2 m et il remonte sur la voie de berge —
    c'est-à-dire exactement le défaut qu'on répare."""
    lo, hi = 0.0, 1.0
    for _ in range(tours):
        mi = (lo + hi) / 2.0
        if test((pa[0] + (pb[0] - pa[0]) * mi, pa[1] + (pb[1] - pa[1]) * mi)):
            lo = mi
        else:
            hi = mi
    return lo


def _entre(pa, pb, t):
    return (pa[0] + (pb[0] - pa[0]) * t, pa[1] + (pb[1] - pa[1]) * t)


def _quais(chenal, relief, grille, tabliers):
    """LE QUAI, TENU PAR LA BERGE — le PLAN, pas l'émission.

    Renvoie (plan, compte, plateformes, murs), où `plan` est
    `{fid: [morceau, ...]}`. Une passe unique, lancée AVANT la boucle des
    routes : une berge ne sait pas à quel tronçon elle appartient, et le
    morceau qui la borde doit tomber dans le GROUPE de ce tronçon — sans quoi
    la rue aurait deux nœuds dans Godot, et les calques thématiques n'en
    repeindraient qu'un.

    L'ordre : on recoud les berges, on demande à chaque station ce que
    l'asphalte fait par ici, on lisse le nu du mur, on découpe par tronçon."""
    st = {"quai_m": 0.0, "avance_m": 0.0, "parapet_m": 0.0, "talus": 0,
          "campagne": 0, "tablier": 0, "morceaux": 0, "runs": 0}
    plan, murs, plateformes = {}, [], []
    boites = _boites(tabliers)

    def sous_tablier(p):
        return _dans_boites(p, boites)

    for chaine in _chaines_berge(chenal):
        net = _densifier(chaine, QUAI_PAS)
        n = len(net)
        if n < 3:
            continue
        # La normale EAU de chaque station. Pas d'onglet ici : la berge n'est
        # pas un ruban à décaler d'une largeur constante, et un onglet
        # s'envolerait au premier angle droit de la rive.
        eau = []
        for i in range(n):
            u = _unite(net[max(0, i - 1)], net[min(n - 1, i + 1)]) or (1.0, 0.0)
            eau.append((-u[1], u[0]))
        prendre = [False] * n
        bord = [0.0] * n
        off = [0.0] * n
        fids = [None] * n
        sous = [False] * n
        for i, p in enumerate(net):
            if sous_tablier(p):
                sous[i] = True
                st["tablier"] += 1
                continue
            # 🌾 Une berge de champ descend à 22 % jusqu'à l'eau : un muret
            # planté au milieu de cette pente ne serait ni une barrière ni un
            # quai. La ville tient la rive avec un mur, la campagne avec un
            # talus — c'est déjà la règle du creusement.
            if relief is not None and relief.z(p[0], p[1]) < -0.20:
                st["talus"] += 1
                continue
            d, f = _debord_asphalte(p, eau[i], (-eau[i][1], eau[i][0]),
                                    grille)
            if d is None:
                st["campagne"] += 1
                continue
            prendre[i] = True
            bord[i] = d
            fids[i] = f
            # Le nu du mur : le débord de l'asphalte, plus la bande. Négatif,
            # il retombe à zéro — le mur se pose alors sur la berge elle-même,
            # et c'est le mur du chenal qui fait la paroi.
            off[i] = max(0.0, d + BANDE_QUAI)
        _combler(prendre)
        # ⚠️ LA CORDE PEND. Entre deux stations de berge (2 m), le mur est une
        # droite alors que le bord de l'asphalte, lui, tourne : quatre quais en
        # courbe laissaient ainsi 16 m² d'asphalte dépasser d'un mètre. Chaque
        # station prend donc le débord de ses voisines — c'est la corde qui se
        # place sur la flèche, et non l'inverse.
        large = list(off)
        for i in range(n):
            if prendre[i]:
                off[i] = max(large[max(0, i - 1)], large[i],
                             large[min(n - 1, i + 1)])
        # 🌉 LE QUAI GLISSE SOUS LE TABLIER, de deux stations. Sans ça il
        # s'arrête au ras du pont et il reste, entre son bout et la culée, un
        # coin d'asphalte qui dépasse le parapet de 1,5 m — mesuré sur les
        # tronçons 97, 101, 128 et 146. On ne prolonge QUE sous un tablier :
        # prolonger dans un talus de champ y planterait un muret.
        for i0, i1 in _plages(prendre):
            for pas_, bout in ((-1, i0), (1, i1)):
                k = bout
                for _ in range(2):
                    j = k + pas_
                    if not (0 <= j < n) or prendre[j] or not sous[j]:
                        break
                    prendre[j] = True
                    bord[j] = bord[k]
                    off[j] = off[k]
                    fids[j] = fids[k]
                    k = j
        for i0, i1 in _plages(prendre):
            if _longueur(net, i0, i1) < 4.0:
                continue
            st["runs"] += 1
            # L'ÉPAULEMENT : le nu ne peut pas sauter d'une station à l'autre.
            for i in range(i0 + 1, i1 + 1):
                off[i] = max(off[i], off[i - 1] - QUAI_PENTE)
            for i in range(i1 - 1, i0 - 1, -1):
                off[i] = max(off[i], off[i + 1] - QUAI_PENTE)
            _decouper_quai(net, eau, off, bord, fids, sous, i0, i1,
                           plan, st, murs, plateformes)
    return plan, st, plateformes, murs


def _decouper_quai(net, eau, off, bord, fids, sous, i0, i1, plan, st, murs,
                   plateformes):
    """Une longueur de quai découpée en morceaux à `fid` constant.

    🔴 LE DÉCOUPAGE NE COUPE QUE LE MAILLAGE, JAMAIS LA LIGNE. Les morceaux
    sont taillés dans les mêmes tableaux, en partageant leur station de
    frontière : deux voisins ont donc les mêmes sommets au millimètre, et le
    joint ne se voit pas. C'est ce qui permet de garder un parapet cliquable —
    cliquer un muret ouvre la fiche de la rue — sans revenir aux 21 bouts de
    mur qu'on vient de supprimer."""
    ext = [(net[i][0] + eau[i][0] * off[i], net[i][1] + eau[i][1] * off[i])
           for i in range(i0, i1 + 1)]
    inte = [(net[i][0] + eau[i][0] * (off[i] - PARAPET_EP),
             net[i][1] + eau[i][1] * (off[i] - PARAPET_EP))
            for i in range(i0, i1 + 1)]
    # Le couronnement ne commence qu'où le sol s'arrête : sous l'asphalte il
    # n'y a rien à couvrir, et par-dessus la plaque de sol deux surfaces au même
    # millimètre se battraient en duel.
    interieur = [(net[i][0] + eau[i][0] * max(0.0, min(bord[i], off[i])),
                  net[i][1] + eau[i][1] * max(0.0, min(bord[i], off[i])))
                 for i in range(i0, i1 + 1)]
    # La plateforme sert au contrôle de l'asphalte en l'air : ce qu'elle couvre
    # est porté. Côté terre elle mord 2 m au-delà de la berge, ce qui ne coûte
    # rien — l'asphalte de ce côté-là n'est pas au-dessus de l'eau.
    arriere = [(net[i][0] - eau[i][0] * 2.0, net[i][1] - eau[i][1] * 2.0)
               for i in range(i0, i1 + 1)]
    plateformes.append(list(arriere) + list(reversed(ext)) + [arriere[0]])
    for j in range(i1 - i0 + 1):
        murs.append((ext[j], eau[i0 + j]))
    st["quai_m"] += _longueur(net, i0, i1)

    coupes = [0]
    for j in range(1, i1 - i0 + 1):
        if fids[i0 + j] != fids[i0 + j - 1]:
            coupes.append(j)
    coupes.append(i1 - i0)
    for a, b in zip(coupes, coupes[1:]):
        if b <= a:
            continue
        st["morceaux"] += 1
        avance = []
        for j0, j1 in _plages([off[i0 + k] > 0.05 for k in range(a, b + 1)]):
            if j1 > j0:
                avance.append((j0, j1))
                st["avance_m"] += _longueur(net, i0 + a + j0, i0 + a + j1)
        # 🚧 PAS DE PARAPET SOUS UN TABLIER. Le quai glisse sous le pont pour
        # que rien ne dépasse entre les deux ; son MURET, lui, monte de 1 m et le
        # tablier n'est qu'à 1 cm au-dessus du couronnement — il traverserait la
        # chaussée du pont et poserait un crochet en travers, vu à l'écran le
        # 2026-08-19. Le couronnement et la paroi, eux, restent : ils sont
        # dessous, invisibles, et ce sont eux qui portent l'asphalte.
        garde_fou = [(j0, j1) for j0, j1
                     in _plages([not sous[i0 + k] for k in range(a, b + 1)])
                     if j1 > j0]
        st["parapet_m"] += sum(_longueur(net, i0 + a + j0, i0 + a + j1)
                               for j0, j1 in garde_fou)
        plan.setdefault(fids[i0 + a], []).append(
            (ext[a:b + 1], inte[a:b + 1], interieur[a:b + 1],
             (eau[i0 + a][0], 0.0, -eau[i0 + a][1]), avance, garde_fou))


def _emettre_quai(m, morceaux, coul_mur, coul_chap, G):
    """Les trois surfaces d'un morceau de quai : couronnement, paroi, parapet.
    Appelé DANS le groupe du tronçon, d'où le fait qu'il ne marque rien."""
    tri = 0
    for ext, inte, interieur, dehors, avance, garde_fou in morceaux:
        tri += _bande3d(m, [(p[0], p[1], Y_QUAI) for p in interieur],
                        [(p[0], p[1], Y_QUAI) for p in ext],
                        coul_mur, G, (0.0, 1.0, 0.0))
        # La paroi ne descend au fond QUE là où le mur s'est avancé sur l'eau.
        # Là où il est posé sur la berge, le mur de quai du chenal est déjà là,
        # à la même place : deux parois coplanaires, c'est du z-fighting sur
        # toute la longueur de l'Ilse.
        for j0, j1 in avance:
            tri += _bande3d(
                m, [(p[0], p[1], Y_QUAI) for p in ext[j0:j1 + 1]],
                [(p[0], p[1], FOND_ILSE) for p in ext[j0:j1 + 1]],
                coul_mur, G, dehors)
        for j0, j1 in garde_fou:
            tri += _parapet(m, ext[j0:j1 + 1], inte[j0:j1 + 1], dehors,
                            coul_mur, coul_chap, G, Y_QUAI)
    return tri


def _bord_eau(m, axe, ch, chenal, relief, coul_mur, coul_chap, G, quais=()):
    """Le quai porté et le pont, sur une part de tronçon. Renvoie un compte.

    L'ordre est celui du raisonnement : on relève ce que chaque station voit de
    l'eau, on décide QUI traverse et qui longe, et seulement ensuite on émet.
    Rien ici ne connaît le nom d'une rue ni le numéro d'un franchissement.

    `quais` : les plateformes de quai déjà planifiées, en boîtes. Elles ne
    servent qu'à savoir où le parapet du pont doit s'arrêter — voir plus bas."""
    st_out = {"pont": 0, "pont_m": 0.0, "pile": 0, "quai_m": 0.0,
              "parapet_m": 0.0, "parapet_coupe_m": 0.0, "sur_quai": 0.0,
              "bouts": 0, "tri": 0}
    ponts = []                  # (longueur, milieu) — pour le point de vue
    # (point du nu extérieur, normale sortante) : le contrôle s'en sert pour
    # dire de quel côté du mur tombe le peu d'asphalte qui reste en l'air.
    murs = []
    h = ch / 2.0
    # Le MÊME axe rallongé que la chaussée : le mur doit couvrir aussi les deux
    # bouts qui remplissent les carrefours, sinon il s'arrête avant l'asphalte.
    net = _densifier(_axe_ruban(axe, h, True), QUAI_PAS)
    if len(net) < 2:
        return st_out, [], ponts, murs
    dec = _onglets(net)
    st = _stations_eau(net, dec, h, chenal, relief)

    # ① QUI TRAVERSE : les deux bords au-dessus de l'eau, sur au moins PONT_MIN.
    plages = _plages_pont(net, st)
    garde = [False] * len(st)
    for a, b, _i0, _i1 in plages:
        for k in range(a, b + 1):
            garde[k] = True
    plateformes = []

    for a, b, i0, i1 in plages:
        st_out["pont"] += 1
        st_out["pont_m"] += _longueur(net, a, b)
        mil = net[(i0 + i1) // 2]
        ponts.append((_longueur(net, i0, i1), mil))
        cotes = {}
        for cote in (1, -1):
            cotes[cote] = [(net[k][0] + st[k]["dec"][0] * cote * (h + BANDE_QUAI),
                            net[k][1] + st[k]["dec"][1] * cote * (h + BANDE_QUAI))
                           for k in range(a, b + 1)]
        # la sous-face du tablier — la seule surface du projet qui regarde en bas
        st_out["tri"] += _bande3d(
            m, [(p[0], p[1], Y_TABLIER) for p in cotes[1]],
            [(p[0], p[1], Y_TABLIER) for p in cotes[-1]],
            coul_mur, G, (0.0, -1.0, 0.0))
        for cote in (1, -1):
            ligne = cotes[cote]
            u = st[a]["dec"]
            dehors = (u[0] * cote, 0.0, -u[1] * cote)
            # la joue du tablier : c'est elle qu'on voit depuis la rivière, et
            # c'est son ombre qui fait qu'un pont est un pont et non un ruban.
            st_out["tri"] += _bande3d(
                m, [(p[0], p[1], Y_SOL) for p in ligne],
                [(p[0], p[1], Y_TABLIER) for p in ligne], coul_mur, G, dehors)
            inte = [(net[k][0] + st[k]["dec"][0] * cote * (h + BANDE_QUAI - PARAPET_EP),
                     net[k][1] + st[k]["dec"][1] * cote * (h + BANDE_QUAI - PARAPET_EP))
                    for k in range(a, b + 1)]
            # la bande de tablier entre l'asphalte et le parapet : le trottoir
            # du pont, sans bordure — sur 70 cm elle ne mérite pas de marche.
            bord = [(net[k][0] + st[k]["dec"][0] * cote * h,
                     net[k][1] + st[k]["dec"][1] * cote * h)
                    for k in range(a, b + 1)]
            st_out["tri"] += _bande3d(
                m, [(p[0], p[1], Y_SOL) for p in bord],
                [(p[0], p[1], Y_SOL) for p in ligne], coul_mur, G, (0.0, 1.0, 0.0))
            # 🌉 LE PARAPET DU PONT S'ARRÊTE AU BORD DE L'EAU — demandé le
            # 2026-08-19 sur capture : « les murs des ponts sont encore dans
            # les routes des berges, ils doivent s'arrêter aux berges. »
            #
            # Il courait sur toute la plage, culées comprises, donc 2,5 m
            # au-delà de la berge GÉOMÉTRIQUE — et le bord de l'eau qu'on VOIT
            # est encore ~5 m plus loin dans la rivière, au nu du quai, parce
            # que la voie de berge y déborde son asphalte et que le mur s'est
            # avancé pour le porter. Le muret du pont finissait donc 7 m après
            # la rive apparente, en travers de la chaussée qui longe.
            #
            # La règle ne mesure plus rien : le parapet ne couvre que l'EAU
            # LIBRE — ni la terre, ni ce que le quai porte déjà. Là où le quai
            # s'arrête (une berge de campagne), c'est la rive qui le borne, et
            # le pont garde son retour de culée.
            libre = (lambda p: chenal.dans_eau(p)
                     and not _dans_boites(p, quais))
            garde_p = [libre(p) for p in ligne]
            st_out["parapet_coupe_m"] += _longueur(net, a, b)
            # Le partage des mètres coupés, pour le contrôle : ce qui montait
            # sur la TERRE (le retour de culée) et ce qui montait sur le QUAI —
            # c'est le second que l'auteur voit en travers de la voie de berge.
            st_out["sur_quai"] += sum(QUAI_PAS for k, p in enumerate(ligne)
                                      if not garde_p[k] and chenal.dans_eau(p))
            for j0, j1 in _plages(garde_p):
                if j1 <= j0:
                    continue
                ext_p, int_p = list(ligne[j0:j1 + 1]), list(inte[j0:j1 + 1])
                # Les deux bouts au millimètre, pas à la station : sinon un
                # trou de 2 m au coin du quai, ou 2 m de muret par-dessus.
                if j0 > 0:
                    t = _bascule(ligne[j0], ligne[j0 - 1], libre)
                    ext_p[0] = _entre(ligne[j0], ligne[j0 - 1], t)
                    int_p[0] = _entre(inte[j0], inte[j0 - 1], t)
                if j1 < len(ligne) - 1:
                    t = _bascule(ligne[j1], ligne[j1 + 1], libre)
                    ext_p[-1] = _entre(ligne[j1], ligne[j1 + 1], t)
                    int_p[-1] = _entre(inte[j1], inte[j1 + 1], t)
                st_out["tri"] += _parapet(m, ext_p, int_p, dehors,
                                          coul_mur, coul_chap, G)
                st_out["bouts"] += 1
                L_p = _cumul(ext_p)[-1]
                st_out["parapet_m"] += L_p
                st_out["parapet_coupe_m"] -= L_p
        plateformes.append(list(cotes[1]) + list(reversed(cotes[-1]))
                           + [cotes[1][0]])
        for cote in (1, -1):
            for j, k in enumerate(range(a, b + 1)):
                u = st[k]["dec"]
                Lu = math.hypot(u[0], u[1]) or 1.0
                murs.append((cotes[cote][j],
                             (u[0] * cote / Lu, u[1] * cote / Lu)))
        # ② LES PILES — une travée de 40 m d'un seul jet n'existe pas dans une
        # petite ville. Elles sont posées sur la partie MOUILLÉE, pas sur le
        # tablier entier : une pile sous une culée serait dans la terre.
        L = _longueur(net, i0, i1)
        k = max(0, int(math.ceil(L / TABLIER_TRAVEE)) - 1)
        for j in range(1, k + 1):
            s = L * j / (k + 1.0)
            d = 0.0
            idx = i0
            while idx < i1 and d + math.hypot(net[idx + 1][0] - net[idx][0],
                                              net[idx + 1][1] - net[idx][1]) < s:
                d += math.hypot(net[idx + 1][0] - net[idx][0],
                                net[idx + 1][1] - net[idx][1])
                idx += 1
            u = _unite(net[idx], net[min(idx + 1, len(net) - 1)]) or (1.0, 0.0)
            st_out["tri"] += _boite(
                m, net[idx], u, PILE_COTE,
                ch + 2.0 * BANDE_QUAI - 2.0 * PILE_RETRAIT,
                FOND_ILSE, Y_TABLIER, coul_mur, G)
            st_out["pile"] += 1

    # ⏸️ « ③ QUI LONGE » A QUITTÉ CETTE FONCTION LE 2026-08-19, et la remettre
    # ici serait revenir en arrière. Le mur de quai était construit ici même,
    # station par station le long de la chaussée, symétrique du pont : d'où un
    # mur qui suivait les évasements de carrefour et se coupait à chaque bout de
    # tronçon. Il se fait maintenant en une seule passe, à partir des berges
    # recousues, après toutes les routes — voir `_quais`.
    return st_out, plateformes, ponts, murs


def _asphalte_en_lair(routes, coudes, chenal, plateformes, murs,
                      morceaux=None, pas=0.75):
    """LE CONTRÔLE : combien d'asphalte reste au-dessus du vide, et s'il se voit.

    Il échantillonne toute la chaussée affichée, garde les points qui tombent
    dans le polygone de l'Ilse, et les range en trois familles :

      · PORTÉ      — posé sur un tablier ou sur un quai ;
      · DERRIÈRE   — en l'air, mais en deçà du nu du mur, donc masqué par le
                     parapet qui passe devant. Ce sont les ~35 amorces de rue
                     au débouché d'un quai : elles traversent, elles ne longent
                     pas, donc la règle ne leur donne pas de mur — et elles
                     finissent derrière celui du quai qu'elles rejoignent ;
      · AU-DELÀ    — en l'air ET au-delà du mur. Le seul chiffre qui se verrait
                     à l'écran, avec son dépassement maximal.

    7 212 m² volaient avant ce lot, sans distinction. Séparer les trois est ce
    qui permet de dire « ✅ » sans mentir : ce qui reste doit être AU-DELÀ, et
    négligeable.

    🔴 `morceaux` N'EST PAS UNE COMMODITÉ : sans lui, ce contrôle rebâtit l'axe
    depuis `routes` et mesure une chaussée QUI N'EST PLUS ÉMISE. Un pont emporté
    (04e) lui faisait alors annoncer 296 m² d'asphalte au-dessus du vide là où il
    n'y a plus rien du tout. Un contrôle qui mesure autre chose que ce qu'on
    affiche est pire qu'absent.
    """
    boites = []
    for poly in plateformes:
        xs = [q[0] for q in poly]
        ys = [q[1] for q in poly]
        boites.append((min(xs), min(ys), max(xs), max(ys), poly))
    # Une grille sur les stations de mur : sans elle, chaque échantillon les
    # compare une à une — 1 500 murs contre 15 000 points.
    GR = 8.0
    idx = {}
    for k, (q, n) in enumerate(murs):
        idx.setdefault((int(q[0] // GR), int(q[1] // GR)), []).append(k)

    total = cache = dela = depasse = 0.0
    for d in routes:
        larg = d["largeur_m"] or 0.0
        if larg <= 0.0:
            continue
        ch = min(D4.EMPRISE_CIRCULATION.get(d["hierarchie"], 8.5), larg)
        h = ch / 2.0
        for ip, part in enumerate(d["parts"]):
            # 🌊 Les morceaux RÉELLEMENT émis, pont emporté compris.
            for axe in (morceaux[d["fid"]][ip] if morceaux
                        else [_axe_arrondi(part, d["fid"], ip, coudes)]):
                net = _axe_ruban(axe, h)
                if len(net) < 2:
                    continue
                dec = _onglets(net)
                for i in range(len(net) - 1):
                    seg = math.hypot(net[i + 1][0] - net[i][0],
                                     net[i + 1][1] - net[i][1])
                    if seg < 1e-9:
                        continue
                    nk = max(1, int(math.ceil(seg / pas)))
                    nw = max(2, int(math.ceil(ch / pas)))
                    aire = (seg / nk) * (ch / nw)
                    for a in range(nk):
                        f = (a + 0.5) / nk
                        px = net[i][0] + (net[i + 1][0] - net[i][0]) * f
                        py = net[i][1] + (net[i + 1][1] - net[i][1]) * f
                        ux = dec[i][0] + (dec[i + 1][0] - dec[i][0]) * f
                        uy = dec[i][1] + (dec[i + 1][1] - dec[i][1]) * f
                        for b in range(nw):
                            w = -h + ch * (b + 0.5) / nw
                            q = (px + ux * w, py + uy * w)
                            if not chenal.dans_eau(q):
                                continue
                            total += aire
                            if any(x0 <= q[0] <= x1 and y0 <= q[1] <= y1
                                   and dedans(poly, q)
                                   for x0, y0, x1, y1, poly in boites):
                                continue
                            best = None
                            cx, cy = int(q[0] // GR), int(q[1] // GR)
                            for jx in (cx - 1, cx, cx + 1):
                                for jy in (cy - 1, cy, cy + 1):
                                    for k in idx.get((jx, jy), ()):
                                        mp = murs[k][0]
                                        dd = math.hypot(q[0] - mp[0], q[1] - mp[1])
                                        if best is None or dd < best[0]:
                                            best = (dd, k)
                            if best is None:
                                dela += aire
                                continue
                            mp, mn = murs[best[1]]
                            proj = (q[0] - mp[0]) * mn[0] + (q[1] - mp[1]) * mn[1]
                            if proj > 0.02:
                                dela += aire
                                depasse = max(depasse, proj)
                            else:
                                cache += aire
    return total, cache, dela, depasse


# ------------------------------------------------- le marquage au sol

def _cumul(pts):
    """Les abscisses curvilignes d'une polyligne : `cum[i]` = distance du
    départ au sommet i. C'est le repère de TOUT le marquage — les traits, les
    zones interdites et les passages piétons sont des intervalles dessus."""
    cum = [0.0]
    for i in range(1, len(pts)):
        cum.append(cum[-1] + math.hypot(pts[i][0] - pts[i - 1][0],
                                        pts[i][1] - pts[i - 1][1]))
    return cum


def _le_long(pts, cum, s):
    """Le point à l'abscisse `s`, et la direction unitaire locale."""
    s = max(0.0, min(cum[-1], s))
    i = 0
    while i < len(cum) - 2 and cum[i + 1] < s:
        i += 1
    t = (s - cum[i]) / max(cum[i + 1] - cum[i], 1e-9)
    u = _unite(pts[i], pts[i + 1]) or (1.0, 0.0)
    return ((pts[i][0] + (pts[i + 1][0] - pts[i][0]) * t,
             pts[i][1] + (pts[i + 1][1] - pts[i][1]) * t), u)


def _tronquer(pts, cum, s0, s1):
    """La sous-polyligne entre deux abscisses, bornes interpolées. Les sommets
    intermédiaires sont GARDÉS : c'est ce qui fait qu'un trait plein posé dans
    un virage suit l'arc au lieu de le couper à la corde."""
    if s1 - s0 < 1e-6:
        return []
    a, _ = _le_long(pts, cum, s0)
    b, _ = _le_long(pts, cum, s1)
    out = [a]
    for i in range(len(pts)):
        if s0 + 1e-6 < cum[i] < s1 - 1e-6:
            out.append(pts[i])
    out.append(b)
    return out


def _fusionner(intervalles):
    """Des intervalles triés et sans recouvrement."""
    out = []
    for a, b in sorted(intervalles):
        if b - a < 1e-6:
            continue
        if out and a <= out[-1][1] + 1e-6:
            out[-1][1] = max(out[-1][1], b)
        else:
            out.append([a, b])
    return out


def _complement(L, bloques):
    """Ce qui reste de [0, L] une fois les zones interdites retirées."""
    out, s = [], 0.0
    for a, b in bloques:
        if a > s:
            out.append((s, min(a, L)))
        s = max(s, b)
    if s < L:
        out.append((s, L))
    return [(a, b) for a, b in out if b - a > 1e-6]


def _croiser(iv, autres):
    """L'intersection d'un intervalle avec une liste d'intervalles."""
    out = []
    for a, b in autres:
        x, y = max(iv[0], a), min(iv[1], b)
        if y - x > 1e-6:
            out.append((x, y))
    return out


def _pointilles(s0, s1):
    """Les traits d'une ligne discontinue, CENTRÉS dans l'intervalle libre.

    🔴 Pourquoi centrer plutôt que dérouler la trame depuis le départ : un
    tronçon fait rarement un nombre entier de motifs, et le reste tombait en
    bout de rue — un trait de 40 cm juste avant le carrefour, qui se lit comme
    une salissure. On compte les traits entiers qui tiennent, et on répartit
    le reste dans les deux marges."""
    L = s1 - s0
    if L < AXE_TRAIT:
        return []                       # un bout de trait est pire que rien
    pas = AXE_TRAIT + AXE_VIDE
    n = max(1, int((L + AXE_VIDE) / pas))
    marge = (L - (n * AXE_TRAIT + (n - 1) * AXE_VIDE)) / 2.0
    return [(s0 + marge + k * pas, s0 + marge + k * pas + AXE_TRAIT)
            for k in range(n)]


def _virages(pts, cum):
    """Les portions d'axe à traiter en TRAIT PLEIN.

    La règle ne regarde ni les coudes de la source ni les arcs de `_coudes` :
    elle mesure la polyligne FINALE. À chaque sommet on cumule le changement
    de direction sur une fenêtre de CONTINUE_FENETRE mètres ; au-delà de
    CONTINUE_ANGLE, le virage masque la visibilité et la ligne devient pleine.

    Ça attrape les deux formes du même fait : un coude arrondi (une suite de
    petits angles d'arc) et un coude resté vif (un seul grand angle). Une
    seule règle, deux géométries."""
    n = len(pts)
    tourne = [0.0] * n
    for i in range(1, n - 1):
        u1, u2 = _unite(pts[i - 1], pts[i]), _unite(pts[i], pts[i + 1])
        if u1 is None or u2 is None:
            continue
        pv = max(-1.0, min(1.0, u1[0] * u2[0] + u1[1] * u2[1]))
        tourne[i] = math.degrees(math.acos(pv))
    pleins = []
    demi = CONTINUE_FENETRE / 2.0
    for i in range(1, n - 1):
        if tourne[i] <= 0.0:
            continue
        total = sum(tourne[j] for j in range(1, n - 1)
                    if abs(cum[j] - cum[i]) <= demi)
        if total >= CONTINUE_ANGLE:
            pleins.append([cum[i] - CONTINUE_PORTEE, cum[i] + CONTINUE_PORTEE])
    return _fusionner(pleins)


def _noeuds_voirie(routes):
    """Les extrémités de tronçon regroupées par position : combien de branches
    s'y rejoignent, et l'emprise de circulation de chacune.

    C'est ce qui distingue un CARREFOUR (trois branches ou plus — on y pose des
    passages piétons et on y coupe les lignes) d'une simple continuation entre
    deux tronçons (deux branches — le marquage passe au travers) et d'un
    cul-de-sac ou d'un bord de carte (une seule)."""
    nd = {}
    for d in routes:
        larg = d["largeur_m"] or 0.0
        if larg <= 0.0:
            continue
        ch = min(D4.EMPRISE_CIRCULATION.get(d["hierarchie"], 8.5), larg)
        for ip, part in enumerate(d["parts"]):
            for p in (part[0], part[-1]):
                k = (round(p[0] / 0.25), round(p[1] / 0.25))
                nd.setdefault(k, []).append((d["fid"], ip, ch))
    return nd


def _zone_echange(nd, p, fid, ip):
    """De combien le marquage d'un tronçon doit reculer devant ce nœud.

    ⚠️ C'est la demi-chaussée de la rue LA PLUS LARGE QUI Y PASSE, pas la
    sienne : c'est la surface que les autres branches balaient, et y peindre
    une ligne d'axe la ferait traverser le carrefour. Sur une continuation à
    deux branches, il n'y a rien à traverser : le recul est nul."""
    br = nd.get((round(p[0] / 0.25), round(p[1] / 0.25)), [])
    if len(br) < 3:
        return 0.0
    autres = [c for (f, i, c) in br if not (f == fid and i == ip)]
    return (max(autres) / 2.0) if autres else 0.0


def _est_carrefour(nd, p):
    return len(nd.get((round(p[0] / 0.25), round(p[1] / 0.25)), [])) >= 3


def _passage_pieton(m, pts, cum, s, ch, coul, G, dy=0.0):
    """La trame d'un passage piéton : des bandes de PASSAGE_BANDE, en travers.

    Chaque bande est un ruban court dans le sens de la marche — donc le même
    code que la chaussée, donc le même sens de faces. Le nombre de bandes se
    déduit de la largeur de chaussée, il n'est jamais choisi : c'est ce qui
    fait qu'un passage de boulevard en a onze et un passage de rue huit."""
    p, u = _le_long(pts, cum, s)
    nrm = (-u[1], u[0])
    demi = ch / 2.0 - PASSAGE_JEU_BORD
    pas = PASSAGE_BANDE + PASSAGE_ECART
    k = int((2.0 * demi + PASSAGE_ECART) / pas)
    if k < 2:
        return 0, 0
    total = k * PASSAGE_BANDE + (k - 1) * PASSAGE_ECART
    t0 = -total / 2.0 + PASSAGE_BANDE / 2.0
    hp = PASSAGE_PROFONDEUR / 2.0
    tri = 0
    for j in range(k):
        t = t0 + j * pas
        c = (p[0] + nrm[0] * t, p[1] + nrm[1] * t)
        a = (c[0] - u[0] * hp, c[1] - u[1] * hp)
        b = (c[0] + u[0] * hp, c[1] + u[1] * hp)
        tri += _ruban(m, [a, b], PASSAGE_BANDE, coul, G,
                      y=Y_MARQUAGE + dy, bouts=False)
    return k, tri


def _marquage(m, d, axe, ip, ch, nd, chenal, coul, G, dy=0.0):
    """Tout le marquage d'une part de tronçon. Renvoie un compte.

    L'ordre compte : on place d'abord les PASSAGES (ce sont eux qui décident
    où le reste n'a pas le droit d'aller), puis on retire du tracé les zones
    de carrefour et les passages, et on ne peint les lignes que dans ce qui
    reste. Une ligne ne peut donc jamais traverser un passage piéton — pas
    parce qu'on le vérifie, mais parce qu'il n'y a plus de place."""
    st = {"passages": 0, "bandes": 0, "traits": 0, "pleins": 0,
          "rives": 0, "tri": 0, "sur_eau": 0, "sans_trottoir": 0}
    cum = _cumul(axe)
    L = cum[-1]
    if L < 1.0:
        return st

    r0 = _zone_echange(nd, axe[0], d["fid"], ip)
    r1 = _zone_echange(nd, axe[-1], d["fid"], ip)

    # ⑤ les passages piétons. Ils demandent un trottoir des DEUX côtés : on
    # applique le test de `_largeur_trottoir` à la demi-largeur du tronçon,
    # c'est-à-dire exactement ce que `_trottoirs` ira poser plus loin.
    a_trottoir = _largeur_trottoir((d["largeur_m"] or 0.0) / 2.0, ch) > 0.0
    tv = []
    if a_trottoir:
        marge = PASSAGE_RECUL + PASSAGE_PROFONDEUR / 2.0
        if _est_carrefour(nd, axe[0]):
            tv.append(r0 + marge)
        if _est_carrefour(nd, axe[-1]):
            tv.append(L - r1 - marge)
        # ⑥ un tronçon long sans traversée : on en pose au milieu, autant
        # qu'il en faut pour rester sous ESPACEMENT_TRAVERSEE.
        bornes = sorted(set([0.0] + tv + [L]))
        for i in range(len(bornes) - 1):
            trou = bornes[i + 1] - bornes[i]
            if trou <= ESPACEMENT_TRAVERSEE:
                continue
            k = int(trou / ESPACEMENT_TRAVERSEE)
            for j in range(1, k + 1):
                tv.append(bornes[i] + trou * j / (k + 1.0))
        # ⑦ et jamais sur un pont : le chenal passe dessous, la peinture non.
        garde = []
        for s in tv:
            if s < PASSAGE_PROFONDEUR or s > L - PASSAGE_PROFONDEUR:
                continue
            pt, _ = _le_long(axe, cum, s)
            if chenal.dans_eau(pt):
                st["sur_eau"] += 1
                continue
            garde.append(s)
        tv = sorted(garde)
    else:
        st["sans_trottoir"] = 1

    for s in tv:
        k, tri = _passage_pieton(m, axe, cum, s, ch, coul, G, dy)
        if k:
            st["passages"] += 1
            st["bandes"] += k
            st["tri"] += tri

    # ④ ce qui reste au marquage longitudinal
    bloques = [[0.0, r0 + JEU_MARQUAGE], [L - r1 - JEU_MARQUAGE, L]]
    for s in tv:
        bloques.append([s - PASSAGE_PROFONDEUR / 2.0 - JEU_MARQUAGE,
                        s + PASSAGE_PROFONDEUR / 2.0 + JEU_MARQUAGE])
    libres = _complement(L, _fusionner(bloques))
    if not libres:
        return st

    # ① et ② la ligne d'axe : pleine dans les virages, discontinue ailleurs
    if ch >= AXE_MIN_CHAUSSEE:
        pleins = _virages(axe, cum)
        for iv in libres:
            ici = _croiser(iv, pleins)
            for a, b in ici:
                st["tri"] += _ruban(m, _tronquer(axe, cum, a, b),
                                    LARGEUR_LIGNE, coul, G,
                                    y=Y_MARQUAGE + dy, bouts=False)
                st["pleins"] += 1
            for a, b in _decouper(iv, ici):
                for t0, t1 in _pointilles(a, b):
                    st["tri"] += _ruban(m, _tronquer(axe, cum, t0, t1),
                                        LARGEUR_LIGNE, coul, G,
                                        y=Y_MARQUAGE + dy, bouts=False)
                    st["traits"] += 1

    # ③ les lignes de rive, pleines, réservées aux voies rapides
    if d["hierarchie"] in HIER_LIGNE_RIVE:
        dec = ch / 2.0 - RIVE_RETRAIT - LARGEUR_LIGNE / 2.0
        for a, b in libres:
            sub = _tronquer(axe, cum, a, b)
            for cote in (-dec, dec):
                st["tri"] += _ruban(m, sub, LARGEUR_LIGNE, coul, G,
                                    y=Y_MARQUAGE + dy, decal=cote, bouts=False)
                st["rives"] += 1
    return st


def _suites(js):
    """Les files d'entiers consécutifs : [3,4,5,9,10] → [(3,5), (9,10)].

    C'est ce qui évite de peindre le dos d'une rangée en autant de bouts
    qu'elle a de places — un vrai parking le peint d'un seul trait."""
    out = []
    for j in js:
        if out and j == out[-1][1] + 1:
            out[-1][1] = j
        else:
            out.append([j, j])
    return [(a, b) for a, b in out]


def _places_de_parc(anneau):
    """La trame de stationnement d'une place-parking : combien de places elle
    range, le marquage qui les dessine, et l'aire qu'elle occupe.

    Sortie : (places, traits, trame) — le compte, les segments à peindre
    ((x0,y0), (x1,y1)), et l'anneau retiré du bord, qui sert deux fois : à
    ranger les places, et à en tenir les arbres dehors.

    Les sept règles sont commentées au § PLACE_LARGEUR. Ce qui n'y est pas et
    qui compte ici : le DOS des deux rangées est le même trait pour les deux.
    Peint une fois par rangée, il serait peint deux fois au même endroit, à la
    même altitude — deux quadrilatères coplanaires, donc du z-fighting sur
    toute la longueur de la place."""
    n = len(anneau)
    if n < 3:
        return 0, [], None
    inner = D4B.retracter(anneau, [BORD_PARKING] * n)
    if len(inner) < 3 or abs(aire_signee(inner)) < MODULE_PARKING * PLACE_LARGEUR:
        return 0, [], None
    ferme = list(inner) + [inner[0]]

    # ① la direction : la plus longue arête de l'emprise, donc la façade
    # principale sur rue. Mesuré sur l'îlot 19 : les neuf directions possibles
    # ne s'écartent que de 119 à 129 places — la direction ne se choisit donc
    # PAS sur le compte, qui ne les départage pas, mais sur ce qu'elle veut
    # dire. Un parking rangé de travers par rapport à sa façade se voit.
    i = max(range(n), key=lambda k: (anneau[(k + 1) % n][0] - anneau[k][0]) ** 2
                                    + (anneau[(k + 1) % n][1] - anneau[k][1]) ** 2)
    a, b = anneau[i], anneau[(i + 1) % n]
    theta = math.atan2(b[1] - a[1], b[0] - a[0])
    ux, uy = math.cos(theta), math.sin(theta)
    vx, vy = -uy, ux
    ox = sum(p[0] for p in inner) / len(inner)
    oy = sum(p[1] for p in inner) / len(inner)
    us = [(p[0] - ox) * ux + (p[1] - oy) * uy for p in inner]
    vs = [(p[0] - ox) * vx + (p[1] - oy) * vy for p in inner]

    def P(u, v):
        return (ox + ux * u + vx * v, oy + uy * u + vy * v)

    def cadre(u0, u1, va, vb):
        """Les QUATRE coins dedans, pas le centre. Un rectangle dont seul le
        centre est testé déborde de moitié sur un bord oblique — et tous les
        bords de cette place-ci sont obliques."""
        return all(dedans(ferme, P(u, v)) for u, v in
                   ((u0, va), (u1, va), (u1, vb), (u0, vb)))

    def trame(dv, du):
        cases = []
        k0 = int(math.floor((min(vs) - dv) / MODULE_PARKING)) - 1
        k1 = int(math.ceil((max(vs) - dv) / MODULE_PARKING)) + 1
        j0 = int(math.floor((min(us) - du) / PLACE_LARGEUR)) - 1
        j1 = int(math.ceil((max(us) - du) / PLACE_LARGEUR)) + 1
        for k in range(k0, k1 + 1):
            base = dv + k * MODULE_PARKING
            dos = base + ALLEE_PARKING + PLACE_LONGUEUR
            for r in (0, 1):
                # r = 0 : la rangée qui donne sur l'allée du module, en deçà.
                # r = 1 : celle qui lui tourne le dos et donne sur l'allée du
                # module SUIVANT. Les deux se touchent en `dos`.
                va = base + ALLEE_PARKING if r == 0 else dos
                vb = dos if r == 0 else base + MODULE_PARKING
                wa = va - ACCES_PARKING if r == 0 else vb
                wb = va if r == 0 else vb + ACCES_PARKING
                for j in range(j0, j1 + 1):
                    ua = du + j * PLACE_LARGEUR
                    ub = ua + PLACE_LARGEUR
                    if cadre(ua, ub, va, vb) and cadre(ua, ub, wa, wb):
                        cases.append((k, r, j))
        return cases

    # ③ le glissement. 80 essais à ~130 places : le coût est celui d'un
    # clignement d'œil, et il vaut 10 places de plus que la trame centrée.
    meilleur = ([], 0.0, 0.0)
    for s in range(GLISSEMENT_V):
        for t in range(GLISSEMENT_U):
            dv = s * MODULE_PARKING / GLISSEMENT_V
            du = t * PLACE_LARGEUR / GLISSEMENT_U
            cases = trame(dv, du)
            if len(cases) > len(meilleur[0]):
                meilleur = (cases, dv, du)
    cases, dv, du = meilleur
    if not cases:
        return 0, [], inner

    par_module = {}
    for k, r, j in cases:
        par_module.setdefault(k, (set(), set()))[r].add(j)

    traits = []
    for k in sorted(par_module):
        base = dv + k * MODULE_PARKING
        dos = base + ALLEE_PARKING + PLACE_LONGUEUR
        ra, rb = par_module[k]
        # ⑥ les séparations. Une par BORD de place, donc une de plus que de
        # places dans une file — et elle traverse les deux rangées d'un coup
        # quand les deux sont là, ce qui est le marquage réel d'un dos à dos.
        bords = set()
        for rangee in (ra, rb):
            for j in rangee:
                bords.add(j)
                bords.add(j + 1)
        for jb in sorted(bords):
            haut = (jb in ra) or (jb - 1 in ra)
            bas = (jb in rb) or (jb - 1 in rb)
            v0 = base + ALLEE_PARKING if haut else dos
            v1 = base + MODULE_PARKING if bas else dos
            u = du + jb * PLACE_LARGEUR
            traits.append((P(u, v0), P(u, v1)))
        # ⑦ le dos, d'un seul trait par file continue : c'est la butée des
        # deux rangées à la fois.
        for j0, j1 in _suites(sorted(ra | rb)):
            traits.append((P(du + j0 * PLACE_LARGEUR, dos),
                           P(du + (j1 + 1) * PLACE_LARGEUR, dos)))
    return len(cases), traits, inner


def _decouper(iv, retires):
    """L'intervalle privé des morceaux déjà traités."""
    out, s = [], iv[0]
    for a, b in sorted(retires):
        if a > s:
            out.append((s, min(a, iv[1])))
        s = max(s, b)
    if s < iv[1]:
        out.append((s, iv[1]))
    return [(a, b) for a, b in out if b - a > 1e-6]


def _dessus_trottoir(m, poly, coul, G, dy=0.0):
    """Une face horizontale au niveau du trottoir. Le sens de parcours est
    MESURÉ, pas supposé : un coin extérieur de virage se parcourt à l'envers
    d'un coin intérieur, et une face à l'envers est cullée — donc invisible,
    et le trou ne se verrait qu'à l'écran."""
    if len(poly) < 3:
        return 0
    if _aire_xy(poly) < 0.0:
        poly = poly[::-1]
    n = 0
    for k in range(1, len(poly) - 1):
        a, b, c = poly[0], poly[k], poly[k + 1]
        if abs(_aire_xy([a, b, c])) < 1e-6:
            continue
        m.triangle(G(a[0], a[1], Y_TROTTOIR + dy),
                   G(b[0], b[1], Y_TROTTOIR + dy),
                   G(c[0], c[1], Y_TROTTOIR + dy), coul)
        n += 1
    return n


def _bordure(m, a, b, vers, coul, G, dy=0.0):
    """LA BORDURE : la face verticale d'un trottoir, du dessus jusqu'à la
    plaque de sol. `vers` est la direction, à plat, vers laquelle elle doit
    regarder — la chaussée pour la bordure de rue, l'îlot pour son flanc.

    Elle descend jusqu'à la PLAQUE (−0,10) et non jusqu'à la chaussée : sous
    le trottoir il y a du sol nu d'un côté, du sol d'îlot de l'autre, et les
    deux sont plus bas. Ce qui dépasse est recouvert, jamais visible."""
    n = (-(b[1] - a[1]), b[0] - a[0])
    if math.hypot(n[0], n[1]) < 1e-9:
        return 0
    if (n[0] * vers[0] + n[1] * vers[1]) < 0.0:
        a, b = b, a
    p = G(a[0], a[1], Y_TROTTOIR + dy)
    q = G(b[0], b[1], Y_TROTTOIR + dy)
    r = G(b[0], b[1], Y_TERRAIN + dy)
    s = G(a[0], a[1], Y_TERRAIN + dy)
    m.triangle(p, s, r, coul)
    m.triangle(p, r, q, coul)
    return 2


def _coin_vif(V, p, e):
    """Le coin de trottoir d'un carrefour : l'onglet des deux bords décalés,
    écrêté en biseau quand il part en pointe. C'est ce que l'auteur a demandé
    — le carrefour garde son angle."""
    a = (V[0] + p["n"][0] * p["w"], V[1] + p["n"][1] * p["w"])
    b = (V[0] + e["n"][0] * e["w"], V[1] + e["n"][1] * e["w"])
    den = p["u"][0] * e["u"][1] - p["u"][1] * e["u"][0]
    if abs(den) > 1e-9:
        t = ((b[0] - a[0]) * e["u"][1] - (b[1] - a[1]) * e["u"][0]) / den
        M = (a[0] + p["u"][0] * t, a[1] + p["u"][1] * t)
        if math.hypot(M[0] - V[0], M[1] - V[1]) <= \
                LIMITE_MITRE_TROTTOIR * max(p["w"], e["w"]):
            return (M, M)
    return (a, b)                               # biseau


def _coin_arrondi(V, p, e, coudes):
    """L'arc de bordure au sommet d'un coude, ou None si ce sommet n'en est
    pas un.

    🔴 LES DEUX ÎLOTS D'UN MÊME COUDE DOIVENT S'ACCORDER, sinon la rue change
    de largeur dans le virage. Ils ne se parlent pas : ils lisent tous les
    deux le MÊME rayon d'axe, calculé une fois pour toutes par `_coudes`, et
    en déduisent le leur — R moins leur distance à l'axe du côté intérieur du
    virage, R plus cette distance du côté extérieur. Deux arcs concentriques,
    donc un corridor de largeur constante."""
    if p["rue"][:2] != e["rue"][:2] or abs(p["rue"][2] - e["rue"][2]) != 1:
        return None                        # deux rues : c'est un carrefour
    cd = coudes.get((p["rue"][0], p["rue"][1], max(p["rue"][2], e["rue"][2])))
    if cd is None:
        return None
    pv = max(-1.0, min(1.0, p["u"][0] * e["u"][0] + p["u"][1] * e["u"][1]))
    if abs(math.degrees(math.acos(pv)) - cd["theta"]) > 8.0:
        return None              # l'anneau ne tourne pas comme l'axe : biseau
    c = ((p["d"] - p["w"]) + (e["d"] - e["w"])) / 2.0
    vers = (-p["n"][0], -p["n"][1])             # de l'axe vers l'îlot
    dedans = (cd["u1"][0] * vers[1] - cd["u1"][1] * vers[0]) * cd["sens"] > 0
    r = cd["R"] - c if dedans else cd["R"] + c
    if r < 1.0:
        return None
    # La tangente recule de T le long de CHAQUE arête : si elle dépasse
    # l'arête de l'anneau, le quadrilatère du trottoir se retourne.
    T = cd["R"] * math.tan(math.radians(cd["theta"]) / 2.0)
    if T > 0.90 * min(p["L"], e["L"]):
        return None
    C = cd["C"]
    A = (C[0] - cd["n1"][0] * r, C[1] - cd["n1"][1] * r)
    B = (C[0] - cd["n2"][0] * r, C[1] - cd["n2"][1] * r)
    # L'anneau de l'îlot extérieur parcourt le coude À REBOURS de l'axe : son
    # premier point d'arc est alors celui de la SECONDE branche.
    if p["u"][0] * cd["u1"][0] + p["u"][1] * cd["u1"][1] < 0.0:
        A, B = B, A
    return tuple(_arc(C, r, A, B))


def _trottoirs(ilots, routes, coudes):
    """Le trottoir de chaque îlot : un anneau posé le long de la limite de
    parcelle, surélevé, qui TOURNE LES COINS DE RUE tout seul.

    🔴 C'est le point important, et il ne se voit pas dans le code : AUCUNE
    LIGNE ICI NE PARLE DE CARREFOUR. Un carrefour est ce qui RESTE entre
    quatre anneaux d'îlot — exactement comme un pont est ce qui reste quand on
    creuse le chenal sous une voirie qui, elle, ne sait rien.

    🔄 Le trottoir était AVANT un quadrilatère plus large que la chaussée,
    glissé SOUS elle, à 3 cm : deux liserés dépassaient de part et d'autre de
    l'asphalte, le carrefour était noyé par le débordement des deux rubans, et
    il n'y avait ni bordure ni coin de rue. L'ordre transversal est maintenant
    celui d'une vraie rue :

        façade │ trottoir │ mètres libres │ chaussée │ …
               └ bordure

    Les mètres libres restent le sol nu de la plaque : c'est là que le
    stationnement DE RUE se dessinera. 🔄 Le commentaire disait « 4 587 places
    à Wehrau, aucune visible » ; les deux moitiés ont bougé. Le compte est de
    3 310 places de rue (`routes.stationnement`, mesuré le 2026-08-19), et
    depuis le même jour la place-parking, elle, est dessinée — 123 places
    peintes sur les 127 annoncées, § `_places_de_parc`. Les rues, non.

    Sortie : {fid de tronçon: [faces]}. Les faces sont rangées sous LA RUE que
    longe l'arête, pas sous l'îlot — cliquer un trottoir ouvre la fiche du
    tronçon. ⚠️ Les fid d'îlot et de tronçon se recouvrent (71 et 178) : mêlés
    dans le même maillage, ils rendraient la ville cliquable n'importe
    comment."""
    segs, idx = _index_voirie(routes)
    faces = {}
    stats = {"ilots": 0, "aretes": 0, "avec_rue": 0, "avec_trottoir": 0,
             "coins": 0, "arrondis": 0, "long": 0.0}
    # Un coude a DEUX bords, et les deux doivent s'arrondir pour que la rue
    # garde sa largeur dans le virage. Le compte le dit au lieu de le supposer.
    par_coude = {}
    for fid_i in sorted(ilots):
        d = ilots[fid_i]
        if d["sous_type"] == "riviere":
            continue
        ring = d["anneau"]
        n = len(ring)
        if n < 3:
            continue
        ar = []
        for i in range(n):
            a, b = ring[i], ring[(i + 1) % n]
            u = _unite(a, b)
            if u is None:
                ar.append(None)
                continue
            stats["aretes"] += 1
            # L'anneau est TRIGONOMÉTRIQUE (forcé par `anneau_ouvert`), donc
            # l'intérieur est à gauche et le dehors — la rue — est à droite.
            nout = (u[1], -u[0])
            rue = _rue_le_long(a, b, nout, segs, idx)
            if rue is None:
                ar.append(None)
                continue
            stats["avec_rue"] += 1
            w = _largeur_trottoir(rue[0], rue[2])
            if w <= 0.0:
                ar.append(None)
                continue
            stats["avec_trottoir"] += 1
            ar.append({"u": u, "n": nout, "w": w, "d": rue[0],
                       "L": math.hypot(b[0] - a[0], b[1] - a[1]),
                       "rue": (rue[3], rue[4], rue[5])})

        deb = [None] * n
        fin = [None] * n
        coins = [None] * n
        for i in range(n):
            e, p = ar[i], ar[(i - 1) % n]
            V = ring[i]
            if e is None and p is None:
                continue
            if e is None:                       # le trottoir s'arrête ici
                fin[(i - 1) % n] = (V[0] + p["n"][0] * p["w"],
                                    V[1] + p["n"][1] * p["w"])
                continue
            if p is None:                       # … et il commence ici
                deb[i] = (V[0] + e["n"][0] * e["w"], V[1] + e["n"][1] * e["w"])
                continue
            stats["coins"] += 1
            arc = _coin_arrondi(V, p, e, coudes)
            if arc is None:
                arc = _coin_vif(V, p, e)
            else:
                stats["arrondis"] += 1
                cle = (p["rue"][0], p["rue"][1],
                       max(p["rue"][2], e["rue"][2]))
                par_coude[cle] = par_coude.get(cle, 0) + 1
            fin[(i - 1) % n] = arc[0]
            deb[i] = arc[-1]
            coins[i] = arc

        for i in range(n):
            e = ar[i]
            if e is None or deb[i] is None or fin[i] is None:
                continue
            a, b = ring[i], ring[(i + 1) % n]
            # Deux coins arrondis qui se rejoignent au milieu de l'arête :
            # le quadrilatère se retournerait. On saute plutôt que de plier.
            if ((fin[i][0] - deb[i][0]) * e["u"][0]
                    + (fin[i][1] - deb[i][1]) * e["u"][1]) <= 0.05:
                continue
            f = faces.setdefault(e["rue"][0], [])
            f.append(("plat", [a, b, fin[i], deb[i]]))
            f.append(("mur", deb[i], fin[i], e["n"]))          # la bordure
            f.append(("mur", a, b, (-e["n"][0], -e["n"][1])))  # le flanc
            stats["long"] += math.hypot(b[0] - a[0], b[1] - a[1])
            c = coins[i]
            if c is not None and len(c) >= 2 and \
                    math.hypot(c[0][0] - c[-1][0], c[0][1] - c[-1][1]) > 1e-6:
                f.append(("plat", [ring[i]] + list(c)))
                for k in range(len(c) - 1):
                    # Le dehors d'un coin n'est PAS la normale d'une de ses
                    # deux arêtes : sur un coin extérieur de virage l'arc
                    # tourne de l'autre côté. La direction qui vaut toujours
                    # est celle qui part du sommet de l'anneau.
                    f.append(("mur", c[k], c[k + 1],
                              ((c[k][0] + c[k + 1][0]) / 2.0 - ring[i][0],
                               (c[k][1] + c[k + 1][1]) / 2.0 - ring[i][1])))
        stats["ilots"] += 1
    stats["coudes_entiers"] = sum(1 for v in par_coude.values() if v == 2)
    return faces, stats


def _semer(anneau, d, rng, relief=None, interdit=None):
    """Le semis d'arbres d'un îlot de sol. Densité dérivée de `canopee`,
    graine fixe : le même export donne toujours la même forêt.

    ⚠️ Le pied de l'arbre suit le talus. Sans ça, les arbres de rive des
    champs 3, 5, 6 et 8 resteraient plantés à 0 — une rangée en lévitation
    au-dessus de la pente, et c'est l'endroit de la carte qu'on regarde.

    `interdit` est un anneau FERMÉ d'où le semis est exclu : la trame de
    stationnement de la place, où un arbre pousserait au milieu d'une place
    peinte. Un rejet de plus dans une boucle qui n'en avait qu'un — la
    position reste tirée, elle n'est pas corrigée."""
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
        if interdit is not None and dedans(interdit, (x, y)):
            continue
        # Un parc, un bois de rive ou une lisière : le conifère y est courant.
        out.append([x, y, 0.0 if relief is None else relief.z(x, y),
                    rng.uniform(0.75, 1.35), rng.uniform(0.0, 6.2832),
                    1 if rng.random() < 0.24 else 0])
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


def _reperes(ilots, routes, cx, cy, relief=None, ponts=()):
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

    # 🌊 Le point de vue sur l'Ilse. C'est là que le chenal se juge : deux
    # mètres de mur au-dessus de l'eau sur toute la longueur du quai, et le
    # tablier des trois franchissements qui passe au-dessus sans y plonger.
    eau_pts = [p for x in ilots.values() if x["sous_type"] == "riviere"
               for p in x["brut"]]
    ip = [0.0, 0.0]
    if eau_pts:
        ip = [round(sum(p[0] for p in eau_pts) / len(eau_pts) - cx, 2),
              round(-(sum(p[1] for p in eau_pts) / len(eau_pts) - cy), 2)]

    # 🌾 Et le point de vue sur le TALUS, qui n'existait pas : les quatre
    # autres sont tous posés sur la ville, où le sol est plat. Sans lui le
    # relief demandé le 2026-08-18 ne se voit sur aucune capture d'essai — donc
    # il n'existe pas (§3 bis). Visé sur le milieu de la plus longue rive de
    # champ, celle du champ 6, en aval.
    bp = list(ip)
    if relief is not None and relief.zones:
        f = max(relief.zones, key=lambda k: relief.zones[k]["longueur"])
        pts = [p for a in relief.zones[f]["riv"] for p in a]
        bp = [round(sum(p[0] for p in pts) / len(pts) - cx, 2),
              round(-(sum(p[1] for p in pts) / len(pts) - cy), 2)]
    # 🌉 ET LE POINT DE VUE SUR LE PLUS LONG FRANCHISSEMENT. `ilse` regarde le
    # chenal de haut : à 260 m d'étendue, un tablier de 70 cm et une pile ne
    # sont pas jugeables. Le pont est visé de près, et c'est là qu'on voit s'il
    # passe AU-DESSUS de l'eau au lieu de flotter dedans.
    # 🅿️ Le point de vue sur la place-parking. Il n'est pas visé sur un fid
    # écrit ici : c'est l'îlot de SOL qui porte des places, et il n'y en a
    # qu'un. 130 m d'étendue — une place de 2,5 m ne se juge pas à 1 200.
    pm = [f for f, x in ilots.items()
          if (x["hauteur"] or 0.0) <= 0.0 and (x["stationnement"] or 0) > 0]
    place = {"cible": centre(pm[0]) if pm else [0.0, 0.0],
             "taille": 130.0,
             "libelle": "La place-parking et ses places"}

    pp, ptaille = ip, 260.0
    if ponts:
        L, mil = max(ponts, key=lambda x: x[0])
        pp = [round(mil[0] - cx, 2), round(-(mil[1] - cy), 2)]
        ptaille = round(L * 2.2, 1)

    # 🌊 LE FAUBOURG SINISTRÉ (23b). Sans ce point de vue, la crue ne se juge
    # sur aucune capture : `ville` la montre à 1 200 m d'étendue, où une ruine
    # fait deux pixels. Visé sur le barycentre des îlots de RIVE GAUCHE qui ont
    # bu — donc il suit la table de `04e` au lieu d'une liste de fid écrite ici.
    noyes = [f for f, x in ilots.items()
             if x.get("rive") == "gauche" and (x.get("hauteur_eau_max") or 0) > 0
             and (x["hauteur"] or 0.0) > 0.0]
    fb = [0.0, 0.0]
    if noyes:
        cs = [centre(f) for f in noyes]
        fb = [round(sum(c[0] for c in cs) / len(cs), 2),
              round(sum(c[1] for c in cs) / len(cs), 2)]
    # 🌉 Et le pont EMPORTÉ, visé sur son milieu : c'est un trou, donc rien ne
    # le signale sur une vue d'ensemble. `pont` vise le plus LONG, qui n'est
    # pas forcément celui que la crue a pris.
    casse = [d for d in routes if (d.get("etat_crue") or "") == "coupe"]
    cp, ctaille = pp, 150.0
    if casse:
        pts = [q for d in casse for part in d["parts"] for q in part]
        cp = [round(sum(q[0] for q in pts) / len(pts) - cx, 2),
              round(-(sum(q[1] for q in pts) / len(pts) - cy), 2)]

    return {
        # 🔄 C'était « la vallée ». Il n'y a plus de vallée : la carte est
        # plate. Le point de vue, lui, sert toujours — c'est la ville entière.
        "ville": {"cible": [0.0, 0.0], "taille": 1200.0,
                  "libelle": "Wehrau en entier"},
        "barre": {"cible": centre(32), "taille": 220.0,
                  "libelle": "La barre de 1974 (ilot 32)"},
        "pans_solaire": {"cible": centre(22), "taille": 115.0,
                         "libelle": "Les panneaux, pan par pan"},
        "quai": {"cible": qp, "taille": 160.0,
                 "libelle": "Les rues a 20 et 22 m"},
        "ilse": {"cible": ip, "taille": 260.0,
                 "libelle": "L'Ilse canalisee et les ponts"},
        "berge": {"cible": bp, "taille": 200.0,
                  "libelle": "Le talus des champs, au bord de l'eau"},
        "pont": {"cible": pp, "taille": ptaille,
                 "libelle": "Le plus long franchissement, tablier et pile"},
        "place": place,
        "faubourg": {"cible": fb, "taille": 420.0,
                     "libelle": "Le faubourg sinistre, rive gauche"},
        "pont_casse": {"cible": cp, "taille": ctaille,
                       "libelle": "Le pont emporte par la crue"},
    }


if __name__ == "__main__":
    for flux in (sys.stdout, sys.stderr):
        try:
            flux.reconfigure(encoding="utf-8", errors="replace")
        except (AttributeError, OSError):
            pass
    main()
