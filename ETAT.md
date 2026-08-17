# ETAT.md — où on en est

> Mis à jour par Claude en fin de session. Complément de [CLAUDE.md](CLAUDE.md).
> **Ce fichier est un signet, pas une source.** Design = le vault. Carte = `QGIS/data/source/*.geojson`.

| Si tu cherches | Va voir |
|---|---|
| **le prototype, ses étapes, celle qui est ouverte** | [Prototype/00 - Prototype.md](Prototype/00%20-%20Prototype.md) |
| ce qui attend, les défauts connus, les tables à régler | [CHANTIERS.md](CHANTIERS.md) |
| ce qui s'est passé, et pourquoi c'est comme ça | [HISTORIQUE.md](HISTORIQUE.md) |
| ce qui est tranché | `Méta/Décisions arrêtées.md` (vault) |

**Dernière mise à jour : 2026-08-17 (session 25)**

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
| **La ville bâtie** — **927 parcelles dont 912 sur rue**, aucune sous 45 m², **zéro reliquat de rue enclavé**, partition à 100,00 %, 15 cœurs d'îlot et **6 venelles**. ✅ **La chaîne a été relancée le 2026-08-17, `07` compris** : 892 volumes bâtis et 12,1 ha de toit réel | source : `chemins.geojson` · dérivés : `emprises`, `parcelles`, `Godot/data/wehrau.json` |
| **La maquette 3D cliquable** — 237 nœuds, fiche à l'îlot et au tronçon, **carte plate**, l'Ilse canalisée et ses trois ponts | `Godot/` → `Godot/README.md` |
| **Le classeur** — 3 parties jouées sur 60 mois, courbes et carte au mois M | `Classeur/` · `QGIS/rendus/parties.html` |
| **Le système énergie** — la table des 13 lignes, 2 décisions à l'îlot, 3 calques, le bandeau à 4 nombres, l'essai imprimé | ✅ **construit, à regarder** → `Godot/scripts/energie.gd` · `Godot/outils/essai_energie.gd` |
| D07, la surchauffe, les quatre moyennes de ville, les six calques | ✂️ **supprimés** (66), archivés dans `Godot/archive/` |

**Les trois contrôles qui comptent, au vert** : la ville privée de sa rivière tombe en **deux morceaux (45 et 11 îlots)** · le réseau routier est **d'un seul tenant** · l'**axe de transit sort tout seul** de l'affectation de trafic.

## Ce qui commande le reste

- 🎯 **Le prototype = un thème mené de bout en bout, l'énergie** (64) — données, décisions, indicateurs, écran. Une **tranche verticale** : un thème complet vaut mieux que sept à moitié. Le thème suivant, c'est **trois pièces** (une table de coefficients par `sous_type`, deux décisions opposées, un calque par indicateur) : *le prototype énergie n'est pas un exemple, c'est le gabarit.*
- 🔗 **La 3D et l'énergie se rejoignent sur le toit** (41 · 56 · 64) : la 3D produit `toit_m2`, `toit_pente`, `toit_plat` et l'ombrage ; l'énergie les lit sans savoir qui parle. **L'énergie n'attend jamais la 3D.**
- 🔓 **Claude écrit ET exécute les scripts de données** (65). Les garde-fous ont maigri le 2026-08-17 avec le passage en texte : arbre git propre avant d'écrire **la source** · passe `--blanc` d'abord **pour les trois scripts qui la touchent** (`00`, `00b`, `tracer_chemins` — c'est du level design) · contrôles imprimés en français, qui eux ne bougent pas. Écrire un `.gpkg` ne demande plus rien : il est dérivé. → `CLAUDE.md` §3
- 🏘️ **Le prototype est Wehrau**, une petite ville qu'on voit en entier (13b · 13d). Vallmar reste la ville du jeu complet, intacte dans le vault. Une ville entière, même petite, a **un amont et un aval** ; un quartier n'en a pas.
- 🎨 **Townscaper pour le rendu** (42b), et **Wehrau est pastel au sol minéral** (42c) : la grisaille est une **proportion** — 28 % d'imperméabilisé, 14 % de canopée, 4 587 places — pas une teinte.
- 🗺️ **La carte est plate** (2026-08-12) — dans l'image ET dans la donnée. Le seul relief est le **chenal de l'Ilse** : murs verticaux, fond à −2 m, plan d'eau à −1 m. Ce que ça a supprimé : le champ d'altitude, la vallée, l'exagération verticale, la subdivision des sols et des chaussées. **La voirie reste à 0** : au-dessus du chenal elle passe au-dessus du vide, donc les trois ponts existent sans qu'une ligne de code parle de pont.
- 💧 **La crue sort du prototype** (2026-08-12, demandé en cours de session) : `alea` et `altitude_relative` restent dans le `.gpkg` **à 0**, ne sont plus exportés vers Godot, et leurs calques et stocks sont retirés de `06`. Ce qui reste de l'eau est ce qui reste vrai sans elle — **deux rives inégales et trois ponts**. ⚠️ À reporter dans le vault : le jeu s'ouvrait sur une crue rive gauche (**23b**).
- 🔴 **Ce que la coupe a coûté** : le contrôle de recoupement Godot ↔ `08_jouer.py` a disparu avec D07. Depuis la session 18, `essai_energie.gd` vérifie le noyau — invariants, remboursement, deux parties en aveugle — mais **contre lui-même seulement** : une formule fausse des deux côtés d'un même fichier passera. → [CHANTIERS.md](CHANTIERS.md) §4

## Prochaine action

### 👁️ Regarder le parcellaire et les venelles en 3D

✅ **La chaîne de données est terminée jusqu'à l'export Godot.** Les six venelles sont dans la source et ressortent comme **588 m² de sol pavé dans le groupe de leur îlot**. Le contrôle imprimé est au vert : 927 parcelles, 912 sur rue, zéro reliquat enclavé, partition 100,00 %, 15 cœurs.

Ce qui attend maintenant l'auteur dans la maquette :

1. regarder les venelles des îlots **22, 24, 26, 38, 44 et 63** — courtes, au pli, sans traverser un cœur vert ;
2. juger les parcelles triangulaires **en 3D**, puisque `07` coupe déjà les pointes des bâtiments ;
3. regarder les défauts encore imprimés : **44 bâtiments sur 892 débordent de leur parcelle** jusqu'à 5,5 m, et **70 empreintes concaves** prennent un toit plat ;
4. puis trancher le potentiel solaire sur la ville désormais stable : **12,1 ha de toit réel**.

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

- [ ] 🔴 **Le potentiel solaire réel est ~9,5 %, pas 25–40 %.** ✅ **La suspension sur les parcelles est levée** : `07` a été relancé sur la ville avec venelles, qui porte désormais **12,1 ha de toit réel**. La fourchette du plan avait été calibrée sur 76,5 ha d'*emprise* ; même équiper 100 % des toits reste très loin de l'autonomie. Le jeu tient (blocages, rentabilités par îlot, « pas d'autonomie par les toits » renforcé), mais les ordres de grandeur du `Prototype/Énergie.md` §5 changent d'échelle. **À trancher maintenant : assumer ce potentiel bas, ou regonfler la colonne `equip` de la table.**
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
python "QGIS/scripts/chaine.py"                        → LA commande : refaire la carte, 0,7 s
python "QGIS/scripts/chaine.py" --godot                → … et alimenter la maquette 3D
python "QGIS/scripts/apercu_parcelles.py"              → le parcellaire en PNG, numéroté
python "QGIS/scripts/apercu_carte.py"                  → la carte en PNG
python "QGIS/scripts/06_etat_zero.py"                  → la ville entière en HTML, 20 calques
python "QGIS/scripts/08_jouer.py" --toutes             → rejouer les parties du classeur
python "QGIS/scripts/tracer_chemins.py" --blanc        → proposer les venelles, sans rien écrire
```

✅ **L'ordre de la chaîne est tenu par `chaine.py`**, plus par la mémoire : il lance 02 → 03 → 04 → 04b → 04c et **s'arrête net** à la première étape qui échoue. La passe `--blanc` n'y sert plus — la carte de travail est dérivée et jetable. Elle reste obligatoire pour les **trois scripts qui écrivent la source** (`00`, `00b`, `tracer_chemins`) : eux touchent du level design.

Le détail des scripts, leurs modes et leurs pièges → **`QGIS/README.md`** (§4 et §9). L'organisation des données → **`QGIS/data/LISEZ-MOI.md`**. La maquette et ses touches (`V` `B` `R` `I` `P`) → **`Godot/README.md`**.

**Deux machines** : Windows principal, Mac occasionnel, **et depuis le 2026-08-17 elles font le même travail**. `git pull` en début de session, `git push` en fin. La carte est du texte que git fusionne ; aucun `.gpkg` n'est suivi. → `CLAUDE.md` §5

## Les deux dernières sessions

**2026-08-17 (session 25) — les venelles reviennent dans la source et traversent toute la chaîne.** L'auteur demande de réintégrer les chemins montrés depuis l'ancienne version du parcellaire. Le garde-fou a joué dans l'ordre prévu : arbre propre, passe `--blanc`, puis écriture de `QGIS/data/source/chemins.geojson`. **Six tracés récupérables**, sur les îlots 22, 24, 26, 38, 44 et 63 ; le septième autrefois annoncé sur l'îlot 40 n'avait jamais été enregistré et ne passe plus le seuil de rectangularité. La chaîne complète jusqu'à `07` donne **6 venelles, 242 m et 588 m² pavés**, 927 parcelles dont **912 sur rue**, zéro reliquat de rue enclavé, partition 100,00 %, 15 cœurs, 892 volumes bâtis et **12,1 ha de toit réel**. Le résultat est visible dans `QGIS/rendus/venelles_nouvelle_chaine.png`. La règle de production solo a commandé le rangement : les six lignes vivent dans la **source texte** ; le GeoPackage, le JSON Godot et les PNG restent des dérivés régénérables.

**2026-08-17 (session 24) — QGIS sort du projet, et la carte devient du texte.** L'auteur ouvre la session sur un constat : *« le workflow geopackage me semble devenu compliqué »*, et une décision — plus de QGIS, Python seul. Ce qui a rendu la suite évidente, c'est de regarder ce que la source contenait vraiment : **rien que de la géométrie**, 70 polygones et 179 lignes, plus une colonne `hierarchy`. Tout le reste — fonction, sous-type, largeurs, adjacences, emprises, parcelles, bâtiments — est recalculé à chaque passage. Le binaire ne protégeait donc rien, et il coûtait deux règles : *« la carte ne s'écrit que sous Windows »* (parce que git ne fusionne pas un `.gpkg`) et la peur permanente qu'un dérivé versionné se périme, qui avait déjà coûté une session entière le 2026-08-14. **La source est passée en GeoJSON**, une entité par ligne, triée par `fid` — les deux contraintes qui rendent la fusion git possible. `carte.py` est le seul fichier du dépôt qui connaisse encore le WKB ; six fonctions d'encodage binaire ont été retirées des scripts qui écrivent la source. **Aucun `.gpkg` n'est plus suivi** : `travail/` et `archive/` sont gitignorés, `bac/` a fondu dans `travail/`. 🔴 **Le contrôle qui a sauvé la mesure, et qu'il ne fallait pas sauter** : la première version arrondissait les coordonnées au millimètre — plus court à lire, sans effet visible sur une carte en mètres. Faux : `04c` a cessé d'effacer la coupe en diagonale de l'îlot 13 (2 coupes, puis 1), parce que la rectangularité de la paire réunie y vaut **1,00 pile contre un seuil à 0,90**. Un demi-millimètre fait basculer un test de forme. L'arrondi a été supprimé, et le texte redonne les géométries **identiques à l'octet** — vérifié sur les 249 entités. La chaîne relancée sur le texte sort exactement les chiffres du binaire : 926 parcelles, 911 sur rue, 0 enclavée, partition 100,00 %, coupes effacées sur les îlots 13 et 33. ✅ **Et l'ordre des étapes est passé de la mémoire au code** : `chaine.py` lance 02 → 03 → 04 → 04b → 04c en **0,7 s** et s'arrête net à la première qui échoue. Cette durée est l'argument : versionner un dérivé qui se refait en moins d'une seconde n'avait aucune contrepartie. ⚠️ Session faite **sur le Mac, qui écrit maintenant la carte comme Windows** — c'est précisément ce que ce travail débloque.

→ **[HISTORIQUE.md](HISTORIQUE.md)** pour les sessions précédentes.
