# Premiers pas après la crue

> Étape 6 ouverte le 2026-09-06 à la demande de l'auteur. L'étape 5 reste en pause, à juger.
> Design : `Vault - Jeu urbanisme/Systèmes/Premiers pas après la crue.md`. Les lieux proposés restent à essayer par l'auteur.

## À jouer

Lancer normalement la maquette, ou Recommencer : départ en pause face aux deux lieux numérotés. Comparer une proposition, engager dans la fiche, puis laisser avancer le temps. DÉBUT rouvre l'accompagnement ; le diagnostic prend sa place.

| Repère de l'essai | Ce qui est mesuré |
|---|---|
| ① Rue des Halles, tronçon 150 | 13,6 k€, 1 mois ; 0 piéton avant livraison, 12 après |
| ② Maisons des Halles, îlot 61 | 376,8 k€, 12 mois ; 62 logements remis en état |
| Protection, berge 2 | 1 018,64 k€, 18 mois ; eau prévue aux maisons : 3,529 → 3,109 m |

La caisse de départ reste à 800 k€. Après la rue, la renaturation complète devient accessible au mois 8 avec la dotation normale. Les premiers pas peuvent être suivis dans les deux ordres ; le solaire reste accessible. Le bouton d'argent d'essai exige désormais `-- --outils`.

## Contrôles

`Godot --path Godot --script res://outils/essai_ouverture.gd -- --ouverture --captures` joue les deux débuts par clics, la comparaison sans dépense, le refus financier, l'épargne, la livraison, les piétons, la protection, la sauvegarde et la reprise. Ajouter `--headless` et retirer `--captures` pour le contrôle sans image.

Captures dans `QGIS/rendus/` : `wehrau_ouverture_01_depart.png`, `..._02_choix_rue.png`, `..._03_livraison.png`, `..._04_protection.png`, `..._05_logements.png`.

Validé le 2026-09-06 : essai rendu de l'ouverture, essai général rendu, essai de sauvegarde ; zéro échec dans les contrôles. Chaîne régénérée. `_posee` acceptait seulement un booléen et comparait mal les deux états de berge : corrigé.

## Ce qui attend le joueur

- Après une livraison, a-t-on envie de regarder le résultat puis de choisir la suite ?
- Le déblaiement et la remise en état font-ils deux débuts suffisamment différents ?
- La renaturation demande-t-elle trop d'épargne après la première réparation ?
- Défauts à signaler : réussite avant livraison, rue toujours vide, dépense dès la comparaison, premiers pas perdus après reprise, guide qui masque les commandes.

La crue suivante reste une prévision, sans événement daté. Le retour des piétons représente la praticabilité locale ; le faubourg reste coupé de l'autre rive tant que les ponts ne sont pas réparés. Le capital politique et le relogement ne sont pas introduits par cet essai.

## Les alentours — 2026-09-09, à juger à l'écran

135 parcelles agricoles traversent l'ancienne limite rectangulaire, avec des surfaces et orientations variées, quatre corps de ferme et des chemins. Quatre sorties routières continuent sur le relief ; l'Ilse extérieure serpente avec une largeur variable. Les cultures n'hébergent plus le semis dispersé qui révélait le rectangle.
Chaque parcelle ouvre une fiche (culture, hectares, ferme), une miniature et son contour ; la sélection se conserve à la reprise. Cette couche agricole n'ajoute encore aucune décision de production : les objets, indicateurs et règles urbaines restent identiques à l'export précédent. Une ancienne sauvegarde est refusée par l'empreinte de carte existante ; essayer sur une nouvelle partie.
Contrôles : `python QGIS/scripts/verifier_campagne.py` (maillages, raccords routiers, parcelles traversantes, comparaison urbaine si référence locale) ; Godot avec `--script res://outils/essai_campagne.gd` (tous les clics, fiches, miniature, diagnostic, sauvegarde/reprise, quatre captures). L'essai général rendu passe également.
À regarder : `wehrau_campagne_ensemble.png`, `..._dessus.png`, `..._montagnes.png`, `..._ferme.png` dans `QGIS/rendus/`. Défauts à signaler : route qui disparaît dans une pente, ligne carrée autour de la ville, arbres au milieu d'une culture, clic qui sélectionne un autre champ. Les noms de cultures et fermes générés restent une proposition visuelle.
