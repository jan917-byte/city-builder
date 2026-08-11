# Godot — Wehrau, jouable

On clique un îlot ou une rue, on lit sa fiche, on décide de planter un
alignement, et on traverse vingt ans : les arbres poussent, la canopée monte,
la surchauffe baisse, le budget encaisse au début et se refait ensuite.

🔄 **Ce n'est plus « de l'affichage, pas de la simulation ».** La décision 39b
disait ça d'une maquette qui montrait un état sans en calculer aucun. Depuis le
2026-08-12, la boucle est ici : le noyau est dans `ville.gd` et `chantiers.gd`,
et c'est la levée de la décision 40 (→ **40b**) qui l'a permis.

Ce qui n'a pas changé : **toute la géométrie reste calculée en Python**, et la
subdivision en parcelles reste hors phase — `Génération procédurale.md:66`.

⚠️ **Le classeur n'est pas abandonné.** `Classeur/` et `08_jouer.py` restent le
banc d'essai : l'endroit où changer d'avis coûte une soirée au lieu de trois
semaines, ce qui reste le principe qui gouverne `Plan 3 mois`. Deux
implémentations des mêmes règles, donc deux occasions de diverger — d'où le
contrôle de recoupement plus bas, qui n'est pas optionnel.

Godot **4.7.1**. Aucun plugin, aucune dépendance.

## Le lancer

La chaîne complète, depuis un dépôt fraîchement tiré :

```bash
python QGIS/scripts/04b_emprises_baties.py --blanc
```

```bash
python QGIS/scripts/04b_emprises_baties.py
```

```bash
python QGIS/scripts/07_exporter_godot.py
```

Puis ouvrir `Godot/` dans Godot 4.7 et lancer (F5).

`Godot/data/wehrau.json` est **gitignoré** : c'est un dérivé de 1,4 Mo que 07
régénère en trois secondes. Sur la deuxième machine, on relance 07 — on ne
transporte pas le fichier.

## Claude lance Godot lui-même (serveur MCP)

Depuis le 2026-08-12, `.mcp.json` à la racine déclare le serveur
[`@coding-solo/godot-mcp`](https://github.com/Coding-Solo/godot-mcp) (MIT).
Claude peut donc **lancer la maquette et lire la console** au lieu de demander
un copier-coller de la pile d'appels. C'est le vrai gain : la boucle
« j'écris du GDScript → tu lances → tu me colles l'erreur » disparaît.

Quatorze outils, en trois groupes :

| | |
|---|---|
| **piloter** | `launch_editor` · `run_project` · `stop_project` · `get_debug_output` · `get_godot_version` |
| **lire** | `list_projects` · `get_project_info` · `get_uid` |
| **écrire** | `create_scene` · `add_node` · `save_scene` · `load_sprite` · `export_mesh_library` · `update_project_uids` |

⚠ `run_project` lance un vrai processus. S'il ne rend pas la main, c'est
`stop_project` qui le tue — pas le gestionnaire de tâches.

**Ce fichier est le seul du dépôt qui ne soit pas portable.** Deux raisons, et
les deux se corrigent à la main sur le Mac — voir `CLAUDE.md` §5 bis :

- la commande est `cmd /c npx`, parce que Node refuse de démarrer un `.cmd`
  sans shell (`EINVAL`). Sur macOS : `npx` directement.
- `GODOT_PATH` pointe l'exécutable **du Bureau**. Le serveur sait deviner
  `/Applications`, `C:\Program Files\Godot` et `/usr/bin/godot` — pas un
  binaire posé sur le Bureau. Sans cette variable, tous les outils échouent.

## Le clavier

| | |
|---|---|
| **clic** | sélectionner un îlot ou une rue — la fiche s'ouvre à droite |
| **Espace** | lecture / pause · les boutons **×1 ×4 ×12** règlent la vitesse |
| **V** | la vallée — tout Wehrau d'un coup |
| **B** | la barre de 1974 (îlot 32) |
| **R** | les rues à 20 et 22 m, et le quai |
| **1 2 3 4** | exagération verticale ×1 ×1,5 ×2 ×3 |
| **Q / E** | rotation de 90° · molette : zoom · clic droit : panoramique |
| **P** | capture PNG dans `QGIS/rendus/` |
| **Échap** | quitter |

`V` `B` `R` ne sont pas un confort : ce sont **les trois critères de réussite**
de `Plan 3 mois.md:48`, une touche chacun. On ne juge pas de mémoire.

⚠️ **La vallée ne se lit à AUCUNE des quatre exagérations** (constaté le
2026-08-12). 9 m de relief sur 898 m de large, vus en axonométrie à angle fixe :
le facteur n'y peut rien. Ça se réglera par l'ombre ou par la caméra, pas par
un multiplicateur.

## La seule règle d'affichage qui compte

**On montre l'écart au mois 0 à côté de la valeur.** Partout : dans le bandeau,
dans la fiche. C'est la leçon de `parties.html` — une canopée qui passe de 0,198
à 0,216 ne se voit pas, et sans l'écart on croit que rien ne bouge.

Le corollaire est dans les **calques** : l'échelle de couleur est fixée sur
l'état de DÉPART, jamais recalculée à chaque pas de temps. Sinon l'extrémum
suit le changement et l'image reste identique.

## Ce que ça doit prouver

> Que Wehrau **existe** comme lieu, et qu'une décision s'y **voit**. On doit
> sentir la vallée, voir la barre de 1974 comme un objet aberrant de 9 niveaux
> au milieu de rangées à 3, trouver monstrueuses les rues à 20 et 22 m — et
> reconnaître une rue qu'on a plantée dix ans plus tôt.

⚠ `Plan 3 mois.md:50` : « Si j'ajoute des toits, j'ai changé de projet. »

## Comment c'est fait

**Toute la géométrie est calculée en Python**, dans `07_exporter_godot.py`.
Godot ne prend aucune décision géométrique : il lit des tableaux et les passe
à `ArrayMesh`. Deux raisons, toutes deux dans `Moteur et architecture.md` :
les boucles géométriques lourdes en GDScript goulottent (l.16), et le vibe
coding est écarté pour « GDScript spécifiquement » (l.32).

L'« interface propre pour basculer en C# » de la ligne 18 n'est donc pas une
hiérarchie de classes : **c'est le contrat JSON**.

```
project.godot
maquette.tscn          un nœud, un script — tout le reste est construit en code
data/wehrau.json       produit par 07 (gitignoré)
scripts/
  maquette.gd          l'orchestrateur : construit, branche, fait passer le temps
  donnees.gd           lecture + validation. Échoue en NOMMANT ce qui manque
  constructeur.gd      tableaux → ArrayMesh. Aucun accès aux nœuds   ← isolé
  ville.gd             l'état, les rampes, les indicateurs. Aucun nœud  ← LE NOYAU
  chantiers.gd         les décisions : cible, coût, capital, budget
  selection.gd         le raycast. Rend un (couche, fid), rien de plus
  interface.gd         la fiche, la décision, le temps, les calques
  alignements.gd       le MultiMesh des arbres, et leur croissance
  materiaux.gd         6 matériaux, zéro texture
  camera_axo.gd        orthographique, angle fixe
outils/
  sonde_api.gd         interroge ClassDB — à lancer avant de déboguer autre chose
```

`ville.gd` et `chantiers.gd` **ne touchent aucun nœud** — même discipline que
`constructeur.gd`, et pour la même raison : c'est ce qui les rend relisibles,
testables, et portables ailleurs le jour venu.

### 🔄 Deux familles fusionnées, ~250 objets

Avant : cinq familles, cinq draw calls. Maintenant **Terrain** et **Eau**
restent fusionnés, mais les 63 îlots bâtis et les 174 tronçons sont **un nœud
chacun** — 237 objets, chacun avec son `StaticBody3D`.

C'est un choix, pas un oubli. Un maillage fusionné ne se sélectionne pas, ne se
surligne pas et ne se reteinte pas objet par objet : sans le découpage il n'y a
pas de jeu, seulement une image. 250 draw calls sur 40 000 triangles ne se
voient pas. L'alternative — raycast sur un plan puis point-dans-polygone —
résout le clic mais ni la surbrillance ni les calques.

Les **arbres**, eux, gardent leur MultiMesh : ils sont le vrai destinataire de
`Génération procédurale.md:74`. Un MultiMesh répète *un même* mesh — les 69
îlots sont 69 formes distinctes, il en faudrait 69 d'une instance chacun.

### L'occlusion voyage dans le canal alpha

07 écrit la teinte occluse dans `COLOR.rgb` **et le facteur d'occlusion seul
dans `COLOR.a`**. C'est ce qui permet de repeindre un îlot en calque thématique
sans perdre ce qui le POSE au sol — l'AO bakée est la fondation, pas un décor
(`Direction artistique` l.21). Aucun matériau du projet n'active la
transparence : ce canal était libre.

Le surlignage et les calques passent par `instance uniform` : une valeur **par
MeshInstance3D**, sans dupliquer le matériau 237 fois.

## Trois pièges rencontrés, et leur résolution

Ils sont documentés ici parce qu'ils reviendront.

1. **Godot considère les faces avant en sens HORAIRE**, l'inverse de la
   convention main droite. Émis dans l'ordre naturel, tout ce qui regarde la
   caméra est pris pour du dos : le terrain entier disparaissait et les
   bâtiments ne se voyaient plus que par leurs murs. `Maillage.triangle()`
   émet donc `p, r, q` — la normale, elle, reste celle de `p, q, r`.
2. **Les couleurs de sommet sont interprétées en espace LINÉAIRE.** Passées en
   sRGB, toute la maquette ressort délavée et le contraste pastel/minéral
   s'efface — c'est-à-dire exactement ce que la décision 42c demande de voir.
   `palette.vers_lineaire()` convertit. Les couleurs passées à `albedo_color`
   ou à une lumière n'ont pas besoin de ça : Godot les convertit lui-même.
3. **`class_name` ne suffit pas en ligne de commande.** Les classes globales
   n'existent qu'une fois le projet indexé par l'éditeur ; un clone frais
   échoue en « Identifier not declared ». D'où `preload()` partout.

## Déboguer

```bash
"C:/Users/janha/Desktop/Godot_v4.7.1-stable_win64.exe/Godot_v4.7.1-stable_win64_console.exe" --headless --path Godot --script res://outils/sonde_api.gd
```

La sonde interroge `ClassDB` sur chaque méthode et propriété utilisées et
construit un vrai `ArrayMesh`. Elle sort en code ≠ 0 au premier manque. À
lancer **avant** de chercher ailleurs quand une version de Godot change.

Deux autres gestes utiles :

- `-- --solo=Terrain` n'affiche qu'une famille (`Terrain`, `Eau`, `Ilots`,
  `Routes`, `Arbres`, `Alignements`). C'est ce qui a permis de répondre
  « est-ce qu'elle se rend ? » par l'expérience plutôt que par le raisonnement.
- `-- --essai` joue la partie de contrôle et quitte. ⚠ **pas** avec
  `--headless` : le pilote de rendu y est factice, aucune image n'en sort.

Chaque famille imprime son nombre de sommets et son étendue au démarrage —
même habitude que les scripts QGIS : un maillage vide se voit dans la console,
il ne se devine pas à l'écran.

## 🔴 Le contrôle de recoupement

Deux moteurs appliquent les mêmes règles : `08_jouer.py` en Python et
`ville.gd` + `chantiers.gd` en GDScript. **Ils doivent tomber sur le même
chiffre**, sinon la duplication a commencé à mentir et personne ne le sait.

```bash
"C:/Users/janha/Desktop/Godot_v4.7.1-stable_win64.exe/Godot_v4.7.1-stable_win64_console.exe" --path Godot -- --essai
```

```bash
python QGIS/scripts/08_jouer.py --partie=4_recoupement
```

Les deux plantent D07 à 6,0 m d'emprise libre au mois 0. Attendu, au 2026-08-12 :

| | Godot | `08_jouer.py` |
|---|---|---|
| tronçons · linéaire · coût | 64 · 6 217 m · 114,9 pts | idem — et la table du `Classeur/README.md` §3 dit **64 · 6 217 · 115** |
| canopée au mois 0 | 0,1978 | 0,198 |
| canopée au mois 60 | **0,2732** | **0,273** |
| solde budgétaire au mois 60 | 397,1 | 397 |

L'essai vérifie aussi que **le clic au centre de la vue « barre » rend l'îlot
32**, et sort quatre captures dans `QGIS/rendus/`.

⚠️ Le décalage du budget a déjà mordu une fois : `08_jouer.py` paie sur les mois
`d` à `d + étale − 1` INCLUS, donc une première mensualité tombe au moment même
où l'on décide. Sans le `+ 1` dans `chantiers.paye()`, les deux moteurs
sortaient 397 et 399 — assez peu pour qu'on l'ignore, ce qui est exactement le
danger.

## 🟠 Trois chiffres qui attendent ton œil

Aucun n'est tranché. Ils sont dans le code avec ce commentaire, pas cachés.

1. **La surchauffe** — `ville.gd` : `3,5 × imperméabilisé − 2,5 × canopée`, en
   °C. Elle n'existe dans aucune colonne du `.gpkg` ; elle se dérive du sol,
   ici et nulle part ailleurs. À t0 elle donne **+1,59 °C** sur Wehrau, l'ordre
   de grandeur d'un îlot de chaleur de petite ville. C'est aussi ce qui donne
   enfin un corps à `confort_ete`, la variable que `effets.csv` réclame et que
   le GeoPackage n'a pas.
2. **Le +0,25 de canopée de D07** (`Classeur/effets.csv`). Dans les données, la
   canopée d'une rue plafonne à **0,18** et sa médiane est **0,10** — aucun
   tronçon ne dépasse 0,20. Planter fait donc passer une rue au-dessus de tout
   ce qui existe à Wehrau. C'est peut-être juste ; ça se regarde.
3. **`CANOPEE_ALIGNEMENT_MAX = 0,40`** (`07_exporter_godot.py`) — la canopée
   d'une rue plantée de bout en bout, un arbre tous les 8 m. C'est une
   constante de **rendu** : elle ne change aucun chiffre de la simulation,
   seulement le nombre d'arbres qu'on voit pour une canopée donnée.

## Ce que la maquette ne montre pas, et ne montrera pas

- **La canopée des îlots bâtis** — 9,5 ha. Un îlot extrudé est un pâté plein :
  il n'y a pas de sol visible dessous. 07 l'imprime au lieu de le taire.
- **Les carrefours.** Les chaussées se recouvrent ; comme elles sont toutes
  dans un seul plan et d'une seule couleur, ça ne se voit pas. Le vrai
  problème est hors phase (`Génération procédurale.md:58`).
- **Le raccord entre bâtiments voisins.** La maquette assume le non-raccord —
  c'est elle l'instrument de la question ouverte n°16, qui ne se tranche pas
  avant de l'avoir regardée (`Questions ouvertes.md:55`).
- **Des toits, des façades, des parcelles.** Hors phase, et le rester.
