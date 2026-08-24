# Le trafic visible

> Étape 5 ouverte le 2026-08-21. Le trafic est un flux agrégé figuré par une poignée de véhicules : aucune voiture ne cherche son chemin.

## Le critère

> **Une rue à `charge = 1,00` est désagréable à regarder.**

Le critère se juge sans fiche et sans calque : sur l'axe chargé, les voitures sont nombreuses et lentes ; dans le cœur ancien, elles sont espacées et la rue reste habitable.

## Le chantier

1. **La ville roule** : un flux animé dérive de `charge`, les voitures garées dérivent de `stationnement`, le tout en instances multiples et sans asset.
2. **La charge garde une échelle stable** : une baisse globale doit pouvoir se voir au lieu de renormaliser une autre rue à 1.
3. **Une décision se voit** : supprimer du stationnement libère réellement la bordure ; retirer la voiture d'un axe reporte le flux agrégé.

## Les limites

- pas d'agent individuel, de feu, de file calculée ni de recherche d'itinéraire par voiture ;
- pas de choix modal ni de matrice origine-destination dans cette étape ;
- le calque `charge` ne sert qu'au diagnostic : s'il faut l'activer pour comprendre l'image, le rendu a raté.

## Ce qu'il faut regarder

| Vue | Ce qui doit se voir | Ce qui prouve que c'est cassé |
|---|---|---|
| axe le plus chargé | voitures proches et lentes, rue hostile | flot dense mais rapide et agréable |
| rue calme du cœur | quelques voitures espacées, stationnement lisible | rue entièrement vide |
| ville entière | l'épine chargée ressort sans calque | toutes les rues paraissent identiques |

## Ce qui reste

- **À regarder par l'auteur** : `wehrau_essai_axe.png` puis `wehrau_essai_axe_ferme.png`, `wehrau_essai_rue_calme.png` puis `wehrau_essai_stationnement_retire.png`, et `wehrau_essai_report_trafic.png`.
- La vue rapprochée porte **341 voitures roulantes visibles sur 972 positions** et **1 000 voitures garées symboliques sur 3 310 places** : deux MultiMesh, deux appels de rendu, aucune ombre.
- Le trafic visible s'anime sur le **GPU à la fréquence de l'écran (60 Hz visés)**. Le CPU ne déplace aucune voiture : une pulsation plafonnée à 4 Hz ne relit `charge` que lorsqu'elle a changé, une fois par rue.
- Au-delà d'une taille de caméra de 700 m, les véhicules sont sous le pixel : les deux MultiMesh sont masqués et la pulsation sort immédiatement.
- Une charge à 1 tasse la file à 4,8 m et ralentit à environ 4 km/h ; la rue calme espace le flux jusqu'à 48 m.
- Les **37 routes endommagées**, dont les trois ponts emportés, ne portent aucune voiture avant la fin de leur réparation ; chaque réouverture rejoue l'affectation.
- Supprimer le stationnement vide sa bordure en deux mois et le bouton montre le chantier. Retirer la voiture vide l'axe dès le clic, puis reporte le flux en six mois ; l'essai fait tomber le tronçon 55 de 1,00 à 0,00.
- Le critère reste ouvert jusqu'au regard de l'auteur : l'essai automatique prouve le mécanisme, pas que l'image est juste.
