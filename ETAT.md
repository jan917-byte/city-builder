# ETAT.md — où on en est
> **Signet, pas source.** Une ligne par sujet, et un lien vers là où il vit. Design → le vault · carte → `QGIS/data/source/` · ce qui s'est passé → [HISTORIQUE.md](HISTORIQUE.md).
> **Plafond : 40 lignes, une idée par ligne.** Ce qui demande une phrase de plus va dans la note d'étape.

## Étape ouverte — 6, [Les premiers pas](Prototype/Premiers%20pas.md)
Critère : *après la première réparation livrée, le joueur veut choisir la suite.* Les étapes 2, 4, 5, 7 et 8 sont en pause → [tableau](Prototype/00%20-%20Prototype.md).
🎮 **Le jeu est sur itch.io, en privé, pour les potes testeurs** (2026-10-22, version Windows). Refaire le zip → `Godot/README.md` § Le lancer, puis le redéposer sur la page.
## Prochaine action
- 🏛️ **Jouer l'ouverture, la mairie d'abord** (117) : pont rouvert → mairie seule → concours (1 point) → étude (80 k€) → université, **cliquée comme un seul îlot, son étude encadrée** (2026-10-22, `essai_campus.gd`). Quoi regarder et quels défauts chercher → [Premiers pas](Prototype/Premiers%20pas.md) § À jouer et § Ce qui attend le joueur. 📸 Captures non prises le 2026-10-19 : `essai_ouverture.gd -- --ouverture --captures`.
- 🪟 **Tes fenêtres en 3D** : `Godot/assets/fenetres/gabarit_fenetres.blend`, une façade type par famille, rez compris, 27 ouvertures à modéliser dans leur cadre orange (LISEZ-MOI dans le fichier, plan numéroté `QGIS/rendus/gabarit_fenetres.png`) ; ensuite je les cuis dans le mur. Frontière concours / habillage tranchée → [Premiers pas](Prototype/Premiers%20pas.md) § L'étude de la prochaine crue, fin.
- 🏚️ **Bâtiments de cour** à un niveau, toit plat sans souche, 12 × 6 m (commités le 2026-10-20) — à voir à l'écran.

## À juger à l'écran
- 💶 **Deux budgets** (118) et 🪜 **la complexité peu à peu** (119, argent sans « chaque mois » au début, trois études de cartes à la mairie) : 1 500 k€ d'urgence, le fonds de 2 000 k€ à la mairie, le pont en dur et le pont résistant → [Premiers pas](Prototype/Premiers%20pas.md) § Deux budgets.
- 🔴 Prix de l'étude, points de l'institut ; 🏛️ **le concours par îlot** (2026-10-21 : trois lauréats selon le lieu, pilotis et parc bloqués jusqu'à l'institut, `concours_05_four`, 50 k€, 15 jours, chantiers à 9 mois, captures `wehrau_ouverture_concours_04` à `_06` ; 115 à réécrire au vault ; ✏️ les parcellaires des lauréats à entourer sur `wehrau_variantes_parcellaire.png`, `apercu_variantes.py` ; emprises refaites le 2026-10-21, avant/après → [Parcelles](Prototype/Parcelles.md) § 2 decies) → [Premiers pas](Prototype/Premiers%20pas.md) § L'étude, § L'institut vend les actions.
- ⚙️ Panneau Graphismes : « ombres moyennes » ou « fines » par défaut → `QGIS/rendus/planche_graphismes_*.png` ; rebond allumé par défaut (+0,5 ms) ; flou, ciel et brume au panneau, éteints ; couleurs douces écartées → [Toits et sol](Prototype/Toits%20et%20sol.md) § 12-13.
- ❄️ Les saisons (printemps, essences, fumée) et 🌳 **les arbres du pack, nos couleurs** (2026-10-22, `wehrau_arbres_avant_apres.png` ; l'hiver validé : `wehrau_arbres_hiver_ramure.png`) → [Saisons](Prototype/Saisons.md) ; couleurs et flocons flaggables (90).
- 🪵 Les dégâts de la crue, densités → [Premiers pas](Prototype/Premiers%20pas.md) § Les dégâts de la crue ; 🏢 densifier à 95 k€ le logement → [Densifier](Prototype/Densifier.md).
- ⏱️ **Le temps à 70 s le mois, les constructions plus courtes, la carte des chantiers en %** (2026-10-22) ; 🗓️ **la date sur deux lignes, au bord de la fiche, sans jauge de crue ni bouton du journal** (`wehrau_date_avant_apres.png`) → [Premiers pas](Prototype/Premiers%20pas.md) § La première année, fermée.
- 🔲 Interface « vitre » et choix de la police parmi six (Rubik en place) → `QGIS/rendus/polices_comparaison.png`.
- 🟠 La percée des îlots compacts (9 m tous les 60 m, `04d`) → `--ilots 49`.
- 🚶 **Fusionnés le 2026-10-20** : venelles en trace (122, `QGIS/rendus/wehrau_venelles.png`), pont coupé cliquable au milieu de l'Ilse, phrase de l'autre rive, fenêtre « Desire Path ».
- ✍️ **Les textes flaggables à réécrire** (90) → `Prototype/Textes des premières minutes.xlsx` ; les noms de lieux → `Godot/data/lieux.json`.

## À trancher (l'auteur)
- 💶 **Les systèmes d'argent avant la seconde crue** : A recettes et entretien (59) · B budget voté (n°21) · C coûts qui durent — recommandé A puis B → `Vault - Jeu urbanisme/Production/Feuille de route.md`.
- 🔴 **Des arbitrages pris mais jamais consignés** → Questions ouvertes n°49 (plus la perspective 35° et la police) ; n°47 (parc sur une partie d'îlot), n°48 (champs dans les moyennes), n°50 (références au titre). La Feuille de route garde un seuil de 5 000 wishlists que 47 a retiré.
- 🔴 **La facture de la crue** : 14 445 k€ pour 8 000 k€ de caisse en vingt ans → [Crue](Prototype/Crue.md).
- 🔴 **Les nombres de *dur mais possible*** (panneau, MWh, caisse, dotation, toit vert) → [Énergie](Prototype/%C3%89nergie.md), [Crue](Prototype/Crue.md).
- 🔴 **Ce qu'un arbre épargne** (0,34 % pour 880 k€) : un autre effet, ou l'assumer → [Trafic](Prototype/Trafic.md).
- 🔴 **La berge au stade « quai apaisé » ne rachète plus rien** ; remplaçant possible : `rive_m` → [Trafic](Prototype/Trafic.md).
- 🔴 **La barre fait 5 niveaux au lieu des 6 décidés** (`04c`, ±1 niveau).
- 🟠 **Le classeur** : banc d'essai des seuils, ou archive ? **Le dessin** : accès aux 11 fermes, calque `routes` pour les tracés manuels.

## Les commandes du quotidien
```
python QGIS/scripts/chaine.py [--godot]          → LA commande : la carte, les bâtiments, la maquette
python QGIS/scripts/chaine.py --gabarit --godot  → … en repartant du dessin Illustrator
```
Le détail des scripts → `QGIS/README.md` · la maquette et ses touches → `Godot/README.md`.
