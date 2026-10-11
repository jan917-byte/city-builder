# ETAT.md — où on en est
> **Signet, pas source.** Design → le vault · carte → `QGIS/data/source/` · détail de l'étape → sa note · ce qui s'est passé → [HISTORIQUE.md](HISTORIQUE.md).
> **Plafond : 40 lignes, une idée par ligne.** Une ligne pointe, elle ne raconte pas.
## Étape ouverte — 6, [Premiers pas](Prototype/Premiers%20pas.md) 🎯 (rouverte le 2026-09-30 pour l'étude de la prochaine crue)
## Prochaine action
1. 🎓 **Rejouer les premières minutes** (retour du 2026-10-08) : pont livré → « Trouver l'université » → campus à trois lieux → « Rebâtir les logements » → planche `wehrau_premieres_minutes_planche.png` (1 à 8), note § Le campus en trois lieux. 🔴 découpe et prix des pilotis.
2. 🛤️ **Corriger le plan du campus** sur `wehrau_campus_plan.png`.
3. **Alléger l'interface** (trop dense au début) : captures numérotées de l'urgence au pont et après, l'auteur coche ce qui reste.
4. 📖 **Juger le livre des concepts** (101 à 103) → note § Le livre des concepts, planche `wehrau_livre_planche.png` ; 🔴 régler le sol perméable sur la jauge.
5. Porter au vault la règle du 2026-10-05 (le guide se tait pendant le chantier, la carte du pont après 5 s de ville) → note § L'étude.
- Contrôles : `essai_ouverture.gd -- --ouverture --captures` (note § Contrôles), puis `chaine.py --godot` et la passe `-- --essai`, qui sort ses images dans `QGIS/rendus/`.
## Ce qui attend l'auteur
- ❄️ **Saisons** à juger → [Saisons](Prototype/Saisons.md), `wehrau_saisons_planche.png` ; couleurs, branches et flocons flaggables (90).
- 🌊 **La prochaine crue** : un mois de recherche, à juger ; la faire tomber entre 6 et 8 ans ; 🪵 dégâts : densités et flaggable (90), `wehrau_debris_01_vue.png` → [Premiers pas](Prototype/Premiers%20pas.md), `wehrau_campus_trois_parties_planche.png`.
- 🚿 **La vie au camp** (usure, « Améliorer le campement », détail argent/confiance) → même note § La vie au camp.
- 🌉 **Pont provisoire** : prix, durée, débit ; 🔴 **prix de l'aide** (0,4 k€/personne/mois) et noms proposés ; 🟤 l'Ilse limpide en 4 mois (question 35) → même note.
- 🏢 **Densifier** : 95 k€ le logement, l'îlot médian à 1 330 k€ ; `PROGRESSIVITE` 0,4 → [Densifier](Prototype/Densifier.md).
- 🎓🏛️ **Université et mairie** attendent le capital politique ; la ville possède tout (70) → [Recherche et mairie](Prototype/Recherche%20et%20mairie.md).
- ☀️🌿 **Toit partagé** : aucun toit coupé en deux sur `wehrau_essai_toit_vert.png` et `wehrau_interface_toit_partage.png`.
- 🟠 **Toits plats, 3,0 ha sur 34 îlots** (`COMPLEXITE_PLAT`) : 17 îlots n'en ont qu'un ou deux, leur curseur vert est un interrupteur → `wehrau_toits_3ha_avant_apres_1.png`.
- 🎨 **Passe graphique** : trois planches numérotées et les couleurs d'accent ; cours vides hors barres → [Toits et sol](Prototype/Toits%20et%20sol.md) § 9 à 12.
- 🌳 **Sorties de ville** : la haie de la sortie est a disparu, le talus des champs ne se voit pas → même note § 8.
- 🚗 **Trafic** : cinq nombres de foule, virages arrondis, vélo éteint (`VELO_ACTIF`), le rendu tient l'image (884 000 triangles) → [Trafic](Prototype/Trafic.md).
- 🔲 **Interface « vitre »** : lisible sur les toits orange ? `-- --interface`, `-- --habillage bois`. **Police** parmi six (`-- --police …`, Rubik en place ; Baloo 2 agrandit la fiche) → `polices_comparaison.png`.
- 🟠 **Dessin à compléter** : massifs plafonnés à 90 m faute d'`altitude_m`, accès aux 11 fermes, 177/178 arrêtées avec les îlots, calque `routes` à ouvrir.
- 🔴 **La barre fait 5 niveaux, pas 6** : le ±1 de `04c` la met à 13,5 m, la hauteur refusée le 2026-08-19 ; `04c` l'imprime.
- 🔴 **Berge au stade « quai apaisé »** : elle ne rachète presque plus rien depuis que les rues sont sur la terre ; `rive_m` pour la remplacer → [Trafic](Prototype/Trafic.md), décision 73, question 24.
- 🔴 **Le talus de la berge rendue empiète sur l'Ilse**, et l'échantillon droit ne dit plus où l'on est → [Toits et sol](Prototype/Toits%20et%20sol.md).
- 🔴 **Planter n'épargne presque rien** (880 k€ pour 0,34 %) : un autre effet, ou l'assumer → [Trafic](Prototype/Trafic.md).
- 🔴 **La facture de la crue** : 14 445 k€ contre 8 000 k€ de caisse en vingt ans ; prix de `04e` = level design (question 23) → [Crue](Prototype/Crue.md).
- 🔴 **Les nombres du « dur mais possible »** : 260 €/m² de panneau, 150 €/MWh, caisse (86), 30 k€/mois, toit vert 140 €/m² et 0,25 m/ha ; dès 0,25 m de crue en moins, 4 des 102 bâtiments condamnés se sauvent ; gisement solaire bas (3,15 ha équipables).
- 🔴 **Arbitrages à consigner** dans `Questions ouvertes.md` **et** `Décisions arrêtées.md` : les cinq de rendu du 2026-08-18 (couleur par époque, calque tissu, zéro asset, étapes 4/2, la DA « un `sous_type` = une teinte » à corriger), deux vues, retrait du verrou (contre 72), ce que rachète un toit vert, solaire OU vert au bâtiment, perspective douce 35° (`wehrau_perspective_comparaison_1.png`), DA vitre et police, réchauffement (36), météo par partie.
- 🟠 **Percée des îlots** (9 m tous les 60 m, level design, `--ilots 49`) · **noms de lieux** : six proposés dans `Godot/data/lieux.json`, 91 sans nom.
- 🟠 **Le classeur** : banc d'essai ou archive ? Un deuxième moteur à moitié entretenu ment sans qu'on le sache.
- ⏸️ **Étape 2 en pause** (le peigne de `04c`) : ne pas la rouvrir tant qu'une autre est ouverte → [Parcelles](Prototype/Parcelles.md) § 7.
## Commandes
`python QGIS/scripts/chaine.py [--godot]` refait tout · `--gabarit` repart du dessin Illustrator · `apercu_parcelles.py` le parcellaire numéroté · `08_jouer.py --toutes` le classeur. Détail → `QGIS/README.md`, `QGIS/data/LISEZ-MOI.md`, `Godot/README.md`.
