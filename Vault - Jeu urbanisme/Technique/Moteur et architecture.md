---
tags: [technique, moteur]
statut: en service — réécrite le 2026-10-12
maj: 2026-10-12
---

# Moteur et architecture

> Le **pourquoi** des choix de moteur. Comment lancer et contrôler la maquette est dans `Godot/README.md`.

## Godot 4, tout en GDScript

**Pourquoi Godot tient** : la simulation est **agrégée** (34), donc la géométrie se génère ponctuellement, pas à chaque image ; le jeu est **lourd en interface** (fiches, calques, thèmes), et les nœuds d'interface de Godot sont solides là-dessus ; solo, PC, open source.

**Le C# n'est plus prévu** (41, révisée le 2026-10-12). Le risque qu'il couvrait — des boucles géométriques lourdes en GDScript — est tombé autrement : **la géométrie est calculée en Python, dans la chaîne**, et Godot ne fait que la charger. Ce qui reste lourd côté Godot (trafic, piétons, arbres, saisons) passe par la carte graphique, en instances et en shaders.

## Qui calcule quoi

| | Où | Ce qu'il fait |
|---|---|---|
| **La chaîne** | `QGIS/scripts/` | la carte, les attributs, les parcelles, les bâtiments, la crue, toute la géométrie 3D |
| **L'export** | `07_exporter_godot.py` | deux fichiers : `wehrau.json` (les données) et `wehrau.bin` (les sommets, au format de Godot) |
| **Le noyau** | `Godot/scripts/ville.gd` et voisins | l'état de la ville, le temps, les chantiers, la caisse, la confiance |
| **La maquette** | `Godot/scripts/` | l'affichage, les fiches, les calques, la caméra |

Le **générateur de géométrie reste isolé derrière une interface** (41) : le toit expose sa surface, sa pente et son ombrage, et l'énergie les lit sans savoir qui les produit — elle tourne aussi sur des toits estimés. Un module dont on peut changer l'intérieur sans tout casser est aussi un module qu'on peut réécrire.

## Qui écrit le code

> **Claude écrit le code, noyau et architecture compris. L'auteur teste, itère, et revient sur ses décisions.** (40b)

Ce que ça coûte : la compréhension n'est plus produite par la construction, elle se va chercher — en jouant, en cassant volontairement, en demandant pourquoi. **Où les erreurs se logeront** : l'architecture, la performance, le game feel, et les API Godot 3 obsolètes qui compilent sans broncher. Les essais de `Godot/outils/` et les commentaires du code sont la mémoire qui survit aux sessions.

## Le test d'échelle

Le jeu complet est [[Vallmar]], 2 à 3 fois Wehrau (77). Un banc de mesure fait tourner **quatre Wehrau côte à côte**, chacune avec sa ville et son trafic : c'est la vérification que l'architecture passera à Vallmar sans changer de méthode. Les chiffres se remesurent, ils ne s'écrivent pas ici.

**Voir aussi** : [[Pipeline QGIS]] · [[Génération procédurale]] · [[Calendrier et budget]]
