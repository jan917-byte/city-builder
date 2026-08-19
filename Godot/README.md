# Godot — Wehrau, une ville

On clique un îlot, on lit sa fiche et on augmente sa part de panneaux
solaires. La ville est faite de **701 volumes sur 809 parcelles**, avec ses cours, ses rangs de
maisons mitoyennes et ses toits à deux pentes. Elle est posée sur une **carte
plate** — sauf les champs, qui **descendent de 2 m** vers le chenal de l'Ilse,
lequel coupe la ville en deux.

🔋 **Le prototype énergie a été simplifié le 2026-08-17** (décision 68).
À gauche : consommation, production solaire, achat et CO₂ de toute la ville.
À droite : seulement l'îlot cliqué, avec un curseur qui peut augmenter sa part
solaire jusqu'à 100 %. La fiche annonce la durée, puis la pose progresse jusqu'à
la cible — **un mois maximum**, proportionnel à la part ajoutée. Les toits
se couvrent peu à peu de **panneaux bleus au liseré blanc**, posés case par case
de 3 m, et les totaux de ville suivent. Le temps avance d'**un mois par minute**
à ×1, se met en pause ou s'accélère en ×4 et ×12, et **Recommencer** le ramène au
mois 0 en annulant les poses ; capital, isolation et calque restent absents.

💶 **Et le même jour, une petite économie y est revenue** (décision 69). Deux
prix, pas un de plus : **260 €/m² posé** — multiplié par le coefficient de coût
du tissu — et **150 €/MWh produit**. Le coût d'une pose, sa recette annuelle et
son amortissement s'en déduisent tous les trois. La mairie a une **caisse**
(800 k€, plus 30 k€/mois) qui n'encaisse **que** les panneaux : la facture
d'énergie de la ville, 7,7 M€/an, est payée par les occupants et ne la traverse
jamais. Quand la caisse ne suit pas, la fiche dit **combien il manque** et le
bouton refuse. Un chantier engagé ne se révise plus — voir `ville.gd`, c'est ce
qui garde la recette juste.

🏛️ **Tout le logement et tous les panneaux appartiennent à la ville** (décision
70, le 2026-08-18). Il n'y a donc pas de toit des autres : pas de loyer de
toiture, pas de copropriété qui refuse, pas de deux régimes selon le tissu.
⚠️ Mais **posséder un logement n'est pas payer sa facture** — la ville est
propriétaire-bailleur, elle a les toits sans avoir les factures, et c'est ce
qui garde le paragraphe ci-dessus vrai.

`chantiers.gd` et `outils/essai_energie.gd` gardent l'ancien prototype à
deux décisions comme trace technique ; ils ne décrivent plus la boucle jouable.

Ce qui n'a pas changé : **toute la géométrie reste calculée en Python**. Godot
empaquette des tableaux et ne décide rien — l'« interface propre » de
`Moteur et architecture:18` est le contrat JSON, pas une hiérarchie de classes.

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

`Godot/data/wehrau.json` est **gitignoré** : c'est un dérivé de **18 Mo** que
07 régénère en **onze secondes**. Sur la deuxième machine, on relance 07 — on ne
transporte pas le fichier. 🔄 Il pesait 1,4 Mo et se refaisait en trois
secondes tant que la maquette n'était que des masses ; ce qui l'a fait grossir,
ce sont le sol, la voirie, le marquage et le percement des murs.

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
| **clic** | sélectionner un îlot ou une rue — la fiche s'ouvre à droite, et l'objet choisi est **cerné d'un trait jaune clair** qui épouse sa silhouette |
| **Espace** | lecture / pause · **×1** = un mois par minute, **×4** et **×12** accélèrent, **Recommencer** ramène au mois 0 |
| **V** | Wehrau en entier |
| **B** | la barre de 1974 (îlot 32) |
| **R** | les rues à 20 et 22 m, et le quai |
| **I** | l'Ilse canalisée et les trois franchissements |
| **G** | le talus des champs, au bord de l'eau |
| **O** | le plus long franchissement, de près : le tablier, sa joue et sa pile |
| **M** | 🆕 la place-parking et ses **123 places peintes** — à regarder de haut |
| **Q / E** | quart de tour, recalé sur les quatre vues cardinales |
| **← → ↑ ↓** | lacet par 15°, hauteur du regard par 8° |
| **T** | bascule vue de dessus ⇄ hauteur précédente |
| **souris** | molette : zoom · clic droit glissé : tourner · clic milieu glissé : déplacer |
| **C** | 🆕 recolorer la ville **par tissu** — la palette d'avant le rendu réaliste, le temps d'un coup d'œil |
| **F3** | afficher / masquer le moniteur : images par seconde, temps d'image et CPU, triangles, appels de rendu, nœuds et mémoire |
| **P** | capture PNG dans `QGIS/rendus/` |
| **Échap** | quitter |

Les gestes de caméra sont **rappelés en bas à gauche de l'écran**, avec l'angle
courant (« vue du sud-est, 32° au-dessus ») : ils ne se devinent pas, et un jeu
qui oblige à ouvrir un fichier pour les connaître n'en est pas un.

`V` `B` `R` ne sont pas un confort : ce sont **les trois critères de réussite**
de `Plan 3 mois.md:48`, une touche chacun. On ne juge pas de mémoire.

### 🔄 La caméra tourne, depuis le 2026-08-17

Elle avait un **angle fixe** — 32° au-dessus de l'horizon, quatre lacets à 90°
— et le fichier interdisait explicitement l'orbite. L'auteur a demandé de voir
la ville sous tous ses angles : le lacet est maintenant libre sur 360° et la
hauteur du regard se règle **de 6° à 90°**.

**Ce qui est préservé, et c'est l'essentiel : l'orthographie.** Aucune
perspective, donc 27 m projettent toujours 3× plus que 9 m où que soit l'objet
dans le cadre — les deux critères de `Plan 3 mois.md:48` tiennent. « S'approcher »
reste réduire le cadrage, jamais avancer : ni LOD, ni distance, ni façades à
détailler. La coupe de `Périmètre et coupes.md:42` n'est pas rouverte.

**Ce qui était payé** : sous ~15°, on regardait la ville par ses **façades**,
qui étaient des murs nus d'une seule teinte. 🔄 **Ça a été réglé le
2026-08-18** — les murs sont percés, et la vue basse montre maintenant des
étages, des entrées et des pignons pleins (`wehrau_essai_facades.png`). Ce qui
reste vrai : l'angle bas est un point de vue de **contrôle**, bon pour juger une
silhouette et des hauteurs, moins bon pour juger un quartier. Le plancher à 6°
existe pour qu'il reste possible sans devenir la vue par défaut.

🔴 **Le piège, mesuré à la première capture** : en orthographie, la profondeur
de sol visible vaut `cadrage / sin(hauteur)`. À 10°, la ville de 1 084 m ne
projetait plus que 188 m — une bande minuscule au milieu d'un écran vide. Le
cadrage est donc **multiplié par le sinus de la hauteur** : la quantité de sol
visible ne dépend plus de l'angle, et la vue par défaut à 32° est restée
exactement celle d'avant. Les bâtiments, eux, grandissent à l'écran quand le
regard descend — c'est ce qu'on vient y chercher.

🔄 **Les touches `1..4` ont disparu, et la vallée avec.** Elles exagéraient le
relief ×1 à ×3 ; le relief ne se lisait à aucun des quatre facteurs — 9 m sur
898 m de large, vus en axonométrie à angle fixe. **La carte est plate depuis le
2026-08-12** : il n'y a plus rien à exagérer, et la question de l'exagération
verticale se ferme d'elle-même.

## 🎨 La couleur ne suit plus la typologie — 2026-08-18

C'était la règle la plus ancienne du rendu, et elle est tombée devant une photo
aérienne : *« un `sous_type` = une teinte, rien à peindre jamais »* posait la
**même couleur sur les murs et sur le toit**, donc chaque bâtiment était un
solide d'une seule teinte et la ville sortait en blocs de pâte à modeler.

Ce qui la remplace n'est pas une peinture, c'est une règle de plus :

| | |
|---|---|
| **le toit et le mur sont deux matériaux** | et la ville se lit d'en haut comme une masse de toits rouges sur des murs clairs, exactement comme une vraie petite ville |
| **le matériau découle de l'ÉPOQUE** | tuile sur l'ancien, étanchéité sombre sur la barre de 1974, bac acier sur la halle, ardoise sur l'équipement. Dans une vraie ville, la couverture EST une trace de la date de construction |
| **chaque bâtiment tire sa teinte de sa POSITION** | décision 35. Deux maisons mitoyennes ne sont plus jumelles, et déplacer une ligne de table ne rebat pas toute la ville |

🔴 **La contrepartie est la touche `C`**, et elle était la condition : la
couleur ne disant plus la typologie, il faut pouvoir la retrouver d'un geste.
Le calque « tissu » repeint les 71 îlots avec la palette d'avant. C'est pour ça
que la table `MASSES` de `palette.py` **reste** alors qu'elle n'est plus la
couleur par défaut : elle est la couleur de ce calque, et celle des aperçus 2D.

**La paire d'images qui juge l'échange** — même vue, même instant :
`wehrau_essai_materiaux.png` et `wehrau_essai_tissu.png`.

## 🪟 Et les murs se percent — 2026-08-18

Même famille, même règle : **aucune fenêtre n'est un triangle**. Le percement
est dessiné par le matériau, comme les rangs de tuile et les panneaux solaires.

Le partage est celui qui vaut partout ici : **`07` décide, Godot dessine.**
L'export sait ce qu'est une rue, un mur mitoyen, un front commerçant, et il
n'envoie qu'un **genre de percement** par mur, plus la longueur de ce mur —
**2 552 murs percés sur 3 547**, soit 23,99 km de façade.

| Genre | Ce qu'on voit | Murs |
|---|---|---:|
| aveugle | de l'enduit plein — les pignons mitoyens, qui font la rangée du cœur ancien | 995 |
| fenêtres | des travées régulières | 1 737 |
| + porte | une entrée au rez, **une par bâtiment** | 697 |
| vitrine | un rez commerçant vitré entre deux trumeaux | 82 |
| bandeau | une bande filante par étage — les trois barres de 1974, les halles | 40 |

Deux choses tiennent le résultat, et ce sont les deux qui auraient pu rater :

- les travées sont **centrées sur chaque façade**, parce que l'export envoie sa
  longueur. Une trame de pas fixe laisserait des demi-fenêtres dans les angles ;
- la **hauteur d'étage vient des données**, pas d'une constante recopiée dans le
  shader. Les murs montant à un multiple exact de cette hauteur, les rangées
  tombent sur les planchers réels et aucune n'est coupée par l'égout.

De loin, le percement **s'efface** en un mur un peu plus sombre au lieu de
grésiller — même geste que les rangs de tuile. La capture qui le juge est
`wehrau_essai_facades.png` : les autres regardent la ville de trop haut.

Le détail complet — les 14 bases de tuile pondérées, le débord de toit,
l'acrotère, les souches, les trottoirs, les bandes de fauche, les deux essences
d'arbre, les cotes de fenêtre et les trois réglages de lumière qui ont dû bouger
avec — est dans **`Prototype/Toits et sol.md`**.

## La seule règle d'affichage qui compte

**On montre l'écart au mois 0 à côté de la valeur.** Partout : dans le bandeau,
dans la fiche. C'est la leçon de `parties.html` — une canopée qui passe de 0,198
à 0,216 ne se voit pas, et sans l'écart on croit que rien ne bouge.

Le corollaire est dans les **calques** : l'échelle de couleur est fixée sur
l'état de DÉPART, jamais recalculée à chaque pas de temps. Sinon l'extrémum
suit le changement et l'image reste identique.

## Ce que ça doit prouver

> Que Wehrau **existe** comme lieu, et qu'une décision s'y **voit**. On doit
> ~~sentir la vallée~~, voir la barre de 1974 comme un objet aberrant de 9
> niveaux au milieu de rangées à 3, trouver monstrueuses les rues à 20 et 22 m
> — et reconnaître une rue qu'on a plantée dix ans plus tôt.

🔄 **Le premier critère est rayé le 2026-08-12** : la carte est plate, il n'y a
plus de vallée à sentir. Ce qui donne son lieu à Wehrau, c'est maintenant la
coupure de l'Ilse — **deux rives inégales et trois ponts** — pas un relief.

🔄 **Et le « 9 niveaux » du deuxième est périmé depuis le 2026-08-19** : devant
l'image, l'auteur a jugé les barres surdimensionnées pour une ville de 5 350
habitants. Elles sont maintenant **trois, de 46 à 58 m de long, à 6 niveaux** —
ce que la décision 13d appelait déjà « un petit Neubau ». L'aberration ne tient
donc plus à la hauteur seule mais à la **forme** : trois dalles parallèles au
milieu de l'îlot, toit plat, sans aucun égard pour les rues. ⚠️ Le critère du
vault (`Plan 3 mois.md:48`) dit toujours 9 — il reste à réécrire ou à annuler,
et c'est l'auteur qui tranche.

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
  ville.gd             l'état, les rampes, les indicateurs, la caisse. Aucun nœud  ← LE NOYAU
  energie.gd           la table des 12 lignes, les formules, les deux prix. Tout statique
  chantiers.gd         ancien prototype à deux décisions, conservé comme trace
  selection.gd         le raycast. Rend un (couche, fid), rien de plus
  interface.gd         la ville à gauche, l'îlot et son curseur à droite
  moniteur_performances.gd  le thermomètre F3, sans dépendance au jeu
  materiaux.gd         6 matériaux, zéro texture
  camera_axo.gd        orthographique, lacet libre et hauteur de 6° à 90°
outils/
  sonde_api.gd         interroge ClassDB — à lancer avant de déboguer autre chose
  essai_energie.gd     contrôle imprimé de l'ancien prototype
```

`ville.gd`, `energie.gd` et `chantiers.gd` **ne touchent aucun nœud** — même discipline que
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

✏️ **Le trait de sélection ne passe pas par là, et n'est pas de la
géométrie.** L'objet choisi est redessiné **seul**, en blanc plat, dans une
petite vue à part qui a son propre monde (donc ni ciel, ni lumière, ni le reste
de la ville) et la **même caméra** que l'image. Un shader plein écran allume
ensuite les pixels vides situés à moins de 3 pixels de ce masque : c'est le
bord de la silhouette. Conséquences gratuites — le trait épouse les pignons,
les débords de toit et les cheminées, et il garde la **même épaisseur à tous
les zooms**. Sans sélection, la vue à part est éteinte et le rectangle caché :
le contour ne coûte rien.

🔴 **Une rue ne se détoure pas sur son maillage rendu**, et c'est la seule
exception : un tronçon est fait de morceaux disjoints — chaussée, mètres
libres, un bout de trottoir par îlot riverain — séparés de plusieurs mètres.
Le masque prend alors le **couloir** que `07` exporte dans `couloirs` (axe +
largeur façade à façade), dont `Constructeur.couloir` fait un ruban plat jamais
affiché. Ne pas essayer de recoudre ça dans le shader : l'écart est en mètres,
le trait en pixels.

🔄 **Retour en arrière signalé** : c'était un ruban de triangles posé au sol le
long de l'anneau de l'îlot, que `07` exportait dans `contours`. Il n'entourait
que l'emprise AU SOL — les bâtiments en sortaient, et dans le cœur ancien ils
le cachaient. Ne pas le réintroduire pour « éviter un rendu supplémentaire » :
un anneau au sol ne peut pas connaître la hauteur des bâtiments.

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

## 🔴 Le contrôle de recoupement — il n'existe plus

**À lire avant de faire confiance à un chiffre de ce projet.**

Jusqu'au 2026-08-12, deux moteurs appliquaient les mêmes règles — `08_jouer.py`
en Python, `ville.gd` + `chantiers.gd` en GDScript — et devaient tomber sur le
même résultat. Le contrôle tenait sur D07, la seule décision jouée. **D07 est
partie dans `archive/`, et le contrôle avec.**

Le dernier résultat connu, et il passait : 0,2732 de canopée au mois 60 côté
Godot, 0,273 côté classeur, 64 tronçons · 6 217 m · 114,9 pts des deux côtés.
Le détail est dans `archive/essai_d07.gd.txt`.

Ce qui reste : `-- --essai` sort ses captures et vérifie que **le clic au
centre de la vue « barre » rend l'îlot 32** — donc que les volumes restent
cliquables après le découpage. C'est un contrôle d'interface, pas de
simulation.

🆕 **Trois contrôles chiffrés se sont ajoutés le 2026-08-17 avec la caisse**, et
eux arrêtent la maquette en code ≠ 0 : la caisse tombe **exactement** du coût
annoncé au mois de la décision · l'îlot que la caisse ne peut pas payer reste
refusé **sans qu'un centime bouge** · un chantier en cours n'accepte pas de
seconde commande. Ils ne comparent toujours qu'un moteur à lui-même, mais ils
attrapent une formule qui dérive — et c'est là que le risque est, la recette
étant une intégrale.

L'essai imprime aussi le **tableau d'économie au mois 0** : ce que coûte chaque
tissu, en combien d'années il se rembourse, et ce que coûterait la ville
entière. C'est ce tableau qui sert à régler `CAISSE_DEPART_KE` et
`DOTATION_KE_MOIS` — sans lui, les deux se règlent à l'aveugle.

⚠️ **Ce que ça veut dire concrètement** : à partir de maintenant, une formule
fausse dans le noyau ne sera plus attrapée par personne avant qu'on la voie à
l'écran. Quand le thème énergie arrivera, ses trois invariants imprimés ne
compareront **qu'un moteur à lui-même** : ils attrapent une formule qui dérive,
pas deux implémentations qui divergent. Si le classeur doit rester le banc
d'essai, c'est lui qu'il faudra étendre — sinon il devient une archive, et il
faut le dire.

## 🏘️ Les parcelles et les toits

Depuis le 2026-08-12, la ville n'est plus 63 pâtés pleins.

| | |
|---|---|
| `04c_parcelles.py` | découpe l'emprise de chaque îlot en **parcelles** — couche `parcelles` du `.gpkg`, **1 096 lignes** depuis le peigne du 2026-08-13 |
| table `BATI`, en haut de `07` | transforme une parcelle en bâtiment : recul de rue, jeu au voisin (**0 = mitoyen exact**), profondeur bâtie, pente du toit |
| → | **702 volumes**, 301 parcelles enclavées devenues cours et jardins |

🔴 **Les deux chiffres de la dernière ligne datent d'avant le peigne.** Le
parcellaire a été refait le 2026-08-13 (`Génération procédurale` dans le
vault) : **987 parcelles ont désormais une façade contre 705**. La maquette
continuera d'afficher l'ancienne ville tant que `07_exporter_godot.py` n'aura
pas été relancé. ⚠️ Le relancer changera la surface de toit, donc le potentiel
solaire de ~9,5 % qui attend un arbitrage.

### 🌳 Les cœurs d'îlot sont dessinés, et pas tous verts

Le fond de parcelle était calculé puis **jeté** : derrière les maisons, on
voyait le terrain nu, donc du gris. Il est maintenant émis — **667 espaces
libres, 9,4 ha**, dont **440 plantés (66 %)** et 317 arbres.

« Pas tous » est le sujet, pas un détail : la table `VERDURE` en haut de `07`
donne la part plantée par tissu — **0,92 en pavillonnaire, 0,30 au cœur
ancien**. C'est ce contraste-là qui fait lire le tissu vu d'en haut, mieux que
la couleur des façades. Une cour de cœur ancien
est pavée ; un jardin de lotissement est vert.

Les jardins partent dans le maillage des **masses**, dans le groupe de leur
îlot : le cœur d'îlot appartient à l'îlot, donc il se clique avec lui et se
teinte avec lui quand un calque s'allume.

### 📦 Les barres et les halles sont des boîtes

`RECTANGULAIRE` (`07`) : `barre_1970` et `friche_industrielle` ne suivent plus
le découpage parcellaire ; leurs volumes sont ramenés à un rectangle aligné
sur la rue.

🔴 **Le piège, mesuré** : prendre le *rectangle englobant* de l'empreinte est
immédiat à écrire et faux. Une parcelle en L a un englobant qui sort très loin
d'elle — **44,5 m de débordement mesurés**, contre 4,8 m avant. On cherche donc
le plus grand rectangle qui **tient dedans** (rastérisation par balayage, puis
plus grand rectangle de cellules pleines). C'est l'emprise au sol, pas une
taille inventée, et ça ne peut pas sortir de la parcelle.

### ✂️ Les pointes sont coupées, `\_/` au lieu de `\/`

Un angle rentrant de l'emprise fabrique des empreintes en lame de couteau. Sous
**70°**, le sommet est remplacé par une arête franche : **162 pointes coupées
sur 119 empreintes**.

🔴 **Ce qui a raté au premier essai, et qui vaut d'être gardé** : couper 2,5 m
de chaque côté d'une pointe à 15° laisse un mur de **65 cm** — c'est encore une
lame, juste tronquée. Ce qu'on vise n'est pas une longueur de coupe mais **la
largeur du mur qui reste** (`PAN_COUPE_M = 4,5 m`), et on coupe aussi loin qu'il
le faut pour l'obtenir.

Et pour ce qu'un chanfrein ne peut pas sauver — une empreinte qui est une lame
de bout en bout — `LARGEUR_MIN_BATI = 3 m` : en dessous, le volume n'est pas
construit et la parcelle repart au jardin.

### 🌊 La ville est plate, l'Ilse coule 2 m plus bas, et les champs y descendent

Demandé par l'auteur le 2026-08-12 : *« la carte est plate, juste la rivière
est −1 à 2 m comme si elle était canalisée »*, puis **repris le 2026-08-18**,
coupe dessinée à l'appui : *« la rivière doit être 2 m en dessous du niveau de
la ville. La ville reste plate mais les champs adjacents à la rivière peuvent
obtenir une topographie simple. »*

```
   champ 0 m ────┐                              ┌──── champ 0 m
                  \___                      ___/       la pente, sur 10 m
     ville 0 m ─┐      │██████████████│     /
      le quai   │      └──────────────┘            −2,00 m   le plan d'eau
                └──────────────────────            −2,60 m   le lit
```

Donc **deux bords d'eau et non plus un seul** — et c'est la même ligne de code
qui fait les deux. Une seule règle : *le mur de quai monte jusqu'à la surface
du sol*. Là où la ville tient la rive, le sol est à 0 et le mur fait 2,6 m ; là
où c'est un champ, le sol est déjà au ras de l'eau et il ne reste du mur qu'une
lèvre noyée.

Le talus, lui, tient dans **une seule fonction** — `Relief.z(x, y)` — que tout
ce qui touche le sol interroge : la plaque, le champ, ses bandes de fauche, ses
arbres, le haut du mur. Aucune de ces surfaces ne peut donc se fendre sur une
autre : elles partagent la même vérité au lieu d'en recopier une.

```
z = −2,20 · f(distance à l'eau) · g(distance aux autres bords du champ)
```

`g` est la moitié qui fait le travail difficile, et elle remplace trois cas
particuliers : au raccord ville/champ le talus **se relève sur 10 m** et le mur
de quai sort du sol tout seul, au lieu d'une marche de 2 m · un pont qui
traverse un champ garde sa terre à 0 de part et d'autre, parce que la route est
un couloir **dehors** de l'emprise · et rien ne déborde jamais du champ, donc ni
la voirie ni les trottoirs n'ont à savoir que le relief existe.

| Mesuré à l'export | |
|---|---:|
| champs riverains | **4** (3, 5, 6, 8) |
| rive en pente | **984 m** sur 2 475 m de berge |
| le reste, en quai droit | **1 462 m** |
| mailles de talus | **2 019** |
| le sol descend à | **−2,15 m**, soit 15 cm sous la nappe |

🔄 **Ce que l'argument d'avant disait, et pourquoi il ne tient plus.** La
version du 2026-08-12 défendait un bord franc partout : *« une berge qui remonte
en pente douce sur 12 m se lisait comme un talus, donc comme rien »*. C'était
vrai avec 1 m de creux — 8 % de pente. À 2,2 m sur 10 m on est à **22 %**, et
surtout la pente ne remplace plus le mur PARTOUT : c'est le **contraste** entre
le quai droit de la ville et le talus des champs qui fait lire les deux.

🔴 **Un piège payé le jour même, et il se voyait.** Un point posé **sur** la
ligne de berge n'est ni dedans ni dehors pour un test d'appartenance : il
ressortait à 0 pendant que ses voisins descendaient à −2,20. Or la plaque et le
talus sont justement coupés sur cette ligne — la berge se hérissait de **dents
grises d'un mètre**, une par sommet. Le bord de l'eau appartient au champ,
point.

**Ce que la mise à plat a supprimé**, et qu'il faudrait réécrire pour revenir :
une classe `Terrain` qui rejouait la règle de pente de `04` (3,2 % en amont,
1,3 % en aval, plafond à 9 m) et l'échantillonnait sur une grille de 4 m · la
subdivision des caps de sol et des rubans de chaussée, qui ne servait qu'à
suivre le relief · le champ d'altitude côté Godot, remplacé par un maillage
comme les autres.

**Ce que ça a coûté en géométrie** : le sol passe d'un champ de 64 736
altitudes à une **plaque de 16 448 triangles** (8 244 avant le talus, qui la
fait redébiter au pas de 3 m sur ses seules berges de champ), trouée à l'exact
le long des berges — une maille que la berge traverse est coupée par la droite de cette
berge, et on ne garde que les morceaux hors de l'eau.

⚠️ **La voirie reste à 0, comme tout le reste.** Au-dessus du chenal, elle passe
donc au-dessus du vide : **un pont, sans une ligne de code qui parle de pont.**

🟢 **Le clic n'a pas changé de niveau.** Toutes les parcelles d'un îlot
tombent dans **le même groupe de maillage** : la géométrie descend à la
parcelle, la sélection reste à l'îlot. Toujours ~237 nœuds cliquables. La
parcelle est l'entité persistante des **données** (35), pas celle du clic.

### 🏠 Le toit plat de repli : essayé le 2026-08-12, puis retiré

Demandé, écrit, regardé, retiré **le même jour** — et c'est la bonne façon de
s'en servir. La demande était : *« quand la surface est trop difficile pour
avoir un toit propre, fait un toit plat »*. Devant l'image, l'auteur a préféré
**les toits d'avant** : une ville qui a des toits, même froissés, plutôt qu'une
ville dont les toits sont propres et plats.

Ce qui a été mesuré au passage mérite d'être gardé, parce que c'est vrai que la
règle soit branchée ou non :

- **Le bon critère est le PLI d'un pan** — l'écart entre les deux diagonales du
  quadrilatère, nul dès que le pan est plan. Médiane **55 cm**, 9ᵉ décile
  **1,89 m**, pire **2,59 m**. La distribution est **continue, sans
  décrochement** : il n'y a pas de seuil à trouver, seulement un curseur.
- 🐞 **La mesure évidente est fausse.** « La distance du 4ᵉ sommet au plan des
  trois autres » : sur un pignon, les deux sommets du faîtage se confondent
  presque, le plan de base est une lame, et **574 bâtiments sur 702** se
  déclaraient vrillés alors que leur pan était un triangle parfaitement plat.
- 🎯 **Le critère « angle trop aigu » ne se déclenche jamais.** `_ecorner` coupe
  déjà tout ce qui passe sous 70°, et le plus petit angle de la ville est
  **70,2°**. Le problème des pointes était réglé en amont ; celui qui restait
  était le pli.

Pour la refaire : elle est dans git, commit *« Toit plat quand l'empreinte ne
sait pas porter deux pentes »*. À 0,35 m de pli toléré, 381 bâtiments
basculaient au toit plat.

### Les trois défauts connus, imprimés à chaque export

Ils sont dans la console de `07`, pas dans un coin de tête :

| Le défaut | Aujourd'hui |
|---|---|
| **50 empreintes concaves** prennent un toit plat | la recette du faîtage suppose qu'un versant avance dans un seul sens ; sur une empreinte concave il se retourne |
| **791 pans réorientés** à l'émission (7 %) | l'orientation d'un toit est **calculée**, pas déduite du parcours de l'anneau. ⚠️ Donc la colonne « toits dehors » du contrôle est vraie **par construction** et ne prouve rien — c'est le nombre de réorientations qui informe |
| **17 bâtiments mordent sur la rue**, jusqu'à 5,5 m | pic de mitre sur angle rentrant. Borné par le recul du tissu, sans commune mesure avec les 258 m de la session 9, mais à reprendre |

🔗 **L'interface du toit** (41 · 64) est posée : chaque îlot expose
`toit_m2` (surface réelle, pente comprise — **11,7 ha**), `toit_pente` et
`toit_plat`. L'ombrage était déjà là, c'est `canopee`. Le code d'énergie lira
ces quatre nombres **sans savoir** si c'est le générateur ou une table de
coefficients qui les produit — c'est ce qui fait qu'il ne l'attend pas.

⚠️ **`toit_m2` est passé de 11,9 à 11,7 ha**, et ce n'est pas une perte : la
surface se compte maintenant **volume par volume**, avec la pente de ce
volume-là. Les 50 bâtiments à toit plat comptaient avant pour l'emprise étirée
de leur tissu. C'est le nombre que l'énergie viendra lire ; il vaut mieux qu'il
soit juste.

## 🟠 Les chiffres qui attendent ton œil

Aucun n'est tranché. Ils sont dans le code avec ce commentaire, pas cachés.

**La table `TISSU`** (`04c_parcelles.py`) — la largeur de façade et la
profondeur visées par tissu. C'est elle qui décide du grain de toute la ville :
7 m au cœur ancien fait un peigne de maisons étroites, 13,5 m en pavillonnaire
fait des maisons individuelles avec un jardin derrière (c'était 18 m, ce qui
donnait des blocs trop larges et trop peu nombreux). Le contrôle n'est pas « est-ce que le nombre est
juste » mais **« est-ce que le cœur ancien ressemble à un cœur ancien »**.

**La table `BATI`** (`07_exporter_godot.py`) — recul de rue, jeu au voisin,
profondeur bâtie, pente du toit.

🔴 **`profondeur` se mesure depuis la FAÇADE, pas depuis la rue** — et c'était
faux jusqu'au 2026-08-12. Le recul était pris *sur* la maison : avec 5,5 m de
recul et 10 m de profondeur, le pavillon faisait **3,5 m de creux**, et ça
valait pour *tous* les pavillons de la ville. Une table dont le nombre ne décrit
pas ce qu'on voit est un piège, pas un réglage.

🔴 Le `jeu` est le seul réglage qui fait
basculer tout un tissu, et il est **réversible dans un seul sens** : écarter des
maisons mitoyennes est facile, les recoller demanderait de réécrire le
générateur (61).

**`CANOPEE_ALIGNEMENT_MAX = 0,40`** (`07_exporter_godot.py`) — la canopée d'une
rue plantée de bout en bout. Constante de **rendu** : elle ne change aucun
chiffre de simulation. Les **1 169 emplacements hors de l'eau** sont exportés
dans le JSON et **321** sont visibles à t0. Les 98 emplacements qui tombaient
dans le polygone de l'Ilse — sur les franchissements — sont écartés avant
l'export, y compris pour une plantation future.

*Deux chiffres de cette liste sont partis avec leur système* : la **surchauffe**
(`3,5 × imperméabilisé − 2,5 × canopée`, +1,59 °C à t0) et le **+0,25 de canopée
de D07**, alors que la canopée d'une rue plafonne à 0,18 dans les données. Les
deux sont consignés dans `archive/`, avec ce qu'il y avait à en dire.

## Ce que la maquette ne montre pas, et ne montrera pas

- **La canopée des îlots bâtis** — 9,5 ha. Elle se compte, elle ne se dessine
  pas : les cours et les jardins existent maintenant, mais rien n'y pousse.
  07 l'imprime au lieu de le taire.
- **Les carrefours.** Les chaussées se recouvrent ; comme elles sont toutes
  dans un seul plan et d'une seule couleur, ça ne se voit pas. Le vrai
  problème est largement dissous par 32f.
- **Le trafic.** ✅ Tranché (62) : ce sera un **flux agrégé** plus quelques
  véhicules figurés qui ne calculent rien. Jamais de graphe navigable. Pas
  encore commencé.
- **Les façades, les fenêtres, les intérieurs.** Le détail ira dans la texture
  et la normal map, jamais dans la géométrie : le budget polygonal appartient
  à la silhouette.
- ✅ ~~**Le raccord entre bâtiments voisins**~~ — **résolu**. La question n°16
  est fermée par 61 : la parcelle est une partition, donc deux voisines
  partagent une arête exactement, et un `jeu` de 0 pose les deux murs dessus au
  millimètre. Le joint en toiture sort du même mouvement.
- ✅ ~~**Des toits, des parcelles**~~ — **faits le 2026-08-12**.
