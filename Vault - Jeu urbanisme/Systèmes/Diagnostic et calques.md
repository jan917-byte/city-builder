---
tags: [système, ui, da]
statut: arrêté
maj: 2026-08-12
---

# Diagnostic et calques

## Le rôle stratégique

**Le diagnostic est l'activité principale entre deux décisions.** C'est ce qui résout le risque de spectateur en temps continu : pendant que ça se construit, le joueur lit ses cartes thermiques, repère un effet de bord, prépare l'intervention suivante. **L'attente devient de l'observation.**

Cadeau caché : ces vues thématiques sont **belles**, elles sont mon métier, et elles règlent en partie le problème de style graphique. Une ville qui bascule en carte de chaleur, c'est un moment visuel fort et pas cher.

## Architecture des calques

Trois calques parents, avec sous-calques :

### 🌳 Vert / climat
canopée · îlot de chaleur · perméabilité · biodiversité

### 🚋 Mobilité
axes · desserte TC · flux · accessibilité piétonne · stationnement

### 👥 Social / économique
densité · loyers · mixité · commerce · vulnérabilité

### Candidats supplémentaires
💧 eau / ruissellement · ⚡ énergie · ⏳ temps et phases de chantier

## 🎯 Chaque calque est apparié à un chiffre — arrêté le 2026-08-12

> **Aucun chiffre global sans son calque.** Le chiffre dit *que* ça bouge, le calque dit *où*.

Ce que la règle change ici : les calques cessent d'être une bibliothèque qu'on consulte si on y pense. **Chacun des sept [[Indicateurs globaux]] est la porte d'entrée d'un calque**, donc le bandeau devient le sommaire du diagnostic.

| L'indicateur | Ouvre le calque |
|---|---|
| 🌡️ Surchauffe | îlot de chaleur |
| 💧 La ville exposée | aléa + fil de l'eau |
| 🚗 L'emprise voiture | stationnement + charge |
| 🏠 Les habitants d'origine | riverain |
| 🏭 CO2 | trafic + chauffage |
| ☀️ Les toits qui produisent | potentiel solaire |
| 🚋 Ce qui est desservi | desserte TC |

Sans cet appariement, un chiffre global est une **moyenne**, et une moyenne efface l'injustice géographique — planter au cœur ancien ou au Ried donnerait le même écart à l'écran. C'est aussi ce qui empêche le bandeau de devenir un tableau de bord qu'on optimise. → [[Décisions arrêtées]] 53 · [[Pièges connus]]

**Ce que ça ajoute à la liste des calques ci-dessus** : le **potentiel solaire** et le **CO2 par îlot** sont neufs, et l'eau cesse d'être un « candidat supplémentaire » pour devenir un calque de premier rang — le jeu s'ouvre dessus.

## Hiérarchie de lecture

1. **Les cartes thématiques font le travail de diagnostic primaire** (heat maps)
2. **Le clic sur un îlot ou un bâtiment** devient une vérification, une curiosité, une histoire — **pas la mécanique obligatoire de collecte d'info**

Cette hiérarchie est importante : elle évite le jeu où il faut cliquer 40 bâtiments pour comprendre quelque chose.

## Le mode « plan »

La ville peut être vue en 3D complète, ou filtrée pour ne montrer qu'une couche de données. Basculer entre monde et plan est aussi une **proposition narrative**, pas seulement une limite technique. → [[Direction artistique]]

**Voir aussi** : [[Indicateurs globaux]] · [[Boucle de jeu]] · [[Géométrie et données]]
