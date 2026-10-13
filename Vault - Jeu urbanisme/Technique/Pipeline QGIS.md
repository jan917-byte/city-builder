---
tags: [technique, QGIS, données]
statut: en service — réécrite le 2026-10-12
maj: 2026-10-12
---

# Pipeline QGIS

> Le **pourquoi** de la chaîne qui fabrique la carte. **Quoi lancer** est dans `QGIS/README.md` ; les tables que l'auteur règle, dans `Prototype/00 - Prototype.md`. Aucun chiffre ici : la chaîne les ressort tous à chaque passage.

## Ce que fait la chaîne

```
SOURCE (texte, suivi par git)        îlots · routes · venelles, en GeoJSON
   ↓  02  qualifier                  fonction, sous_type, exception, hiérarchie, largeur
   ↓  03  adjacences                 qui touche qui, et par quelle rue
   ↓  04  attributs dérivés          densité, eau, charge, stationnement… (table TISSU)
   ↓  04b · 04c · 04d                l'îlot sans sa voirie → les parcelles → les bâtiments
   ↓  04e  la crue                   hauteur d'eau, dégâts, ponts coupés
   ↓  07  export Godot               wehrau.json (données) + wehrau.bin (sommets)
```

Le nom est resté, la dépendance non : **QGIS ne fait plus partie de la chaîne**. Les scripts tournent sur un Python nu, sur les deux machines. QGIS — ou Illustrator — ne sert plus qu'à **dessiner une retouche**, que la chaîne reprend dans la source.

## Les principes

- **La carte générée est la source ; la main retouche** (31b) — ouvrir une percée, fermer une impasse, tracer une venelle. Jamais de création à la main.
- **La source est du texte, tout le reste se refait** (31) : une entité par ligne, triée, donc git la fusionne entre les deux machines. Un GeoPackage est un dérivé.
- **Deux champs saisis à la main, le reste dérivé** (32) ; et **un attribut ne s'écrit que s'il débloque une décision nommée** (32d).
- **Le level design est en tête de fichier** — les listes de `fid` de `02`, les tables `TISSU` — et c'est l'auteur qui le tient. Un outil peut proposer ; il n'écrase jamais.
- **La rue est le vide que les îlots cèdent** (32f) : l'îlot recule de la demi-largeur de sa rue, et c'est une donnée, pas un effet d'affichage.

## Les pièges payés une fois, et qui ne reviennent pas tout seuls

- 🔴 **Les ponts se déguisent en rives.** Un franchissement longe la rivière, et la règle « borde l'eau → rive » l'avale : la ville se retrouve sans pont, deux réseaux étanches, sans alerte. Un pont se reconnaît à ce qu'il **sépare deux morceaux de rivière** (30b).
- **Un graphe de rues se construit sur tous les sommets**, pas sur les extrémités : une rue en T au milieu d'un tronçon serait sinon déconnectée.
- **Une largeur constante par hiérarchie rend tout seuil inopérant** : quatre largeurs, trois réglages, aucun arbitrage (31d).
- **Les brins morts au bord de la carte sont les radiales vers la campagne.** Ce ne sont pas des erreurs.
- **Le contrôle qui prouve que la carte n'est pas décorative** : privée de sa rivière, la ville tombe en deux morceaux — les îlots ne se touchent jamais par-dessus l'eau (28).

**Voir aussi** : [[Géométrie et données]] · [[Génération procédurale]] · [[Wehrau]]
