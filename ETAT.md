# ETAT.md — où on en est

> Mis à jour par Claude en fin de session. Complément de [CLAUDE.md](CLAUDE.md).
> **Ce fichier est un signet, pas une source.** Design = le vault. Carte = `QGIS/data/source/*.geojson`.

| Si tu cherches | Va voir |
|---|---|
| **le prototype, ses étapes, celle qui est ouverte** | [Prototype/00 - Prototype.md](Prototype/00%20-%20Prototype.md) |
| ce qui attend, les défauts connus, les tables à régler | [CHANTIERS.md](CHANTIERS.md) |
| ce qui s'est passé, et pourquoi c'est comme ça | [HISTORIQUE.md](HISTORIQUE.md) |
| ce qui est tranché | `Méta/Décisions arrêtées.md` (vault) |

**Dernière mise à jour : 2026-08-18 (session 33)**

🏛️ **La ville possède tout — le logement compris.** Tranché pour simplifier :
il n'y a plus de toit des autres, donc plus de loyer de toiture, plus de
copropriété qui refuse, plus de deux régimes selon le tissu. **La question
n°22 est close le lendemain de son ouverture, et aucune ligne de calcul ne
bouge** : la décision ratifie ce que l'économie de la veille avait dû supposer
pour tourner. ⚠️ Une seule chose à tenir : **posséder un logement n'est pas
payer sa facture** — la ville est propriétaire-bailleur, ses locataires paient
leur électricité. Sans ça, les 7,7 M€/an d'énergie de Wehrau tomberaient dans
une caisse dotée de 0,36 M€/an. → `Décisions arrêtées` **70**

🆕 **La décision solaire se paie.** Une petite économie est revenue dans le
prototype : **260 €/m² posé** (× le coefficient de coût du tissu) et **150 €/MWh
produit**, et rien d'autre. La mairie a une **caisse** — 800 k€ au départ,
30 k€/mois de dotation — qui n'encaisse que les panneaux, jamais la facture des
habitants. La fiche annonce le prix avant de valider et **dit combien il manque**
quand la caisse ne suit pas. Mesuré : équiper Wehrau en entier coûte
**10,8 M€** pour **648 k€/an**, et l'amortissement classe les tissus — **dalle
8 ans, barre 10, friche et équipement 11, pavillonnaire 18, maisons de ville 19,
front commerçant 20, cœur ancien 31**. Six contrôles imprimés au vert, capture
du refus comprise. → [Prototype/Énergie.md](Prototype/Énergie.md) ·
`Décisions arrêtées` **69**

🆕 **La décision solaire prend maintenant du temps — et le temps a ralenti
soixante fois.** La fiche annonce la durée avant validation ; la pose avance
ensuite vers la cible, en assombrissant les toits et en recalculant les deux
échelles au même rythme. **0 → 100 % prend 1 mois maximum** ; à mi-pose, l'îlot
32 affiche **50 % réalisés et 15 jours restants**. L'échelle de base est
désormais **une minute réelle pour un mois** (c'était une seconde : la pose
était finie avant qu'on ait relâché la souris). Le bandeau du bas donne pause,
×1, ×4 et ×12 ; `Espace` alterne lecture et pause. Contrôle Godot et captures à
0 %, 50 % et 100 % au vert.
→ [Prototype/Énergie.md](Prototype/Énergie.md)

🆕 **Le prototype énergie tient maintenant en une décision.** À gauche, quatre
conséquences pour toute la ville ; à droite, seulement l'îlot cliqué. Le
curseur augmente sa part solaire de sa valeur actuelle jusqu'à 100 %, sans
budget, capital, isolation ou calque. Contrôle réel sur l'îlot 32 :
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
| **Le système énergie** — une décision à l'îlot, part solaire 0–100 %, ville à gauche et îlot cliqué à droite, **et une caisse qui limite le rythme** | ✅ **économie branchée et capturée, à regarder** → [Prototype/Énergie.md](Prototype/Énergie.md) |
| D07, la surchauffe, les quatre moyennes de ville, les six calques | ✂️ **supprimés** (66), archivés dans `Godot/archive/` |

**Les trois contrôles qui comptent, au vert** : la ville privée de sa rivière tombe en **deux morceaux (45 et 11 îlots)** · le réseau routier est **d'un seul tenant** · l'**axe de transit sort tout seul** de l'affectation de trafic.

## Ce qui commande le reste

- 🎯 **Le prototype énergie teste le lien local → global** (68), **et depuis
  la 69 il teste aussi « où investir ? »** : une seule décision, mais elle a un
  prix et un rendement qui dépendent du tissu. La paire de décisions opposées,
  le capital politique et l'isolation restent une ambition du jeu complet.
- 🔗 **La 3D et l'énergie se rejoignent sur le toit** (41 · 56 · 64) : la 3D produit `toit_m2`, `toit_pente`, `toit_plat` et l'ombrage ; l'énergie les lit sans savoir qui parle. **L'énergie n'attend jamais la 3D.**
- 🔓 **Claude écrit ET exécute les scripts de données** (65). Les garde-fous ont maigri le 2026-08-17 avec le passage en texte : arbre git propre avant d'écrire **la source** · passe `--blanc` d'abord **pour les trois scripts qui la touchent** (`00`, `00b`, `tracer_chemins` — c'est du level design) · contrôles imprimés en français, qui eux ne bougent pas. Écrire un `.gpkg` ne demande plus rien : il est dérivé. → `CLAUDE.md` §3
- 🏘️ **Le prototype est Wehrau**, une petite ville qu'on voit en entier (13b · 13d). Vallmar reste la ville du jeu complet, intacte dans le vault. Une ville entière, même petite, a **un amont et un aval** ; un quartier n'en a pas.
- 🎨 **Townscaper pour le rendu** (42b), et **Wehrau est pastel au sol minéral** (42c) : la grisaille est une **proportion** — 28 % d'imperméabilisé, 14 % de canopée, 4 587 places — pas une teinte.
- 🗺️ **La carte est plate** (2026-08-12) — dans l'image ET dans la donnée. Le seul relief est le **chenal de l'Ilse** : murs verticaux, fond à −2 m, plan d'eau à −1 m. Ce que ça a supprimé : le champ d'altitude, la vallée, l'exagération verticale, la subdivision des sols et des chaussées. **La voirie reste à 0** : au-dessus du chenal elle passe au-dessus du vide, donc les trois ponts existent sans qu'une ligne de code parle de pont.
- 💧 **La crue sort du prototype** (2026-08-12, demandé en cours de session) : `alea` et `altitude_relative` restent dans le `.gpkg` **à 0**, ne sont plus exportés vers Godot, et leurs calques et stocks sont retirés de `06`. Ce qui reste de l'eau est ce qui reste vrai sans elle — **deux rives inégales et trois ponts**. ⚠️ À reporter dans le vault : le jeu s'ouvrait sur une crue rive gauche (**23b**).
- 🔴 **Ce que la coupe a coûté, et ce qui en est revenu** : le dilemme
  panneaux/isolation n'est toujours pas testé. Le temps est revenu comme durée
  de pose visible (31), et l'argent comme coût et rendement (32) — mais **en
  euros, pas en points** : l'ancien noyau à points reste isolé comme trace et
  ne se réactive pas. Les deux dérives de prix restent écrites et débranchées.

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

### 👁️ Puis regarder le geste énergie, son temps et son prix

Ouvrir la maquette, cliquer un îlot bâti et déplacer le curseur à droite.
Regarder d'abord le temps : la durée est annoncée avant « Augmenter » — **1 mois
pour 0 → 100 %**, en jours pour une hausse plus petite ; la barre et le toit
avancent ensemble vers la cible ; les totaux de gauche suivent ; pause, ×1, ×4
et ×12 changent le rythme sans changer la durée en mois. À ×1 le compteur gagne
**un mois par minute de montre**, donc la pose complète dure une minute.

Puis l'argent, qui est neuf. **Cliquer un cœur ancien, puis la barre de 1974**
et comparer la ligne « Se rembourse en » : **31 ans contre 10**. Pousser le
curseur d'un gros îlot à 100 % : la ligne sous le curseur dit le prix et ce
qu'il resterait en caisse. Sur l'**îlot 31** — la friche, 869 k€ — elle passe au
rouge, dit *« il manque 69 k€ »*, et le bouton refuse. C'est le seul non que le
prototype sache prononcer.

Les captures de référence sont
`QGIS/rendus/wehrau_essai_barre.png` (0 %),
`QGIS/rendus/wehrau_essai_caisse.png` (**le refus**),
`QGIS/rendus/wehrau_essai_solaire_pose.png` (50 %, après 15 jours) et
`QGIS/rendus/wehrau_essai_solaire_100.png` (100 %, caisse à 442 k€).

```bash
"C:/Users/janha/Desktop/Godot_v4.7.1-stable_win64.exe/Godot_v4.7.1-stable_win64_console.exe" --path Godot -- --essai
```

## Ce qui attend l'auteur

- [ ] 🔴 **Le potentiel solaire réel est bien inférieur aux 25–40 % du plan.** La suspension est levée : la mesure unique est maintenant **10,4 ha de toiture réelle pente comprise** sur les 701 volumes de `04d`. Le jeu tient (blocages, rentabilités par îlot, « pas d'autonomie par les toits » renforcé). **À trancher maintenant : assumer ce potentiel bas, ou regonfler la colonne `equip` de la table.**
- [x] ✅ ~~**Qui possède les panneaux ?**~~ **Tout appartient à la ville**,
  logement compris (70). À rouvrir **avant Vallmar**, pas avant : le
  propriétaire qui dit non est une tension que le jeu complet devra porter —
  une transformation urbaine où personne ne peut refuser n'est pas une
  transformation, c'est un plan.
- [ ] 🟠 **Les quatre nombres de l'économie sont du level design, pas de la
  physique** : 260 €/m², 150 €/MWh, 800 k€ de caisse, 30 k€/mois de dotation.
  Ce sont eux qui décident si le jeu est « dur mais possible ». Le tableau
  mesuré pour les juger est imprimé par `-- --essai` et recopié dans
  [Prototype/Énergie.md](Prototype/Énergie.md) §4.
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

**2026-08-18 (session 33) — un seul propriétaire.** L'auteur ferme en une phrase la question ouverte la veille : *« pour simplifier le prototype, disons que tout le logement et tous les panneaux appartiennent à la ville »*. C'est plus court que les trois pistes examinées — il n'y a plus de toit des autres, donc plus de loyer de toiture à mettre dans la table, plus de copropriété qui refuse, plus de deux régimes selon le tissu. 🟢 **Aucune ligne de calcul ne change** : la décision **ratifie** ce que l'économie du 2026-08-17 avait dû supposer pour tourner. Ce qui change, c'est qu'on peut maintenant le dire, et que ce qui distingue les îlots n'est plus la propriété mais le coût d'accès au toit et son rendement — déjà dans la table. ⚠️ **La ligne qui tient tout le reste** : posséder un logement n'est pas payer sa facture. La ville est **propriétaire-bailleur**, ses locataires paient leur électricité ; sans ça la facture de 7,7 M€/an entrerait dans une caisse dotée de 0,36 M€/an et il n'y aurait plus de jeu. Décision **70**, question **n°22** close. Contrôle Godot relancé, six vérifications au vert, caisse à **442 k€** au mois 1 après la pose de l'îlot 32.

**2026-08-17 (session 32) — une petite économie, deux prix.** L'auteur demande
*« une petite économie simple, avec les coûts et les rendements des panneaux
solaires »*. Deux prix suffisent — **260 €/m² posé** et **150 €/MWh produit** —
et tout le reste s'en déduit : le coût d'une pose, sa recette annuelle, son
amortissement. L'unité passe du « point » à l'euro, parce qu'un point ne se
compare à rien. La `cout_x` de la table, jusque-là documentaire, devient enfin
visible : un toit de cœur ancien coûte plus du double d'un toit de barre au
mètre carré. La caisse municipale — 800 k€, 30 k€/mois — **n'encaisse que les
panneaux** : faire passer la facture d'énergie de la ville (7,7 M€/an) par la
mairie aurait donné un jeu sans décision. 🔴 **Le piège du jour, et il était
dans le noyau, pas dans l'écran** : la recette est l'**intégrale** de la part
équipée dans le temps, et l'ancienne machinerie de révision d'un chantier
**réécrivait la base** de cet historique — un joueur qui relève sa cible à
mi-pose aurait fait croire à la caisse que le toit produisait depuis le premier
jour. Les rampes s'**additionnent** maintenant au lieu de se remplacer, un
chantier engagé ne se révise plus, et le dictionnaire qui servait à défaire la
réécriture a disparu avec elle. L'intégrale est calculée en forme close, donc
la caisse vaut la même chose à 5 ou à 500 images par seconde. Trois nouveaux
contrôles imprimés arrêtent la maquette s'ils tombent à faux, et une capture
montre le refus. Décision **69**, question **n°22** ouverte dans la foulée : la
ville paie et encaisse sur des toits qui ne sont pas tous à elle.

→ **[HISTORIQUE.md](HISTORIQUE.md)** pour les sessions précédentes.
