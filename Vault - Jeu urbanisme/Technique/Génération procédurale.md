---
tags: [technique, procédural, 3d, actif]
statut: ✅ parcelles et toits FAITS le 2026-08-12 — parcellaire refait au **peigne sur rue** le 2026-08-13 : 1 096 parcelles, 987 sur rue. Carte plate depuis le 2026-08-12.
maj: 2026-08-13
---

# Génération procédurale

C'est le **moteur de la beauté** du jeu, pas un raccourci. Le joueur écrit la structure, le système écrit le grain. → [[Vision et prémisses]]

## ✅ Ce qui est fait — le 2026-08-12

> **63 pâtés pleins sont devenus 690 bâtiments.**

| | |
|---|---|
| `04c_parcelles.py` | découpe l'emprise de chaque îlot — couche `parcelles`, **968 lignes** |
| table `BATI`, en haut de `07_exporter_godot.py` | parcelle → bâtiment : recul de rue, **jeu au voisin (0 = mitoyen exact)**, profondeur bâtie, pente de toit |
| → | **690 volumes**, **278 parcelles enclavées** devenues cours et jardins, **624 toits à deux pentes** |

## 🔄 Le parcellaire refait — le 2026-08-13, le peigne sur rue

> **La table disait 8 m de façade sur 20 m de fond. Le générateur n'en respectait que le produit.**

D'après **Vanegas, Kelly, Weber, Halatsch, Aliaga et Müller, *Procedural Generation of Parcels in Urban Modeling*, Eurographics 2012**. Le papier montre qu'un îlot réel se découpe de deux façons, et que la découpe récursive par boîte englobante — celle de Parish & Müller 2001, et celle qu'on employait — produit des parcelles implausibles.

**Le défaut n'était pas où on l'attendait : l'aire tombait juste, la forme était fausse.** Un cœur ancien sortait à 111,7 m² pour 112 visés — mais en **carré de 10,6 m de côté** au lieu d'une lanière de 7 × 16. Une parcelle sur deux tournait le dos à la rue, et **30 % n'avaient aucune façade**, donc aucun bâtiment.

| élancement (grand axe ÷ petit) | avant | après | visé |
|---|---|---|---|
| `coeur_ancien` | 1,59 | **2,07** | 2,29 |
| `maisons_de_ville` | 1,46 | **2,39** | 2,50 |
| `pavillonnaire` | 1,51 | **2,00** | 2,07 |
| `front_commercant` | 1,59 | **1,47** | 1,64 |
| parcelles sans façade *(hors cœurs)* | 30 % | **1 %** | — |

**Le peigne** (méthode « skeleton » du papier, §4.2) longe chaque rue, prend une bande aussi profonde que le tissu le demande, et la débite en dents larges comme la façade visée. Ce qu'aucune rue n'a réclamé est le **cœur d'îlot**. Deux règles font tenir le reste :

- les arêtes sont servies **de la plus longue à la plus courte**, et la bande **déborde de sa profondeur à chaque bout** : la rue la plus longue prend le coin. C'est le schéma `StreetLength` du papier (§4.2.2) obtenu **sans son squelette droit**, hors de portée en Python pur ;
- **rien n'est coupé qui ne touche la rue** — sinon les droites de chaque arête viennent tailler le cœur, qui ressortait en confettis (236 morceaux pour 32 îlots avant ce tri, un ou deux après).

**La boîte n'est pas jetée** : elle garde les deux rôles que le papier lui laisse (§4.3) — les tissus à un ou deux gros objets par îlot, et le **remplissage du cœur**. La table `TISSU` gagne une colonne `style` qui choisit entre les deux.

🎯 **Ce que ça change en aval** : **987 parcelles porteront une maison contre 705**. Les 109 sans façade se décomposent en **102 de cœur, voulues**, et **7 de rue**, qui sont le vrai reliquat — contre 298 confettis dispersés. ⚠️ **Beaucoup plus de toits, donc le potentiel solaire de ~9,5 % est à recalculer** avant de trancher la question ouverte qui l'attend.

👁️ **Et ça se voit** : `apercu_parcelles.py` sort le parcellaire en PNG (`--avant` compare deux versions côte à côte). Ni `apercu_carte` ni `06_etat_zero` ne dessinaient les parcelles — le découpage ne se jugeait qu'au bout de la chaîne, dans Godot. La lecture tient en deux couleurs : **en couleur de tissu la parcelle portera une maison, en vert elle repart au jardin**. Le vert dispersé au milieu des maisons est le défaut ; le vert rassemblé en cœur d'îlot est le résultat.

### ✂️ Les éclats sont réunis à leur voisine — et aucun ne survit

Le peigne laissait **31 parcelles sous les 45 m² d'`AIRE_MIN`**, jusqu'à 0,06 m². Le papier dit quoi en faire (§4.2.3) : **réunir l'éclat à la voisine avec qui il partage le plus long bord**, et recommencer tant qu'il en reste.

`fusionner` met bout à bout les arêtes orientées des deux anneaux, **annule celles qui vont par paires inverses** — le bord commun, qui disparaît — et recoud le reste. Aucune bibliothèque géométrique : c'est l'idée de `couper` prise à l'envers. Un contrôle d'aire refuse le résultat s'il est faux, donc **la décision 61 ne peut pas tomber là** : au pire un éclat survit, et le contrôle le dit.

🐞 **Deux pièges ont failli faire échouer ça, et méritent d'être retenus.**

1. **Les T.** Deux voisines partagent le même bord mais pas le même nombre de **sommets** dessus — `nettoyer` retire un sommet aligné d'un côté et pas de l'autre, et une coupe peut tomber au milieu de l'arête d'en face. L'arête ne trouve alors pas son inverse et la réunion échoue. Mesuré : **26 éclats survivants, dont 18 avaient pourtant une voisine franche**. On remet les sommets manquants des deux côtés avant de comparer.
2. **Le bruit du flottant.** Une aire calculée sur des coordonnées à six chiffres (EPSG:25832) porte un bruit d'environ **2,4·10⁻⁴ m² — exactement 2⁻¹²**. Le seuil relatif du contrôle d'aire tombait dessus et **refusait onze réunions parfaitement justes**. Il se lit maintenant en centimètres carrés : un tracé faux se trompe de m², le bruit de cm², deux ordres de grandeur séparent les deux. *Un seuil serré n'est pas un seuil sûr.*

✅ **Résultat : 48 éclats réunis, aucun survivant, la plus petite parcelle de la ville fait 45,2 m².**

**La décision 61 n'est pas seulement tenue, elle est prouvée** : la somme des aires
des parcelles vaut **100,00 %** de l'aire de l'emprise sur chacun des **54 îlots**,
écart maximal 9,3·10⁻⁷. Le contrôle est imprimé à chaque exécution.

**La décision 35 aussi** : la graine d'une parcelle se dérive de sa **géométrie**,
pas de son rang — une parcelle qui n'a pas bougé garde sa graine même si sa
voisine est redécoupée. Et la partition est calculée **une fois** puis écrite dans
le `.gpkg` : ⚠️ elle ne se rejoue jamais à l'affichage, ce qui est exactement le
piège que 61 signalait.

🐞 **L'erreur qui a coûté la soirée, à garder** : couper au milieu **géométrique**
du rectangle englobant paraissait naturel et donnait n'importe quoi. L'îlot 34 ne
remplit que 67 % de son rectangle ; la coupe médiane le partageait en 927 et
1 685 m², le gros morceau se redécoupait une fois de trop, et le tissu sortait
**deux à trois fois trop fin**. On coupe désormais par l'**aire**.

🏔️ **Le joint en toiture n'a demandé aucun travail.** Le faîtage court
parallèlement à la rue et chaque sommet d'égout est relié à sa projection dessus :
les arêtes de bout donnent des pignons **verticaux**, donc deux maisons mitoyennes
ont leurs pignons dans le même plan et le décrochement entre deux hauteurs se fait
franc. C'était le seul reste de 61.

### ⚠️ Trois défauts connus, imprimés à chaque export

| | |
|---|---|
| **18 bâtiments sur 690 mordent sur la rue**, jusqu'à 4,8 m | pic de mitre sur angle rentrant, borné par le recul du tissu. Sans commune mesure avec les 258 m de la session 9, mais à reprendre |
| **47 empreintes concaves sur 671 prennent un toit plat** | la recette du faîtage suppose qu'un versant avance dans un seul sens |
| **748 pans de toit réorientés à l'émission (7 %)** | l'orientation d'un toit est **calculée**, pas déduite du parcours de l'anneau — un pignon n'est pas un versant. ⚠️ Donc le contrôle « faces vers l'extérieur » est vrai **par construction** pour les toits et ne prouve plus rien de ce côté |

## La phase précédente : une ville crédible et belle

La maquette de masses existe et se joue. Ce qu'elle montre reste **63 pâtés pleins** : un îlot extrudé n'est pas un ensemble de bâtiments. La phase ne s'arrête donc plus là — le seuil devient *« avoir envie de la regarder, et croire qu'on y habite »*. → [[Décisions arrêtées]] 51

🔄 **La subdivision en parcelles entre en phase.** Elle en était explicitement exclue : « le point dur du pipeline, et l'attaquer maintenant reviendrait à changer de projet ». C'est bien un changement de projet, et il est assumé — 2 à 4 semaines d'itération à lui seul.

**Ce qui rend cette phase tenable** : la ville est déjà entièrement décrite dans les données. Il n'y a rien à modéliser, il y a des générateurs à écrire.

> **Le test qui remplace la limite de calendrier** (52) : *si je devais en faire 200, est-ce que je tiendrais ?* Si non, la tâche n'est pas de peindre l'asset, c'est d'écrire le générateur.

| La donnée existante | Ce qu'elle produit en 3D |
|---|---|
| 69 polygones d'îlots | les volumes, par extrusion |
| `hauteur`, 2 à 9 niveaux | × 3 m — la silhouette |
| ~~`altitude_relative`~~ | ⏸️ **plus rien** — la carte est plate depuis le 2026-08-12 |
| 178 polylignes + `largeur_m` | les rubans de voirie |
| `sous_type`, 13 valeurs | la teinte et le grain de chaque volume |
| `impermeabilise` · `canopee` | le sol : minéral, planté, entre les deux |
| `charge` | combien de voitures instancier |

### ✅ ~~Le piège du terrain~~ — résolu en supprimant le terrain

Il y avait ici un vrai piège et sa sortie : `altitude_relative` étant **une valeur par îlot**, extruder chaque îlot depuis la sienne donnait un terrain en escalier, et la sortie était de **rejouer la règle** qui avait produit l'altitude plutôt que d'interpoler après coup → [[Décisions arrêtées]] 32e.

🔄 **Le 2026-08-12, l'auteur a mis la carte à plat** — dans l'image et dans la donnée. Il n'y a plus de champ d'altitude à échantillonner, donc plus de piège. Ce qui l'a emporté n'est pas la difficulté mais l'**invisibilité** : 9 m de relief sur 898 m de large, vus en axonométrie à angle fixe, ne se lisaient à **aucune** des quatre exagérations verticales. Une donnée qui coûte un champ continu et ne se voit pas est une donnée à retirer.

**Ce qui reste comme relief, et c'est tout** : le **chenal de l'Ilse**, murs verticaux, fond à −2 m, plan d'eau à −1 m. Il fait deux choses que la vallée ne faisait pas — il **coupe** la ville en deux, et il fabrique les trois ponts sans qu'aucune ligne de code parle de pont, la voirie restant à 0 au-dessus du vide.

**La leçon générale, elle, tient toujours** : *rejouer la règle plutôt que d'interpoler le résultat*. Elle s'appliquera au premier champ continu suivant.

### Ce qui reste hors phase, et le reste

- **Les intérieurs, les façades détaillées, les fenêtres modélisées.** Le détail va dans la texture et la normal map, jamais dans la géométrie : le budget polygonal appartient à la **silhouette**, qui est ce qui se lit à cette distance.
- **Les agents individuels, tout court.** ✅ Tranché le 2026-08-12 : le trafic est un **flux**, et les véhicules figurés sont de l'ambiance qui ne calcule rien. Voir « le trafic » plus bas → 62

## Le principe de rendu

> La carte est une base de données d'entités portant des **attributs continus**. Le rendu est une **fonction pure de ces attributs**.

Conséquence : les résultats visuels sont **composables** sans avoir à auteur chaque combinaison. C'est ce qui rend l'ampleur du jeu tenable en solo.

Corollaire à tenir dès la maquette de masses : **aucun état visuel n'est posé à la main dans une scène.** Si un rendu ne s'explique pas par une valeur de simulation, c'est un bug de design. → [[Direction artistique]]

## Le pipeline, étape par étape

| Étape | Difficulté | Où on en est |
|---|---|---|
| 1. Subdivision de l'îlot en parcelles | 🔴 ~~2–4 semaines — le point dur~~ | ✅ **fait le 2026-08-12** — `04c_parcelles.py`, 968 parcelles, partition à 100,00 % |
| 2. Parcelle → emprise (offset) | 🟢 | 🟢 le geste existe : `04b` fait déjà reculer l'îlot de la demi-largeur de rue |
| 3. Extrusion en volume | 🟢 | ✅ fait à l'échelle de l'îlot |
| 4. Détail — toits, gabarits, matériau de sol | 🟡 | 🟡 **toits faits** (624 à deux pentes, le joint en toiture compris). Le matériau de sol reste à faire |
| 5. Scatter au sol (arbres, mobilier) | 🟡 | 🟢 les arbres d'alignement poussent avec `canopee` |
| 6. **Carrefours** | 🔴 ~~le plus dur de tous~~ | 🟡 **largement dissous par 32f** — plus de rubans à raccorder, un vide qui se referme |
| 7. **Le trafic visible** | 🟡 | 🎯 en phase — **un flux, pas des agents** (62) |

## ⚠️ La contrainte architecturale du projet

> **La parcelle est l'entité persistante, pas l'îlot. Elle est seedée individuellement.**

Raison : quand le joueur densifie un secteur, **seules les parcelles concernées se régénèrent** — l'îlot entier ne se réinitialise pas. Sinon la mémoire visuelle de la transformation est détruite, et cette mémoire est le cœur du jeu.

C'est à décider **avant** d'écrire la première ligne du générateur de parcelles. Irréversible en pratique. La maquette de masses ne la contredit pas : elle travaille à l'échelle de l'îlot et sera jetée.

## Le raccord des bâtiments voisins — ✅ tranché le 2026-08-12

> **La parcelle est une partition de l'emprise de l'îlot. Le générateur découpe, il ne pose pas des formes dans un vide.**

Conséquence directe : deux parcelles voisines partagent une arête **exactement**, parce qu'elles sont les deux moitiés d'une même découpe. Le mitoyen n'est pas un raccord à faire, c'est une propriété de la méthode. → [[Décisions arrêtées]] 61

Ce que ça écarte : *assumer le non-raccord* (compatible avec une maquette de masses, plus avec un tissu de `maisons_de_ville` et de `coeur_ancien`, où le mitoyen **est** la forme urbaine) et *la grille locale à la Townscaper* (contredit 27 et 29).

**Ce qui reste à faire, et qui n'est pas un travail en plus** : le **joint en toiture** entre deux parcelles de hauteurs différentes. Il tombe sur l'étape 4 du pipeline, déjà en phase.

✅ **Le piège a été évité, et c'est vérifiable** : la partition est calculée par `04c` et écrite dans le `.gpkg`, donc elle ne se rejoue jamais à l'affichage. Formulé à l'époque ainsi — la partition ne doit **pas se rejouer** quand une seule parcelle change. Sinon on ré-effondre le voisinage à chaque clic — exactement ce qu'on reproche à Townscaper (42b) — et la contrainte architecturale ci-dessous tombe avec.

**Réversible dans un seul sens** : écarter les parcelles de quelques centimètres redonne le non-raccord ; l'inverse demanderait de réécrire le générateur.

## Le trafic — rendre `charge` visible

`charge` est déjà là : une affectation par plus court chemin en temps, dont **l'axe de transit est sorti tout seul** sans qu'on le désigne. Mais rien ne bouge à l'écran, donc la variable la plus politique du jeu est un nombre dans une fiche.

Ce que des voitures apportent, et qui n'est pas décoratif : une rue saturée **se voit** avant d'être lue, et « retirer la voiture de l'axe » cesse d'être une ligne de tableur. C'est la règle générale du projet appliquée au mouvement — *qu'est-ce que ça change à l'écran, sans texte ?*

✅ **Tranché le 2026-08-12 : un flux agrégé, plus une poignée de véhicules figurés aux points chauds.** Une densité qui glisse le long du tronçon, proportionnelle à `charge` — cohérent avec la simulation agrégée (34). Les véhicules figurés ne calculent rien : ils ne cherchent pas leur chemin, leur densité se lit sur `charge`. **Jamais de graphe navigable, jamais de file d'attente au carrefour.** → [[Décisions arrêtées]] 62

🎯 **Le critère se juge à l'écran** : *une rue à `charge = 1,00` doit être désagréable à regarder.* Si le flux est trop propre, la marge est d'ajouter des véhicules figurés et de l'encombrement à l'arrêt — pas un système de navigation. C'est une marge bornée, et c'est volontaire.

Ce qui vaut de toute façon :

- **Une instance multiple par famille**, jamais un nœud par voiture.
- **Une réserve d'objets réutilisés** pour tout ce qui est nombreux et éphémère — voitures, piétons, particules. Le geste se prend au début, pas après : créer et détruire en continu finit par écrouler les performances.
- **Des tableaux parallèles plutôt que des objets** si le nombre monte, et la boucle isolée derrière une interface propre — comme la géométrie (41).

## Ce qui se répète doit s'instancier

Arbres, voitures, voitures garées, mobilier : **une seule instance multiple par famille**, pas un nœud par objet.

⚠️ **Ce que la maquette a dû concéder le 2026-08-12** : les 63 îlots bâtis et les 174 tronçons sont devenus **un nœud chacun**. Un maillage fusionné ne se sélectionne pas, ne se surligne pas et ne se reteinte pas objet par objet — sans le découpage il n'y a pas de jeu, seulement une image. ~250 draw calls sur 40 000 triangles ne se voient pas. La règle vaut donc pour ce qui est **nombreux et identique**, pas pour ce qui est **cliquable et distinct**.

## Contrainte du « avant / après »

Le jeu porte sur la **transformation** : chaque élément a besoin d'**au moins deux états**. Donc la géométrie doit être **paramétrique**, pas modélisée à la main. C'est ce qui a disqualifié le pixel art. → [[Direction artistique]]

**Voir aussi** : [[Moteur et architecture]] · [[Géométrie et données]] · [[Plan 3 mois]]
