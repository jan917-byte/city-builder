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
🅿️ **Les 3 310 places de rue sont peintes** — **2 984 files marquées**, le reste tombant hors des morceaux d'axe. Elles se posent contre le trottoir, et **les mètres libres du corridor reçoivent l'asphalte** (0,2 m sur une rue de 13 m, 1,65 m sur un boulevard de 18) : c'est la bande de sol nu que rien n'expliquait. Elles vivent dans **leur maillage**, un nœud par tronçon, et **disparaissent quand la rue n'a plus de places** — sans quoi « retirer les places » n'aurait retiré que les voitures. `07` mesure l'écart à l'axe (`bord_places_m`), `trafic.gd` le lit : les voitures tombent dans les cases.
🔴 **Ce que la berge rachète n'a plus de base mesurée.** `ville.berge_largeur_rendue_m` part du débord d'asphalte, qui vient de tomber à ~0 : **le quai apaisé ne rachète plus rien** (−0,53 m de crue avant, −0,00 m aujourd'hui) et la berge renaturée seule garde ses 3,5 m. Le nombre de remplacement est du **level design** : la fiche affiche maintenant `rive_m`, la rive minérale entre la chaussée et l'eau — 1,4 · 2,1 · 3,5 · 10,2 m selon la berge.
🔴 **La décision « deux vues » n'existe pas dans le vault** : à ouvrir dans `Questions ouvertes.md` et fermer dans `Décisions arrêtées.md`.

## Ce qui reste

- **À regarder par l'auteur** : `wehrau_essai_axe.png` puis `wehrau_essai_axe_ferme.png`, `wehrau_essai_rue_calme.png` puis `wehrau_essai_stationnement_retire.png`, et `wehrau_essai_report_trafic.png`.
- La vue rapprochée porte **329 voitures roulantes visibles sur 963 positions** et **1 008 voitures garées symboliques sur 3 310 places** : deux MultiMesh, deux appels de rendu, aucune ombre.
- Le trafic visible s'anime sur le **GPU à la fréquence de l'écran (60 Hz visés)**. Le CPU ne déplace aucune voiture : une pulsation plafonnée à 4 Hz ne relit `charge` que lorsqu'elle a changé, une fois par rue.
- Au-delà d'une taille de caméra de 700 m, les véhicules sont sous le pixel : les deux MultiMesh sont masqués et la pulsation sort immédiatement.
- Une charge à 1 tasse la file à 4,8 m et ralentit à environ 4 km/h ; la rue calme espace le flux jusqu'à 48 m.
- Les **37 routes endommagées**, dont les trois ponts emportés, ne portent aucune voiture avant la fin de leur réparation ; chaque réouverture rejoue l'affectation.
- Supprimer le stationnement vide sa bordure en deux mois et le bouton montre le chantier. Retirer la voiture vide l'axe dès le clic, puis reporte le flux en six mois ; l'essai fait tomber le tronçon 55 de 0,88 à 0,00.
- Depuis la fusion du 2026-08-24, la maquette lit la charge **d'après-crue** que `04e` réécrit : le tronçon 55 part de 0,88 et non de 1,00, et la rue à 1,00 du critère est le tronçon **5**. → [Crue](Crue.md) § 6
- Le critère reste ouvert jusqu'au regard de l'auteur : l'essai automatique prouve le mécanisme, pas que l'image est juste.
