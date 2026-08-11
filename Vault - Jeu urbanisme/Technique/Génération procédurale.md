---
tags: [technique, procédural, 3d, actif]
statut: 🎯 phase active — la subdivision en parcelles y entre le 2026-08-12
maj: 2026-08-12
---

# Génération procédurale

C'est le **moteur de la beauté** du jeu, pas un raccourci. Le joueur écrit la structure, le système écrit le grain. → [[Vision et prémisses]]

## 🎯 La phase actuelle : une ville crédible et belle

La maquette de masses existe et se joue. Ce qu'elle montre reste **63 pâtés pleins** : un îlot extrudé n'est pas un ensemble de bâtiments. La phase ne s'arrête donc plus là — le seuil devient *« avoir envie de la regarder, et croire qu'on y habite »*. → [[Décisions arrêtées]] 51

🔄 **La subdivision en parcelles entre en phase.** Elle en était explicitement exclue : « le point dur du pipeline, et l'attaquer maintenant reviendrait à changer de projet ». C'est bien un changement de projet, et il est assumé — 2 à 4 semaines d'itération à lui seul.

**Ce qui rend cette phase tenable** : la ville est déjà entièrement décrite dans les données. Il n'y a rien à modéliser, il y a des générateurs à écrire.

> **Le test qui remplace la limite de calendrier** (52) : *si je devais en faire 200, est-ce que je tiendrais ?* Si non, la tâche n'est pas de peindre l'asset, c'est d'écrire le générateur.

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

### Ce qui reste hors phase, et le reste

- **Les intérieurs, les façades détaillées, les fenêtres modélisées.** Le détail va dans la texture et la normal map, jamais dans la géométrie : le budget polygonal appartient à la **silhouette**, qui est ce qui se lit à cette distance.
- **Les agents individuels au-delà de l'ambiance.** Voir « le trafic » plus bas — c'est une décision coûteuse à inverser, et elle n'est pas prise.

## Le principe de rendu

> La carte est une base de données d'entités portant des **attributs continus**. Le rendu est une **fonction pure de ces attributs**.

Conséquence : les résultats visuels sont **composables** sans avoir à auteur chaque combinaison. C'est ce qui rend l'ampleur du jeu tenable en solo.

Corollaire à tenir dès la maquette de masses : **aucun état visuel n'est posé à la main dans une scène.** Si un rendu ne s'explique pas par une valeur de simulation, c'est un bug de design. → [[Direction artistique]]

## Le pipeline, étape par étape

| Étape | Difficulté | Où on en est |
|---|---|---|
| 1. Subdivision de l'îlot en parcelles | 🔴 **2–4 semaines d'itération — le point dur** | 🎯 **c'est la phase** |
| 2. Parcelle → emprise (offset) | 🟢 | 🟢 le geste existe : `04b` fait déjà reculer l'îlot de la demi-largeur de rue |
| 3. Extrusion en volume | 🟢 | ✅ fait à l'échelle de l'îlot |
| 4. Détail — toits, gabarits, matériau de sol | 🟡 | 🎯 en phase |
| 5. Scatter au sol (arbres, mobilier) | 🟡 | 🟢 les arbres d'alignement poussent avec `canopee` |
| 6. **Carrefours** | 🔴 ~~le plus dur de tous~~ | 🟡 **largement dissous par 32f** — plus de rubans à raccorder, un vide qui se referme |
| 7. **Le trafic visible** | 🟡 | 🎯 en phase — voir plus bas |

## ⚠️ La contrainte architecturale du projet

> **La parcelle est l'entité persistante, pas l'îlot. Elle est seedée individuellement.**

Raison : quand le joueur densifie un secteur, **seules les parcelles concernées se régénèrent** — l'îlot entier ne se réinitialise pas. Sinon la mémoire visuelle de la transformation est détruite, et cette mémoire est le cœur du jeu.

C'est à décider **avant** d'écrire la première ligne du générateur de parcelles. Irréversible en pratique. La maquette de masses ne la contredit pas : elle travaille à l'échelle de l'îlot et sera jetée.

## Le raccord des bâtiments voisins — ce que Townscaper offre et qu'on n'aura pas

L'aspect de [[Direction artistique]] repose chez Townscaper sur une **grille de quadrilatères** où les modules se raccordent automatiquement. Sur des parcelles libres issues de la polygonisation, ce raccord est un travail en plus, et personne ne l'a fait à notre place. → [[Questions ouvertes]] n°16

## Le trafic — rendre `charge` visible

`charge` est déjà là : une affectation par plus court chemin en temps, dont **l'axe de transit est sorti tout seul** sans qu'on le désigne. Mais rien ne bouge à l'écran, donc la variable la plus politique du jeu est un nombre dans une fiche.

Ce que des voitures apportent, et qui n'est pas décoratif : une rue saturée **se voit** avant d'être lue, et « retirer la voiture de l'axe » cesse d'être une ligne de tableur. C'est la règle générale du projet appliquée au mouvement — *qu'est-ce que ça change à l'écran, sans texte ?*

⚠️ **Une décision très coûteuse à inverser attend ici** : agents individuels ou flux agrégés ? → [[Questions ouvertes]] n°18. Elle n'est pas prise. Ce qui est déjà sûr :

- **Une instance multiple par famille**, jamais un nœud par voiture.
- **Une réserve d'objets réutilisés** pour tout ce qui est nombreux et éphémère — voitures, piétons, particules. Le geste se prend au début, pas après : créer et détruire en continu finit par écrouler les performances.
- **Des tableaux parallèles plutôt que des objets** si le nombre monte, et la boucle isolée derrière une interface propre — comme la géométrie (41).

## Ce qui se répète doit s'instancier

Arbres, voitures, voitures garées, mobilier : **une seule instance multiple par famille**, pas un nœud par objet.

⚠️ **Ce que la maquette a dû concéder le 2026-08-12** : les 63 îlots bâtis et les 174 tronçons sont devenus **un nœud chacun**. Un maillage fusionné ne se sélectionne pas, ne se surligne pas et ne se reteinte pas objet par objet — sans le découpage il n'y a pas de jeu, seulement une image. ~250 draw calls sur 40 000 triangles ne se voient pas. La règle vaut donc pour ce qui est **nombreux et identique**, pas pour ce qui est **cliquable et distinct**.

## Contrainte du « avant / après »

Le jeu porte sur la **transformation** : chaque élément a besoin d'**au moins deux états**. Donc la géométrie doit être **paramétrique**, pas modélisée à la main. C'est ce qui a disqualifié le pixel art. → [[Direction artistique]]

**Voir aussi** : [[Moteur et architecture]] · [[Géométrie et données]] · [[Plan 3 mois]]
