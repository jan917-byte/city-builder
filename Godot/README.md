# Godot — la maquette de Wehrau

Relever la ville après la crue et équiper ses toits se disputent la même caisse dès le premier mois. Deux jauges suivent les deux fronts, **adaptation** et **réduction**. Godot **4.7.1**, aucun plugin, aucune dépendance.
🔴 **Aucun chiffre mesuré dans ce fichier.** Ils sont dans `Prototype/`, à l'étape qui les porte, et l'export les réimprime à chaque passage. Le design est dans le vault, ce qui reste à faire dans `ETAT.md`.
**Toute la géométrie est calculée en Python**, par `07_exporter_godot.py` et les modules de `QGIS/scripts/export_godot/`. Godot ne prend aucune décision géométrique : il lit des tableaux et les passe à `ArrayMesh`. L'« interface propre » de `Moteur et architecture:18` n'est pas une hiérarchie de classes, **c'est le contrat JSON**.

## Le lancer

```bash
python QGIS/scripts/chaine.py --godot
```

Puis ouvrir `Godot/` dans Godot 4.7 et lancer (F5).
`Godot/data/wehrau.json` est **gitignoré** : c'est un dérivé que `07` régénère. Sur la deuxième machine on relance `07` — on ne transporte pas le fichier.
`Godot --path Godot -- --interface` sort rapidement les captures de contrôle de l'interface : la fiche d'une rue, son diagnostic, la fiche d'un îlot et celle d'une berge, les deux menus de lieu, plus chaque miniature seule à sa taille de rendu.
## Sauvegarder une partie

Les boutons **Sauvegarder** (F5 dans le jeu) et **Reprendre** (F9) sont à côté du temps. Une seule partie manuelle est conservée, avec une copie de secours ; reprendre revient en pause. « Recommencer » ne supprime pas la sauvegarde.
Le mois, les décisions, les travaux, la recherche, les politiques, les rues fermées et le cadrage sont conservés. Les réglages non engagés restent des essais et ne sont pas sauvegardés.
Fichier local : `user://partie.wehrau`, dans le dossier de données Godot de l'utilisateur ; il ne voyage pas par git. Une carte régénérée différente ou un format incompatible est refusé avant de modifier la partie en cours.
Le contrôle autonome se lance avec `Godot --headless --path Godot --script res://outils/essai_sauvegarde.gd` ; ajouter `-- --captures` et retirer `--headless` pour produire l'aperçu de reprise.
Les noms affichés viennent de `Godot/data/lieux.json`, table éditoriale à modifier à la main. Le numéro reste en infobulle sur le titre de la fiche.

## Le clavier

| | |
|---|---|
| **clic bref** | sélectionner au relâchement un îlot ou une rue ; glisser ne sélectionne pas |
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
| **souris** | clic gauche glissé : attraper le sol · Ctrl + clic gauche glissé : tourner et incliner autour du point visé · molette : zoom progressif au pointeur |
| **F3** | afficher / masquer le moniteur de performances |
| **P** | capture PNG dans `QGIS/rendus/` |
| **Échap** | quitter |

## Les deux vues

**La ville vivante** et **le diagnostic**, à la souris : le bouton « Diagnostic » du tableau de bord, puis le menu des thèmes qui prend sa place — pas de raccourci clavier, c'est voulu. Le diagnostic passe la ville en **maquette blanche** — plus de matière, plus d'arbres, plus de voitures, rien que le volume — et **seul le thème choisi est en couleur** : tant qu'il ressemble à la ville vivante, on ne sait plus si on juge le rendu ou le thème. Le temps continue, la caméra ne bouge pas, la fiche répond toujours au clic — **le diagnostic change ce qu'on voit, jamais ce qu'on peut faire**. Un thème neuf, c'est **trois pièces** : une ligne dans `THEMES` (haut de `maquette.gd`), son genre de peinture, et un panneau seulement s'il en faut un.

En bas à gauche, la boussole **N** remet le nord en haut ; **Dessus / 3D** alterne plan et inclinaison précédente. Les panneaux gardent leurs clics et leur molette. `V` `B` `R` restent les repères de contrôle. `Godot --headless --path Godot --script res://outils/essai_camera.gd` vérifie les gestes ; retirer `--headless` et ajouter `-- --ville` vérifie les clics et boutons dans la maquette et produit un aperçu.

## Les fichiers

| Entrée | Rôle |
|---|---|
| `maquette.tscn` · `scripts/maquette.gd` · `donnees.gd` · `constructeur.gd` | scène, orchestration, validation et maillages |
| `scripts/ville.gd` · `energie.gd` | état de la ville, décisions, budget et énergie |
| `scripts/recherche.gd` · `politiques.gd` | tables de recherche et de politiques |
| `scripts/interface.gd` · `selection.gd` · `lieux.gd` | fiches, clic et noms affichés |
| `scripts/sauvegarde.gd` | écriture, lecture et copie de secours de la partie |
| `scripts/apercu.gd` · `echantillon.gd` | miniature et coupe de rue ou de berge |
| `scripts/trafic.gd` · `materiaux.gd` · `camera_axo.gd` · `paysage.gd` | trafic, matières, caméra et décor extérieur exporté |
| `outils/` · `scripts/moniteur_performances.gd` | contrôles autonomes et thermomètre F3 ; `chantiers.gd` reste l'ancien prototype |


`ville.gd`, `energie.gd` et `chantiers.gd` **ne touchent aucun nœud**, même discipline que `constructeur.gd` : c'est ce qui les rend relisibles et portables ailleurs le jour venu.

## Les règles qui tiennent le rendu

- **La caméra est orthographique**, et ça ne se rouvre pas : aucune perspective, donc une hauteur double projette double où que soit l'objet. « S'approcher » est réduire le cadrage, jamais avancer — ni LOD, ni distance, ni façades à détailler.
- 🔴 En orthographie, la profondeur de sol visible vaut `cadrage / sin(hauteur)`. Le cadrage est donc **multiplié par le sinus de la hauteur**, sinon la vue rasante ne montre plus qu'une bande au milieu d'un écran vide.
- **On montre l'écart au mois 0 à côté de la valeur**, partout. Une valeur qui bouge de 2 % ne se voit pas, et sans l'écart on croit que rien ne bouge.
- **L'échelle de couleur d'un thème est fixée sur l'état de DÉPART**, jamais recalculée à chaque pas de temps — sinon l'extrémum suit le changement et l'image reste identique.
- **Le toit et le mur sont deux matériaux**, le matériau découle de l'**époque** du bâtiment, et chaque bâtiment tire sa teinte de sa **position** (35). Le thème « tissu » est la contrepartie : la couleur ne disant plus la typologie, il faut pouvoir la retrouver d'un geste.
- **Aucune fenêtre n'est un triangle** : le percement est dessiné par le matériau. `07` décide le genre de percement et la longueur du mur, Godot dessine.

## Ce qui se sélectionne, et comment

Les îlots bâtis et les tronçons sont **un nœud chacun**, avec leur `StaticBody3D`. C'est un choix, pas un oubli : un maillage fusionné ne se sélectionne pas, ne se surligne pas et ne se reteinte pas objet par objet. Toutes les parcelles d'un îlot tombent dans le même groupe : **la géométrie descend à la parcelle, la sélection reste à l'îlot.**

L'occlusion voyage dans `COLOR.a` — la teinte occluse est dans `COLOR.rgb`, le facteur seul dans l'alpha. C'est ce qui permet de repeindre un îlot en calque sans perdre ce qui le pose au sol. Aucun matériau du projet n'active la transparence : ce canal était libre.

🎓🏛️ **Deux menus ont un lieu** : la **mairie** (îlot 20) signe les politiques de la ville, l'**université** (îlot 36) finance la recherche. Chacun s'ouvre par son bouton du bandeau **ou** par un bouton dans la fiche de son îlot — le lieu est un raccourci, jamais le seul chemin. La fiche d'un îlot reste **la fiche de l'îlot** : le menu est une autre fiche, et il prend sa place. Leurs tables se règlent en haut de `recherche.gd` et `politiques.gd`.

🎚️ **On règle, on compare, puis on met en place.** Une décision ne part pas au clic : les réglages se posent sur l'objet, se retirent d'un second clic, et **un seul bouton** les engage ensemble. Prix, durée et refus se calculent **une fois, sur le total** — deux décisions qui tiennent séparément ne tiennent pas forcément ensemble. Une commande fait **un chantier**, et c'est le noyau qui refuse, jamais l'interface. La miniature porte l'**avant** et l'**après** sur deux boutons : rien n'y est rendu deux fois, l'état du jour est un autre jeu de paramètres passé au même objet, et les boutons se cachent quand les deux images seraient identiques.

🔎 **La miniature de la fiche est une vue à part**, en isométrie, l'objet toujours vu **de trois quarts** et posé sur une dalle épaisse — sans épaisseur, c'est une découpe sur du papier. Un **îlot** y est le maillage de la ville, et le lacet se cale sur le quart de tour le plus proche de la vue. Une **rue** et une **berge**, non : elles sont montrées par un **morceau droit fabriqué** (`echantillon.gd`), à la largeur et du type mesurés, sous un angle fixe — il n'est nulle part dans la ville, il n'y a rien à y reconnaître, et la berge doit garder son eau du côté du regard. Ses voitures suivent les règles du trafic, dans l'état que la fiche promet et non celui de la ville.

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

La sonde interroge `ClassDB` sur chaque méthode utilisée et construit un vrai `ArrayMesh`. Elle sort en code ≠ 0 au premier manque — **à lancer avant de chercher ailleurs** quand une version de Godot change. Chaque famille imprime son nombre de sommets et son étendue au démarrage : un maillage vide se voit dans la console, il ne se devine pas à l'écran.

- `-- --solo=Terrain` n'affiche qu'une famille (`Terrain`, `Eau`, `Ilots`, `Routes`, `Arbres`, `Alignements`, `Paysage`). `--script res://outils/apercu_vallee.gd` produit les vues de contrôle de la vallée.
- `-- --essai` joue la partie de contrôle et quitte. ⚠️ **pas** avec `--headless` : le pilote de rendu y est factice, aucune image n'en sort.
- `-- --banc` mesure et quitte : quatre cadrages verrou d'écran levé, puis la pulsation du trafic et le prix d'une image, part par part. 🔴 **À lancer AVANT d'optimiser quoi que ce soit** — le coupable n'est presque jamais celui qu'on croit, et le banc dit s'il est dans le script ou dans le rendu. Les chiffres vivent dans `Prototype/`, pas ici.

`.mcp.json` à la racine déclare le serveur `godot-mcp`, qui permet de lancer la maquette et de lire la console. 🔴 **C'est le seul fichier du dépôt qui ne soit pas portable** : il est écrit pour Windows, et se corrige à la main sur le Mac. `run_project` lance un vrai processus — c'est `stop_project` qui le tue.

Les essais vérifient les commandes, la reprise et les invariants du moteur. La question du recoupement avec le classeur est suivie dans `ETAT.md`, « Le rôle du classeur ».

---

**Voir aussi** — `Prototype/` pour l'étape en cours et ses défauts · `ETAT.md` pour ce qui attend l'auteur · `archive/LISEZ-MOI.md` pour ce qui a été retiré · le vault : `Technique/Moteur et architecture.md` · `Technique/Direction artistique.md`.
