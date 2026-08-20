# QGIS/data — trois dossiers, un seul est suivi par git

| Dossier | Quoi | Git |
|---|---|---|
| `source/` | **la carte**, en GeoJSON : îlots, routes, et les venelles quand elles existent | ✅ **suivi** |
| `travail/` | la carte de travail (`wehrau.gpkg`) et les copies d'essai | ❌ ignoré |
| `archive/` | les anciens GeoPackages | ❌ ignoré |

## La règle, en une phrase

**Ce qui est écrit à la main va dans `source/`. Tout le reste se refait.**

```
python QGIS/scripts/chaine.py
```

La chaîne reconstruit `travail/wehrau.gpkg` **de zéro** à chaque passage, en 0,7 s. Une carte de travail ne peut donc pas être plus vieille que le code qui la fabrique — c'est exactement le piège qu'un `.gpkg` suivi par git faisait payer : il se périmait en silence, et rien ne le disait.

🔴 **Git ne fusionne pas un binaire.** C'est pour ça qu'aucun GeoPackage n'est suivi : sans ça, modifier la carte sur les deux machines obligerait à en jeter une.

## Le format

Du GeoJSON écrit à la main pour tenir **une entité par ligne, triée par `fid`**. C'est ce qui rend le diff lisible et la fusion possible : deux machines qui touchent deux îlots différents ne se marchent jamais dessus.

Les coordonnées sont en **EPSG:25832** (mètres) et **ne sont jamais arrondies** — voir l'en-tête de `QGIS/scripts/carte.py` pour ce qu'un arrondi au millimètre a cassé.

La source ne contient **que de la géométrie**. Tout le reste — fonction, sous-type, largeurs, adjacences, emprises, parcelles, bâtiments — est recalculé à chaque passage.

## Modifier la carte

Trois scripts écrivent dans `source/`, et eux seuls. Ils gardent tous leur passe `--blanc`, qui calcule et n'écrit rien — parce que ce qu'ils touchent est du **level design**, pas du dérivé.

```
python QGIS/scripts/00_decouper_ilots.py --blanc      découper un îlot en deux
python QGIS/scripts/00b_ilots_lisiere.py --blanc      poser un îlot de lisière
python QGIS/scripts/tracer_chemins.py --blanc         proposer des venelles
```

Après écriture, `git diff` montre en clair les îlots touchés, et `git checkout QGIS/data/source` défait tout.
