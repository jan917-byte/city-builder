# ETAT.md — où on en est

> Mis à jour par Claude en fin de session. Complément de [CLAUDE.md](CLAUDE.md).
> Source de vérité du design = le vault. Source de vérité de la carte = `QGIS/data/Prototype_qualifie.gpkg`. Ici, seulement des signets et l'avancement.

**Dernière mise à jour : 2026-08-12 (session 14)**

---

## Position dans le plan

🎯 **Phase actuelle : une ville crédible et belle.** L'ordre a changé une seconde fois le 2026-08-12 → `Décisions arrêtées` **51**. D'abord Wehrau qu'on a envie de regarder — **parcelles, toits, trafic, sol**. *Ensuite* chaque indicateur, système et décision repris **un par un**, plus en lot de onze.

Ce que ça déplace : 49 mettait déjà la ville avant les décisions, mais visait une maquette de masses et posait le seuil à « sentir le lieu ». Le seuil devient **« avoir envie de la regarder, et croire qu'on y habite »**. Ce qu'on regarde aujourd'hui, c'est encore **63 pâtés pleins**.

⚠️ **La limite « une semaine, pas de toits » tombe** — 51 fait entrer les toits dans le plan. Le risque qu'elle couvrait, lui, est intact : la 3D avance toujours parce que chaque amélioration se voit. Ce qui la remplace est une règle de production, pas une date → **52** : *si je devais en faire 200, est-ce que je tiendrais ?* Si non, on n'écrit pas l'asset, on écrit le générateur.

✅ **La boucle est dans Godot** : on clique un îlot ou une rue, on lit sa fiche, on décide de planter un alignement, et vingt ans passent — les arbres poussent, la canopée monte, la surchauffe baisse, le budget encaisse. → `Godot/README.md` · `Décisions arrêtées` **39c**

Le classeur reste le **banc d'essai** — l'endroit où changer d'avis coûte une soirée. Un contrôle de recoupement compare les deux moteurs à chaque fois, sinon la duplication ment sans qu'on le sache.

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

### Phase A — la ville crédible et belle

1. 🔴 **Un passage QGIS, sous Windows, AVANT le générateur de parcelles** — `02` écrase le `.gpkg`, donc toute retouche de carte se fait maintenant ou coûte une chaîne complète plus tard. Une seule tâche : **supprimer deux des cinq franchissements** (tronçons 136, 145, 168, 169, 171 → `Décisions arrêtées` **30c**). Trois contrôles après : le réseau routier reste d'un seul tenant (`03`), le faubourg de rive gauche garde un accès qui n'est pas le quai, et **l'axe de transit peut s'être déplacé** — `--calque=charge` se regarde
2. 🎯 **La subdivision de l'îlot en parcelles.** Le point dur du pipeline, **2 à 4 semaines** annoncées, et ce qui sépare 63 pâtés d'une ville. ✅ **Ses deux verrous sont levés** : la parcelle est une **partition** de l'emprise, donc le mitoyen sort de la géométrie (**61**), et la parcelle reste l'entité persistante (**35**). 🔴 **Le premier point à vérifier dans le code** : la partition ne doit pas se rejouer quand une seule parcelle change — sinon on ré-effondre le voisinage à chaque clic, comme Townscaper, et 35 tombe avec. → `Technique/Génération procédurale.md`
3. ☐ **Les toits et les gabarits**, une fois les parcelles là. Une recette, pas des assets. Y compris le **joint en toiture** entre deux parcelles de hauteurs différentes — c'est tout ce que 61 laisse à faire
4. ☐ **Le trafic.** ✅ **Tranché : un flux agrégé, plus quelques véhicules figurés qui ne calculent rien** (**62**). Jamais de graphe navigable ni de file d'attente au carrefour. Le critère se juge à l'écran : *une rue à `charge = 1,00` doit être désagréable à regarder* — si le flux est trop propre, on ajoute de l'encombrement à l'arrêt, pas de la navigation
5. ☐ **Le sol** — un matériau paramétré par `impermeabilise`, `canopee` et l'usure. Trois curseurs qui sont déjà des attributs.
6. ☐ **La lumière.** ⚠️ **La vallée ne se lit à aucune des quatre exagérations** (constaté le 2026-08-12). 9 m sur 898 m en axonométrie à angle fixe : le facteur n'y peut rien, c'est l'ombre ou la caméra.

### Phase B — un indicateur, un système, une décision à la fois

🆕 **La phase B a maintenant sa liste.** Les indicateurs globaux sont définis : **sept**, plus les deux ressources. → `Systèmes/Indicateurs globaux.md` · `Décisions arrêtées` **53 à 59**

Trois contrôles en découlent, à faire dans le classeur avant d'écrire quoi que ce soit dans Godot :

7. ☐ 🔴 **Calibrer les deux formules de budget** — recettes ∝ `logements`, charges ∝ mètres de voirie. Le contrôle est nommé : *une stratégie de densification pure ne doit pas s'autofinancer*, sinon le piège de l'exponentielle est rouvert pour de bon. C'est aussi ce qui doit faire **mordre** un budget qui ne mord jamais (418 pts sur 500, +152 de solde, aucune décision refusée).
8. ☐ **Vérifier que chaque indicateur a un antagoniste.** Ceux qui n'en ont pas sont mal conçus — les bornes sont la ceinture, le frein ce sont les antagonismes.
9. ☐ **Trois valeurs à t0 manquent** : la ville exposée, le CO2, la desserte. Calculables sur les attributs existants, côté Windows.
9bis. ☐ 🔴 **Repondérer les trois moyennes** — `canopee_moy` et `impermeabilise_moy` par la **surface**, `riverain_moy` par la **population** (ce qui supprime au passage le cas particulier « îlots habités seulement »). À faire dans `08_jouer.py` **et** dans `ville.gd`, puis refaire le contrôle de recoupement. Les chiffres du classeur bougeront. → `Décisions arrêtées` **63**
9ter. ☐ **`stationnement` porte deux sens** — part de surface sur l'îlot, places sur rue sur le tronçon — et « l'emprise voiture » agrège déjà les deux (4 587 places **et** 17,6 % de voirie). À renommer avant d'écrire la formule de l'indicateur, sinon quelque chose les additionnera.

10. ☐ **Trois corrections que le classeur a sorties**, à reprendre quand on arrivera sur les décisions concernées :
   · 🔴 **`largeur_m >= 20`, la cible de D05, rate quatre des cinq rues les plus chargées.** Les tronçons 13, 21, 54 et 55 font **18 m** et portent 0,87 à 1,00 de charge. « Retirer la voiture de l'axe de transit » n'attrape que le tronçon 11. Deux mètres de seuil décident si la décision existe
   · 🔴 **La montée de D07 est de 60 mois** : sur l'horizon d'une partie, l'arbre ne reprend jamais ses mètres à la noue. La concurrence arbre/noue, qui est le sujet de D07 et D08, ne se joue pas
   · ✅ ~~**Le budget ne mord jamais**~~ — **traité par la décision 59** : deux formules (recettes ∝ `logements`, charges ∝ mètres de voirie). Reste à calibrer, c'est le point 7
11. ☐ **Trois chiffres de D07 attendent ton œil**, tous commentés dans le code et listés dans `Godot/README.md` : la **surchauffe** (`3,5 × imperméabilisé − 2,5 × canopée`, +1,59 °C à t0), le **+0,25 de canopée** (alors que la canopée d'une rue plafonne à 0,18 dans les données), et **`CANOPEE_ALIGNEMENT_MAX`** (rendu seulement).
12. ☐ **La deuxième décision dans Godot.** La candidate est **D06 supprimer le stationnement** : c'est elle qui libère l'emprise de D07 et D08, donc c'est elle qui rend la chaîne intéressante. Il ne manque qu'une entrée dans `DECISIONS` de `chantiers.gd` et une portée `voisins` pour le report de charge.
13. ☐ **`confort_ete` n'existe pas dans le `.gpkg`** et c'est la seule variable de D10, seule décision du thème `energie`. `08_jouer.py` la crée à 0 et le signale ; Godot y répond par la **surchauffe**, dérivée du sol. Soit on la dérive dans `04`, soit D10 s'exprime autrement.

### 🧪 En travers : le test « énergie seule »

🆕 **Un plan de session écrit le 2026-08-12 depuis le Mac, à exécuter sous Windows → [PLAN_energie.md](PLAN_energie.md).** Le jeu réduit à un seul thème : quatre nombres (consommation, production locale, achat, CO2), une décision (poser des panneaux, par îlot), tout le reste masqué mais intact. La question testée : *est-ce qu'une décision qui rapporte de l'argent fait un jeu ?*

🎯 **Le plan a changé de centre de gravité en cours d'écriture, sur un apport de l'auteur** : ce qu'on teste n'est pas « une décision qui rapporte de l'argent », c'est ***choisir où investir, et quand*** — *« pour être efficient, il faut investir au bon endroit au bon moment, la base du métier »*. Deux conséquences écrites dans le plan §6 bis : montrer la rentabilité risque de **résoudre** le jeu (on trie du plus vert au plus rouge), donc il faut **deux cartes qui pointent en sens inverse** — l'argent vers les hangars, la légitimité vers le centre — et **le temps qui déplace la carte** (panneau −6 %/an, énergie +2 %/an, donc « pas encore » devient une réponse valide sur les seuls îlots au-delà de ~17 ans).

Deux choses à savoir avant de le lancer : il **n'écrit rien dans le `.gpkg`** (seul `07` est relancé, en lecture) donc il ne concurrence pas le passage QGIS du point 1 ; et il laisse **trois décisions à l'auteur** — la régie municipale (à qui appartiennent les panneaux), l'ajout du capital politique au périmètre (sans lui le test mesure un tri), et **les quartiers de Wehrau n'ont pas de nom**, ce qui empêche la phrase « c'est là qu'il faut commencer ».

🚧 **La vue chantiers entre au plan** (§6 ter), également sur un apport de l'auteur : un calque de ce qui est **en train** de se faire, et une barre d'état au clic sur l'objet. Ce que ça règle : *les chantiers en cours n'ont pas leur place dans le bandeau du tout* — **trois temps, trois formes**, le bandeau le passé, les ressources le futur, la carte le présent. Deux conséquences : la barre a **deux segments** (le délai n'est pas la montée, et « il ne se passe rien pendant six mois » est une vérité à enseigner), et une décision porte désormais **trois durées** — délai · travaux · maturation — sans quoi 64 tronçons resteraient « en travaux » pendant les cinq ans de croissance d'un arbre. Garde-fou écrit : **jamais une liste de chantiers**, sinon c'est un écran de gestion de projet.

🆕 **Quatre candidats à `Décisions arrêtées`, prêts mais non tranchés** (plan §9 bis) : *la décision spatiale est le jeu* — corollaire opérationnel, **toute décision doit avoir un lieu où elle est bonne et un lieu où elle est mauvaise** — et *le capital politique se regagne par la visibilité du chantier*, qui fermerait un point ouvert de `Indicateurs globaux`.

### Reste à faire, sans urgence

14. ☐ **Regarder `emprises` dans QGIS par-dessus `ilots`** — les écritures dans le `.gpkg` sont faites (`emplois` = 878, `emprises` = 69 lignes, vérifiées en lecture seule), mais le contrôle à l'œil ne l'est pas. `04b` signale quatre réparations de boucle : îlots **55, 13, 16, 21**.
15. ☐ Digérer le brainstorm importé du 2026-08-11 (refs / positionnement / UI) — 9 décisions et 7 questions à remonter

**Deux machines** : Windows principal, Mac occasionnel. `git pull` en début de session, `git push` en fin. ⚠️ Les `.gpkg` ne se fusionnent pas — le travail QGIS se fait sur une machine à la fois. → `CLAUDE.md` §5

**Boucle de contrôle** :
`python "QGIS/scripts/apercu_carte.py" "QGIS/data/Prototype_qualifie.gpkg"` → la carte
`python "QGIS/scripts/apercu_carte.py" "QGIS/data/Prototype_qualifie.gpkg" --adjacences` → le graphe, rouge = coupure, vert = on passe
`python "QGIS/scripts/apercu_carte.py" "QGIS/data/Prototype_qualifie.gpkg" --calque=alea` → n'importe quel attribut en dégradé (`charge`, `emprise_libre_m`, `densite`, `riverain`…)
`python "QGIS/scripts/04_deriver_attributs.py" --blanc` → tout recalculer sans rien écrire

`python "QGIS/scripts/06_etat_zero.py"` → **la ville entière dans une page** : 22 calques cliquables, les stocks à côté, un seul fichier HTML sans dépendance. C'est la boucle « je vois donc je corrige ».

`python "QGIS/scripts/04b_emprises_baties.py" --blanc` → le retrait de voirie sans rien écrire : contrôles, tableau des réparations, part de voirie.
`python "QGIS/scripts/palette.py"` → la palette : 13 sous-types, 9 familles, et la règle du sol vérifiée sur la plaie 19.

`python "QGIS/scripts/08_jouer.py" --toutes` → **les parties jouées** : les 60 mois de chaque fichier de `Classeur/parties/`, un `_resultat.csv` par partie, et `QGIS/rendus/parties.html` — la carte à n'importe quel mois, le mode **écart au mois 0**, et les courbes superposées. Le contrôle de fin vérifie que le mois 0 calculé retrouve `partie.csv`.

**Les outils** (dans `QGIS/scripts/`) :
`apercu_carte.py` la vue en PNG · `02_qualifier.py` le level design en listes de `fid` · `03_adjacences.py` le graphe · `04_deriver_attributs.py` la table de correspondance · `04b_emprises_baties.py` **le retrait de voirie, écrit la couche `emprises`** · `05_exporter_classeur.py` la carte en CSV · `06_etat_zero.py` la vue interactive · `07_exporter_godot.py` **la maquette 3D** · `08_jouer.py` **le moteur du classeur** · `palette.py` les couleurs · `01_champs_et_valuemaps.py` pour qualifier à la souris dans QGIS.

Seuls `02`, `03`, `04` et `04b` écrivent dans le `.gpkg`. Tous acceptent un chemin en argument — pour essayer un changement sur une copie avant de l'écrire.

⚠️ **Chaîne à relancer dans l'ordre** : 02 → 03 → **04 → 04b**. Le 02 repart de `Vallmar2.gpkg` et écrase `Prototype_qualifie.gpkg` — **y compris la couche `emprises`**.

**La maquette 3D** : `Godot/` — voir `Godot/README.md`. Touches `V` la vallée · `B` la barre de 1974 · `R` les rues à 20 et 22 m · `1..4` l'exagération verticale · `P` capture. Une touche par critère de réussite : on ne juge pas de mémoire.

**Claude lance Godot lui-même** depuis le 2026-08-12 : `.mcp.json` déclare le serveur MCP `@coding-solo/godot-mcp` — lancer le projet, lire la console, monter des scènes. → `Godot/README.md` § « Claude lance Godot lui-même » · `CLAUDE.md` §5 bis pour la variante Mac.

## Ce qui bloque

**Rien.** La semaine 2 peut s'écrire.

⏸️ La durée d'une partie est **mise de côté volontairement** : pas de fin imposée, on joue jusqu'à l'ennui puis on recommence dans une autre direction. Hypothèse de travail non fixée : ~20 ans en ~2 h. → `Décisions arrêtées` 14b · 14c

🟢 **Cinq questions closes le 2026-08-12** — n°16 (le mitoyen par construction), n°18 (le trafic en flux), n°17 (le dortoir assumé), n°12 (trois ponts), n°14 (la barre reste). Plus le nom : **Wehrau** et l'**Ilse** sont arrêtés (13f).
🟠 À trancher pendant le mois 1 : ~~d'où vient l'argent~~ ✅ (n°3 close le 2026-08-12) · le deuxième axe des fins · le premier clic.
🖥️ **Trois questions qui se tranchent en dessinant l'écran, pas dans le vault** : **n°19** onze nombres permanents, est-ce que ça tient ? · **n°20** `Déclin et défaite` refuse la jauge globale que « la ville exposée » vient d'introduire · **n°21** comment le joueur comprend que l'économie commande son budget, alors que les deux sont loin l'un de l'autre à l'écran.

→ `Méta/Questions ouvertes.md`

## En attente d'une décision de l'auteur

- [ ] **L'exagération verticale.** 9 m de relief sur 898 m de large, contre 27 m pour la barre. Touches `1..4` dans la maquette. Se tranche devant l'image, pas dans le vide — et une fois tranchée, se consigne
- [ ] **Lesquels des cinq ponts sautent** (30c tranche le nombre, pas les fid). Se choisit sur la carte, sous trois contraintes → point n°1

- [x] ✅ **Le raccord des bâtiments** (n°16) — **la parcelle est une partition de l'emprise**, le mitoyen sort de la géométrie → `Décisions arrêtées` 61
- [x] ✅ **Le trafic** (n°18) — **un flux, plus quelques véhicules figurés** → 62
- [x] ✅ **Wehrau est un dortoir** (n°17) — assumé, aucun sol d'activité dessiné → 50b
- [x] ✅ **Trois franchissements, pas cinq** (n°12) → 30c
- [x] ✅ **La barre de 1974 reste sur l'îlot 32** (n°14) — la phrase du vault était fausse, pas la carte → 13e
- [x] ✅ **Le nom** — **Wehrau** et l'**Ilse** sont arrêtés → 13f
- [x] ✅ **Wehrau porte ~5 350 habitants** (2026-08-11, prototype seulement — Vallmar garde ses 112 000) → `Décisions arrêtées` 13d
- [x] ✅ **Le jeu s'ouvre sur une crue, sur la rive gauche** (2026-08-11) → `Décisions arrêtées` 23b
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

### 2026-08-12 (session 14) — un indicateur vit à deux échelles
- 🔗 **Ce que l'auteur a apporté et qui n'était nulle part** : les indicateurs existent **globalement et localement** (îlot, tronçon), et les deux sont liés. Le vault avait la règle 53 (« aucun chiffre global sans son calque ») mais **pas la règle de composition** — comment on passe d'un niveau à l'autre. Formulation retenue : **l'indicateur local et le calque sont le même objet vu de deux côtés**, comme le bandeau et les milestones (57). → **63**
- ⚠️ **Correction apportée à l'énoncé de départ** : « le local est un % du total » est vrai pour les **stocks** (population, places, CO2, m² de toit), faux pour les **taux** (canopée, imperméabilisé, surchauffe, riverain). Un îlot à 40 % de canopée ne détient pas 40 % de la canopée de la ville.
- 🐞 **Le défaut de session 10 était exactement ça** : `canopee_moy` et `impermeabilise_moy` en moyennes simples par îlot, où un champ de 50 ha pèse autant qu'un parc de 0,4 ha. Il était consigné comme un choix ; il devient une **dette à rembourser** (point 9bis).
- ⚖️ **Tranché par l'auteur** : *un taux se pondère par ce dont il est le taux* — surface pour le sol, population pour les gens, mètres de voirie pour la rue. Gain non prévu : `riverain_moy` n'a plus besoin de son cas particulier « îlots habités seulement », un îlot inhabité pèse zéro tout seul. **La règle absorbe l'exception.**
- ⚖️ **Tranché aussi** : la **fiche reprend l'ordre et les icônes du bandeau** — un seul vocabulaire, et l'écart à t0 se lit aux deux échelles. → **63b**
- 🔴 **Une collision de nom sortie au passage** : `stationnement` désigne la part de surface en parking sur un îlot **et** les places sur rue sur un tronçon, alors que « l'emprise voiture » agrège déjà les deux. À renommer avant que l'indicateur ait une formule (point 9ter).

### 2026-08-12 (session 13) — la phase A est débloquée en une séance
- 🟢 **Cinq questions closes, dont les deux qui bloquaient le générateur de parcelles.** Aucune ne demandait de code : elles demandaient un arbitrage.
- 🎯 **n°16 se règle par la méthode, pas par un travail de couture** — *la parcelle est une **partition** de l'emprise de l'îlot*. Le générateur découpe au lieu de poser des formes dans un vide, donc deux voisines partagent une arête **exactement**. Ce qui a tranché : 20 îlots de `maisons_de_ville` et 12 de `coeur_ancien` — le mitoyen n'y est pas un raccord à faire, c'est **la forme urbaine**. Ce qu'il reste est le **joint en toiture**, et il tombe sur un chantier déjà prévu. Réversible dans un seul sens : écarter les parcelles redonne le non-raccord, l'inverse non. → **61**
- 🔴 **Le piège nommé avec** : la partition ne doit pas se rejouer quand une seule parcelle change, sinon on ré-effondre le voisinage à chaque clic comme Townscaper — et la décision 35 tombe avec. C'est le premier point à vérifier dans le code.
- 🚗 **n°18 : un flux, pas des agents** — plus une poignée de véhicules figurés qui ne calculent rien et dont la densité se lit sur `charge`. *Le spectacle est la transformation urbaine, pas la circulation.* **Critère jugeable à l'œil** : une rue à `charge = 1,00` doit être **désagréable à regarder** ; si le flux est trop propre, la marge est l'encombrement à l'arrêt, **pas** la navigation. → **62**
- 🏭 **n°17 : le dortoir est assumé**, 0,16 emploi par habitant, aucun sol d'activité dessiné. Gain : l'axe saturé et les 0,86 place par habitant deviennent des **symptômes**, pas des anomalies — et les deux friches deviennent **le seul levier d'emploi de la ville**. Coût assumé, écrit : *une ville sans travail est une ville sans matin*, le mouvement du matin sort de la carte — cohérent avec 62. → **50b**
- 🌉 **n°12 : trois franchissements, pas cinq.** À cinq, la rivière ne coupe plus rien et « ajouter une passerelle » cesse d'être une décision. Opération propre côté données : les îlots ne se touchent jamais par-dessus l'eau. ⚠️ **Lesquels sautent n'est pas tranché** — trois contraintes, dont une non évidente : **l'affectation de trafic se rejoue, l'axe de transit peut se déplacer**. → **30c**
- 🏢 **n°14 : la barre de 1974 reste sur l'îlot 32.** C'était la phrase du vault qui était fausse, pas la carte. Ce qui l'expose n'est pas la proximité de l'eau mais d'être **en bout de chaîne** — et c'est un meilleur récit. → **13e** · **13f** : les noms Wehrau et Ilse sont arrêtés, la fenêtre du renommage gratuit se fermait avec le code.
- ⚠️ **Ce que ça met à l'ordre du jour immédiat** : un passage QGIS sous Windows **avant** le générateur, puisque `02` écrase le `.gpkg`. Une seule tâche, deux ponts.

### 2026-08-12 (session 12) — les indicateurs globaux, et l'argent enfin tranché
- 🎯 **Une règle qui commande tout le bandeau** : ***aucun chiffre global sans son calque***. Le chiffre dit *que* ça bouge, le calque dit *où*. Elle a taillé **dix-neuf indicateurs candidats à sept**, par un critère unique — un chiffre dont on ne saurait pas dessiner la carte est une jauge qu'on optimise, pas une invitation à regarder la ville. Motif de fond : un indicateur global est une **moyenne**, et une moyenne efface l'injustice géographique que Wehrau porte. → `Décisions arrêtées` **53**
- 🆕 **Note système neuve** : `Systèmes/Indicateurs globaux.md` — les sept, leurs calques, leurs bornes, et le tableau de ce qui pousse contre quoi.
- 💰 **La plus vieille question structurante tombe : d'où vient l'argent (n°3).** Deux formules — **recettes ∝ `logements`, charges ∝ mètres de voirie** — au lieu d'une économie simulée. Le déclencheur est un fait mesuré en session 10 : **le budget ne mordait jamais**. Récupère au passage les **charges d'entretien du réseau**, orphelines depuis que l'économie a été écartée. ⚠️ Rouvre le piège de l'exponentielle : contrôle nommé, *une densification pure ne doit pas s'autofinancer*. → **59**
- 🔗 **Le bandeau et les milestones sont le même objet.** En cherchant à borner les indicateurs, on trouve que **cinq des sept maxima sont des jalons qui ont déjà un nom** — zéro voiture, zéro carbone, autonome en énergie, ville-éponge, « personne n'a été chassé ». Borner, c'est nommer l'état où l'indicateur sature. Ferme deux sous-questions de `Milestones.md` : zéro carbone en compteur permanent, et **quand les jalons s'affichent** (en pointillés, révélés à l'approche). → **57**
- 🧪 **Une manœuvre réutilisable, sortie deux fois** : *une formule sur des attributs existants n'est pas une sous-simulation.* Elle a sauvé le CO2, le renouvelable **et** le budget — trois choses qui semblaient exiger une économie. Le renouvelable devient « la part des toits qui produit », donc de la géométrie, et il tombe sur le chantier des toits déjà prévu. → **56**
- ⚫ **Le carbone gris est assumé** : démolir-reconstruire émet un gros coup immédiat. Ça rend **« adapter » mécaniquement défendable face à « reconstruire »** — deux des trois postures déjà adossées à `alea`. L'indicateur ne mesure pas seulement, il rend chiffrable un dilemme qui existait déjà. ⚠️ Risque symétrique : trop lourd, il dit « ne touche à rien ».
- ❌ **Toute l'économie écartée** — chômage, revenu, productivité, imposition, loyer, vacance. Aucune donnée derrière, et mises bout à bout elles font *Cities: Skylines*, contre le but affiché. Le social passe par `riverain`. → **55**
- 🖥️ **Ressources et indicateurs ne se dessinent pas pareil** : compteurs contre barres. *Les indicateurs regardent en arrière, les ressources en avant.* Le budget passe à **trois nombres** — ce que tu as, **ce qui est engagé**, ce qui est libre — parce que le code paie étalé quand le capital est comptant. → **58**
- 🟠 **Ce que ça laisse ouvert, deux questions neuves** : **n°19** — onze nombres permanents à l'écran, alors que le seuil défendu en début de séance était de six ; trois élargissements successifs, chacun défendable seul, aucun regardé avec les autres. **n°20** — `Déclin et défaite` refuse explicitement la jauge globale (*« une note de résilience sur 100 ne dit rien »*), que l'indicateur « ville exposée » vient d'introduire. Résolution proposée, non confirmée : la règle 53 la lève, puisque la barre est appariée à la carte.
- 💡 **Puis l'économie revient par une autre porte, et en mieux — décision 60.** Le joueur ne voit que **deux choses** : une **barre sans nombre** (l'économie va bien ou mal) et son **budget annuel**, qui en dépend. Le calcul est caché. Ce que ça gagne : ***un état non chiffré ne s'optimise pas*** — tout le piège *Democracy 4* tient au pourcentage. Même geste que le capital politique en un chiffre. Ça **révise 59** au lieu de s'y ajouter : les deux formules décrivent ce que le joueur **maîtrise**, l'état de l'économie est le **multiplicateur qu'il ne maîtrise pas**. Moteur **mixte** (cycle exogène lent × part endogène modeste), place dans le **bandeau de contexte**.
- 🔴 **Deux garde-fous écrits avec — 60b.** ***Formule cachée ≠ causalité cachée*** : que le joueur ne voie pas l'équation, très bien ; qu'il ne puisse pas dire pourquoi son budget a baissé, non. Quand la barre bouge, **quelque chose le dit en une phrase et sans chiffre**. Et l'interdit explicite : **l'économie cachée ne sert jamais à ajuster la difficulté** (21) — un état qui dérive sans être vu est le terrain rêvé de la difficulté adaptative, et ça arrivera par accident si ce n'est pas nommé.
- ❓ **Question n°21, posée par l'auteur** : la barre est dans le contexte, le budget avec les ressources — **ils sont loin l'un de l'autre**, donc comment le joueur comprend-il le lien ? Trois pistes non tranchées, dont la plus forte : **le budget est voté une fois par an, pas subi** — ce qui donnerait au passage un battement annuel à un jeu qui n'a pas de tours.
- ✅ **Le brainstorm est digéré le jour même** — neuf décisions remontées, trois questions ouvertes, six notes touchées. Le fichier reste en archive : **les options écartées n'existent nulle part ailleurs.**

### 2026-08-12 (session 11) — Frostpunk et Democracy 4 sortent du brainstorm
- 🎮 **Deux jeux entrent comme références durables**, répartis là où ils portent plutôt que listés au même endroit : `Systèmes/Décisions.md` (inertie des effets, échelle du district, capital politique — et ce qu'on **ne** reprend pas : le curseur d'intensité de D4, le conseil qui vote de FP2), `Technique/Direction artistique.md` (la jauge en matière à voler ; ⚠️ l'UI blanche sur neige blanche, risque direct avec une palette pastel), `Vision/Ton et règles d'écriture.md` (Frostpunk = le repoussoir du cynisme, mais son livre des lois est à prendre), `Vision/Pièges connus.md` (D4 en cas d'école des jauges d'humeur).
- ⚠️ **Le brainstorm du 2026-08-11 reste non digéré** : seules ses références sont remontées. Ses **9 décisions et 7 questions** attendent toujours.

### 2026-08-12 (session 10) — le noyau n'est plus réservé
- 🔓 **La décision 40 est levée → 40b, tranchée par l'auteur.** Claude écrit le code, noyau **et architecture** compris ; l'auteur teste, itère et revient sur ses décisions. La règle était écrite à **cinq endroits** — tous corrigés, plus `Godot/README.md`. Ce que 40 protégeait n'était pas la frappe mais la **compréhension** : elle n'est plus produite par la construction, elle devient une chose à aller chercher. Réversible, mais le coût du retour grandit avec la base de code. → `Décisions arrêtées` 40b
- 🆕 **Serveur MCP Godot** (`.mcp.json`, `@coding-solo/godot-mcp`, MIT) : Claude lance la maquette et lit la console lui-même. Testé de bout en bout avant écriture — handshake, 14 outils, `get_godot_version` → `4.7.1.stable.official.a13da4feb`. Deux pièges vécus : `npx` seul ne démarre pas sous Windows (Node refuse un `.cmd` sans shell, `EINVAL`) d'où `cmd /c`, et `GODOT_PATH` est obligatoire — l'exécutable est sur le Bureau, hors des emplacements devinés. **Seul fichier non portable du dépôt.**
- 🐞 **`Godot/README.md` pointait `Downloads/` pour la sonde** ; l'exécutable est sur le **Bureau**. La commande de débogage ne marchait pas telle quelle.
- 🧹 **`CLAUDE.md` §1 rattrape le réel** : le prototype y était encore l'Altstadt (13b l'a remplacé par Wehrau le 2026-08-10) et le fichier affirmait qu'il n'existait « ni dépôt Godot ni script versionné ». « Moteur de simu écrit à la main » retiré — contredisait 40b.
- ✅ **Les deux écritures dans le vrai `.gpkg`**, à la demande de l'auteur : `emplois` = 878, couche `emprises` = 69/69 anneaux simples, 76,5 ha bâtis, 17,6 % de voirie. Contrôle population ✅ 5 353 hab. `04b` signale **quatre réparations de boucle à regarder** : îlots 55, 13, 16 et 21 — deux cœurs anciens, deux fronts commerçants ; le 16 tombe de 2 132 à 560 m².
- 🆕 **`08_jouer.py`, le moteur du classeur.** Rampes, budget étalé sur `L + M`, capital payé comptant au mois `d`, les quatre portées. Il calcule la quantité d'une décision **sur l'état du mois où le chantier commence**, pas sur t0 — c'est tout le mécanisme de D06, qui n'existe que parce qu'elle libère les mètres de D07 et D08.
- 🆕 **Trois liens qui n'étaient dans aucune table** : tronçon → îlots riverains (géométrique, critère de `04b` — **178/178 tronçons, 0 orphelin, 2,0 îlots par tronçon**), tronçon → tronçons voisins par sommet partagé, et l'aval d'une décision de voirie. Sans le premier, `D07;voisins;ilots;canopee` ne retombait nulle part et la spécificité spatiale disparaissait.
- 🔴 **Le résultat qui compte** : **`largeur_m >= 20` rate quatre des cinq rues les plus chargées.** Les tronçons 13, 21, 54 et 55 font 18 m et portent 0,87 à 1,00 de charge. D05 n'attrape que le tronçon 11 — et comme elle reporte +0,35 sur les voisines, elle **double le nombre de rues saturées (5 → 10) sans jamais toucher l'axe**. Le classeur a fait ce qu'on lui demandait : rendre une erreur de seuil visible en une soirée.
- 🐞 **Trois définitions de stock étaient fausses**, sorties par le contrôle du mois 0 : `canopee_moy` et `impermeabilise_moy` sont des **moyennes simples par îlot**, pas pondérées par la surface, et `riverain_moy` ne compte que les **îlots habités**. Un champ de 50 ha y pèse autant qu'un parc de 0,4 ha — c'est le choix consigné dans `partie.csv`, laissé tel quel, mais il est maintenant écrit quelque part.
- ⚠️ **Aucune décision n'a été refusée pour cause de budget** sur les trois parties. La contrainte réelle est le capital politique, pas l'argent.
- 🆕 **`QGIS/rendus/parties.html`** : les trois parties superposées, un curseur de 60 mois, le mode **écart au mois 0** — le seul qui rende un changement lisible — le journal des chantiers et huit courbes.
- 🎯 **Puis tout est passé dans Godot**, à la demande de l'auteur : *« je veux voir le résultat visible du code plutôt que penser à un système complexe sans pouvoir le visualiser »*. Une décision de bout en bout — D07 planter l'alignement — plutôt que onze à moitié.
- 🆕 **La ville est cliquable.** 07 exporte trois choses neuves : les **attributs par objet** (la fiche), les **plages d'indices par objet** (`groupes`) et les **emplacements d'alignement avec leur seuil de canopée**. Godot en refait **237 nœuds** — 63 îlots bâtis, 174 tronçons — chacun avec son corps de collision. On passe de 5 draw calls à ~250, et c'est le prix du jeu : un maillage fusionné ne se sélectionne pas, ne se surligne pas, ne se reteinte pas.
- 🆕 **Le noyau en GDScript** : `ville.gd` (l'état, les rampes, les indicateurs) et `chantiers.gd` (cible, coût, capital, budget étalé). Ni l'un ni l'autre ne touche un nœud — même discipline que `constructeur.gd`. Plus `selection.gd`, `interface.gd`, `alignements.gd`.
- 🔴 **Le recoupement passe.** À décision, seuil et mois identiques : Godot donne **0,2732** de canopée au mois 60, `08_jouer.py` **0,273** ; 64 tronçons, 6 217 m, 114,9 pts des deux côtés — et la table du `Classeur/README.md` §3 annonçait bien 64 · 6 217 · 115. La commande est dans `Godot/README.md`, elle n'est pas optionnelle.
- 🐞 **Le budget décalait d'un mois** : `08_jouer.py` paie sur `d` à `d + étale − 1` inclus, donc une mensualité tombe au moment où l'on décide. 397 d'un côté, 399 de l'autre — assez peu pour qu'on l'ignore, ce qui est exactement le danger. Corrigé.
- 🐞 **Les arbres sautaient au lieu de pousser.** La position d'un arbre d'alignement dépendait de la densité (`t = L·(k+0,5)/n`) : faire monter la canopée redistribuait tout l'alignement. Désormais 07 exporte **tous** les emplacements avec un **seuil**, la position est fixe, et seul le seuil décide. Un arbre planté reste où il est.
- 🆕 **L'occlusion voyage dans le canal alpha** de la couleur de sommet. C'est ce qui permet de repeindre un îlot en calque thématique sans perdre ce qui le pose au sol. Aucun matériau du projet n'activait la transparence : le canal était libre.
- 🟠 **Trois chiffres attendent l'œil de l'auteur**, tous commentés dans le code : la **surchauffe** (`3,5 × imperméabilisé − 2,5 × canopée`, +1,59 °C à t0), le **+0,25 de canopée de D07** (alors que la canopée d'une rue plafonne à 0,18 dans les données), et `CANOPEE_ALIGNEMENT_MAX` (rendu seulement).
- 🔄 **Puis l'auteur a changé le cap, en fin de session** : *« je veux d'abord avoir une ville crédible et belle — travailler le trafic, les îlots. Ensuite on prendra chaque indicateur, système et décision un à un. »* Consigné en **51**, et répercuté dans cinq notes du vault : `Plan 3 mois` (les phases A/B/C remplacent les mois), `Génération procédurale` (les parcelles entrent en phase, le trafic aussi), `Direction artistique` (ce que « belle » veut dire, et la règle de production), `Questions ouvertes` (n°16 réveillée, **n°18** neuve sur le trafic), `00 - Index`.
- ⚠️ **Ce que ce virage coûte, écrit noir sur blanc** : la limite « une semaine, pas de toits » tombe (**52**) alors qu'elle était le garde-fou contre le risque nommé *« que la 3D mange le calendrier »*. Le risque est **accepté**, pas éliminé. Ce qui le tient maintenant est une règle de production — *si je devais en faire 200, est-ce que je tiendrais ?* — et un critère d'échec : **le pari est perdu si, dans six semaines, la ville est plus belle et qu'aucune décision de plus n'a été traitée.**

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

### 2026-08-10 (sessions 1 à 5) — compressé
Encodage réparé · `CLAUDE.md` et ce fichier posés · carte qualifiée (69 îlots, 178 tronçons, 4 plaies de 1965) · `03_adjacences` et `04_deriver_attributs` écrits, quatre défauts réels sortis par le dry-run (aucun pont, graphe sur les extrémités, largeurs constantes, axe se trompant de rive) · [dépôt GitHub](https://github.com/jan917-byte/city-builder) créé · `QGIS/` scindé en `scripts`/`data`/`rendus`. Le détail est dans l'historique git.

*(`Méta/Journal.md` reste vierge de ma main — c'est le fichier de l'auteur.)*
