# Les saisons — voir le temps passer

> Étape 8, faite le 2026-10-10 à la demande de l'auteur pendant que l'étape 6 reste ouverte. **À juger**, pas ouverte.
> Pas encore de note au vault : les arbitrages ci-dessous sont à consigner à la fin du chantier.

**Critère proposé** : sans interface, on devine le mois à deux mois près, et on distingue un hiver de l'an 18 d'un hiver de l'an 1.

## Ce que l'auteur a tranché (2026-10-10)

- Le réchauffement est une **tendance mondiale** : le joueur ne la change pas (réponse partielle à la question 36).
- **Le visuel d'abord.** Rien ne touche encore au solaire, au chauffage ni à la caisse ; on les branchera plus tard.
- **La météo est tirée au hasard à chaque partie**, et gardée dans la sauvegarde. « Recommencer » tire une nouvelle partie.
- **Des saisons, pas une météo** : **une seule neige par hiver**, plus ou moins longue selon l'hiver, et **plus courte au fil des ans**. Elle arrive lentement, **collines d'abord, puis toits et arbres, puis le sol**, et fond par le bas ; de légers flocons tombent pendant qu'elle arrive.
- Les arbres nus montrent **leurs branches**.
- Les couleurs de saison sont **les miennes, provisoires et flaggables (90)** : l'auteur les remplacera.

## Ce qu'on voit

| | Ce qui change dans l'année |
|---|---|
| Feuillus de ville | bourgeons en voile vert tendre deux semaines avant la feuille, puis vert tendre plus ou moins jaune, vert ; couleurs d'automne en octobre (jaune, orange, roux selon l'arbre), nus fin novembre ; chaque arbre à deux semaines près de son voisin, et chacun son vert, du jaune au bleuté |
| Variétés (2026-10-19) | **cerisier à fleurs** rose avant ses feuilles (avril), **marronnier** à bougies blanches (mai), **hêtre pourpre** rouge vin l'été, rose cuivré au débourrement ; dans les jardins un feuillu sur six environ, sur une rue toute la rue |
| Tilleul (2026-10-19) | l'arbre d'alignement : ovale, dense ; jaune à l'automne. Une rue plantée tire une essence pour toute sa longueur : tilleul, cerisier, marronnier ou feuillu |
| Bouleau, peuplier | jaunes à l'automne ; le peuplier nu garde sa flèche |
| Fruitiers | en fleurs mi-avril, en taches sur le vert tendre ; un sur trois à fleurs roses |
| Saule | le premier vert, le dernier jaune ; nu, ses rameaux retombent |
| Conifères | verts toute l'année, la neige se pose dessus |
| Roseaux | paille d'octobre à mai, sur pied |
| Buissons, forêt | nus, ils gardent une masse de rameaux brun-gris (pas de branches), qui verdit au débourrement |
| Herbe | terne l'hiver, tendre au printemps, jaunie les étés chauds |
| Neige | une fois par hiver, entre le 10 décembre et le 25 janvier ; douze jours pour arriver (collines, toits et couronnes, jardins et champs, par grands pans), dix pour fondre ; **la chaussée reste déneigée** |
| Flocons | à l'écran, légers, seulement pendant l'arrivée ; absents en vue diagnostic |
| Fumée (2026-10-19) | des bouffées grises sortent des souches des maisons anciennes et d'un toit plat sur deux (une souche au bord, deux sur les longs) et partent vers l'est ; en été une souche sur vingt, toutes sous 2 °C, plus épaisses et plus hautes ; ni des ruines ni du bâti rebâti moderne ; elle suit l'étage ajouté ; absente en vue diagnostic |
| Collines | blanches en hiver au-dessus d'une limite qui monte avec les années |
| Thermomètre du haut | la température **tirée** du mois, plus la normale |

## Les chiffres

- `essai_saison`, 400 parties : **3,3 semaines** de neige par hiver des ans 1 à 5, **2,3** des ans 16 à 20 ; chaque hiver a sa neige, l'hiver le plus court en tient **1,2**. Graine 7 : de 1,2 à 7 semaines selon l'hiver.
- Limite de neige des collines hors neige de l'hiver, graine 7 : **120 m** en janvier de l'an 1, **774 m** en janvier de l'an 18. Les collines visibles plafonnent vers 250 m, plus haut c'est la brume du bord.
- Banc, ville entière : **6,83 → 6,96 ms/image**, 9,66 → 10,43 millions de triangles (les branches, repliées l'été).
- Essais : général sans erreur ; sauvegarde, les 92 échecs connus (lieux sans nom), la météo reprise à l'identique.

## Quoi regarder

`QGIS/rendus/wehrau_saisons_planche.png`, numérotée de 1 à 12. La refaire :

```
Godot_console.exe --path Godot --position 6000,6000 --script res://outils/apercu_saisons.gd
python Godot/outils/planche_saisons.py
Godot_console.exe --headless --path Godot --script res://outils/essai_saison.gd
Godot_console.exe --path Godot --position 6000,6000 --script res://outils/apercu_arbres.gd -- --mois=9.5
```

En jouant : laisser filer en ×1 puis ×12 un hiver entier. **Ce qui prouverait que c'est cassé** : deux neiges dans le même hiver, une ville qui blanchit d'un coup, des flocons hors de la chute ou en vue diagnostic, des arbres verts en janvier, de la neige sur la chaussée, de la neige en vue diagnostic, des bâtons bruns qui sortent d'une couronne en été, ou deux nouvelles parties avec les mêmes hivers.

## Ce qu'on perd

- **La partie s'ouvre arbres nus** : la crue tombe fin février, donc le 1er mars est gris, et le vert n'arrive qu'en avril.
- **La neige blanche sous une interface claire** : le piège de Frostpunk, noté dans la direction artistique.
- La neige sur un toit cache ses panneaux solaires, comme en vrai.
- **L'hiver sans neige** ne raconte plus le réchauffement : il se lit à la neige plus courte et aux collines qui ne blanchissent plus. À ×12, l'arrivée ne dure que deux secondes.

## Ce qui reste

- 🌸 **Les arbres du printemps, à juger** (2026-10-19, demande de l'auteur : « au printemps c'est pas très beau ») : `apercu_arbres.gd -- --mois=1.5`, pépinière en 16 numéros. Le tilleul, les variétés et le choix d'essence par rue sont **proposés** : les parts sont en haut de `Constructeur.variete` et dans `maquette._essence_rue`. ⚠️ La teinte qui glisse d'un arbre à l'autre s'écarte de « une teinte, des valeurs » de la direction artistique : à trancher. La miniature de la fiche d'une rue montre encore un feuillu ordinaire.

- 🌳 **Les arbres du pack, à juger** (2026-10-22, demande de l'auteur : « garde nos couleurs ») : la forme des packs craftpix (`Godot/modeles/`), nos verts, nos saisons, notre écorce. Planches numérotées `QGIS/rendus/wehrau_pack_arbres_numeros.png` et `_buissons_` : feuillu 7, conifère 18, bouleau 5, peuplier 4, fruitier 2, saule 15, tilleul 6, buisson 7 (pack buissons) ; le roseau reste dessiné par le code. Chaque modèle est étiré à la hauteur **et** à la largeur de l'arbre d'avant (espacements, part d'ombre des fiches). Le n° 1 (couronne plate) faisait une forêt de savane : écarté. Avant / après : `QGIS/rendus/wehrau_arbres_avant_apres.png`.
  - **Ce qu'on perd** : chaque arbre d'une essence a la même couronne, seuls taille, rotation et penché varient (avant, ses lobes grossissaient, bougeaient, manquaient) ; les arbres nus montrent le bois du modèle au lieu des branches dessinées.
  - **De loin** (la forêt en vue d'ensemble ; de près, à la lisière, le modèle entier), chaque modèle passe à une version allégée : ses blocs de feuillage en volumes à six côtés, son bois en un fût (`--loin` force cette version sur l'aperçu). En ville, jamais : elle n'y gagnait rien et cachait les modèles dès 340 m. Coût mesuré contre les recettes d'avant (RX 9060 XT, 1080p, GPU) : vue d'ensemble 7,8 → 8,4 ms, cœur ancien 7,2 → 8,0 ms ; sans la version de loin, la forêt seule coûtait +7 ms.
  - **Cassé si** : les anciennes boules rondes (modèle non lu : avertissement « arbre : … illisible » dans la console), un arbre vert en janvier, un tronc vert, une couronne détachée de son tronc l'hiver, des arbres qui flottent ou s'enfoncent.
- 🎨 **Les couleurs** (`Godot/shaders/saison.gdshaderinc`) et **les flocons** (`Godot/shaders/flocons.gdshader`) sont flaggables : voie sans IA, l'auteur choisit les couleurs et dessine un flocon. Les branches nues viennent des modèles du pack, plus du code.
- 🔥 **La fumée, à juger** (2026-10-19, demande de l'auteur) : `QGIS/rendus/wehrau_fumee_planche.png` (outil `apercu_fumee.gd`) ; sans lumière, gris moyen, plus foncée sous la neige pour s'y voir. Flaggable (90), voie sans IA : l'auteur règle teinte, taille et vent en haut de `Godot/shaders/fumee.gdshader`. **Cassé si** : des carrés gris nets, de la fumée l'été sur toutes les cheminées, ou qui reste au toit d'avant un étage ajouté.
- ☀️ Le soleil ne baisse pas l'hiver : les ombres sont les mêmes toute l'année.
- 🌾 Les champs ne changent qu'avec la neige : leur saison viendra avec la Campagne.
- 🔌 Brancher la saison sur le solaire, le chauffage et la crue : plus tard (auteur).
- Les réglages : haut de `saison.gd` (rythme du réchauffement, tenue de la neige, durée de l'arrivée et de la fonte, limite des collines), dates de chaque essence dans `feuillage.gdshader`, brume de rameaux dans `constructeur.gd`.
