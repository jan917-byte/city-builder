---
tags: [système, coeur, gameplay]
statut: en cours de spécification
---

# Décisions

Le cœur du jeu. Le joueur ne construit pas, il **décide**. → [[Vision et prémisses]]

## Trois échelles

1. **Réseau / ville entière** — un tracé de tram, une politique de stationnement
2. **Quartier** — densifier un secteur, désimperméabiliser
3. **Ciblée** — cette rue-là, cet îlot-là

L'échelle retenue pour le jeu est **la ville entière avec interventions par quartier**, articulée sur deux niveaux : **réseau** et **tissu**.

## Anatomie d'une décision (schéma du classeur)

| Champ | Description |
|---|---|
| `échelle` | réseau / quartier / ciblée |
| `cout_budget` | en % du budget |
| `cout_capital_politique` | |
| `delai_avant_effet` | ⏱️ **variable centrale** en temps continu |
| `duree_montee_en_charge` | l'effet arrive progressivement |
| `effet_maturite` | ce que ça donne à terme |
| `effet_de_bord` | la conséquence négative honnête |
| `condition_deblocage` | ce qui doit être vrai pour qu'elle apparaisse |
| `ouvre` / `ferme` | les décisions rendues possibles ou impossibles |

## L'exemple de référence

> ### Reprendre la rue de la Gare aux voitures
> **Portée** : un lieu précis · **Coût** : 15 % du budget · **Délai** : 2 mois
>
> **Contre** : les commerçants, les artisans qui livrent
> **Pour** : les riverains, les parents d'élèves de l'école voisine
>
> **Effet immédiat** : le trafic se reporte sur les rues parallèles, deux quartiers se dégradent. Les commerçants perdent du chiffre pendant les travaux.
>
> **À 5 ans** : fréquentation piétonne en hausse, deux commerces ont fermé et trois ont ouvert (pas les mêmes), les loyers montent de 8 % sur le linéaire.
>
> **À l'écran** : l'asphalte devient clair, des arbres apparaissent, des terrasses débordent, les voitures disparaissent de l'axe et s'épaississent à côté.
>
> **Ouvre** : passer le tram par cet axe. **Ferme** : élargir le carrefour nord.

Ce que cet exemple contient et qu'il faut reproduire :
- un coût qui n'est pas qu'en argent
- une conséquence négative **honnête et non punitive**
- de la gentrification comme **résultat du succès**
- un effet visuel qui raconte l'histoire

**C'est le niveau à viser pour les 10 décisions du prototype.**

## Irréversibilité

**Les décisions sont irréversibles mais pas irrécupérables.** On ne fait pas Ctrl+Z sur un tram. On peut corriger, à grand coût.

## Règles de composition

- Taper large : mobilité / logement / énergie / eau / espace public / social
- 2–3 décisions disponibles au départ, le reste **visible et verrouillé avec sa condition affichée**
- **Le lieu doit changer le résultat.** Sinon la carte est décorative → [[Pièges connus]]

**Voir aussi** : [[Chantiers et temps]] · [[Ressources]] · [[Vallmar]]
