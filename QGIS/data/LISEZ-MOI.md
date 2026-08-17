# QGIS/data — trois dossiers, un seul est suivi par git

| Dossier | Quoi | Git |
|---|---|---|
| `source/` | **La carte**, en GeoJSON. 70 îlots, 179 tronçons, et les venelles quand elles existent. | ✅ **suivi** |
| `travail/` | La carte de travail (`wehrau.gpkg`) et toutes les copies d'essai. | ❌ ignoré |
| `archive/` | Les anciens GeoPackages, gelés le 2026-08-17. | ❌ ignoré |

## La règle, en une phrase

**Ce qui est écrit à la main va dans `source/`. Tout le reste se refait.**

La chaîne complète — `02 → 03 → 04 → 04b → 04c` — tourne en **0,7 seconde** :

```
python QGIS/scripts/chaine.py
```

Elle reconstruit `travail/wehrau.gpkg` **de zéro** à chaque passage. Une carte
de travail ne peut donc plus être plus vieille que le code qui la fabrique.

## Ce que ça a remplacé, et pourquoi

Jusqu'au 2026-08-17, `Vallmar2.gpkg` (la source) et `Prototype_qualifie.gpkg`
(la carte de travail) étaient suivis par git. Deux ennuis, payés à chaque
session :

1. **Git ne fusionne pas un `.gpkg`.** Modifier la carte sur le Mac et sous
   Windows obligeait à en jeter une. D'où la règle « la carte ne s'écrit que
   sous Windows », qui interdisait la moitié du travail sur l'autre machine.
2. **La carte de travail se périmait en silence.** Le 2026-08-14, une session
   entière est passée à décrire un défaut de parcellaire déjà corrigé dans le
   code : le `.gpkg` du dépôt datait de deux commits plus tôt, et rien ne le
   disait.

Ce qui a rendu le binaire inutile, c'est la sortie de QGIS de la chaîne : plus
personne n'ouvre ces fichiers à la main. Or la source ne contient **que de la
géométrie** — 66 ko de texte. Tout le reste (fonction, sous-type, largeurs,
adjacences, emprises, parcelles, bâtiments) est recalculé à chaque passage.

Les deux fichiers d'origine sont dans `archive/`, **et surtout dans
l'historique git**, qui est l'archive qui compte :

```
git show fab5f7c:QGIS/data/Vallmar2.gpkg > recupere.gpkg
```

La conversion a été vérifiée : le texte redonne les géométries **identiques à
l'octet**, et la chaîne relancée dessus sort exactement les mêmes chiffres —
mêmes parcelles, même partition à 100,00 %, mêmes coupes effacées.

## Modifier la carte

Trois scripts écrivent dans `source/`, et eux seuls. Ils gardent tous leur
passe `--blanc`, qui calcule et n'écrit rien — parce que ce qu'ils touchent
est du **level design**, pas du dérivé.

```
python QGIS/scripts/00_decouper_ilots.py --blanc     découper un îlot en deux
python QGIS/scripts/00b_ilots_lisiere.py --blanc     poser un îlot de lisière
python QGIS/scripts/tracer_chemins.py --blanc        proposer des venelles
```

Après écriture, `git diff` montre en clair les îlots touchés, et
`git checkout QGIS/data/source` défait tout.

## Le format

Du GeoJSON, écrit à la main pour tenir **une entité par ligne**, triée par
`fid`. C'est ce qui rend le diff lisible et la fusion possible : deux machines
qui touchent deux îlots différents ne se marchent jamais dessus.

Les coordonnées sont en **EPSG:25832** (mètres) et **ne sont jamais
arrondies** — voir l'en-tête de `QGIS/scripts/carte.py` pour ce qu'un arrondi
au millimètre a cassé le jour où on l'a essayé.
