---
tags: [technique, procédural, 3D]
statut: étudié, non commencé
---

# Génération procédurale

C'est le **moteur de la beauté** du jeu, pas un raccourci. Le joueur écrit la structure, le système écrit le grain. → [[Vision et prémisses]]

## Le principe de rendu

> La carte est une base de données d'entités portant des **attributs continus**. Le rendu est une **fonction pure de ces attributs**.

Conséquence : les résultats visuels sont **composables** sans avoir à auteur chaque combinaison. C'est ce qui rend l'ampleur du jeu tenable en solo.

## Le pipeline, étape par étape

| Étape | Difficulté |
|---|---|
| 1. Subdivision de l'îlot en parcelles | 🔴 **2–4 semaines d'itération — le point dur** |
| 2. Parcelle → emprise (offset) | 🟢 |
| 3. Extrusion en volume | 🟢 |
| 4. Détail low-poly | 🟡 |
| 5. Scatter au sol (arbres, mobilier) | 🟡 |
| 6. **Carrefours** | 🔴 le plus dur de tous |

## ⚠️ La contrainte architecturale du projet

> **La parcelle est l'entité persistante, pas l'îlot. Elle est seedée individuellement.**

Raison : quand le joueur densifie un secteur, **seules les parcelles concernées se régénèrent** — l'îlot entier ne se réinitialise pas. Sinon la mémoire visuelle de la transformation est détruite, et cette mémoire est le cœur du jeu.

C'est à décider **avant** d'écrire la première ligne du générateur. Irréversible en pratique.

## Réduction de périmètre possible

Utiliser des **empreintes OSM existantes comme slots de parcelles persistantes** supprime l'étape la plus dure du pipeline pour 90 % de la ville.

⚠️ Contradit la décision « ville fictive, pas d'OSM ». À arbitrer. → [[Questions ouvertes]]

## Contrainte du « avant / après »

Le jeu porte sur la **transformation** : chaque élément a besoin d'**au moins deux états**. Donc la géométrie doit être **paramétrique**, pas modélisée à la main.

C'est ce qui a disqualifié le pixel art. → [[Direction artistique]]

**Voir aussi** : [[Moteur et architecture]] · [[Géométrie et données]]
