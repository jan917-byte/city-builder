# Le prototype — ce qu'on construit, étape par étape

> **Ce dossier est le chantier ; le vault est la tête.** Les règles de partage sont dans `CLAUDE.md` §2 et n'ont pas à être répétées ici.
> **Une seule étape est ouverte à la fois**, et elle se termine quand **son critère est vu à l'écran**. **Plafond de ce fichier : 60 lignes.**

## Les étapes

| | L'étape | État | Son critère de réussite |
|---|---|---|---|
| 1 | **La carte** — îlots, rues, attributs | ✅ | la ville privée de sa rivière tombe en deux morceaux · le réseau tient d'un seul tenant · l'axe de transit sort tout seul |
| 2 | **[Les parcelles](Parcelles.md)** | ⏸️ **en pause** | la surface de toit mesurée retombe sur le coefficient de l'énergie · le cœur ancien ressemble à un cœur ancien |
| 3 | **[L'énergie](Énergie.md)** — une décision, deux échelles | ✅ **à regarder** | cliquer un îlot, le passer de 0 à 100 % solaire, voir ses toits et les quatre totaux de ville changer |
| 4 | **[Les toits et le sol](Toits%20et%20sol.md)** | ⏸️ **en pause** | croire qu'on y habite |
| 5 | **[Le trafic visible](Trafic.md)** | 🎯 **ouverte** | une rue à `charge = 1,00` est désagréable à regarder |
| 6 | **Le thème suivant** | ☐ | il s'écrit en trois pièces, sans toucher à la machinerie |

⏸️ **Les étapes 2 et 4 sont en pause, pas finies** : leurs critères n'ont pas été vus à l'écran. L'auteur a ouvert la 5 explicitement ; la règle d'une seule étape ouverte tient.

## Ce qui commande le prototype

- 🎯 **Une seule décision testée** (68), mais elle a un prix et un rendement qui dépendent du tissu (69) : le prototype teste le lien **local → global**, et « où investir ? ».
- 🔗 **La 3D et l'énergie se rejoignent sur le toit** (41 · 56 · 64) : la 3D produit `toit_m2`, `toit_pente`, `toit_plat_m2` et l'ombrage ; l'énergie les lit sans savoir qui parle. 🔴 **L'énergie n'attend jamais la 3D** — le prototype reste jouable avec les toits estimés.
- 🏘️ **Le prototype est Wehrau**, une ville entière qu'on voit en entier (13b · 13d) : elle a un amont et un aval, un quartier n'en a pas.
- 🎨 **Townscaper pour le rendu** (42b), **Wehrau pastel au sol minéral** (42c) — le pastel étant celui des **murs** seulement depuis le 2026-08-18.
- 🗺️ **La carte est plate**, dans l'image et dans la donnée. Le seul relief est le chenal de l'Ilse (fond à −2,85 m, nappe à −2 m) et le talus des 4 champs riverains. La voirie reste à 0 : **aucune ligne de code ne parle de pont**.
- 💧 **La crue revient, sur la branche `crue` seulement** (23b) → [Crue](Crue.md). `alea` est rallumé et le faubourg de rive gauche est sinistré ; `altitude_relative` reste à 0, la carte reste plate. Sur `master`, la phrase d'avant tient toujours : ce qui reste de l'eau est ce qui reste vrai sans elle — deux rives inégales et trois franchissements.
- 🏛️ **La ville possède tout, logement compris** (70) — mais **posséder un logement n'est pas payer sa facture** : la ville est propriétaire-bailleur, ses locataires paient leur électricité.

## Les tables que l'auteur règle

Ce sont **elles, et pas le code**, qui décident de ce qu'on voit. Une ligne changée, on relance, on regarde. Le contrôle n'est pas « est-ce juste » mais ***« est-ce qu'on croirait y habiter »***.

| La table | Où | Ce qu'elle décide |
|---|---|---|
| les listes de `fid` | haut de `02_qualifier.py` | quel îlot est quoi, `PONTS_SUPPRIMES` compris |
| `TISSU` | `04_deriver_attributs.py` | densité, hauteur, imperméabilisation, canopée, parking — le comportement de la carte |
| `TISSU` | `04c_parcelles.py` | largeur de façade, profondeur, `style` (`peigne` ou `boite`) — **le grain de toute la ville** |
| `TISSU` | `04d_emprises_batiments.py` | recul, retraits, profondeur, plafond d'emprise, famille de forme — l'empreinte du bâtiment |
| les sept nombres de la crue | haut de `04e_crue.py` | qui est ruiné, qui est mouillé, quel pont est coupé — **branche `crue`** |
| `TOITURES` · `ENDUITS` | `palette.py` | les matériaux du bâti — la couleur de la ville depuis le 2026-08-18 |
| `BATI` | `07_exporter_godot.py` | **la pente du toit seulement** |
| les six nombres de la berge, **les deux du toit vert** | haut de `ville.gd` | prix et durée, et **combien de crue rachètent un mètre de rive rendue et un hectare verdi** |
| 🏢 les cinq nombres de la densification | haut de `ville.gd` | prix du logement posé, durée, loyer, entretien, plafond d'étages |
| `DENSE_INTERDIT` · le m² brut par logement | haut de `07`, haut de `04d` | **qui a le droit de monter**, et combien de logements un étage ajoute |
| les quatre nombres de la plantation | haut de `ville.gd` | prix de l'arbre, durée de reprise, plafond de canopée, et **ce qu'un arbre épargne** |

🔴 Dans `04d.TISSU`, le retrait latéral à 0 fait le mitoyen, et il n'est **réversible que dans un sens** (61).

## La dette — ce qui ment tant que ce n'est pas payé

Aucune n'est sur le chemin critique, mais chacune fausse un chiffre.

- 🔴 **Calibrer les deux formules de budget** (59) : recettes ∝ `logements`, charges ∝ mètres de voirie. Le contrôle nommé — *une densification pure ne doit pas s'autofinancer* — **tourne et passe** depuis le 2026-09-03 (`--essai`), mais sur les seuls logements neufs : le parc existant ne paie ni ne rapporte encore. Le budget ne mord toujours jamais (418/500, +152 de solde, aucune décision refusée sur trois parties).
- ✅ **`logements` sort du plancher mesuré** (2026-09-03) — emprise bâtie × niveaux ÷ **101 m² bruts**, écrit par `04d`. La ville ne bouge presque pas (**2 705 → 2 645**), ça redistribue entre îlots, et **ajouter un étage ajoute enfin des habitants**. 04 garde QUI loge, la mesure dit COMBIEN. → [Densifier](Densifier.md)
- 🟠 **La recette de fenêtres compte les étages depuis le zéro MONDE, pas depuis le pied du mur** — or les deux rives sont à **±1 m** (`RIVE_GAUCHE_Y`, `RIVE_DROITE_Y` dans `07`). Rive droite, l'allège du rez tombe **au niveau du sol** ; rive gauche, elle flotte **2 m au-dessus**. Trouvé le 2026-09-03 en posant la couture du bardage, qui doit se recaler sur cette trame pour ne pas couper une fenêtre en deux. Le jour où la fenêtre part du pied du mur, ce recalage saute.
- 🔴 **Repondérer les trois moyennes** (63) : `canopee_moy` et `impermeabilise_moy` par la surface, `riverain_moy` par la population — dans `08_jouer.py` **et** `ville.gd`, puis refaire le recoupement.
- 🔴 **`largeur_m >= 20`, la cible de D05, ne prend pas l'axe** : sur les **16 tronçons au-dessus de 0,80, 5 seulement font 20 m** ; les 11 autres en font 18. D05 ne ferme pas l'axe de transit, elle en ferme cinq bouts. **Deux mètres de seuil décident si la décision existe.** 🔄 Remesuré le 2026-08-24 : l'ancienne liste (13, 21, 54, 55) datait du comptage de charge corrigé depuis.
- 🔴 **La montée de D07 est de 60 mois** : sur une partie, l'arbre ne reprend jamais ses mètres à la noue, donc la concurrence arbre/noue ne se joue pas.
- **`stationnement` porte deux sens** — part de surface sur l'îlot, places sur rue sur le tronçon. **À renommer avant d'écrire l'indicateur**, sinon quelque chose les additionnera. 🔄 Mesuré le 2026-08-19 : **3 310** places sur les tronçons, **1 028** sur les îlots (dont 127 sur la seule place-parking, les 901 autres sous du bâti, donc invisibles par construction). L'ancien chiffre unique de « 4 587 » ne correspond à aucune des deux colonnes — exactement le symptôme que cette ligne annonce.
- **Vérifier que chaque indicateur a un antagoniste** : les bornes sont la ceinture, le frein ce sont les antagonismes.
- **Trois valeurs à t0 manquent** (la ville exposée, le CO₂, la desserte) et **`confort_ete` n'existe pas dans le `.gpkg`** — seule variable de D10, créée à 0.
- **La deuxième décision dans Godot** : la candidate est **D06 supprimer le stationnement**, c'est elle qui libère l'emprise de D07 et D08.
- **Sans urgence** : digérer le brainstorm du 2026-08-11 (9 décisions, 7 questions) · le tag `jeu/brightvale` · les conséquences de 5 350 hab. — **la barre est faite** le 2026-08-19 (trois dalles de 46 à 58 m, 6 niveaux, 99 logements), ~~reste le lycée~~ — l'îlot 36 est **l'université** et l'îlot 20 **la mairie** (75 · 76) ; ce qu'on y fait est arrêté le 2026-09-02 (**79** le labo qu'on finance · **80** les règles et les subventions) et une **version simple est branchée** le 2026-09-02 (81 : deux portes, et la fiche d'îlot reste la fiche de l'îlot) → [Recherche et mairie](Recherche%20et%20mairie.md) ; le nom de l'université reste à trancher (13d le voulait en Realschule) · quatre vestiges du dossier QGIS, aucun bloquant : `apercu_carte.py` plante sur un clone frais (`rendus/` est gitignoré et le script ne le crée pas) · `01_champs_et_valuemaps.py` a divergé de `02` · `classification.json` n'est jamais lu · `00b_mettre_a_echelle.py` vise `Vallmar2.gpkg`, disparu le 2026-08-17 · et `routes` garde la colonne `hierarchy` d'origine à côté de `hierarchie`.
