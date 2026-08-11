---
tags: [moc, projet]
statut: vivant
maj: 2026-08-12
---

# 🏙️ Projet jeu — city-builder de transformation urbaine

> Un city-builder PC où le joueur ne construit pas : il **décide**. Une ville moyenne ordinaire, voiture-dépendante, qu'on transforme sur 20 ans. Objectif : **inspirer**, pas simuler la bureaucratie.

**Titre de travail** : aucun · candidats dans [[Marketing et Steam]]
**Où j'en suis** : mois 1 bouclé — la carte est **simulable**, la ville a des **stocks**, et **elle se joue** : on clique, on décide, vingt ans passent
**Phase actuelle** 🎯 : **une ville crédible et belle** — parcelles, toits, trafic, sol. *Ensuite* chaque indicateur, système et décision **un par un** → [[Décisions arrêtées]] 51
**Périmètre du prototype** : [[Wehrau]], une petite ville entière — **pas** un quartier de [[Vallmar]]
**Prochaine action concrète** : la subdivision de l'îlot en parcelles — le point dur, 2 à 4 semaines → [[Génération procédurale]] · [[Plan 3 mois]]
**Le garde-fou** ⚠️ : ce n'est plus une date, c'est *« si je devais en faire 200, est-ce que je tiendrais ? »* → 52

---

## 🧭 Fondations

- [[Vision et prémisses]] — les deux bases non négociables, ce que le jeu est et n'est pas
- [[Ton et règles d'écriture]] — « dur mais possible », les clichés interdits
- [[Boucle de jeu]] — les 60 secondes qui se répètent
- [[Pièges connus]] — la liste des façons de rater ce projet

## ⚙️ Systèmes

- [[Ressources]] — argent + capital politique
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
- [[Questions ouvertes]] — ⚠️ dont une bloquante
- [[Glossaire]] — vocabulaire du projet, base de l'i18n
- [[Journal]] — ce que j'apprends à chaque session

---

## ⚠️ Les 3 trucs à trancher maintenant

✅ **Tranché le 2026-08-11** : la crue d'ouverture (rive gauche), 5 350 habitants, le capital politique en **un chiffre**, les [[Milestones]] cumulables, 2 h de partie, **la ville de t0 avant les décisions** (49) et **Townscaper** comme référence de travail (42b).

1. **D'où vient l'argent ?** Budget fixe ou recettes dépendant de la ville. → [[Ressources]]
2. **Le deuxième axe des fins** — le vieux problème, avec un candidat neuf : « personne n'a été chassé ». → [[Fins et pluralisme]]
3. **Le nom** — « Wehrau » et « l'Ilse » sont proposés, pas arrêtés. Se renomment en une commande tant que rien n'est codé. → [[Wehrau]]

🔴 **Et deux qui bloquent la phase A**, à trancher **avant** d'écrire le générateur de parcelles :
- **n°16 — le raccord des bâtiments voisins.** Endormie par la maquette de masses (un pâté plein n'a pas de voisin à coudre), **réveillée par les parcelles** : deux parcelles mitoyennes vont se toucher pour de bon, et dans un tissu de maisons de ville le mitoyen *est* la forme urbaine.
- **35 — la parcelle est-elle bien l'entité persistante ?** Déjà arrêtée 🔒, mais elle n'a jamais été mise à l'épreuve du code. Irréversible en pratique une fois le générateur écrit.

Et deux autres questions ouvertes : **n°17** — Wehrau est un dortoir, on assume ? — et **n°18**, neuve : **le trafic, des voitures ou un flux ?** → [[Questions ouvertes]]

## 🔄 Révisions récentes

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
