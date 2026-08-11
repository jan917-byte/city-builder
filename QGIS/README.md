# QGIS — la carte de Wehrau

> Ce dossier fabrique **la carte simulable du prototype**. Il ne contient pas de design : le design est dans le vault, et ce document y **pointe** au lieu de le recopier.
> → `Vault - Jeu urbanisme/Technique/Pipeline QGIS.md` et `…/Géométrie et données.md`
>
> Chiffres de ce document **vérifiés le 2026-08-11** en relisant `Prototype_qualifie.gpkg` et en relançant `04 --blanc`.

La ville du prototype est **Wehrau**, pas Vallmar. Le fichier source s'appelle encore `Vallmar2.gpkg` — c'est un nom d'export, pas une ville. Ne pas le renommer tant que rien ne le justifie : c'est la seule chose qui n'a jamais été touchée.

---

## 1. Ce que fait ce dossier, en une phrase

Une couche de **lignes** dessinée dans QGIS est polygonisée en **îlots** ; quatre scripts Python y écrivent, couche par couche, tout ce dont une décision de jeu aura besoin — le type de tissu, ce qui sépare deux îlots, la hauteur d'eau, la charge de trafic — et un cinquième script permet de **regarder** le résultat au lieu de lire des colonnes.

Le produit final n'est pas une carte. C'est **un GeoPackage dont chaque colonne répond à « quelle décision devient possible ? »**.

## 2. Arborescence

```
QGIS/
├─ README.md                     ← ce fichier
├─ data/
│   ├─ Vallmar2.gpkg             🔒 la SOURCE, jamais écrite   (184 Ko)
│   └─ Prototype_qualifie.gpkg   ⚙️ le fichier de travail, régénérable  (217 Ko)
├─ scripts/
│   ├─ 01_champs_et_valuemaps.py    (console QGIS — optionnel, hors chaîne)
│   ├─ 02_qualifier.py              ① le level design
│   ├─ 03_adjacences.py             ② le graphe
│   ├─ 04_deriver_attributs.py      ③ les attributs dérivés
│   ├─ apercu_carte.py              👁 la boucle de contrôle (lecture seule)
│   └─ classification.json          (vestige — voir §8)
└─ rendus/                        PNG régénérables, **gitignoré** (absent d'un clone frais)
```

Les deux `.gpkg` sont versionnés. Ce sont des **binaires : git ne les fusionne pas.** Le travail QGIS se fait sur une machine à la fois. → `CLAUDE.md` §5 bis

## 3. Le pipeline

```
   ┌──────────────────┐
   │ Vallmar2.gpkg    │  ilots(69) + routes(178), EPSG:25832, aucun attribut
   │ 🔒 lecture seule │  sauf `hierarchy` (l'export d'origine)
   └────────┬─────────┘
            │  02_qualifier.py   ← COPIE le fichier, puis écrit
            ▼
   ┌──────────────────────────────────────────────────────┐
   │ Prototype_qualifie.gpkg                              │
   │   ilots   + fonction, sous_type, exception, surface  │
   │   routes  + hierarchie, largeur_m                    │
   └────────┬─────────────────────────────────────────────┘
            │  03_adjacences.py  ← écrit en place
            ▼
   │   + table `adjacences` (179 lignes)
   │   + ilots.bord_carte_m
            │  04_deriver_attributs.py  ← écrit en place
            ▼
   │   + 12 colonnes sur ilots · 4 sur routes
            │
            ▼  apercu_carte.py (ro)          ▼  export GeoJSON → Godot  ☐ mois 2
       PNG légendé + bilan chiffré
```

### ⚠️ La règle de la chaîne

**02 → 03 → 04, dans cet ordre, sans en sauter.** `02_qualifier.py` fait un `shutil.copy2` de la source : il **écrase** `Prototype_qualifie.gpkg` et détruit tout ce que 03 et 04 y avaient écrit. Relancer 02 seul laisse un fichier amputé de la table `adjacences` — et 04 refuse alors de démarrer.

Ce qu'on peut relancer seul, sans risque : **03**, **04**, et **`apercu_carte.py`** (lecture seule, tourne même avec QGIS ouvert sur le fichier).

### Étape 6, la seule qui reste

**Export GeoJSON** (`ilots`, `routes`, `adjacences`) vers Godot. Prévu mois 2. Rien n'est écrit pour l'instant.

## 4. Les fichiers, un par un

### `02_qualifier.py` — le level design (382 l.)

**C'est le fichier le plus important du dossier avec 04.** Tout le level design tient dans une trentaine de lignes en haut du fichier, sous forme de **listes de `fid`** :

```python
RIVIERE = [4, 7, 51, 52, 54, 57]
PLACE_PARKING = [19]        # la place du marché, la plus centrale, sur l'eau
DALLE = [45]                # l'îlot rasé en 1971
FRICHES = [31, 65]          # le moulin et la brasserie, en aval
BARRE = [32]                # le grand ensemble de 1974
…
```

On change une ligne, on relance la chaîne, on regarde le PNG. **L'itération est gratuite, et c'est tout l'intérêt du dispositif.** Tout îlot non listé tombe par défaut en `maisons_de_ville`.

Deux garde-fous intégrés :
- un `fid` affecté à deux sous-types fait planter le script avec le numéro fautif — pas de silence
- `exception = 1` marque les îlots posés à la main, par opposition au tissu dérivé par règle. **17 exceptions**, cible du vault ≈ 20. ✅

Ce fichier décide aussi de la **hiérarchie et de la largeur des 178 tronçons**, par un arbre de règles, dans cet ordre : pont → quai à voie rapide → berge → boulevard hérité → route de campagne → ruelle de cœur → rue. Puis il **module** la largeur selon le tissu desservi (ancien −2 m, moderne +2 m, campagne +1 m) et la longueur (+1 m par 60 m, plafonné à +3 m).

> 🔴 **Pourquoi cette modulation existe.** Une largeur constante par hiérarchie donne quatre valeurs distinctes sur toute la carte, donc trois réglages possibles pour un seuil, donc **aucun arbitrage**. La variation n'est pas du réalisme décoratif : elle est ce qui rend la « doctrine à seuil » jouable. → `Décisions arrêtées` 31d

> 🔴 **La règle qui a coûté le plus cher.** Un pont longe le polygone rivière exactement comme une berge. La règle naïve « borde la rivière → `rive` » l'avale, et la ville se retrouve avec **deux réseaux routiers étanches sans que rien ne le signale**. Le critère qui les distingue : un franchissement **touche deux morceaux de rivière**, puisque c'est lui qui l'a découpée. Cinq ponts retrouvés par cette règle.

### `03_adjacences.py` — le graphe (314 l.)

L'étape qui rend la carte **non décorative**. Pour chaque paire d'îlots partageant une frontière, elle écrit une ligne : `id_a`, `id_b`, `hierarchie_separatrice`, `longueur_m`, `permeabilite`.

Méthode : chaque segment de frontière est clé-é sur une grille de 25 cm ; un segment porté par deux îlots est une frontière partagée ; son milieu est projeté sur la voirie la plus proche (tolérance 50 cm, recherche indexée en cellules de 25 m) pour savoir **quelle rue le sépare**. Une frontière sans voirie sous elle tombe en `sans_rue` — deux arrières qui se touchent.

La perméabilité d'une paire est la **moyenne pondérée par la longueur** de ses morceaux, avec une pénalité ×0,5 au-delà de 20 m de large. Les sept valeurs de base sont **du design, pas de la mesure** ; elles sont en haut du fichier et tabulées dans le vault. → `Géométrie et données`

Une frontière sans voisin n'est pas une adjacence : elle est comptée à part en `bord_carte_m` sur l'îlot (**9 îlots, 3 862 m**), pour que « pas de voisin » et « donnée manquante » restent distinguables.

**Le contrôle intégré**, et il compte : le script recalcule les composantes connexes de la ville privée de sa rivière et de ses champs. Résultat vérifié aujourd'hui — **deux morceaux, 45 et 11 îlots**. La coupure du fleuve est dans la géométrie, pas dans une convention de code.

### `04_deriver_attributs.py` — les attributs dérivés (676 l.)

Le plus gros fichier, et **le plus dense en design** : deux champs sont saisis à la main, tout le reste se dérive ici.

Le cœur du fichier est la table `TISSU` : **13 lignes, une par `sous_type`, six colonnes** (densité nette, hauteur, part imperméabilisée, canopée, fragilité du riverain, part en stationnement). Treize lignes qui décident du comportement de la carte entière. Les densités sont calées sur du tissu allemand réel, pas choisies pour atteindre un chiffre de population.

Trois sous-systèmes en dessous :

**L'eau, sans MNT.** Il n'y a pas de modèle de terrain : le relief est du design assumé. `position_fil_eau` se lit **en latitude** (l'Ilse traverse du nord au sud en décrivant un S — un axe droit se tromperait de rive sur les méandres). `rive` est calculée sur la direction **locale** de la berge la plus proche, orientée vers l'aval. `altitude_relative` monte en s'éloignant de l'eau, avec une pente qui **s'adoucit vers l'aval** (3,2 % → 1,3 %) parce qu'une vallée s'élargit en descendant. `alea` décroît avec l'altitude et **augmente vers l'aval à altitude égale** (×0,80 → ×1,20). C'est ce qui met l'injustice géographique dans le terrain lui-même et pas dans un coefficient.

**Le trafic** (`charge_reseau`, ~110 l.). Une affectation minimale par plus court chemin **en temps**, pas en distance : deux demandes superposées, l'échange entre les sorties de carte (degré 1) et le local entre carrefours (degré ≠ 2), pondérées 55/45. Normalisée sur le 9<sup>e</sup> décile — normaliser sur le maximum écraserait tout, un seul tronçon portant l'essentiel des chemins. Ce n'est pas une simulation : c'est le socle sur lequel « fermer une rue reporte sa charge sur les voisines » devient calculable.

> Deux pièges déjà payés, tous deux corrigés dans le code : les nœuds du graphe sont **tous les sommets**, pas les extrémités de tronçons (sinon un raccord en T casse le réseau en morceaux) ; et une berge à largeur nulle est **hors graphe** (c'est une rive, pas une voie).

**L'emprise libre.** `largeur_m` moins ce que la circulation réclame par hiérarchie. C'est l'entrée de la doctrine à seuil : « je plante au-delà de X m ». Les mètres libres de la voie rapide de berge sont neutralisés — ce sont des files de circulation, pas du stationnement, et c'est précisément ce que sa suppression rendrait.

`--blanc` calcule tout, affiche tout, **n'écrit rien**. C'est le mode par défaut du travail. Le compte rendu n'est pas décoratif : il sort quatre choses invisibles sur la carte — la population réellement portée, les cinq plaies de 1965 relues dans les données, la courbe de la doctrine à seuil pour X de 2 à 9 m, et la connexité du réseau routier (c'est elle qui a révélé l'absence de ponts).

### `apercu_carte.py` — la boucle de contrôle (585 l.)

**Lecture seule**, SQLite ouvert en `mode=ro` : ne peut pas abîmer un fichier, tourne pendant que QGIS est ouvert dessus. Sort un PNG de 2 200 px légendé, avec échelle, et un bilan chiffré en console (îlots, linéaire, ce qui est renseigné, brins morts).

Trois modes :

```bash
python3 QGIS/scripts/apercu_carte.py QGIS/data/Prototype_qualifie.gpkg
python3 QGIS/scripts/apercu_carte.py QGIS/data/Prototype_qualifie.gpkg --adjacences
python3 QGIS/scripts/apercu_carte.py QGIS/data/Prototype_qualifie.gpkg --calque=alea
```

- **par défaut** : coloriage par `sous_type` (à défaut `fonction`), rues épaissies par hiérarchie, brins morts cerclés de rouge
- **`--adjacences`** : la carte s'efface à 72 %, le graphe s'affiche par-dessus — **rouge = coupure, vert = on passe**
- **`--calque=<champ>`** : n'importe quel champ numérique en dégradé froid→chaud, sur les îlots s'il y est, sinon sur les traits de rue. C'est ce qui permet de vérifier un attribut **en le regardant** : `--calque=charge` fait sortir l'axe de transit tout seul, sans qu'on l'ait désigné.

Seule dépendance externe de tout le dossier : **Pillow** (`pip install pillow`).

Les **8 brins morts** signalés sont les radiales qui sortent vers la campagne. Ce ne sont pas des erreurs — le bord de l'emprise n'est pas une rue. Ne pas les « corriger ».

### `01_champs_et_valuemaps.py` — hors chaîne (153 l.)

Le seul script à **coller dans la console Python de QGIS**, sur une copie, si on préfère qualifier à la souris en vue formulaire plutôt que par listes de `fid`. Il ajoute les champs manquants et pose les listes déroulantes. Démarre en `SIMULATION = True` : rien n'est écrit tant qu'on ne l'a pas repassé à `False`.

Il ne fait **pas** partie de la chaîne 02→03→04 et n'a pas été utilisé depuis que la qualification se fait par listes de `fid`. Voir §8 : sa liste de sous-types a divergé.

## 5. Le schéma réel, tel qu'il est dans le fichier aujourd'hui

`Prototype_qualifie.gpkg` · SQLite/GeoPackage · **EPSG:25832** (UTM 32N) · emprise 0,93 km²

**`ilots`** — 69 polygones · *saisi = posé à la main dans 02, dérivé = calculé*

| Colonne | Origine | |
|---|---|---|
| `fid` · `geom` | source | POLYGON |
| `fonction` | 02 | freiraum · habitation · industrie · mixte · riviere |
| `sous_type` | 02 | **13 valeurs** — c'est lui qui porte le level design |
| `exception` | 02 / 04 | 1 = saisie protégée du recalcul (17 îlots) |
| `surface_m2` | 02 | |
| `bord_carte_m` | 03 | frontière sans voisin — ≠ donnée manquante |
| `densite` `logements` `hauteur` | 04 | densifier · seuil de viabilité TC |
| `impermeabilise` | 04 | désimperméabiliser · ruissellement |
| `canopee` | 04 | planter · confort d'été |
| `desserte_tc` | 04 | le seuil que la densité doit atteindre |
| `riverain` | 04 | fragilité sociale — la boucle de gentrification |
| `stationnement` | 04 | le coût politique de la place-parking, chiffré |
| `altitude_relative` · `alea` | 04 | reconstruire / adapter / rendre à l'eau |
| `position_fil_eau` | 04 | la digue protège ici et aggrave en aval |
| `rive` | 04 | gauche / droite / lit — l'asymétrie des deux rives |

**`routes`** — 178 tronçons, MULTILINESTRING · `hierarchy` (source, héritée) · `hierarchie` + `largeur_m` (02) · `emprise_libre_m` + `stationnement` + `charge` + `canopee` (04)

**`adjacences`** — 179 lignes, table attributaire sans géométrie, déclarée dans `gpkg_contents` pour que QGIS la voie · `id_a` `id_b` `hierarchie_separatrice` `longueur_m` `permeabilite`

⚠️ La couche de lignes s'appelle **`routes`** dans le fichier, pas `rues` comme dit le vault. Le nom du fichier prime. → `Décisions arrêtées` 31c

### Le contrat entre les scripts

Trois dépendances dures, dont deux sont vérifiées à l'exécution :

1. **02 → 04** : tout `sous_type` écrit par 02 doit avoir sa ligne dans `TISSU`. ✅ vérifié, 04 s'arrête avec la liste des manquants.
2. **03 → 04** : la table `adjacences` doit exister ; 04 s'en sert pour `desserte_tc`. ✅ vérifié, message explicite.
3. **02 → 03/04** : les noms de couches `ilots` / `routes` sont **codés en dur** dans les trois scripts. Renommer une couche dans QGIS casse la chaîne sans avertissement.

## 6. Où est le design, où est la mécanique

Chaque script est coupé en deux par un commentaire. **Au-dessus** : ce qui se règle et se relance. **En dessous** : « rien à régler ». Les quatre endroits qui décident du comportement de la carte, par ordre de densité :

| Où | Quoi | Combien |
|---|---|---|
| `04` · `TISSU` | densité, hauteur, imperméabilisation, canopée, fragilité, parking | **13 lignes × 6 colonnes** |
| `02` · les listes de `fid` | quel îlot est quoi | ~30 lignes |
| `03` · `PERMEABILITE` | ce qu'une rue laisse passer | **7 nombres** |
| `04` · pentes et aléa | le relief, qui n'existe nulle part ailleurs | 5 constantes |

**Les deux fichiers à relire en priorité** — ils sont d'ailleurs listés comme en attente dans `ETAT.md` : les listes de `fid` de `02` et la table `TISSU` de `04`.

### La plomberie partagée

Les quatre scripts hors console QGIS **n'importent ni GDAL, ni Shapely, ni QGIS** — seulement `sqlite3` et `struct` de la bibliothèque standard (plus Pillow pour l'aperçu). Ils lisent le WKB à la main. Conséquence directe : **la chaîne tourne sur n'importe quelle machine avec un Python nu**, sans installer QGIS, ce qui est exactement ce qu'il faut pour un dépôt qui vit sur deux machines.

Le prix : ~60 lignes de lecteur WKB (`gpkg_vers_wkb`, `lire_wkb`, `enveloppe`) **dupliquées dans les quatre fichiers**. C'est assumé et ça n'a pas divergé, mais c'est le premier candidat à une factorisation si un cinquième script arrive.

Autre astuce partagée, moins évidente : les déclencheurs d'index spatial du GeoPackage appellent `ST_IsEmpty`, `ST_MinX`… que SQLite seul n'a pas. **Écrire le moindre attribut échoue sans elles.** Les scripts les rebranchent en Python (`brancher_fonctions_spatiales`) ; comme aucune géométrie n'est jamais modifiée, ces fonctions ne font que relire ce qui est déjà écrit.

## 7. L'état, vérifié le 2026-08-11

| | |
|---|---|
| Emprise | 0,93 km² · 898 × 1 036 m |
| Îlots | **69** — 56 bâtis · 7 champs · 6 morceaux de rivière |
| Sous-types | **13** · **17 exceptions** (cible ≈ 20) |
| Routes | **178** tronçons · 13,6 km — rue 100 · boulevard 40 · rive 21 · ruelle 17 |
| Franchissements de l'Ilse | **5** |
| Adjacences | **179** paires · 13,60 km de frontières partagées, soit **exactement** le linéaire de voirie — aucune frontière en `sans_rue` |
| Population portée | 2 549 logements · **5 353 habitants** sur 38,3 ha bâtis (140 hab/ha) |
| Stationnement | 3 350 places sur rue + 1 237 sur îlot = **4 587**, soit 1,80 par logement |

**Les trois contrôles qui comptent, tous les trois au vert :**

- la ville privée de sa rivière et de ses champs tombe en **deux morceaux (45 et 11 îlots)** — la coupure est dans la géométrie
- le réseau routier, lui, est **d'un seul tenant** (195 nœuds) — les cinq ponts existent
- l'**axe de transit sort tout seul** de l'affectation de trafic : le tronçon 55 monte à `charge = 1,00` sans qu'on l'ait désigné

Étapes 1 à 5 faites. **Reste l'étape 6, l'export GeoJSON, mois 2.**

## 8. Dérives connues — à corriger, aucune bloquante

Relevées en relisant le dossier le 2026-08-11. Rien n'empêche de travailler ; les deux premières se corrigent en une ligne.

1. 🟠 **`apercu_carte.py` plante sur un clone frais.** `QGIS/rendus/` est gitignoré, donc absent après un `git clone` — et le script ne le crée pas : `FileNotFoundError` au moment du `im.save`. Reproduit à l'instant sur ce Mac. Correctif : `os.makedirs(RENDUS, exist_ok=True)` avant l'enregistrement.
2. 🟠 **`HABITANTS_VAULT = 18000` dans `04`** est périmé. La décision 13d fixe Wehrau à **~5 350 habitants**, et la carte en porte 5 353 — soit la cible à 3 près. Mais le contrôle compare toujours à 18 000 et sort un **⚠️ « la carte n'en porte que 30 % »** à chaque exécution, alors que la réalité est un ✅. Un contrôle qui crie faux finit par ne plus être lu. Passer la constante à `5350`.
3. 🟡 **`01_champs_et_valuemaps.py` a divergé de `02`.** Sa liste `SOUS_TYPES` date de l'Altstadt (`coeur_medieval`, `faubourg`, `quai`, `friche`…) et ne recoupe presque pas les 13 sous-types réellement écrits (`coeur_ancien`, `maisons_de_ville`, `barre_1970`, `dalle_commerciale`, `jardins_familiaux`, `friche_industrielle`…). Le coller dans QGIS aujourd'hui poserait des listes déroulantes qui ne correspondent plus aux données. Sa docstring parle encore de l'Altstadt. À resynchroniser sur `02` ou à archiver.
4. 🟡 **`classification.json` est un vestige** de l'époque sans champ `fonction` : `apercu_carte.py` ne le lit qu'en repli, et `Prototype_qualifie.gpkg` a le champ, donc il n'est **jamais utilisé**. Il contredit d'ailleurs `02` (l'îlot 27 y est un champ, il est pavillonnaire depuis). Le supprimer, ou le garder pour lire un `.gpkg` non qualifié — mais alors le remettre d'accord avec `02`.
5. ⚪ **Cosmétique dans `04`** : le compte rendu titre « LES QUATRE PLAIES DE 1965 » et en liste cinq, et annonce la crue d'ouverture comme « non arrêté » alors que la décision 23b l'a tranchée le 2026-08-11.
6. ⚪ **La colonne `hierarchy` d'origine survit** dans `routes` à côté de `hierarchie`. Sans effet — plus aucun script ne la lit après `02` — mais c'est un doublon qui piégera quelqu'un un jour.

## 9. Mémo — les commandes

```bash
# regarder (lecture seule, sans danger, tourne avec QGIS ouvert)
python3 QGIS/scripts/apercu_carte.py QGIS/data/Prototype_qualifie.gpkg
python3 QGIS/scripts/apercu_carte.py QGIS/data/Prototype_qualifie.gpkg --adjacences
python3 QGIS/scripts/apercu_carte.py QGIS/data/Prototype_qualifie.gpkg --calque=alea

# tout recalculer et tout afficher, sans rien écrire
python3 QGIS/scripts/04_deriver_attributs.py --blanc

# régénérer la carte entière — dans cet ordre, 02 écrase le fichier de travail
python3 QGIS/scripts/02_qualifier.py && \
python3 QGIS/scripts/03_adjacences.py && \
python3 QGIS/scripts/04_deriver_attributs.py
```

*(sous Windows, `python` au lieu de `python3`)*

---

**Voir aussi** — dans le vault : `Technique/Pipeline QGIS.md` · `Technique/Géométrie et données.md` · `Ville/Wehrau.md` · `Méta/Décisions arrêtées.md` (30b, 31b, 31c, 31d, 32). À la racine : `ETAT.md` · `CLAUDE.md` §5 et §5 bis.
