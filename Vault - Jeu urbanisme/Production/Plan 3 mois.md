---
tags: [production, plan, actif]
statut: en cours — mois 1
---

# Plan 3 mois

> **Le principe qui gouverne tout** : tant que la question ouverte est *quelles décisions et quels effets*, la traiter dans un outil où **changer d'avis est gratuit**.

## 📍 Mois 1 — QGIS + classeur

❌ Prototype papier **rejeté** (je veux du digital). Ce qui comptait n'était pas le carton, c'était **la vitesse d'itération** : pouvoir jeter un système de décisions entier en une soirée. La version tableur va plus vite que le papier : on change un coefficient, les 60 mois se recalculent.

### Semaine 1 — la carte 🟡 *presque bouclée*
**Périmètre : [[Wehrau]]**, une petite ville entière — plus un quartier. → [[Périmètre et coupes]]
✅ Carte générée puis qualifiée : **69 polygones sur 0,93 km²**, 13 sous-types, 17 exceptions.
La rivière est un **îlot** (`fonction = 'riviere'`), pas une ligne.
☐ Reste la table d'adjacence et les attributs dérivés → [[Pipeline QGIS]]

Placer les dilemmes **consciemment**. C'est du level design, pas de la cartographie.

> **Sortie de semaine** : ✅ les cinq phrases sont écrites → [[Wehrau]]

### Semaine 2 — le système de décisions
Classeur, feuille `decisions` :
`échelle` · `cout_budget` · `cout_capital_politique` · **`delai_avant_effet`** · **`duree_montee_en_charge`** · `effet_maturite` · `effet_de_bord` · `condition_deblocage`

⚠️ Le **délai** est la variable centrale en temps continu. S'il n'est pas dans le classeur, je teste un jeu qui n'est pas le mien. → [[Chantiers et temps]]

**10 décisions.** Ne pas équilibrer — chercher la **forme**, pas les valeurs.

⚠️ Les décisions doivent se différencier **d'un îlot à l'autre** et **d'amont en aval**. Sinon le pilier de spécificité spatiale n'est pas testé. → [[Périmètre et coupes]]

### Semaine 3 — jouer
Feuilles `chantiers` et `partie` (1 ligne = 1 mois, **60 mois**).
**5 parties jouées** par moi.

### Semaine 4 — lire
Critère : **ratio hésitation / ennui**.

> **Le classeur devient la spec.** C'est le document qu'on traduit en Godot au mois 2, et il aura déjà été testé.

**Ce que je perds** : faire jouer quelqu'un d'autre. Un tableur est injouable pour un tiers. Les tests externes attendent le mois 3.

## 📍 Mois 2 — Godot 4

- Export GeoJSON depuis `Prototype_qualifie.gpkg`
- Affichage de la carte, calques thématiques
- **Noyau de simulation écrit par moi**, pas vibe-codé → [[Moteur et architecture]]
- Ghost preview

## 📍 Mois 3 — équilibrage + playtests

- Équilibrage sur la base des 5 parties du mois 1
- **5 playtests externes** — première confrontation avec des non-urbanistes

## 📓 Discipline

Un fichier [[Journal]] où je note à chaque session **ce que j'ai appris**, pas ce que j'ai fait. C'est ce fichier qui me sauvera au mois 6.

## ⚠️ Le vrai risque

**Que le mois 1 soit sauté.** Un mauvais système de décisions codé en Godot coûte trois semaines à corriger ; dans un classeur, une soirée.

**Voir aussi** : [[Pipeline QGIS]] · [[Décisions]] · [[Calendrier et budget]]
