---
tags: [moc, projet]
statut: vivant
maj: 2026-08-11
---

# 🏙️ Projet jeu — city-builder de transformation urbaine

> Un city-builder PC où le joueur ne construit pas : il **décide**. Une ville moyenne ordinaire, voiture-dépendante, qu'on transforme sur 20 ans. Objectif : **inspirer**, pas simuler la bureaucratie.

**Titre de travail** : aucun · candidats dans [[Marketing et Steam]]
**Où j'en suis** : mois 1, semaines 1 et 2 bouclées — la carte est **simulable** et la ville a des **stocks**
**Phase actuelle** 🎯 : **[[Wehrau]] à t0, crédible et regardable en 3D**, avant toute décision → [[Décisions arrêtées]] 49
**Périmètre du prototype** : [[Wehrau]], une petite ville entière — **pas** un quartier de [[Vallmar]]
**Prochaine action concrète** : la maquette de masses dans Godot, une semaine, pas plus → [[Génération procédurale]] · [[Plan 3 mois]]

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
- [[Pipeline QGIS]] — le GeoPackage, les trois scripts, ce qui reste à faire
- [[Génération procédurale]] 🎯 — **la phase active** : la maquette de masses de t0
- [[Moteur et architecture]] — Godot 4, GDScript vs C#
- [[Direction artistique]] — **Townscaper**, palette qui se réchauffe avec la ville

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

Et deux questions neuves, nées de la phase actuelle : **le raccord des bâtiments voisins** (n°16) et **Wehrau est un dortoir, on assume ?** (n°17). → [[Questions ouvertes]]

## 🔄 Révisions récentes

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
