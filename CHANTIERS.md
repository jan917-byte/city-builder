# CHANTIERS.md — ce qui est connu, pas encore fait

> Sorti de [ETAT.md](ETAT.md) le 2026-08-12. `ETAT.md` dit **où on en est et quoi faire maintenant** ; ici on garde **tout ce qui attend**, avec sa raison d'attendre.
> Rien ici n'empêche de jouer ni d'avancer. Ce qui bloque vraiment est dans `ETAT.md`.
> Trois familles : les **défauts visibles** de la ville · la **dette** des formules et des seuils · le **matériel de level design** à regarder à l'œil.

---

## ⏸️ Point de reprise — limite de tokens du 2026-08-18

**Trois travaux sont encore en chantier au moment du commit de fin de
session.** Ce commit est un point de sauvegarde demandé par l'auteur, pas la
preuve que ces trois travaux sont terminés. La session s'arrête parce que la
limite de tokens a été atteinte ; les reprendre et les vérifier avant d'ouvrir
un quatrième sujet.

## 0. ✅ Les deux générateurs de bâtiment sont réunis — réglé le 2026-08-17

`07_exporter_godot.py` lit directement la couche `batiments` de `04d` et ne recalcule plus l'empreinte. Après la restructuration 71, Godot montre **756 volumes sur 751 parcelles bâties**, zéro débordement et **11,0 ha de toiture réelle pente comprise**. Les captures de référence ont été régénérées ; le potentiel solaire peut de nouveau être tranché sur ce chiffre unique. → `Prototype/Parcelles.md` §2 septies

## 1. Les défauts visibles de la ville

Ils ne sont pas cachés : `07_exporter_godot.py` les imprime à chaque export. Aucun n'empêche de jouer.

| | Le défaut | Ce qu'on voit |
|---|---|---|
| 1 | ✅ ~~**Des bâtiments mordent sur la rue**~~ | **réglé en lisant les empreintes de `04d`** — zéro hors parcelle ; les 38 dernières alertes venaient d'un anneau ouvert dans le contrôle de `07` |
| 2 | ☐ **159 empreintes concaves prennent un toit plat** | la recette du faîtage suppose qu'un versant avance dans un seul sens. ⚠️ Un repli plus large (toit plat dès qu'un pan se plie trop) a été essayé le 2026-08-12 et **retiré devant l'image** → `Godot/README.md` |
| 3 | ☐ **169 pans de toit (2 %) sont réorientés à l'émission** | ⚠️ conséquence : la colonne « toits dehors » du contrôle est vraie **par construction** et ne prouve plus rien. Le chiffre qui informe est celui des réorientations |
| 4 | ✅ ~~**La vallée ne se lit à aucune des quatre exagérations**~~ | **réglé en supprimant la vallée** le 2026-08-12 : la carte est plate, les touches `1..4` sont retirées |
| 5 | 🔄 **Le trafic** | inchangé depuis la session 9. **Le sol et la lumière, eux, ont bougé le 2026-08-18** : trottoirs, bandes de fauche, ambiant réchauffé → `Prototype/Toits et sol.md` §3 · §4 |
| 10 | ☐ **4 587 places de stationnement, et aucune ne se voit** | `routes.places` les compte depuis `04`. C'est **le sujet du jeu**, et c'est la plus grosse chose que le sol ne dit toujours pas. 🔄 Le **marquage** de la chaussée est fait depuis le 2026-08-18 (axe, rives, passages piétons) et donne la forme à suivre : des règles qui lisent la largeur, pas une liste de places. La place est **réservée dans l'image** — les mètres libres entre la bordure et l'asphalte → `Prototype/Toits et sol.md` § 3 ter |
| 7 | ✅ ~~**Des doigts de cour rentrent dans la masse bâtie**, et de petits ressauts en escalier~~ | **corrigé le 2026-08-17 (2)** — l'empreinte n'a plus droit qu'à **un** décrochement rentrant, et l'aile arrière est vérifiée adossée. 28 → **15** empreintes à deux décrochements, 2 → **0** en C, 52 encoches refermées → `Prototype/Parcelles.md` §2 nonies |
| 8 | 🔴 ☐ **La PARCELLE en dard, et c'est le peigne qui la fabrique** | **118 parcelles de rue sur 809 ont au moins un sommet rentrant**, les pires à 59–80° : la **435** de l'îlot 40 sort en flèche, la **443** en lanière (89 m² pour 2,0 m de façade au bout), la **438** porte deux replis. C'est ce que l'auteur a entouré le 2026-08-17 sur le bout sud-est de l'îlot 40 — *« des parcelles bizarres avec des formes de bâtiment pas réalistes »*. 🔴 **Ce n'est PAS la soudure des coins** : éteinte, le compte passe de 119 à 118. C'est `04c`, le peigne, là où deux bandes de rues différentes se rencontrent. **Le remède du bâtiment ne peut rien pour celui-là** — une empreinte propre dans une parcelle en dard laisse quand même le dard en beige à l'écran |
| 9 | ☐ **15 empreintes gardent deux décrochements** | leur poche dépasse `ENCOCHE_AIRE_MAX` (45 m²), donc on ne sait pas encore dire si c'est une encoche ou la cour que l'équerre entoure. Îlots 13, 28, 29, 30, 40, 43, 50, 58, 62, 66 |
| 11 | 🔴 ☐ **L'axe de certains quais passe au-dessus du chenal** | sorti tout seul le 2026-08-18 : la règle ⑦ du marquage refuse de peindre un passage piéton sur l'eau, et elle en a refusé **22** — bien plus que les trois franchissements n'en expliquent. Le reste vient des **quais**, dont l'axe mord le chenal par endroits. ⚠️ Ce n'est pas un défaut du marquage, c'est un défaut de **carte** que le marquage a rendu visible — et la chaussée du quai roule donc en partie au-dessus du vide. À regarder de près sur `wehrau_essai_ilse.png` avant de décider si c'est la berge ou le tracé qu'on bouge. 🔄 **Deux fois plus visible depuis le 2026-08-18** : la nappe est passée de −1,00 à −2,00 m, donc la chaussée qui mord le chenal surplombe maintenant 2 m de vide au lieu d'un. Le talus des champs, lui, ne peut pas masquer ce défaut — il ne touche que les rives de CHAMP, et celles-ci sont des rives de RUE |
| 6 | ☐ **Le fond du chenal ne se voit jamais** | l'eau est opaque, donc des deux mètres du chenal on n'en voit qu'**un** — le mur au-dessus de la nappe. Le fond à −2 m coûte 43 triangles et sert d'assurance, pas d'image |

## 2. Les quatre tables de level design

Ce sont **elles, et pas le code**, qui décident de ce qu'on voit. Une ligne changée, on relance, on regarde.
Le contrôle n'est pas « est-ce juste » mais ***« est-ce qu'on croirait y habiter »***.

| La table | Où | Ce qu'elle décide |
|---|---|---|
| les listes de `fid` | haut de `02_qualifier.py` | quel îlot est quoi — dont **`PONTS_SUPPRIMES`** désormais |
| `TISSU` | `04_deriver_attributs.py` | densité, hauteur, imperméabilisation, canopée, fragilité, parking — **le comportement de la carte** |
| `TISSU` | `04c_parcelles.py` | largeur de façade, profondeur, et **`style`** (`peigne` ou `boite`) — **le grain de toute la ville**. 🔄 Depuis le peigne du 2026-08-13, les deux premières colonnes disent enfin ce qu'elles disent : la boîte ne respectait que leur **produit** |
| `TISSU` | `04d_emprises_batiments.py` | recul, retraits, profondeur, plafond d'emprise et famille de forme — **l'empreinte du bâtiment** |
| `TOITURES` · `ENDUITS` | `palette.py` | 🆕 **les matériaux du bâti** — quelle couverture pour quelle époque, et quels enduits pour quel tissu. C'est elle qui décide de la couleur de la ville depuis le 2026-08-18 |
| `BATI` | `07_exporter_godot.py` | **la pente du toit seulement** ; ses anciennes colonnes de forme ne sont plus consommées |

🔴 Dans `04d.TISSU`, le retrait latéral à 0 fait le mitoyen, et il n'est **réversible que dans un sens** (décision 61).

## 3. La dette — formules, seuils, définitions

Aucune n'est sur le chemin critique du prototype énergie, mais chacune ment tant qu'elle n'est pas payée.

- [ ] 🔴 **Calibrer les deux formules de budget** — recettes ∝ `logements`, charges ∝ mètres de voirie (décision 59). Le contrôle est nommé : *une stratégie de densification pure ne doit pas s'autofinancer*, sinon le piège de l'exponentielle est rouvert pour de bon. C'est aussi ce qui doit faire **mordre** un budget qui ne mord jamais (418 pts sur 500, +152 de solde, aucune décision refusée sur trois parties).
- [ ] 🔴 **Repondérer les trois moyennes** — `canopee_moy` et `impermeabilise_moy` par la **surface**, `riverain_moy` par la **population** (ce qui supprime au passage le cas particulier « îlots habités seulement »). À faire dans `08_jouer.py` **et** dans `ville.gd`, puis refaire le contrôle de recoupement. Les chiffres du classeur bougeront. → `Décisions arrêtées` **63**
- [ ] 🔴 **`largeur_m >= 20`, la cible de D05, rate quatre des cinq rues les plus chargées.** Les tronçons 13, 21, 54 et 55 font **18 m** et portent 0,87 à 1,00 de charge. « Retirer la voiture de l'axe de transit » n'attrape que le tronçon 11. **Deux mètres de seuil décident si la décision existe.**
- [ ] 🔴 **La montée de D07 est de 60 mois** : sur l'horizon d'une partie, l'arbre ne reprend jamais ses mètres à la noue. La concurrence arbre/noue, qui est le sujet de D07 et D08, ne se joue pas.
- [ ] **`stationnement` porte deux sens** — part de surface sur l'îlot, places sur rue sur le tronçon — et « l'emprise voiture » agrège déjà les deux (4 587 places **et** 17,6 % de voirie). **À renommer avant d'écrire la formule de l'indicateur**, sinon quelque chose les additionnera.
- [ ] **Vérifier que chaque indicateur a un antagoniste.** Ceux qui n'en ont pas sont mal conçus — les bornes sont la ceinture, le frein ce sont les antagonismes.
- [ ] **Trois valeurs à t0 manquent** : la ville exposée, le CO2, la desserte. Calculables sur les attributs existants, côté Windows.
- [ ] **`confort_ete` n'existe pas dans le `.gpkg`** et c'est la seule variable de D10 (l'ancienne décision « énergie » du classeur — le thème a depuis ses deux vraies décisions dans Godot, panneaux et isolation, qui ne s'en servent pas). `08_jouer.py` la crée à 0 et le signale ; Godot y répondait par la **surchauffe**, dérivée du sol. Soit on la dérive dans `04`, soit D10 s'exprime autrement.
- [ ] **Trois chiffres attendent l'œil de l'auteur**, tous commentés dans le code et listés dans `Godot/README.md` : la **surchauffe** (`3,5 × imperméabilisé − 2,5 × canopée`, +1,59 °C à t0), le **+0,25 de canopée** de D07 (alors que la canopée d'une rue plafonne à 0,18 dans les données), et **`CANOPEE_ALIGNEMENT_MAX`** (rendu seulement). ⏸️ En sommeil : D07 est archivée (66).
- [ ] **La deuxième décision dans Godot.** La candidate est **D06 supprimer le stationnement** : c'est elle qui libère l'emprise de D07 et D08, donc c'est elle qui rend la chaîne intéressante. Il ne manque qu'une entrée dans `DECISIONS` de `chantiers.gd` et une portée `voisins` pour le report de charge.
- [ ] **La vue chantiers** (`Prototype/Énergie.md` §6 ter) — le calque de « ce qui est en train de se faire », la barre à deux segments (délai | travaux) au clic, la bascule automatique au premier chantier. ⏸️ **Sortie de la session énergie par l'auteur** (2026-08-12). Ce qui est déjà prêt pour elle : la durée des `travaux` est dans chaque décision et chaque entrée du journal (`fin_travaux` comprise), et l'étalement du budget court déjà sur délai + travaux. Il ne manque que l'affichage.
- [ ] **Les réparations de boucle de `04b`** — passées de 4 à **7 îlots** avec la carte à trois ponts. Les quatre signalées « à regarder » sont les mêmes qu'avant (**55, 13, 16, 21** — deux cœurs anciens, deux fronts commerçants ; le 16 tombe de 2 132 à 560 m²). Les trois neuves (9, 11, 62) ne sont pas signalées.

## 4. Le classeur — à retrancher ou à entretenir

⚠️ **Le rôle du classeur est à trancher.** Il n'a jamais été étendu à l'énergie, et le recoupement des deux moteurs est suspendu (`Prototype/Énergie.md` §9 c) depuis que D07 est archivée. Banc d'essai des seuils, ou archive ? **Un deuxième moteur à moitié entretenu ment sans qu'on le sache.**

🔴 Rappel de ce que la coupe a coûté : le **contrôle de recoupement** entre Godot et `08_jouer.py` a disparu avec D07. Il avait déjà attrapé un vrai bug (le décalage d'un mois du budget). Une formule fausse dans le noyau ne sera plus attrapée par personne avant qu'on la voie à l'écran.

## 5. Sans urgence

- [ ] **Digérer le brainstorm importé du 2026-08-11** (refs / positionnement / UI) — 9 décisions et 7 questions à remonter.
- [ ] **Le tag `jeu/brightvale`** du brainstorm importé — nom de travail abandonné, autre projet, ou candidat à verser dans `Marketing et Steam` ?
- [ ] **Les conséquences de 5 350 habitants** sur deux équipements : le lycée devient une Realschule et la barre de 1974 un petit Neubau. La galerie a disparu avec la décision 71. Acté dans la décision 13d, pas encore écrit dans `Ville/Wehrau.md`.
- [ ] **Les six dérives connues du dossier QGIS** → `QGIS/README.md` §8. Aucune bloquante.

---

**Voir aussi** : [ETAT.md](ETAT.md) · [HISTORIQUE.md](HISTORIQUE.md) · [Prototype/Énergie.md](Prototype/Énergie.md) · `QGIS/README.md` · `Godot/README.md`
