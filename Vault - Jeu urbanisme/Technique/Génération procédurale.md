---
tags: [technique, procédural, 3d, actif]
statut: 🎯 phase active depuis le 2026-08-11
maj: 2026-08-11
---

# Génération procédurale

C'est le **moteur de la beauté** du jeu, pas un raccourci. Le joueur écrit la structure, le système écrit le grain. → [[Vision et prémisses]]

## 🎯 La phase actuelle : Wehrau à t0, crédible et regardable

Le prototype ne cherche plus d'abord un système de décisions. Il cherche **une ville qui existe** — [[Wehrau]] au temps zéro, avant toute décision et avant toute crue, visible en 3D et crédible à l'œil. → [[Décisions arrêtées]] 49

Pourquoi cet ordre : une crue est une **perturbation d'un état**, et l'état n'existait pas. Chaque effet chiffré du classeur s'appliquait à du vide. Même chose pour le procédural — on ne peut pas juger un générateur sans avoir une ville à regarder.

**Ce qui rend cette phase tenable** : la ville est déjà entièrement décrite dans les données. Il n'y a rien à modéliser, il y a un lecteur à écrire.

| La donnée existante | Ce qu'elle produit en 3D |
|---|---|
| 69 polygones d'îlots | les volumes, par extrusion |
| `hauteur`, 2 à 9 niveaux | × 3 m — la silhouette |
| `altitude_relative` | la vallée, sans MNT |
| 178 polylignes + `largeur_m` | les rubans de voirie |
| `sous_type`, 13 valeurs | la teinte et le grain de chaque volume |
| `impermeabilise` · `canopee` | le sol : minéral, planté, entre les deux |
| `charge` | combien de voitures instancier |

### ⚠️ Le piège du terrain

`altitude_relative` est **une valeur par îlot**. Extruder chaque îlot depuis la sienne donne un terrain en escalier : une marche à chaque limite, des trous entre les rues et les blocs. Invisible en 2D, criant en 3D.

La sortie n'est pas d'interpoler après coup mais de **rejouer la règle qui a produit l'altitude** — la pente qui s'adoucit vers l'aval, quatre lignes en haut de `04_deriver_attributs.py`. On obtient un champ continu, échantillonnable partout, et les îlots viennent s'y poser. Bonus : le terrain et les données ne peuvent plus diverger. → [[Décisions arrêtées]] 32e

### Où cette phase s'arrête volontairement

**À la maquette de masses.** Un îlot extrudé est un pâté plein, pas un ensemble de bâtiments — le registre d'une maquette d'agence d'urbanisme. C'est assez pour voir la ville, et c'est même le bon registre pour un jeu qui parle de décisions et pas de construction.

La subdivision en parcelles (étape 1 ci-dessous) **ne fait pas partie de cette phase**. C'est le point dur du pipeline, et l'attaquer maintenant reviendrait à changer de projet.

## Le principe de rendu

> La carte est une base de données d'entités portant des **attributs continus**. Le rendu est une **fonction pure de ces attributs**.

Conséquence : les résultats visuels sont **composables** sans avoir à auteur chaque combinaison. C'est ce qui rend l'ampleur du jeu tenable en solo.

Corollaire à tenir dès la maquette de masses : **aucun état visuel n'est posé à la main dans une scène.** Si un rendu ne s'explique pas par une valeur de simulation, c'est un bug de design. → [[Direction artistique]]

## Le pipeline, étape par étape

| Étape | Difficulté | Phase actuelle |
|---|---|---|
| 1. Subdivision de l'îlot en parcelles | 🔴 **2–4 semaines d'itération — le point dur** | ⏸️ hors phase |
| 2. Parcelle → emprise (offset) | 🟢 | ⏸️ hors phase |
| 3. Extrusion en volume | 🟢 | 🎯 **c'est la phase** |
| 4. Détail low-poly | 🟡 | ⏸️ |
| 5. Scatter au sol (arbres, mobilier) | 🟡 | 🟡 partiellement — la canopée |
| 6. **Carrefours** | 🔴 le plus dur de tous | ⏸️ hors phase |

## ⚠️ La contrainte architecturale du projet

> **La parcelle est l'entité persistante, pas l'îlot. Elle est seedée individuellement.**

Raison : quand le joueur densifie un secteur, **seules les parcelles concernées se régénèrent** — l'îlot entier ne se réinitialise pas. Sinon la mémoire visuelle de la transformation est détruite, et cette mémoire est le cœur du jeu.

C'est à décider **avant** d'écrire la première ligne du générateur de parcelles. Irréversible en pratique. La maquette de masses ne la contredit pas : elle travaille à l'échelle de l'îlot et sera jetée.

## Le raccord des bâtiments voisins — ce que Townscaper offre et qu'on n'aura pas

L'aspect de [[Direction artistique]] repose chez Townscaper sur une **grille de quadrilatères** où les modules se raccordent automatiquement. Sur des parcelles libres issues de la polygonisation, ce raccord est un travail en plus, et personne ne l'a fait à notre place. → [[Questions ouvertes]] n°16

## Ce qui se répète doit s'instancier

Arbres, voitures, voitures garées, mobilier : **une seule instance multiple par famille**, pas un nœud par objet. Le geste se prend au début, pas après. Même règle pour tout ce qui est nombreux et éphémère — piétons, particules : ça passe par une réserve d'objets réutilisés, jamais par une création/destruction continue.

## Contrainte du « avant / après »

Le jeu porte sur la **transformation** : chaque élément a besoin d'**au moins deux états**. Donc la géométrie doit être **paramétrique**, pas modélisée à la main. C'est ce qui a disqualifié le pixel art. → [[Direction artistique]]

**Voir aussi** : [[Moteur et architecture]] · [[Géométrie et données]] · [[Plan 3 mois]]
