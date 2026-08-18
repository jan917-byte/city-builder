---
tags: [technique, QGIS, données, actif]
statut: en cours — la carte est simulable, reste l'export
maj: 2026-08-10
---

# Pipeline QGIS

> **Périmètre du prototype : [[Wehrau]]**, une petite ville entière. → [[Périmètre et coupes]]

## Le workflow réel

```
1. CARTE GÉNÉRÉE        Vallmar2.gpkg — ilots + routes, EPSG:25832   ✅
2. QUALIFICATION        fonction / sous_type / exception             ✅
3. HIÉRARCHIE + LARGEUR sur les 178 tronçons                         ✅
4. ADJACENCE            quel type de rue sépare quels îlots          ✅
5. ATTRIBUTS DÉRIVÉS    densité, eau, charge, emprise libre…         ✅
6. EXPORT GeoJSON       → Godot, mois 2                              ☐
```

**La carte est simulable.** Les cinq premières étapes sont faites : chaque îlot et chaque tronçon portent les entrées dont une décision a besoin.

🔄 **Révision du 2026-08-10 : le tracé manuel intégral est abandonné.** La carte générée donne en une soirée une structure meilleure que ce qu'un tracé à la main produisait en une semaine. Le tracé manuel reste l'outil de **retouche** — ouvrir une percée, fermer une impasse, ajouter une passerelle — pas de création. → [[Décisions arrêtées]] 31b

## L'état du fichier

| | |
|---|---|
| Source intouchée | `QGIS/data/Vallmar2.gpkg` |
| Fichier de travail | `QGIS/data/Prototype_qualifie.gpkg` |
| Emprise | 0,93 km² · 898 × 1 036 m |
| `ilots` | 69 polygones — 56 bâtis, 7 champs, 6 morceaux de rivière |
| `routes` | 178 tronçons · 13,6 km · médiane 62 m |

**Contrôle fait** : 297 sommets d'îlots sur 300 tombent à moins de 10 cm d'une ligne de `routes`. La polygonisation est cohérente avec le réseau — donc l'adjacence par la rue est calculable. → [[Géométrie et données]]

## Les outils

Quatre scripts dans `QGIS/scripts/`. Les données sont dans `QGIS/data/`, les préviews dans `QGIS/rendus/`. Aucun n'écrit dans `Vallmar2.gpkg`.

### `apercu_carte.py` — la boucle de contrôle

```
python QGIS/scripts/apercu_carte.py QGIS/data/Vallmar2.gpkg            # la source
python QGIS/scripts/apercu_carte.py QGIS/data/Prototype_qualifie.gpkg  # la version qualifiée
```

Sort un PNG légendé et un bilan chiffré : nombre d'îlots, linéaire, ce qui est renseigné et ce qui ne l'est pas, brins morts. **Lecture seule** (SQLite en mode `ro`) : tourne pendant que QGIS est ouvert. C'est ce qui permet de regarder la ville à deux au lieu de la décrire.

### `02_qualifier.py` — le level design

Tout le level design est en haut du fichier, en listes de `fid`. On change une ligne, on relance, on regarde. C'est ce qui rend l'itération gratuite — le principe qui gouverne le mois 1. → [[Plan 3 mois]]

### `01_champs_et_valuemaps.py` — pour la saisie dans QGIS

À coller dans la console Python de QGIS **sur une copie**, si on préfère qualifier à la souris en vue formulaire plutôt que par listes de `fid`. Pose les champs et les listes déroulantes. Démarre en `SIMULATION = True`.

### `03_adjacences.py` — la table d'adjacence ✅

**L'étape qui rend la carte non décorative.** Pour chaque paire d'îlots qui se touchent : la frontière partagée, la `hierarchie` de la rue qui la porte, et une perméabilité.

**179 paires · 13,60 km de frontières partagées.** Le total est exactement le linéaire de voirie : **aucune frontière ne tombe en `sans_rue`**. Les deux couches sont cohérentes de bout en bout.

Répartition : rue 101 · boulevard 40 · rive 21 · ruelle 17. Voisins par îlot : min 3 · médiane 5 · max 13. Neuf îlots touchent le bord de carte (3 862 m), stockés en `bord_carte_m` — un bord de carte n'est pas une rue, et il ne doit pas être confondu avec une donnée manquante.

> **Contrôle qui compte** : la ville privée de sa rivière et de ses champs tombe en **deux morceaux (45 et 11 îlots)**. La rivière coupe pour de bon. Les îlots ne se touchent jamais par-dessus l'eau ; seules les routes la franchissent, par cinq ponts. La coupure est dans la géométrie, pas dans une convention de code.

### `04_deriver_attributs.py` — les attributs dérivés ✅

Deux champs sont saisis à la main, tout le reste se dérive ici. La règle qui a présidé au choix des colonnes : **chacune doit répondre à « quelle décision devient possible ? »**. Une colonne qui ne débloque aucune décision n'est pas écrite. → [[Géométrie et données]]

`--blanc` fait un dry-run : tout est calculé et affiché, rien n'est écrit. **C'est le mode par défaut du travail** — on regarde le compte rendu, on ajuste la table en tête de fichier, on relance.

Le compte rendu sert de contrôle, pas de décoration. Il sort quatre choses qu'on ne voit pas sur la carte :

- **la population que la carte porte réellement** — 2 726 logements, 5 725 habitants sur 38,0 ha bâtis
- **les quatre îlots repères relus dans les données** : la place-parking, la barre et les deux friches, avec leur rive, leur position sur le fil de l'eau, leur distance à l'Ilse et leur stationnement
- **la courbe de la doctrine à seuil** : combien de rues sont concernées par « je plante au-delà de X m d'emprise libre », pour X de 2 à 9 m
- **la connexité du réseau routier**, qui est ce qui a révélé l'absence de ponts

## ☐ Ce qui reste

### 6. L'export GeoJSON

`ilots`, `routes`, `adjacences`. Mois 2. → [[Plan 3 mois]]

### `apercu_carte.py --calque=<champ>` — voir un attribut

```
python QGIS/scripts/apercu_carte.py QGIS/data/Prototype_qualifie.gpkg --calque=alea
python QGIS/scripts/apercu_carte.py QGIS/data/Prototype_qualifie.gpkg --calque=charge
```

N'importe quel champ numérique, en dégradé du froid au chaud. Sur les îlots si le champ y est, sinon sur les traits de rue. C'est ce qui permet de vérifier un attribut **en le regardant** au lieu de lire une colonne : `charge` fait apparaître l'axe de transit tout seul, sans qu'on ait eu à le désigner.

## Pièges vérifiés sur ce fichier

- **`ST_IsEmpty` manquante.** Les déclencheurs d'index spatial du GeoPackage appellent des fonctions spatiales que SQLite seul n'a pas. Écrire un attribut sans les fournir échoue. `02_qualifier.py` les branche.
- **Console Windows en cp1252.** Un simple `é` dans un `print` fait planter un script. Reconfigurer `sys.stdout` en UTF-8 en tête de fichier.
- **Les 8 « brins morts »** sont les radiales qui sortent vers la campagne. Ce ne sont pas des erreurs : le bord de l'emprise n'est pas une rue. Ne pas les « corriger ».
- 🔴 **Les ponts se déguisent en rives.** Un franchissement longe le polygone rivière : la règle « borde la rivière → `hierarchie = rive` » l'avale, et la ville se retrouve **sans aucun pont** — deux réseaux routiers étanches, sans que rien ne le signale. Ce qui distingue un pont d'une berge : **il sépare deux morceaux de rivière**, puisque c'est lui qui l'a découpée. Corrigé le 2026-08-10, cinq franchissements retrouvés.
- **Un graphe de rues ne se construit pas sur les extrémités de tronçons.** Une rue qui se raccorde en T au milieu d'un autre tronçon serait vue comme déconnectée. Prendre **tous les sommets** comme nœuds.
- **Une largeur constante par hiérarchie rend tout seuil inopérant** — quatre largeurs distinctes, donc trois réglages possibles, donc pas d'arbitrage. → [[Décisions arrêtées]] 31d

**Voir aussi** : [[Géométrie et données]] · [[Wehrau]] · [[Plan 3 mois]]
