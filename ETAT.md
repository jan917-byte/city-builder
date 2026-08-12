# ETAT.md — où on en est

> Mis à jour par Claude en fin de session. Complément de [CLAUDE.md](CLAUDE.md).
> **Ce fichier est un signet, pas une source.** Design = le vault. Carte = `QGIS/data/Prototype_qualifie.gpkg`.

| Si tu cherches | Va voir |
|---|---|
| ce qui attend, les défauts connus, les tables à régler | [CHANTIERS.md](CHANTIERS.md) |
| ce qui s'est passé, et pourquoi c'est comme ça | [HISTORIQUE.md](HISTORIQUE.md) |
| le prototype en cours, en détail | [PLAN_energie.md](PLAN_energie.md) |
| ce qui est tranché | `Méta/Décisions arrêtées.md` (vault) |

**Dernière mise à jour : 2026-08-12 (session 16)**

---

## Ce qui existe aujourd'hui

| | Où |
|---|---|
| **La carte simulable** — 0,93 km², 69 îlots, 178 tronçons, 13 sous-types, 17 exceptions, **3 franchissements** | `QGIS/data/Prototype_qualifie.gpkg` |
| **La ville bâtie** — 1 003 parcelles, **702 bâtiments**, 634 toits à deux pentes, 667 espaces libres dont **440 plantés** | couches `emprises` et `parcelles` |
| **La maquette 3D cliquable** — 237 nœuds, fiche à l'îlot et au tronçon, l'Ilse creusée et ses trois ponts | `Godot/` → `Godot/README.md` |
| **Le classeur** — 3 parties jouées sur 60 mois, courbes et carte au mois M | `Classeur/` · `QGIS/rendus/parties.html` |
| **Le système énergie** | ⏳ **pas commencé** → `PLAN_energie.md` |
| D07, la surchauffe, les quatre moyennes de ville, les six calques | ✂️ **supprimés** (66), archivés dans `Godot/archive/` |

**Les trois contrôles qui comptent, au vert** : la ville privée de sa rivière tombe en **deux morceaux (45 et 11 îlots)** · le réseau routier est **d'un seul tenant** · l'**axe de transit sort tout seul** de l'affectation de trafic.

## Ce qui commande le reste

- 🎯 **Le prototype = un thème mené de bout en bout, l'énergie** (64) — données, décisions, indicateurs, écran. Une **tranche verticale** : un thème complet vaut mieux que sept à moitié. Le thème suivant, c'est **trois pièces** (une table de coefficients par `sous_type`, deux décisions opposées, un calque par indicateur) : *le prototype énergie n'est pas un exemple, c'est le gabarit.*
- 🔗 **La 3D et l'énergie se rejoignent sur le toit** (41 · 56 · 64) : la 3D produit `toit_m2`, `toit_pente`, `toit_plat` et l'ombrage ; l'énergie les lit sans savoir qui parle. **L'énergie n'attend jamais la 3D.**
- 🔓 **Claude écrit ET exécute les scripts de données** (65), y compris sur le vrai `.gpkg`. Trois garde-fous non optionnels : arbre git propre avant d'écrire · passe `--blanc` d'abord · contrôles imprimés en français. → `CLAUDE.md` §3
- 🏘️ **Le prototype est Wehrau**, une petite ville qu'on voit en entier (13b · 13d). Vallmar reste la ville du jeu complet, intacte dans le vault. Une ville entière, même petite, a **un amont et un aval** ; un quartier n'en a pas.
- 🎨 **Townscaper pour le rendu** (42b), et **Wehrau est pastel au sol minéral** (42c) : la grisaille est une **proportion** — 28 % d'imperméabilisé, 14 % de canopée, 4 587 places — pas une teinte.
- 🔴 **Ce que la coupe a coûté** : le contrôle de recoupement Godot ↔ `08_jouer.py` a disparu avec D07. Une formule fausse dans le noyau ne sera plus attrapée avant qu'on la voie à l'écran. → [CHANTIERS.md](CHANTIERS.md) §4

## Prochaine action

### 🔋 Le système énergie — `PLAN_energie.md` §3 à §8, moins le calque visibilité

Tout est prêt côté données. Quatre morceaux, dans cet ordre :

1. **`Godot/scripts/energie.gd`**, fichier neuf — la table des treize lignes et les deux dérives du temps (panneau −6 %/an, énergie achetée +2 %/an).
2. **Les deux décisions** dans `chantiers.gd`, qui visent l'**îlot** alors qu'il ne sait viser que la rue — c'est la seule vraie plomberie.
3. **Les trois calques** : rentabilité solaire (quatre classes, aucun chiffre), gain d'isolation, toits qui produisent.
4. **Le bandeau** à quatre nombres, en écart à t0.

⚠️ **Deux pièges nommés dans le plan** : le capital politique doit pouvoir être **positif** (l'isolation en rend), et le contrôle de refus budgétaire ne doit **pas** compter le retour du chantier qu'on accepte — sinon un chantier se finance lui-même.

🎯 **Le contrôle le plus important** : une partie « panneaux seuls » doit se bloquer sur le **capital**, une partie « isolation seule » sur le **budget**. Les deux décisions sont de nature opposée — *les panneaux achètent de l'argent, l'isolation achète de la légitimité* — et leurs cartes sont presque inverses, sauf sur **la barre de 1974**, qui devient l'objet central du jeu.

🔴 **Ce que le prototype mesurera, et qu'il faut assumer** : l'auteur a refusé le contrepoids du capital politique par la visibilité (**66c**). Sans lui, le test répond à *« choisir où investir fait-il un jeu ? »* en mesurant **un tri par colonne**, pas un choix de lieu. Ce qui reste pour faire bouger la carte : les quatre classes sans chiffre, et la dérive de −6 %/an qui fait reculer la zone rouge.

## Ce qui attend l'auteur

**Rien ne bloque le code.** Le prototype énergie peut s'écrire dès maintenant.

- [ ] 🟠 **La régie municipale** — à qui appartiennent les panneaux ? Sans réponse, le retour au budget est un raccourci comptable qu'on ne saura plus justifier.
- [ ] 🟠 **Le nom des quartiers de Wehrau** — sans lui, « investir dans le Ried avant la rive gauche » n'existe pas comme phrase.
- [ ] **L'exagération verticale** — 9 m de relief sur 898 m de large, contre 27 m pour la barre. Touches `1..4` dans la maquette. Se tranche **devant l'image**, et une fois tranchée, se consigne.
- [ ] **Les quatre tables de level design** → [CHANTIERS.md](CHANTIERS.md) §2. Une ligne changée, on relance, on regarde.
- [ ] **Cinq candidats à `Décisions arrêtées`**, prêts mais non tranchés (`PLAN_energie.md` §9 bis) : dont *la décision spatiale est le jeu* — **toute décision doit avoir un lieu où elle est bonne et un lieu où elle est mauvaise**.

🖥️ **Trois questions se tranchent en dessinant l'écran, pas dans le vault** : **n°19** onze nombres permanents, est-ce que ça tient ? · **n°20** `Déclin et défaite` refuse la jauge globale que « la ville exposée » vient d'introduire · **n°21** comment le joueur comprend que l'économie commande son budget, alors que les deux sont loin l'un de l'autre à l'écran. → `Méta/Questions ouvertes.md`

⏸️ **La durée d'une partie est mise de côté volontairement** : pas de fin imposée, on joue jusqu'à l'ennui puis on recommence dans une autre direction. Hypothèse non fixée : ~20 ans en ~2 h. → `Décisions arrêtées` 14b · 14c

## Les commandes du quotidien

```
python "QGIS/scripts/apercu_carte.py" "QGIS/data/Prototype_qualifie.gpkg"        → la carte en PNG
python "QGIS/scripts/06_etat_zero.py"                                            → la ville entière dans une page HTML, 22 calques
python "QGIS/scripts/07_exporter_godot.py"                                       → alimenter la maquette 3D
python "QGIS/scripts/08_jouer.py" --toutes                                       → rejouer les parties du classeur
```

⚠️ **Chaîne à relancer dans l'ordre : 02 → 03 → 04 → 04b → 04c**, puis `07`. Le `02` repart de `Vallmar2.gpkg` et **écrase** `Prototype_qualifie.gpkg`, y compris `emprises` et `parcelles`. Tout script qui écrit a un mode `--blanc` qui calcule et n'écrit rien : **il tourne toujours d'abord**.

Le détail des onze scripts, leurs modes et leurs pièges → **`QGIS/README.md`** (§4 et §9). La maquette et ses touches (`V` `B` `R` `I` `1..4` `P`) → **`Godot/README.md`**.

**Deux machines** : Windows principal, Mac occasionnel. `git pull` en début de session, `git push` en fin. ⚠️ Les `.gpkg` ne se fusionnent pas — le travail QGIS se fait sur une machine à la fois. → `CLAUDE.md` §5

## Les deux dernières sessions

**2026-08-12 (session 16) — cinq corrections devant l'image.** Les barres et hangars deviennent des boîtes, les pointes sont coupées, le pavillonnaire fait enfin des maisons individuelles, les cœurs d'îlot sont plantés (440 sur 667), l'Ilse est creusée de 1,6 m et les ponts passent au-dessus. 🐞 Le vrai bug ne se voyait que sur l'image : `profondeur` était comptée depuis la rue et non depuis la façade — **tous** les pavillons de la ville faisaient 3,5 m de creux.

**2026-08-12 (session 15) — le prototype se réduit, et la ville se bâtit.** Deux règles levées (65, 66b), le prototype réduit à la ville et à l'énergie (66), trois franchissements au lieu de cinq (30c), les parcelles et les toits, et l'interface du toit posée. Le système énergie n'a pas été commencé, à la demande de l'auteur.

→ **[HISTORIQUE.md](HISTORIQUE.md)** pour les seize sessions.
