# Godot — la maquette de masses de Wehrau à t0

Wehrau au temps zéro, en volumes. **De l'affichage, pas de la simulation** :
la décision 39b le dit explicitement, ce projet ne touche pas au noyau réservé
par la décision 40. Il sera jeté quand la subdivision en parcelles arrivera —
`Génération procédurale.md:66`.

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

## Le clavier

| touche | |
|---|---|
| **V** | la vallée — tout Wehrau d'un coup |
| **B** | la barre de 1974 (îlot 32) |
| **R** | les rues à 20 et 22 m, et le quai |
| **1 2 3 4** | exagération verticale ×1 ×1,5 ×2 ×3 |
| **Q / E** | rotation de 90° · molette : zoom · clic droit : panoramique |
| **P** | capture PNG dans `QGIS/rendus/` |
| **Échap** | quitter |

Les trois premières touches ne sont pas un confort : ce sont **les trois
critères de réussite** de `Plan 3 mois.md:48`, une touche chacun. On ne juge
pas de mémoire.

## Ce que ça doit prouver, et rien d'autre

> Que Wehrau **existe** comme lieu. On doit **sentir la vallée**, voir **la
> barre de 1974 comme un objet aberrant de 9 niveaux au milieu de rangées à
> 3**, et **trouver monstrueuses les rues à 20 et 22 m**.

Et le critère de sortie, `Plan 3 mois.md:58` : *est-ce que la 3D m'a montré
quelque chose que la page HTML ne montrait pas ?* Si la réponse est non, on
arrête la 3D et on reprend le classeur. **Ce sera un bon résultat, pas un
échec.**

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
  maquette.gd          l'orchestrateur, le clavier, les captures
  donnees.gd           lecture + validation. Échoue en NOMMANT ce qui manque
  constructeur.gd      tableaux → ArrayMesh. Aucun accès aux nœuds  ← le noyau isolé
  materiaux.gd         5 matériaux, zéro texture
  camera_axo.gd        orthographique, angle fixe
outils/
  sonde_api.gd         interroge ClassDB — à lancer avant de déboguer autre chose
```

### Cinq familles, cinq draw calls

Terrain · Voirie · Sols · Masses · Eau, chacune fusionnée en **un** ArrayMesh.
≈ 40 000 triangles au total.

Les 69 îlots n'ont **pas** de MultiMesh, et c'est une lecture explicite de
`Génération procédurale.md:74`, pas un oubli : un MultiMesh répète *un même*
mesh, or ce sont 69 formes distinctes — il en faudrait 69 d'une instance
chacun, soit 69 draw calls au lieu d'un. Les **arbres**, eux, en ont un : ils
sont le vrai destinataire de la règle.

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
"C:/Users/janha/Downloads/Godot_v4.7.1-stable_win64.exe/Godot_v4.7.1-stable_win64_console.exe" --headless --path Godot --script res://outils/sonde_api.gd
```

La sonde interroge `ClassDB` sur chaque méthode et propriété utilisées et
construit un vrai `ArrayMesh`. Elle sort en code ≠ 0 au premier manque. À
lancer **avant** de chercher ailleurs quand une version de Godot change.

Deux autres gestes utiles :

- `-- --solo=Terrain` n'affiche qu'une famille. C'est ce qui a permis de
  répondre « est-ce qu'elle se rend ? » par l'expérience plutôt que par le
  raisonnement.
- `-- --capture` prend les trois points de vue et quitte. ⚠ **pas** avec
  `--headless` : le pilote de rendu y est factice, aucune image n'en sort.

Chaque famille imprime son nombre de sommets et son étendue au démarrage —
même habitude que les scripts QGIS : un maillage vide se voit dans la console,
il ne se devine pas à l'écran.

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
