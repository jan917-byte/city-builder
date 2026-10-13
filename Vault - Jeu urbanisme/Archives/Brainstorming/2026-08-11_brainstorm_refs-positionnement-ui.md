---
tags: [brainstorming, veille-concurrentielle, direction-artistique, ui]
statut: brut
date: 2026-08-11
sujet: références, positionnement et direction UI
---

# 2026-08-11 — Références, positionnement et direction UI

**Question de départ :** où se situe le jeu par rapport à ce qui existe, et à quoi ressemble son interface ?
**Ce qui en est sorti :** un positionnement (« Terra Nil, mais sur une ville que tu reconnais »), une DA écartée (le système de modules Townscaper), un modèle d'UI (carte → UI → carte), une règle dure (le jeu ne pose jamais le diagnostic), et un candidat sérieux à la décision signature : **la coupe de rue**.
**À remonter où :** [[Décisions arrêtées]] (les 9 cases cochées du §6) · [[Questions ouvertes]] (les 7 du §7, dont une qui répond peut-être à la n°5) · [[Décisions]] (colonne `signal_diagnostic`) · [[Direction artistique]] · [[Marketing et Steam]]

> [!warning] Provenance — document importé, vocabulaire d'un autre vault
> Cette session a été tenue ailleurs. Le corps est déposé **tel quel**, sans nettoyage, conformément à [[00 - Brainstorming]]. Deux conséquences à connaître avant de le lire :
>
> - Il portait le tag `jeu/brightvale` — un nom qui n'apparaît nulle part ici. Nom de travail abandonné, autre projet, ou variante à verser dans [[Marketing et Steam]] : à toi de dire.
> - Ses wikilinks pointent vers des notes qui n'existent pas dans ce vault. Correspondances :
>
> | Dans le document | Ici |
> |---|---|
> | `[[Tableau des décisions]]` | [[Décisions]] — le classeur de la semaine 2 |
> | `[[Piliers de design]]` | [[Vision et prémisses]] |
> | `[[Décisions architecturales non tranchées]]` | [[Questions ouvertes]] |
> | `[[QGIS - pipeline ville.gpkg]]` · `[[QGIS]]` | [[Pipeline QGIS]] |
>
> Les noms de jeux (`[[Terra Nil]]`, `[[Townscaper]]`…) restent en wikilinks non résolus : ce sont des références externes, pas des notes manquantes.

---

> [!abstract] En une phrase
> Aucun ingrédient du concept n'est neuf isolément, mais la combinaison n'existe nulle part. Le positionnement à tester : **« [[Terra Nil]], mais sur une ville que tu reconnais. »**

---

## 1. Positionnement

### Ce qui n'est PAS neuf
- Le contrôle indirect : SimCity zone depuis 1989, le joueur n'a jamais posé les bâtiments.
- Le city builder écolo : [[Terra Nil]], [[Solaria]], une dizaine de jams solarpunk.
- L'expertise urbaine comme argument : [[Citystate Metropolis]], [[Block'hood]].
- La beauté procédurale : [[Townscaper]], [[Tiny Glade]].

### Ce qui EST neuf — le croisement de trois choses
1. **La ville de départ est le problème.** Tout le genre part d'une page blanche, y compris les jeux écolos. Avantage le plus solide et le plus dur à copier : il exige de savoir ce qu'est réellement une ville moyenne périurbaine.
2. **Le joueur décide au lieu de dessiner.** Une intention sur un secteur, pas un outil de tracé. Poussé plus loin que le zonage classique.
3. **Les causalités sont vraies.** Seuils de densité / viabilité TC, dimensionnement de rétention, flux piétons et survie du commerce. Personne d'autre ne peut les écrire sans les inventer.

> [!tip] Test du pitch
> Si un joueur comprend le positionnement en trois secondes, c'est bon. À valider sur la page Steam.

---

## 2. Carte des concurrents

| Jeu | Proximité | Ce qu'il prouve | Ce qu'il te laisse |
|---|---|---|---|
| [[Terra Nil]] | Posture — « reverse city builder », le plaisir = regarder les effets se propager | Le geste léger + propagation lente fonctionne comme plaisir principal | Pas d'habitants, pas de conflits d'usage, 4-8h, plus proche du jeu de plateau solo |
| [[Citystate Metropolis]] | **Concurrent le plus dangereux.** Dev solo, gridless, bâtiments procéduraux, politiques et zonage, quartiers mixtes | Le marché de « l'urbanisme sérieux » existe et un solo peut l'adresser | Il construit ex nihilo et simule 1M d'habitants. Il fait du SimCity sérieux ; toi de la *transformation* |
| [[Urbek]] | Mécanique — pas d'argent, pas de catastrophes, les bâtiments évoluent selon leur voisinage | Comment rendre lisible une règle de causalité pure | Pas de ville existante, pas de politique |
| [[Lichenia]] | Concept — SimCity organique pour l'Anthropocène, tuiles énigmatiques | Le seul à approcher « réparer une ville existante ». Gratuit, 30 min | Micro-jeu expérimental, aucune ambition de production |
| [[Frostpunk 2]] | **Structure** — districts au lieu de bâtiments, factions, conseil qui vote les lois | Le pivot micro→macro est viable commercialement | Survie et cynisme ; ton ton est « dur mais possible » |
| [[Block'hood]] / [[Common'hood]] | Auteur — Jose Sanchez, architecte et prof | Un expert du métier peut faire un jeu qui tient | Piège documenté : produire « le rendu d'architecte qui sur-promet ». À éviter absolument en solarpunk |
| [[Solaria]] | Thème + contrôle indirect — « la ville se construit toute seule », Godot, dev solo | Idem sur l'esprit | Minimaliste, hexagonal, cosy, sans propos |
| [[Tiny Glade]] | **Architecture** — le joueur pose la structure, le système pose le grain | 1M de wishlists sans marketing payant, 600k ventes en un mois, à deux | Aucun système, aucun enjeu — c'est un jouet |

---

## 3. Direction graphique

### Le cas [[Townscaper]] — beau mais à écarter
Townscaper se décompose en deux couches :
- **Couche rendu** (aplats sans texture, palette resserrée, AO douce, lumière fixe, caméra calme, zéro interface) → ✅ **reproductible en solo, c'est la voie la moins chère vers le beau.**
- **Couche géométrie** (grille de quads irréguliers + modules authorés pour chaque configuration de coins, déformés sur la maille) → ❌ troisième jeu de Stålberg avec cette techno, des années de spécialiste.

> [!warning] Mais le coût n'est pas le vrai argument — trois conflits de design
> 1. **Townscaper ré-effondre le voisinage à chaque clic.** C'est exactement l'inverse du pilier *parcelles persistantes / mémoire visuelle de la transformation*.
> 2. **Townscaper n'a pas de sol.** Ni rue, ni asphalte, ni stationnement. La seule chose qu'il n'a jamais eu à résoudre est ton sujet entier.
> 3. **Townscaper ne sait produire que du charme.** Or la ville de départ doit être quelconque et reconnaissable — c'est l'antagoniste. Si l'« avant » est déjà joli, le joueur n'a aucune raison d'agir.

**Ton brief est plus dur que celui de Stålberg** : rendre la banalité périurbaine sans la rendre laide ni cynique, et faire que l'après soit visiblement meilleur. Personne ne l'a résolu → c'est le terrain.

### Autres références
- [[Cloud Gardens]] — la végétation qui envahit le béton. Littéralement l'avant/après.
- [[Summerhouse]] — façades ordinaires assemblées, mélancolie urbaine.
- [[Dorfromantik]] — lisibilité et palette.
- **Sprawl Repair Manual** (Galina Tachieva) — les motifs de réparation de l'étalement, du politique au dessin.
- **URB-I** — collection d'avant/après de transformations voiture → piéton via Street View. Les deux états de chaque élément sont déjà documentés par centaines.
- 🎯 **Piste propre : la maquette d'architecte.** Matériaux physiques, carton, bois, béton, lumière du nord, palette européenne. Dit « projet » plutôt que « rêve ».

---

## 4. Pipeline art — systèmes, pas assets

> [!quote] Règle unique
> Ne jamais produire un asset qu'on peut produire une recette. Test : *« si je devais en faire 200, est-ce que je tiendrais ? »*

- **Géométrie bête, détail dans la matière.** Le budget polygonal va à la silhouette (ce qui se lit à distance en axonométrie), jamais à la surface. Briques, joints, tuiles, feuillage → normal maps.
- **Un seul graphe « sol urbain »** paramétré `perméabilité` / `usure` / `végétalisation` → asphalte neuf, asphalte fissuré, pavé drainant, plateau piéton, rue-jardin. Une recette et trois curseurs qui *sont déjà* des attributs de simulation. Avant/après gratuit sur l'élément le plus présent à l'écran.
- **Matériaux qui lisent la géométrie** (usure sur arêtes, salissure dans les creux) → délaissé vs réhabilité = un mesh, deux réglages. Aucun asset « après » à modéliser.
- **Arbres en geometry nodes paramétrés par âge** → probablement le meilleur retour visuel par heure investie du projet. Un arbre qui *grandit* au lieu d'*apparaître* relie `canopee` à du visible et raconte le temps long de l'urbanisme sans texte.
- **Chantiers plutôt qu'animations** : échafaudage / palissade / poussière en système réutilisable. Le chantier dit « ta décision est en cours » — indispensable puisque les changements sont lents.
- **Pooling dès la première version** pour piétons, vélos, voitures, trams, particules.

> [!important] Règle architecturale
> Aucun état visuel n'est posé à la main dans une scène. Tout rendu dérive d'une valeur de simulation par parcelle. Si un pixel ne s'explique pas par une variable, c'est un bug de design.

---

## 5. UI et carte — le vrai sujet

> [!important] Cadrage retenu : **carte → UI → carte**
> Le temps de jeu est ~50/50, mais l'attention fait un aller-retour : on **diagnostique** sur la carte, on **décide** dans l'UI, on **jouit** sur la carte. La carte est aux deux bouts ; l'UI est le goulot au milieu. La cible n'est donc pas une belle UI *par-dessus* la ville mais une UI *dessinée dans* la ville — le panneau flottant est ce qui reste quand on n'a pas trouvé comment inscrire la décision dans l'espace.

### Le modèle à trois surfaces

| Surface | Rôle | Registre |
|---|---|---|
| Carte abstraite | comprendre | données, aplats, isochrones |
| UI | décider | instruments, coupe, arbitrage |
| Ville rendue | jouir | matière, arbres, ombre, gens |

> [!danger] Piège à éviter
> La carte de diagnostic et la carte de récompense **ne peuvent pas être la même**. Si on lit la carte de chaleur pour décider de planter, puis la même carte de chaleur pour voir le résultat, la récompense est un aplat qui change de teinte sur un calque abstrait — un tableur colorié, pas « regarde ce que j'ai fait ».

**Conséquence :** la transition abstrait ↔ concret est une pièce de *game feel* majeure, pas une bascule de bouton. Le plan-guide passe alors du statut de style à celui de **mécanique** : le calque de diagnostic est un calque, on le pose sur la ville pour lire, on le soulève pour voir. Le geste réel du métier devient le geste de navigation du jeu. Si ce mouvement est beau et rapide, le problème d'interface principal est réglé.

### Règle dure : le jeu ne dit jamais le diagnostic

Poser un diagnostic, c'est repérer une **contradiction entre deux couches** : de la densité sans desserte, de l'imperméabilisation en amont d'un point bas, du commerce sur une rue que plus personne ne traverse à pied.

Si un panneau affiche « ⚠️ îlot de chaleur ici », le diagnostic est mort et le jeu devient une liste de tâches — c'est-à-dire le simulateur bureaucratique explicitement refusé. **Le jeu montre les données, jamais le verdict. Des instruments, pas des alertes.** C'est frontalement contre l'ergonomie moderne, c'est inconfortable, et c'est le jeu.

➡️ **Impact sur [[Tableau des décisions]] : ajouter une colonne `signal_diagnostic`** — quelle couche révèle le besoin de cette décision. Si aucune couche ne le révèle : soit il manque une couche, soit la décision n'a pas sa place.

### Récompense différée — le risque structurel

Les changements se matérialisent lentement (cœur du concept) — ce qui affaiblit mécaniquement la récompense. Un plaisir différé de huit années de jeu n'est pas un plaisir. Trois réponses :

1. **Le fantôme instantané** — promet immédiatement. *(déjà acté)*
2. **Le chantier** — dit « ta décision est en cours ». *(déjà acté)*
3. 🎯 **Le point de vue épinglé** — *nouveau.* Le joueur pose un repère sur une rue, le jeu capture l'état à cet instant. Il revient plus tard et compare : curseur avant/après, même cadrage, dix ans d'écart. C'est URB-I transformé en fonctionnalité, le seul dispositif qui rende une transformation lente *jouissive*, et accessoirement la machine à screenshots pour la page Steam et le devlog.

> **Une transformation qui ne se compare pas ne se voit pas.**

### Références jeu

**[[Frostpunk 2]] — le plus proche mécaniquement.** Districts entiers au lieu de bâtiments individuels, population aux visions divergentes, factions + conseil qui vote les lois.
- ❌ *Ratés à ne pas répéter* : menu en barre horizontale en bas, icônes trop serrées, scroll latéral quand les options s'accumulent, mis-clics fréquents, difficulté à voir où l'on peut poser. Et **UI blanche sur neige blanche** — le jeu a été retardé pour corriger l'UI et ça n'a pas suffi. ⚠️ Risque identique avec une palette « maquette » claire.
- ✅ *À voler* : la jauge de tension en liquide noir qui monte et frémit vers l'ébullition. Une variable rendue en **matière** plutôt qu'en pourcentage → à appliquer à `canopee`, `impermeabilise`, etc.

**Map modes (Paradox / Victoria 3) — piste principale.** Le même territoire re-rendu en N couches de données. *Déjà fait* : `densite`, `impermeabilise`, `canopee`, `desserte_tc` sont des modes de carte déjà stylés dans [[QGIS]]. À porter, pas à inventer.
> **Règle qui en découle : une décision se prend toujours dans le mode de carte qui la justifie.** On plante des arbres depuis la carte de chaleur, on densifie depuis la carte de desserte. L'argument du planificateur devient le geste du joueur.

**[[Mini Metro]]** — l'UI *est* l'esthétique (diagramme de Beck). Preuve qu'un langage schématique peut porter tout le rendu d'un système. Pertinent pour le tram.

**[[Democracy 4]]** — contre-exemple. Graphe causal juste, rendu de tableur avec des flèches. Piller la logique, jeter l'image.

### Les instruments du métier — l'atout incopiable

- 🎯 **La coupe de rue.** Le dessin le plus iconique de la profession, un avant/après lisible en une image, et un objet manipulable (chaussée, stationnement, piste, trottoir, arbres). **Streetmix** prouve que le geste est plaisant même pour des non-urbanistes. Personne dans le jeu vidéo n'en a fait une mécanique. → **Candidat sérieux à la question ouverte « quelle décision est la plus satisfaisante à prendre ».**
- **Les isochrones.** « Ce qu'on atteint en 10 min à pied » — une tache qui grandit quand on ouvre une traverse. Retour visuel instantané sur une décision structurelle.
- **Le plan-guide.** Feutre sur calque posé sur photo aérienne : le geste réel. Comme langage d'interface, immédiatement identifiable, inexistant en jeu, et dit « projet en cours » plutôt que « menu ».
- **Isotype (Otto Neurath).** Pictogrammes inventés dans les années 1920 pour rendre les statistiques sociales et urbaines lisibles par les habitants. L'ancêtre littéral du problème d'UI, et viennois plutôt que californien.

> [!important] Règle de conception des décisions
> Pour chaque décision : *qu'est-ce qu'elle dessine sur la ville avant même d'être validée ?* Si la réponse est « un chiffre change dans un panneau », la décision n'est pas encore conçue. Le fantôme de projet instantané n'est pas un confort, c'est le cœur de l'interface.

---

## 6. Décisions prises cette session

- [x] Le positionnement se défend par le croisement des trois angles, pas par un seul.
- [x] Écarter le système de modules type Townscaper — trop coûteux **et** incompatible avec le pilier de lisibilité.
- [x] Garder la recette de **rendu** de Townscaper / Tiny Glade (aplats, palette resserrée, AO, lumière fixe).
- [x] La ville de départ doit être quelconque, pas jolie. Contrainte de DA, pas seulement de propos.
- [x] Les modes de carte QGIS existants sont le socle de l'UI, pas un outil de production séparé.
- [x] **Modèle carte → UI → carte** : diagnostic et récompense sur la carte, décision dans l'UI.
- [x] **Trois surfaces distinctes** — la carte de diagnostic ne peut pas servir de carte de récompense.
- [x] **Le jeu ne pose jamais le diagnostic à la place du joueur.** Instruments, pas alertes.
- [x] Le plan-guide devient une mécanique de navigation (poser / soulever le calque), pas seulement un style.

## 7. Questions ouvertes

- [ ] La coupe de rue est-elle **la** décision signature, ou un outil parmi d'autres ?
- [ ] Comment rendre la banalité périurbaine séduisante à regarder sans la rendre désirable ?
- [ ] Contraste UI / ville : quelle palette d'interface tient sur une ville en tons clairs de maquette ?
- [ ] Les agents (piétons, voitures) sont-ils du spectacle ou de l'ambiance ? → tranche entre individus et flux agrégés. **Coûteux à inverser.**
- [ ] Combien de couches de diagnostic au minimum pour qu'une **contradiction** soit lisible sans être dite ? (2 suffisent-elles ?)
- [ ] Le point de vue épinglé : capture de l'état réel, ou re-simulation du passé au moment de la comparaison ? → **question d'architecture, à trancher tôt.**
- [ ] Le geste calque posé/soulevé : bascule, fondu, ou déplacement physique du calque ? C'est un choix de *feel*, il se teste en prototype.

## 8. Prochaines actions

- [ ] Jouer [[Lichenia]] (30 min, gratuit)
- [ ] Jouer [[Urbek]] + démo [[Tiny Glade]] (2 h) — noter une seule chose pour chacun : *ce que le joueur clique, et ce qui se passe juste après*
- [ ] Écrire le pitch en une phrase et vérifier qu'il distingue de [[Terra Nil]] et [[Citystate Metropolis]] (20 min)
- [ ] Material Maker : **un** graphe de sol avec un curseur `usure` allant d'asphalte neuf à asphalte fissuré (2 h). Si le curseur marche, le pipeline entier est prouvé.
- [ ] Dessiner **une seule** décision (« supprimer le stationnement sur cette rue ») sur trois supports — en coupe, en mode de carte, en fantôme sur le plan (1 h, une feuille). Savoir lequel est le geste du jeu.
- [ ] ⭐ Sur cette même feuille, écrire **quelle couche a fait remarquer le problème**. Si la réponse ne vient pas, la décision n'a pas de phase de diagnostic → elle arrive par un menu, pas par une observation.
- [ ] Ajouter la colonne `signal_diagnostic` au [[Tableau des décisions]]
- [ ] Regarder 20 min de gameplay de [[Citystate Metropolis]]

---

## 9. Reprendre ici

Le prochain livrable proposé et non encore fait : **un prototype HTML cliquable de l'éditeur de coupe de rue** — curseurs de largeur, bascule avant/après, et les chiffres métier qui bougent en dessous. À tester dans le navigateur, retour sous forme de bugs.

Second candidat, désormais aussi important : **un prototype du geste calque** — une carte, deux couches de diagnostic, et le mouvement poser/soulever. C'est le seul moyen de savoir si la transition abstrait ↔ concret est agréable.

> [!note] Rappel de cadrage
> La moitié UI du jeu est une **bonne** nouvelle en solo : c'est la partie la moins chère à itérer, la plus efficace en vibe coding, et celle où l'expertise métier est imbattable. C'est le terrain du projet, pas celui de Stålberg.

---

**Liens** : [[Piliers de design]] · [[Décisions architecturales non tranchées]] · [[Tableau des décisions]] · [[QGIS - pipeline ville.gpkg]]

*(ligne d'origine conservée telle quelle — les liens résolus sont dans l'encart de provenance en tête)*

**Voir aussi** : [[00 - Brainstorming]] · [[Direction artistique]] · [[Décisions]] · [[Questions ouvertes]]
