# ETAT.md — où on en est

> Mis à jour par Claude en fin de session. Complément de [CLAUDE.md](CLAUDE.md).
> **Ce fichier est un signet, pas une source.** Design = le vault. Carte = `QGIS/data/Prototype_qualifie.gpkg`.

| Si tu cherches | Va voir |
|---|---|
| ce qui attend, les défauts connus, les tables à régler | [CHANTIERS.md](CHANTIERS.md) |
| ce qui s'est passé, et pourquoi c'est comme ça | [HISTORIQUE.md](HISTORIQUE.md) |
| le prototype en cours, en détail | [PLAN_energie.md](PLAN_energie.md) |
| ce qui est tranché | `Méta/Décisions arrêtées.md` (vault) |

**Dernière mise à jour : 2026-08-12 (session 18)**

---

## Ce qui existe aujourd'hui

| | Où |
|---|---|
| **La carte simulable** — 0,93 km², 69 îlots, 178 tronçons, 13 sous-types, 17 exceptions, **3 franchissements** | `QGIS/data/Prototype_qualifie.gpkg` |
| **La ville bâtie** — 1 003 parcelles, **702 bâtiments**, **634 toits à deux pentes**, 667 espaces libres dont **440 plantés** | couches `emprises` et `parcelles` |
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

### 👁️ Regarder le système énergie tourner — `PLAN_energie.md` §8

Le code est fait et les contrôles imprimés sont au vert. Ce qui manque, c'est le regard de l'auteur. Lancer la maquette, puis dans l'ordre :

1. **Le calque rentabilité au mois 0** : est-ce qu'il fait dire « c'est là » en trois secondes ? Les champs et les parcs ne sont pas peints — pas de toit, décision indisponible.
2. **Basculer sur le gain d'isolation** : les deux cartes doivent être presque inverses, **la barre de 1974 chaude sur les deux**.
3. **Avancer de dix ans sans rien faire** : la zone rouge doit avoir reculé, et l'achat grimpé tout seul (+2 %/an — c'est voulu, pas un bug).
4. **Décider** : panneaux sur la barre, puis isoler la même barre. La production décolle après 6 mois ; la consommation tombe après l'isolation ; les toits équipés virent à l'ardoise sombre.

Sept captures de référence sont déjà dans `QGIS/rendus/wehrau_essai_*.png` (régénérables : `Godot_console.exe --path Godot -- --essai`). Le contrôle imprimé complet : `Godot_console.exe --headless --path Godot --script res://outils/essai_energie.gd`.

✅ **Le contrôle le plus important est passé, en aveugle et imprimé** : la partie « panneaux seuls » se bloque sur le **capital** (solde final 2 106 pts, 27 îlots hors de portée), la partie « isolation seule » sur le **budget** (solde final 1 pt, capital monté à 202). Les deux décisions se contraignent l'une l'autre — *les panneaux achètent de l'argent, l'isolation achète de la légitimité*.

🔴 **Ce que le prototype mesurera, et qu'il faut assumer** : l'auteur a refusé le contrepoids du capital politique par la visibilité (**66c**). Sans lui, le test répond à *« choisir où investir fait-il un jeu ? »* en mesurant **un tri par colonne**, pas un choix de lieu. Ce qui reste pour faire bouger la carte : les quatre classes sans chiffre, et la dérive de −6 %/an qui fait reculer la zone rouge.

## Ce qui attend l'auteur

- [ ] 🔴 **Le potentiel solaire réel est ~9,5 %, pas 25–40 %.** La fourchette du plan avait été calibrée sur 76,5 ha d'*emprise* ; les vrais toits font 11,7 ha, et même équiper 100 % de chaque m² plafonnerait vers 28 %. Le jeu tient (blocages, rentabilités par îlot, « pas d'autonomie par les toits » renforcé), mais les ordres de grandeur du `PLAN_energie.md` §5 changent d'échelle : ville équipée ~350 pts et non ~1 000, retour plein ~27 pts/an et non ~90. **À trancher : assumer ~9,5 %, ou regonfler la colonne `equip` de la table.** L'essai imprime l'écart à chaque passage.
- [ ] 🟠 **La régie municipale** — à qui appartiennent les panneaux ? Sans réponse, le retour au budget est un raccourci comptable qu'on ne saura plus justifier. Le tarif de rachat **figé au mois de la décision** (ce qui rend le remboursement exact) plaide déjà pour une régie qui signe des contrats.
- [ ] 🟠 **Le nom des quartiers de Wehrau** — sans lui, « investir dans le Ried avant la rive gauche » n'existe pas comme phrase. Les calques sortent bien des **zones**, pas des confettis : la phrase attend son vocabulaire.
- [x] ✅ ~~**L'exagération verticale**~~ — **close par la mise à plat** le 2026-08-12. Il n'y a plus de relief à exagérer ; les touches `1..4` sont retirées de la maquette.
- [ ] 🟠 **La crue dans le vault** — la décision **23b** (le jeu s'ouvre sur une crue rive gauche) est en contradiction avec « pas de crue pour ce prototype ». Suspendue ou abandonnée ? À écrire dans `Décisions arrêtées`, pas à laisser implicite.
- [ ] **Les quatre tables de level design** → [CHANTIERS.md](CHANTIERS.md) §2. Une ligne changée, on relance, on regarde.
- [ ] **Cinq candidats à `Décisions arrêtées`**, prêts mais non tranchés (`PLAN_energie.md` §9 bis) : dont *la décision spatiale est le jeu* — **toute décision doit avoir un lieu où elle est bonne et un lieu où elle est mauvaise**.

🖥️ **Trois questions se tranchent en dessinant l'écran, pas dans le vault** : **n°19** onze nombres permanents, est-ce que ça tient ? · **n°20** `Déclin et défaite` refuse la jauge globale que « la ville exposée » vient d'introduire · **n°21** comment le joueur comprend que l'économie commande son budget, alors que les deux sont loin l'un de l'autre à l'écran. → `Méta/Questions ouvertes.md`

⏸️ **La durée d'une partie est mise de côté volontairement** : pas de fin imposée, on joue jusqu'à l'ennui puis on recommence dans une autre direction. Hypothèse non fixée : ~20 ans en ~2 h. → `Décisions arrêtées` 14b · 14c

## Les commandes du quotidien

```
python "QGIS/scripts/apercu_carte.py" "QGIS/data/Prototype_qualifie.gpkg"        → la carte en PNG
python "QGIS/scripts/06_etat_zero.py"                                            → la ville entière dans une page HTML, 20 calques
python "QGIS/scripts/07_exporter_godot.py"                                       → alimenter la maquette 3D
python "QGIS/scripts/08_jouer.py" --toutes                                       → rejouer les parties du classeur
```

⚠️ **Chaîne à relancer dans l'ordre : 02 → 03 → 04 → 04b → 04c**, puis `07`. Le `02` repart de `Vallmar2.gpkg` et **écrase** `Prototype_qualifie.gpkg`, y compris `emprises` et `parcelles`. Tout script qui écrit a un mode `--blanc` qui calcule et n'écrit rien : **il tourne toujours d'abord**.

Le détail des onze scripts, leurs modes et leurs pièges → **`QGIS/README.md`** (§4 et §9). La maquette et ses touches (`V` `B` `R` `I` `P`) → **`Godot/README.md`**.

**Deux machines** : Windows principal, Mac occasionnel. `git pull` en début de session, `git push` en fin. ⚠️ Les `.gpkg` ne se fusionnent pas — le travail QGIS se fait sur une machine à la fois. → `CLAUDE.md` §5

## Les deux dernières sessions

**2026-08-12 (session 18) — le système énergie, de la table au bandeau.** Tout le périmètre d'un coup : `energie.gd` (la table des treize lignes, les deux dérives), les deux décisions à l'**îlot** avec la troisième durée « travaux », les retours d'argent au **tarif figé au mois de la décision**, le refus qui contrôle le budget **et** le capital, les trois calques (les îlots sans toit ne sont **pas peints**), la fiche décomposée (« couverture 12 % : 8 produits, 4 économisés »), le bandeau à quatre nombres, les toits qui virent à l'ardoise, et `essai_energie.gd` — le contrôle imprimé qui joue **deux parties en aveugle** : panneaux seuls bloque sur le capital, isolation seule sur le budget, remboursement de la barre au mois 111 comme calculé. 🔴 La découverte de la session : **le potentiel réel des toits est ~9,5 %**, la fourchette 25–40 % du plan avait été calibrée sur l'emprise, pas sur les toits. La vue chantiers est **reportée** par l'auteur → [CHANTIERS.md](CHANTIERS.md) §3.

**2026-08-12 (session 17) — la carte devient plate, et un toit de repli est essayé puis retiré.** (1) **La carte est plate**, dans l'image et dans la donnée ; l'Ilse devient un chenal à murs verticaux ; **la crue sort du prototype**, décidé en cours de session. (2) Le toit plat de repli — *« quand la surface est trop difficile, fait un toit plat »* — a été **écrit, regardé et retiré le même jour** : devant l'image, l'auteur a préféré les toits d'avant. 🎯 Ce que l'essai a laissé, et qui reste vrai : le bon critère est le **pli d'un pan** (l'écart entre ses deux diagonales), sa distribution est **continue, sans décrochement** — donc c'était un curseur, pas un seuil à trouver ; la mesure évidente est **fausse** (574 bâtiments sur 702 se déclaraient vrillés à tort) ; et le critère « angle trop aigu » **ne se déclenche jamais**, le plus petit angle de la ville étant 70,2°.

→ **[HISTORIQUE.md](HISTORIQUE.md)** pour les seize premières sessions.
