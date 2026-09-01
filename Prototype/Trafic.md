# Le trafic visible

> Étape 5 ouverte le 2026-08-21. Le trafic est un flux agrégé figuré par une poignée de véhicules : aucune voiture ne cherche son chemin.

## Le critère

> **Une rue à `charge = 1,00` est désagréable à regarder.**

Le critère se juge sans fiche et sans calque : sur l'axe chargé, les voitures sont nombreuses et lentes ; dans le cœur ancien, elles sont espacées et la rue reste habitable.

## Le chantier

1. **La ville roule** : un flux animé dérive de `charge`, les voitures garées dérivent de `stationnement`, le tout en instances multiples et sans asset.
2. **La charge garde une échelle stable** : une baisse globale doit pouvoir se voir au lieu de renormaliser une autre rue à 1.
3. **Une décision se voit** : supprimer du stationnement libère réellement la bordure ; retirer la voiture d'un axe reporte le flux agrégé.

## Les limites

- pas d'agent individuel, de feu, de file calculée ni de recherche d'itinéraire par voiture ;
- pas de choix modal ni de matrice origine-destination dans cette étape ;
- le thème `charge` ne sert qu'au diagnostic : s'il faut l'ouvrir pour comprendre l'image, le rendu a raté.

## Ce qu'il faut regarder

| Vue | Ce qui doit se voir | Ce qui prouve que c'est cassé |
|---|---|---|
| axe le plus chargé | voitures proches et lentes, rue hostile | flot dense mais rapide et agréable |
| rue calme du cœur | quelques voitures espacées, stationnement lisible | rue entièrement vide |
| ville entière | l'épine chargée ressort sans thème | toutes les rues paraissent identiques |

## Les deux vues — écrites le 2026-08-25, jugées par personne

Le calque de charge n'est plus une touche : c'est un **thème du diagnostic**, la deuxième des deux vues. La première est la ville vivante ; la seconde passe la ville en **maquette blanche** — plus de matière, plus d'arbres, plus de voitures — et n'y laisse en couleur que le thème choisi au menu : dangers, chantiers, énergie, trafic, tissu. Le temps continue, la caméra ne bouge plus d'elle-même, et la fiche répond au clic dans les deux.

Pourquoi ça compte pour cette étape : le critère se juge **sans thème**, sur la ville vivante. Tant que le diagnostic ressemblait à la ville, on ne savait pas si on jugeait le rendu ou le calque.

| À regarder, toutes au même cadrage | Ce qui doit s'y voir |
|---|---|
| `wehrau_essai_materiaux.png` | la ville vivante, le point de départ |
| `wehrau_essai_diag_trafic.png` | l'épine chargée en rouge sur une ville de carton |
| `wehrau_essai_diag_energie.png` | le dégradé d'amortissement ; gris = pas de toit équipable |
| `wehrau_essai_diag_dangers.png` · `..._diag_tissu.png` · `..._chantiers.png` | les trois thèmes déjà connus, sur le même carton |
| `wehrau_essai_retour_ville.png` | **exactement `essai_materiaux`** |

Ce qui prouverait que c'est cassé : une voiture ou un arbre sur une image de diagnostic · `essai_retour_ville` qui diffère de `essai_materiaux` · deux signaux sur le même objet · un carton si clair que les couleurs de thème s'y perdent — le seul réglage qu'aucun contrôle n'attrape, il tient à un nombre du shader.

✅ **L'interface papier est compilée et vue sur Mac** : bandeau d'indicateurs à pictogrammes, fiche locale à droite, thèmes en onglets à gauche. `--interface` sort les cadrages courts : la fiche d'une rue, le diagnostic, la fiche d'un îlot, celle d'une berge et **une fiche en chantier**, plus **la miniature seule** (`wehrau_apercu_rue/ilot/berge/berge_talus.png`) — à 296 px dans une capture d'écran, son cadrage ne se juge pas.
🧩 **Une rue et une berge sont montrées par un morceau droit fabriqué**, plus par un bout de la ville (2026-08-31) : la bonne largeur, le bon type, sur ~40 m de ligne droite, sous un angle fixe. La rue 55 sort en boulevard de 20 m — chaussée de 10,5 m, deux trottoirs de 2 m, axe discontinu, lignes de rive, bordure pleine à 47 places. La berge 6 sort en quai : l'Ilse, un mur avec son parapet, **10,2 m de quai minéral**, puis la voie de berge. Renaturer verdit la bande du bord (3,5 m) et laisse le reste du quai minéral. La berge 4, sans un mètre de mur, sort en talus d'herbe. **Ce qui prouverait que c'est cassé** : un trou entre deux bandes, une berge vue de dos (l'eau derrière le bloc), des voitures garées le long d'une rive, ou un quai qui ne recule pas d'un état à l'autre.
🔧 **La fiche porte une barre de chantier** sous la miniature — reconstruction, tablier, déblaiement, pose de panneaux, rive, retrait des places : celui qui finit le dernier. Elle n'apparaît qu'en travaux. À juger sur `wehrau_interface_chantier.png` (berge 6 au mois 3 sur 6 : barre à moitié, « encore 3,0 mois »).
🌊 **Route, berge, rivière sont trois bandes distinctes** (2026-08-31, demandé devant l'image). L'axe des rues de berge est tracé SUR la ligne d'eau : la chaussée, centrée dessus, posait **6 043 m² d'asphalte au-dessus de l'Ilse** d'un bord et laissait jusqu'à **15 m de sol nu** entre elle et le trottoir de l'autre — alors que `04b` recule déjà l'îlot riverain de la largeur ENTIÈRE du corridor. L'axe **dessiné** se décale donc vers les façades ; la source ne bouge pas. **20 tronçons sur 1 365 m**, décalés de 4,7 à 15,1 m ; il reste **1,4 m** de rive sur une voie `rive` de 10 m et **9,9 m** sur le boulevard de quai. L'asphalte au-dessus du chenal tombe à **13 m²**, dont 1 hors parapet ; les 19 rues qui débouchaient dans l'eau s'arrêtent à la rive ; plus aucun passage piéton n'est refusé au-dessus du fleuve (16 avant).
🅿️ **Les places de rue sont peintes** (le compte du jour est deux lignes plus bas). Elles se posent contre le trottoir, et **les mètres libres du corridor reçoivent l'asphalte** (0,2 m sur une rue de 13 m, 1,65 m sur un boulevard de 18) : c'est la bande de sol nu que rien n'expliquait. Elles vivent dans **leur maillage**, un nœud par tronçon, et **disparaissent quand la rue n'a plus de places** — sans quoi « retirer les places » n'aurait retiré que les voitures. `07` mesure l'écart à l'axe (`bord_places_m`) : c'est lui qui pose la file, et le morceau droit de la fiche le relit.
🚦 **Le carrefour est vidé de ce qui n'y a pas sa place** (2026-09-01, demandé devant l'image). Chaque tronçon ouvrait sa file de places au premier mètre de son axe : à un nœud à quatre branches, **huit files** se rejoignaient sur le même point et les voitures garées se croisaient en travers des passages piétons. Trois corrections, toutes à la source : ① la file ne se pose plus que dans ce que le marquage longitudinal laisse libre — zone d'échange et passages retirés —, avec **5 m de recul** de part et d'autre, la règle réelle ; ② `07` **exporte le milieu et la direction de chaque place** (`places_rue`) et `trafic.gd` y pose ses voitures au lieu de refaire le calcul : une voiture ne peut plus se garer là où aucune file n'est peinte ; ③ les passages piétons de toute la ville se confrontent avant d'être peints — **41 retirés** parce qu'ils en croisaient un autre, deux branches repartant sous un angle serré posant une croix de peinture au milieu du carrefour. Compté : **2 140 places peintes sur 3 339** annoncées par `04` (2 984 avant), **192 passages** (232 avant), **745 voitures garées** sur **98 rues marquées**. ⚠️ **Un tiers des places annoncées n'a plus où se peindre** — c'est la donnée de `04` qui ne tient pas compte des carrefours, pas le dessin. **Ce qui prouverait que c'est cassé** : une voiture garée sur un passage ou dans un carrefour · deux passages qui se recouvrent · une file qui commence au premier mètre d'un tronçon · une rue à `stationnement` non nul dont la bordure ne montre plus rien alors qu'elle a 40 m entre deux carrefours.
🚗 **Les voitures qui roulent traversent toujours les passages**, et c'est voulu : elles glissent en continu sur l'axe, aucune ne s'arrête. À `charge = 1,00` la file est à 4,8 m et bouche le carrefour — c'est ce que dit une rue saturée.
✏️ **Le trait de sélection touche maintenant l'objet**, sans les 2 px de vide qui servaient autrefois à réunir les morceaux d'une rue. Cette couture est devenue inutile depuis que chaque route a son couloir de masque. Ses deux bords sont raccordés en continu, sans dents dans les courbes ; une berge est projetée au sol dans le masque, donc son mur et son parapet ne produisent plus plusieurs contours.
🔴 **Ce que la berge rachète n'a plus de base mesurée.** `ville.berge_largeur_rendue_m` part du débord d'asphalte, qui vient de tomber à ~0 : **le quai apaisé ne rachète plus rien** (−0,53 m de crue avant, −0,00 m aujourd'hui) et la berge renaturée seule garde ses 3,5 m. Le nombre de remplacement est du **level design** : la fiche affiche maintenant `rive_m`, la rive minérale entre la chaussée et l'eau — 1,4 · 2,1 · 3,5 · 10,2 m selon la berge.
✅ **Compilé et vu le 2026-08-25** : le menu s'ouvre, les cinq thèmes se peignent, `essai_retour_ville` ne s'écarte de `essai_materiaux` que de 176 pixels sur 1,4 million.
🟠 **Le thème « tissu » peint aussi la campagne** : les champs, le parc et la rivière sont des îlots, donc ils prennent leur teinte de tissu et le carton disparaît sous eux. C'est le thème qui fait ça, pas la maquette blanche — reste à décider si « tissu urbain » a le droit de colorer ce qui n'est pas urbain.
🔴 **La décision « deux vues » n'existe pas dans le vault** : à ouvrir dans `Questions ouvertes.md` et fermer dans `Décisions arrêtées.md`.

## La fiche se règle avant de décider — 2026-08-31

🎚️ **On pose, on compare, puis on met en place.** Les cinq décisions étaient cinq boutons qui partaient au clic : rien à essayer, rien à reprendre, et chacun disait « il manque 214 k€ » de son côté. Ce sont maintenant des **réglages posés** sur l'objet choisi — panneaux, arbres, retirer les places, fermer aux voitures, reconstruire, quai apaisé, berge renaturée —, marqués d'une coche, et qu'un second clic retire. Un seul bouton en bas : **un prix, une durée, un refus**, et la commande part en **un seul chantier**, l'objet restant en travaux jusqu'à ce que le dernier corps de métier ait fini. La caisse n'est vérifiée qu'une fois, sur le total : réparer et poser des panneaux tenaient séparément et plus ensemble, et seul le total pouvait le dire.
🔎 **La miniature a deux boutons, AVANT et APRÈS.** Même cadrage, même objet : d'un côté ce qui est là, de l'autre ce qui sera livré. Ils n'apparaissent que si les deux images diffèrent — sans réglage posé ni chantier en cours, le geste ne voudrait rien dire. À juger sur `wehrau_apercu_rue_avant.png` → `wehrau_apercu_rue_apres.png` (rue 55, réglée à « places retirées + planté de bout en bout » : deux bordures garnies et 2 arbres → bordures vides et 4 arbres), et sur `wehrau_interface_reglages.png` pour la fiche entière.
🌳 **Planter est le sixième réglage, et il est sur la RUE.** Un îlot bâti porte **8,78 ha de canopée** qu'une maquette de masses ne peut pas dessiner — le pâté est plein, il n'y a pas de sol dessous : les 52 îlots bâtis n'ont pas un arbre à l'écran. La rue, si — `07` tenait déjà **821 emplacements en réserve**, chacun avec son seuil de canopée, et sait n'en révéler aucun dans l'Ilse ni sur la chaussée. **234 arbres en terre au mois 0**, sur **100 tronçons plantables** ; le curseur compte des arbres et pas des pourcents, parce que c'est l'arbre qu'on paie et l'arbre qu'on voit.
🔴 **Ce qu'un arbre épargne n'est pas tranché, et le nombre posé ne tient pas.** Tout planter — **587 arbres, 880 k€, trois ans de dotation** — épargne **147 MWh/an sur 43 571, soit 0,34 %** de la consommation de la ville. À ce compte planter est une décoration, pas une décision. Le seul levier est `PLANTATION_MWH_ARBRE_AN` (0,25 MWh/an par arbre, haut de `ville.gd`) et il faudrait le multiplier par dix, ce qu'aucune ombre portée sur des façades ne justifie. Ce que l'arbre fait réellement ici, le jeu ne le mesure pas : chaleur, eau, confort d'été — et `confort_ete` n'existe pas dans le `.gpkg`. **À trancher : un autre effet, ou l'assumer comme décor payant.**

**Ce qui prouverait que la fiche est cassée** : un réglage posé sur un objet qui survit au clic sur le suivant · le prix annoncé et la caisse qui ne tombent pas du même montant (contrôle imprimé par `--interface`) · deux chantiers sur le même objet · les boutons Avant/Après visibles alors que rien n'est posé · une miniature « avant » qui montre déjà le réglage.

## Les usagers doux — 2026-09-01

🚶🚲 **Les piétons et les cyclistes suivent l'INVERSE de la charge.** Même principe que les voitures — un flux agrégé, aucun agent, deux MultiMesh de plus, l'animation sur le GPU — mais leur nombre est ce que la rue laisse : `foule = fond de la hiérarchie × (1 − chasse × charge)`, et l'espacement s'interpole entre les deux bornes. C'est ce qui fait qu'une rue à `charge = 1,00` est désagréable **sans ouvrir de thème** : elle est vide de monde. Fermer un axe aux voitures ne fait donc pas que retirer les voitures — six mois plus tard la charge est retombée et le trottoir s'est rempli. Mesuré sur l'axe 55 : **10 piétons et 2 cyclistes à `charge = 1,00`, 42 et 14 une fois rendu**.

| | où il passe | le plus dense | le plus rare | ce que la charge lui prend |
|---|---|---|---|---|
| piéton | le milieu du trottoir (`bord_trottoir_m`, mesuré par `07`) | 6 m | 30 m | 80 % |
| cycliste | dehors des voitures, dedans des places | 18 m | 110 m | 90 % |

🔴 **Cinq nombres de level design**, à trancher devant l'image comme `PART_RENONCE` : les deux « chasses », et le fond de fréquentation par hiérarchie (`FOULE`, haut de `trafic.gd` — boulevard 1,00 · rue 0,85 · ruelle 0,70 · rive 0,55).

**Ce qui a été fait pour tenir la charge machine** : les créneaux sont semés **une fois** et leur transformée, leur teinte et leur donnée d'animation ne sont plus jamais réécrites — la pulsation n'écrit qu'une transformée, et **seulement celles qui basculent**. Les créneaux d'une rue sont **contigus** : la pulsation compare la foule de **174 rues** et n'ouvre le groupe que si elle a bougé d'un trente-deuxième. Trois étages de détail au lieu d'un — la voiture tient jusqu'à **700 m** de caméra, le cycliste **450**, le piéton **320** —, et une famille éteinte ne coûte ni dessin ni pulsation. Compté : **4 012 créneaux de piéton** (1 386 visibles au mois 0) et **1 218 de cycliste** (278), **deux appels de rendu de plus**, aucune ombre.

**À regarder** : `wehrau_essai_axe.png` → `wehrau_essai_axe_rendu.png` (même cadrage, l'axe 55 fermé six mois plus tôt) et `wehrau_essai_rue_calme.png`.
**Ce qui prouverait que c'est cassé** : un piéton sur une rue noyée ou un pont emporté · un piéton sur la chaussée d'une rue à trottoir · un cycliste sur le trottoir · une rue fermée aux voitures qui se vide aussi de son monde · des marcheurs groupés à un bout d'une rue calme · une famille absente de la première image après un zoom.
🟠 **Deux limites assumées** : les créneaux traversent le carrefour, donc un marcheur coupe le nœud en diagonale au lieu de suivre un passage — un piéton qui bouge n'est pas une voiture garée en travers ; et une rue rendue aux piétons garde son monde **sur les trottoirs**, la chaussée reste vide.
🟠 **Ce qu'aucun d'eux ne change encore** : ni la consommation, ni le CO₂, ni un indicateur. Ils disent la rue, ils ne la comptent pas — la question du levier est la même que celle de l'arbre, deux paragraphes plus haut.

## Les voitures font le tour — 2026-09-01

🔄 **Une voiture ne revient plus en arrière au bout de son segment : elle passe au suivant.** Avant, chacune bouclait sur son morceau droit — **médiane 19,9 m, 43 % en font moins de 10** —, donc un retour en arrière toutes les 2,4 s sous les yeux. Maintenant elle tourne le coin, traverse le carrefour et continue. **864 arcs orientés**, chacun désignant un seul suivant : la continuation la plus droite.

🔴 **La table est une PERMUTATION, et c'est elle qui tient tout.** À chaque nœud, les arcs qui entrent sont appariés **un à un** à ceux qui sortent (appariement exact, degrés 1 à 5). Donc les circuits sont fermés et couvrent tout le réseau, et **une rue ne peut pas se vider au profit d'une autre**. « Le plus droit devant » seul ne suffisait pas : deux entrées choisissaient la même sortie, et tout le trafic finissait par se ramasser dans quelques boucles. Résultat : **31 circuits**, du plus long — 12 km, 112 tronçons — aux **65 impasses**, où le demi-tour est le seul mouvement possible. Simulé sur 10 minutes : les tronçons s'écartent de **±3 voitures** de leur compte de départ, deux se retrouvent momentanément vides sur 173.

✅ **La décision 62 tient** : la table est calculée **une fois au chargement**, aucune voiture ne cherche son chemin, il n'y a ni file d'attente ni nœud par véhicule. Le seul cas où une voiture choisit est le clic qui ferme une rue — elle prend alors la sortie ouverte la plus droite, et la rue fermée se vide au coin au lieu d'avaler les voitures.

**La densité reste une propriété de la rue.** Ce n'est plus le rang de semis d'une voiture qui décide si on la voit, c'est un **quota par tronçon** tenu à la pulsation : même compte qu'avant — **329 visibles sur 963** —, mais celles qui ne tiennent pas dedans s'effacent **au carrefour** au lieu du milieu de la rue.

**Ce que ça coûte** : le shader anime toujours seul, à la fréquence de l'écran ; le CPU ne touche que les deux ou trois voitures qui changent d'arc dans l'image — **29 µs par image** sur les 7 500 du script, mesuré au banc. Une horloge (`temps_trafic`) est partagée avec le GPU, sans quoi le CPU ne saurait pas où le shader a posé la voiture.

🟠 **Ce qui reste à juger, et c'est neuf** : au coin, la voiture **pivote d'un coup** — pas d'arc de braquage. À voir sur `wehrau_essai_axe.png` puis `wehrau_essai_axe_2s.png`, **même cadrage, deux secondes plus tard, rien d'autre n'a bougé**.

## Ce que ça coûte à la machine — 2026-09-01

📊 **Il y a maintenant un banc**, `Godot --path Godot -- --banc` : quatre cadrages mesurés verrou d'écran levé, puis la pulsation du trafic part par part et le prix d'une image part par part. Il quitte tout seul. Sans lui, « ça rame » ne désignait rien.

| ce qui coûte | avant | après |
|---|---|---|
| **une affectation** — fermer une rue, rouvrir un pont | **147 ms** | **17 ms** |
| une pulsation (4×/s) : les voitures garées | 2,0 ms | 0,6 ms |
| une image, tout le script de la maquette | 10,1 ms | **5,6 ms** |
| l'image à l'écran (M1 Max, 1600 × 900) | 9,0 ms | 9,2 ms |

🔴 **L'affectation était la seule saccade du jeu** : à chaque réouverture de rue, un quart de seconde perdu. Trois causes, toutes payées. ① Dijkstra balayait sa file d'attente **en entier** à chaque extraction — c'est un **tas binaire**. ② Le réseau comptait ses nœuds au sommet de polyligne : un sommet dont les deux bouts portent le même tronçon ne décide de rien, et **414 nœuds / 432 arêtes deviennent 159 / 177**. ⚠️ On ne contracte que si le `fid` est le même des deux côtés, sinon fermer un tronçon ne creuse plus le cul-de-sac que l'affectation traite comme une porte. ③ Une **porte est aussi un carrefour**, donc 65 des 221 Dijkstra étaient refaits à l'identique ; et le flux **remonte l'arbre** au lieu de relire chaque trajet depuis sa cible.
✅ **Les charges n'ont pas bougé d'un centième** : `--essai` réimprime *axe 55 à 1,00 · 10 piétons et 2 cyclistes · 42 et 14 rendu · 27 rues voisines plus chargées · 34,9 → 33,5*.
🌿 **La moitié du budget d'une image partait dans la crue** : `degats()` redemandait les hectares de toit vert de la ville **une fois par îlot**, soit 71 × 71 passages — 5,2 ms, retombés à 1,1. La somme est mémorisée sur le mois exact, et toute décision qui verdit l'efface.
🔄 **Retour en arrière signalé** : le bandeau a été rafraîchi 10 fois par seconde au lieu de 60. Ça ne gagnait **rien** — l'image est tenue par la carte graphique, pas par le script — et le contrôle du clic de `--essai` tombait à côté de la berge 6. Retiré. Le lien n'est pas compris : ne pas le refaire sans l'avoir trouvé.
🟠 **Ce qui reste, et c'est du rendu, donc de l'image** : la ville dessine **884 000 triangles pour 70 000** de géométrie, en **849 appels**. Les 1 125 arbres et les ombres portées expliquent l'écart. Le baisser change ce qu'on voit — c'est un arbitrage de l'auteur, pas une optimisation.

## Ce qui reste

- **À regarder par l'auteur** : `wehrau_essai_axe.png` puis `wehrau_essai_axe_2s.png` (le tour), puis `wehrau_essai_axe_ferme.png`, `wehrau_essai_rue_calme.png` puis `wehrau_essai_stationnement_retire.png`, et `wehrau_essai_report_trafic.png`.
- La vue rapprochée porte **329 voitures roulantes visibles sur 963 en circuit** et **1 008 voitures garées symboliques sur 3 310 places** : deux MultiMesh, deux appels de rendu, aucune ombre.
- Le trafic visible s'anime sur le **GPU à la fréquence de l'écran (60 Hz visés)**. Le CPU ne déplace aucune voiture : il n'engage que celles qui changent d'arc, et une pulsation plafonnée à 4 Hz ne relit `charge` que lorsqu'elle a changé, une fois par rue.
- Au-delà d'une taille de caméra de 700 m, les véhicules sont sous le pixel : les deux MultiMesh sont masqués et la pulsation sort immédiatement.
- Une charge à 1 tasse la file à 4,8 m et ralentit à environ 4 km/h ; la rue calme espace le flux jusqu'à 48 m.
- Les **37 routes endommagées**, dont les trois ponts emportés, ne portent aucune voiture avant la fin de leur réparation ; chaque réouverture rejoue l'affectation.
- Supprimer le stationnement vide sa bordure en deux mois et le bouton montre le chantier. Retirer la voiture vide l'axe dès le clic, puis reporte le flux en six mois ; l'essai fait tomber le tronçon 55 de 1,00 à 0,00.
- 🚗 **Le report n'est plus intégral : une part renonce à la voiture** (2026-09-01, demandé). Un trajet dont le chemin s'allonge perd d'abord **25 % — la part fixe qui ne reprend pas la voiture** —, puis une part qui grandit avec le détour (un détour de +50 % de temps garde 75 % du reste). Un trajet que la fermeture n'allonge pas ne perd rien. Mesuré sur la fermeture du tronçon 55 : **27 rues voisines plus chargées** et le total de charge de la ville qui tombe de **34,9 à 33,5, soit −3,9 %** ; sans la part fixe, la ville ne perdait que **0,7 %** et la fermeture ne se voyait que comme un déplacement. La référence du détour est le réseau **entier ouvert**, ponts compris, mesurée une fois au chargement (+0,2 s).
- 🔴 **Les deux nombres du renoncement sont du level design** (`PART_RENONCE` 0,25 et `ELASTICITE_RENONCE` 0,7, haut de `trafic.gd`) : à trancher devant l'image, pas dans le code.
- **La rue du critère est bien le tronçon 55, et il est à 1,00.** `04e` l'exporte à 0,88, mais la maquette rejoue l'affectation au chargement avec les 37 rues coupées et le report l'y remonte. Le contrôle imprimait la valeur de la source et non celle de l'écran ; il imprime la charge vue depuis le 2026-08-25. → [Crue](Crue.md) § 6
- **Le cadrage de la rue calme est passé de 70 m à 45 m** : à 70 m la bordure vidée pesait 0,4 % de l'image et l'avant/après du stationnement ne se voyait pas. À 45 m il en pèse 8,8 %.
- 🔴 **L'essai n'était pas reproductible** : il figeait la vitesse mais pas l'horloge, qui tourne pendant le chargement — deux passes de la même version imprimaient 417 puis 508 logements perdus « au mois 0 ». `mois` est remis à zéro à l'entrée, et 508 est bien la somme portée par la source.
- Le critère reste ouvert jusqu'au regard de l'auteur : l'essai automatique prouve le mécanisme, pas que l'image est juste.
