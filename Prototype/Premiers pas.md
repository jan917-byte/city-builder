# Premiers pas après la crue

> Étape 6 ouverte le 2026-09-06 à la demande de l'auteur. L'étape 5 reste en pause, à juger.
> Design : `Vault - Jeu urbanisme/Systèmes/Premiers pas après la crue.md`. Les lieux proposés restent à essayer par l'auteur.

## À jouer

Au lancement, un écran demande le mode : **histoire** ou **auteur**. Le mode auteur livre tout chantier engagé au clic — les prix, la caisse et la dotation ne changent pas. Les drapeaux `-- --histoire` et `-- --auteur` sautent l'écran pour les contrôles.

Puis départ en pause sur le relogement, faubourg et champs dans la même image. Choisir un champ, engager dans sa fiche, laisser avancer le temps. DÉBUT rouvre l'accompagnement ; le diagnostic prend sa place.

| Repère de l'essai | Ce qui est mesuré |
|---|---|
| Sinistrés à reloger | 260 logements perdus, 7 îlots, faubourg de rive gauche |
| ① champ 1082 | 195 places · 293 k€ |
| ② champ 1083 | 141 places · 212 k€ |
| ③ champ 1084 | 114 places · 171 k€ |
| ① Rue des Forgerons, tronçon 148 | 15,7 k€, 1 mois |
| ② Maisons des Forgerons, îlot 59 | 734,4 k€, 12 mois ; 43 logements sinistrés, 24 restés habitables |
| Protection, berge 3 | 1 019 k€, 18 mois ; bief des maisons des Forgerons |

La caisse de départ reste à 800 k€. **Le camp en prend la moitié** : après ① le plus grand champ, il reste 507 k€, donc la rue passe tout de suite et relever les logements demande **huit mois d'épargne**. La berge devient accessible au mois 20 au lieu de 12. Le bouton d'argent d'essai exige toujours `-- --outils`.

## Le relogement — 2026-09-17

**Aucune liste de fid** : `07` écrit le morceau de réseau de chaque îlot une fois les trois ponts retirés, et un champ n'est proposé que s'il partage celui du faubourg. Redessiner un pont ou une desserte déplace la scène sans toucher au code. Un champ n'étant riverain d'aucune rue, il hérite du morceau de la route la plus proche sous 30 m — 10 m mesurés pour 1082 et 1083, 115 m pour le premier champ réellement sans accès.

**Aucun des trois ne loge tout le monde** : 195 places au mieux pour 260 sinistrés. Le choix du lieu est donc un vrai choix, et 65 personnes restent dehors après le premier camp.

**Un champ de l'autre rive se pose quand même** (arbitrage de l'auteur) : la fiche prévient, le bouton reste actif, le camp se monte, personne n'y va. Réparer un pont le remplirait.

Les places de containers sont semées par la chaîne, deux boîtes par logement ; la maquette n'en montre que le nombre payé, donc un camp qui grandit ne coûte aucun triangle décidé à l'exécution. Le camp dégage les arbres de son champ.

## Les pastilles — 2026-09-17

Sept pastilles de sans-abri, une par îlot touché, avec le nombre de logements perdus ; trois pastilles de pont coupé ; une par camp posé, avec ses occupants ou le mot « vide ». Elles gardent leur taille à l'écran, s'éteignent au-delà de 900 m de caméra, et **s'effacent à la livraison, pas à l'engagement**.

La boue et les ruines n'en portent pas : elles se voient déjà au sol, et les badger mettait vingt-sept pastilles sur le faubourg. Les passes de capture (`--essai`, `--interface`, `--banc`) n'en affichent aucune : les images de référence jugent la ville.

## Contrôles

`Godot --path Godot --script res://outils/essai_ouverture.gd -- --ouverture --captures` joue le relogement, le mauvais champ, les deux débuts par clics, la comparaison sans dépense, le refus financier, l'épargne, la livraison, les piétons, la protection, le mode auteur, la sauvegarde et la reprise. Ajouter `--headless` et retirer `--captures` pour le contrôle sans image. `python QGIS/scripts/verifier_relogement.py` contrôle l'export (6 cas).

Captures dans `QGIS/rendus/` : `wehrau_ouverture_01_relogement.png`, `..._02_camp.png`, `..._03_depart.png`, `..._04_choix_rue.png`, `..._05_livraison.png`, `..._06_protection.png`, `..._07_logements.png`, `..._08_camp_vide.png`.

Validé le 2026-09-17 : ouverture 0 échec, trafic 0, travaux 0, essai général rendu sans alerte ; 6 contrôles de relogement, 6 campagne, 3 voirie, 11 crue. **Deux dettes trouvées et laissées** : `verifier_berges` attend 8 berges et en trouve 9 (antérieur), et `essai_sauvegarde` compte 94 « lieu sans nom » — les 88 champs et la 9ᵉ berge n'ont pas de nom dans `Godot/data/lieux.json`. **Les trois champs du relogement s'affichent donc « Îlot 1082 » dans la scène d'ouverture.**

Validé le 2026-09-06 : essai rendu de l'ouverture, essai général rendu, essai de sauvegarde ; zéro échec dans les contrôles. Chaîne régénérée. `_posee` acceptait seulement un booléen et comparait mal les deux états de berge : corrigé.

## Ce qui attend le joueur

- Après une livraison, a-t-on envie de regarder le résultat puis de choisir la suite ?
- Le déblaiement et la remise en état font-ils deux débuts suffisamment différents ?
- La renaturation demande-t-elle trop d'épargne après la première réparation ?
- Le camp de containers est-il assez laid, et le champ assez perdu, pour qu'on veuille relever les logements ?
- 1,5 k€ le logement de containers : la moitié de la caisse est-elle le bon prix ?
- Défauts à signaler : réussite avant livraison, rue toujours vide, dépense dès la comparaison, premiers pas perdus après reprise, guide qui masque les commandes, camp qui déborde du champ, pastille qui reste après une livraison.

La crue suivante reste une prévision, sans événement daté. Le retour des piétons représente la praticabilité locale ; le faubourg reste coupé de l'autre rive tant que les ponts ne sont pas réparés. Le capital politique n'est pas introduit par cet essai.

## Campagne du SVG vers Godot — 2026-09-15

Les 88 champs gardent leur contour importé, leur teinte et des bandes parallèles à leur grand côté. La grille agricole globale est retirée ; prairies et cultures se distinguent davantage. Les deux massifs portent des croupes boisées et se prolongent dans le décor extérieur, sans seconde ceinture de champs.

Les quatre sorties principales suivent exclusivement les limites communes de deux champs existants (623 m) et s'arrêtent à la lisière. Chaque angle du SVG est conservé ; aucun prolongement ne traverse la forêt ou les montagnes. Les dessertes 177 et 178 s'arrêtent avec les îlots, à la demande de l'auteur. Les prolongements sont du décor ; les décisions et le trafic restent sur les tronçons existants. Les arbres sont écartés des nouvelles chaussées.

Contrôles : `verifier_campagne.py` (6 cas), `verifier_voirie.py` (3 cas), chaîne complète et aires des 88 champs exportés vérifiées (écart maximal 0,013 %), axes des prolongements contrôlés sur les limites communes (écart inférieur à 1 mm), et trois cadrages Godot via `--script res://outils/apercu_campagne.gd`. Aperçus : `QGIS/rendus/wehrau_campagne_dessus_apres.png`, `..._relief_apres.png`, `..._champs_apres.png` ; `..._avant.png` garde le même cadrage avant correction.

À regarder : ① contours des champs, ② sortie ouest posée sur la limite des champs, ③a/b montagnes. Défauts à signaler : route coupant un champ ou dépassant sa lisière, champ réapparu derrière un massif, rupture rectangulaire du paysage. Les chemins d'accès aux fermes restent à dessiner. Les alertes d'export concernant les anciens ponts et les effectifs attendus de l'ancienne carte restent un chantier distinct.

## Emprise de boue — 2026-09-16

Le contour annoté par l'auteur limite le dépôt à l'est, indépendamment des îlots. Le nord et l'ouest de l'Ilse restent propres ; les dégâts des bâtiments et la boue lisent le même champ spatial. La route 177, ancienne desserte traversant le nouveau lit au sud, est retirée de la carte de travail. Aperçu numéroté : `QGIS/rendus/wehrau_emprise_crue_apres.png`.

Chaîne régénérée ; 20 contrôles Python passent et le rendu des trois zones est vérifié. Les premiers lieux passent aux Forgerons, avec la berge de leur bief. **Reste : deux échecs du parcours d'ouverture sur la réparation des logements ; le bouton d'engagement dépasse le bas de la fiche.** Tests arrêtés à la demande de l'auteur avant correction de cette interface ; la passe générale n'est pas déclarée validée.

## Quai aval le long de l'Ilse — 2026-09-17

À la demande de l'auteur, la route 178 suit la rive est jusqu'au bord sud du champ 1082 : six sommets, 235,7 m, raccord au réseau conservé. Son ancien tracé droit disparaît. Les champs rendus cèdent désormais la place aux chaussées qui les traversent ; leur contour source reste intact.
Chaîne régénérée, neuf contrôles voirie/campagne passent ; aucun centre des 120 triangles du quai n'est masqué par un champ. Aperçu numéroté : `QGIS/rendus/wehrau_quai_aval_apres.png`, reproductible avec `--script res://outils/apercu_quai_aval.gd`. À regarder : ① raccord, ② route continue au bord de l'Ilse, ③ arrêt au dernier champ ; une chaussée recouverte par le champ ou prolongée dans la forêt serait un défaut.
