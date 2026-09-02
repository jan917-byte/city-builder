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

- **Les règles** (stationnement payant, toit vert obligatoire) : elles se paient en **capital politique**, qui vit encore dans le classeur et pas dans la maquette. La fiche de la mairie le dit à l'écran plutôt que de faire semblant.
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
