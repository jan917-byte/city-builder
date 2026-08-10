---
tags: [système, temps]
statut: arrêté
---

# Chantiers et temps

## Temps continu — arrêté

**Le tour par tour est rejeté.** Raison de fond : le mécanisme central (le joueur pose une intention, la ville la réalise lentement) est incohérent avec le tour par tour — un tour, c'est une horloge qui attend le joueur, alors qu'on veut une ville qui continue sans lui.

## Ce que ça change vraiment

**Sous le capot : rien.** Un tick par mois simulé. Ce qu'on abandonne, ce n'est pas la discrétisation, c'est **l'arrêt forcé**. Le classeur du mois 1 marche pareil : une ligne = un mois. Coût zéro sur le prototype.

## Paramètres

- **Tick mensuel**
- **3 vitesses** + pause
- **Pause généreuse, gratuite, décomplexée** — on veut que le joueur hésite, et le temps réel punit la délibération sauf si la pause est totalement libre
- **Pause automatique** à chaque événement climatique

## Les trois temps d'une décision

```
  pose        délai avant effet        montée en charge         maturité
   │──── ghost preview ────│─────────────────────│──────────────────▶
   ▲                        ▲                     ▲
   │                        │                     │
 feedback              premiers effets       effet plein
 instantané             visibles
```

- **Le ghost preview est non négociable** : feedback immédiat pendant que la réalisation reste lente. C'est la réponse au risque de spectateur.
- **Le délai est la variable centrale** du design en temps continu. Il doit être modélisé dès le classeur du mois 1, sinon on teste un jeu qui n'est pas le sien.

## Plusieurs chantiers en vol

Règle de rythme : **toujours 3 chantiers à des stades différents**. Une seule décision en cours = on attend. Trois décalées = on arbitre en continu.

**Voir aussi** : [[Boucle de jeu]] · [[Décisions]] · [[Plan 3 mois]]
