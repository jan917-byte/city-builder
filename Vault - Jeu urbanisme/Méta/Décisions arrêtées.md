---
tags: [méta, registre]
statut: vivant
maj: 2026-08-10 (rév. rivière · périmètre · le prototype devient une ville à part)
---

# Décisions arrêtées

Légende : 🔒 difficile à inverser · 🔓 réversible · 🟡 arrêté mais paramètres ouverts

## Socle

| # | Décision | | Note |
|---|---|---|---|
| 1 | City-builder PC ambitieux | 🔒 | Prémisse fondatrice |
| 2 | Le jeu valorise mon expertise d'urbaniste | 🔒 | Prémisse fondatrice |
| 3 | « Ambitieux » = profondeur sur périmètre étroit, pas grande échelle | 🔒 | [[Vision et prémisses]] |
| 4 | **Transformation** d'une ville existante, pas construction sur terrain vierge | 🔒 | |
| 5 | Ville moyenne ordinaire, reconnaissable, **pas dystopique** | 🔒 | |
| 6 | Direction solarpunk / utopie — inspirer, pas simuler la bureaucratie | 🔒 | |
| 7 | **Pas de mécaniques de procédure réglementaire** | 🔒 | Rejeté explicitement |
| 8 | Ton : « dur mais possible », jamais cynique | 🔒 | [[Ton et règles d'écriture]] |
| 9 | Buts : zéro carbone + résilience climatique. **Fin choisie par le joueur** | 🔒 | |

## Gameplay

| # | Décision | | Note |
|---|---|---|---|
| 10 | **Aucune manipulation directe** — le joueur pose des intentions | 🔒 | Le geste central |
| 11 | Le joueur écrit la **structure**, le système écrit le **grain** | 🔒 | |
| 12 | **Ghost preview instantané** obligatoire | 🔒 | Anti-spectateur |
| 13 | Échelle du **jeu** : ville entière, interventions par quartier, 2 niveaux réseau/tissu | 🟡 | |
| 13b | ~~Échelle du **prototype** : l'[[Altstadt]] uniquement~~ → **le prototype est [[Wehrau]], une petite ville entière (~5 350 hab.)**, pas un quartier de [[Vallmar]] | 🔓 | 🔄 **révisé 2026-08-10.** La carte disponible est une ville complète : noyau + rivière traversante + campagne. Gain décisif : **l'amont/aval entre dans le prototype** → [[Périmètre et coupes]] |
| 13c | **Quatre plaies héritées de 1965** dans le prototype : la place-parking · le quai en voie rapide · l'axe de transit dans le cœur · la galerie de 1971 | 🔓 | ✅ 2026-08-10. « Fort mais réparable » : chacune se répare par une décision **différente**, aucune gratuitement → [[Wehrau]] |
| 14 | **Temps continu**, tick mensuel, 3 vitesses. Tour par tour rejeté | 🔒 | |
| 15 | Pause généreuse + pause auto sur événement climatique | 🔓 | |
| 16 | **Deux ressources non convertibles** : argent + capital politique | 🔒 | |
| 17 | Le capital politique **ne s'achète pas** — se regagne par les résultats visibles | 🔒 | |
| 18 | **Pas d'échéance électorale** | 🔒 | Écarté |
| 19 | Décisions **irréversibles mais pas irrécupérables** | 🔒 | |
| 20 | **Pas de game over** — des quartiers qu'on perd, lentement et visiblement | 🟡 | Proposé, non confirmé |
| 21 | **Pas de difficulté adaptative** | 🔒 | Écarté |
| 22 | Système de **happenings** : crises rares, lourdes, espacées | 🟡 | |
| 23 | La crise ouvre une **fenêtre politique** pour l'impossible | 🟡 | |
| 24 | Le **diagnostic par cartes thématiques** est l'activité principale entre deux décisions | 🔒 | |
| 25 | 3 calques parents : vert/climat, mobilité, social/éco | 🔓 | |

## Technique

| # | Décision | | Note |
|---|---|---|---|
| 26 | **Ville fictive**, pas OSM en production | 🔒 | La tension OSM est close |
| 27 | **Géométrie : îlot**, issu de la polygonisation d'une couche ligne | 🔒 | ~~tracée à la main~~ — voir 31b |
| 28 | **L'adjacence passe par la rue**, dont le caractère module l'effet | 🔒 | ✅ **table construite 2026-08-10, 179 paires.** Contrôle : la ville privée de sa rivière tombe en deux morceaux |
| 28b | **Perméabilité** : 7 valeurs par hiérarchie, moyenne pondérée par la longueur, **divisée par 2 au-delà de 20 m de largeur** | 🟡 | ✅ 2026-08-10. Du design, pas de la mesure — ces sept nombres décident du comportement de toute la carte → [[Géométrie et données]] |
| 29 | Grille réservée aux **champs continus dérivés**, calculés au runtime | 🔒 | |
| 30 | ~~Le fleuve est dans la couche `rues`~~ → **la rivière est un îlot** (`fonction = 'riviere'`), les rives sont les lignes | 🔒 | 🔄 **révisé 2026-08-10.** Lui donne une surface, un état transformable, et met la coupure dans la géométrie → [[Géométrie et données]] |
| 30b | **Un pont se reconnaît à ce qu'il sépare deux morceaux de rivière** | 🔓 | ✅ 2026-08-10. Sans cette règle, les cinq franchissements tombaient en `rive` et la ville avait **deux réseaux routiers étanches**. Découvert par un test de connexité, pas à l'œil |
| 31 | GeoPackage unique, EPSG:25832 | 🔒 | Le fichier de travail est `QGIS/Prototype_qualifie.gpkg` |
| 31b | ~~**Extraction automatique abandonnée** — tracé manuel~~ → **la carte générée est la source de vérité** | 🔓 | 🔄 **révisé 2026-08-10.** Elle donne en une soirée ce qu'un tracé manuel donnait en une semaine, et elle est meilleure. Le tracé manuel reste l'outil de **retouche**, pas de création → [[Pipeline QGIS]] |
| 31c | Les couches s'appellent `ilots` et `routes`, les champs `hierarchie` / `largeur_m` / `fonction` / `sous_type` / `exception` / `surface_m2` | 🔓 | ✅ 2026-08-10. `routes` et non `rues` : c'est le nom réel dans le fichier |
| 31d | **La largeur d'une rue varie autour de sa base** — tissu desservi et longueur du tronçon | 🟡 | ✅ 2026-08-10. Une largeur constante par hiérarchie ne donne que 4 valeurs distinctes : un seuil n'a alors que 3 réglages, et « doctrine à seuil » devient une case à cocher. 39 largeurs distinctes sur les rues → [[Géométrie et données]] |
| 32 | 2 champs saisis à la main, le reste dérivé par CASE ; flag `exception` | 🔒 | **17 exceptions posées** sur [[Wehrau]] — cible ~20 tenue |
| 32b | **13 `sous_type`**, pour ~12 visés | 🟡 | ✅ 2026-08-10 → [[Wehrau]]. Chacun est une ligne de table de correspondance : si la dérivation devient pénible, couper ici |
| 32c | **Une caractéristique de voirie ne devient pas un type d'îlot** | 🔓 | ✅ 2026-08-10. `quai_voie_rapide` a été créé puis supprimé : la voie rapide de berge est une largeur de rue, pas une nature d'îlot. Règle générale à tenir |
| 32d | **Un attribut ne s'écrit que s'il débloque une décision nommée** | 🔒 | ✅ 2026-08-10. Critère appliqué aux 12 champs d'îlot et 4 champs de rue de l'étape 5. Ce qui décrit sans rien débloquer ne s'écrit pas → [[Géométrie et données]] |
| 32e | **Le relief est du design, pas une mesure** — pas de MNT, une pente qui s'adoucit vers l'aval | 🟡 | ✅ 2026-08-10. 3,2 % en amont, 1,3 % en aval. Met l'injustice amont/aval dans le terrain, pas dans un coefficient |
| 33 | `.qml` = référence couleur unique QGIS ↔ Godot | 🔓 | |
| 34 | **Simulation agrégée**, pas d'agents individuels | 🔒 | Conditionne tout le reste |
| 35 | **La parcelle est l'entité persistante**, seedée individuellement | 🔒 | Sinon la mémoire de transformation est détruite |
| 36 | Pas de plugin IA dans QGIS — workflow PyQGIS relu et collé | 🔓 | |
| 37 | **Pas de SVG** en import QGIS — PNG + world file + décalquage | 🔒 | |

## Production

| # | Décision | | Note |
|---|---|---|---|
| 38 | **Prototype papier rejeté** → QGIS + tableur | 🔓 | Ce qui compte est la vitesse d'itération |
| 39 | Pas de Godot avant le mois 2 | 🔓 | |
| 40 | **J'écris le noyau de simulation moi-même** | 🔒 | Le reste = échafaudage jetable |
| 41 | Godot 4 privilégié, C# isolé derrière une interface propre | 🟡 | Pas verrouillé |
| 42 | Low-poly flat-shaded, référence Mini Motorways | 🔓 | Réversible |
| 43 | **Pixel art écarté** | 🔓 | Pas paramétrique |
| 44 | Lancement **EN + DE** uniquement | 🔓 | |
| 45 | i18n + glossaire **dès le jour 1** | 🔒 | |
| 46 | Cible **~10 000 mots** de texte | 🔓 | |
| 47 | Page Steam en ligne tôt comme test de marché | 🔓 | |
| 48 | Pas de dépense avant le vertical slice | 🔓 | |

**Voir aussi** : [[Questions ouvertes]] · [[00 - Index]]
