---
tags: [méta, questions, actif]
statut: ⚠️ à traiter
maj: 2026-08-11
---

# Questions ouvertes

## ⏸️ Mise de côté volontairement

### 1. Combien de temps dure une partie ? — **reportée le 2026-08-11**

Ce n'est plus la question qu'on croyait. **Le jeu n'a pas de fin imposée** : la partie continue jusqu'à ce que le joueur s'ennuie et n'ait plus grand-chose à faire — Minecraft, Cities: Skylines. On recommence alors en prenant **d'autres décisions**, et c'est de là que vient la rejouabilité, pas d'une condition de victoire. → [[Décisions arrêtées]] 14c

**Hypothèse de travail en attendant** : ~20 ans d'évolution en ~2 h pour le prototype. **Non fixé, assumé comme tel** — de quoi écrire le classeur sans se mentir. → 14b

Ce qui reste vrai et qu'il faudra reprendre un jour : ce n'est pas le temps passé au clavier qui commande l'équilibrage des délais, c'est le **nombre de mois simulés**. Une spirale de déclin qui met quinze mois à s'installer ne dit pas la même chose sur 60 mois et sur 240. À rouvrir quand les 5 parties de la semaine 3 auront donné des chiffres — pas avant.

*Plus rien ne bloque le classeur de la semaine 2.*

## 🟠 Structurantes — à trancher pendant le mois 1

### ~~2. Le capital politique : un chiffre ou plusieurs groupes ?~~ ✅ **close le 2026-08-11**
**Un chiffre.** Le risque des jauges d'humeur est écarté ; ce qu'on perd — le « pour qui on fait la ville » — se récupère en exigeant que chaque décision **nomme qui perd** dans son `effet_de_bord`. → [[Décisions arrêtées]] 16b · [[Ressources]]

### 3. D'où vient l'argent ?
Budget fixe, ou recettes dépendant de la ville ? Le second est plus riche mais recrée une exponentielle. Contrepartie proposée : les charges d'entretien du réseau montent avec l'étalement. → [[Ressources]]

### 4. Le deuxième axe des fins
Les trois archétypes s'effondrent sur un seul axe et deux d'entre eux sont photographiquement indiscernables. Il faut un axe orthogonal qui produise des **différences de forme urbaine**. → [[Fins et pluralisme]]

⚠️ **Les [[Milestones]] ne répondent pas à cette question** — ils sont cumulables, les fins s'excluent. Mais l'un d'eux pourrait faire l'axe : **« personne n'a été chassé »**. Tous les autres jalons disent *quel domaine on optimise* ; celui-là dit *à quel prix*, et il pousse contre tous les autres au lieu de s'ajouter à côté. Proposé le 2026-08-11, non tranché.

### 5. Quelle est LA décision la plus satisfaisante ?
Celle que le joueur montre en disant *« regarde ce que j'ai fait »*. Candidat le plus fort à l'échelle du jeu complet : **que faire de [[La Fonderie]]** — hors périmètre du prototype.

**Candidat désigné pour le prototype** : **libérer la place du marché de ses voitures** ([[Wehrau]], îlot 19). C'est le point le plus central de la ville, il touche l'eau, et le même geste rend la place aux piétons **et** le centre à la rivière. Deuxième candidat : **rendre à l'eau** la rive aval, qui a l'avantage rare d'être une décision de **ne pas construire**. À départager par les 5 parties du mois 1.

### 6. Le premier clic et les 60 premières secondes
Toujours sans réponse. Se découvre en jouant, pas en réfléchissant.

## 🟡 Contradictions à résoudre

### ~~7. OSM : écarté ou réintroduit ?~~ ✅ **close**
Le tracé est manuel, la ville est fictive. La piste « empreintes OSM comme parcelles persistantes » tombe. Conséquence à assumer : la **subdivision de l'îlot en parcelles** reste dans le pipeline, et c'est l'étape la plus dure (2–4 semaines). → [[Génération procédurale]]

### ~~8. Périmètre : ville entière ou un quartier ?~~ ✅ **close le 2026-08-10, puis révisée le même jour**
Prototype = ~~[[Altstadt]]~~ → **[[Wehrau]]**, une petite ville entière. Meilleur rendement à coût égal : une ville, même petite, a un amont et un aval. → [[Périmètre et coupes]]

### 9. Une ville ou trois ?
Trois villes = trois fois le contenu. Test décisif : **si les structures urbaines sont identiques, une ville suffit avec trois scénarios de départ.** Trois villes ne se justifient que si leurs *formes* imposent des stratégies incompatibles. → [[Vallmar]]

### 10. Vallmar : je garde les noms ou je réécris ?
La structure est validée. Les noms sont à moi.

### ~~11. Quand tracer le deuxième quartier ?~~ 🟢 **détendue le 2026-08-10**
La question naissait de ce qu'un quartier seul ne peut pas tester « le lieu change le résultat ». [[Wehrau]] le teste : amont, aval, ville, campagne. Ce qui reste ouvert n'est plus le deuxième quartier mais **le changement d'échelle** : ce qui hésite dans une petite ville hésitera-t-il à 112 000 ? Ça se tranche au mois 3, pas maintenant. → [[Périmètre et coupes]]

### 12. Combien de franchissements pour l'Ilse ?
Le vault visait « deux ponts au maximum » pour que la rivière soit une vraie coupure. La carte du prototype en a **cinq** — confirmé le 2026-08-10, les cinq sont maintenant typés comme tels dans les données (tronçons 136, 145, 168, 169, 171). Trop de ponts = la rivière ne coupe plus rien, et « ajouter une passerelle » cesse d'être une décision. Soit on en supprime deux au tracé, soit on assume que la coupure se joue ailleurs (la voie rapide de berge). → [[Wehrau]]

**Ce que les données ajoutent** : les îlots ne se touchent **jamais** par-dessus l'eau — la ville privée de sa rivière tombe en deux morceaux. La coupure des îlots est totale ; seules les routes franchissent. Supprimer deux ponts est donc une opération purement routière, sans effet de bord.

### ~~13. Combien d'habitants Wehrau porte-t-elle vraiment ?~~ ✅ **close le 2026-08-11**

**~5 350 habitants — pour le prototype.** La géométrie tranche : 38,3 ha bâtis ne portent pas 18 000 personnes, il y faudrait 470 hab/ha bâti quand un centre allemand dense plafonne vers 350. La carte est la source de vérité (décision 31b), et le chiffre annoncé s'aligne sur elle, pas l'inverse.

La décision ne concerne **que [[Wehrau]]** : [[Vallmar]] garde ses 112 000 habitants, la question de l'échelle du jeu complet reste entière (n°11).

Ce que ça engage, et qui reste à écrire : le lycée devient une Realschule, la galerie de 1971 un supermarché avec parking en toiture, la barre de 1974 un petit Neubau. Aucun des trois n'est absurde à 5 350 habitants, aucun n'est évident non plus. → [[Décisions arrêtées]] 13d

### 14. Le grand ensemble de 1974 est à 200 m de l'eau
Le vault écrit qu'il est « posé contre l'eau ». Dans les données, l'îlot 32 est à **199 m de l'Ilse**, altitude relative 3,2 m, aléa 0,53. Il est bien le plus en aval de toute la ville (fil de l'eau 0,84) et de loin le plus fragile socialement (0,85) — l'injustice tient. Mais il n'a pas les pieds dans l'eau.

**Recommandation : garder l'îlot 32 et corriger la phrase** — « en aval, dans la plaine élargie » plutôt que « contre l'eau ». Ce qui fait l'injustice ici n'est pas la proximité, c'est d'être en bout de chaîne : tout ce que l'amont imperméabilise lui arrive dessus.

L'alternative serait de déplacer la barre sur l'îlot 58 (39 m de l'eau, en aval) — mais il ne fait que 0,45 ha, trop petit pour un grand ensemble, et ça libère l'îlot le plus en aval de la carte.

### ~~15. Le jeu s'ouvre-t-il sur une crue ?~~ ✅ **close le 2026-08-11**

**Oui — et elle tombe sur la rive gauche.** Le jeu s'ouvre sur une inondation majeure, des ruines encore chaudes, et **une seconde crue annoncée** : c'est elle qui transforme « ne pas reconstruire » d'un choix sentimental en un calcul.

Ce n'est pas la ville qui est frappée, c'est le **faubourg de rive gauche** — 13 îlots, 417 logements, aléa moyen 0,75 contre 0,43 sur l'autre rive. Le brainstorm d'origine imaginait une rive droite industrielle sinistrée ; la carte dit autre chose, et dit mieux : *le petit bout de ville d'en face qu'on pourrait décider de ne pas reconstruire*. Treize îlots, un sixième du parc, et personne pour peser dans un conseil municipal.

Ce que la carte porte : à +2 m, **23 îlots et 935 logements** touchés (37 % du parc) ; à +3 m, 30 îlots et 1 320 logements (52 %).

Ce qui reste à écrire, et qui est le travail de la semaine 2 : quelles décisions le premier tour propose, et laquelle est « rendre à l'eau ». → [[Décisions arrêtées]] 23b · [[Wehrau]] · [[Décisions]]

## 🟢 Peut attendre (réversible)

Style graphique définitif · moteur verrouillé · nom · modèle économique et prix · nombre de langues

**Voir aussi** : [[Décisions arrêtées]] · [[Plan 3 mois]]
