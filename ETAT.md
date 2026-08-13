# ETAT.md — où on en est

> Mis à jour par Claude en fin de session. Complément de [CLAUDE.md](CLAUDE.md).
> **Ce fichier est un signet, pas une source.** Design = le vault. Carte = `QGIS/data/Prototype_qualifie.gpkg`.

| Si tu cherches | Va voir |
|---|---|
| **le prototype, ses étapes, celle qui est ouverte** | [Prototype/00 - Prototype.md](Prototype/00%20-%20Prototype.md) |
| ce qui attend, les défauts connus, les tables à régler | [CHANTIERS.md](CHANTIERS.md) |
| ce qui s'est passé, et pourquoi c'est comme ça | [HISTORIQUE.md](HISTORIQUE.md) |
| ce qui est tranché | `Méta/Décisions arrêtées.md` (vault) |

**Dernière mise à jour : 2026-08-14 (session 22)**

🆕 **Le chemin dans l'îlot** — quand le peigne bute sur un îlot en L, on ne coupe plus l'îlot : on y dessine une **venelle de 3 à 5 m**, retirée de l'emprise avant la découpe. 70 îlots restent 70, et le coude a enfin un devant et un derrière. **7 chemins sur Wehrau, 690 m².** → [Prototype/Parcelles.md](Prototype/Parcelles.md) §4 bis · `Décisions arrêtées` **67 · 67b · 67c**

🆕 **Le prototype a sa catégorie, à côté du vault** : [`Prototype/`](Prototype/00%20-%20Prototype.md) — une note par étape, **une seule ouverte à la fois**. L'étape en cours est [**les parcelles**](Prototype/Parcelles.md). Le vault garde toutes les idées et reste la source de vérité du design ; `Prototype/` porte le chantier. → `CLAUDE.md` §2

---

## Ce qui existe aujourd'hui

| | Où |
|---|---|
| **La carte simulable** — 0,93 km², **70 îlots, 177 tronçons** (ouest redécoupé par l'auteur le 2026-08-13), 13 sous-types, 17 exceptions, **3 franchissements** | `QGIS/data/Prototype_qualifie.gpkg` |
| **La ville bâtie** — **1 105 parcelles dont 998 sur rue** dans le code, aucune sous 45 m². ⚠️ Le `.gpkg` en contient encore 1 096 dont 987 : **il est plus vieux que le code**, et les **702 bâtiments** sont plus vieux encore. Ni `04c` ni `07` n'ont été relancés | couches `emprises` et `parcelles` |
| **La maquette 3D cliquable** — 237 nœuds, fiche à l'îlot et au tronçon, **carte plate**, l'Ilse canalisée et ses trois ponts | `Godot/` → `Godot/README.md` |
| **Le classeur** — 3 parties jouées sur 60 mois, courbes et carte au mois M | `Classeur/` · `QGIS/rendus/parties.html` |
| **Le système énergie** — la table des 13 lignes, 2 décisions à l'îlot, 3 calques, le bandeau à 4 nombres, l'essai imprimé | ✅ **construit, à regarder** → `Godot/scripts/energie.gd` · `Godot/outils/essai_energie.gd` |
| D07, la surchauffe, les quatre moyennes de ville, les six calques | ✂️ **supprimés** (66), archivés dans `Godot/archive/` |

**Les trois contrôles qui comptent, au vert** : la ville privée de sa rivière tombe en **deux morceaux (45 et 11 îlots)** · le réseau routier est **d'un seul tenant** · l'**axe de transit sort tout seul** de l'affectation de trafic.

## Ce qui commande le reste

- 🎯 **Le prototype = un thème mené de bout en bout, l'énergie** (64) — données, décisions, indicateurs, écran. Une **tranche verticale** : un thème complet vaut mieux que sept à moitié. Le thème suivant, c'est **trois pièces** (une table de coefficients par `sous_type`, deux décisions opposées, un calque par indicateur) : *le prototype énergie n'est pas un exemple, c'est le gabarit.*
- 🔗 **La 3D et l'énergie se rejoignent sur le toit** (41 · 56 · 64) : la 3D produit `toit_m2`, `toit_pente`, `toit_plat` et l'ombrage ; l'énergie les lit sans savoir qui parle. **L'énergie n'attend jamais la 3D.**
- 🔓 **Claude écrit ET exécute les scripts de données** (65), y compris sur le vrai `.gpkg`. Trois garde-fous non optionnels : arbre git propre avant d'écrire · passe `--blanc` d'abord · contrôles imprimés en français. → `CLAUDE.md` §3
- 🏘️ **Le prototype est Wehrau**, une petite ville qu'on voit en entier (13b · 13d). Vallmar reste la ville du jeu complet, intacte dans le vault. Une ville entière, même petite, a **un amont et un aval** ; un quartier n'en a pas.
- 🎨 **Townscaper pour le rendu** (42b), et **Wehrau est pastel au sol minéral** (42c) : la grisaille est une **proportion** — 28 % d'imperméabilisé, 14 % de canopée, 4 587 places — pas une teinte.
- 🗺️ **La carte est plate** (2026-08-12) — dans l'image ET dans la donnée. Le seul relief est le **chenal de l'Ilse** : murs verticaux, fond à −2 m, plan d'eau à −1 m. Ce que ça a supprimé : le champ d'altitude, la vallée, l'exagération verticale, la subdivision des sols et des chaussées. **La voirie reste à 0** : au-dessus du chenal elle passe au-dessus du vide, donc les trois ponts existent sans qu'une ligne de code parle de pont.
- 💧 **La crue sort du prototype** (2026-08-12, demandé en cours de session) : `alea` et `altitude_relative` restent dans le `.gpkg` **à 0**, ne sont plus exportés vers Godot, et leurs calques et stocks sont retirés de `06`. Ce qui reste de l'eau est ce qui reste vrai sans elle — **deux rives inégales et trois ponts**. ⚠️ À reporter dans le vault : le jeu s'ouvrait sur une crue rive gauche (**23b**).
- 🔴 **Ce que la coupe a coûté** : le contrôle de recoupement Godot ↔ `08_jouer.py` a disparu avec D07. Depuis la session 18, `essai_energie.gd` vérifie le noyau — invariants, remboursement, deux parties en aveugle — mais **contre lui-même seulement** : une formule fausse des deux côtés d'un même fichier passera. → [CHANTIERS.md](CHANTIERS.md) §4

## Prochaine action

### 🔗 Sous Windows : `tracer_chemins.py`, puis la chaîne complète, puis `07`

🔴 **`04c` d'abord, et c'est nouveau : la carte du dépôt est plus vieille que le code.** `Prototype_qualifie.gpkg` a été écrit au commit `18a6b4c`, donc **avant** `c409680` — celui qui coupe au milieu quand l'îlot est assez profond. La couche `parcelles` du `.gpkg` montre encore l'ancienne découpe, et la maquette Godot montre une ville encore plus ancienne. Deux commandes, dans cet ordre, chacune précédée de sa passe `--blanc` :

```
python "QGIS/scripts/tracer_chemins.py" --blanc
```

```
python "QGIS/scripts/tracer_chemins.py"
```

⚠️ Celui-là écrit dans **`Vallmar2.gpkg`**, la source — donc il faut ensuite repasser toute la chaîne, puisque `02` recopie la source par-dessus la carte de travail.

```
python "QGIS/scripts/02_qualifier.py" & 03 & 04 & 04b
```

```
python "QGIS/scripts/04c_parcelles.py" --blanc
```

```
python "QGIS/scripts/04c_parcelles.py"
```

```
python "QGIS/scripts/07_exporter_godot.py"
```

Ce qui doit avoir changé, et qu'il faut lire dans ce qui s'imprime :

1. **les 7 venelles** sur les îlots 22, 24, 26, 38, 40, 44 et 63 — au pli, courtes, aucun cœur d'îlot entamé ;
2. **les cœurs d'îlot d'un seul tenant** — un cœur ne se reparcelle plus (**67c**), donc plus de damier dans une cour ;
2 bis. **les cœurs d'îlot rendus au centre, pas aux parcelles** (**67d**) — sur les îlots 10, 33, 49, 50 et 66, le vert doit occuper le milieu au lieu d'une parcelle deux à trois fois trop grosse. **15 cœurs pour 0,86 ha** ;
3. **les îlots 64 et 69 coupés au milieu** — le défaut n°1 désigné sur l'image le 2026-08-14, et il tombe tout seul ;
4. **l'îlot 32 en deux parcelles** de 5 579 m² au lieu d'un anneau de 7 parcelles de rue autour d'un cœur vide, donc **deux barres posées au milieu** ;
5. **893 parcelles sur rue et ZÉRO enclavée** là où l'ancienne découpe en donnait 705 ;
6. **les deux défauts connus devraient reculer sans qu'on les vise** : les 18 bâtiments qui mordent sur la rue et les 47 empreintes concaves à toit plat — des parcelles plus rectangulaires font des empreintes plus rectangulaires. À vérifier, pas à promettre.

🔴 **Et le chiffre qui commande la décision en attente : la surface de toit.** Elle va monter avec le nombre de bâtiments, donc **le potentiel solaire de ~9,5 % sera calculé sur une autre ville**. Ne pas trancher la première case de « ce qui attend l'auteur » avant d'avoir relancé la chaîne.

### 👁️ Puis regarder le système énergie tourner — `Prototype/Énergie.md` §8

Le code est fait et les contrôles imprimés sont au vert. Ce qui manque, c'est le regard de l'auteur. Lancer la maquette, puis dans l'ordre :

1. **Le calque rentabilité au mois 0** : est-ce qu'il fait dire « c'est là » en trois secondes ? Les champs et les parcs ne sont pas peints — pas de toit, décision indisponible.
2. **Basculer sur le gain d'isolation** : les deux cartes doivent être presque inverses, **la barre de 1974 chaude sur les deux**.
3. **Avancer de dix ans sans rien faire** : la zone rouge doit avoir reculé, et l'achat grimpé tout seul (+2 %/an — c'est voulu, pas un bug).
4. **Décider** : panneaux sur la barre, puis isoler la même barre. La production décolle après 6 mois ; la consommation tombe après l'isolation ; les toits équipés virent à l'ardoise sombre.

Sept captures de référence sont déjà dans `QGIS/rendus/wehrau_essai_*.png` (régénérables : `Godot_console.exe --path Godot -- --essai`). Le contrôle imprimé complet : `Godot_console.exe --headless --path Godot --script res://outils/essai_energie.gd`.

✅ **Le contrôle le plus important est passé, en aveugle et imprimé** : la partie « panneaux seuls » se bloque sur le **capital** (solde final 2 106 pts, 27 îlots hors de portée), la partie « isolation seule » sur le **budget** (solde final 1 pt, capital monté à 202). Les deux décisions se contraignent l'une l'autre — *les panneaux achètent de l'argent, l'isolation achète de la légitimité*.

🔴 **Ce que le prototype mesurera, et qu'il faut assumer** : l'auteur a refusé le contrepoids du capital politique par la visibilité (**66c**). Sans lui, le test répond à *« choisir où investir fait-il un jeu ? »* en mesurant **un tri par colonne**, pas un choix de lieu. Ce qui reste pour faire bouger la carte : les quatre classes sans chiffre, et la dérive de −6 %/an qui fait reculer la zone rouge.

## Ce qui attend l'auteur

- [ ] 🔴 **Le potentiel solaire réel est ~9,5 %, pas 25–40 %.** ⏸️ **Suspendu au 2026-08-13 : le chiffre va bouger.** Le peigne fait passer les parcelles bâtissables de 705 à 987 ; il faut relancer `07` avant de trancher, sinon on arbitre sur les toits d'une ville qui n'existe plus. La fourchette du plan avait été calibrée sur 76,5 ha d'*emprise* ; les vrais toits font 11,7 ha, et même équiper 100 % de chaque m² plafonnerait vers 28 %. Le jeu tient (blocages, rentabilités par îlot, « pas d'autonomie par les toits » renforcé), mais les ordres de grandeur du `Prototype/Énergie.md` §5 changent d'échelle : ville équipée ~350 pts et non ~1 000, retour plein ~27 pts/an et non ~90. **À trancher : assumer ~9,5 %, ou regonfler la colonne `equip` de la table.** L'essai imprime l'écart à chaque passage.
- [ ] 🟠 **La régie municipale** — à qui appartiennent les panneaux ? Sans réponse, le retour au budget est un raccourci comptable qu'on ne saura plus justifier. Le tarif de rachat **figé au mois de la décision** (ce qui rend le remboursement exact) plaide déjà pour une régie qui signe des contrats.
- [ ] 🟠 **Le nom des quartiers de Wehrau** — sans lui, « investir dans le Ried avant la rive gauche » n'existe pas comme phrase. Les calques sortent bien des **zones**, pas des confettis : la phrase attend son vocabulaire.
- [x] ✅ ~~**L'exagération verticale**~~ — **close par la mise à plat** le 2026-08-12. Il n'y a plus de relief à exagérer ; les touches `1..4` sont retirées de la maquette.
- [ ] 🟠 **La crue dans le vault** — la décision **23b** (le jeu s'ouvre sur une crue rive gauche) est en contradiction avec « pas de crue pour ce prototype ». Suspendue ou abandonnée ? À écrire dans `Décisions arrêtées`, pas à laisser implicite.
- [ ] **Les quatre tables de level design** → [CHANTIERS.md](CHANTIERS.md) §2. Une ligne changée, on relance, on regarde.
- [ ] **Cinq candidats à `Décisions arrêtées`**, prêts mais non tranchés (`Prototype/Énergie.md` §9 bis) : dont *la décision spatiale est le jeu* — **toute décision doit avoir un lieu où elle est bonne et un lieu où elle est mauvaise**.

🖥️ **Trois questions se tranchent en dessinant l'écran, pas dans le vault** : **n°19** onze nombres permanents, est-ce que ça tient ? · **n°20** `Déclin et défaite` refuse la jauge globale que « la ville exposée » vient d'introduire · **n°21** comment le joueur comprend que l'économie commande son budget, alors que les deux sont loin l'un de l'autre à l'écran. → `Méta/Questions ouvertes.md`

⏸️ **La durée d'une partie est mise de côté volontairement** : pas de fin imposée, on joue jusqu'à l'ennui puis on recommence dans une autre direction. Hypothèse non fixée : ~20 ans en ~2 h. → `Décisions arrêtées` 14b · 14c

## Les commandes du quotidien

```
python "QGIS/scripts/apercu_carte.py" "QGIS/data/Prototype_qualifie.gpkg"        → la carte en PNG
python "QGIS/scripts/06_etat_zero.py"                                            → la ville entière dans une page HTML, 20 calques
python "QGIS/scripts/07_exporter_godot.py"                                       → alimenter la maquette 3D
python "QGIS/scripts/08_jouer.py" --toutes                                       → rejouer les parties du classeur
python "QGIS/scripts/tracer_chemins.py" --blanc                                  → proposer les venelles, sans rien écrire
python "QGIS/scripts/apercu_parcelles.py" --avant ancien.gpkg                    → le parcellaire avant/après
```

⚠️ **Chaîne à relancer dans l'ordre : 02 → 03 → 04 → 04b → 04c**, puis `07`. Le `02` repart de `Vallmar2.gpkg` et **écrase** `Prototype_qualifie.gpkg`, y compris `emprises` et `parcelles`. Tout script qui écrit a un mode `--blanc` qui calcule et n'écrit rien : **il tourne toujours d'abord**.

Le détail des douze scripts, leurs modes et leurs pièges → **`QGIS/README.md`** (§4 et §9). La maquette et ses touches (`V` `B` `R` `I` `P`) → **`Godot/README.md`**.

**Deux machines** : Windows principal, Mac occasionnel. `git pull` en début de session, `git push` en fin. ⚠️ Les `.gpkg` ne se fusionnent pas — le travail QGIS se fait sur une machine à la fois. → `CLAUDE.md` §5

## Les deux dernières sessions

**2026-08-14 (session 21) — l'auteur regarde le parcellaire et désigne trois défauts.** Le parcellaire ne se voyait nulle part avant `apercu_parcelles.py` ; cette session est la première où quelqu'un le regarde vraiment. Trois choses en sont sorties, et elles n'ont pas eu la même réponse. **① Les îlots 64 et 69 — « la séparation doit se faire au milieu »** : une rangée prenait tout le fond (28 m sur 34 en 64), celle d'en face se contentait du reste. ✅ **Déjà corrigé dans le code** par `c409680` — ce que l'auteur regardait était **la carte, plus vieille que le code**. C'est la découverte de la session, et elle vaut au-delà du cas : `Prototype_qualifie.gpkg` a été écrit au commit `18a6b4c`, deux commits avant la correction, et rien ne le signalait. **② L'îlot 32, la barre de 1974** — « pas de parcelles, les deux barres seront posées au milieu de l'îlot sans considération du tissu urbain bâti ». ✅ **Fait** : la barre passe du peigne à la boîte, l'îlot sort en **2 parcelles de 5 579 m²** au lieu d'un anneau de 7 parcelles de rue autour d'un cœur vide — le peigne en faisait un tissu de rue, c'est-à-dire l'inverse de ce qu'a fait 1970. **③ L'îlot 24, « parcelles bizarres, triangulaires »** ⚠️ **mesuré, pas corrigé** : 41 parcelles à trois côtés et 56 portant un angle sous 35°, sur 1 031 — le compte n'existait pas. **Deux remèdes essayés, les deux rejetés devant les chiffres** : arrêter la bande au coin rentrant ne fait pas reculer les triangles (41 → 44) et fragmente le cœur (72 → 86 morceaux, 137 avec la bissectrice exacte du squelette) ; réunir la pointe à sa voisine marche mais coûte **14 % des maisons de la ville** pour 53 pointes, et 14 triangles restent. Le mécanisme est en place et **éteint** (`ANGLE_MIN_PARCELLE = 0`), avec les deux tableaux de balayage dans `Prototype/Parcelles.md` §6 bis. 🎯 Ce qu'il faut retenir : **`07` coupe déjà la pointe des bâtiments**, donc le juge est la 3D et pas la carte. 👁️ Et l'aperçu s'est corrigé en route : **les numéros d'îlot sont écrits sur l'image** (demandé en cours de session — sans eux on décrit un défaut au lieu de le nommer), une **légende des tissus** en bas, le vert « jardin » assombri parce qu'il se confondait avec le vert « pavillonnaire », et les polices trouvées sur le Mac — les titres sortaient en carrés. ⚠️ Session faite **sur le Mac** : rien n'a été écrit dans le vrai `.gpkg`, tout est passé par `--blanc` et des copies dans `QGIS/data/bac/`.

**2026-08-13 (session 19) — le parcellaire se débite depuis la rue.** D'après **Vanegas et al., *Procedural Generation of Parcels in Urban Modeling*, Eurographics 2012**, apporté par l'auteur. Le défaut n'était pas où on l'attendait : **l'aire tombait juste, la forme était fausse**. La découpe par boîte englobante ne respectait que le **produit** façade × profondeur — un cœur ancien sortait à 111,7 m² pour 112 visés, mais en carré de 10,6 m au lieu d'une lanière de 7 × 16 ; une parcelle sur deux tournait le dos à la rue ; **30 % n'avaient aucune façade**, donc aucun bâtiment. Le **peigne** (méthode « skeleton » du papier) longe chaque rue, prend une bande profonde comme le tissu le demande, la débite en dents larges comme la façade visée, et laisse au milieu ce qu'aucune rue n'a réclamé : le cœur d'îlot. L'élancement tombe sur sa cible dans les quatre tissus de rue (2,07 / 2,39 / 2,04 / 1,48 pour 2,29 / 2,50 / 2,07 / 1,64), les parcelles sans façade passent de **30 % à 1 %**, et **987 parcelles porteront une maison contre 705**. La boîte n'est pas jetée : elle garde les deux rôles que le papier lui laisse — les gros objets, et le remplissage du cœur. 🎯 Trois trouvailles à garder : **la rue la plus longue doit prendre le coin** (sinon le coin est orphelin et finit en éclats — 82 morceaux de cœur sur le seul îlot 35) · **on ne coupe que ce qui touche la rue** (sinon les droites de chaque arête viennent tailler le cœur à l'autre bout de l'îlot) · et **un seuil serré n'est pas un seuil sûr** : le contrôle d'aire de la réunion d'éclats refusait onze fusions justes parce qu'il était réglé sur le **bruit du flottant** (2,4·10⁻⁴ m², soit exactement 2⁻¹² sur des coordonnées à six chiffres). ✂️ **Les parcelles trop petites sont réunies à leur voisine de plus long bord** (papier §4.2.3) : 48 réunies, **aucune ne survit**, la plus petite parcelle de la ville fait 45,2 m². 👁️ Et le parcellaire **se voit enfin** : `apercu_parcelles.py`, qui n'existait pas — ni `apercu_carte` ni `06` ne dessinaient les parcelles. ⚠️ La session s'est faite pendant que l'auteur redécoupait l'ouest de Wehrau dans QGIS : la carte est passée à **70 îlots et 177 tronçons**, et `02` a effacé `emprises`/`parcelles` en cours de route — elles ont été refaites sur la carte neuve (`04b` puis `04c`).

→ **[HISTORIQUE.md](HISTORIQUE.md)** pour les dix-huit premières sessions.
