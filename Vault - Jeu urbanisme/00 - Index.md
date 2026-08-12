---
tags: [moc, projet]
statut: vivant
maj: 2026-08-12
---

# 🏙️ Projet jeu — city-builder de transformation urbaine

> Un city-builder PC où le joueur ne construit pas : il **décide**. Une ville moyenne ordinaire, voiture-dépendante, qu'on transforme sur 20 ans. Objectif : **inspirer**, pas simuler la bureaucratie.

**Titre de travail** : aucun · candidats dans [[Marketing et Steam]]
**Où j'en suis** : mois 1 bouclé — la carte est **simulable**, la ville a des **stocks**, et **elle se joue** : on clique, on décide, vingt ans passent
**Phase actuelle** 🎯 : **le prototype énergie est la colonne vertébrale** — un thème de bout en bout, et les autres s'y branchent ensuite. La 3D et l'UI avancent **en parallèle, tirées par lui** → [[Décisions arrêtées]] **64**
**Périmètre du prototype** : [[Wehrau]], une petite ville entière — **pas** un quartier de [[Vallmar]]
**Prochaine action concrète** : le prototype énergie sous Windows — quatre nombres, **deux décisions de nature opposée** (poser des panneaux · isoler), trois calques → `PLAN_energie.md` · [[Plan 3 mois]]
**Ce que le prototype teste** : *est-ce que choisir **où** investir, et **quand**, fait un jeu ?*
**Les deux garde-fous** ⚠️ : *« si je devais en faire 200, est-ce que je tiendrais ? »* (52) · et **quand les deux pistes se disputent une journée, l'énergie gagne** (64b)

---

## 🧭 Fondations

- [[Vision et prémisses]] — les deux bases non négociables, ce que le jeu est et n'est pas
- [[Ton et règles d'écriture]] — « dur mais possible », les clichés interdits
- [[Boucle de jeu]] — les 60 secondes qui se répètent
- [[Pièges connus]] — la liste des façons de rater ce projet

## ⚙️ Systèmes

- [[Carte des systèmes]] 🆕 — **la page qui tient l'ensemble** : trois schémas — la machine, les sept, les tensions
- [[Indicateurs globaux]] 🆕 — les sept chiffres du bandeau, et la règle *un chiffre, un calque*
- [[Ressources]] — argent + capital politique. Le budget tient en **deux formules** depuis le 2026-08-12
- [[Décisions]] — l'anatomie d'une décision, l'exemple de référence
- [[Chantiers et temps]] — temps continu, délai, montée en charge
- [[Happenings]] — canicule, crue, révolte : urgence contre vision
- [[Diagnostic et calques]] — l'activité principale entre deux décisions
- [[Déclin et défaite]] — pas de game over, des quartiers qu'on perd
- [[Milestones]] — les jalons cumulables : zéro voiture, ville-éponge, autonomie… la rareté est dans le calendrier
- [[Fins et pluralisme]] — le problème non résolu des archétypes. **À ne pas confondre avec les milestones**

## 🗺️ La ville

- [[Wehrau]] 🎯 — ~5 350 hab., **le prototype** : une petite ville qu'on voit en entier
- [[Vallmar]] — 112 000 hab., la ville du jeu complet. Design en réserve
  - [[Altstadt]] · [[Les Vergnes]] · [[La Fonderie]] · [[Quartier Gare]] · [[Hochfeld]] · [[Le Ried]]

## 🔧 Technique

- [[Géométrie et données]] — l'îlot comme entité, la rue comme adjacence
- [[Pipeline QGIS]] — le GeoPackage, les scripts, ce qui reste à faire
- [[Génération procédurale]] 🎯 — **la phase active** : les parcelles, les toits, le trafic
- [[Moteur et architecture]] — Godot 4, GDScript vs C#. **Godot porte la boucle** depuis le 2026-08-12 → 39c
- [[Direction artistique]] 🎯 — **Townscaper**, et la règle de production qui remplace le calendrier

## 📦 Production

- [[Plan 3 mois]] — le plan opérationnel détaillé
- [[Calendrier et budget]] — 3–5 ans, ~15 000 €
- [[Périmètre et coupes]] — quoi couper si ça déborde
- [[Marketing et Steam]] — page Steam tôt, localisation, presse

## 💭 Brainstorming

- [[00 - Brainstorming]] — les discussions brutes avec Claude, déposées telles quelles. Rien n'y est décidé tant que ça n'est pas remonté ailleurs.

## 🧾 Méta

- [[Décisions arrêtées]] — le registre, avec ce qui est réversible ou non
- [[Questions ouvertes]] — 🟢 plus aucune ne bloque la phase A depuis le 2026-08-12
- [[Glossaire]] — vocabulaire du projet, base de l'i18n
- [[Journal]] — ce que j'apprends à chaque session

---

## ⚠️ Les trucs à trancher maintenant

✅ **Tranché le 2026-08-12** : les **sept indicateurs globaux** et la règle *un chiffre, un calque* (53–54), **pas d'économie chiffrée** (55), le CO2 et le renouvelable **dérivés et non simulés** avec le carbone gris (56), **le max d'un indicateur est un milestone** révélé à l'approche (57), compteurs contre barres (58), **d'où vient l'argent — deux formules** (59), et **l'économie en barre sans nombre** avec ses deux garde-fous (60, 60b).
✅ **Tranché le 2026-08-11** : la crue d'ouverture (rive gauche), 5 350 habitants, le capital politique en **un chiffre**, les [[Milestones]] cumulables, 2 h de partie, **la ville de t0 avant les décisions** (49) et **Townscaper** comme référence de travail (42b).

🟢 **La phase A n'est plus bloquée.** Les cinq questions qui la tenaient sont closes le 2026-08-12 : le **mitoyen par construction** (61, ferme n°16), le **trafic en flux** (62, ferme n°18), **le dortoir assumé** (50b, ferme n°17), **trois ponts au lieu de cinq** (30c, ferme n°12), **la barre de 1974 reste sur l'îlot 32** (13e, ferme n°14). Et le nom est arrêté : **Wehrau**, l'**Ilse** (13f).

Ce qui reste, et qui ne bloque rien tout de suite :

1. **Le deuxième axe des fins** — le vieux problème, avec un candidat qui s'est renforcé : « personne n'a été chassé » est désormais l'un des sept indicateurs, et **le seul qui ne monte jamais**. → [[Fins et pluralisme]]
2. **35 — la parcelle est bien l'entité persistante ?** Arrêtée 🔒 et jamais mise à l'épreuve du code. Elle ne se tranche plus, elle se **vérifie** : la partition (61) ne doit pas se rejouer quand une seule parcelle change.
3. **Trois questions qui se tranchent en dessinant l'écran, pas ici** : **n°19** — onze nombres permanents, est-ce que ça tient ? — **n°21** — comment le joueur comprend-il que l'économie commande son budget, alors que les deux sont loin l'un de l'autre ? — et **n°20**, une contradiction interne : [[Déclin et défaite]] refuse la jauge globale que l'indicateur « ville exposée » vient d'introduire. → [[Questions ouvertes]]

⚠️ **Un travail QGIS attend avant le générateur de parcelles** : supprimer deux ponts, et regarder si l'axe de transit se déplace. `02` écrase le `.gpkg`, donc ça se fait **avant**, pas après.

## 🔄 Révisions récentes

**2026-08-12 (matin) — la phase A est débloquée, cinq questions closes**
- 🎯 **Le raccord des bâtiments se règle par la méthode, pas par un travail de couture** : *la parcelle est une **partition** de l'emprise de l'îlot.* Le générateur découpe au lieu de poser des formes dans un vide, donc deux voisines partagent une arête exactement. Ce qui a tranché : 20 îlots de `maisons_de_ville` et 12 de `coeur_ancien` — le mitoyen n'y est pas un détail, **c'est la forme urbaine**. → **61**
- 🚗 **Le trafic sera un flux, pas des agents** — plus une poignée de véhicules figurés qui ne calculent rien. *Le spectacle est la transformation urbaine, pas la circulation.* Critère nommé et jugeable à l'écran : **une rue à `charge = 1,00` doit être désagréable à regarder** ; si le flux est trop propre, on ajoute de l'encombrement, pas de la navigation. → **62**
- 🏭 **Wehrau reste un dortoir, assumé** : 0,16 emploi par habitant. Ça rend la ville cohérente avec elle-même — l'axe saturé et les 0,86 place par habitant deviennent des symptômes — et ça donne un levier unique : **les deux friches sont le seul levier d'emploi de la ville**. Coût assumé : le mouvement du matin sort de la carte. → **50b**
- 🌉 **Trois franchissements au lieu de cinq.** À cinq, la rivière ne coupe plus rien et « ajouter une passerelle » cesse d'être une décision. ⚠️ **Lesquels** se choisit sur la carte, et l'affectation de trafic se rejoue. → **30c**
- 🏢 **La barre de 1974 reste sur l'îlot 32** — c'était la phrase du vault qui était fausse, pas la carte. Ce qui l'expose n'est pas la proximité de l'eau mais d'être **en bout de chaîne**. → **13e** · et **13f** : les noms Wehrau et Ilse sont arrêtés.

**2026-08-12 (nuit) — les indicateurs globaux**
- 🎯 **Une règle qui commande tout le bandeau** : *aucun chiffre global sans son calque*. Elle a taillé dix-neuf indicateurs candidats à **sept**, par un critère simple — un chiffre dont on ne saurait pas dessiner la carte est une jauge qu'on optimise, pas une invitation à regarder la ville. → 53 · [[Indicateurs globaux]]
- 💰 **La plus vieille question structurante tombe : d'où vient l'argent.** Deux formules — recettes ∝ logements, charges ∝ mètres de voirie — au lieu d'une économie simulée. Le déclencheur est un fait mesuré : **le budget ne mordait jamais** (418 pts dépensés sur 500, +152 de solde, aucune décision jamais refusée). Récupère au passage les **charges d'entretien**, orphelines. → 59 · [[Ressources]]
- 🔗 **Le bandeau et les [[Milestones]] sont le même objet.** En cherchant à borner les indicateurs, on trouve que **cinq des sept maxima sont des jalons qui ont déjà un nom** — zéro voiture, zéro carbone, autonome en énergie, ville-éponge, « personne n'a été chassé ». Ferme au passage deux sous-questions des Milestones. → 57
- 🧪 **Une manœuvre réutilisable** : *une formule sur des attributs existants n'est pas une sous-simulation.* Elle a sauvé le CO2, le renouvelable et le budget — trois choses qui semblaient exiger une économie. → 56
- ⚫ **Le carbone gris est assumé**, ce qui rend **« adapter » mécaniquement défendable face à « reconstruire »**. L'indicateur ne mesure pas seulement : il rend chiffrable un dilemme déjà présent dans le vault.
- 💡 **Puis l'économie revient par une autre porte, et en mieux** : le joueur ne voit qu'une **barre sans nombre** et son **budget annuel**, qui en dépend — le calcul est caché. ***Un état non chiffré ne s'optimise pas*** : tout le piège *Democracy 4* tient au pourcentage. Ça révise 59 — les formules décrivent ce qu'on **maîtrise**, l'économie est le **multiplicateur qu'on ne maîtrise pas**. → **60**
- 🔴 ***Formule cachée ≠ causalité cachée***, et l'économie cachée ne sert **jamais** à ajuster la difficulté (21). Quand la barre bouge, quelque chose le dit en une phrase. → **60b**
- 🟠 **Ce que ça laisse ouvert** : onze nombres permanents à l'écran (n°19), une contradiction avec [[Déclin et défaite]] (n°20), et **comment le joueur comprend que l'économie commande son budget** (n°21) — piste la plus forte : *le budget se vote une fois par an*.

**2026-08-12 (soir)**
- 🔄 **L'ordre change une seconde fois : la ville crédible et belle passe devant les systèmes.** 49 mettait déjà la ville avant les décisions, mais visait une maquette de masses. Le seuil passe de *« sentir le lieu »* à ***« avoir envie de la regarder, et croire qu'on y habite »***. Ensuite seulement, chaque indicateur, système et décision **un par un**, plus en lot de onze. → 51 · [[Plan 3 mois]]
- ⚠️ **La limite « une semaine, pas de toits » tombe** — 51 fait entrer les toits dans le plan. Mais le risque qu'elle couvrait est intact : la 3D avance toujours parce que chaque amélioration se voit. Ce qui la remplace est une **règle de production**, pas une date : *si je devais en faire 200, est-ce que je tiendrais ?* → 52 · [[Direction artistique]]
- 🔴 **La subdivision en parcelles entre en phase.** Elle en était explicitement exclue — « le point dur, l'attaquer reviendrait à changer de projet ». C'est un changement de projet, et il est assumé. → [[Génération procédurale]]
- 🎮 **Godot porte la boucle de jeu** : on clique un îlot, on décide, vingt ans passent. Le classeur devient le **banc d'essai**, et un contrôle de recoupement compare les deux moteurs — il a déjà attrapé un décalage d'un mois sur le budget. → 39c
- ❓ **Question neuve n°18 : le trafic, des voitures ou un flux ?** Coûteuse à inverser. Ce qui penche : ici le spectacle est la transformation urbaine, pas la circulation. Mais ça se regarde à l'écran. → [[Questions ouvertes]]

**2026-08-12**
- 🎮 **Frostpunk / Frostpunk 2 et Democracy 4 entrent comme références**, sortis du brainstorm et répartis là où ils portent : la mécanique dans [[Décisions]] (inertie des effets, décision à l'échelle du district, capital politique), l'interface dans [[Direction artistique]] (la jauge en matière à voler, l'UI blanche sur neige blanche à éviter), le ton dans [[Ton et règles d'écriture]] (Frostpunk est le repoussoir du cynisme), et un cas d'école dans [[Pièges connus]] (les jauges d'humeur de D4). Les 9 décisions et 7 questions du brainstorm, elles, **attendent toujours**.

**2026-08-11 (soir)**
- 🔄 **L'ordre a changé : la ville de t0 passe devant le système de décisions.** Une crue est la perturbation d'un état, et l'état n'existait pas. Le classeur est écrit et chiffré, il attend son socle. → [[Décisions arrêtées]] 49 · [[Plan 3 mois]]
- 🎨 **Townscaper remplace Mini Motorways** comme référence de travail. On prend la couche rendu, on écarte la couche géométrie : sa grille de quadrilatères contredit l'îlot polygonisé, et il n'a **pas de sol** — ni rue ni stationnement, soit le sujet entier d'ici. → 42b
- 🎨 **Wehrau à t0 est un peu pastel, et grise quand même** : les bâtiments sont dans la palette dès la première image, **c'est le sol qui est minéral**. La grisaille est une **proportion** — 28 % d'imperméabilisé, 14 % de canopée — pas une teinte posée. Ni cliché dystopique, ni tout donné d'avance. → 42c · [[Direction artistique]]
- 💼 **Les emplois entrent dans les données** : 878 pour 5 353 habitants, soit **0,16 par habitant**. Pas un coefficient trop bas — 10,4 ha d'activité sur 38 ha bâtis. **Wehrau est un dortoir**, et ça explique l'axe de transit saturé. → 50 · n°17
- 🖥️ **Godot entre au mois 1**, pour le rendu seulement — la maquette de masses ne touche pas au noyau de simulation. → 39b

**2026-08-11**
- Mise à jour de l'état affiché : la semaine 1 est bouclée.
- **Quatre questions fermées** : la population de [[Wehrau]] (5 350), le **scénario d'ouverture — une crue sur la rive gauche**, le **capital politique en un chiffre**, et la durée d'une partie. → [[Décisions arrêtées]] 13d · 23b · 16b · 14b
- **Système neuf : les [[Milestones]]** — des jalons cumulables, pas des fins. Ce qui les rend durs est un coût d'opportunité : *la rareté est dans le calendrier, pas dans les règles*. → 9b
- ⏸️ **La durée d'une partie passe de bloquante à reportée** : le jeu n'a **pas de fin imposée**, la rejouabilité vient du redémarrage dans une autre direction. → 14c
- Brainstorm importé sur les **références, le positionnement et l'UI** — non digéré, 9 décisions et 7 questions y attendent d'être remontées. → [[00 - Brainstorming]]

**2026-08-10**
- La **rivière est un îlot**, plus une ligne → [[Géométrie et données]]
- ~~Tracé manuel, extraction abandonnée~~ → **la carte générée est la source de vérité**, le tracé manuel devient un outil de retouche → [[Pipeline QGIS]]
- ~~Prototype = Altstadt~~ → **prototype = [[Wehrau]], petite ville entière**. Gain : l'amont/aval entre dans le prototype → [[Périmètre et coupes]]
- **La ville est qualifiée** : 13 sous-types, 17 exceptions, quatre plaies de 1965 → [[Wehrau]]
- **Les attributs dérivés sont calculés** : 12 par îlot, 4 par tronçon. La carte n'est plus un dessin, elle est **simulable** → [[Pipeline QGIS]]
