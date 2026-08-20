# Étape 4 — Les toits et le sol

> **Critère : croire qu'on y habite.** Ouverte le 2026-08-18 devant une photo aérienne de petite ville allemande, sur une phrase : *« la couleur des bâtiments ne doit plus suivre la typologie mais être plus réaliste »*. **Plafond : 140 lignes.**

Ce que l'auteur a tranché en ouvrant l'étape : le détail va jusqu'aux **couleurs, au relief de toit, au sol, aux arbres et aux fenêtres** · on lit encore le tissu par **l'époque et le grain**, plus un **calque à la touche `C`** · **zéro asset**, tout reste une recette.

## 1. La couleur vient de l'époque et de la position, plus de la typologie

🔴 **La règle qui saute est « un `sous_type` = une teinte »** : elle posait la même couleur sur le mur et sur le toit, donc chaque bâtiment était un solide d'une seule teinte et la ville sortait en pâte à modeler. ⚠️ **Ce n'est pas un abandon de « aucun état visuel posé à la main »** — c'est l'inverse : la couleur venait d'une **étiquette**, elle vient maintenant de **deux données**, l'époque et la position (35).

| Tissu | Couverture | À l'écran |
|---|---|---|
| cœur ancien, front commerçant, maisons de ville, pavillonnaire | **tuile** | la masse rouge de la ville vue d'en haut |
| équipement (dont l'église) | **ardoise** | gris-bleu sombre, un objet public au milieu du rouge |
| barre 1970 | **étanchéité** | bitume et gravier, plat et sombre |
| friche industrielle | **bac acier** | gris métal, les halles du sud |

⚠️ **La tuile a 14 bases pondérées, pas une**, dont deux sombres à 1/14 : à sept bases équiprobables, 28 % des toits sortaient sombres, et comme un versant au nord est **déjà** assombri par la lumière, des quartiers entiers devenaient noirs.
Les **murs restent pastel et clairs** (42c) — la règle de la DA devient enfin visible, un mur clair ayant maintenant du sombre à côté. 5 à 6 enduits par tissu, ±5 % de valeur et ±3,5 % de température tirés du lieu. 🔄 La barre de 1974 perd son gris-bleu froid : ce qui la dit étrangère est désormais **son toit plat et sombre au milieu du rouge**.

## 2. Le relief du toit, et les fenêtres

| Ajouté | Mesure | Ce que ça fait |
|---|---|---|
| **débord de toit** | 0,40 m, 570 volumes à deux pentes | LA ligne qui fait qu'un volume cesse d'être une boîte |
| **rive** | 0,26 m | la tranche du débord. Sans elle, le toit est une feuille de papier |
| **acrotère** | 0,45 m, tous les toits plats | le muret de terrasse ; sans lui, la barre et les halles sont rases |
| **souches de cheminée** | 0,8 m, 1,3 m au-dessus du faîtage, **452 (79 % des toits pentus)** | vu d'en haut, ce qui distingue un toit habité d'un couvercle |
| **rangs de tuiles** | 32 cm, dans le shader | se voit au zoom, s'efface avant de grésiller |

⚠️ **Le toit est monté de l'épaisseur de la rive**, sinon on voit *sous* le débord dès que la caméra descend à 10° — et sous le débord il n'y a rien, les faces arrière étant cullées.
⚠️ **Le décalage d'anneau mesure le sens du parcours au lieu de le supposer** : un anneau horaire décalé avec la normale d'un anneau trigonométrique **rentre** au lieu de sortir, et le défaut serait invisible sur les 95 % de bâtiments dans le bon sens.

🪟 **Les fenêtres** (demandées le 2026-08-18) : **aucune n'est un triangle** — deux quads par fenêtre coûteraient ~40 000 triangles, plus de la moitié de la ville, pour un détail qui tient sur deux pixels à la vue par défaut. *Le détail va dans le matériau, jamais dans le maillage.* L'export envoie **un genre de percement par mur** plus la longueur de ce mur ; le matériau dessine et ne décide rien. Mesuré : **2 556 murs percés sur 3 551** (23,92 km) — **995 aveugles** (pignons mitoyens), **1 737 en fenêtres**, **697 portes** (une par bâtiment, sur sa plus longue façade sur rue), **82 vitrines**, **40 bandeaux**. Travées centrées par façade, entraxe tiré du bâtiment, rangées alignées sur les planchers réels — **aucune coupée par l'égout**. **0 triangle ajouté, 0,2 s d'export.**

🔴 **Deux pièges payés le même jour** : ① le test « la rue est-elle devant ce mur ? » mesurait si un pas vers le dehors *rapprochait* de la rue — faux dès qu'un bâtiment est à l'alignement, la distance vaut zéro et tout pas l'augmente : **2 vitrines pour 49 volumes**. On regarde le **signe**, pas la variation → 82. ② à 1,75 m d'entraxe la barre sortait en carte perforée : ce qui fait un bandeau, c'est que l'ouverture soit **deux fois plus large que haute**.
🔴 **La hauteur d'étage est passée au shader depuis les données**, pas recopiée dans son code : c'est le seul nombre qu'il partage avec la géométrie. Les murs montent à un multiple exact de cette hauteur, donc les rangées tombent juste sans que le matériau connaisse la hauteur d'un bâtiment.

## 3. Le sol, les arbres, le jardin

| | Mesure | Ce que ça change |
|---|---|---|
| **trottoirs** | 2,0 m, **174 tronçons sur 178** | pris sur les mètres **libres** du tronçon : là où la donnée n'en laisse pas, il n'y en a pas |
| **bandes de fauche** | **7 champs, 198 bandes de 15 m** | un champ était un aplat de 3 ha, la plus grande surface unie de l'image. Le sens est tiré de la position |
| **teinte des champs** | 5 bases (blé, prairie, chaume, herbe grasse, terre travaillée) | une par champ, tirée de sa position |
| **arbres** | **1 107 feuillus, 170 conifères** | tronc + trois lobes décentrés, deux recettes et non deux fichiers |
| **arbres d'alignement** | **283 à t0** | exportés depuis toujours, plus affichés depuis la suppression de D07 — or ils lisent `routes.canopee`, une donnée de départ |
| **jardins pavillonnaires** | **174 parcelles bâties sur 174** vertes | l'ancien tirage qui en laissait 8 % en gris ne s'applique plus à ce tissu |
| **accès et haies** | **174 chemins (749,4 m)**, écart max **0,0000°** à la perpendiculaire · **820 tronçons de haie, 10,32 km** | la haie fait tout le tour sauf à l'ouverture ; une limite partagée n'est dessinée qu'une fois. **0 autre tissu touché** |

🔴 **Le tronc a dû sortir du feuillage** : la couleur d'instance du MultiMesh multiplie tout ce qu'elle touche, un `material_override` aurait peint le tronc en vert. Deux surfaces, deux matériaux.
🌊🛣️ **L'eau et la chaussée sont deux zones interdites au semis.** Les alignements suivaient les trois franchissements (**11 arbres dans l'eau**) et pouvaient retomber dans la chaussée d'une **autre** rue au carrefour, ou dans un axe arrondi. Le contrôle lit maintenant toutes les surfaces d'asphalte, rallonges comprises, avec **40 cm** de marge : **160 emplacements écartés (39 visibles à t0)**, et la chaîne s'arrête si un seul tronc retombe dans l'Ilse ou l'asphalte. Mesuré : **0 et 0**.

## 3 bis. La rue a un bord, et elle tourne

Demandé en deux phrases : *« séparation chaussée trottoirs, courbes au lieu d'angles (sauf aux croisements) »*.
🔴 **Ce que la version d'avant cachait** : le trottoir n'était pas un trottoir mais un quadrilatère **plus large que la chaussée, glissé dessous** à 3 cm — donc ni bordure, ni coin de rue, et un carrefour noyé sous le recouvrement des deux rubans. **Le trottoir appartient maintenant à l'îlot** : un anneau de 2 m le long de la limite de parcelle, **bordure de 14 cm**, qui **tourne les coins tout seul** — aucune ligne du code de voirie ne parle de carrefour, exactement comme aucune ne parle de pont. **17,78 km de bordure, 65 îlots, 338 coins.**
Côté courbes : **25 des 33 coudes marqués sont arrondis**, les **122 carrefours** gardent leur angle. 🔴 **Le rayon n'est pas un goût, c'est ce que le corridor accepte** : arrondir pousse le tracé vers l'intérieur, donc le trottoir extérieur gonfle et l'intérieur maigrit — quatre plafonds mesurés par coude, 6 à 20 m. **Les coudes très serrés restent des angles**, et c'est juste : dans une rue de 13 m, un virage à 90° est un angle du tissu.
⚠️ **Deux défauts trouvés en chemin** : la chaussée était **éclairée à l'envers** (3 060 normales sur 3 060 vers le bas, elle ne recevait que l'ambiant) et le trottoir avait **la couleur du sol nu** (2 % d'écart de valeur), donc invisible partout sauf contre l'asphalte.

## 3 ter. Le marquage — sept règles, aucun trait posé à la main

Demandé ainsi : *« procédural avec des règles, pas à la main »*. Les sept règles ne lisent que des choses déjà dans la donnée : la **largeur de chaussée** décide de la ligne d'axe (5,5 m, sinon une seule voie) · la **hiérarchie** décide des lignes de rive (boulevard et quai) · le **nombre de branches au nœud** décide où le marquage s'arrête et où se posent les traversées · la **courbure de l'axe** décide où la ligne devient pleine — on ne double pas dans un virage.
Mesuré : **260 passages piétons (2 171 bandes)**, **999 traits d'axe**, **23 portions pleines**, **110 lignes de rive**, **7 232 triangles** sur 56 698.
🔴 **La règle qui fait le tri toute seule** est celle du passage piéton : elle exige un trottoir des deux côtés, donc elle exclut d'un coup les **35 tronçons** trop étroits — les ruelles de 5 m *et les rues de 10 m*. Ce n'est pas une liste d'exceptions : si le centre manque de traversées, c'est **la largeur des rues** qu'il faut regarder.

## 3 quater. L'Ilse — elle descend de 2 m, la ville cesse de voler dessus

Demandé avec une coupe dessinée. 🔴 **Ce qui change n'est pas la profondeur mais qu'il y ait deux bords d'eau**, faits par la même règle : *le mur de quai monte jusqu'à la surface du sol, quelle qu'elle soit*. Là où la ville tient la rive, il fait **2,6 m** ; là où c'est un champ, le sol est au ras de l'eau et il n'en reste qu'une lèvre noyée.
Le relief tient dans **une seule fonction** que tout ce qui touche le sol interroge (plaque, champ, bandes de fauche, arbres, alignements, haut du mur) : elles partagent la même vérité au lieu d'en recopier une. Sa moitié difficile n'est pas la pente mais le **fondu** — le relief se relève à 0 dès qu'on approche d'un autre bord du champ, ce qui supprime trois cas particuliers d'un coup : la marche ville/champ devient une remontée sur 10 m, un pont qui traverse un champ garde sa terre à 0, et rien ne déborde de l'emprise. Mesuré : **4 champs riverains, 984 m de rive à 22 %** sur 2 475 m de berge, **2 019 mailles**, sol à **−2,15 m**, plaque à −2,85 m.
🔴 **Piège** : un point posé **sur** la ligne de berge n'est ni dedans ni dehors, il ressortait à 0 pendant que ses voisins descendaient — la berge se hérissait de **dents grises d'un mètre**. ⚠️ La pente douce avait été rejetée le 2026-08-12 (« se lisait comme un talus, donc comme rien ») : ce qui change, c'est que le creux double et que la pente **ne remplace plus le mur partout** — c'est le contraste qui les fait lire tous les deux.

Puis, le creusement fait, la suite : *« les routes au bord de la rivière volent sur l'eau… celles qui passent sur l'eau doivent être transformées en pont. »* **Mesuré avant de toucher à quoi que ce soit : 7 212 m² d'asphalte au-dessus du chenal, sur 42 tronçons.**
🔴 **Deux causes qu'il fallait séparer, parce qu'elles ne se réparent pas pareil** : ① la voie de berge **longe** — son bord dépasse la berge de 3,25 m (voie de rive) à 7,00 m (boulevard de quai), **6 400 m² sur 39 tronçons** ; ② trois tronçons (**145**, **168**, **169**) **traversent** vraiment, **800 m²**. Longer se répare par un mur porteur, traverser par un pont — et **aucune ligne ne nomme une rue**. 🔴 **Le pont est un ÉTAT de la route, pas un objet du jeu** : tablier et parapet partent dans le groupe du tronçon, donc cliquer un parapet ouvre la fiche de la rue.
🔴 **Le piège payé, et il était gros** : le boulevard de quai a son axe **posé sur la ligne d'eau**, donc la berge est à distance nulle **des deux côtés** et la mesure seule concluait « bord de l'eau » du côté des façades — un mur de 2,65 m debout au milieu de la ville. **Une distance ne dit pas de quel côté est la rivière.** La question qui manquait — *y a-t-il de l'eau 30 cm au-delà du bord trouvé ?* — a supprimé **la moitié du mur** : 2,98 km → 1,51 km, 9 338 triangles au lieu de 17 028.
🧱🌉 **Deux reprises le 2026-08-19, même faute des deux côtés : le mur suivait la ROUTE au lieu de l'EAU.** Le mur de quai, décalé de la chaussée, héritait de ses **évasements de carrefour** — **21 morceaux** en travers du débouché des rues perpendiculaires. Le parapet du pont, lui, courait sur toute la plage du tablier et finissait **7 m après la rive apparente**, en travers du carrefour. La règle ne mesure plus rien : *le parapet ne borde que l'eau libre*, ni la terre ni ce que le quai porte déjà — le tablier gardant ses culées, seul ce qui **dépasse du sol** s'arrête. **56 m de muret retirés**, **180 m gardés sur l'eau en 6 bouts** (un par joue, 6 attendus pour 3 ponts).
✅ **Les 7 208 m² sont portés à 100,0 %** — il reste 2 m² au-delà du parapet, à 17 cm. ⚠️ **Ce que ça révèle et qui n'est pas réparé** : l'asphalte déborde sur l'Ilse de **4,7 m en moyenne** sur tout le linéaire urbain, le quai prend donc **6 m** à la rivière. Ce n'est plus un défaut visible, c'est un **choix de carte** — une Ilse plus large veut dire reculer le **tracé** des voies de berge, pas toucher au mur.

## 3 quinquies. Les barres redescendent à la taille de Wehrau

Demandé devant l'image : *« les barres sont surdimensionnées pour une petite ville, moins larges, et mets-en 3 »*. **80 × 70 → 46 × 80** dans `04c`, et les deux nombres ne font pas la même chose :
🔴 **le PRODUIT décide le compte** — 11 158 m² d'emprise sur l'îlot 32, le seul îlot de barre de Wehrau, divisés par 3 680 m² donnent 3,03, donc **trois** parcelles là où 5 600 m² en donnaient deux.
🔴 **la PROFONDEUR décide le SENS de la découpe**, et c'est le piège : on ne débite en lanières que si le morceau est moins profond qu'une fois et demie la consigne. L'emprise mesure 136 × 114 m — **sous 76 m on repart en dos-à-dos et il sort une lanière de 136 m**, une barre de Großstadt, exactement ce qu'on retire. 80 m passe au-dessus des 114, donc les trois se rangent **en peigne**.
Mesuré : trois dalles de **46, 57 et 58 m** sur 12 m de fond, **6 niveaux**, **99 logements**, **2 003 m² d'emprise** contre 2 674 avant.
⚠️ **Un critère du vault dit toujours « 9 niveaux »** (`Plan 3 mois.md:48`, la touche `B`) : soit il se réécrit, soit la baisse s'annule. **Ça ne se tranche pas dans une note de chantier** — `Questions ouvertes.md` **et** `Décisions arrêtées.md`. L'argument de l'orthographie, lui, ne bouge pas : il porte sur le **rapport** des hauteurs, et 16,2 m contre 8,1 m se lisent encore.

## 3 sexies. La place du marché montre enfin ses 123 places

Demandé en une phrase : *« dessine des places de parc sur la place centrale. regarde comment faire de manière procédurale. »* L'îlot 19 est le seul îlot de **sol** qui porte du stationnement — `04` lui compte **127 places** depuis toujours, et ce nombre n'existait que dans la fiche : à l'écran, la place la plus centrale de la ville, **celle qui est le sujet du jeu**, était un aplat gris de 5 800 m².
**Cinq règles, et aucune ne nomme un îlot** : la **direction** est celle de la plus longue arête de l'emprise (donc la plus longue façade sur rue) · le **module** est une allée de 6 m et deux rangées de 5 m dos à dos, soit 16 m répétés · la trame **glisse en 80 positions** et on garde celle qui range le plus · une place tient si ses **quatre coins** sont dans l'emprise retirée de 3 m · et elle doit avoir **3 m d'allée devant elle**, sinon elle est enclavée.
🔴 **Mesuré : 123 places rangées contre 127 annoncées, écart −3 %** — et c'est le **seul contrôle du projet qui confronte deux chaînes**, la géométrie répondant à un nombre que `04` a calculé sans elle. 78 traits, **156 triangles**, 24,9 m² par place.
⚠️ Trois détails qui ne se voient qu'à l'écran : le **dos des deux rangées est un seul trait** (peint deux fois, il clignoterait sur toute la longueur) · la peinture est 1 cm au-dessus du **sol** et non de la chaussée (reprise telle quelle, elle passait 6 cm dessous, invisible) · les **2 arbres de la place tiennent le bord** par un rejet de plus dans le semis, sans quoi un sur deux poussait au milieu d'une place peinte.

## 4. La lumière a bougé avec la couleur

Trois réglages accordés à une ville dont les murs *étaient* la couleur, changés le même jour : **ambiant** `#8FA0AE` 0,85 → `#A2A29C` 0,74 (un ambiant bleu généreux repeignait toute façade non exposée, la ville avait l'air d'un jour de pluie) · **soleil** 1,15 → 1,45 — la somme ne bouge presque pas, ce qui change est le **partage** ciel/soleil, donc le contraste qui fait lire un enduit crème comme crème · **occlusion bakée** `AO_MIN` 0,62 → 0,74, parce qu'à 0,62 le bas de chaque façade tombait à 62 % de sa valeur et **la variation entre deux maisons voisines disparaissait**. Le SSAO garde le contact au sol.

## 5. Le calque `C`, le trait de sélection, les panneaux, les performances

🎨 **La touche `C`** est la contrepartie du rendu réaliste, et c'était la condition de l'auteur : elle repeint les 71 îlots avec la palette d'avant. Même uniforme que les calques thématiques, donc l'occlusion survit et deux repeints ne peuvent pas se superposer. ⚠️ Opacité **1,0** et non 0,88 : à 0,92 le rouge des tuiles transparaissait et le cœur ancien sortait orange. 🔴 C'est pour ça que la table `MASSES` de `palette.py` reste.

✏️ **Le trait autour de l'objet choisi.** L'éclaircissement ne suffisait plus sur des toits clairs. 🔴 **Le premier essai s'est trompé de géométrie** : un ruban posé **au sol** le long de l'anneau d'îlot — les bâtiments en sortaient, et dans le cœur ancien ils le cachaient (l'îlot 22 n'en montrait qu'un tiers). **Aucune ligne au sol ne peut entourer un volume.** Le trait est calculé **à l'écran** : l'objet est redessiné seul dans une vue à part, même caméra, et un shader allume les pixels vides à moins de **3 pixels** de la silhouette — donc il suit les pignons, les débords et les cheminées, et garde la **même épaisseur à tous les zooms**. 🔴 **Une rue fait exception** : un tronçon est fait de morceaux disjoints et ressortait en bandes parallèles ; `07` exporte donc son **couloir** (axe + largeur façade à façade, 14,6 m sur 174 tronçons), ruban plat jamais affiché qui n'existe que pour être détouré.

🌞 **Les panneaux suivent le bâtiment**, pan par pan : la grille mondiale a été remplacée par l'axe de faîtage déjà calculé pour chacun des 756 volumes. Le versant le mieux exposé se remplit de 0 à 50 %, puis l'autre ; un toit plat reste un seul pan. Surface solaire, économie et durée inchangées.

📈 **La maquette montre son propre coût** : panneau `F3` — ips, temps d'image, triangles, appels, nœuds, mémoire ; vert, orange sous **55 ips**, rouge sous **30**. Ville entière : **180 ips · 5,6 ms · 496 appels · 258 Mio · 73 359 triangles**. Il disparaît pendant `--essai`, donc les captures restent comparables.

## 6. Ce qu'il faut regarder

| Ce qu'il faut voir | Ce qui prouverait que c'est cassé |
|---|---|
| **La place-parking** (`wehrau_essai_place.png`, touche `M`) — une trame régulière, allées dans le sens de la plus longue façade, **aucune place enclavée**, les 2 arbres **au bord** | des places qui débordent de l'emprise · une double ligne au dos des rangées qui **clignote** quand la caméra bouge · un arbre planté au milieu d'une place |
| **Le quai et les ponts** (`wehrau_essai_ilse.png`) — le mur **ne longe que l'eau**, aucun bout en travers d'un débouché de rue, le parapet **s'arrête à la rive** | un mur debout côté façades · un muret qui traverse un carrefour · de l'asphalte qui surplombe le vide |
| **Façades** (`wehrau_essai_facades.png`) — fenêtres alignées d'un étage à l'autre, la rangée du haut s'arrêtant sous la gouttière | une rangée **coupée** par l'égout, ou qui déborde sur le toit |
| deux mitoyennes avec **deux rythmes de travées**, un **pignon plein** entre elles, **une** porte par maison au rez sur la rue | une trame unique qui traverse les angles · des fenêtres sur un mur mitoyen · deux portes sur un bâtiment d'angle |
| la barre de 1974 en **bandes horizontales** (`wehrau_essai_barre.png`) ; en dézoomant, les fenêtres **s'effacent** | un damier de petits carrés · un grésillement quand la caméra tourne |
| **Berge** (`wehrau_essai_berge.png`, touche `G`) — champ rayé, **bande verte qui descend**, puis l'eau ; le **trait d'eau tombe dans la pente** ; au raccord, le talus **remonte sur 10 m** | une bande verte **plate** posée comme un tapis · une lèvre de terre qui affleure sur tout le linéaire · une **marche de 2 m** en travers · un arbre en lévitation · des **dents grises** le long de la rive |
| **Rue** (`wehrau_essai_ilse.png`, `_dessus.png`) — bande claire continue qui **tourne les coins**, **marche** d'ombre entre trottoir et sol, rues **en courbe**, **carrefours nets en angle**, asphalte plus clair | une bande qui s'arrête à chaque carrefour · un trottoir à plat ou qui flotte · une courbe qui déborde · un carrefour arrondi en flaque |
| **L'échange** — `wehrau_essai_materiaux.png` (toits rouges sur murs clairs) contre `wehrau_essai_tissu.png` (touche `C`) | **si la seconde te manque tout le temps, la lecture par époque ne suffit pas et il faut rediscuter.** C'est le seul vrai risque de la passe |
| **De près** — aucun tronc dans l'Ilse, liseré sombre du débord, souches sur les faîtages, deux mitoyennes qui n'ont plus la même façade | — |
| **Le trait de sélection** (`_barre.png`, `_eglise.png`, `_caisse.png`) | un trait qui ne se referme pas, qui reste au sol pendant que les bâtiments en sortent, ou qui change d'épaisseur au zoom |

## 7. Ce qui se règle en une ligne, si l'image ne va pas

| Si tu trouves que… | La ligne |
|---|---|
| trop de toits sombres | `TOITURES["tuile"]` de `palette.py` — **pondérée par répétition** |
| les murs sont trop gris à l'ombre | `AMBIANT` de `palette.py`, et l'énergie du soleil dans `maquette.gd` |
| le débord / les cheminées / les trottoirs / la bordure | `DEBORD_TOIT` · `PART_CHEMINEES` · `LARGEUR_TROTTOIR` · `HAUTEUR_BORDURE`, dans `07_exporter_godot.py` |
| le trottoir est trop clair ou trop sombre | `TROTTOIR` de `palette.py` |
| les rues serpentent, ou pas assez | `RAYON_MAX`, `COUDE_MIN_DEG`, et `ELARGISSEMENT_MAX` qui décide combien de coudes s'arrondissent |
| les places de parc sont trop serrées, trop larges, ou trop peu | le module de `07_exporter_godot.py` — allée **6 m**, rangée **5 m**, retrait **3 m** du bord |
| les barres sont trop grosses, ou il y en a trop | `"barre_1970"` dans la table de `04c_parcelles.py` — le **produit** fait le compte, la **profondeur** fait le sens |
| le talus est trop raide, l'eau pas assez basse, la berge trop verte | `TALUS_LARGEUR` (10 m = 22 %) · `NAPPE_ILSE` et `TALUS_BAS` (le sol doit rester sous la nappe) · le mélange vers `SOLS["parc"]` |

## 8. Ce qui reste

- ⏸️ **Trois travaux laissés en chantier à la session 45** (limite de tokens) : à reprendre et vérifier **avant d'ouvrir un quatrième sujet**.
- 🔄 **Le stationnement DE RUE : 3 310 places, et aucune ne se voit.** La moitié « place-parking » est faite (§ 3 sexies, 123 places à −3 % du compte). Restent les tronçons. ⚠️ **L'ancien chiffre de 4 587 agrégeait les deux sens du champ `stationnement`** et ne correspond à aucune colonne : 3 310 sur les tronçons, 1 028 sur les îlots (dont 127 sur la seule place, les 901 autres sous des îlots bâtis, donc invisibles par construction). La forme à suivre est maintenant **prouvée et pas supposée** — une trame tirée de la géométrie retombe à 3 % du tableur.
- ✅ ~~**L'axe de certains quais passe au-dessus du chenal**~~ — **plus un défaut visible** depuis § 3 quater : les 7 208 m² sont portés à 100,0 %. ⚠️ Ce qui reste est un **choix de carte** : le quai prend 6 m à l'Ilse. Une rivière plus large veut dire **reculer le tracé** des voies de berge, pas toucher au mur.
- ☐ **159 empreintes concaves prennent un toit plat** (la recette du faîtage suppose un versant qui avance dans un seul sens) et **169 pans (2 %) sont réorientés à l'émission** — ⚠️ conséquence : la colonne « toits dehors » du contrôle est vraie **par construction** et ne prouve plus rien ; le chiffre qui informe est celui des réorientations. Un repli plus large (toit plat dès qu'un pan se plie trop) a été essayé le 2026-08-12 et **retiré devant l'image**.
- ☐ **Les fenêtres, ce qui en reste** : les **pignons sous toiture** ne sont pas percés (ils appartiennent au maillage du toit), ni **volets** ni **balcons**, et un mur mitoyen est aveugle sur toute sa hauteur y compris la part qui dépasse d'un voisin plus bas. Les trois se voient de près, aucun à la vue de jeu.
- ☐ **Le sol des cours** est la teinte de la plaque là où la cour n'est pas plantée : ça passe pour du pavé, mais c'est ce qu'on voit quand rien n'est dessiné.
- ☐ **8 coudes sur 33 restent des angles** faute de place, et **11 coudes arrondis sur 25 n'ont qu'un bord de trottoir** — pas rattrapable sans bouger les parcelles.
- ☐ **Le talus s'arrête aux champs** : la friche 31 et la barre 32 touchent l'eau et gardent un quai droit. Une berge naturelle au sud est **une ligne** — la règle lit le `sous_type` du riverain, pas une liste d'îlots.
- ☐ **Le fond du chenal ne se voit jamais** : l'eau est opaque, donc des deux mètres on n'en voit qu'un. Le fond à −2,60 m coûte 43 triangles et sert d'assurance, pas d'image.
- 🔄 **Le trafic n'a pas bougé depuis la session 9** — c'est l'étape 5.
- 🔴 **Le critère « 9 niveaux » du vault est périmé** depuis que la barre est descendue à 6 (§ 3 quinquies) : à réécrire ou à annuler, dans le vault et pas ici.
- 🔴 **La DA du vault dit encore « un `sous_type` = une teinte »**, et c'est faux. À fermer dans `Questions ouvertes.md` **et** `Décisions arrêtées.md`, pas au détour de cette note.

---

**Voir aussi** : [00 - Prototype.md](00%20-%20Prototype.md) · [Parcelles.md](Parcelles.md) · [ETAT.md](../ETAT.md) · `Godot/README.md`
