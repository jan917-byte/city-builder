---
tags: [ville, prototype, level-design]
statut: 🎯 périmètre du prototype
maj: 2026-08-18
habitants: 5350  # arrêté le 2026-08-11 → Décisions arrêtées 13d
---

# Wehrau

> 🎯 **C'est le périmètre du prototype.** Tout le mois 1 se joue ici.
> **Wehrau n'est pas [[Vallmar]]** — c'est une autre ville, plus petite, qu'on voit **en entier**. Vallmar reste la ville visée pour le jeu complet ; on verra plus tard si ce centre y devient un quartier.

**Une rivière : l'Ilse. Une petite ville qu'on tient tout entière dans un écran.**

> ✅ **Les noms sont arrêtés le 2026-08-12 : la ville est Wehrau, la rivière est l'Ilse.** Ils étaient proposés depuis le 2026-08-10 et la fenêtre pour renommer sans frais se refermait — le générateur de parcelles est le moment où les noms entrent dans le code. → [[Décisions arrêtées]] 13f

> ✅ **5 350 habitants, arrêté le 2026-08-11.** Le vault annonçait 18 000 ; la carte, une fois les densités posées, en porte 5 350 sur 38,3 ha bâtis, et c'est la carte qui gagne. Il aurait fallu 470 hab/ha bâti pour tenir 18 000, quand un centre allemand dense plafonne vers 350. Wehrau est une **petite ville de marché** — c'est le cadre le plus lisible pour l'histoire qu'on raconte, puisque la place du marché y est *la* place. → [[Décisions arrêtées]] 13d

## Ce qui ne va pas ici, en quatre phrases

1. **La place du marché est un parking.** C'est le point le plus central de la ville, il touche l'eau, et il est couvert de voitures depuis 1968.
2. **La ville a été coupée de sa rivière** par une voie rapide de berge, sur la rive gauche, là où le centre la touchait.
3. **Une route de transit traverse le cœur du nord au sud** — c'est aussi la rue commerçante, donc la toucher, c'est toucher les commerçants.
4. **En aval, un grand ensemble de 1974 est posé dans la plaine élargie** — la ville envoie sa crue sur ceux qui n'ont pas voix au chapitre. C'est l'îlot le plus en aval de toute la carte, et de loin le plus fragile. ✅ **Il reste où il est** : à 199 m de l'eau, pas les pieds dedans — ce qui l'expose n'est pas la proximité, c'est d'être en **bout de chaîne** → [[Décisions arrêtées]] 13e

> 🔄 **La galerie de 1971 sort de la carte le 2026-08-18.** L'ancien îlot 45
> est coupé par une nouvelle rue en **45 et 72**, deux fronts commerçants. La
> catégorie qui ne servait qu'à cette galerie disparaît. → [[Décisions arrêtées]] 71

C'est la sortie attendue de la semaine 1. → [[Plan 3 mois]]

## La carte

**0,93 km² · 71 polygones · 13,8 km de voirie · EPSG:25832**

| | |
|---|---|
| îlots bâtis | 55 |
| champs (hors les murs) | 7 |
| morceaux de rivière | 6 — l'Ilse est découpée par ses franchissements |
| exceptions de level design | 16 (cible du vault : ~20) |

La ville est un **noyau ovale d'environ 900 × 1 000 m**, avec cinq routes radiales qui sortent vers la campagne. Autour, des champs : ce n'est pas un décor en attente, c'est **la réserve foncière et l'espace d'expansion de crue**.

**L'Ilse traverse la carte du nord au sud en décrivant un grand S** : elle entre au nord-est, mord vers l'ouest à mi-hauteur, ressort au sud-est. Trois franchissements relient ses deux rives. Ce méandre n'est pas un détail de dessin — c'est lui qui fait que **Wehrau est une ville de rive droite avec un petit faubourg en face** : 52 îlots d'un côté, 13 de l'autre.

> ✅ **Trois franchissements** depuis le 2026-08-12 : les tronçons 136 et 171
> ont disparu, le réseau routier reste d'un seul tenant. → [[Décisions arrêtées]] 30c

Fichier : `QGIS/data/Prototype_qualifie.gpkg` → [[Pipeline QGIS]]

## Ce que la ville pèse

| | |
|---|---|
| logements | 2 726 |
| habitants | 5 725 mesurés — cible ~5 350, [[Décisions arrêtées]] 13d |
| surface bâtie | 38,0 ha (sur 92,8 ha d'emprise) |
| places de stationnement | 4 338, dont 3 310 sur rue — **1,59 place par logement** |
| franchissements de l'Ilse | **3** (30c) |

> **1,59 place par logement.** C'est le chiffre qui dit ce qu'est cette ville
> en 1965 : un stock de voitures rangé partout, dont **1 028 places sur les
> îlots eux-mêmes**. Chaque décision qui touche l'emprise publique se paiera
> là-dessus. → [[Ressources]]

## Les deux rives

| | îlots | logements | aléa moyen |
|---|---|---|---|
| rive droite (la ville) | 52 | 2 235 | 0,43 |
| rive gauche (le faubourg) | 13 | 417 | 0,75 |

**C'est le faubourg qui est exposé, pas la ville.** Treize îlots, un sixième du parc, un aléa presque deux fois supérieur — et personne pour peser dans un conseil municipal.

## L'ouverture : la crue

✅ **Arrêté le 2026-08-11 : le jeu s'ouvre sur une crue, et elle tombe sur la rive gauche.** → [[Décisions arrêtées]] 23b

Des ruines encore chaudes sur les treize îlots du faubourg, 417 logements touchés — et **une seconde crue annoncée**. C'est l'annonce qui fait le jeu : sans elle, « ne pas reconstruire » est un choix sentimental ; avec elle, c'est un calcul.

Cette réparation forme le prologue : **seule l'adaptation est en jeu**. La réduction des émissions entre lorsque la ville tient de nouveau. → [[Adaptation et réduction]] · [[Décisions arrêtées]] 72

Ce que la carte porte, si on veut chiffrer l'événement :

| Niveau | Îlots touchés | Logements | Part du parc |
|---|---|---|---|
| +2 m | 23 | 935 | 37 % |
| +3 m | 30 | 1 320 | 52 % |

Ce n'est pas la ville industrielle sinistrée du brainstorm d'origine : c'est **le petit bout de ville d'en face**, celui qu'on pourrait décider de ne pas relever. Plus dur, et plus juste par rapport à ce que dit la géométrie — l'amont imperméabilise, l'aval encaisse.

⚠️ **Ce qui reste à écrire** : quelles décisions le premier tour propose, et laquelle est « rendre à l'eau ». C'est le travail de la semaine 2. → [[Décisions]] · [[Plan 3 mois]]

## Le tissu

| `sous_type` | `fonction` | n | Ce que ça joue |
|---|---|---|---|
| `maisons_de_ville` | habitation | 20 | le tissu ordinaire, la matière de fond |
| `coeur_ancien` | mixte | 13 | parcellaire fin, mitoyen, cours minérales |
| `pavillonnaire` | habitation | 12 | la frange, la plus dure à faire bouger |
| `champ` | freiraum | 7 | hors les murs — ce qui peut recevoir l'eau |
| `riviere` | riviere | 6 | l'Ilse, canalisée |
| `front_commercant` | mixte | 5 | les commerçants organisés, dont les nouveaux îlots 45 et 72 |
| `equipement` | mixte | 2 | église protégée · lycée |
| `friche_industrielle` | industrie | 2 | le moulin et la brasserie, en aval |
| `place_minerale` | freiraum | 1 | 🔴 la place du marché, devenue parking |
| `barre_1970` | habitation | 1 | 🔴 le grand ensemble en aval |
| `parc` | freiraum | 1 | le jardin de ville |
| `jardins_familiaux` | freiraum | 1 | la réserve de terre la plus facile à mobiliser |

**12 sous-types**, exactement la cible de [[Géométrie et données]]. Chacun est une ligne de table de correspondance à remplir : si l'étape de dérivation devient pénible, c'est ici qu'il faut couper.

> ⛪ **L'îlot 16 est l'église du village.** Il est classé équipement et protégé :
> son toit existe dans la géométrie (**172 m²**), mais expose **0 m² équipable** au système
> énergie. Le jeu refuse donc toute pose et en donne la raison. → [[Décisions arrêtées]] 71

> 🔴 **La voie rapide de berge n'est pas un type d'îlot.** Elle a d'abord été encodée comme tel (`quai_voie_rapide`), à tort : c'est une propriété de la **rue** — 22 m de largeur sur les tronçons de rive de la rive gauche. Les îlots derrière sont du tissu ordinaire. La plaie est entière, elle est juste au bon endroit dans les données.

> ✅ **Wehrau est un dortoir, et on l'assume** — arrêté le 2026-08-12. **943 emplois pour 5 725 habitants, soit 0,16 par habitant**, quand une petite ville allemande comparable tourne entre 0,35 et 0,50. Ce n'est pas un coefficient mal réglé : il n'y a que 10,4 ha d'activité sur 38 ha bâtis. Ce que ça achète, c'est une ville cohérente avec elle-même — l'axe de transit saturé et les 0,76 place par habitant deviennent des **symptômes**, pas des anomalies — et un levier unique : **reconvertir le moulin et la brasserie est le seul levier d'emploi de la ville.** Ce que ça coûte, assumé : *une ville sans travail est une ville sans matin*, et le mouvement du matin **sort** de la carte. → [[Décisions arrêtées]] 50b

> Wehrau n'a **pas d'hôpital** sur la carte. Un choix, pas un oubli : à cette échelle il est hors emprise, voire dans la ville voisine. Il se remet en ajoutant un `fid` dans `EQUIPEMENTS`.

## Les trois plaies de 1965

Le principe : *dur mais réparable*. Chaque plaie se répare par une décision **différente**, et aucune ne se répare gratuitement. → [[Ton et règles d'écriture]]

| La plaie | Où | Ce que sa réparation coûte |
|---|---|---|
| La place-parking | îlot 19, le plus central, à 41 m de l'eau · aléa 0,86 · **127 places** | le stationnement du centre, donc les commerçants |
| Le quai en voie rapide | les tronçons de rive à 22 m | le report de trafic sur le reste du réseau |
| L'axe de transit | traverse le cœur du nord au sud | c'est la rue commerçante : conflit frontal |

> **L'axe de transit n'a pas eu besoin d'être désigné : il sort tout seul des données.** L'affectation de trafic minimale — plus court chemin en temps, entre les cinq radiales et entre les carrefours — fait apparaître une épine rouge nord-sud qui traverse le cœur. Le récit du vault et la mesure disent la même chose. → `apercu_carte.py --calque=charge`

**La place-parking est la candidate au titre de « LA décision la plus satisfaisante »** : elle est centrale, elle est visible, et la libérer rend la rivière au centre-ville du même geste. → [[Questions ouvertes]]

## Ce que Wehrau permet et que l'Altstadt seule ne permettait pas

**L'amont et l'aval sont dans la carte.** L'Ilse entre au nord et sort au sud ; le grand ensemble de 1974 et les friches sont en aval, le centre marchand est au milieu. Autrement dit : **la ville qui cause la crue et la ville qui la subit sont dans le même écran**, et le joueur peut faire les deux.

Et ce n'est pas qu'une affaire de position sur une ligne : **la vallée s'élargit vers l'aval**, donc à distance égale de l'eau on y est plus exposé. Aléa moyen 0,41 en amont, 0,51 en aval. L'injustice est dans le terrain, pas dans un coefficient. → [[Géométrie et données]]

C'est le pilier « le lieu change le résultat », testable dès le mois 1. → [[Périmètre et coupes]]

## Rapport à Vallmar

[[Vallmar]] reste la ville du jeu complet : 112 000 habitants, six quartiers, une structure qui encode des injustices que Wehrau ne peut qu'esquisser. Rien de ce qui suit n'est annulé — c'est du design en réserve.

Ce que Wehrau sert à savoir : **est-ce que la forme des décisions tient ?** Si elle tient à cette échelle, on la porte à 112 000. Si elle ne tient pas, on n'a pas perdu six quartiers dessinés pour rien.

**Voir aussi** : [[Vallmar]] · [[Pipeline QGIS]] · [[Périmètre et coupes]] · [[Décisions]]
