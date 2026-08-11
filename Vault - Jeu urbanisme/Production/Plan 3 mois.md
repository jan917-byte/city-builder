---
tags: [production, plan, actif]
statut: 🔄 réordonné le 2026-08-12 — la ville crédible et belle passe devant les systèmes
maj: 2026-08-12
---

# Plan 3 mois

> **Le principe qui gouverne tout** : tant que la question ouverte est *quelles décisions et quels effets*, la traiter dans un outil où **changer d'avis est gratuit**. Le classeur reste cet outil — il ne disparaît pas, il devient le banc d'essai. → [[Décisions arrêtées]] 39c

## 🔄 L'ordre a changé deux fois

**Le 2026-08-11.** Le plan enchaînait carte → décisions → Godot. On a écrit le classeur, puis constaté que l'ordre était faux : une crue est la perturbation d'un état, et l'état n'existait pas. Les effets chiffrés s'appliquaient à du vide. → 49

**Le 2026-08-12.** La ville de t0 existe, elle se clique et elle se joue. Mais c'est encore **63 pâtés pleins** : un îlot extrudé n'est pas un ensemble de bâtiments. L'ordre change une seconde fois — **la ville crédible et belle passe devant les systèmes**, et les systèmes se traiteront ensuite **un par un**, pas en lot. → **51**

Ce que ça déplace : 49 posait le seuil à *« on doit sentir le lieu »*. Le seuil devient *« on doit avoir envie de la regarder, et croire qu'on y habite »*.

## ⚠️ Ce qui remplace la limite d'une semaine

L'ancien plan protégeait la 3D par un calendrier : *une semaine, et si j'ajoute des toits j'ai changé de projet*. **51 fait entrer les toits dans le plan**, donc cette phrase n'a plus d'objet. Le risque qu'elle couvrait, lui, est intact : la 3D est séduisante, chaque amélioration se voit, donc elle avance toujours.

Ce qui la remplace est une **règle de production**, pas une date → 52 :

> **Si je devais en faire 200, est-ce que je tiendrais ?** Si non, la tâche n'est pas de peindre l'asset, c'est d'écrire le générateur.

Et son corollaire, déjà en vigueur : *si un rendu ne s'explique pas par une valeur de simulation, c'est un bug de design.*

## 📍 Mois 1 — QGIS + classeur

❌ Prototype papier **rejeté** (je veux du digital). Ce qui comptait n'était pas le carton, c'était **la vitesse d'itération** : pouvoir jeter un système de décisions entier en une soirée. La version tableur va plus vite que le papier : on change un coefficient, les 60 mois se recalculent.

### Semaine 1 — la carte ✅ *bouclée le 2026-08-10*
**Périmètre : [[Wehrau]]**, une petite ville entière — plus un quartier. → [[Périmètre et coupes]]
✅ Carte générée puis qualifiée : **69 polygones sur 0,93 km²**, 13 sous-types, 17 exceptions.
La rivière est un **îlot** (`fonction = 'riviere'`), pas une ligne.
✅ Table d'adjacence (179 paires) et 12 attributs dérivés par îlot → [[Pipeline QGIS]]

Placer les dilemmes **consciemment**. C'est du level design, pas de la cartographie.

> **Sortie de semaine** : ✅ les cinq phrases sont écrites → [[Wehrau]]
> **Et au-delà** : la carte est **simulable**. Trois contrôles le disent — la ville privée de sa rivière tombe en deux morceaux, le réseau routier tient par ses cinq ponts, et l'axe de transit sort tout seul de l'affectation de trafic sans qu'on l'ait désigné.

### Semaine 2 — les stocks de t0 ✅ *faite le 2026-08-11*

La ville a désormais un **état**, pas seulement une géométrie : logements, habitants, emplois, ménages fragiles, sol imperméable, canopée, places de stationnement, logements exposés à l'eau, sol d'activité.

Deux d'entre eux n'existaient pas et disent quelque chose :
- **~5 353 habitants** — dérivés, pas saisis : 2 549 logements × 2,1
- **878 emplois, soit 0,16 par habitant.** Pas un coefficient trop bas : la ville n'a que 10,4 ha d'activité sur 38 ha bâtis. **Wehrau est un dortoir**, ce qui explique l'axe de transit saturé et les 0,86 place de parking par habitant. Pour changer ça il faut dessiner du sol d'activité, pas régler un chiffre.

Une page HTML autonome montre les 22 calques et les stocks côte à côte. C'est la boucle *je vois donc je corrige*, et c'est elle qui a fait apparaître les deux trous ci-dessus.

### Semaine 3 — la ville en volume ✅ *faite le 2026-08-11*

**Une maquette de masses dans Godot 4.** Les 69 îlots extrudés à leur `hauteur`, la voirie en rubans, la vallée en terrain continu, la palette de [[Direction artistique]]. → [[Génération procédurale]]

Les trois constats sont acquis : la barre de 1974 écrase ses voisines, le quai à 22 m recule trois îlots de cœur ancien, la place-parking se lit comme une rue qui a enflé. **La vallée, non** — elle ne se lit à aucune des quatre exagérations verticales, et le facteur n'y peut rien : 9 m de relief sur 898 m de large en axonométrie à angle fixe. Ça se réglera par l'ombre ou par la caméra.

### Semaine 4 — la boucle entre dans Godot ✅ *faite le 2026-08-12*

On clique un îlot ou une rue, sa fiche s'ouvre, on décide de planter un alignement, et vingt ans passent : les arbres poussent, la canopée monte, la surchauffe baisse, le budget encaisse. → 39c

Le critère de sortie de la semaine 3 est répondu par l'usage : **oui, la 3D a montré ce que la page HTML ne montrait pas.** Ce qui appelle la suite plutôt que l'arrêt.

## 🎯 Phase A — une ville crédible et belle

C'est **la phase active**. Le seuil : *avoir envie de la regarder, et croire qu'on y habite.*

Ce qui manque, dans l'ordre où ça change l'image :

| | Ce que c'est | |
|---|---|---|
| **1. Les parcelles** | 63 pâtés pleins → des bâtiments. C'est le **point dur du pipeline**, 2 à 4 semaines à lui seul, et c'est aussi ce qui sépare une maquette d'une ville | 🔴 |
| **2. Les toits et les gabarits** | une fois les parcelles là : pentes, hauteurs qui varient dans l'îlot, décalages. Une **recette**, pas des assets | 🟡 |
| **3. Le trafic** | `charge` existe déjà et sort tout seul de l'affectation — mais rien ne bouge à l'écran. Des voitures rendent la variable **visible**, et une rue saturée cesse d'être un chiffre | 🟡 |
| **4. Les carrefours** | [[Génération procédurale]] les classait « le plus dur de tous ». 32f les a largement dissous : il n'y a plus de rubans à raccorder, il y a un vide qui se referme | 🟡 |
| **5. Le sol** | un seul matériau paramétré par `impermeabilise`, `canopee`, usure — asphalte neuf, asphalte fissuré, pavé drainant, plateau piéton. Quatre curseurs qui **sont déjà des attributs** | 🟡 |
| **6. La lumière et la vallée** | le relief ne se lit pas. C'est l'ombre et la caméra, pas l'exagération | 🟡 |
| **7. L'ambiance** | piétons, mobilier, végétation d'îlot. **En dernier**, et par une réserve d'objets réutilisés | 🟢 |

⚠️ **Deux questions se rouvrent avec les parcelles**, et aucune n'est un détail : le **raccord des bâtiments voisins** (n°16), que la maquette de masses avait rendu sans objet, et **la parcelle comme entité persistante** (35) — à trancher *avant* la première ligne du générateur, irréversible en pratique.

⚠️ Piège de la DA, inchangé : Wehrau à t0 reste **ordinaire**. Une ville de départ charmante ne laisse rien à transformer. Ce qu'on rend beau est le **rendu**, pas le sujet. → [[Direction artistique]] 42c

## 🎯 Phase B — un indicateur, un système, une décision à la fois

Le classeur `Classeur/` existe : 11 décisions, 37 effets, coûts calculés depuis la carte. Il a été **joué pour la première fois le 2026-08-12** — trois parties, et il a immédiatement sorti une erreur de seuil que personne n'avait vue.

🔄 **Ce qui change** : on ne traite plus les onze décisions en lot. On en prend **une**, on la mène jusqu'au bout — sa cible, son coût, ses effets, ce qu'elle donne à l'écran, contre quoi elle pousse — et on ne passe à la suivante qu'après. Même chose pour chaque indicateur.

Pour chacune, quatre questions, et la dernière est la moins évidente :

1. **Qu'est-ce que ça change à l'écran, sans texte ?** Si la réponse est « rien », c'est une ligne de tableur, pas une mécanique.
2. **Est-ce que ça se différencie d'un îlot à l'autre, et d'amont en aval ?** Sinon le pilier de spécificité spatiale n'est pas testé. → [[Périmètre et coupes]]
3. **Le délai est-il juste ?** C'est la variable centrale en temps continu. → [[Chantiers et temps]]
4. **Contre quel autre système celle-ci pousse-t-elle ?** Si elle ne pousse contre rien, c'est un curseur, pas une mécanique. L'hésitation ne vient pas d'un coût opposé à un bénéfice — elle vient de boucles qui se contraignent l'une l'autre.

Le critère reste le **ratio hésitation / ennui**, et il se lit maintenant en jouant dans Godot plutôt que dans un tableur.

## 📍 Phase C — équilibrage + playtests

- Équilibrage sur la base des parties jouées
- **5 playtests externes** — première confrontation avec des non-urbanistes
- **Ce que je perdais à jouer au tableur** — faire jouer quelqu'un d'autre — n'est plus perdu : la boucle est dans Godot

## 📓 Discipline

Un fichier [[Journal]] où je note à chaque session **ce que j'ai appris**, pas ce que j'ai fait. C'est ce fichier qui me sauvera au mois 6.

## ⚠️ Les deux vrais risques

**Que le classeur soit sauté.** Un mauvais système de décisions codé en Godot coûte trois semaines à corriger ; dans un classeur, une soirée. 🟢 **Le risque a baissé, il n'a pas disparu** : le classeur a été joué, et la boucle qui vit maintenant dans Godot se recoupe avec lui à chaque fois. Ce qu'il faut tenir, c'est de **continuer à essayer les seuils dans le classeur avant de les coder**.

**Que la 3D mange le calendrier.** Elle est séduisante et chaque amélioration se voit, donc elle avance toujours. 🔴 **Ce risque, lui, vient d'être accepté volontairement** — c'est le sens de 51. Il n'est plus couvert par une date mais par la règle de production de 52 : *si je devais en faire 200, est-ce que je tiendrais ?*

C'est un pari, et il vaut d'être nommé comme tel : **on paie du calendrier maintenant pour que chaque système travaillé ensuite se voie immédiatement.** Le pari est perdu si, dans six semaines, la ville est plus belle et qu'aucune décision de plus n'a été traitée.

**Voir aussi** : [[Pipeline QGIS]] · [[Génération procédurale]] · [[Direction artistique]] · [[Décisions]] · [[Calendrier et budget]]
