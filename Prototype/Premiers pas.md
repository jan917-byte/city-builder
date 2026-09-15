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

## Campagne du SVG vers Godot — 2026-09-15

Les 88 champs gardent leur contour importé, leur teinte et des bandes parallèles à leur grand côté. La grille agricole globale est retirée ; prairies et cultures se distinguent davantage. Les deux massifs portent des croupes boisées et se prolongent dans le décor extérieur, sans seconde ceinture de champs.

Les quatre sorties principales suivent exclusivement les limites communes de deux champs existants (623 m) et s'arrêtent à la lisière. Chaque angle du SVG est conservé ; aucun prolongement ne traverse la forêt ou les montagnes. Les dessertes 177 et 178 s'arrêtent avec les îlots, à la demande de l'auteur. Les prolongements sont du décor ; les décisions et le trafic restent sur les tronçons existants. Les arbres sont écartés des nouvelles chaussées.

Contrôles : `verifier_campagne.py` (6 cas), `verifier_voirie.py` (3 cas), chaîne complète et aires des 88 champs exportés vérifiées (écart maximal 0,013 %), axes des prolongements contrôlés sur les limites communes (écart inférieur à 1 mm), et trois cadrages Godot via `--script res://outils/apercu_campagne.gd`. Aperçus : `QGIS/rendus/wehrau_campagne_dessus_apres.png`, `..._relief_apres.png`, `..._champs_apres.png` ; `..._avant.png` garde le même cadrage avant correction.

À regarder : ① contours des champs, ② sortie ouest posée sur la limite des champs, ③a/b montagnes. Défauts à signaler : route coupant un champ ou dépassant sa lisière, champ réapparu derrière un massif, rupture rectangulaire du paysage. Les chemins d'accès aux fermes restent à dessiner. Les alertes d'export concernant les anciens ponts et les effectifs attendus de l'ancienne carte restent un chantier distinct.
