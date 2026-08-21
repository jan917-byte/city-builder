# Godot — la maquette de Wehrau

On clique un îlot, on lit sa fiche, on augmente sa part de panneaux solaires, et les totaux de ville suivent. Godot **4.7.1**, aucun plugin, aucune dépendance.

🔴 **Aucun chiffre mesuré dans ce fichier.** Ils sont dans `Prototype/`, à l'étape qui les porte, et l'export les réimprime à chaque passage. Le design est dans le vault, ce qui reste à faire dans `ETAT.md`.

**Toute la géométrie est calculée en Python**, dans `07_exporter_godot.py`. Godot ne prend aucune décision géométrique : il lit des tableaux et les passe à `ArrayMesh`. L'« interface propre » de `Moteur et architecture:18` n'est pas une hiérarchie de classes, **c'est le contrat JSON**.

## Le lancer

```bash
python QGIS/scripts/chaine.py --godot
```

Puis ouvrir `Godot/` dans Godot 4.7 et lancer (F5).

`Godot/data/wehrau.json` est **gitignoré** : c'est un dérivé que `07` régénère. Sur la deuxième machine on relance `07` — on ne transporte pas le fichier.

## Le clavier

| | |
|---|---|
| **clic** | sélectionner un îlot ou une rue — la fiche s'ouvre à droite, l'objet choisi est cerné d'un trait clair qui épouse sa silhouette |
| **Espace** | lecture / pause · **×1** = un mois par minute, **×4** et **×12** accélèrent, **Recommencer** ramène au mois 0 |
| **V** | Wehrau en entier |
| **B** | la barre de 1974 |
| **R** | les rues larges, et le quai |
| **I** | l'Ilse canalisée et les trois franchissements |
| **G** | le talus des champs, au bord de l'eau |
| **O** | le plus long franchissement, de près |
| **M** | la place-parking et ses places peintes — à regarder de haut |
| **F** | le faubourg sinistré, rive gauche |
| **N** | le pont que la crue a emporté |
| **Q / E** | quart de tour, recalé sur les quatre vues cardinales |
| **← → ↑ ↓** | lacet par 15°, hauteur du regard par 8° |
| **T** | bascule vue de dessus ⇄ hauteur précédente |
| **souris** | molette : zoom · clic droit glissé : tourner · clic milieu glissé : déplacer |
| **C** | recolorer la ville **par tissu** — la palette d'avant le rendu réaliste |
| **F3** | afficher / masquer le moniteur de performances |
| **P** | capture PNG dans `QGIS/rendus/` |
| **Échap** | quitter |

Les gestes de caméra sont rappelés en bas à gauche de l'écran, avec l'angle courant. `V` `B` `R` ne sont pas un confort : ce sont **les critères de réussite du plan**, une touche chacun. On ne juge pas de mémoire.

## Les fichiers

```
maquette.tscn          un nœud, un script — tout le reste est construit en code
data/wehrau.json       produit par 07 (gitignoré)
scripts/
  maquette.gd          l'orchestrateur : construit, branche, fait passer le temps
  donnees.gd           lecture + validation. Échoue en NOMMANT ce qui manque
  constructeur.gd      tableaux → ArrayMesh. Aucun accès aux nœuds   ← isolé
  ville.gd             l'état, les rampes, les indicateurs, la caisse  ← LE NOYAU
  energie.gd           la table par tissu, les formules, les deux prix. Tout statique
  chantiers.gd         ancien prototype à deux décisions, conservé comme trace
  selection.gd         le raycast. Rend un (couche, fid), rien de plus
  interface.gd         la ville à gauche, l'îlot et son curseur à droite
  moniteur_performances.gd  le thermomètre F3, sans dépendance au jeu
  materiaux.gd         les matériaux, zéro texture
  camera_axo.gd        orthographique, lacet libre et hauteur de 6° à 90°
outils/
  sonde_api.gd         interroge ClassDB — à lancer avant de déboguer autre chose
  essai_energie.gd     contrôle imprimé de l'ancien prototype
```

`ville.gd`, `energie.gd` et `chantiers.gd` **ne touchent aucun nœud**, même discipline que `constructeur.gd` : c'est ce qui les rend relisibles et portables ailleurs le jour venu.

## Les règles qui tiennent le rendu

- **La caméra est orthographique**, et ça ne se rouvre pas : aucune perspective, donc une hauteur double projette double où que soit l'objet. « S'approcher » est réduire le cadrage, jamais avancer — ni LOD, ni distance, ni façades à détailler.
- 🔴 En orthographie, la profondeur de sol visible vaut `cadrage / sin(hauteur)`. Le cadrage est donc **multiplié par le sinus de la hauteur**, sinon la vue rasante ne montre plus qu'une bande au milieu d'un écran vide.
- **On montre l'écart au mois 0 à côté de la valeur**, partout. Une valeur qui bouge de 2 % ne se voit pas, et sans l'écart on croit que rien ne bouge.
- **L'échelle de couleur d'un calque est fixée sur l'état de DÉPART**, jamais recalculée à chaque pas de temps — sinon l'extrémum suit le changement et l'image reste identique.
- **Le toit et le mur sont deux matériaux**, le matériau découle de l'**époque** du bâtiment, et chaque bâtiment tire sa teinte de sa **position** (35). La touche `C` est la contrepartie : la couleur ne disant plus la typologie, il faut pouvoir la retrouver d'un geste.
- **Aucune fenêtre n'est un triangle** : le percement est dessiné par le matériau. `07` décide le genre de percement et la longueur du mur, Godot dessine.

## Ce qui se sélectionne, et comment

Les îlots bâtis et les tronçons sont **un nœud chacun**, avec leur `StaticBody3D`. C'est un choix, pas un oubli : un maillage fusionné ne se sélectionne pas, ne se surligne pas et ne se reteinte pas objet par objet. Toutes les parcelles d'un îlot tombent dans le même groupe : **la géométrie descend à la parcelle, la sélection reste à l'îlot.**

L'occlusion voyage dans `COLOR.a` — la teinte occluse est dans `COLOR.rgb`, le facteur seul dans l'alpha. C'est ce qui permet de repeindre un îlot en calque sans perdre ce qui le pose au sol. Aucun matériau du projet n'active la transparence : ce canal était libre.

✏️ **Le trait de sélection n'est pas de la géométrie.** L'objet choisi est redessiné seul, en blanc plat, dans une petite vue à part ; un shader plein écran allume les pixels vides proches de ce masque. Le trait épouse donc les pignons et les débords, et garde la même épaisseur à tous les zooms.

🔴 **Une rue ne se détoure pas sur son maillage rendu**, et c'est la seule exception : un tronçon est fait de morceaux disjoints séparés de plusieurs mètres. Le masque prend le **couloir** que `07` exporte. Ne pas essayer de recoudre ça dans le shader : l'écart est en mètres, le trait en pixels.

🔄 **Retour en arrière signalé** : le trait était un ruban de triangles posé au sol le long de l'anneau de l'îlot. Il n'entourait que l'emprise AU SOL — les bâtiments en sortaient, et dans le cœur ancien ils le cachaient. Ne pas le réintroduire pour « éviter un rendu supplémentaire ».

## Trois pièges de Godot, payés, qui reviendront

1. **Les faces avant sont en sens HORAIRE**, l'inverse de la convention main droite. Émis dans l'ordre naturel, tout ce qui regarde la caméra est pris pour du dos. `Maillage.triangle()` émet donc `p, r, q` — la normale reste celle de `p, q, r`.
2. **Les couleurs de sommet sont interprétées en espace LINÉAIRE.** Passées en sRGB, toute la maquette ressort délavée. `palette.vers_lineaire()` convertit. Les couleurs passées à `albedo_color` ou à une lumière n'en ont pas besoin : Godot les convertit lui-même.
3. **`class_name` ne suffit pas en ligne de commande.** Les classes globales n'existent qu'une fois le projet indexé par l'éditeur ; un clone frais échoue en « Identifier not declared ». D'où `preload()` partout.

## Déboguer

```bash
godot --headless --path Godot --script res://outils/sonde_api.gd
```

La sonde interroge `ClassDB` sur chaque méthode utilisée et construit un vrai `ArrayMesh`. Elle sort en code ≠ 0 au premier manque — **à lancer avant de chercher ailleurs** quand une version de Godot change.

- `-- --solo=Terrain` n'affiche qu'une famille (`Terrain`, `Eau`, `Ilots`, `Routes`, `Arbres`, `Alignements`).
- `-- --essai` joue la partie de contrôle et quitte. ⚠️ **pas** avec `--headless` : le pilote de rendu y est factice, aucune image n'en sort.

Chaque famille imprime son nombre de sommets et son étendue au démarrage : un maillage vide se voit dans la console, il ne se devine pas à l'écran.

`.mcp.json` à la racine déclare le serveur `godot-mcp`, qui permet de lancer la maquette et de lire la console. 🔴 **C'est le seul fichier du dépôt qui ne soit pas portable** : il est écrit pour Windows, et se corrige à la main sur le Mac. `run_project` lance un vrai processus — c'est `stop_project` qui le tue.

## 🔴 Le contrôle de recoupement n'existe plus

**À lire avant de faire confiance à un chiffre de ce projet.** Deux moteurs appliquaient les mêmes règles — `08_jouer.py` en Python, `ville.gd` en GDScript — et devaient tomber sur le même résultat. La décision qui portait ce contrôle est partie dans `archive/`, et le contrôle avec.

Ce qui reste sont des contrôles **d'un moteur contre lui-même** : la caisse tombe exactement du coût annoncé · l'îlot que la caisse ne peut pas payer reste refusé sans qu'un centime bouge · un chantier en cours n'accepte pas de seconde commande. Ils attrapent une formule qui dérive, **pas deux implémentations qui divergent**.

Concrètement : une formule fausse dans le noyau ne sera plus attrapée par personne avant qu'on la voie à l'écran. Si le classeur doit rester le banc d'essai, c'est lui qu'il faudra étendre — sinon il devient une archive, et il faut le dire.

---

**Voir aussi** — `Prototype/` pour l'étape en cours et ses défauts · `ETAT.md` pour ce qui attend l'auteur · `archive/LISEZ-MOI.md` pour ce qui a été retiré · le vault : `Technique/Moteur et architecture.md` · `Technique/Direction artistique.md`.
