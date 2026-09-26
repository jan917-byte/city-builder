# -*- coding: utf-8 -*-
"""Réglages du rendu et compteurs de fabrication, sans changement de valeurs."""

import palette as PAL

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

# Le sol nu d'un îlot bâti : 2 cm SOUS les jardins, venelles et accès
# qui se posent dessus, 13 cm au-dessus de la plaque de terrain.
Y_SOL_ILOT = Y_SOL - 0.02

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

# Les arbres des bois et des haies sont semés sans rien savoir de la voirie.
# 2 m : le pied du modèle (1 m × 1,95 au plus) reste hors de l'asphalte, la
# couronne peut déborder — plus large, on rasait les haies qui bordent les routes.
MARGE_PIED_DECOR = 2.0

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

# Jusqu'où on cherche la chaussée, CÔTÉ TERRE, pour dire qu'il y a un quai ici.
# 🔄 4 m jusqu'au 2026-08-31, quand l'asphalte touchait encore l'eau. Depuis que
# le corridor se colle aux façades (§ COLLE_MIN) la chaussée s'écarte de la rive
# de 1,4 m (une voie `rive`) à 9,4 m (le boulevard de quai) : à 4 m le mur de
# quai disparaissait sur tout le linéaire. Au-delà de 14 m, la rue passe
# derrière quelque chose et une barrière n'y voudrait rien dire.
QUAI_PORTEE = 14.00

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

# 🌊 LA BERGE EST UN OBJET (2026-08-26). Jusqu'ici elle n'était que le bord des
# six îlots d'eau : ni cliquable, ni transformable. Elle est découpée AUX
# FRANCHISSEMENTS — un morceau par rive et par bief. C'est la seule coupe que
# le joueur voit, et la seule qui laisse le mur d'un seul tenant (2026-08-19).
BERGE_MIN_M = 15.0         # plus court, c'est un bout sous un pont, pas une berge

# 🌊 UNE RUE QUI LONGE L'ILSE POSE TOUT SON CORRIDOR SUR LA TERRE (2026-08-31,
# demandé devant l'image : « route | berge | rivière »). `04b` recule déjà
# l'îlot riverain de la LARGEUR ENTIÈRE du corridor — la chaussée, elle, restait
# centrée sur l'axe de la source, c'est-à-dire SUR la ligne d'eau. D'où les deux
# défauts vus le même jour : 4 819 m² d'asphalte au-dessus de l'Ilse d'un bord,
# et jusqu'à 15 m de sol nu entre l'asphalte et le trottoir de l'autre.
# 🔴 SEUL L'AXE DESSINÉ BOUGE. La source garde le tracé de l'auteur (level
# design), et le décalage se MESURE sur l'emprise bâtie au lieu de recopier la
# règle de `04b` — même piège que `_rue_le_long`.
COLLE_MIN = 0.75           # en deçà, le décalage ne se verrait pas

COLLE_PAS = 0.50           # le pas de la sonde qui cherche la façade

COLLE_SONDE = 4.0          # une station tous les 4 m le long du tronçon

COLLE_EAU = 1.50           # de combien la sonde dépasse le bord de l'asphalte

COLLE_PART = 0.55          # part des stations qui doivent longer l'eau

COLLE_PORTEE = 32.0        # jusqu'où chercher l'emprise bâtie, côté terre

# 🔴 LA BANDE DOIT SE VOIR, sinon la décision n'a pas d'effet à l'écran. Le
# couronnement du mur fait 1 m de large et passe SOUS le trottoir du quai : à
# lui seul il ne donnait qu'un filet vert. La bande reprend donc les mètres que
# le quai a pris au fleuve, et se pose 2 cm au-dessus de ce qu'elle recouvre —
# le trottoir en ville (Y_TROTTOIR), le talus en campagne (Y_SOL + relief).
BERGE_BANDE_M = 3.5        # la largeur de rive que la transformation rend

# 🔴 SON BORD CÔTÉ TERRE EST UNE LIGNE (2026-09-02, demandé devant l'image).
# La fenêtre de moyenne, puis la pente maximale du biseau, en mètres par
# station de 2 m : 0,25 m, c'est 7° d'écart à la direction de la berge.
BERGE_LISSE_M = 8.0

BERGE_LISSE_PENTE = 0.25

BERGE_Y = 0.02             # de combien elle passe au-dessus de son support

# De combien la bande de campagne s'ENFOUIT sous le talus. 4 cm ne suffisaient
# pas : entre deux stations le quad est droit, le talus courbe, et il ressortait
# en dents grises tout le long des deux rives — vu à l'écran le 2026-08-26.
BERGE_ENFOUIE = 0.60

# 🌿 LE SEMIS D'UNE RIVE RENDUE AU FLEUVE. Une bande verte est un aplat, et un
# aplat se lit comme de la peinture : ce qui fait lire une berge renaturée est
# ce qui y POUSSE. Même format que les arbres — [x, y, alt, échelle, lacet,
# genre] —, rangé par berge : Godot n'affiche que le semis des berges rendues.
SEMIS_ROSEAU_PAS = 2.20    # au fil de l'eau, une touffe tous les 2,2 m

SEMIS_BUISSON_PAS = 7.50   # en retrait, un buisson tous les 7,5 m

# Sous cette largeur de bande, il n'y a de place que pour la ligne d'eau.
SEMIS_BUISSON_LARGE = 1.60

SEMIS_ROSEAU, SEMIS_BUISSON = 2, 3   # les essences de `constructeur.gd`

# Ce que le ruban de sélection prend au quai en plus de la bande. Il entoure ce
# que la décision CHANGE — la bande verte et le mur —, pas les 10 m de
# promenade minérale : à la largeur de la rive libre, le trait traversait les
# toits du cœur ancien.
BERGE_TRAIT_MARGE = 1.5

# 🌿 UNE RIVE RENDUE ENTRE DANS L'EAU (2026-09-02, demandé devant l'image :
# « il faut qu'elle entre progressivement dans l'eau et non pas un mur »). Un
# mur qui verdit reste un mur : la pente est de la GÉOMÉTRIE. D'où un deuxième
# corps par berge, montré à la place du mur quand la rive est rendue.
# 🔴 LE TALUS PREND SUR L'ILSE (~31 m de large), FAUTE DE POUVOIR CREUSER : la
# plaque de sol est un maillage fusionné une fois pour toutes, un talus taillé
# dans la bande de rive resterait enterré dessous. Il part donc du bord de la
# bande et descend AU LIT — s'arrêter au-dessus laisserait une arête flottante.
PENTE_RIVE_M = 4.50        # course horizontale moyenne → 31° sur 2,74 m

PENTE_OMBRE = 0.68         # l'occlusion au fil de l'eau, 1,00 en haut du talus

PENTE_OND = 0.14           # ce que le talus s'autorise en plus ou en moins

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
    # 🌊 CE QUE LA BERGE RACHÈTE (question 24) : la hauteur d'eau annoncée en
    # mètres, et la part ruinée sous une crue plus basse de 0 à 2,50 m. Godot
    # n'a pas le profil de terrain de `04e` — il lit cette courbe.
    "hauteur_eau_annonce", "ruine_apres_baisse",
    # 🔧 CE QUE LA RÉPARATION COÛTE, calculé par `04e` et jamais ici : le prix
    # est du level design, il vit avec les sept nombres de la crue.
    "batiments_ruines", "cout_reparation_ke",
]

COLS_ROUTES = ["fid", "hierarchie", "largeur_m", "emprise_libre_m", "charge",
               "canopee", "stationnement", "etat_crue", "hauteur_eau",
               "part_boue", "cout_reparation_ke"]

# 🅿️ Calculé, pas lu : l'écart à l'axe où `trafic.gd` pose une voiture garée.

# Ce qui part dans `objets` : la fiche qu'on lit en cliquant, et l'état de
# départ du noyau. Tout ce qui n'est pas là ne peut ni s'afficher ni évoluer.
FICHE_ILOTS = [c for c in COLS_ILOTS if c != "fid"]

# 🔗 L'interface du toit (41 · 64), calculée et non lue dans le `.gpkg` :
# surface réelle, pente, et le drapeau « toit plat ». L'ombrage, lui, est déjà
# là — c'est `canopee`.
TOIT_ILOTS = ["toit_m2", "toit_pente", "toit_plat", "toit_plat_m2",
               "toit_m2_neuf"]

# 🏢 CE QU'UN ÉTAGE DE PLUS DONNE, mesuré ici et nulle part ailleurs :
# combien de bâtiments de l'îlot ont le droit de monter, combien de logements
# UN étage ajoute sur leurs emprises réunies, et le profil des paliers —
# `dense_cumul[k]` = la part de cette emprise atteinte aux k+1 premiers.
DENSE_ILOTS = ["dense_n", "dense_logements_etage", "dense_cumul"]

# 🏕️🌉 CE QUE LE RELOGEMENT DEMANDE : le morceau de réseau qui porte l'îlot
# une fois les ponts emportés — deux îlots de morceaux différents ne se
# rejoignent pas à pied —, et le nombre de places de camp mesuré sur le champ.
ACCES_ILOTS = ["morceau", "camp_places"]

# 🔴 Un champ n'est riverain d'aucune rue : la berge l'en sépare. Sous ce
# seuil, il hérite du morceau de la route la plus proche. Mesuré : 10 m pour
# les champs 1082 et 1083 du faubourg, 115 m pour le premier qui n'a
# réellement pas d'accès — le seuil ne tranche rien de serré.
ACCES_RATTRAPAGE_M = 30.0

FICHE_ROUTES = ([c for c in COLS_ROUTES if c != "fid"]
                + ["longueur_m", "bord_places_m", "bord_trottoir_m"])

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
    "collectif_1995":          (5.0,  4.0,   13.0,     0.00),  # toit plat (auteur, 2026-08-25)
    "ilot_compact":            (1.0,  0.0,   12.0,     0.00),  # toit plat (auteur, 2026-08-25)
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

# 🏢 LE PATRIMOINE NE MONTE PAS (auteur, 2026-09-03). Tout le reste du bâti
# peut prendre un ou deux étages ; le cœur ancien et le front commerçant, non.
# C'est du level design : une ligne de moins ici et la silhouette ancienne de
# Wehrau change.
DENSE_INTERDIT = {"coeur_ancien", "front_commercant"}

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

# 🎨 LA FAMILLE DE FAÇADE : ce que le shader ajoute au percement — volets et
# soubassement (1, 2), stores (3), allèges de couleur (4), bardage et portes de
# quai (5), balcons (6). Voyage dans la partie entière de UV2.y, le tirage du
# bâtiment dans sa partie décimale. 0 = rien de plus que les fenêtres.
FAMILLE_FACADE = {
    "coeur_ancien": 1,
    "maisons_de_ville": 1,
    "pavillonnaire": 2,
    "front_commercant": 3,
    "barre_1970": 4,
    "friche_industrielle": 5,
    "collectif_1995": 6,
    "ilot_compact": 6,
}

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

# 🅿️ La place DE RUE est plus longue : on s'y range en marche arrière, le long
# du trottoir. Même valeur que `trafic.gd` (LONGUEUR_PLACE), qui y pose les
# voitures — les deux dessinent la même file.
PLACE_RUE_LONGUEUR = 5.50

# 🅿️ Ce que la file laisse libre devant un passage piéton et à l'entrée d'un
# carrefour : la règle réelle des 5 m, et ce qu'il faut ici pour qu'une
# voiture garée ne pose plus son capot sur la première bande blanche.
PLACE_RECUL_PASSAGE = 5.00

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

# 🏕️ LE CAMP DE CONTAINERS — ce qu'on pose sur un champ pour loger les
# sinistrés de la crue. 🎚️ LEVEL DESIGN : la taille de la case décide combien
# de logements tiennent sur un champ. Une case de 6,5 × 6,0 m tient un
# container et son passage ; l'occupation en personnes se règle dans ville.gd.
# Le bord laissé libre empêche un container de toucher la haie.
CAMP_CONTAINER_M = (6.5, 6.0)
CAMP_BORD_M = 6.0
CAMP_PLAFOND = 400
# UN logement, UN abri (long, large, haut) : ce qui est à l'écran est le
# nombre que la fiche annonce. Ce qui reste dans la case est l'allée.
CAMP_BOITE_M = (5.6, 2.9, 2.6)

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

# ============================================================ le talus des champs

# Une arête d'emprise est « riveraine » si elle est POSÉE sur la berge. Mesuré
# le 2026-08-18 : les 4 champs riverains ont bien leurs arêtes à 0,00 m de
# l'eau (04b ne les recule pas — `larg` y est nul), mais leurs SOMMETS ne
# coïncident pas avec ceux du polygone d'eau : le retrait des arêtes voisines
# les a fait glisser le long de la rive. D'où un test de distance, et non
# d'égalité de clés — l'égalité ne trouvait que 6 arêtes sur 10.
BORD_EAU_TOL = 0.5

# ================================================ la voirie : courbes et bordures

GRILLE_VOIRIE = 25.0        # l'index spatial des segments de rue, en cellules

LIMITE_MITRE_RUBAN = 2.0    # au-dela, l'onglet part en pointe : on l'ecrete
