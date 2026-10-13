---
tags: [système, temps]
statut: arrêté
maj: 2026-08-25
---

# Chantiers et temps

## Temps continu — arrêté

**Le tour par tour est rejeté.** Raison de fond : le mécanisme central (le joueur pose une intention, la ville la réalise lentement) est incohérent avec le tour par tour — un tour, c'est une horloge qui attend le joueur, alors qu'on veut une ville qui continue sans lui.

## Ce que ça change vraiment

**Sous le capot : rien.** Un tick par mois simulé. Ce qu'on abandonne, ce n'est pas la discrétisation, c'est **l'arrêt forcé**. La maquette avance mois par mois, et la pause reste à un clic.

## Paramètres

- **Tick mensuel**
- **3 vitesses** + pause
- **Pause généreuse, gratuite, décomplexée** — on veut que le joueur hésite, et le temps réel punit la délibération sauf si la pause est totalement libre
- **Pause automatique** à chaque événement climatique

## Les trois temps d'une décision

```
  réglage dans la fiche       validation       chantier       livraison
   │──── preview du résultat ────│────────────────│───────────────▶
   ▲                             ▲               ▲               ▲
 futur visible             intention posée   travaux visibles   résultat dans la ville
```

- **La preview de la fiche est non négociable.** Tout réglage qui change un îlot ou un tronçon met immédiatement à jour la miniature de l'objet sélectionné ; elle montre l'état qui sera livré, avant validation comme pendant le chantier.
- **La ville ne montre jamais le futur.** Avant la livraison, elle garde son état construit réel ; pendant les travaux, seul le signal de chantier partagé s'y ajoute. Le résultat apparaît dans la ville quand le chantier est fini.
- **La miniature ne ment pas** : elle est produite par les mêmes paramètres et la même recette visuelle que l'objet livré, jamais par une vignette dessinée à part.
- **Le délai est la variable centrale** du design en temps continu. Un prix sans délai teste un autre jeu que celui-ci : le pont provisoire contre le pont en dur (87) n'est un choix que parce qu'il gagne cinq mois.

## Plusieurs chantiers en vol

Règle de rythme : **toujours 3 chantiers à des stades différents**. Une seule décision en cours = on attend. Trois décalées = on arbitre en continu.

**Voir aussi** : [[Boucle de jeu]] · [[Décisions]] · [[Premiers pas après la crue]]
