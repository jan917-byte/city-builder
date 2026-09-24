---
tags: [système, gameplay, prototype]
statut: en essai, à juger par l'auteur
maj: 2026-09-24
---

# Premiers pas après la crue

L'auteur demande d'essayer une première boucle : **voir un manque → choisir une intervention → voir le lieu reprendre vie → comprendre sa fragilité → préparer une transformation**. L'implémentation est autorisée ; le plaisir et les lieux proposés restent à juger. → [[Questions ouvertes]] n°29

## Une réussite avant le dilemme

Le récit présente la crue, puis le temps part à ×1 sur le relogement. Le joueur cherche un terrain pour les premiers abris. Après le premier camp livré, le guide invite à ouvrir le trafic et à comparer les trois ponts : rétablir une liaison ouvre les accès, mais répartit différemment les trajets. Un camp monté sur la mauvaise rive conduit également à ce diagnostic, sans enfermer le joueur.

Comparer n'engage rien ; la fiche du pont propose deux chantiers : un pont provisoire, vite posé mais sur une seule voie, ou le pont en dur, plus long (décision 87). Ses rues d'accès se déblaient pendant les travaux, qui ne laissent donc pas le joueur sans rien à faire. Pendant les travaux du pont, le relogement et les réparations restent possibles. Le tablier réapparaît à sa livraison ; l'accès piéton des camps reste distinct de l'accès routier. La réussite du guide attend une liaison routière continue : chaque extrémité rejoint un carrefour praticable sans passer par un autre pont. Un pont livré sans accès le dit et reste sans voitures. Le guide propose ensuite la rue ou les logements des Forgerons, puis les pistes déjà présentes : réparer, protéger ou investir.

La protection diminue l'eau prévue dans le secteur après livraison ; réparer seul laisse cette prévision inchangée. Le coût de la berge peut obliger à épargner. Aucun cadeau de trésorerie ni verrou supplémentaire ne fabrique le choix.

## Un accompagnement que l'on peut quitter

Pendant la première installation, les fiches proposent le relogement. Ensuite les réparations sont disponibles. L'accompagnement se réduit, se retrouve par DÉBUT et se conserve dans la sauvegarde. Les étapes suivent les livraisons réelles ; un pont reconstruit directement sur la carte est reconnu sans exiger de visite préalable du calque.

Les deux premières propositions et la berge sont des choix de lieu pour cet essai, pas un générateur de missions. Leurs identifiants se règlent en haut de `Godot/scripts/ouverture.gd` ; les mesures et les contrôles vivent dans `Prototype/Premiers pas.md`.

La crue annoncée n'a pas encore de date ni de déclenchement. La première victoire est locale : une rue dégagée ne rétablit pas à elle seule les ponts du faubourg.

## Une carte lisible, des conséquences attribuables

Décision 85 : aucune pastille de sinistré, camp, pont ou chantier, aucun numéro du guide sur la carte. Le compteur « Personnes sans logement » reste en bas à droite, même avec le guide réduit ; les places en construction sont distinctes. Il baisse uniquement lorsque des logements sont livrés et accessibles.
La consigne invite à consulter le trafic et à rétablir une liaison ; elle ne désigne aucun pont. Chaque fiche compare pont et accès : coût restant, délai minimal et report de trafic prévu. Les rues à déblayer peuvent être examinées séparément ; un aperçu temporaire souligne le parcours. Toute autre continuité praticable convient. Les différences viennent du réseau existant ; aucun bonus arbitraire n'est ajouté aux ponts.
Le paiement et la perte agricole interviennent à l'engagement ; les logements et passages utilisables sont annoncés à la livraison. Palissades, grues, abris, tabliers et circulation rendent ces changements visibles. Les notifications sont des constats brefs dans l'interface, sans confettis ni chiffres flottants ; le journal sauvegardé permet de les relire. Les effets économiques récurrents et la circulation restent ceux de la simulation.
Le budget initial couvre le relogement, un pont au choix et le déblaiement des routes (décision 86). Le relogement progressif et le verrou à zéro restent proposés séparément.

**Voir aussi** : [[Boucle de jeu]] · [[Chantiers et temps]] · [[Wehrau]] · [[Ressources]] · [[Questions ouvertes]]
