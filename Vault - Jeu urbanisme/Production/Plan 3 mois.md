---
tags: [production, plan, actif]
statut: 🔄 réordonné le 2026-08-11 — la ville de t0 passe devant
maj: 2026-08-11
---

# Plan 3 mois

> **Le principe qui gouverne tout** : tant que la question ouverte est *quelles décisions et quels effets*, la traiter dans un outil où **changer d'avis est gratuit**.

## 🔄 L'ordre a changé le 2026-08-11

Le plan enchaînait carte → décisions → Godot. On a écrit le classeur, puis constaté que **l'ordre était faux** : une crue est la perturbation d'un état, et l'état n'existait pas. Les effets chiffrés s'appliquaient à du vide.

**La phase actuelle est donc : [[Wehrau]] à t0, crédible et regardable.** Une ville qui existe avant qu'on décide quoi que ce soit — et visible en 3D, parce que c'est en voyant qu'on corrige. → [[Décisions arrêtées]] 49

Le classeur reste écrit et chiffré dans `Classeur/`. Il ne disparaît pas, il attend son socle.

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

### Semaine 3 — la ville en volume 🎯 *en cours*

**Une maquette de masses dans Godot 4.** Les 69 îlots extrudés à leur `hauteur`, la voirie en rubans, la vallée en terrain continu, la palette de [[Direction artistique]]. → [[Génération procédurale]]

**Ce que ça doit prouver, et rien d'autre** : que Wehrau **existe** comme lieu. On doit sentir la vallée, voir la barre de 1974 comme un objet aberrant de 9 niveaux au milieu de rangées à 3, et trouver monstrueuses les rues à 20 et 22 m. Aucun de ces trois constats ne se lit sur un dégradé de couleurs.

⚠️ **Limite de temps posée d'avance : une semaine.** Si j'ajoute des toits, j'ai changé de projet. La subdivision en parcelles est **hors phase** — c'est le point dur du pipeline, 2 à 4 semaines à lui seul.

⚠️ Piège de la DA : Wehrau à t0 doit rester **ordinaire et un peu triste**. Une ville de départ charmante ne laisse rien à transformer. → [[Direction artistique]]

### Semaine 4 — regarder et corriger

La maquette rend visibles des erreurs que les tableaux cachent. On corrige la table de correspondance et les exceptions, on relance, on regarde.

Critère de sortie : **est-ce que la 3D m'a montré quelque chose que la page HTML ne montrait pas ?** Si non, on arrête la 3D et on reprend le classeur.

## 📍 Mois 2 — le système de décisions

Le classeur `Classeur/` existe : 11 décisions, 37 effets, coûts calculés depuis la carte. Il n'a **jamais été joué** et ses valeurs sont posées, pas calibrées.

- Feuilles `chantiers` et `partie` (1 ligne = 1 mois, **60 mois**)
- **5 parties jouées** par moi
- Critère : **ratio hésitation / ennui**
- ⚠️ Le **délai** est la variable centrale en temps continu. S'il n'est pas dans le classeur, je teste un jeu qui n'est pas le mien. → [[Chantiers et temps]]
- ⚠️ Les décisions doivent se différencier **d'un îlot à l'autre** et **d'amont en aval**, sinon le pilier de spécificité spatiale n'est pas testé. → [[Périmètre et coupes]]

Puis, dans Godot : **noyau de simulation écrit par moi**, pas vibe-codé → [[Moteur et architecture]] · ghost preview · calques thématiques.

**Ce que je perds à jouer au tableur** : faire jouer quelqu'un d'autre. Les tests externes attendent le mois 3.

## 📍 Mois 3 — équilibrage + playtests

- Équilibrage sur la base des 5 parties du mois 1
- **5 playtests externes** — première confrontation avec des non-urbanistes

## 📓 Discipline

Un fichier [[Journal]] où je note à chaque session **ce que j'ai appris**, pas ce que j'ai fait. C'est ce fichier qui me sauvera au mois 6.

## ⚠️ Les deux vrais risques

**Que le classeur soit sauté.** Un mauvais système de décisions codé en Godot coûte trois semaines à corriger ; dans un classeur, une soirée. Le report du mois 1 au mois 2 est un report, pas un abandon.

**Que la 3D mange le calendrier.** Elle est séduisante et chaque amélioration se voit, donc elle avance toujours — c'est exactement ce qui la rend dangereuse. D'où la limite d'une semaine et le critère de sortie de la semaine 3.

**Voir aussi** : [[Pipeline QGIS]] · [[Génération procédurale]] · [[Direction artistique]] · [[Décisions]] · [[Calendrier et budget]]
