---
tags: [moc, projet]
statut: vivant
maj: 2026-08-10
---

# 🏙️ Projet jeu — city-builder de transformation urbaine

> Un city-builder PC où le joueur ne construit pas : il **décide**. Une ville moyenne ordinaire, voiture-dépendante, qu'on transforme sur 20 ans. Objectif : **inspirer**, pas simuler la bureaucratie.

**Titre de travail** : aucun · candidats dans [[Marketing et Steam]]
**Où j'en suis** : mois 1, semaine 1 — **la carte existe et elle est qualifiée**
**Périmètre du prototype** : [[Wehrau]], une petite ville entière 🎯 — **pas** un quartier de [[Vallmar]]
**Prochaine action concrète** : la table d'adjacence, puis les attributs dérivés → [[Pipeline QGIS]]

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
- [[Fins et pluralisme]] — le problème non résolu des archétypes

## 🗺️ La ville

- [[Wehrau]] 🎯 — ~5 350 hab., **le prototype** : une petite ville qu'on voit en entier
- [[Vallmar]] — 112 000 hab., la ville du jeu complet. Design en réserve
  - [[Altstadt]] · [[Les Vergnes]] · [[La Fonderie]] · [[Quartier Gare]] · [[Hochfeld]] · [[Le Ried]]

## 🔧 Technique

- [[Géométrie et données]] — l'îlot comme entité, la rue comme adjacence
- [[Pipeline QGIS]] — le GeoPackage, les trois scripts, ce qui reste à faire
- [[Génération procédurale]] — parcelles persistantes, volumes paramétriques
- [[Moteur et architecture]] — Godot 4, GDScript vs C#
- [[Direction artistique]] — low-poly, Mini Motorways, système de calques

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

1. **Combien de temps dure une partie ?** → bloque l'équilibrage de tout le reste. Voir [[Questions ouvertes]]
2. **Le capital politique est-il un chiffre ou plusieurs groupes ?** → [[Ressources]]
3. **Le nom de la ville du prototype** — « Wehrau » et « l'Ilse » sont proposés, pas arrêtés. Se renomme en une commande tant que rien n'est codé. [[Wehrau]]

## 🔄 Révisions récentes (2026-08-10)

- La **rivière est un îlot**, plus une ligne → [[Géométrie et données]]
- ~~Tracé manuel, extraction abandonnée~~ → **la carte générée est la source de vérité**, le tracé manuel devient un outil de retouche → [[Pipeline QGIS]]
- ~~Prototype = Altstadt~~ → **prototype = [[Wehrau]], petite ville entière**. Gain : l'amont/aval entre dans le prototype → [[Périmètre et coupes]]
- **La ville est qualifiée** : 13 sous-types, 17 exceptions, quatre plaies de 1965 → [[Wehrau]]
