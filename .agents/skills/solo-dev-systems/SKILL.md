---
name: solo-dev-systems
description: Principes de production pour un jeu solo ambitieux — générer l'art par des systèmes (matériaux procéduraux, normal maps, geometry nodes) plutôt que le peindre à la main, faire réagir le monde aux données de simulation, tenir la performance (pooling, data-oriented), et concevoir des systèmes en tension. Utiliser dès que la conversation touche au pipeline art, aux assets, aux textures, à la végétation, aux perfs, au nombre d'entités simulées, à la génération procédurale, au scope d'un dev solo, ou à la question « comment un seul mec peut produire ça » — même si l'utilisateur ne le demande pas explicitement. Utiliser aussi pour arbitrer un choix technique entre « faire à la main » et « construire un système ».
---

# Systèmes plutôt qu'assets — production solo

Distillé d'un devlog de dev solo (Project Tomorrow, Unity) qui produit un rendu « fait par une équipe » sans équipe, sans éditeur, sans IA générative. La règle unique qui traverse tout : **ne jamais produire un asset qu'on peut produire une recette.**

Le test à appliquer à chaque tâche de contenu : *« si je devais en faire 200, est-ce que je tiendrais ? »* Si non, la tâche n'est pas « peindre l'asset », c'est « construire le générateur ».

---

## 1. Matériaux générés par des règles, pas peints

Construire les surfaces à partir de maths — bruits, tile samplers, blends — dans un graphe paramétrique (Substance Designer, ou équivalent gratuit : Material Maker, ou du shader code direct). Un graphe = variations infinies. Changer une valeur met à jour toute la surface.

**Pourquoi ça compte ici :** le jeu est un jeu de *transformation*. Chaque surface a besoin d'au moins deux états (avant / après). Un asset peint à la main double le travail à chaque état ; un graphe paramétré expose l'état comme un simple paramètre. C'est le même argument que la géométrie paramétrique, appliqué à la matière.

**Application concrète :** un seul graphe « revêtement de sol urbain » avec des paramètres `perméabilité`, `usure`, `végétalisation` couvre asphalte neuf, asphalte fissuré, pavé drainant, plateau piéton, rue jardin. Pas cinq textures — une recette et quatre curseurs, qui sont *déjà* des attributs de la simulation.

## 2. Normal maps : du détail sans géométrie

Un quad plat + une normal map = le rendu d'un asset sculpté sans polygone supplémentaire. La normal map ne fait qu'ajouter de l'information d'éclairage.

Pour une ville vue en axonométrie avec des milliers de bâtiments, c'est le levier de perf le plus rentable : garder le kit de volumes paramétriques très simple en géométrie, et mettre toute la richesse (briques, joints, tuiles, feuillage) dans les textures. Le budget polygonal doit aller à la *silhouette* (ce qui se lit à distance), jamais au détail de surface.

## 3. Smart materials qui réagissent à la géométrie

Plutôt que peindre l'usure bâtiment par bâtiment : des matériaux qui lisent la géométrie et posent automatiquement l'usure sur les arêtes, la saleté dans les creux, la variation de teinte. On peint une fois la logique, elle s'applique à tout le kit.

**Corollaire pour ce projet :** ça donne gratuitement la lisibilité du temps et de l'entretien. Un bâtiment « délaissé » et le même bâtiment « réhabilité » = le même mesh, deux réglages du même matériau. La transformation devient visible sans nouvel asset.

## 4. Végétation procédurale (Blender geometry nodes)

Méthode du devlog : poser des sphères simples sur un tronc, puis scatter des *cartes de feuilles* (leaf cards) dessus via geometry nodes. Chaque carte est à six faces pour tenir sous tous les angles. Une texture, et l'arbre se construit seul.

**Directement pertinent** : la canopée est une variable de simulation dans ce projet (ombre, îlot de chaleur, ruissellement). Un générateur d'arbre paramétré par espèce, âge et emprise permet :
- de faire pousser les arbres dans le temps (paramètre âge) au lieu de les faire *apparaître* ;
- d'avoir des essences différentes selon le climat local sans multiplier les assets ;
- de lier directement l'attribut `canopee` à un rendu visible.

Un arbre planté qui grandit sur plusieurs années de jeu est probablement le retour visuel le plus fort et le moins cher du projet.

## 5. Le monde réagit aux données, pas à un script

Point le plus important du devlog : parce que l'environnement est piloté par des données, il réagit en temps réel. L'art répond au gameplay, pas l'inverse. Plus le joueur construit, plus le monde guérit — sol mort qui reverdit, végétation qui revient, eau qui redevient claire.

**C'est exactement le pilier « lisibilité de la transformation ».** Conséquence architecturale à tenir : aucun état visuel ne doit être posé à la main dans une scène. Tout visuel dérive d'une valeur de simulation par parcelle. Si un rendu ne peut pas être expliqué par une variable, c'est un bug de design.

Règle de travail : pour chaque nouvelle variable de simulation, se demander immédiatement *« qu'est-ce que ça change à l'écran, sans texte ? »*. Si la réponse est « rien », la variable est une ligne de tableur, pas un mécanisme de jeu.

## 6. Animation et transition générées

Le devlog résout un problème d'animation en inversant l'ordre : faire tourner l'arme d'abord, le corps suit — la logique produit l'animation au lieu de la rejouer. Coûteux à mettre au point, mais ensuite valable pour toutes les armes.

**Transposition :** les transitions de bâtiments (démolition, surélévation, changement d'usage) ne doivent pas être des animations authorées mais une interpolation entre deux états paramétriques + un système d'effets partagé (échafaudage, palissade de chantier, poussière). Un système de chantier réutilisable > cinquante animations spécifiques. Et le chantier lui-même est un signal de jeu : il dit « ta décision est en cours », ce dont ce projet a précisément besoin puisque les changements sont lents.

## 7. Pooling : réutiliser, ne jamais détruire

Spawner et détruire en continu force l'allocation/libération mémoire et finit par écrouler les perfs. Solution : un pool — l'objet revient dans la réserve au lieu d'être détruit, et ressort au prochain besoin.

Pertinent pour tout ce qui est nombreux et éphémère : piétons, vélos, voitures, trams, particules, feuilles, gouttes, icônes flottantes. À prévoir dès la première version du rendu d'agents, pas après.

## 8. Orientation données : des systèmes, pas des individus

Le devlog passe de « chaque ennemi exécute sa logique » à « un système met à jour tous les ennemis d'un coup » (ECS/DOTS + Burst chez Unity), pour exploiter tous les cœurs CPU.

**Attention, transfert partiel :** DOTS et Burst sont propres à Unity. Sur Godot 4, il n'y a pas d'équivalent intégré. Ce qui se transfère, c'est le *principe* :
- stocker les entités en tableaux parallèles (structure of arrays) plutôt qu'en objets ;
- écrire les mises à jour comme des passes sur ces tableaux (déplacement, puis destination, puis charge) ;
- garder cette boucle en C# derrière une interface propre, comme prévu pour la géométrie ;
- ne pas mettre un nœud Godot par piéton.

Décision à trancher tôt, parce qu'elle est très coûteuse à inverser : agents individuels vs flux agrégés. Le devlog montre que « des milliers d'individus » est atteignable en solo — mais dans un jeu où c'est *le* spectacle. Ici, le spectacle est la transformation urbaine ; les agents ne sont peut-être qu'une couche d'ambiance, auquel cas quelques centaines suffisent et le débat est clos.

## 9. Systèmes en tension = gameplay émergent

Chaque système pousse contre un autre : l'eau maintient en vie mais fait aussi pousser la nourriture ; le terraforming débloque de meilleures défenses mais les défenses protègent le terraforming. Le jeu n'est pas scripté, il est simulé — le gameplay émerge de la tension.

**C'est le critère d'hésitation, formulé côté systèmes.** Un tableau de décisions où chaque ligne est un coût contre un bénéfice ne produit pas d'hésitation ; il produit un calcul. L'hésitation vient de boucles qui se contraignent mutuellement : densifier finance le tram mais consomme le foncier qui servait à la rétention d'eau ; retirer la voiture libère l'espace public mais coupe le commerce de son chaland tant que la fréquence du tram n'a pas monté.

Test à appliquer à toute nouvelle mécanique : *contre quel autre système celle-ci pousse-t-elle ?* Si elle ne pousse contre rien, c'est un curseur, pas une mécanique.

## 10. Production et visibilité

- Page Steam publique tôt ; la wishlist est le signal de marché le plus lisible et le devlog sert à la nourrir.
- Le devlog *est* le marketing. Le format qui marche : montrer les systèmes et les ratés, pas les promesses. Les plans de bugs (animations grotesques, essais loupés) rendent le reste crédible.
- L'angle « un seul mec » est un actif narratif. L'angle « ancien projet civic-tech avec couverture presse » aussi.
- Le devlog affiche « je n'ai pas utilisé d'IA » comme argument de légitimité. C'est une position marketing, pas une règle technique. Si de l'assistance LLM est utilisée sur ce projet, ne pas construire la communication sur une revendication de pureté difficile à tenir — mieux vaut ne rien revendiquer sur ce point que devoir se rétracter.

---

## Ce que ce devlog ne prouve pas

À garder en tête pour ne pas sur-généraliser :
- L'auteur avait déjà un jeu à six chiffres de revenus et une audience — le « départ de zéro » est relatif.
- C'est une vidéo promotionnelle : elle montre la partie qui a marché, pas les 15 mois de calendrier réel.
- Un jeu d'action tolère une simulation approximative tant que ça bouge. Un city-builder d'urbaniste est jugé sur la *justesse* des relations de cause à effet — les gains de perf n'achètent rien si le modèle est faux.
- Substance Designer / Painter sont payants (abonnement). Alternatives à évaluer avant de s'engager : Material Maker, ArmorPaint, ou des shaders écrits directement dans Godot.

## Checklist avant d'ajouter du contenu

1. Est-ce que je fabrique un asset ou une recette ? (recette par défaut)
2. Est-ce que cet élément a ses deux états, avant et après ?
3. Est-ce que son apparence dérive d'une variable de simulation, ou est-elle posée à la main ?
4. Est-ce que le détail est dans la texture plutôt que dans la géométrie ?
5. Si c'est nombreux et éphémère : est-ce que ça passe par un pool ?
6. Contre quel système celui-ci pousse-t-il ?
