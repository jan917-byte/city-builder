---
tags: [système, coeur, gameplay]
statut: en cours de spécification
maj: 2026-08-12
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

## Références — deux jeux qui ont déjà résolu une moitié

Ce sont les deux plus proches **mécaniquement** de ce qui est spécifié ci-dessus. Ni l'un ni l'autre n'est un modèle entier : on prend une pièce et on laisse le reste.

| Jeu | Ce qu'on lui prend | Ce qu'on lui laisse |
|---|---|---|
| **Democracy 4** | Le graphe causal assumé : une politique n'a pas un effet, elle en a huit, dont trois qu'on n'avait pas vus. Et surtout l'**inertie** — un effet met des tours à atteindre sa pleine puissance | Le rendu : un tableur avec des flèches. Et la transparence totale — il montre tout le graphe au joueur |
| **Frostpunk 2** | L'échelle : on décide sur des **districts**, pas sur des bâtiments. Et la loi comme objet de jeu — la décision passe par un coût politique, pas par un bouton | Le conseil, les factions et le vote. C'est exactement le simulateur bureaucratique refusé → [[Vision et prémisses]] |
| **Frostpunk** (1) | Le livre des lois : un arbre, un palier à la fois, et **chaque loi se voit dans la ville** — pas seulement dans un menu | Le ton. Voir [[Ton et règles d'écriture]] |

Trois conséquences concrètes pour ce qui est spécifié plus haut :

- **L'inertie de Democracy 4 est déjà dans le schéma**, sous deux champs séparés : `delai_avant_effet` (rien ne bouge) puis `duree_montee_en_charge` (l'effet arrive). Le découpage en deux est plus juste que le curseur unique de D4 — un tram ne commence pas à monter en charge le lendemain de la décision.
- **Le curseur d'intensité de D4 n'est pas repris.** Là-bas une politique se règle de 0 à 100 %, et le jeu devient un exercice de réglage. Ici une décision se prend ou ne se prend pas ; ce qui la nuance, c'est **où** elle s'applique. → *le lieu doit changer le résultat*
- **Le capital politique reste un chiffre**, pas un conseil qui vote. Frostpunk 2 dépense le sien en négociation avec des factions ; ici il se dépense et se regagne sur des **résultats visibles**. → [[Décisions arrêtées]] 16b · [[Ressources]]

> Ce que ces deux jeux prouvent ensemble : **le pivot micro → macro est commercialement viable** (Frostpunk 2 décide par district et se vend), et **un graphe causal honnête tient un jeu entier** (Democracy 4 n'a rien d'autre). Ce qu'aucun des deux n'a : une ville qu'on reconnaît, et un effet qu'on regarde.

**Voir aussi** : [[Chantiers et temps]] · [[Ressources]] · [[Vallmar]] · [[Direction artistique]]
