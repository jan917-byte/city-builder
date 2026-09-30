# Recherche et mairie — la version simple, branchée

**Ce n'est pas une étape ouverte.** L'étape 5 (le trafic) l'est toujours, et son critère n'a pas encore été vu à l'écran. Ce chantier-ci est une **version simple** des décisions **79** (l'université), **80** (la mairie) et **81** (deux portes), posée le 2026-09-02 sans toucher au trafic.

Le design est dans le vault (`Systèmes/Université et recherche.md`, `Systèmes/Mairie et politiques.md`). Ici : ce qui tourne, ce qui n'y est pas, et ce qui casserait.

## Ce qui tourne

| Le geste | Ce que ça fait | Mesuré |
|---|---|---|
| **Financer un sujet** à l'université | on paie chaque mois jusqu'au palier ; le sujet ne s'arrête plus, c'est un chantier | rendement **600 k€** · pose **360** · sédum **144** |
| **Le palier tombe** | il vaut pour **toute la ville, panneaux déjà posés compris** — et seulement à partir de son mois | mois 24 : la ville passe de **212 à 229 MWh/an** sans qu'un toit bouge |
| **Signer une subvention** à la mairie | un prix baisse tant qu'elle tient, et elle **prélève tous les mois** | îlot 49 à 100 % : **292 → 234 k€**, pour **6 k€/mois** |
| **Retirer une subvention** | la dépense s'arrête, ce qui a été versé reste versé | — |
| **Ouvrir un menu** | par le bouton du bandeau **ou** par le bouton de la fiche de l'îlot 20 / 36 | la fiche d'îlot garde tout : type, logements, conso, toit, curseurs |

Les paliers et les subventions se **multiplient** sur le même prix : recherche « pose » **et** subvention donnent −32 % sur un panneau.

## Quoi lancer, quoi regarder

`python QGIS/scripts/chaine.py --godot`, puis la passe d'interface :

```
/Applications/Godot.app/Contents/MacOS/Godot --path Godot -- --interface
```

Trois captures neuves dans `QGIS/rendus/` :

1. `wehrau_interface_ilot_universite.png` — **la fiche de l'îlot 36 reste une fiche d'îlot**, avec un bouton en plus. C'est le critère de 81.
2. `wehrau_interface_universite.png` — les trois sujets, leur prix mensuel, leur durée.
3. `wehrau_interface_mairie.png` — les deux subventions, et la ligne qui dit pourquoi les règles ne sont pas là.

Et deux contrôles imprimés, tous deux à ✅ : la subvention qui baisse le prix annoncé, et le **palier rétroactif**.

## Ce qui n'est PAS fait, et pourquoi

- **Les règles** (stationnement payant, toit vert obligatoire) : elles ne dépensent pas de capital, elles en demandent un **seuil**, relevé à chaque règle signée (**96**, **98**) ; leurs effets ne sont pas conçus. La fiche de la mairie le dit à l'écran plutôt que de faire semblant.
- **Les objets neufs** (stockage, réseau de chaleur, agrivoltaïsme) : c'est du contenu, pas du branchement. Les trois sujets actuels ne déplacent que des nombres.
- **L'éolienne volante** : écartée des paliers par **78**. Elle vit ailleurs — preview du futur, ou fin *solarpunk high-tech*.

## Les nombres sont du level design

| La table | Où |
|---|---|
| les trois sujets — prix mensuel, durée, effet | haut de `recherche.gd` |
| les deux subventions — prix mensuel, effet | haut de `politiques.gd` |

Repère pour les juger : la dotation est de **30 k€/mois**, la caisse de **800 k€** au départ. Une subvention à 6 k€/mois prend **un cinquième** de la dotation, et tout financer à l'université coûte **1 104 k€** — trois ans de dotation.

## Ce qui prouverait que c'est cassé

- Le palier tombe **mais les îlots déjà équipés ne bougent pas** : il n'est pas rétroactif, et c'est ce que 79 exige.
- La production **passée** monte aussi quand le palier tombe : le passé a été repayé au tarif d'après, et la caisse fait un bond.
- La subvention baisse le prix **et** la caisse ne perd rien tous les mois : elle est gratuite, ce n'est pas une politique.
- Couper une subvention rembourse ce qui a été versé.
- Cliquer l'îlot 36 n'ouvre **que** le menu, ou la fiche d'îlot se met à parler de recherche : les deux fiches ont fusionné, 81 tombe.
- Le menu ne s'ouvre qu'en allant sur place : le raccourci est devenu un détour obligatoire.

## Ce qui reste à trancher

- 🔴 **La subvention et le propriétaire unique** : la ville possède tout (**70**), donc subventionner déplace de l'argent d'une poche à l'autre. Soit ça vise le **programme** — accélérer un poste en prenant sur le reste —, soit 70 se rouvre. → vault, question n°25
- 🟠 **Retirer une politique** est gratuit aujourd'hui. Si ça le reste, signer n'engage à rien.
- 🟠 **La fiche du menu remplace celle de l'îlot**. C'est le choix fait ; à confirmer sur l'image.

## Le capital politique — 2026-09-30

Un compteur à côté de la caisse, dans le bandeau et en haut (**58**) ; le joueur le lit **« confiance »** (**97**). Il part de **50** et ne passe jamais sous zéro : à zéro, la fiche grise « Mettre en place » et dit ce qui manque (**96**).

| Ce qui le fait bouger | Quand | Combien (haut de `ville.gd`, 🔴 level design) |
|---|---|---|
| retirer des places, ou fermer aux voitures | à la décision | −0,2 par place — axe 55 : **−9** |
| … selon ce que la rue est devenue (**99**) | un an après la livraison | de 0,5 à 1,5 × la dépense : plus elle a perdu de trafic, plus elle rend ; un report sur une voisine retranche |
| des habitants rentrent chez eux | livraison de l'îlot relevé | +0,25 par logement — îlot 59 : **+11** |
| un pont rouvert | livraison | **+15** |
| plus personne ne dort dehors | livraison du dernier abri | **+5** |

Chaque mouvement est **dit dans le journal**, avec sa raison : le compteur ne bouge jamais sans phrase. La fiche annonce les trois moments — tout de suite, à la livraison, un an après.

**À regarder** : `-- --interface`, puis `wehrau_interface_rue_posee.png` (annotée : `wehrau_capital_politique.png`) — ① le compteur en haut, ② sa ligne sous la caisse, ③ la fiche de l'axe 55, places retirées : *−9 confiance, +5 à +14 un an après, selon la rue*. Contrôle : `Godot --headless --path Godot --script res://outils/essai_capital.gd`, 0 échec.

| Fermer aux voitures (mesuré avec le vrai trafic) | Charge avant | Report le pire | Coût, puis retour |
|---|---|---|---|
| Boulevard du Marché (55) | 1,00 | +0,42 rue des Fontaines | −9, puis **+5** |
| Boulevard des Saules (16) | 0,68 | aucun | −15, puis **+23** |
| Rue des Saules (77) | 0,54 | +0,20 rue des Saules (79) | −14, puis **+12** |
| Rue de l'Amont (120) | 0,06 | aucun | −16, puis **+10** — elle était déjà vide |

🔴 **Le Boulevard du Marché, le geste phare de l'étape 5, ne rend que la moitié** : son trafic déborde. À juger — c'est honnête, mais c'est aussi le premier exemple que le joueur essaiera.
**Serait un défaut** : un compteur qui bouge sans ligne au journal, un gain avant la livraison, un refus qui engage quand même, un capital sous zéro, une reprise qui change le compteur.
**Pas encore** : les postures d'un îlot sinistré (**95**), les règles de la mairie et leur seuil, le signe sur la carte (**93**). Un pont compte à sa livraison, que ses accès soient dégagés ou non.

