---
tags: [technique, da, actif]
statut: référence de travail — Townscaper depuis le 2026-08-11
maj: 2026-08-11
---

# Direction artistique

> 🔄 **Ce n'est plus une décision reportable.** Tant que la DA attendait le vertical slice, elle pouvait dormir. La phase actuelle est de **rendre [[Wehrau]] crédible et regardable à t0** — il faut donc un registre visuel maintenant, quitte à en changer.

## La direction retenue

**Référence de travail : Townscaper.** Elle remplace *Mini Motorways*. → [[Décisions arrêtées]] 42b

Ce qu'on lui prend, et qui tient en cinq mots : **volumes doux, palette pastel, zéro texture**.

| Ce qu'on prend | Pourquoi |
|---|---|
| Aucune texture — la couleur est portée par le matériau | Un `sous_type` = une teinte. Rien à peindre, jamais |
| Des volumes simples aux arêtes adoucies | La lisibilité vient de la silhouette, pas du détail |
| Une occlusion ambiante marquée | C'est elle, et pas la géométrie, qui donne la profondeur |
| Une palette courte et sourde | 8–10 teintes, tenues → voir plus bas |
| Une petite échelle, presque une maquette | Wehrau fait 0,93 km². On voit la ville entière d'un coup |
| Aucun bruit d'interface dans la vue 3D | Les calques sont l'interface → [[Diagnostic et calques]] |

La [[Génération procédurale]] reste le moteur : chaque volume est extrudé d'un attribut, aucun n'est modélisé.

## Ce qu'on ne prend pas : la géométrie

Le brainstorm du 2026-08-11 avait déjà découpé Townscaper en deux couches, et sa conclusion tient : **on garde la couche rendu, on écarte la couche géométrie.** → `Brainstorming/2026-08-11_brainstorm_refs-positionnement-ui.md` §3

| Couche | |
|---|---|
| **Rendu** — aplats sans texture, palette resserrée, occlusion douce, lumière fixe, caméra calme, zéro interface | ✅ **reproductible en solo. La voie la moins chère vers le beau** |
| **Géométrie** — grille de quadrilatères irréguliers, modules authorés pour chaque configuration de coins | ❌ troisième jeu de son auteur avec cette technologie. Des années de spécialiste |

Mais le coût n'est pas le vrai argument. **Trois conflits de design**, et chacun touche un pilier :

1. **Townscaper ré-effondre le voisinage à chaque clic.** C'est l'inverse exact de *la parcelle est l'entité persistante* — sans laquelle la mémoire visuelle de la transformation est détruite. → [[Décisions arrêtées]] 35
2. **Townscaper n'a pas de sol.** Ni rue, ni asphalte, ni stationnement. La seule chose qu'il n'a jamais eu à résoudre est **le sujet entier de ce jeu**.
3. **Townscaper ne sait produire que du charme.** Voir ci-dessous — c'est le conflit le plus dangereux.

Et la géométrie d'ici est **l'îlot issu de la polygonisation d'une couche ligne**, la grille étant réservée aux champs continus. → 27 · 29 · [[Géométrie et données]]

Conséquence concrète : sur des parcelles libres, **les raccords entre bâtiments voisins ne se feront pas tout seuls.** C'est un travail en plus, et il est réel. → [[Questions ouvertes]] n°16

## ⚠️ Le piège, et il est sérieux

Townscaper est **beau tout de suite et sans effort**. C'est un jouet : le joueur n'a rien à perdre, rien à réparer, et chaque clic embellit. Si l'*avant* est déjà joli, le joueur n'a aucune raison d'agir.

Mais l'erreur symétrique est pire, et c'est un cliché : **une ville de départ grise et triste**. Le ton du projet est *dur mais possible, jamais cynique*, et la ville de départ est **ordinaire, pas dystopique**. → [[Ton et règles d'écriture]] · [[Décisions arrêtées]] 5

### Wehrau à t0 : un peu pastel, et grise quand même

**La règle** : Wehrau ne s'assombrit pas et ne se désature pas. Elle est **déjà dans la palette du jeu** dès la première image — des bâtiments doux, chaleureux, agréables à regarder. **Ce qui est gris, c'est le sol.**

Et le sol n'est pas gris à cause d'un filtre : il est gris **parce que la ville est effectivement minérale**. 28 % de surface imperméabilisée, 14 % de canopée, 4 587 places de stationnement, un quai en voie rapide de 22 m. La grisaille n'est pas une teinte posée sur l'image, c'est **une proportion de l'image** — et elle est déjà dans les données.

> Les bâtiments sont pastel. Le sol est de l'asphalte. Le joueur voit une ville qu'il aime bien, posée sur un sol qu'il n'aime pas.

Deux conséquences :

- **Aucune interprétation possible en dystopie.** Rien n'est délabré, rien n'est fissuré, rien ne pleut. C'est une ville allemande moyenne un mardi ordinaire, et elle est plutôt jolie. Ce qu'on lui reproche est une **question d'aménagement**, pas de misère.
- **La marge est visible sans être donnée.** On voit tout de suite ce qui manque — des arbres, un sol qui boit, une berge qu'on approche — parce que la place existe et qu'elle est occupée par autre chose. Le joueur n'a pas besoin qu'on le lui dise.

### Ce qui bouge, et ce qui ne bouge jamais

| | |
|---|---|
| **Les teintes** | fixes. Une teinte par `sous_type`, jamais modifiée — sinon ce n'est plus la même ville |
| **La lumière** | fixe et calme. Pas de météo d'ambiance, pas de golden hour, pas de ciel gris |
| **La saturation** | bornée et déjà haute à t0. Elle monte un peu, elle ne part pas de zéro |
| **La part minérale du sol** | 🎯 **c'est elle qui porte tout** — dérivée de `impermeabilise`, `canopee`, `stationnement` |

C'est la règle générale du projet appliquée à la couleur : *aucun état visuel posé à la main, tout dérive d'un attribut.*

> **Le brief est plus dur que celui de Stålberg** : rendre la banalité périurbaine sans la rendre laide ni cynique, et faire que l'après soit visiblement meilleur. Personne ne l'a résolu — c'est précisément le terrain.

## D'où vient la qualité perçue

Pas de la complexité artistique, mais de :

1. **Une palette disciplinée** — 8–10 couleurs, dérivées des conventions de zonage réelles. Elle est **entière dès t0** : c'est la part de sol minéral qui fait la différence, pas la saturation
2. **Une typographie forte** — Inter ou IBM Plex Sans
3. **Une épaisseur de trait constante**
4. **Des micro-animations**

## ❌ Pixel art — écarté

- Pas paramétrique
- Impose une grille et une caméra fixe
- **Double le travail d'assets** à cause du avant/après
- C'est un métier de spécialiste (⚠️ *Terra Nil* en référence d'avertissement)

## Pistes gardées en réserve

- **La maquette d'architecte** — carton, bois, ombres douces, tilt-shift. Elle cherchait la même chose que Townscaper : rendre désirable une ville de départ ordinaire. À reprendre si le pastel s'avère trop tendre.
- **Un shader basse résolution à palette limitée** par-dessus le low-poly, si on veut la chaleur du pixel sans ses coûts.

## Autres directions explorées et écartées

Low-poly flat-shaded façon *Mini Motorways* (remplacée) · rendu axonométrique collage · risographie · plan cadastral animé

**Voir aussi** : [[Génération procédurale]] · [[Périmètre et coupes]] · [[Diagnostic et calques]]
