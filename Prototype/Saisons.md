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
| Feuillus de ville | vert tendre début avril, vert, couleurs d'automne en octobre (jaune, orange, roux selon l'arbre), nus fin novembre ; chaque arbre à une semaine près de son voisin |
| Bouleau, peuplier | jaunes à l'automne ; le peuplier nu garde sa flèche |
| Fruitiers | en fleurs blanc rosé mi-avril, avant leurs feuilles |
| Saule | le premier vert, le dernier jaune ; nu, ses rameaux retombent |
| Conifères | verts toute l'année, la neige se pose dessus |
| Roseaux | paille d'octobre à mai, sur pied |
| Buissons, forêt | nus, ils gardent une masse de rameaux brun-gris (pas de branches) |
| Herbe | terne l'hiver, tendre au printemps, jaunie les étés chauds |
| Neige | une fois par hiver, entre le 10 décembre et le 25 janvier ; douze jours pour arriver (collines, toits et couronnes, jardins et champs, par grands pans), dix pour fondre ; **la chaussée reste déneigée** |
| Flocons | à l'écran, légers, seulement pendant l'arrivée ; absents en vue diagnostic |
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

- 🎨 **Les couleurs** (`Godot/shaders/saison.gdshaderinc`), **les branches** (`Constructeur._ramure`) et **les flocons** (`Godot/shaders/flocons.gdshader`) sont flaggables : voie sans IA, l'auteur choisit les couleurs, modélise une ramure nue par essence (cinq pièces) et dessine un flocon.
- ☀️ Le soleil ne baisse pas l'hiver : les ombres sont les mêmes toute l'année.
- 🌾 Les champs ne changent qu'avec la neige : leur saison viendra avec la Campagne.
- 🔌 Brancher la saison sur le solaire, le chauffage et la crue : plus tard (auteur).
- Les réglages : haut de `saison.gd` (rythme du réchauffement, tenue de la neige, durée de l'arrivée et de la fonte, limite des collines), dates de chaque essence dans `feuillage.gdshader`, brume de rameaux dans `constructeur.gd`.
