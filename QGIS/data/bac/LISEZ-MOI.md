# `bac/` — les copies de travail des GeoPackages

Ce dossier existe pour une seule raison : **les `.gpkg` ne se fusionnent pas.**
Ce sont des binaires. Si la même carte est modifiée sous Windows et sur le Mac
sans passer par un `push`/`pull`, git ne fusionne rien — il faut choisir une
version et jeter l'autre, donc jeter une soirée de travail.

**Tout ce qui est ici est ignoré par git**, sauf ce fichier. C'est l'endroit où
on pose une copie d'un `.gpkg` pour la triturer sans risque.

## La règle, en une ligne

> **Le script voyage entre les deux machines. La carte, non.**
> `QGIS/data/*.gpkg` ne s'écrit que **sous Windows**.

## Ce que ça donne en pratique

Pour essayer une découpe sans toucher à la vraie carte — sur n'importe quelle
machine, et c'est le mode de travail par défaut sur le Mac :

```
cp QGIS/data/Prototype_qualifie.gpkg QGIS/data/bac/essai.gpkg
python3 QGIS/scripts/04c_parcelles.py QGIS/data/bac/essai.gpkg
python3 QGIS/scripts/apercu_parcelles.py QGIS/data/bac/essai.gpkg \
        --avant QGIS/data/Prototype_qualifie.gpkg
```

La dernière commande sort l'avant/après côte à côte dans `QGIS/rendus/`, qui
est lui aussi ignoré par git : les images se regardent là où elles sont
produites, elles ne se transportent pas.

Et pour un contrôle qui ne demande même pas de copie, tout script qui écrit a
son mode `--blanc` : il calcule, il imprime ses tableaux, il n'écrit rien.

## Ce qui tourne sur le Mac, et ce qui n'y tourne pas

| | Mac |
|---|---|
| Les onze scripts de `QGIS/scripts/` | ✅ Python pur + `sqlite3`, rien à installer |
| `apercu_carte.py`, `apercu_parcelles.py`, `06_etat_zero.py` | ✅ demandent Pillow : `pip3 install pillow` |
| Écrire dans `QGIS/data/*.gpkg` | ❌ jamais — c'est ce que ce dossier évite |
| QGIS lui-même, Godot | ❌ ne sont pas installés |

**Voir aussi** : `CLAUDE.md` §5 et §5 bis · `QGIS/README.md`
