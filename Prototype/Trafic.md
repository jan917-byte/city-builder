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
- le thème `charge` ne sert qu'au diagnostic : s'il faut l'ouvrir pour comprendre l'image, le rendu a raté.

## Ce qu'il faut regarder

| Vue | Ce qui doit se voir | Ce qui prouve que c'est cassé |
|---|---|---|
| axe le plus chargé | voitures proches et lentes, rue hostile | flot dense mais rapide et agréable |
| rue calme du cœur | quelques voitures espacées, stationnement lisible | rue entièrement vide |
| ville entière | l'épine chargée ressort sans thème | toutes les rues paraissent identiques |

## Les deux vues — écrites le 2026-08-25, jugées par personne

Le calque de charge n'est plus une touche : c'est un **thème du diagnostic**, la deuxième des deux vues. La première est la ville vivante ; la seconde passe la ville en **maquette blanche** — plus de matière, plus d'arbres, plus de voitures — et n'y laisse en couleur que le thème choisi au menu : dangers, chantiers, énergie, trafic, tissu. Le temps continue, la caméra ne bouge plus d'elle-même, et la fiche répond au clic dans les deux.

Pourquoi ça compte pour cette étape : le critère se juge **sans thème**, sur la ville vivante. Tant que le diagnostic ressemblait à la ville, on ne savait pas si on jugeait le rendu ou le calque.

| À regarder, toutes au même cadrage | Ce qui doit s'y voir |
|---|---|
| `wehrau_essai_materiaux.png` | la ville vivante, le point de départ |
| `wehrau_essai_diag_trafic.png` | l'épine chargée en rouge sur une ville de carton |
| `wehrau_essai_diag_energie.png` | le dégradé d'amortissement ; gris = pas de toit équipable |
| `wehrau_essai_diag_dangers.png` · `..._diag_tissu.png` · `..._chantiers.png` | les trois thèmes déjà connus, sur le même carton |
| `wehrau_essai_retour_ville.png` | **exactement `essai_materiaux`** |

Ce qui prouverait que c'est cassé : une voiture ou un arbre sur une image de diagnostic · `essai_retour_ville` qui diffère de `essai_materiaux` · deux signaux sur le même objet · un carton si clair que les couleurs de thème s'y perdent — le seul réglage qu'aucun contrôle n'attrape, il tient à un nombre du shader.

🔴 **Écrit sur un Mac sans Godot** : ni compilé, ni lancé, ni vu. Les touches `C` `D` `H` `X` ont été retirées avec l'ancien mécanisme — si le menu ne s'ouvre pas, il n'y a plus de chemin de secours au clavier.
🔴 **La décision « deux vues » n'existe pas dans le vault** : à ouvrir dans `Questions ouvertes.md` et fermer dans `Décisions arrêtées.md`.

## Ce qui reste

- **À regarder par l'auteur** : `wehrau_essai_axe.png` puis `wehrau_essai_axe_ferme.png`, `wehrau_essai_rue_calme.png` puis `wehrau_essai_stationnement_retire.png`, et `wehrau_essai_report_trafic.png`.
- La vue rapprochée porte **341 voitures roulantes visibles sur 972 positions** et **1 000 voitures garées symboliques sur 3 310 places** : deux MultiMesh, deux appels de rendu, aucune ombre.
- Le trafic visible s'anime sur le **GPU à la fréquence de l'écran (60 Hz visés)**. Le CPU ne déplace aucune voiture : une pulsation plafonnée à 4 Hz ne relit `charge` que lorsqu'elle a changé, une fois par rue.
- Au-delà d'une taille de caméra de 700 m, les véhicules sont sous le pixel : les deux MultiMesh sont masqués et la pulsation sort immédiatement.
- Une charge à 1 tasse la file à 4,8 m et ralentit à environ 4 km/h ; la rue calme espace le flux jusqu'à 48 m.
- Les **37 routes endommagées**, dont les trois ponts emportés, ne portent aucune voiture avant la fin de leur réparation ; chaque réouverture rejoue l'affectation.
- Supprimer le stationnement vide sa bordure en deux mois et le bouton montre le chantier. Retirer la voiture vide l'axe dès le clic, puis reporte le flux en six mois ; l'essai fait tomber le tronçon 55 de 0,88 à 0,00.
- Depuis la fusion du 2026-08-24, la maquette lit la charge **d'après-crue** que `04e` réécrit : le tronçon 55 part de 0,88 et non de 1,00, et la rue à 1,00 du critère est le tronçon **5**. → [Crue](Crue.md) § 6
- Le critère reste ouvert jusqu'au regard de l'auteur : l'essai automatique prouve le mécanisme, pas que l'image est juste.
