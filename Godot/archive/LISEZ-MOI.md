# Ce qui a été retiré du prototype le 2026-08-12

> Décision de l'auteur : *« je veux le prototype simple avec la ville en 3D et le système énergie »* — les autres indicateurs et systèmes sortent du code actif.
>
> **Supprimé pour de bon, pas masqué.** `Prototype/Énergie.md` §2 proposait de les masquer par une liste ; l'auteur a tranché l'inverse. Ce dossier est la trace demandée : *« garde en mémoire quelque part »*.

## Ce qui est parti

| Le morceau | Où il est ici | Ce qu'il faisait |
|---|---|---|
| **D07 planter l'alignement** | `d07.gd.txt` | la seule décision jouable du prototype : on plantait les deux rives d'une rue, l'arbre mettait cinq ans à faire de l'ombre |
| **Les arbres d'alignement** | `alignements.gd.txt` | 1 278 emplacements plantables, un `MultiMesh`, un seuil de canopée par emplacement. C'était le seul endroit où le temps se voyait **sans lire un chiffre** |
| **La surchauffe** | `indicateurs.gd.txt` | `3,5 × imperméabilisé − 2,5 × canopée`, +1,59 °C à t0. Elle n'existait dans aucune colonne du `.gpkg` — elle se dérivait du sol |
| **Les quatre indicateurs de ville** | `indicateurs.gd.txt` | canopée moyenne, imperméabilisé moyen, canopée des rues, places de stationnement |
| **Les six calques** | `indicateurs.gd.txt` | canopée, surchauffe, imperméabilisé, canopée des rues, emprise libre |
| **Le contrôle de recoupement** | `essai_d07.gd.txt` | il rejouait dans Godot ce que `Classeur/parties/4_recoupement.csv` demandait à `08_jouer.py`, et vérifiait que les deux moteurs tombaient sur la même canopée au mois 60 |

## Ce que ça coûte, et qu'il faut savoir

🔴 **Le contrôle de recoupement entre les deux moteurs disparaît.** C'était la seule façon de savoir tout de suite si Godot et `08_jouer.py` divergeaient. `Prototype/Énergie.md` §9c l'avait déjà accepté comme une exception ; ce sont maintenant les trois invariants imprimés du prototype énergie qui tiennent ce rôle, et ils ne comparent qu'un moteur à lui-même.

🟢 **Ce qui n'est PAS parti** : `canopee` reste une donnée de la carte et reste calculée. C'est elle qui fait l'ombrage des toits dans le système énergie — le rendement d'un panneau est multiplié par `1 − 0,4 × canopée` de l'îlot. Les 541 arbres semés au sol restent aussi : ils font partie de la ville, pas d'un indicateur.

## Ce que coûterait le retour

Ce n'est pas un interrupteur. Remettre D07 demande de reposer une entrée de décision, de rebrancher les arbres d'alignement sur un `MultiMesh`, de rendre à `07_exporter_godot.py` l'export des 1 278 emplacements plantables, et de remettre les indicateurs dans le bandeau et les calques.

**Compter une demi-journée**, et le faire seulement quand le thème « chaleur et confort » arrivera pour de bon — parce qu'alors la décision se réécrira de toute façon avec les trois durées (délai · travaux · maturation) que le prototype énergie a introduites, et que D07 n'avait pas.

**Voir aussi** : `../../Prototype/Énergie.md` · `../README.md` · `Méta/Décisions arrêtées` 64
