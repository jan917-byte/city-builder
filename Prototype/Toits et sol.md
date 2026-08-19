# Étape 4 — Les toits et le sol

> **Critère de réussite : croire qu'on y habite.**
> Ouverte le 2026-08-18, à la demande de l'auteur, devant une photo aérienne
> de petite ville allemande. L'étape 2 (les parcelles) passe en pause : ce qui
> lui restait est descendu dans [CHANTIERS.md](../CHANTIERS.md) §1 n°8.

Ce que l'auteur a demandé, en une phrase : *« la couleur des bâtiments ne doit
plus suivre la typologie mais être plus réaliste, avec un niveau de détail
adéquat pour un prototype qui doit quand même rendre beau »*.

Et ce qu'il a tranché en ouvrant l'étape :

| La question | Ce qui a été choisi |
|---|---|
| jusqu'où va le détail | couleur **+ relief du toit + sol et arbres**. ~~Pas les fenêtres~~ → 🔄 **les fenêtres aussi**, demandées le 2026-08-18 dans la journée (§ 2 bis) |
| comment on lit encore le tissu | par l'**époque et le grain**, **plus un calque « tissu »** à la touche |
| des assets ? | **zéro** — tout reste une recette |
| est-ce que ça ouvre l'étape 4 | **oui** |

---

## 1. Ce qui a changé, et pourquoi c'est une règle et pas une peinture

🔴 **La règle qui saute est « un `sous_type` = une teinte ».** Elle vient de la
direction artistique, elle a tenu jusqu'ici, et elle produisait une ville en
blocs de pâte à modeler : la même teinte était posée sur les murs **et** sur le
toit, donc chaque bâtiment était un solide d'une seule couleur.

Ce qui la remplace tient en trois lignes, et aucune n'est un choix posé à la
main sur un objet :

1. **le toit et le mur sont deux matériaux distincts** ;
2. **le matériau découle de l'époque du bâti**, pas de sa fonction. C'est déjà
   ce que fait une vraie ville : la couverture est une trace de la date de
   construction ;
3. **chaque bâtiment tire sa teinte de sa position**, donc deux maisons
   mitoyennes ne sont plus jumelles.

⚠️ **Ce n'est pas un abandon de « aucun état visuel posé à la main ».** C'est
le contraire : avant, la couleur venait d'une **étiquette** (`sous_type`) ;
maintenant elle vient de **l'époque + la position**, qui sont deux données.

### Les couvertures

| Tissu | Couverture | Ce que ça donne à l'écran |
|---|---|---|
| cœur ancien, front commerçant, maisons de ville, pavillonnaire | **tuile** | la masse rouge qui fait la ville vue d'en haut |
| équipement (dont l'église) | **ardoise** | gris-bleu sombre, un objet public au milieu du rouge |
| barre 1970 | **étanchéité** | bitume et gravier, plat et sombre |
| friche industrielle | **bac acier** | gris métal, les halles du sud |

La tuile a **14 bases pondérées**, pas une. Deux d'entre elles sont sombres et
ne pèsent qu'**1/14 chacune** : au premier essai, sept bases également
probables donnaient 28 % de toits sombres, et comme un versant au nord est
**déjà** assombri par la lumière, des quartiers entiers sortaient noirs.

### Les murs

Ils restent **pastel et clairs** — la règle de la DA ne tombe pas, elle devient
enfin visible : un mur clair a maintenant quelque chose de sombre à côté de
lui. Cinq à six enduits par tissu, du blanc cassé au jaune paille, plus une
dérive de valeur (±5 %) et de température (±3,5 %) tirée du lieu.

🔄 **La barre de 1974 perd son gris-bleu froid**, qui était le seul endroit de
la palette où une teinte disait « étranger ». Ce que ça enlève est rendu
ailleurs et mieux : **son toit est plat et sombre quand toute la ville est en
tuile rouge**, et sa silhouette est déjà la plus longue de Wehrau.

## 2. Le relief du toit

| Ce qui est ajouté | Mesure | Ce que ça fait |
|---|---|---|
| **le débord de toit** | 0,40 m, sur les 570 volumes à deux pentes | c'est LA ligne qui fait qu'un volume cesse d'être une boîte : une bande d'ombre sur la façade et un liseré sombre autour de chaque maison vue d'en haut |
| **la rive** | 0,26 m d'épaisseur | la tranche du débord. Sans elle, le toit est une feuille de papier |
| **l'acrotère** | 0,45 m, sur tous les toits plats | le muret qui borde une terrasse. Sans lui, la barre et les halles sont des boîtes rases |
| **les souches de cheminée** | 0,8 m de côté, 1,3 m au-dessus du faîtage, **452 posées (79 % des toits pentus)** | vu d'en haut, c'est ce qui distingue un toit habité d'un couvercle |
| **les rangs de tuiles** | 32 cm, dans le shader | se voit au zoom rapproché, s'efface avant de grésiller |

⚠️ **Le toit est monté de l'épaisseur de la rive au lieu d'être posé au ras du
mur.** Sinon on voit *sous* le débord dès que la caméra descend (10° est une
vue offerte par la maquette), et sous le débord il n'y a rien : les faces
arrière sont cullées, donc on voit à travers la maison.

⚠️ **Le décalage d'anneau mesure le sens du parcours au lieu de le supposer.**
Un anneau horaire décalé avec la normale d'un anneau trigonométrique **rentre**
au lieu de sortir : le toit passerait sous le mur, et le défaut serait
invisible sur les 95 % de bâtiments dont l'anneau est dans le bon sens.

## 2 bis. Les fenêtres

> Demandées le 2026-08-18, après le lot ci-dessus, en une phrase : *« fais
> aussi la génération procédurale des fenêtres »*. La note disait « pas les
> fenêtres » ; elle ne le dit plus.

🔴 **Aucune fenêtre n'est un triangle.** Elles sont dessinées par le matériau,
comme les rangs de tuile et les panneaux solaires. Deux quads par fenêtre sur
les 756 volumes coûteraient environ **40 000 triangles** — plus de la moitié de
la ville entière — pour un détail qui, à la vue par défaut, tient sur deux
pixels. La règle du budget polygonal ne bouge pas : *le détail va dans le
matériau, jamais dans le maillage.*

### Ce que la carte décide, et ce que le matériau dessine

C'est le partage qui compte, et c'est le même que partout ailleurs ici :

| | Ce qu'il sait | Ce qu'il produit |
|---|---|---|
| **l'export** (`07`) | la rue, le mitoyen, le tissu, la parcelle | un **genre de percement** par mur, et la longueur de ce mur |
| **le matériau** (Godot) | quatre nombres par sommet de mur | les travées, les étages, les vitres, les portes |

Le matériau ne sait donc pas ce qu'est une rue. Il reçoit, par sommet :

- **`u` et `L`** — combien de mètres depuis le coin gauche de la façade, et la
  longueur totale de cette façade ;
- **le genre et un tirage** — la recette à appliquer, et le nombre tiré de la
  position du bâtiment, le même sur ses quatre murs.

⚠️ **`L` est ce qui centre les travées, et ce n'est pas un raffinement.** Sans
lui, la trame se poserait sur une grille mondiale : un mur de 7,2 m et son
voisin de 11,8 m auraient les mêmes fenêtres au même endroit, donc des
demi-fenêtres dans les angles. C'est la faute exacte que la grille de panneaux
a coûté à corriger la veille — voir § 5 ter.

### Les cinq genres, et ce qui les décide

Trois questions par mur, dans cet ordre, et c'est tout :

| Genre | Quand | Ce qu'on voit | Murs |
|---|---|---|---:|
| **aveugle** | mur **mitoyen**, ou plus court que 2 m | de l'enduit plein | **995** |
| **fenêtres** | façade arrière, ou sur cour | des travées régulières | **1 737** |
| **+ porte** | la **plus longue** façade sur rue | idem, plus une entrée au rez | **697** |
| **vitrine** | front commerçant, sur rue | un rez vitré entre deux trumeaux | **82** |
| **bandeau** | barre 1970, friche industrielle | une bande filante par étage | **36** |

**2 552 murs percés sur 3 547**, soit **23,99 km de façade**.

🧱 **Le mur mitoyen est aveugle, et c'est lui qui fait la rangée.** Dans le
cœur ancien, une maison a deux façades percées — rue et cour — et deux pignons
pleins. Personne ne l'a peint : un mur est mitoyen si les trois quarts de sa
longueur longent, à moins de 30 cm, une arête presque parallèle d'un **autre**
bâtiment. Trois points de contrôle et pas un seul : effleurer le coin du voisin
ne compte pas.

🚪 **Une porte par bâtiment, jamais deux.** Un pavillon d'angle a deux façades
sur rue ; il n'a pas deux entrées. La porte va sur la plus longue des deux, et
l'autre redevient une façade ordinaire.

### Les cotes, et pourquoi ce sont celles-là

| | Mesure | Ce que ça fait |
|---|---|---|
| **l'étage** | **2,70 m**, lu dans les données | les murs montent à un multiple exact de cette hauteur, donc **aucune fenêtre n'est coupée par l'égout** — et le matériau n'a jamais besoin de connaître la hauteur du bâtiment |
| **l'allège** | 0,95 m | hauteur d'appui. C'est elle qui fait qu'un étage se lit comme un étage |
| **le linteau** | 2,25 m | 45 cm de mur sous la gouttière |
| **la fenêtre** | 1,15 m de large, **deux vantaux** | le meneau central ne s'allume que sur les ouvertures assez larges pour en avoir un |
| **l'entraxe** | 2,75 à 3,70 m, **tiré du bâtiment** | deux maisons mitoyennes n'ont pas le même rythme de travées |
| **l'embrasure** | ombre au linteau, appui de 13 cm | sans elle, une fenêtre est un autocollant |
| **le bandeau de 1974** | ouverture de ~2,4 m, meneaux de 30 cm | ⚠️ à 1,75 m d'entraxe, mesuré, la barre sortait **criblée de petits carrés** — une carte perforée, pas un bandeau. Ce qui fait la bande, c'est que l'ouverture soit deux fois plus large que haute |

### 🔴 Loin, on ne dessine plus : on assombrit

C'est la partie qui n'est pas décorative. À la vue par défaut (1 200 m de
large), une fenêtre de 1,15 m tient sur **deux pixels** : la dessiner n'y fait
plus que du bruit, qui grouille dès que la caméra bouge. Le matériau rend donc
la main à la **part vitrée du mur** — un enduit un peu plus sombre, ce qui est
exactement ce que l'œil voit à cette distance, et pas un seul scintillement.
Même geste que les rangs de tuile, et même raison.

Ce que ça change à l'écran : la ville de haut ne bouge presque pas. Ce qui
change, c'est **la vue basse**, qui était le prix assumé de la caméra ouverte
du 2026-08-17 — « sous 15°, on regarde la ville par ses façades, qui sont des
murs nus d'une seule teinte ». Ce n'est plus vrai.

⏱️ **Coût mesuré : 0,2 s** sur les 11 s de l'export, et **0 triangle**.

## 3. Le sol et les arbres

| | Mesure | Ce que ça change |
|---|---|---|
| **les trottoirs** | 2,0 m de chaque côté, sur **174 tronçons sur 178** | ils se prennent sur les mètres **libres** du tronçon : là où la donnée n'en laisse pas, il n'y en a pas. C'est ce liseré clair qui sépare la chaussée du bâti — sans lui, une rue et un parking sont la même tache grise |
| **les bandes de fauche** | **7 champs, 198 bandes de 15 m**, ±5,5 % de valeur | un champ était un aplat de 3 ha, la plus grande surface unie de l'image. Le sens de la fauche est tiré de la position, donc deux champs voisins ne se fauchent pas dans le même sens |
| **la teinte des champs** | 5 bases : blé, prairie, chaume, herbe grasse, terre travaillée | une par champ, tirée de sa position |
| **les arbres** | **1 107 feuillus, 170 conifères** | tronc + trois lobes décentrés + dégradé vertical bakké, au lieu d'une sphère à six segments. Les deux essences sont deux recettes, pas deux fichiers |
| **les arbres d'alignement** | **279 à t0** | ils étaient exportés depuis toujours et n'étaient plus affichés depuis la suppression de D07. Or ils ne dépendent pas de D07 : leur seuil se compare à `routes.canopee`, une donnée de départ. Une ville aux boulevards plantés dans la donnée et nus à l'image, c'était un mensonge |

🔴 **Le tronc a fallu le sortir du feuillage.** L'arbre a **deux surfaces** —
couronne et tronc — avec deux matériaux, parce que la couleur d'instance du
MultiMesh multiplie tout ce qu'elle touche : un `material_override` aurait
peint le tronc en vert.

🌊 **La rivière est une zone interdite au semis.** Les arbres de parc
l'étaient déjà par construction, mais les alignements suivaient aussi les
trois franchissements : leur décalage latéral posait **11 arbres visibles dans
l'eau**, et gardait 87 emplacements futurs au même endroit. Les **98
emplacements** sont maintenant écartés avant l'export ; la chaîne s'arrête si
un seul tronc retombe dans le polygone de l'Ilse. Contrôle mesuré : **0**.

🛣️ **La chaussée est une deuxième zone interdite.** Un arbre d'alignement
était bien posé hors de la chaussée de **son** tronçon, mais cette bande libre
peut être coupée par une autre rue au carrefour — et l'axe arrondi d'un virage
peut aussi la rattraper. Le contrôle lit donc toutes les surfaces d'asphalte,
leurs rallonges de carrefour comprises, avec **40 cm de marge** : les 36 cm du
plus gros tronc, plus l'arrondi de l'export. Mesuré : **1 arbre semé et 150
emplacements d'alignement écartés**, dont **42 visibles à t0** ; **0 tronc
reste dans la chaussée**, y compris parmi les emplacements qui pousseront plus
tard.

### 3 bis. Le jardin, son accès et sa haie

Les parcelles pavillonnaires qui portent réellement un bâtiment sont
**toutes vertes**. Avant, le tirage qui variait les cours dans les autres
tissus laissait aussi 8 % des pavillons sur un sol gris : aucune donnée de la
ville n'expliquait cette différence, elle disparaît donc du seul pavillonnaire.

Chaque maison reçoit un chemin de **1,40 m** jusqu'à sa limite sur rue. Pour
chaque façade possible, l'export mesure tous les trajets qui arrivent à angle
droit sur la route, puis garde le plus court. La **haie basse de 1,15 m** fait
désormais tout le tour de la parcelle, rue comprise, sauf à l'ouverture de ce
chemin. Une limite partagée est dessinée une seule fois, donc deux voisins
n'empilent jamais deux volumes au même endroit.

| Contrôle | Mesure |
|---|---:|
| parcelles pavillonnaires bâties vertes et bordées | **174 sur 174** |
| chemins maison→route | **174**, soit **749,4 m** |
| écart maximal à la perpendiculaire | **0,0000°** |
| tronçons de haie, après les ouvertures | **820** |
| longueur visible de haie | **10,32 km** |
| autres tissus touchés | **0** |

Ce ne sont pas des assets : le sol, le chemin et la haie dérivent du tissu,
de la parcelle, de la présence et de la position réelles du bâtiment. Une
parcelle vide reste donc ouverte.

## 3 bis. La rue : la chaussée, le trottoir, et les courbes

Demandé le 2026-08-18, en deux phrases : *« séparation chaussée trottoirs,
courbes au lieu d'angles (sauf aux croisements) »*. Trois arbitrages ont été
posés avant de toucher au code — vraie bordure, trottoir contre la façade,
arrondi des seuls vrais coudes.

### Le trottoir a changé de place, pas seulement de hauteur

🔴 **Ce que la version d'avant cachait, et c'est le cœur de cette passe** : le
trottoir n'était pas un trottoir. C'était un quadrilatère **plus large que la
chaussée, glissé dessous**, à 3 cm : ce qui dépassait de part et d'autre de
l'asphalte en tenait lieu. Il n'y avait donc **ni bordure, ni coin de rue**, et
au carrefour les deux rubans se recouvraient — le carrefour était une flaque.

Ce qui le remplace n'est pas un réglage mais un changement de propriétaire :
**le trottoir appartient à l'îlot, pas à la rue**. C'est un anneau posé le long
de la limite de parcelle, tout autour du pâté. La conséquence est celle qu'on
cherchait :

> **Aucune ligne du code de voirie ne parle de carrefour.** Un carrefour est ce
> qui reste entre quatre anneaux d'îlot — exactement comme un pont est ce qui
> reste quand on creuse le chenal sous une voirie qui, elle, ne sait rien.

L'ordre transversal est enfin celui d'une vraie rue :

```
   façade │ trottoir │ mètres libres │ chaussée │ mètres libres │ trottoir │ façade
          └ bordure de 14 cm
```

| | Mesure | Ce que ça change |
|---|---|---|
| **la bordure** | 14 cm | la marche, avec sa face verticale. C'est elle qui fait qu'une rue a un bord au lieu d'un changement de teinte |
| **le trottoir** | 2,0 m, **381 arêtes d'emprise sur 462 qui longent une rue** | il s'arrête là où la donnée ne laisse pas 80 cm : une ruelle de 5 m n'en a pas, et c'est juste |
| **la longueur bordée** | **17,78 km de bordure, 65 îlots** | |
| **les coins** | **338 coins de trottoir** | ils tournent tout seuls : le coin est l'angle de l'anneau |

⚠️ **Le retrait de `04b` n'est pas recopié, il est RETROUVÉ.** Une arête
d'emprise a été reculée de la demi-largeur de sa rue — ou de la largeur entière
au bord de l'eau, pour que le quai de 22 m tienne sur la terre. Refaire ce
calcul dans `07` en ferait une seconde source de vérité, qui dériverait le jour
où `04b` changerait. On cherche donc, dans la direction du dehors, une rue
parallèle, et on **mesure** la distance.

### Les courbes s'arrêtent où le corridor s'arrête

| | Compte |
|---|---|
| coudes internes de la voirie | **81** |
| dont marqués (≥ 20°) | **33** |
| **arrondis** | **25** |
| carrefours, qui gardent leur angle | **122** |

🔴 **Le rayon n'est pas un goût, c'est ce que le corridor accepte.** Arrondir un
tracé le pousse vers l'intérieur du virage : le trottoir extérieur gonfle
d'autant, le trottoir intérieur maigrit. Quatre plafonds mesurés sur la
géométrie de chaque coude — le confort (25 m), tenir dans les deux segments
voisins, un élargissement extérieur sous 3 m, et 50 cm de trottoir intérieur
qui doivent survivre. Résultat : de 6 à 20 m de rayon selon le coude.

**Conséquence assumée** : les coudes très serrés ne s'arrondissent pas. Dans
une rue de 13 m bordée de façades, un virage à 90° est **un angle du tissu** —
les maisons y font l'angle, la chaussée le fait aussi. L'adoucir demanderait de
bouger les parcelles, donc de rouvrir l'étape 2.

⚠️ **Un coude a deux bords, et les deux doivent s'accorder** sinon la rue
change de largeur dans le virage. Les deux îlots ne se parlent pas : ils lisent
le **même rayon d'axe** et en déduisent le leur — R moins leur distance à l'axe
du côté intérieur, R plus cette distance du côté extérieur. Deux arcs
concentriques. Mesuré : **35 coins arrondis, dont 14 coudes des deux bords** ;
les autres ont un bord sans trottoir (champ, berge, bord de carte).

### Deux défauts trouvés en chemin, et corrigés

🔴 **La chaussée était éclairée à l'envers depuis toujours.** Mesuré :
**3 060 triangles sur 3 060** avaient leur normale tournée vers le **bas**. La
ville roulait donc sur un asphalte qui ne recevait que la lumière ambiante,
jamais le soleil. Le sol des îlots, lui, était dans le bon sens : l'écart de
valeur entre une rue et une cour, qu'on prenait pour un choix de palette, était
un bug d'orientation.

🔄 **Le trottoir était de la couleur du sol nu.** `TROTTOIR` (#8D8A82) et
`MINERAL_CLAIR` (#83838A) — la teinte de la plaque — étaient à 2 % de valeur
l'un de l'autre. Le trottoir était donc invisible **partout sauf contre
l'asphalte**, et la « bande claire de part et d'autre de la rue » qu'on croyait
voir était en fait le sol nu. Il faut qu'il se distingue de **deux** voisins,
pas d'un : #A8A399.

## 3 ter. Le marquage au sol — sept règles, aucun trait posé à la main

Demandé le 2026-08-18 : *« dessine les lignes blanches et les passages
piétons, procédural avec des règles, pas à la main »*. Il n'y a donc **aucune
liste de positions** nulle part : le marquage lit la largeur de chaussée, la
hiérarchie du tronçon, le nombre de branches à chaque nœud et la courbure de
l'axe. Changer une rue dans la source refait son marquage sans qu'on y
revienne.

| | La règle | Ce qu'elle lit | Ce qu'elle pose |
|---|---|---|---|
| ① | **ligne d'axe** si la chaussée fait 5,5 m ou plus | l'emprise de circulation | trait de 3 m, vide de 6 m, largeur 15 cm |
| ② | **axe continu dans les virages** | la direction change de 30° en moins de 30 m | trait plein, 12 m de part et d'autre |
| ③ | **ligne de rive** sur boulevard et voie de berge | la hiérarchie | trait plein continu, à 35 cm du bord |
| ④ | **rien dans le carrefour** | la demi-chaussée de la rue **la plus large qui y passe** | le marquage s'arrête avant la zone d'échange |
| ⑤ | **passage piéton** sur chaque branche de carrefour | il faut un trottoir des deux côtés | bandes de 50 cm, écart 50 cm, 2,50 m de profondeur |
| ⑥ | **une traversée de plus** si on reste 120 m sans passage | la longueur du tronçon | un passage au milieu, autant qu'il en faut |
| ⑦ | **jamais sur un pont** | le chenal de l'Ilse | le passage est refusé |

**Ce que ça donne, mesuré à l'export :**

| | |
|---|---|
| passages piétons | **260**, soit **2 171 bandes** |
| traits d'axe discontinus | **999** |
| portions d'axe passées en trait plein (virages) | **23** |
| lignes de rive | **110** |
| triangles ajoutés | **7 232**, sur 56 698 |
| tronçons trop étroits pour un trottoir, donc **sans passage** | **35** |
| passages refusés au-dessus de l'Ilse | **22** |

🔴 **La règle ⑤ est celle qui fait le tri toute seule, et c'est elle qui
mérite l'œil.** Elle ne nomme aucune rue : elle repose sur le même test que
le trottoir (`TROTTOIR_MIN`, 80 cm). Une ruelle de 5 m n'a pas la place d'un
trottoir, donc elle n'a pas de passage piéton — et **une rue de 10 m non
plus**, parce qu'à 10 m il ne reste que 65 cm entre la chaussée et la limite
de parcelle. Ces 35 tronçons ne sont pas une exception saisie à la main, ils
sont la conséquence d'un chiffre déjà arrêté ailleurs. Si l'auteur trouve que
le centre manque de traversées, c'est **la largeur des rues** qu'il faut
regarder, pas une liste de passages.

⚠️ **Les 22 passages refusés au-dessus de l'eau ne sont pas tous des ponts.**
Les trois franchissements en fournissent quelques-uns ; le reste vient des
**quais**, dont l'axe passe par endroits au-dessus du chenal. C'est une
propriété de la carte, pas du marquage — mais c'est le marquage qui l'a
rendue visible, et elle vaudra un regard.

**Ce que ça a coûté ailleurs :** rien de neuf. Une ligne blanche est un ruban
de 15 cm et une bande de passage un ruban de 50 cm — c'est le **même code que
la chaussée**, donc le même sens de faces et le même onglet dans les courbes.
Il a seulement fallu lui apprendre deux choses : un décalage latéral (pour la
ligne de rive) et de ne **pas** se rallonger toute seule aux extrémités — la
rallonge qui remplit les carrefours déborderait précisément là où on vient de
lui interdire d'aller.

La peinture n'est pas blanche : `#C6C3B9`, à ~78 % de valeur. Un blanc pur au
sol sort plus lumineux que les tuiles et attire l'œil en bas de l'image, alors
que le marquage n'est qu'une trame de lecture. Le marquage est rangé dans le
**groupe de son tronçon** — cliquer une ligne blanche ouvre la fiche de la
rue, comme cliquer son trottoir.

## 3 quater. La rivière descend de 2 m, et les champs y descendent avec elle

Demandé le 2026-08-18, avec une coupe dessinée : *« la rivière doit être 2 m en
dessous du niveau de la ville. La ville reste plate mais les champs adjacents à
la rivière peuvent obtenir une topographie simple. »*

```
   champ 0 m ────┐                              ┌──── champ 0 m
                  \___                      ___/       la pente, sur 10 m
     ville 0 m ─┐      │██████████████│     /
      le quai   │      └──────────────┘            −2,00 m   le plan d'eau
                └──────────────────────            −2,60 m   le lit
```

🔴 **Ce qui change vraiment, ce n'est pas la profondeur, c'est qu'il y a
maintenant DEUX bords d'eau.** Avant, l'Ilse avait le même bord franc partout —
un mur vertical, que la rive soit une rue ou un champ. Maintenant le quai reste
droit et le champ descend, et **c'est la même ligne de code qui fait les deux** :
le mur de quai monte jusqu'à la **surface du sol**, quelle qu'elle soit. Là où
la ville tient la rive, le sol est à 0 et le mur fait 2,6 m ; là où c'est un
champ, le sol est déjà au ras de l'eau et il ne reste du mur qu'une lèvre noyée.

| Mesuré | |
|---|---:|
| champs riverains | **4** sur 7 (îlots 3, 5, 6, 8) |
| rive en pente | **984 m** |
| rive restée en quai droit | **1 462 m** |
| pente | 2,20 m sur 10 m, soit **22 %** |
| mailles de talus | **2 019** |
| le sol descend à | **−2,15 m** — 15 cm sous la nappe, pour que le trait d'eau tombe DANS la pente et non sur une lèvre de terre |

**Une seule fonction porte le relief**, et tout ce qui touche le sol la lit : la
plaque, le champ, ses bandes de fauche, ses arbres, les arbres d'alignement, le
haut du mur de quai. C'est ce qui garantit qu'aucune de ces surfaces ne peut se
fendre sur une autre — elles partagent la même vérité au lieu d'en recopier une.

Elle a deux moitiés. La première est la pente dessinée. **La seconde est celle
qui fait le travail difficile** : le relief se **relève à 0** dès qu'on approche
d'un autre bord du champ. Sans elle, il aurait fallu trois cas particuliers :

- au raccord ville/champ, le talus remonte sur 10 m et **le mur de quai sort du
  sol tout seul**, au lieu d'une marche de 2 m en travers de la rive ;
- **un pont qui traverse un champ** garde sa terre à 0 de part et d'autre : une
  route est un couloir *dehors* de l'emprise de l'îlot, donc le talus s'en
  écarte sans qu'une ligne de code parle de pont ;
- rien ne déborde jamais du champ, donc **ni la voirie ni les trottoirs n'ont à
  savoir que le relief existe**.

🌾 **La berge n'est ni fauchée ni cultivée** — on ne descend pas une
moissonneuse à 22 %. Sa teinte part de celle du champ et va aux deux tiers vers
le vert du parc : deux champs voisins ont donc encore deux berges différentes,
et la cassure du haut se lit même à contre-jour, là où la pente seule ne se
verrait pas.

🔴 **Le piège payé le jour même, et il se voyait à l'écran.** Un point posé
**sur** la ligne de berge n'est ni dedans ni dehors pour un test
d'appartenance : il ressortait à 0 pendant que ses voisins descendaient à
−2,20 m. Or la plaque et le talus sont justement coupés sur cette ligne — la
berge se hérissait de **dents grises d'un mètre**, une par sommet. Le bord de
l'eau appartient au champ, point.

⚠️ **La pente douce avait déjà été essayée, et rejetée** le 2026-08-12 : *« une
berge qui remonte sur 12 m se lisait comme un talus, donc comme rien »*. C'était
vrai à 1 m de creux (8 %). Ce qui change ici : le creux double, et surtout la
pente **ne remplace plus le mur partout** — c'est le contraste entre le quai
droit et le talus qui les fait lire tous les deux.

## 3 quinquies. Les routes ne volent plus sur l'eau : le quai porté et le pont

Demandé le 2026-08-18, juste après le creusement : *« les routes au bord de la
rivière volent sur l'eau. Fais en sorte qu'il y ait un mur entre l'eau et la
route ; le mur peut dépasser de 1 m pour faire une barrière. Les routes qui
passent sur l'eau doivent être transformées en pont. »*

**Ce qui volait, mesuré avant de toucher à quoi que ce soit : 7 212 m²
d'asphalte au-dessus du chenal, sur 42 tronçons.** Deux causes, et il fallait
les séparer parce qu'elles ne se réparent pas de la même façon.

| | Ce que c'est | Combien |
|---|---|---:|
| ① | la **voie de berge est tracée sur la ligne d'eau**. Son bord côté rivière dépasse la berge de 3,25 m (une voie `rive`) à 7,00 m (le boulevard de quai). Elle ne traverse rien : elle **longe** | 6 400 m², 39 tronçons |
| ② | trois tronçons (**145**, **168**, **169**) **traversent** vraiment, sur 35 à 40 m, leurs deux bords au-dessus de l'eau | 800 m², 3 tronçons |

### 🔴 La règle ne nomme aucune rue

On regarde, **station par station le long de la chaussée**, si l'eau est sous
**un** bord (on longe) ou sous **les deux** (on traverse) :

- **les deux bords mouillés, sur au moins 8 m → un PONT** ;
- **un seul bord, et la rue est parallèle à la berge à moins de 60° → un QUAI
  PORTÉ** ;
- ni l'un ni l'autre → rien.

C'est tout. Changer le tracé d'un quai dans la source refait son mur ; ajouter
un franchissement fabrique son pont, son tablier et sa pile. Le seuil de 8 m
n'est pas décoratif : sans lui, les **~35 amorces de rue** qui débouchent sur un
quai — la demi-largeur d'asphalte que chaque chaussée ajoute pour remplir son
carrefour — devenaient chacune un petit pont de 4 m.

### Une seule ligne de mur, deux façons de descendre

```
   longer                                    traverser
   ─────────────┬──┐                        ┌──────────────┐   parapet 1,00 m
     chaussée   │  │                        │   chaussée   │
   ═════════════╪══╪  0,05                  ├──────────────┤   tablier −0,65
        (vide)  ║  ║                        └──────────────┘
   - - - - - - -║  ║  −2,00 nappe    - - - - - -║ pile ║- - -   −2,00
   ─────────────╨──╨  −2,60 fond    ───────────╨──────╨──────   −2,60
```

> ⏸️ **CETTE SECTION DÉCRIT L'ÉTAT DU 2026-08-18. Le mur de quai ne se
> construit plus comme ça** — il suit la berge depuis le lendemain, voir
> **§ 3 septies**. Ce qui reste vrai ici : le **pont**, ses culées, ses piles,
> et le fait que le parapet soit le même muret des deux côtés. Les chiffres du
> quai, eux, sont périmés ; ils servent de point de comparaison.

**La ligne du mur était le plus dehors des deux : la berge, ou le bord de
l'asphalte plus sa bande de 1,10 m.** Un seul `max` pour les deux cas — le mur
collait à la berge quand la rue était en retrait, il s'avançait sur l'eau quand
elle débordait. Ce qui l'a fait tomber n'est pas ce `max` mais **ce qu'on
décalait** : l'axe de la chaussée, évasements de carrefour compris.

Ce qui change d'un cas à l'autre, c'est **jusqu'où le mur descend** : au fond du
chenal quand il porte un quai, à la sous-face du tablier quand il porte un pont.
Le parapet, lui, est **le même muret dans les deux cas** — c'est ce qui fait
qu'un bord de pont et un bord de quai se ressemblent, comme dans une vraie
ville. Son chaperon est plus clair que son corps : vu d'en haut, c'est **lui**
qui dit qu'il y a une barrière.

| Mesuré | |
|---|---:|
| ponts | **3** — 119 m de tablier, **3 piles** |
| quai porté | **1,51 km** |
| parapet de 1,00 m | **1,74 km** |
| mur avancé sur l'eau | **1,50 km** |
| triangles | **9 338** |
| l'Ilse, largeur médiane | **38 m → 32 m** — les quais lui prennent 6 m |

**Le contrôle imprimé** range tout l'asphalte au-dessus du chenal en trois
familles, et c'est lui qui dit si les deux règles couvrent la ville :

| | m² | |
|---|---:|---|
| **porté** — posé sur un tablier ou un quai | 7 116 | **98,7 %** |
| **derrière** — en l'air, mais en deçà du nu du mur, donc masqué par le parapet qui passe devant : ce sont les amorces de rue | 87 | invisible |
| **au-delà** — en l'air *et* au-delà du mur : le seul chiffre qui se verrait | **5** | dépassement max 4,22 m, sur six coins de carrefour d'un mètre carré au plus |

### Deux défauts trouvés en chemin, et le second était gros

🔴 **Un mur de 2,65 m debout au milieu de la ville.** Le boulevard de quai a son
**axe posé sur la ligne d'eau** : la berge est alors à distance **nulle des deux
côtés**, et la mesure seule concluait « bord de l'eau » du côté des façades
aussi. Une distance ne dit pas de quel côté est la rivière. La règle qui
manquait tient en une question — *y a-t-il de l'eau 30 cm au-delà du bord
trouvé ?* — et elle a supprimé **la moitié du mur** : 2,98 km → 1,51 km, et
9 338 triangles au lieu de 17 028.

⚠️ **Cinq trous dans le parapet**, vus à l'écran avant d'être expliqués. La
distance à la berge se mesure **dans la section** de la rue — c'est ce qui évite
de prendre une berge qui passe derrière les façades d'en face. Mais la section
ne répond pas toujours : quand la berge fait un **angle**, son point le plus
proche est oblique et un rayon à 90° passe à côté d'un bord pourtant à trois
mètres ; et quand la voie de berge dérive si loin que son **axe est dans le
chenal**, il n'y a plus rien devant elle à quarante mètres. D'où un secours au
plus proche voisin — pour la distance, de ce côté-là ; pour la direction du
fleuve, des deux côtés, puisqu'elle est la même sur ses deux rives.

### Ce qui n'a pas bougé, et c'est voulu

- **Le mur de berge du chenal reste posé partout**, y compris sous les quais où
  il est masqué. Il coûte peu et il garantit qu'aucune fente ne s'ouvre au
  raccord ; le mur avancé ne descend au fond **que là où il s'est avancé**,
  sinon deux parois coplanaires se battraient en duel sur toute la longueur de
  l'Ilse.
- **Le dessus du quai est 1 cm sous le sol** (`Y_QUAI`), pour la même raison :
  là où le mur se pose sur la berge, sa bande de couronnement recouvre un ou
  deux décimètres de plaque. Un centimètre plus bas, c'est le sol qui gagne. Il
  reste 6 cm **au-dessus** de l'asphalte, le seul voisin qu'il ne doit pas
  laisser passer devant.
- **Aucune ligne de code ne décide qu'un tronçon « est un pont »** : le pont est
  un **état de la route**, pas un objet du jeu. Son tablier et son parapet
  partent dans le groupe du tronçon — cliquer un parapet ouvre la fiche de la
  rue, comme cliquer son trottoir.

## 3 nonies. La place du marché montre enfin ses 123 places

*Demandé le 2026-08-19 :* « **dessine des places de parc sur la place centrale.
regarde comment faire de manière procédurale.** »

L'îlot 19 est le seul îlot de **sol** de Wehrau qui porte du stationnement :
`04` lui compte **127 places** depuis toujours — sa surface × la part de
parking de son tissu ÷ 25 m². Ce nombre n'existait que dans la fiche. À
l'écran, la place la plus centrale de la ville, celle qui **est** le sujet du
jeu, était un aplat gris de 5 800 m² qui ne disait rien.

### La règle, en cinq lignes, et aucune ne nomme un îlot

| | La règle | Ce qu'elle lit | Ce qu'elle décide |
|---|---|---|---|
| ① | **la direction** | la **plus longue arête** de l'emprise | l'inclinaison des rangées |
| ② | **le module** | rien — c'est une mesure de voirie | allée 6 m + deux rangées de 5 m **dos à dos** = 16 m, répété |
| ③ | **le glissement** | le nombre de places obtenu | la trame glisse (16 crans en travers, 5 le long) et **on garde celle qui en range le plus** |
| ④ | **la place tient** | les **quatre coins** dans l'emprise retirée de 3 m | les rangées s'effilochent le long des bords obliques |
| ⑤ | **l'accès** | 3 m d'allée **devant** la place | pas de place enclavée derrière une rangée |

🔴 **Le déclencheur ne nomme ni l'îlot 19 ni `place_minerale`.** C'est *un îlot
de sol qui porte des places* — et il n'y en a qu'un. La barre et l'équipement
en portent aussi, mais ils ont une hauteur et sont partis dans une autre
branche bien avant. Le jour où le level design pose une deuxième place, elle se
dessinera sans qu'on revienne dans le code.

**Pourquoi la direction ne se choisit PAS sur le compte.** Les neuf directions
possibles ont été mesurées : elles ne s'écartent que de **119 à 129 places**.
Le compte ne les départage donc pas — il les départagerait sur du bruit. La
plus longue arête d'une **emprise** est la plus longue façade sur rue : c'est
ce que ça veut dire qui tranche, pas six places de plus.

### Mesuré

| | |
|---|---|
| places rangées | **123** |
| places annoncées par `04` | **127** — écart **−3 %** ✅ |
| surface utile (emprise retirée de 3 m) | **3 062 m²**, soit **24,9 m² par place** |
| traits peints | **78** |
| triangles ajoutés | **156**, dans les 4 804 du sol |
| arbres de la place | **2**, dont **0** sur la trame ✅ |

🔴 **Le contrôle du haut est le seul du projet qui confronte deux chaînes.**
Partout ailleurs, ce qu'on imprime est mesuré sur ce qu'on vient de dessiner :
c'est vrai par construction. Ici, la géométrie répond à un nombre que `04` a
calculé **sans elle**, avec une constante de 25 m² par place posée à la main
dans un tableau. Les deux ne s'étaient jamais parlé, et ils tombent à 3 %
l'un de l'autre. Au-delà de ~10 %, c'est que l'un des deux ment — le contrôle
le dira.

⚠️ **Le retrait de 3 m n'est pas une marge de dessin.** C'est ce qui reste de
sol nu tout autour, par où on entre et on ressort. Mesuré : à 0,5 m la trame
monte à **153 places** et vient buter contre le trottoir ; à 6 m elle tombe à
**96** et la place se vide. Le réglage a un effet direct sur le nombre de
places qu'on verra disparaître le jour où on dépavera la place.

### Le dos des deux rangées est **un seul trait**

Peint une fois par rangée, il serait peint **deux fois au même endroit, à la
même altitude** — deux quadrilatères coplanaires, donc du z-fighting sur toute
la longueur de la place. Les séparations, elles, traversent les deux rangées
d'un coup quand les deux sont là : 78 traits pour 123 places, et c'est le
marquage réel d'un dos à dos, pas une économie.

⚠️ **La peinture est 1 cm au-dessus du SOL, pas de la chaussée.** Le marquage
de rue vit à −0,01 m ; la place est un cap d'îlot à +0,05 m. Repris tel quel,
le marquage serait passé **6 cm sous la place** — invisible, et rien ne
l'aurait dit.

### Les arbres tiennent le bord

Le semis tire au hasard dans l'anneau et ne sait rien de la trame : sans rien,
un arbre sur deux de la place pousse **au milieu d'une place peinte**. Ce qui
l'en empêche est un **rejet de plus** dans la boucle qui en avait déjà un — la
position reste tirée, elle n'est pas corrigée à la main. Les deux arbres de la
place bordent donc le parking, comme sur une vraie place de marché.

⚠️ **Effet de bord assumé** : un tirage rejeté décale la suite du semis, donc
les arbres des îlots de numéro supérieur à 19 ne sont plus exactement aux
mêmes endroits qu'avant. C'est du bruit, pas un défaut — le semis reste à
graine fixe et le même export redonne toujours la même forêt.

### Ce qu'il faut regarder — touche `M`

`M` est un repère de plus, et il a dû être ajouté : une place de parc fait
**2,5 m de large**, donc à la vue par défaut (1 200 m de cadrage) elle tient
sur un demi-pixel. La capture d'essai `wehrau_essai_place.png` la vise à 130 m
et **68° au-dessus** — un marquage au sol se juge de dessus.

Ce qui prouverait que c'est cassé : des traits qui clignotent avec le sol
(altitude reprise de la chaussée), une rangée sans allée devant elle, un arbre
au milieu d'une place, ou un écart de plus de 10 % au contrôle.

## 3 octies. Le parapet du pont s'arrête au bord de l'eau

*Demandé le 2026-08-19, juste après le mur de quai :* « **les murs des ponts
sont encore dans les routes des berges. Ils doivent s'arrêter aux berges.** »

Le quai venait d'être réparé ; le pont, lui, était resté sur son ancienne règle.
Son muret courait sur **toute la plage du tablier, culées comprises** — donc
2,5 m au-delà de la berge **géométrique**. Or le bord de l'eau qu'on VOIT est
encore ~5 m plus loin dans la rivière : la voie de berge y déborde son asphalte,
et le mur de quai s'est avancé pour le porter. Le muret du pont finissait donc
**7 m après la rive apparente**, en travers de la chaussée qui longe — deux
murets parallèles posés sur le carrefour, à chaque bout de chaque pont.

### La règle, et elle ne mesure rien

> **Le parapet d'un pont ne borde que l'eau libre : ni la terre, ni ce que le
> quai porte déjà.**

Le tablier, lui, ne bouge pas — il lui faut ses culées pour mordre sur la
terre. Ce qui s'arrête, c'est le seul morceau qui **dépasse du sol** :

| L'ouvrage | Où il commence | Où il finit |
|---|---|---|
| tablier, joues, sous-face | 2,5 m dans la terre | 2,5 m dans la terre d'en face |
| **parapet du pont** | **au nu du mur de quai** | **au nu du mur d'en face** |
| parapet du quai | le long de la rive | s'interrompt sous le tablier |

Les deux se rejoignent **en équerre au coin de la culée**, et aucun ne monte sur
la chaussée de l'autre. Le bout est coupé **par dichotomie**, pas à la station :
les stations sont à 2 m, et 2 m de trop remettaient le muret sur la voie de
berge — 2 m de moins ouvraient un trou au coin.

### Mesuré

| | avant | après |
|---|---:|---:|
| parapet de pont, gardé sur l'eau | 238 m | **180 m en 6 bouts** (un par joue) |
| … posé sur le **quai**, en travers de la voie de berge | **56 m** | **0** |
| … posé sur la **terre**, au-delà de la culée | 2 m | 0 |
| asphalte au-dessus du chenal, porté | 100,0 % | **100,0 %** |
| … au-delà du mur | 2 m², dépassement 0,17 m | **inchangé** |
| triangles | 8 368 | **8 158** |

Le contrôle compte aussi les **bouts** : 6 attendus pour 3 ponts, 6 obtenus. Un
septième voudrait dire qu'un muret s'est coupé au milieu d'une travée.

### Ce qui devient visible, et c'est normal

Au coin de chaque culée, un **liseré d'eau** apparaît entre le mur de quai et le
tablier : c'est la rivière, que le muret trop long cachait. Vérifié en plan :
le couronnement du quai vient buter sur le tablier sans laisser de trou, et
aucun asphalte ne reste en l'air — les deux chiffres du contrôle sont
inchangés.

## 3 septies. Le mur de quai suit la berge, plus la route

*Demandé le 2026-08-19, une capture à l'appui :* « **les murs au bord des routes
au bord du fleuve ne fonctionnent pas bien. Ils doivent seulement longer le
fleuve.** »

La veille, le mur de quai était un **décalé de la chaussée** : on prenait son axe
rallongé, on l'écartait de la demi-largeur plus 1,10 m, on rabattait sur la
berge. Sur le papier c'était symétrique du pont ; à l'écran ça donnait trois
choses, et **les trois viennent de la même cause**, pas d'un réglage à corriger.

| | Ce qu'on voyait | D'où ça venait |
|---|---|---|
| ① | des **bouts de mur en travers du débouché** de chaque rue perpendiculaire, au pied des trois ponts | la chaussée se rallonge d'une demi-largeur pour remplir le carrefour, et le mur suivait cet évasement |
| ② | des **bouts francs** au milieu de l'eau, dont un mur de **3,2 m** tout seul | un mur par part de tronçon : **21 morceaux**, 21 paires de bouts |
| ③ | le mur **zigzaguait** dans une rivière droite | il partait jusqu'à **47°** de la direction de la berge |

### La règle tient en une phrase

> **Le mur suit la berge. Il ne s'avance sur l'eau que là où l'asphalte y
> déborde, et d'autant.**

Les arêtes de berge sont **recousues en polylignes continues** — `Chenal` n'en
donnait qu'un sac, et un sac ne se longe pas. Puis, tous les 2 m le long de la
rive, une sonde demande ce que l'asphalte fait ici :

| Ce que la sonde trouve | Ce que le mur fait |
|---|---|
| de la chaussée **qui longe**, débordant sur l'eau | il s'avance d'autant, plus la bande de 1,10 m |
| une chaussée qui s'arrête en deçà de la berge | il se pose **sur la berge** |
| **aucune** chaussée à 4 m | rien : c'est une rive de campagne |
| une berge de champ **en pente** | rien : la ville tient la rive avec un mur, la campagne avec un talus |
| un **tablier** au-dessus | le mur passe dessous, **sans son parapet** |

🔴 **Seule une rue qui LONGE déplace le bord de l'eau** (45° au plus). C'est
la pièce qui a manqué au premier essai : sans elle, l'amorce d'asphalte de
chaque rue perpendiculaire poussait le mur à la porter, et le quai partait en
**festons** dans la rivière — pire que le défaut qu'on réparait. Une rue qui
traverse reste derrière le parapet du quai, comme avant.

Et le nu du mur ne peut pas sauter d'une station à l'autre : **1 m par 2 m au
plus**, ce qui transforme une marche en **épaulement à 27°**.

### Mesuré — avant et après

| | 2026-08-18 (le mur suit la route) | 2026-08-19 (le mur suit la berge) |
|---|---:|---:|
| quai porté | 1,51 km en **21 morceaux** | **1,37 km en 4 longueurs continues** |
| parapet | 1,74 km | 1,57 km |
| écart moyen à la berge | 4,1 à **8,1 m**, sans que rien ne le dise | **c'est l'avancée sur l'eau, et rien d'autre** |
| écart max à la direction de la berge | **47°** | — le mur *est* la berge |
| asphalte au-dessus du chenal, **porté** | 98,7 % | **100,0 %** |
| … masqué derrière un parapet | 87 m² | 0 m² |
| … **au-delà du mur** (le seul qui se verrait) | 5 m², dépassement **4,22 m** | **2 m², dépassement 0,17 m** |
| triangles | 9 338 | **8 368** |

Les 1 372 m de rive suivie se répartissent ainsi sur les 2 520 m de berge :
**990 m de talus de champ**, **106 m sans aucune rue à 4 m** (les deux bouts de
carte, là où l'Ilse quitte la ville), **50 m sous un tablier**.

### Deux pièges payés en chemin

⚠️ **Le quai doit glisser SOUS le tablier, de deux stations.** Arrêté au ras du
pont, il laissait entre son bout et la culée un coin d'asphalte dépassant le
parapet de **1,52 m** — sur quatre tronçons. C'est ce prolongement qui fait
passer le porté de 99,6 % à 100,0 %.

⚠️ **Mais son PARAPET, non.** Le couronnement du quai est à 1 cm sous le sol, le
tablier à 70 cm dessous : un muret de 1 m ressortait par la chaussée du pont et
posait un **crochet en travers**. Le couronnement et la paroi restent sous le
tablier ; le garde-fou s'arrête à son bord.

### Ce qui a disparu du code, et pourquoi c'est le bon signe

Poser le mur depuis la route demandait de **deviner** où était l'eau : un rayon
tiré dans la section de la rue, un secours au plus proche voisin quand la berge
faisait un angle, un test de direction, un compteur de rives vues mais non
bordées. **150 lignes**, toutes supprimées. La berge, elle, sait où elle est.

🔴 **Ce qui n'a pas bougé : le morceau de quai reste dans le GROUPE de sa rue.**
Le mur est taillé d'un seul tenant le long de la berge, puis découpé en
**27 morceaux à tronçon constant** qui partagent leurs sommets de frontière —
le joint ne se voit pas, et cliquer un parapet ouvre toujours la fiche de la
rue. Sans ce partage, une rue aurait eu deux nœuds dans Godot et les calques
thématiques n'en auraient repeint qu'un.

## 3 sexies. Les barres redescendent à la taille de Wehrau

Demandé devant la capture, en une phrase : *« les barres sont surdimensionnées
pour une petite ville, je les veux moins larges et haute, et mets-en 3 »*.
C'était déjà écrit dans `CHANTIERS.md` depuis la décision 13d — à 5 350
habitants, « la barre de 1974 devient un petit Neubau » — et jamais fait.

|  | avant | après |
|---|---:|---:|
| objets sur l'îlot 32 | 2 | **3** |
| longueur | 116 et 93 m | **46, 57 et 58 m** |
| profondeur | 12,8 m | 11,7 à 12,8 m |
| emprise au sol totale | 2 674 m² | **2 003 m²** |
| niveaux | 9 (24,3 m) | **6 (16,2 m)** |
| logements | 198 | **99** |
| Wehrau entier | 5 725 hab. (107 % de la cible) | **5 517 hab. (103 %)** |

### Trois nombres seulement, et chacun fait une chose

- **Le compte** vient du produit `façade × profondeur` de la table des
  parcelles : 11 158 m² d'emprise bâtie divisés par 3 680 m² donnent trois
  parcelles là où 5 600 en donnaient deux.
- **Le sens de la découpe** vient de la profondeur seule, et c'est le piège de
  la ligne. Le découpage ne débite en lanières que si le morceau est moins
  profond qu'une fois et demie la consigne ; l'emprise de l'îlot 32 mesure
  136 × 114 m, donc sous 76 m on repart en dos-à-dos et il en sort une lanière
  de **136 m de long** — une barre de Großstadt, exactement ce qu'on retire.
  À 80 m, les trois parcelles se rangent **en peigne** le long de l'îlot, et
  les trois dalles sortent parallèles.
- **La densité suit la hauteur**, elle ne se choisit pas à part. 2 003 m² sur
  6 niveaux font 12 018 m² de plancher au lieu de 24 066 : à surface par
  logement constante il reste 99 logements sur 198. Laisser 130 log/ha aurait
  entassé les 198 anciens dans 12 018 m², soit 61 m² bruts par logement.

### 🔴 6 niveaux et pas 5, et c'est l'image qui a tranché

Le premier essai est descendu à **5 niveaux**. Sur la capture, les barres
passaient **sous** les faîtages du cœur ancien — 4 niveaux plus une pente à
1,00 sur 11 m de fond, soit 16,3 m — et l'îlot 32 cessait d'être le point haut
de Wehrau. Ce n'était plus une baisse, c'était un effacement : à l'échelle de
la ville entière, la barre ne se distinguait plus de rien. À 6 niveaux le toit
plat arrive au niveau des faîtages, et ce qui porte l'aberration change de
nature — ce n'est plus la hauteur seule, c'est la **forme** : trois dalles
parallèles au milieu de l'îlot, toit plat, sans aucun égard pour les rues.

### ⚠️ Un critère du vault dit toujours « 9 niveaux »

`Plan 3 mois.md:48` — *« la barre de 1974 comme un objet aberrant de 9 niveaux
au milieu de rangées à 3 »* — est l'un des trois critères de réussite du
prototype, et la touche `B` existe pour lui. Il n'est plus vrai. **Ça ne se
tranche pas dans une note de chantier** : soit le critère se réécrit, soit la
baisse s'annule. En attendant, la baisse est en place et le désaccord est
signalé dans le code (`camera_axo.gd`) et dans `Godot/README.md`.

### Un contrôle est tombé au rouge, et il avait raison de tomber

L'essai énergie vérifiait que l'isolation fait baisser la consommation de
**« au moins 1 500 MWh »** — un nombre en dur calé sur les 198 logements de
l'ancienne barre. À 99 logements l'isolation n'enlève plus que 1 069 MWh et le
contrôle est passé au rouge alors que la mécanique était intacte. Un contrôle
qui dépend du level design ne contrôle pas le moteur : il compare maintenant la
baisse mesurée à **ce que la table promet** pour cet îlot-là, quel que soit son
nombre de logements. Les 25 contrôles sont au vert.

## 4. La lumière a dû bouger avec la couleur

Trois réglages ont changé **le même jour et pour la même raison** : ils étaient
tous accordés à une ville dont les murs *étaient* la couleur.

| Réglage | Avant | Après | Pourquoi |
|---|---|---|---|
| l'ambiant | `#8FA0AE` à 0,85 | `#A2A29C` à 0,74 | un ambiant bleu généreux ne se voyait pas sur du rose et du crème saturés. Sur des enduits clairs et neutres, il repeignait **toute façade non exposée au soleil** en gris-bleu, et la ville avait l'air d'un jour de pluie |
| le soleil | 1,15 | 1,45 | la somme des deux ne bouge presque pas : ce qui change est le **partage** entre le soleil et le ciel, donc le contraste entre une façade au soleil et la même à l'ombre. C'est lui qui fait lire un enduit crème comme crème |
| l'occlusion bakée (`AO_MIN`) | 0,62 | 0,74 | à 0,62 le bas de chaque façade tombait à 62 % de sa valeur. Sur des murs colorés ça passait pour de l'ombre ; sur des enduits clairs ça les ramenait tous au même gris et **la variation entre deux maisons voisines disparaissait**. Le SSAO reste là pour le contact au sol, qui est le vrai rôle de cette ombre |

## 5. Le calque « tissu », touche `C`

C'est la **contrepartie** du rendu réaliste, et elle était la condition de
l'auteur. La couleur ne dit plus la typologie ; une touche la rend, en
repeignant les 71 îlots avec la palette d'avant.

Il passe par le **même** uniforme que les calques thématiques, donc l'occlusion
bakée survit et les deux ne peuvent pas s'afficher ensemble — ce qui est voulu :
deux repeints superposés ne se lisent plus.

⚠️ Son opacité est à **1,0** et non 0,88 comme les calques thématiques. Ceux-là
laissent voir la matière sous la mesure ; celui-ci **remplace** la matière. À
0,92 le rouge des tuiles transparaissait et le cœur ancien sortait orange au
lieu de sable.

🔴 **C'est pour ça que la table `MASSES` de `palette.py` reste**, alors qu'elle
n'est plus la couleur par défaut de la maquette : elle est la couleur de ce
calque, et celle des aperçus 2D, qui eux lisent une carte et pas une ville.

## 5 bis. Le trait autour de l'îlot choisi

Demandé le 2026-08-18 : *« quand on sélectionne un îlot, il faut une ligne
blanche autour de ce qui est sélectionné »*, puis, après un premier essai :
*« je veux que la ligne contourne tout ce que contient l'îlot ou le dépasse,
pas uniquement l'îlot au sol. Elle s'adapte à la vue caméra. Elle peut être
légèrement jaune tout comme l'îlot. »*

Jusque-là le seul retour était un **éclaircissement** de l'îlot cliqué, et
c'est le rendu de cette étape qui l'a rendu illisible : sur des toits déjà
clairs, ou sous la touche `C` qui repeint tout, « un peu plus lumineux » ne se
distingue plus d'une variation de matériau. L'éclaircissement **reste** ; le
trait s'ajoute.

🔴 **Le premier essai s'est trompé de géométrie, et c'est l'enseignement de la
passe.** Il posait un ruban de triangles **au sol**, le long de l'anneau
d'emprise de l'îlot. Deux défauts, et aucun n'était réparable en réglant un
nombre : les bâtiments **dépassent** de cet anneau (débord de toit compris),
donc ils sortaient du trait ; et dans le cœur ancien ils sont plantés dessus,
donc ils le **cachaient** — vu du sud-est à 32°, l'îlot 22 n'en montrait qu'un
tiers. Aucune ligne posée au sol ne peut entourer un volume : il faut la
silhouette, donc il faut la vue.

**Ce qui le remplace tient en trois pièces**, et aucune n'est de la géométrie :

| | Ce que c'est |
|---|---|
| ① le masque | une petite vue à part, invisible, où **l'îlot choisi est redessiné seul**, en blanc plat sur du vide, avec la **même caméra** que l'image. Il a **deux pièces** — voir juste en dessous |
| ② le trait | un shader plein écran qui allume les pixels **vides mais à moins de 3 pixels de ce masque** — donc le bord de la silhouette, jamais l'intérieur. Le masque est d'abord élargi de 2 pixels, ce qui recoud les coutures fines (une venelle, un joint de trottoir) sans que le trait s'en aperçoive |
| ③ la caméra | recopiée à chaque image du pivot vers la vue à part : c'est ça, et rien d'autre, qui fait que le trait épouse l'angle |

Ce que ça donne, sans qu'une ligne de code parle de bâtiment : le trait suit
les pignons, les débords de toit et les souches de cheminée, il fait le tour de
la cour d'îlot, il se referme toujours, et son **épaisseur ne change pas au
zoom** puisqu'elle est en pixels.

🔴 **La silhouette rendue, seule, laissait le trait troué.** Demandé le
2026-08-18 au soir : *« la sélection d'îlot doit montrer le contour immeuble +
îlot ; là il y a des trous dans les zones grises »*. La cause tient en une
phrase : **un îlot bâti ne dessine pas son sol**. Sous les barres de l'îlot 32
il n'y a que la plaque de terrain, qui n'appartient à personne — donc rien de
ce gris n'entrait dans le masque, donc le trait collait aux bâtiments et
laissait la moitié de l'îlot dehors. `07` exporte pour ça l'**emprise au sol**
de chaque îlot — **65 îlots, 491 sommets** ; les 6 îlots d'eau n'en ont pas,
ils ne sont pas sélectionnables. Godot en fait une plaque plate **jamais
affichée**, posée dans le masque **à côté** de la silhouette : le trait suit
l'**union des deux**, donc le sol de l'îlot *et* tout ce qui le dépasse en
hauteur.

⚠️ **Ce n'est pas le retour du ruban du premier essai**, et la nuance est
toute la leçon : le ruban *remplaçait* la silhouette, la plaque la
**complète**. Chaque point porte son altitude, pour qu'une emprise de champ
suive son talus au lieu de flotter au-dessus du bord.

🔴 **Une rue ne se détoure pas comme un îlot, et c'est la seule exception.**
Un tronçon n'est pas une surface : c'est la chaussée, plus les **mètres
libres** (du sol nu, qui n'appartient à personne — c'est là que le
stationnement se dessinera), plus **un bout de trottoir par îlot riverain**.
Trois choses disjointes, **séparées de 2,6 m** sur le tronçon 120 : détourées
telles quelles, elles donnent trois bandes parallèles et pas une rue. `07`
exporte donc, pour chaque tronçon, son **couloir** — l'axe (coudes arrondis
compris) et la largeur **façade à façade**, `largeur_m + 1,5 m`, 14,6 m en
moyenne sur les 174 tronçons. Godot en fait un ruban plat **jamais affiché**,
qui n'existe que pour être détouré. ⚠️ Ce n'était pas rattrapable dans le
shader : l'écart est en **mètres** et le trait en **pixels**, donc un
rebouchage à l'écran tiendrait à un zoom et lâcherait au suivant.

**Couleur** : `1,00 / 0,95 / 0,66` — un jaune clair, accordé à
l'éclaircissement de l'îlot. Un blanc pur à côté d'un îlot réchauffé se lisait
comme deux retours différents pour une seule sélection.

⚠️ **Ce que la vue à part ne voit pas, et c'est voulu** : le reste de la ville.
Elle a **son propre monde**, vide — donc pas de ciel, pas de lumière, rien qui
masque l'îlot. Conséquence assumée : quand un immeuble voisin cache l'îlot
choisi, le trait passe **devant** ce voisin au lieu de disparaître. C'est le
même choix que le fantôme de l'essai précédent, en plus simple : un contour de
sélection qu'un bâtiment peut effacer n'entoure plus rien.

🟢 **Ce que ça ne coûte pas** : sans sélection, la vue à part est éteinte et le
rectangle caché — le contour ne consomme rien du tout. 🔄 *Il était écrit ici
que « rien n'a été ajouté à l'export » ; ce n'est plus vrai depuis les
emprises.* Ce que ça pèse : **491 sommets** pour les 65 îlots et 174 couloirs
de rue, ni rendus, ni cliquables, ni éclairés.

## 5 ter. Les panneaux suivent le bâtiment, un pan après l'autre

Demandé le 2026-08-18 : *« la pose des panneaux solaires doit se faire par pan
de toit, et les panneaux doivent si possible être alignés avec la direction du
bâtiment »*.

La grille mondiale a disparu. Chaque volume transmet maintenant au matériau
la direction de son propre faîtage — celle que la façade sur rue avait déjà
décidée. Les rangées suivent cet axe, puis remontent la pente à angle droit.
Sur les rares volumes sans adresse, la plus longue arête du bâtiment sert de
repli : aucun panneau ne retombe sur un axe arbitraire de la carte.

La progression est elle aussi spatiale : sur un toit à deux pentes, le pan le
mieux exposé au sud est rempli de 0 à 50 %, puis le second de 50 à 100 %. Si
les deux regardent est et ouest, l'est départage. Un toit plat reste un seul
pan. À **50 %**, on doit donc voir un versant bleu entier et l'autre encore en
tuile — jamais deux versants mouchetés à moitié.

Ce n'est toujours pas un asset : la même recette couvre les **756 volumes**.
L'export transmet seulement un axe de deux nombres à chaque sommet de toit ;
la surface solaire, le coût, la production et la durée ne changent pas.

## 5 quater. Les performances se voient dans la maquette

Demandé le 2026-08-18 : *« rajoute un moniteur des performances dans Godot »*.
Le panneau est affiché en haut, entre les deux fiches, et `F3` le masque ou le
rappelle. Il lit les compteurs réels de Godot quatre fois par seconde : images
par seconde, temps d'une image, CPU, triangles, appels de rendu, nœuds, mémoire
générale et mémoire vidéo. La couleur passe à l'orange sous **55 ips**, puis au
rouge sous **30 ips** ; il donne donc une alerte lisible avant que le jeu ne
devienne pénible.

Mesuré sur la vue entière, sous Windows avec la RX 9060 XT :

| | mesure vue à l'écran |
|---|---:|
| cadence | **180 ips · 5,6 ms/image** |
| CPU | **7,2 ms** |
| géométrie rendue | **933 501 triangles · 496 appels** |
| scène | **810 nœuds** |
| mémoire | **258 Mio · 252 Mio vidéo** |

Le moniteur est volontairement absent des captures `--essai` : elles jugent la
ville et doivent rester comparables d'une machine à l'autre. La capture manuelle
`wehrau_moniteur_performances.png` prouve son emplacement et sa lisibilité.

## 6. Ce qu'il faut regarder

```bash
python QGIS/scripts/chaine.py --godot
```

```bash
"C:/Users/janha/Desktop/Godot_v4.7.1-stable_win64.exe/Godot_v4.7.1-stable_win64_console.exe" --path Godot -- --essai
```

**La paire qui juge l'échange**, et c'est la seule chose à regarder en premier :

- `QGIS/rendus/wehrau_essai_materiaux.png` — la ville en matériaux ;
- `QGIS/rendus/wehrau_essai_tissu.png` — **la même image**, touche `C`.

Si la première est belle et que la seconde reste lisible, l'échange est bon. Si
la seconde te manque tout le temps, c'est que la lecture par époque ne suffit
pas et il faudra rediscuter.

**Puis, de près** — `wehrau_essai_ilse.png` : le débord de toit doit se voir
comme un liseré sombre autour de chaque maison, les souches comme de petits
points bruns sur les faîtages, et les trottoirs comme deux bandes claires de
part et d'autre de l'asphalte.

**Le marquage** se juge sur `wehrau_essai_barre.png` et `wehrau_essai_ilse.png`.
Ce qu'il faut voir : le **boulevard** porte trois lignes — une discontinue au
milieu, deux pleines contre les bordures ; une **rue** n'en porte qu'une, au
milieu ; une **ruelle** n'en porte aucune. Les **passages piétons** tombent
juste après le coin de rue, jamais dans le carrefour, et aucun trait ne
traverse un passage. Dans les **virages**, la ligne du milieu devient pleine.
Ce qui prouverait que c'est cassé : un trait qui coupe un passage piéton, une
ligne qui continue **au milieu d'un carrefour**, un marquage peint sur un
**pont** au-dessus de l'Ilse, ou des lignes qui scintillent au zoom (le
z-fighting avec l'asphalte, 1 cm plus bas).

🌉 **Le bord de l'eau a deux vues neuves**, et il les fallait :
`wehrau_essai_ilse.png` regarde le chenal à 260 m d'étendue, où un tablier de
70 cm et un parapet de 1 m ne tiennent pas deux pixels.

- `wehrau_essai_pont.png` (touche **O**) — **le plus long franchissement, de
  profil, 12° au-dessus.** Ce qu'il faut voir : l'eau qui passe **sous** le
  tablier, la joue du tablier et son ombre, la **pile** posée au milieu de la
  travée, et le parapet qui court d'une culée à l'autre.
- `wehrau_essai_quai.png` (touche **R**) — le quai porté : l'asphalte, la bande
  de pierre, le parapet, l'eau. Rien entre les deux derniers.

Ce qui prouverait que c'est cassé : de l'asphalte qui **dépasse** le parapet
au-dessus de l'eau, un parapet **interrompu** au milieu d'un quai, un mur qui
descend au fond du chenal **du côté des façades**, ou un tablier qui **plonge**
dans l'eau au lieu de la surplomber de 1,35 m.

🅿️ **La place-parking a sa propre vue** — touche `M`, et
`wehrau_essai_place.png` dans l'essai. Il la fallait pour la même raison que
les fenêtres : une place de parc fait 2,5 m de large, donc à 1 200 m de cadrage
elle tient sur un demi-pixel. La vue est **haute (68°)** — un marquage au sol se
juge de dessus.

Ce qu'il faut y voir : **quatre bandes de places dos à dos**, inclinées comme
la plus longue façade de la place, séparées par des allées vides ; les rangées
qui **s'effilochent** contre les bords obliques au lieu de s'arrêter au carré ;
un **seul trait** entre les deux rangées d'une bande ; et les deux arbres de la
place **au bord**, jamais au milieu d'une place peinte. Ce qui prouverait que
c'est cassé : des traits qui **clignotent** avec le sol, une rangée sans allée
devant elle, un arbre planté dans une place, ou un écart de plus de 10 % au
contrôle imprimé par `07`.

🪟 **Les fenêtres ont leur propre vue** — `wehrau_essai_facades.png`, ajoutée
avec elles. Les autres captures regardent la ville de haut, où le percement est
sous le pixel et où le matériau a déjà rendu la main à l'aplat : **sans cette
image, tout le lot ne se voit nulle part**. Cadrage de 150 m, 14° au-dessus —
la hauteur d'un piéton au bout de la rue, la seule d'où un rez-de-chaussée se
lit.

| Ce qu'il faut voir | Ce qui prouverait que c'est cassé |
|---|---|
| les fenêtres **alignées d'un étage à l'autre**, et la rangée du haut qui s'arrête sous la gouttière | une rangée **coupée en deux** par l'égout, ou qui déborde sur le toit |
| deux maisons mitoyennes avec **deux rythmes de travées** différents | une trame unique qui traverse les façades sans voir les angles |
| un **pignon plein** entre deux maisons de la même rangée | des fenêtres sur un mur qui touche le voisin |
| **une** porte par maison, au rez, sur la rue | deux portes sur un bâtiment d'angle, ou une porte sur la cour |
| la barre de 1974 en **bandes horizontales**, pas en pointillé | un damier de petits carrés — l'entraxe est retombé trop court |
| en dézoomant, les fenêtres **s'effacent** en un mur plus sombre | un grésillement qui court sur les façades quand la caméra tourne |

**Dans les quartiers pavillonnaires** — `wehrau_essai_ville.png` : les jardins
doivent être séparés par de fines lignes vert sombre. Si elles se lisent comme
des murs ou ferment les maisons côté rue, la hauteur ou le filtrage est cassé.

**Et de haut** — `wehrau_essai_dessus.png` : Wehrau doit se lire comme une
masse de toits rouges, avec les halles et les barres en gris sombre au sud, et
les champs rayés autour. L'Ilse doit y traverser les champs **bordée d'un
liseré vert** : c'est le talus, vu de 400 m.

🌊 **Le talus, lui, a maintenant sa propre vue** — touche `G`, et
`wehrau_essai_berge.png` dans l'essai. Les quatre autres repères sont tous
posés sur la ville, où le sol est plat : sans celui-ci le relief ne se voit sur
aucune capture, donc il n'existe pas. La vue est **basse (18°)**, parce qu'une
pente se juge de profil.

Ce qu'il faut y voir : le champ jaune pâle rayé, puis une **bande verte** qui
descend, puis l'eau — et le trait d'eau qui tombe **dans** la pente, pas sur son
bord. Ce qui prouverait que c'est cassé : des **dents grises** le long de la
rive (la plaque qui ressort), une **marche verticale** au raccord ville/champ au
lieu d'une remontée sur 10 m, un **arbre en lévitation** au-dessus de la pente,
ou de l'eau qui déborde par-dessus la berge.

Et sur `wehrau_essai_ilse.png`, en ville : le mur de quai fait maintenant
**deux mètres au-dessus de l'eau** au lieu d'un. S'il n'y a pas de mur du tout
quelque part le long d'un quai, c'est le défaut n° 11 de `CHANTIERS.md` — l'axe
de la rue qui mord le chenal — et il est deux fois plus visible qu'hier.

**Le trait de sélection** se voit sur `wehrau_essai_barre.png` (l'îlot 32, de
près — le trait monte sur les deux barres au lieu de rester au sol), sur
`wehrau_essai_eglise.png` et `wehrau_essai_caisse.png` (à l'échelle de la ville
entière : la même épaisseur, et c'est le seul élément de l'image qui ressort).
Ce qui prouverait qu'il est cassé : un trait qui **ne se referme pas**, qui
reste au sol pendant que les bâtiments en sortent, qui **change d'épaisseur
quand on zoome**, ou une **rue qui ressort en plusieurs bandes** au lieu d'un
seul bloc.

**Les panneaux pan par pan** se jugent sur
`wehrau_essai_solaire_pans.png` : l'îlot 22 est arrêté à **50 %**. Chaque toit
incliné doit montrer un pan bleu entier et son opposé en tuile ; les lignes
blanches doivent rester parallèles au faîtage propre de chaque bâtiment. Ce
qui prouverait que c'est cassé : des demi-pans équipés des deux côtés, ou une
grille qui garde la même direction quand le bâtiment tourne.

**Le moniteur de performances** est visible au lancement normal, au milieu du
bord supérieur. `F3` doit le faire disparaître puis revenir. Ce qui prouverait
qu'il est cassé : un panneau qui recouvre une des deux fiches, des valeurs qui
restent figées quand la caméra bouge, ou une capture `--essai` qui le contient.

## 7. Ce qui reste à cette étape

- ✅ **Les fenêtres** sont faites (§ 2 bis). Ce qu'il en reste, et qui est
  petit : les **pignons sous toiture** ne sont pas percés — ils appartiennent
  au maillage du toit, qui ne porte pas de coordonnées de façade ; il n'y a ni
  **volets** ni **balcons** ; et un mur mitoyen est aveugle **sur toute sa
  hauteur**, y compris la part qui dépasse d'un voisin plus bas. Les trois se
  voient de près et aucun ne se voit à la vue de jeu.
- ☐ **Le sol des cours** est la teinte de la plaque de terrain là où la cour
  n'est pas plantée. Ça passe pour du pavé, mais ce n'est pas un choix : c'est
  ce qu'on voit quand rien n'est dessiné.
- ☐ **Le stationnement DE RUE.** 🔄 Cette ligne disait « 4 587 places à Wehrau
  et aucune ne se voit » ; ses deux moitiés ont bougé le 2026-08-19. La
  **place-parking est dessinée** — 123 places peintes (§ 3 nonies). Les
  **rues**, non : `routes.stationnement` en compte **3 310**, réparties le long
  des mètres libres entre la bordure et l'asphalte, et pas une ne se voit. Ça
  reste la plus grosse chose que le sol ne dit pas encore, et c'est le sujet du
  jeu. La forme est maintenant connue : la place a montré qu'une trame tirée de
  la géométrie retombe à 3 % du compte du tableur — le long d'une rue, ce sera
  un pas de 5,5 m sur les mètres libres, pas une liste de places.
- ☐ **8 coudes marqués sur 33 restent des angles**, faute de place dans le
  corridor — et **11 coudes arrondis sur 25 n'ont qu'un bord de trottoir**. Ce
  n'est pas rattrapable sans bouger les parcelles.
- ☐ **159 empreintes concaves prennent encore un toit plat** — défaut connu,
  antérieur à cette étape → [CHANTIERS.md](../CHANTIERS.md) §1 n°2.
- ☐ **Le talus s'arrête aux champs**, et c'est un choix : le parc (46) et les
  jardins familiaux (48) ne touchent pas l'eau, mais **la friche 31 et la barre
  32 si**, et elles gardent un quai droit. Si l'auteur veut une berge naturelle
  au sud, c'est une ligne — la règle lit le `sous_type` du riverain, pas une
  liste d'îlots.
- ☐ **5 m² d'asphalte dépassent encore le parapet**, sur six coins de
  carrefour — des coins d'un mètre carré au plus, au bout des quais, là où la
  rallonge de remplissage du carrefour va plus loin que la dernière station de
  mur. Chiffré par le contrôle à chaque export ; à reprendre **seulement si ça
  se voit**.
- ☐ **Les quais prennent 6 m à l'Ilse** (38 m de large en médiane, 32 m après).
  C'est la conséquence assumée de porter la rue là où elle est tracée. L'autre
  réponse serait de **déplacer la voie de berge dans la source** — du level
  design, donc la main de l'auteur, pas la mienne.
- ☐ **Le lit reste plat à −2,60 m et personne ne le voit** : la nappe est
  opaque. Le jour où l'eau devient translucide, il faudra lui donner un fond
  qui mérite d'être vu.
- 🔴 **La direction artistique du vault dit encore « un `sous_type` = une
  teinte, rien à peindre jamais »**, et c'est maintenant faux. À fermer dans
  `Questions ouvertes.md` **et** `Décisions arrêtées.md` — pas au détour de
  cette note.

---

**Voir aussi** : [00 - Prototype.md](00%20-%20Prototype.md) ·
[Parcelles.md](Parcelles.md) · [ETAT.md](../ETAT.md) ·
[CHANTIERS.md](../CHANTIERS.md) · `Godot/README.md`
