---
tags: [système, gameplay, prototype]
statut: en essai, à juger par l'auteur
maj: 2026-09-06
---

# Premiers pas après la crue

L'auteur demande d'essayer une première boucle : **voir un manque → choisir une intervention → voir le lieu reprendre vie → comprendre sa fragilité → préparer une transformation**. L'implémentation est autorisée ; le plaisir et les lieux proposés restent à juger. → [[Questions ouvertes]] n°29

## Une réussite avant le dilemme

Le départ montre un morceau du faubourg après la crue, en pause. Deux propositions ouvrent les fiches existantes et leurs miniatures : déblayer une rue rapidement, ou remettre les logements voisins en état. Comparer n'engage rien ; le bouton de la fiche lance le chantier.

Le temps avance à la demande du joueur. À la première réparation livrée, l'accompagnement marque une pause : la rue redevient praticable ou les logements sont remis en état. Le résultat vient de la simulation. Le bouton « Et maintenant ? » amène trois intentions : poursuivre les réparations, renaturer la berge, ou investir dans le solaire.

La protection diminue l'eau prévue dans le secteur après livraison ; réparer seul laisse cette prévision inchangée. Le coût de la berge peut obliger à épargner. Aucun cadeau de trésorerie ni verrou supplémentaire ne fabrique le choix.

## Un accompagnement que l'on peut quitter

La ville entière reste jouable. L'accompagnement se réduit, se retrouve par DÉBUT et se conserve dans la sauvegarde. Les étapes suivent les réparations réelles, y compris si le joueur commence ailleurs.

Les deux premières propositions et la berge sont des choix de lieu pour cet essai, pas un générateur de missions. Leurs identifiants se règlent en haut de `Godot/scripts/ouverture.gd` ; les mesures et les contrôles vivent dans `Prototype/Premiers pas.md`.

La crue annoncée n'a pas encore de date ni de déclenchement. La première victoire est locale : une rue dégagée ne rétablit pas à elle seule les ponts du faubourg.

**Voir aussi** : [[Boucle de jeu]] · [[Chantiers et temps]] · [[Wehrau]] · [[Ressources]] · [[Questions ouvertes]]
