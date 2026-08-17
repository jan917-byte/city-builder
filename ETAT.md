# ETAT.md — où on en est

> Mis à jour par Claude en fin de session. Complément de [CLAUDE.md](CLAUDE.md).
> **Ce fichier est un signet, pas une source.** Design = le vault. Carte = `QGIS/data/source/*.geojson`.

| Si tu cherches | Va voir |
|---|---|
| **le prototype, ses étapes, celle qui est ouverte** | [Prototype/00 - Prototype.md](Prototype/00%20-%20Prototype.md) |
| ce qui attend, les défauts connus, les tables à régler | [CHANTIERS.md](CHANTIERS.md) |
| ce qui s'est passé, et pourquoi c'est comme ça | [HISTORIQUE.md](HISTORIQUE.md) |
| ce qui est tranché | `Méta/Décisions arrêtées.md` (vault) |

**Dernière mise à jour : 2026-08-17 (session 30)**

🆕 **Le prototype énergie tient maintenant en une décision.** À gauche, quatre
conséquences pour toute la ville ; à droite, seulement l'îlot cliqué. Le
curseur augmente sa part solaire de sa valeur actuelle jusqu'à 100 %, sans
budget, capital, isolation, temps ou calque. Contrôle réel sur l'îlot 32 :
**0 → 100 %**, production de ville **0,0 → 0,3 GWh/an**, achat **51,1 → 50,9**,
CO₂ **12,8 → 12,7 kt/an** ; les toits passent visiblement à l'ardoise sombre.
→ [Prototype/Énergie.md](Prototype/Énergie.md) · `Décisions arrêtées` **68**

🆕 **Godot montre enfin les nouveaux bâtiments.** `07_exporter_godot.py` lit directement la couche `batiments` de `04d` au lieu de recalculer sa propre ville. Résultat vérifié dans les captures : **701 volumes sur 693 parcelles bâties**, cours et jardins visibles sous les volumes, **zéro bâtiment hors parcelle**, **10,4 ha de toiture réelle pente comprise**. Les captures `wehrau_essai_ville.png` et `wehrau_essai_barre.png` ont été régénérées. → [Prototype/Parcelles.md](Prototype/Parcelles.md) §2 septies

🆕 **Le bâtiment n'a plus droit qu'à UNE équerre.** L'auteur a regardé les îlots 40 et 41 : *« l'îlot 40 a encore des parcelles bizarres avec des formes de bâtiment pas réalistes, et l'îlot 41 a des coins encore à corriger »*. C'était la suite annoncée la veille — les doigts de cour et les ressauts en escalier. Le critère n'est pas une largeur mais **le nombre de décrochements rentrants** : mesuré sur les 701 empreintes, 542 n'en ont aucun, **131 en ont un** (l'équerre : immeuble d'angle, maison + aile arrière — les deux voulues), 28 en ont deux ou trois, et **aucune de ces 28 n'a d'excuse**. Deux règles : ① **l'aile arrière est enfin vérifiée adossée** — sa docstring le promettait depuis le premier jour sans que rien ne le contrôle, et sur une parcelle d'angle elle s'adossait à son propre bâtiment, au milieu de la cour ; ② **l'encoche se referme**, après l'aile et pas avant, la plus petite poche d'abord. **28 → 15** empreintes à deux décrochements, **2 → 0** en C, **52 encoches refermées**. R0 (0), R2 bis (16), emprises, cour du cœur ancien et partition inchangés ; toit 9,00 → **9,02 ha**. → [Prototype/Parcelles.md](Prototype/Parcelles.md) §2 nonies

🔴 **Et l'îlot 40 n'est réparé qu'à moitié : ce qu'il reste est dans la PARCELLE.** Le bout sud-est que l'auteur a entouré garde une parcelle en flèche (435), une lanière (443) et deux replis (438). **118 parcelles de rue sur 809 ont un sommet rentrant**, et le compte ne bouge pas quand on éteint la soudure des coins (119 → 118) : **c'est le peigne de `04c`, pas la soudure**. Une empreinte propre dans une parcelle en dard laisse quand même le dard en beige à l'écran. → [CHANTIERS.md](CHANTIERS.md) §1 n°8

🆕 **Le coin d'îlot tourne enfin.** L'auteur a dessiné trois fois l'emprise voulue par-dessus l'image (îlots 40, 41, 59) : *« c'est surtout les coins d'îlots que je trouve encore problématiques »*. Deux causes, une par script. ① **`04c`** — la rue la plus longue prend le coin, donc la parcelle d'angle n'avait qu'un **flanc** sur l'autre rue : façade faible **7,4 m** en médiane. La parcelle du coin absorbe maintenant sa voisine du côté faible (**118 soudures sur 36 îlots**) → façade faible **12,6 m**, et **122 coins sur 163** ont leurs deux bras, contre 48. ② **`04d`** — la réunion des deux bandes laissait une cour **au milieu** de la masse, d'où le bâtiment en C ; une tranche enfermée par le bâtiment y repart désormais (**152 poches comblées**) → **7 → 2** bâtiments à trois coins rentrants. Emprises, cour du cœur ancien, R0 et partition inchangés. **927 → 809 parcelles**, toit 8,86 → **9,00 ha**. → [Prototype/Parcelles.md](Prototype/Parcelles.md) §2 octies

🆕 **Le bâtiment n'est plus la parcelle.** L'auteur a relu `parcelles_ilot_14.png` : *« les bâtiments ressemblent trop aux parcelles »*. La cause était la table de `04d`, où le cœur ancien et les maisons de ville n'avaient **aucune règle de profondeur** — l'empreinte *était* la parcelle, à **0,96** près. Maintenant le bâtiment est une **bande mesurée depuis chaque limite sur rue**, et le reste est cour ou jardin. **Cour en cœur ancien : 4 % → 24 %** · emprises 0,96 → **0,76** (cœur ancien), 0,65 → **0,56** (maisons de ville) · façades reculées 22 → **19** · **0 bâtiment hors de sa parcelle** · **81 ailes arrière**, **18 pointes rendues au jardin**, **37 parcelles traversantes qui portent deux bâtiments**. La surface de toit passe de 10,12 à **8,86 ha**. → [Prototype/Parcelles.md](Prototype/Parcelles.md) §2 septies

🆕 **`04d` est dans la chaîne et alimente maintenant Godot.** La chaîne est **02 → 03 → 04 → 04b → 04c → 04d → 07** avec `--godot` ; l'aperçu 2D et la maquette 3D lisent la même empreinte. → [CHANTIERS.md](CHANTIERS.md) §0

🆕 **Les venelles sont réintégrées dans la chaîne procédurale.** Après la passe à blanc, les six tracés récupérés ont été écrits dans `QGIS/data/source/chemins.geojson`, puis la chaîne complète a tourné jusqu'à Godot. Résultat : **6 venelles sur les îlots 22, 24, 26, 38, 44 et 63 · 588 m² pavés · 927 parcelles dont 912 sur rue · zéro reliquat enclavé · partition 100,00 % · 892 volumes bâtis · 12,1 ha de toit réel**. Le septième tracé annoncé autrefois sur l'îlot 40 n'avait jamais été enregistré et ne passe plus le seuil de rectangularité. → [Prototype/Parcelles.md](Prototype/Parcelles.md) §4 · §4 bis

🆕 **QGIS est sorti du projet, et la carte est devenue du texte.** L'auteur ayant acté qu'il n'ouvrirait plus QGIS, plus rien n'obligeait la source à être un GeoPackage. Elle est maintenant **`QGIS/data/source/*.geojson`** — 66 ko de texte, une entité par ligne, que **git fusionne**. Tout `.gpkg` est un dérivé, gitignoré, refait par **`python QGIS/scripts/chaine.py`** en **0,7 s**. Ce que ça supprime : la règle « la carte ne s'écrit que sous Windows », les six commandes à lancer dans l'ordre, et le risque qu'une carte du dépôt soit plus vieille que le code. → [QGIS/data/LISEZ-MOI.md](QGIS/data/LISEZ-MOI.md) · `CLAUDE.md` §5

🆕 **Les deux derniers défauts désignés sur l'image sont corrigés** — *« c'est bien mieux »*. ① **La direction des parcelles** (îlots 63 et 26) : le petit côté d'un îlot allongé réclamait 58 m de fond pour 28 visés, et le bout de l'îlot sortait en dalles couchées en travers du tissu. Le plafond de profondeur vaut maintenant **même en pavillonnaire** (`PROF_MAX = 1,3`). ② **Deux triangles qui font un rectangle** (îlot 13) : la coupe en diagonale s'efface, **2 fois en ville**, là où l'ancien seuil de pointe coûtait 14 % des maisons. **893 → 912 parcelles sur rue**, zéro enclavée, partition toujours à 100,00 %. → [Prototype/Parcelles.md](Prototype/Parcelles.md) §2 quinquies · §2 sexies

🆕 **Le chemin dans l'îlot** — quand le peigne bute sur un îlot en L, on ne coupe plus l'îlot : on y dessine une **venelle de 3 à 5 m**, retirée de l'emprise avant la découpe. 70 îlots restent 70, et le coude a enfin un devant et un derrière. **6 chemins sur Wehrau, 588 m².** → [Prototype/Parcelles.md](Prototype/Parcelles.md) §4 bis · `Décisions arrêtées` **67 · 67b · 67c**

🆕 **Le prototype a sa catégorie, à côté du vault** : [`Prototype/`](Prototype/00%20-%20Prototype.md) — une note par étape, **une seule ouverte à la fois**. L'étape en cours est [**les parcelles**](Prototype/Parcelles.md). Le vault garde toutes les idées et reste la source de vérité du design ; `Prototype/` porte le chantier. → `CLAUDE.md` §2

---

## Ce qui existe aujourd'hui

| | Où |
|---|---|
| **La carte simulable** — 0,93 km², **70 îlots, 177 tronçons** (ouest redécoupé par l'auteur le 2026-08-13), 13 sous-types, 17 exceptions, **3 franchissements** | source : `QGIS/data/source/` · travail : `QGIS/data/travail/wehrau.gpkg` |
| **La ville bâtie** — **809 parcelles dont 794 sur rue**, aucune sous 45 m², **zéro reliquat de rue enclavé**, partition à 100,00 %, 15 cœurs d'îlot et **6 venelles** | source : `chemins.geojson` · dérivés : `emprises`, `parcelles` |
| **Les bâtiments** — **701 empreintes sur 693 parcelles**, une bande depuis la rue, une cour derrière, **un immeuble d'angle qui tourne la rue** et **au plus une équerre par empreinte**, **9,02 ha d'emprise de toit / 10,4 ha de toiture pente comprise**, zéro hors parcelle. **Godot lit cette couche directement** | dérivé : couche `batiments` de `04d` · `Godot/data/wehrau.json` |
| **La maquette 3D cliquable** — 237 nœuds, fiche à l'îlot et au tronçon, **carte plate**, l'Ilse canalisée et ses trois ponts | `Godot/` → `Godot/README.md` |
| **Le classeur** — 3 parties jouées sur 60 mois, courbes et carte au mois M | `Classeur/` · `QGIS/rendus/parties.html` |
| **Le système énergie** — une décision à l'îlot, part solaire 0–100 %, ville à gauche et îlot cliqué à droite, sans ressources | ✅ **simplifié et capturé, à regarder** → [Prototype/Énergie.md](Prototype/Énergie.md) |
| D07, la surchauffe, les quatre moyennes de ville, les six calques | ✂️ **supprimés** (66), archivés dans `Godot/archive/` |

**Les trois contrôles qui comptent, au vert** : la ville privée de sa rivière tombe en **deux morceaux (45 et 11 îlots)** · le réseau routier est **d'un seul tenant** · l'**axe de transit sort tout seul** de l'affectation de trafic.

## Ce qui commande le reste

- 🎯 **Le prototype énergie teste d'abord le lien local → global** (68) : une
  seule décision, aucun coût. La paire de décisions opposées et les ressources
  restent une ambition du jeu complet, pas le test actuel.
- 🔗 **La 3D et l'énergie se rejoignent sur le toit** (41 · 56 · 64) : la 3D produit `toit_m2`, `toit_pente`, `toit_plat` et l'ombrage ; l'énergie les lit sans savoir qui parle. **L'énergie n'attend jamais la 3D.**
- 🔓 **Claude écrit ET exécute les scripts de données** (65). Les garde-fous ont maigri le 2026-08-17 avec le passage en texte : arbre git propre avant d'écrire **la source** · passe `--blanc` d'abord **pour les trois scripts qui la touchent** (`00`, `00b`, `tracer_chemins` — c'est du level design) · contrôles imprimés en français, qui eux ne bougent pas. Écrire un `.gpkg` ne demande plus rien : il est dérivé. → `CLAUDE.md` §3
- 🏘️ **Le prototype est Wehrau**, une petite ville qu'on voit en entier (13b · 13d). Vallmar reste la ville du jeu complet, intacte dans le vault. Une ville entière, même petite, a **un amont et un aval** ; un quartier n'en a pas.
- 🎨 **Townscaper pour le rendu** (42b), et **Wehrau est pastel au sol minéral** (42c) : la grisaille est une **proportion** — 28 % d'imperméabilisé, 14 % de canopée, 4 587 places — pas une teinte.
- 🗺️ **La carte est plate** (2026-08-12) — dans l'image ET dans la donnée. Le seul relief est le **chenal de l'Ilse** : murs verticaux, fond à −2 m, plan d'eau à −1 m. Ce que ça a supprimé : le champ d'altitude, la vallée, l'exagération verticale, la subdivision des sols et des chaussées. **La voirie reste à 0** : au-dessus du chenal elle passe au-dessus du vide, donc les trois ponts existent sans qu'une ligne de code parle de pont.
- 💧 **La crue sort du prototype** (2026-08-12, demandé en cours de session) : `alea` et `altitude_relative` restent dans le `.gpkg` **à 0**, ne sont plus exportés vers Godot, et leurs calques et stocks sont retirés de `06`. Ce qui reste de l'eau est ce qui reste vrai sans elle — **deux rives inégales et trois ponts**. ⚠️ À reporter dans le vault : le jeu s'ouvrait sur une crue rive gauche (**23b**).
- 🔴 **Ce que la coupe a coûté** : le prototype ne teste plus l'économie, le
  temps ni le dilemme panneaux/isolation. L'ancien noyau et son essai restent
  isolés comme trace ; ils ne décrivent plus la boucle jouable.

## Prochaine action

### 👁️ Regarder l'îlot 41, puis attaquer la parcelle en dard sur l'îlot 40

```bash
python QGIS/scripts/chaine.py && python QGIS/scripts/apercu_parcelles.py --ilots 40,41,59
```

**Sur l'îlot 41, ce qui doit avoir changé** : la masse du haut à droite était une équerre avec **une dent qui pendait dans la cour** et un ressaut en escalier ; elle sort maintenant en un seul bloc franc. Plus aucun bâtiment en C dans la ville. Si un ressaut se voit encore, c'est un des **15** dont la poche dépasse `ENCOCHE_AIRE_MAX` (45 m²) — le nombre est dans `04d`, une ligne à changer, on relance, on regarde.

🔴 **Sur l'îlot 40, le défaut restant N'EST PAS dans le bâtiment.** Le bout sud-est garde une parcelle en flèche (**435**), une lanière (**443**, 89 m² pour 2,0 m de façade au bout) et deux replis (**438**). C'est `04c` qu'il faut ouvrir, pas `04d`, et c'est **le peigne** : là où deux bandes issues de rues différentes se rencontrent, le reste part en dard. Mesuré : **118 parcelles de rue sur 809** ont un sommet rentrant, et éteindre la soudure des coins n'en enlève qu'une. La piste à essayer, dans l'esprit de « deux biseaux qui refont un rectangle » (§2 sexies) : **réunir le dard à la voisine dont il est le complément**, et juger la paire sur le sommet rentrant qui disparaît. ⚠️ À mesurer d'abord — combien de parcelles de rue ça coûte.

Et les deux points de la session 26, toujours ouverts : sur l'**îlot 14** le cœur sort en **couloir sinueux, pas en cour commune** (à trancher : aligner les fonds de bâti d'une rangée, ou garder l'irrégularité) ; sur l'**îlot 59** la pointe gauche est rendue au jardin.

✅ **La maquette 3D montre maintenant ces bâtiments.** `07` lit la couche `batiments`, retrouve la façade de chaque parcelle pour le faîtage et dessine la parcelle sous les volumes pour laisser paraître cour ou jardin. La chaîne et les captures sont régénérées.

### 👁️ Puis, les venelles en 3D

Les six venelles sont dans la source et ressortent comme **588 m² de sol pavé dans le groupe de leur îlot**. À regarder sur les îlots **22, 24, 26, 38, 44 et 63** — courtes, au pli, sans traverser un cœur vert. Le défaut encore imprimé par `07` : **159 empreintes concaves** prennent un toit plat.

### 👁️ Puis regarder le geste énergie simplifié

Ouvrir la maquette, cliquer un îlot bâti et déplacer le curseur à droite.
Regarder trois choses : le panneau de droite ne change pas au survol ; le toit
s'assombrit après « Augmenter » ; les totaux de gauche réagissent aussitôt.

Les captures de référence sont
`QGIS/rendus/wehrau_essai_barre.png` (0 %) et
`QGIS/rendus/wehrau_essai_solaire_100.png` (100 %).

## Ce qui attend l'auteur

- [ ] 🔴 **Le potentiel solaire réel est bien inférieur aux 25–40 % du plan.** La suspension est levée : la mesure unique est maintenant **10,4 ha de toiture réelle pente comprise** sur les 701 volumes de `04d`. Le jeu tient (blocages, rentabilités par îlot, « pas d'autonomie par les toits » renforcé). **À trancher maintenant : assumer ce potentiel bas, ou regonfler la colonne `equip` de la table.**
- [ ] ⏸️ **La régie municipale** — hors du prototype tant qu'il n'y a ni budget
  ni retour financier ; reste une question du jeu complet.
- [ ] 🟠 **Le nom des quartiers de Wehrau** — sans lui, « investir dans le Ried avant la rive gauche » n'existe pas comme phrase. Les calques sortent bien des **zones**, pas des confettis : la phrase attend son vocabulaire.
- [x] ✅ ~~**L'exagération verticale**~~ — **close par la mise à plat** le 2026-08-12. Il n'y a plus de relief à exagérer ; les touches `1..4` sont retirées de la maquette.
- [ ] 🟠 **La crue dans le vault** — la décision **23b** (le jeu s'ouvre sur une crue rive gauche) est en contradiction avec « pas de crue pour ce prototype ». Suspendue ou abandonnée ? À écrire dans `Décisions arrêtées`, pas à laisser implicite.
- [ ] **Les quatre tables de level design** → [CHANTIERS.md](CHANTIERS.md) §2. Une ligne changée, on relance, on regarde.
- [ ] ⏸️ **La décision spatiale comme dilemme** — l'ancien prototype la
  testait par la rentabilité et l'isolation ; le prototype actuel ne la teste
  volontairement plus.

🖥️ **Trois questions se tranchent en dessinant l'écran, pas dans le vault** : **n°19** onze nombres permanents, est-ce que ça tient ? · **n°20** `Déclin et défaite` refuse la jauge globale que « la ville exposée » vient d'introduire · **n°21** comment le joueur comprend que l'économie commande son budget, alors que les deux sont loin l'un de l'autre à l'écran. → `Méta/Questions ouvertes.md`

⏸️ **La durée d'une partie est mise de côté volontairement** : pas de fin imposée, on joue jusqu'à l'ennui puis on recommence dans une autre direction. Hypothèse non fixée : ~20 ans en ~2 h. → `Décisions arrêtées` 14b · 14c

## Les commandes du quotidien

```
python "QGIS/scripts/chaine.py"                        → LA commande : refaire la carte ET les bâtiments, 3,2 s
python "QGIS/scripts/chaine.py" --godot                → … et alimenter la maquette 3D
python "QGIS/scripts/apercu_parcelles.py"              → le parcellaire en PNG, numéroté
python "QGIS/scripts/apercu_carte.py"                  → la carte en PNG
python "QGIS/scripts/06_etat_zero.py"                  → la ville entière en HTML, 20 calques
python "QGIS/scripts/08_jouer.py" --toutes             → rejouer les parties du classeur
python "QGIS/scripts/tracer_chemins.py" --blanc        → proposer les venelles, sans rien écrire
```

✅ **L'ordre de la chaîne est tenu par `chaine.py`**, plus par la mémoire : il lance 02 → 03 → 04 → 04b → 04c → **04d** et **s'arrête net** à la première étape qui échoue. La passe `--blanc` n'y sert plus — la carte de travail est dérivée et jetable. Elle reste obligatoire pour les **trois scripts qui écrivent la source** (`00`, `00b`, `tracer_chemins`) : eux touchent du level design.

Le détail des scripts, leurs modes et leurs pièges → **`QGIS/README.md`** (§4 et §9). L'organisation des données → **`QGIS/data/LISEZ-MOI.md`**. La maquette et ses touches (`V` `B` `R` `I` `P`) → **`Godot/README.md`**.

**Deux machines** : Windows principal, Mac occasionnel, **et depuis le 2026-08-17 elles font le même travail**. `git pull` en début de session, `git push` en fin. La carte est du texte que git fusionne ; aucun `.gpkg` n'est suivi. → `CLAUDE.md` §5

## Les deux dernières sessions

**2026-08-17 (session 29) — la 3D lit enfin les bâtiments.** L'auteur demande à voir les nouveaux bâtiments dans Godot. Le défaut était celui déjà nommé : `04d` écrivait les 701 empreintes corrigées, mais `07` recalculait encore 892 volumes avec son ancienne table, donc l'aperçu et la maquette montraient deux villes. `07` lit maintenant la couche `batiments`, rattache chaque volume à sa parcelle et retrouve sa plus longue façade pour orienter le faîtage. La parcelle est dessinée sous ses volumes : le bâti opaque cache son emprise, et ce qui reste visible est exactement la cour ou le jardin, sans second moteur de différence polygonale. Contrôles : **701 volumes sur 693 parcelles bâties**, **116 parcelles non bâties**, **10,4 ha de toiture réelle pente comprise**, murs 3272/3272 et toits 9464/9464 vers l'extérieur. Les 38 débordements annoncés au premier passage étaient faux : le contrôle passait un anneau ouvert au test d'appartenance et oubliait sa dernière arête ; fermé et associé à la vraie parcelle d'origine, il donne **zéro** comme R0 de `04d`. La chaîne complète passe en 6,6 s. Godot charge 70 îlots, 177 tronçons, 237 objets cliquables et 26 182 triangles ; les captures `wehrau_essai_ville.png` et `wehrau_essai_barre.png` sont régénérées. Ce qui reste : **159 empreintes concaves à toit plat** et 158 pans réorientés (2 %), plus le jugement ciblé des parcelles en pointe.

**2026-08-17 (session 28) — l'encoche du bâtiment.** L'auteur regarde `parcelles_ilot_40/41` : *« l'îlot 40 a encore des parcelles bizarres avec des formes de bâtiment pas réalistes, et l'îlot 41 a des coins encore à corriger »*. C'est la suite que la session 27 avait nommée sans l'écrire — « les doigts de cour et les ressauts en escalier demanderaient une ouverture morphologique, pas un seuil de plus ». 🔴 **Ce qui a débloqué la mesure, c'est de compter les décrochements au lieu de mesurer des largeurs** : sur les 701 empreintes, 542 n'ont aucun sommet rentrant, **131 en ont un** — l'équerre, c'est-à-dire l'immeuble d'angle et la maison prolongée de son aile arrière, les deux voulues et très lisibles — et 28 en ont deux ou trois, dont **aucune n'a d'excuse**. Un seuil de largeur ne sait pas les séparer, et c'est mesuré : rallumer l'aile arrière fait passer les poches à bouche ≤ 8 m de 14 à 57, alors que l'aile est la forme la plus **voulue** du fichier. Deux règles, dans deux fonctions. ① **`aile_arriere` vérifie enfin qu'elle est adossée** — sa docstring promettait « adossée à une limite latérale et jamais posée au milieu » depuis le premier jour, mais rien ne le contrôlait : l'aile se pose à un **bout de la cour** mesuré le long de la façade, et sur une parcelle d'**angle**, dont le bâtiment est déjà la réunion de deux bandes, ce bout-là est le mur de l'autre bande. Elle s'adossait donc à son propre bâtiment. On essaie les deux bouts, le tiré d'abord. ② **`fermer_encoches` referme les poches**, la plus petite d'abord — sur une parcelle d'angle la grande poche est la cour que l'équerre entoure, la petite est la dent qui pend dedans — et **après l'aile, pas avant** : l'aile fabrique volontairement un décrochement, donc juger la forme avant elle ne voit pas l'escalier qu'elle produit. 🔴 **Le piège qui a coûté la moitié de la mise au point** : la corde qui referme une poche a ses deux bouts **sur la limite de parcelle**, puisque le retrait latéral vaut 0 en mitoyen ; testée telle quelle elle tombe du mauvais côté du test de parité, et 12 encoches se refermaient au lieu de 52. On teste des points décalés de 10 cm vers l'intérieur de la poche. Résultat : **28 → 15** empreintes à deux décrochements, **2 → 0** en C, **52 encoches refermées** sur 52 bâtiments, R0 toujours à 0, R2 bis inchangé à 16, emprises (0,76 · 0,56 · 0,81), cour du cœur ancien (24 %) et partition inchangées, toit 9,00 → **9,02 ha**. 🔴 **Et il faut dire ce qui n'est PAS réparé** : le bout sud-est de l'îlot 40, celui que l'auteur a entouré, garde une parcelle en flèche (435), une lanière (443) et deux replis (438) — **118 parcelles de rue sur 809 ont un sommet rentrant**, et éteindre la soudure des coins n'en enlève qu'une (119 → 118). Le défaut est dans le **peigne de `04c`**, pas dans `04d`, et aucune règle de bâtiment ne peut le cacher : une empreinte propre dans une parcelle en dard laisse quand même le dard en beige à l'écran. ⚠️ Session faite **sur le Mac**.

**2026-08-17 (session 27) — le coin d'îlot.** L'auteur regarde `parcelles_ilot_40/41/59` et tranche en une phrase : *« le reste fonctionne plutôt bien, c'est surtout les coins d'îlots que je trouve encore problématiques »*, avec l'emprise voulue **dessinée en rouge par-dessus l'image**, trois fois. Les deux causes étaient dans deux scripts différents et il fallait les deux. ① Dans `04c`, la rue la plus longue prend le coin (le débordement de `_bande`, qui empêche le coin de finir en éclats), donc la parcelle d'angle a une vraie façade sur une rue et un simple **flanc** sur l'autre — mesuré : façade forte 16,2 m, **façade faible 7,4 m**, 34 coins sur 163 sous la moitié de la consigne. `04d` y bâtissait bien la réunion de deux bandes, mais le second bras était un moignon. La parcelle du coin absorbe donc sa voisine **du côté faible** (`souder_les_angles`, même geste que `recoller_rectangles` donc la partition ne peut pas tomber), avec trois garde-fous sans lesquels la règle dérive en « le coin avale la rangée » : jamais vers une voisine sans façade sur la rue faible, aucun bras au-delà de 2,6 façades, aucune parcelle au-delà de 2,2 fois l'aire du tissu. 🔴 Et **un coin n'est pas toujours un sommet** : la moitié sont **biseautés**, deux sommets séparés par un pan coupé de deux mètres, qui pris un par un ne font que deux virages de 15° — la pointe de l'îlot 59 et le nord-ouest de l'îlot 40 passaient à travers. ② Dans `04d`, la réunion des deux bandes laisse derrière elle un coin **dont la pointe vise le coin de rue** : le bâtiment en fait le tour et sort en **C**, une cour creusée en plein milieu de la masse. Une tranche d'arrière **enfermée par le bâtiment** repart maintenant au bâtiment — le partage se lit sur son **ouverture**, la part de son contour qui est du bord de parcelle et non du mur. Résultat : **122 coins sur 163 ont leurs deux bras** (48 avant), façade faible **12,6 m**, parcelle d'angle 148 → **278 m²**, et **7 → 2** bâtiments à trois coins rentrants. Emprises (0,76 · 0,56 · 0,82), cour du cœur ancien (24 %), R0 (0) et partition (100,00 %) sont inchangés ; **927 → 809 parcelles**, toit 8,86 → **9,00 ha**. 🔴 **Trois pistes essayées et retirées le jour même** : un seuil de largeur de cour *seul* (434 cours sur 701 tombaient dessous — la cour médiane du cœur ancien fait 2,3 m de profondeur, le seuil annulait la correction de la veille) ; **recoller les tranches d'arrière avant de les juger** (la poche du coin fusionne avec la cour de fond, l'ouverture repasse le seuil, et le C revient tel quel) ; combler une poche sans vérifier qu'elle recolle (le morceau ressortait en second bâtiment posé dans la cour). ⚠️ Ce qui reste, et l'auteur l'a entouré : des **doigts** de cour qui rentrent dans la masse et de petits ressauts en escalier — ça demande une ouverture morphologique, pas un seuil de plus.


→ **[HISTORIQUE.md](HISTORIQUE.md)** pour les sessions précédentes.
