---
tags: [technique, da, actif]
statut: 🎯 phase active depuis le 2026-08-12 — référence Townscaper depuis le 2026-08-11
maj: 2026-08-12
---

# Direction artistique

> 🔄 **Ce n'est plus une décision reportable.** Tant que la DA attendait le vertical slice, elle pouvait dormir. La phase actuelle est de **rendre [[Wehrau]] crédible et regardable à t0** — il faut donc un registre visuel maintenant, quitte à en changer.
>
> 🎯 **Et depuis le 2026-08-12, ce n'est plus seulement un registre à choisir : c'est le travail en cours.** → [[Décisions arrêtées]] 51

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

## 🎯 Ce que « belle » veut dire ici — depuis le 2026-08-12

La DA cesse d'être un registre à choisir pour devenir **le travail en cours**. → [[Décisions arrêtées]] 51 · [[Plan 3 mois]] phase A

Le seuil n'est plus *« on doit sentir le lieu »* mais **« on doit avoir envie de la regarder, et croire qu'on y habite »**. Ce qui manque à la maquette, dans l'ordre où ça change l'image :

| | |
|---|---|
| **Des bâtiments, pas des pâtés** | 63 îlots extrudés d'un bloc. C'est le registre de la maquette d'agence — il a fait son travail, il ne fait plus illusion. La subdivision en parcelles entre en phase → [[Génération procédurale]] |
| **Des toits** | ce que 42b promettait de Townscaper et qu'on n'a pas encore : c'est la **silhouette** qui porte la lisibilité, pas le détail |
| **Un sol qui a une matière** | un seul matériau paramétré par `impermeabilise`, `canopee` et l'usure couvre asphalte neuf, asphalte fissuré, pavé drainant, plateau piéton. **Pas cinq textures — une recette et trois curseurs, qui sont déjà des attributs** |
| **Du mouvement** | une rue à `charge = 1,00` doit être désagréable à regarder avant d'être lue → n°18 |
| **Une lumière qui creuse** | la vallée ne se lit à aucune exagération. 9 m sur 898 m : ce n'est pas le relief qu'il faut forcer, c'est l'ombre |

## ⚠️ La règle de production, qui remplace la limite de calendrier

L'ancien garde-fou était une date — *une semaine, et si j'ajoute des toits j'ai changé de projet*. Il tombe avec 51. Ce qui le remplace tient en une question, à poser à **chaque tâche de contenu** → 52 :

> **Si je devais en faire 200, est-ce que je tiendrais ?**
> Si non, la tâche n'est pas de peindre l'asset, c'est d'**écrire le générateur**.

Six conséquences concrètes, toutes vérifiables :

1. **Une recette, jamais un asset.** Un jeu de *transformation* a besoin d'au moins **deux états par élément** — un asset peint double le travail à chaque état, un graphe paramétré expose l'état comme un curseur.
2. **Le détail va dans la texture, pas dans la géométrie.** Le budget polygonal appartient à la **silhouette**, seule chose qui se lit à cette distance. Une normal map rend un mur sculpté sans un polygone de plus.
3. **Le matériau lit la géométrie.** L'usure sur les arêtes, la salissure dans les creux, la variation de teinte : on écrit la logique une fois, elle s'applique à tout le kit. Un bâtiment délaissé et le même réhabilité = **le même maillage, deux réglages**.
4. **La végétation est un générateur**, pas une bibliothèque d'arbres. Paramétré par essence, âge et emprise — ce qui donne gratuitement l'arbre qui **grandit** au lieu d'apparaître. C'est déjà en place, et c'est le retour visuel le moins cher du projet.
5. **Les transitions sont interpolées, pas animées.** Démolition, surélévation, changement d'usage : deux états paramétriques et **un système de chantier partagé** — échafaudage, palissade, poussière. Un système réutilisable vaut mieux que cinquante animations, et le chantier est lui-même un signal : il dit *ta décision est en cours*, ce dont un jeu aux effets lents a précisément besoin.
6. **Tout ce qui est nombreux et éphémère passe par une réserve d'objets réutilisés.** Voitures, piétons, particules. Le geste se prend au début.

⚠️ **Ce que cette liste ne dit pas** : les outils de matériaux procéduraux les plus connus sont payants. À évaluer avant de s'engager — un shader écrit directement dans Godot fait peut-être l'affaire, et il n'a pas d'abonnement.

## D'où vient la qualité perçue

Pas de la complexité artistique, mais de :

1. **Une palette disciplinée** — 8–10 couleurs, dérivées des conventions de zonage réelles. Elle est **entière dès t0** : c'est la part de sol minéral qui fait la différence, pas la saturation
2. **Une typographie forte** — Inter ou IBM Plex Sans
3. **Une épaisseur de trait constante**
4. **Des micro-animations**

## Deux références d'interface : Frostpunk 2 et Democracy 4

Townscaper donne le registre de la **ville**. Il ne dit rien de l'**interface** — il n'en a pas. Ces deux-là si, et par les deux bouts : l'un montre ce qu'il faut voler, l'autre ce qu'il ne faut jamais faire.

### **Frostpunk 2** — une variable rendue en matière

✅ **À voler : la jauge de tension en liquide noir**, qui monte et frémit vers l'ébullition. Ce n'est pas un pourcentage, c'est une **matière qui se comporte**. On lit l'état sans lire de chiffre.

C'est exactement la règle du projet appliquée à l'interface : *aucun état visuel posé à la main, tout dérive d'un attribut*. À appliquer en priorité aux attributs qui portent déjà le propos — `canopee`, `impermeabilise`, `stationnement`. Une canopée de 14 % doit **se voir comme une quantité**, pas s'afficher comme « 14 % ».

⚠️ **Et son raté, qui est le risque le plus direct ici : UI blanche sur neige blanche.** Le jeu a été retardé pour corriger son interface et ça n'a pas suffi. Une palette pastel et claire pose **le même problème** : il n'y a plus de fond sombre où poser un panneau. Le contraste de l'interface est donc une contrainte de DA, pas un réglage de fin de projet. → [[Questions ouvertes]]

Les autres ratés notés, à ne pas répéter : barre de menu horizontale en bas, icônes trop serrées, scroll latéral quand les options s'accumulent, mis-clics fréquents.

> Le **texte** de l'interface a ses propres interdits — majuscules intégrales, tiret cadratin, emoji décoratif, ton d'application. Ils sont listés dans [[Ton et règles d'écriture]] et valent pour chaque libellé posé dans Godot.

### **Democracy 4** — le contre-exemple

❌ **La logique est juste, l'image est un tableur avec des flèches.** Tout le contenu du jeu est vrai et tout est illisible, parce que rien n'est jamais rendu : le graphe causal est affiché *comme un graphe*.

C'est la démonstration par l'absurde du modèle **carte → UI → carte** : là-bas il n'y a pas de carte, donc pas de récompense à regarder, donc le graphe doit tout porter. Ici la ville existe — **on pille la logique, on jette l'image.** → [[Décisions]] · [[Diagnostic et calques]]

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
