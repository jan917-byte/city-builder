# ETAT.md — où on en est

> Mis à jour par Claude en fin de session. Complément de [CLAUDE.md](CLAUDE.md).
> Source de vérité du design = le vault. Source de vérité de la carte = `QGIS/data/Prototype_qualifie.gpkg`. Ici, seulement des signets et l'avancement.

**Dernière mise à jour : 2026-08-11 (session 9)**

---

## Position dans le plan

🎯 **Phase actuelle : Wehrau à t0, crédible et regardable en 3D** — ✅ **la maquette existe et se lance** (`Godot/`) — avant toute décision, avant toute crue. → `Méta/Décisions arrêtées.md` 49 · `Technique/Génération procédurale.md`

L'ordre a changé le 2026-08-11 : le classeur a été écrit, puis on a constaté qu'une crue est **la perturbation d'un état** et que l'état n'existait pas. Le classeur reste dans `Classeur/`, il passe au mois 2.

**Style graphique : Townscaper** — volumes doux, palette pastel, zéro texture. On prend le rendu, pas la grille. → `Décisions arrêtées` 42b

**Wehrau à t0 : un peu pastel, et grise quand même.** Les bâtiments sont dans la palette dès la première image — c'est **le sol** qui est minéral, et il l'est parce qu'il l'est vraiment : 28 % d'imperméabilisé, 14 % de canopée, 4 587 places. La grisaille est une **proportion**, pas une teinte, donc ni cliché dystopique ni tout donné d'avance. → `Décisions arrêtées` 42c

🔄 **Le prototype n'est plus l'Altstadt de Vallmar.** C'est **Wehrau**, une petite ville qu'on voit en entier. Vallmar reste la ville du jeu complet, intacte dans le vault. → `Ville/Wehrau.md`

Ce que ça gagne : une ville entière, même petite, a **un amont et un aval**. Un quartier n'en a pas. L'injustice géographique entre dans le prototype.

**La carte est simulable.** Les cinq étapes du pipeline sont faites. 0,93 km² · 69 polygones · 178 tronçons · 13 sous-types · **17 exceptions** (cible : ~20) · 179 paires d'adjacence · **5 franchissements de l'Ilse**.

Chaque îlot porte 12 attributs, chaque tronçon 4 — et chacun répond à « quelle décision devient possible ? ». → `Technique/Géométrie et données.md`

> **Les trois contrôles qui comptent**
> — la ville privée de sa rivière tombe en **deux morceaux (45 et 11 îlots)** : la coupure est dans la géométrie
> — le réseau routier, lui, est **d'un seul tenant** : les cinq ponts existent enfin
> — l'**axe de transit sort tout seul** de l'affectation de trafic, sans qu'on l'ait désigné

## Prochaine action concrète

1. 🔴 **Les deux commandes qui écrivent dans le `.gpkg`, jamais lancées sur les données réelles.** Elles ont été validées sur une copie ; `CLAUDE.md` §3 réserve l'exécution sur les vraies données à l'auteur. Filet : le `.gpkg` est suivi par git, `git checkout -- QGIS/data/Prototype_qualifie.gpkg` défait tout.
   `python "QGIS/scripts/04_deriver_attributs.py"` → écrit la colonne `emplois`, débloque `05` et `06`
   `python "QGIS/scripts/04b_emprises_baties.py"` → écrit la couche `emprises` (le retrait de voirie). **Regarder la couche dans QGIS par-dessus `ilots` avant de continuer**
2. 🎯 **Regarder la maquette et trancher trois choses.** `python "QGIS/scripts/07_exporter_godot.py"` puis ouvrir `Godot/` dans Godot 4.7 (F5).
   · **la vallée se sent-elle à ×1 ?** touches `1` `2` `3` `4` — c'est le seul arbitrage qui ne se fait pas dans le vide
   · **le retrait est-il juste ?** 17,6 % de voirie, trois îlots de cœur ancien reculés de 22 m par le quai
   · **question n°16** (le raccord des voisins) : la maquette est son instrument, elle est prête
3. ☐ **Le critère de sortie**, et il compte plus que le reste : *est-ce que la 3D m'a montré quelque chose que la page HTML ne montrait pas ?* Si non, **on arrête la 3D et on reprend le classeur — et ce sera un bon résultat, pas un échec**. ⚠️ « Si j'ajoute des toits, j'ai changé de projet »
4. ☐ **Mois 2 : jouer le classeur.** Écrit et chiffré dans `Classeur/`, jamais joué — les valeurs sont posées, pas calibrées
5. ☐ Digérer le brainstorm importé du 2026-08-11 (refs / positionnement / UI) — 9 décisions et 7 questions à remonter

**Deux machines** : Windows principal, Mac occasionnel. `git pull` en début de session, `git push` en fin. ⚠️ Les `.gpkg` ne se fusionnent pas — le travail QGIS se fait sur une machine à la fois. → `CLAUDE.md` §5

**Boucle de contrôle** :
`python "QGIS/scripts/apercu_carte.py" "QGIS/data/Prototype_qualifie.gpkg"` → la carte
`python "QGIS/scripts/apercu_carte.py" "QGIS/data/Prototype_qualifie.gpkg" --adjacences` → le graphe, rouge = coupure, vert = on passe
`python "QGIS/scripts/apercu_carte.py" "QGIS/data/Prototype_qualifie.gpkg" --calque=alea` → n'importe quel attribut en dégradé (`charge`, `emprise_libre_m`, `densite`, `riverain`…)
`python "QGIS/scripts/04_deriver_attributs.py" --blanc` → tout recalculer sans rien écrire

`python "QGIS/scripts/06_etat_zero.py"` → **la ville entière dans une page** : 22 calques cliquables, les stocks à côté, un seul fichier HTML sans dépendance. C'est la boucle « je vois donc je corrige ».

`python "QGIS/scripts/04b_emprises_baties.py" --blanc` → le retrait de voirie sans rien écrire : contrôles, tableau des réparations, part de voirie.
`python "QGIS/scripts/palette.py"` → la palette : 13 sous-types, 9 familles, et la règle du sol vérifiée sur la plaie 19.

**Les outils** (dans `QGIS/scripts/`) :
`apercu_carte.py` la vue en PNG · `02_qualifier.py` le level design en listes de `fid` · `03_adjacences.py` le graphe · `04_deriver_attributs.py` la table de correspondance · `04b_emprises_baties.py` **le retrait de voirie, écrit la couche `emprises`** · `05_exporter_classeur.py` la carte en CSV · `06_etat_zero.py` la vue interactive · `07_exporter_godot.py` **la maquette 3D** · `palette.py` les couleurs · `01_champs_et_valuemaps.py` pour qualifier à la souris dans QGIS.

Seuls `02`, `03`, `04` et `04b` écrivent dans le `.gpkg`. Tous acceptent un chemin en argument — pour essayer un changement sur une copie avant de l'écrire.

⚠️ **Chaîne à relancer dans l'ordre** : 02 → 03 → **04 → 04b**. Le 02 repart de `Vallmar2.gpkg` et écrase `Prototype_qualifie.gpkg` — **y compris la couche `emprises`**.

**La maquette 3D** : `Godot/` — voir `Godot/README.md`. Touches `V` la vallée · `B` la barre de 1974 · `R` les rues à 20 et 22 m · `1..4` l'exagération verticale · `P` capture. Une touche par critère de réussite : on ne juge pas de mémoire.

## Ce qui bloque

**Rien.** La semaine 2 peut s'écrire.

⏸️ La durée d'une partie est **mise de côté volontairement** : pas de fin imposée, on joue jusqu'à l'ennui puis on recommence dans une autre direction. Hypothèse de travail non fixée : ~20 ans en ~2 h. → `Décisions arrêtées` 14b · 14c

🟠 À trancher pendant le mois 1 : d'où vient l'argent · le deuxième axe des fins · le premier clic.
🟢 Détendue : « quand tracer le deuxième quartier » — Wehrau teste déjà l'amont/aval.

→ `Méta/Questions ouvertes.md`

## En attente d'une décision de l'auteur

- [ ] **Le raccord des bâtiments voisins** (question n°16). 🟢 **L'instrument existe** : la maquette est construite et assume le non-raccord. À l'échelle de l'îlot la question ne se pose pas — un pâté plein n'a pas de voisin à coudre, et le retrait de voirie lui a donné des faces franches. Elle ne redeviendra vive qu'à la subdivision en parcelles. **Reste à confirmer à l'œil**
- [ ] **L'exagération verticale.** 9 m de relief sur 898 m de large, contre 27 m pour la barre. Touches `1..4` dans la maquette. Se tranche devant l'image, pas dans le vide — et une fois tranchée, se consigne
- [ ] **Wehrau est un dortoir** (question n°17). 0,16 emploi par habitant. On assume, ou on dessine du sol d'activité dans QGIS

- [x] ✅ **Wehrau porte ~5 350 habitants** (2026-08-11, prototype seulement — Vallmar garde ses 112 000) → `Décisions arrêtées` 13d
- [x] ✅ **Le jeu s'ouvre sur une crue, sur la rive gauche** (2026-08-11) → `Décisions arrêtées` 23b
- [ ] **Le grand ensemble de 1974 est à 200 m de l'eau**, pas « contre l'eau ». J'ai corrigé la phrase du vault ; l'autre option est de déplacer la barre. → n°14
- [ ] **Cinq franchissements pour la rivière**, alors que le vault en voulait deux au maximum. Ils sont maintenant typés dans les données. → n°12
- [ ] **Le nom.** « Wehrau » et la rivière « l'Ilse » sont mes propositions, marquées comme telles dans la note. Se renomment en une commande tant que rien n'est codé.
- [ ] **Relire deux fichiers de level design** : les listes de `fid` en haut de `QGIS/scripts/02_qualifier.py`, et la table de correspondance `TISSU` en haut de `QGIS/scripts/04_deriver_attributs.py` — treize lignes qui décident du comportement de toute la carte. Une ligne changée, on relance, on regarde.
- [ ] **Le tag `jeu/brightvale`** du brainstorm importé — nom de travail abandonné, autre projet, ou candidat à verser dans `Marketing et Steam` ?
- [ ] **Les conséquences de 5 350 habitants** sur trois équipements : le lycée devient une Realschule, la galerie de 1971 un supermarché, la barre de 1974 un petit Neubau. Acté dans la décision, pas encore écrit dans `Ville/Wehrau.md`.

## Ce que le brainstorm a donné

Le brainstorm du 2026-08-10 (`Brainstorming/…inondation-rive-droite.md`) a servi de plan pour l'étape 5 : ses trois idées transférables sont maintenant **dans les données**, pas dans une note.

| L'idée | Ce qui l'implémente |
|---|---|
| la **doctrine à seuil** (« je plante au-delà de X m ») | `emprise_libre_m`, qui a exigé que les largeurs de rue varient |
| le **modèle de trafic minimal** (charge → report → seuil) | `charge`, une affectation par plus court chemin en temps |
| « **rendre à l'eau** » | `alea`, `altitude_relative`, `position_fil_eau`, `rive` |

Reste en `brut` : le tableau `decisions` et les trois postures (reconstruire / adapter / rendre à l'eau), qui sont la semaine 2.

## Historique des sessions Claude

### 2026-08-11 (session 9) — la maquette existe
- 🔴 **Le fait qui a commandé toute la session** : les 69 îlots **pavent 99,75 % de l'emprise**, et les axes de rue tombent **exactement** sur leurs bords (0,0000 m d'écart, mesuré sur 83 segments). `largeur_m` était un attribut **sans lieu**. Extrudées telles quelles, les empreintes donnaient un bloc plein de 93 ha : le critère « trouver monstrueuses les rues à 20 et 22 m » était littéralement inobservable. → décision **32f**
- 🆕 **`04b_emprises_baties.py`** : l'îlot recule de la demi-largeur de la rue, la rue devient le négatif. Nouvelle couche `emprises` dans le GeoPackage (écrite en Python pur, en-tête GPKG encodé à la main — aucun GDAL dans ce dépôt). **69/69 anneaux simples, 76,5 ha bâtis, 17,6 % de voirie.** Le pic de mitre aux sommets réflexes envoyait un sommet de l'îlot 43 à **258 m** : limite de mitre + biseau, puis réparation de boucle. Contrôle final : **aucun sommet à plus de 5 cm hors de l'îlot d'origine**.
- 🆕 **`palette.py`**, qui **ferme la décision 33** : le `.qml` désigné comme référence couleur unique n'a jamais existé, et Godot ne sait pas le lire. 9 familles pour 13 sous-types. La règle `lerp(teinte, MINERAL, impermeabilise)` donne à la place du marché (îlot 19, `imperm = 1,00`) **exactement la couleur de la chaussée** — la plaie apparaît sans avoir été peinte. → **33b**
- 🆕 **`07_exporter_godot.py`** + **le projet `Godot/`**. Terrain continu rejoué depuis la formule de `04` (grille de 8 m, 16 440 sommets). Toute la géométrie est en Python ; Godot empaquette des tableaux et ne décide rien — l'« interface propre » de `Moteur et architecture:18` est **le contrat JSON**, pas une hiérarchie de classes.
- ✅ **Les trois critères sont atteints, vérifiés sur capture** : la barre de 1974 écrase ses voisines (le gris-bleu froid la rend étrangère au pastel), le quai à 22 m recule trois îlots de cœur ancien, la place-parking se lit comme une rue qui a enflé. Reste **la vallée** : 9 m sur 898 m, à arbitrer devant l'image avec les touches `1..4`.
- 🐞 **Trois pièges Godot 4.7, tous trouvés par l'expérience et pas par le raisonnement** — consignés dans `Godot/README.md` : les faces avant sont en sens **horaire** (le terrain entier était cullé, les bâtiments ne se voyaient que par leurs murs) · les couleurs de sommet sont en espace **linéaire** (tout ressortait délavé, et le contraste pastel/minéral avec) · `class_name` ne suffit pas en ligne de commande, d'où `preload()`.
- ⚠️ **Rien n'a été écrit dans le vrai `.gpkg`** — `CLAUDE.md` §3 réserve ça à l'auteur. Tout a été validé sur une copie. Les deux commandes sont l'action n°1.

### 2026-08-11 (session 8)
- ✅ **Le PC est raccordé — il l'était déjà.** Le diagnostic de la session 7 était faux : le dossier *est* un dépôt, avec `origin` correctement configuré sur `jan917-byte/city-builder`. Il était simplement **en retard de 5 commits**, en fast-forward propre. Ni clone frais, ni sauvegarde, ni rapatriement manuel — l'étape 3 était inutile. La procédure a été retirée de ce fichier.
- ⚠️ **Deux modifications locales traînaient sur le PC**, toutes deux sans valeur : Obsidian avait reformaté le tableau de `Décisions arrêtées` (padding des colonnes, zéro changement de fond) et `Direction artistique` avait perdu sa section « Clichés interdits » — que la version amont, entièrement réécrite depuis, conserve. **Mises en stash plutôt qu'en commit** : les committer aurait cassé le fast-forward et réintroduit une régression. Récupérables par `git stash list` / `git stash pop` si besoin, sinon `git stash drop`.
- 🟢 **Les `.gpkg` n'ont pas divergé** : suivis par git et non modifiés localement. Le point de vigilance « il faudra choisir une version » ne s'est pas matérialisé.
- ✂️ **Section « Clichés interdits » retirée de `Direction artistique`** (demande de l'auteur). Elle renvoyait à `Ton et règles d'écriture`, qui **ne porte pas** la liste des clichés visuels. La golden hour reste couverte par le tableau « Ce qui bouge, et ce qui ne bouge jamais » ; ⚠️ **« pas de tours-forêts » n'est plus consigné nulle part**, et « pas de Ghibli » ne survit que dans le brainstorm non digéré.
- 🔍 **Les emplois vérifiés avant écriture** : le commentaire de `04` décrit la règle par `fonction`, la table `TISSU` l'implémente par `sous_type` — les deux coïncident, tous les sous-types porteurs d'emploi sont bien `mixte` ou `industrie`. Recalcul en lecture seule sur le `.gpkg` : **879 emplois, 10,4 ha d'activité, 0,16 par habitant**. Conforme à ce qu'annonce la session 7. Reste à écrire la colonne.

### 2026-08-11 (session 7, suite)
- 🎯 **La phase du prototype est réécrite dans le vault** : la ville de t0 passe devant le système de décisions (décision 49), Godot entre au mois 1 pour le rendu seul (39b), **Townscaper** remplace Mini Motorways (42b), les emplois sont consignés (50). Deux questions neuves : le raccord des bâtiments (16) et le dortoir (17). Fichiers touchés : `Direction artistique`, `Génération procédurale`, `Plan 3 mois`, `Décisions arrêtées`, `Questions ouvertes`, `00 - Index`.
- ⚠️ **Les deux erreurs symétriques, tranchées par l'auteur (42c)** : une ville de départ charmante ne laisse rien à transformer ; une ville de départ grise et triste tombe dans le cliché dystopique interdit par 5 et 8. La sortie : **les bâtiments sont pastel, le sol est minéral**. Et la grisaille n'est pas un filtre, c'est une **proportion déjà présente dans les données** — 28 % d'imperméabilisé, 14 % de canopée, 4 587 places. Ce qui bouge en jeu est la part minérale du sol ; les teintes et la lumière ne bougent jamais.

### 2026-08-11 (session 7)
- 🔄 **L'ordre a été corrigé en cours de route.** On a d'abord chiffré la crue (`Classeur/`, 11 décisions, 37 effets), puis constaté qu'une crue est une **perturbation d'un état** — et que l'état n'existait pas. Retour à l'état zéro. Le classeur reste, il repassera devant quand l'état sera stable.
- ❌ **L'arbre de décision (Miro) écarté comme format de travail**, gardé comme croquis de complétude par happening. Un arbre ne porte ni le délai, ni le lieu, ni les liens `ouvre`/`ferme`. Le format retenu : des CSV `;` dans le dépôt — jamais de `.xlsx`, c'est un binaire qui ne fusionne pas.
- 🆕 **`06_etat_zero.py`** : la ville entière dans **une page HTML autonome**, 22 calques cliquables, les stocks calculés à côté. Répond à « quand je vois, je corrige ».
- 🆕 **Les emplois** : 7ᵉ colonne de `TISSU`, uniquement sur `industrie` + `mixte`. **878 emplois pour 5 353 habitants — 0,16 par habitant.** Ce n'est pas un coefficient trop bas : la ville n'a que 10,4 ha d'activité sur 38 ha bâtis. **Wehrau est un dortoir**, ce qui explique l'axe de transit saturé et les 0,86 place de parking par habitant. Pour changer ça il faut dessiner du sol d'activité, pas régler un chiffre.
- 🐞 **`HABITANTS_VAULT` valait encore 18 000** (Vallmar) : le contrôle de fin de `04` criait à 30 % d'écart depuis que le prototype est Wehrau. Remis à 5 350.
- 🆕 **`05_exporter_classeur.py`** : la carte en CSV (69 · 178 · 179 lignes) pour que le classeur ne devienne pas une quatrième source de vérité.

### 2026-08-11 (session 6)
- 🎯 **Trois questions fermées par l'auteur** : population de Wehrau (~5 350, prototype seulement) · **crue d'ouverture sur la rive gauche** · **capital politique = un chiffre**. Consignées dans `Décisions arrêtées` (13d, 23b, 16b), fermées dans `Questions ouvertes` (13, 15, 2), répercutées dans `Wehrau.md`, `Ressources.md` et `00 - Index`.
- 🆕 **Système des milestones** (`Systèmes/Milestones.md`, décision 9b) : des jalons **cumulables**, pas des fins — zéro voiture, ville-éponge, autonomies. Ce qui les rend durs est un **coût d'opportunité**, pas une interdiction : *la rareté est dans le calendrier, pas dans les règles*. Conséquence notée dans `Ressources` : un capital politique en chiffre unique règle le **rythme**, jamais la **direction** — l'arbitrage vient du sol et du temps.
- ⏸️ **La durée d'une partie est reportée, pas tranchée** (14b, 14c) : **pas de fin imposée**, on joue jusqu'à l'ennui puis on recommence dans une autre direction. Les milestones deviennent le marqueur de progression. Hypothèse de travail assumée : ~20 ans en ~2 h.
- **Brainstorm importé** dans `Brainstorming/2026-08-11_brainstorm_refs-positionnement-ui.md` — positionnement, veille concurrentielle, DA et UI. Déposé brut avec un encart de provenance : il vient d'un autre vault, son vocabulaire diffère (table de correspondance dans l'encart). Non digéré.
- **Le vault rattrape la réalité** : `00 - Index` et `Plan 3 mois` annonçaient encore l'adjacence et les attributs dérivés comme « à faire » — faits depuis la session 3. Semaine 1 marquée bouclée.
- **Travail sur deux machines assumé** : `CLAUDE.md` §5 réécrite (elle décrivait un environnement Windows sans dépôt git), `README.md` corrigé (il s'intitulait « Vallmar » alors que le prototype est Wehrau), `.gitattributes` ajouté — LF partout, `.gpkg` marqués binaires. Vérifié : aucune renormalisation provoquée, le dépôt était déjà propre.

### 2026-08-10 (session 5)
- **Restructuration du dépôt** (recommandations de la session) : doublon `Vault - Jeu urbanisme/Production/ETAT.md` supprimé ; skill projet déplacé `SKILLS/` → `.claude/skills/solo-dev-systems/` ; `QGIS/` scindé en `scripts/`, `data/`, `rendus/` (préviews régénérables gitignorées, chemins des scripts recâblés sur `data/` et `rendus/`) ; `README.md` racine ajouté. Les scripts tournent (`apercu_carte.py` et `04 --blanc` vérifiés).

### 2026-08-10 (session 4)
- **Dépôt GitHub créé** : [jan917-byte/city-builder](https://github.com/jan917-byte/city-builder) (privé). 60 fichiers, commit initial. `.gitignore` exclut `__pycache__`, config locale Claude, raccourcis Windows, `workspace.json` Obsidian.

### 2026-08-10 (session 3)
- **Étape 5 faite** : `04_deriver_attributs.py`, 12 attributs d'îlot + 4 de rue, tous justifiés par une décision nommée. Table de correspondance de 13 lignes.
- Le dry-run a sorti **quatre défauts réels**, tous corrigés : aucun pont dans le réseau (5 franchissements typés comme des rives) ; graphe de rues construit sur les extrémités au lieu des sommets ; largeurs constantes rendant tout seuil inopérant ; axe droit se trompant de rive sur les méandres de l'Ilse.
- Nouveau mode `--calque=<champ>` dans `apercu_carte.py` : voir n'importe quel attribut en dégradé.
- **Trois questions ouvertes neuves** (13, 14, 15), dont deux à trancher avant la semaine 2.

### 2026-08-10 (sessions 1 et 2)
- Encodage réparé (11 dossiers/fichiers renommés), `CLAUDE.md` et ce fichier mis en place, icône du dossier et raccourci Obsidian.
- **Qualification complète de la carte** : 69 îlots, 178 tronçons, quatre plaies de 1965 placées consciemment. Trois scripts écrits, aucun n'écrit dans la source. Table d'adjacence construite. **Vault** : note neuve `Ville/Wehrau.md`, douze décisions révisées dans `Décisions arrêtées`, **0 wikilink cassé**.

*(`Méta/Journal.md` reste vierge de ma main — c'est le fichier de l'auteur.)*
