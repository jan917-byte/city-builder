# La campagne — ce que porte un champ

> Étape 7 ouverte le 2026-09-29 à la demande de l'auteur ; les Premiers pas passent en pause.
> Design : `Vault - Jeu urbanisme/Brainstorming/2026-09-29_brainstorm_campagne-vivant-indicateurs.md`, décisions 77c · 77d · 91.

## Ce que l'auteur a tranché (2026-09-29)

| Question | Réponse |
|---|---|
| Ce que compte la barre | **toute l'assiette, en chiffres de jeu** : gonflés pareil pour tous les usages (77d) |
| Les usages ouverts | **quatre** : céréales (départ), maraîchage, verger, prairie |
| Le frais non produit | **s'achète sur la caisse**, comme l'énergie achetée |
| L'unité de décision | le **champ** (88), pas la ferme |

## Ce qui tourne

Cliquer un champ, onglet Campagne : un bloc **Culture** à quatre boutons, un seul usage visé à la fois, fermé pendant l'urgence et sous un camp. On pose, le récapitulatif dit le prix, la durée, les nourris et **l'économie d'achats**, on met en place. Le champ passe en **terre labourée** pendant le chantier, puis prend sa culture : planches de légumes en patchwork, **vrais arbres fruitiers en rangs qui grandissent cinq ans**, prairie d'un vert uni.

| Culture | Nourrit / ha | Prix / ha | Chantier | Autre effet |
|---|---|---|---|---|
| Céréales | 12 | 10 k€ | 6 mois | — |
| Maraîchage | 120 | 60 k€ | 1 an | — |
| Verger | 70 | 25 k€ | 1 an, **première récolte à 5 ans** | retient un peu la pluie |
| Prairie | 0 | 5 k€ | 6 mois | **abaisse la crue partout**, 0,5 cm par hectare |

La ville **paie 5 € par mois et par personne qu'elle ne nourrit pas**. La dotation couvre déjà le mois 0 : la caisse ne voit que l'écart, positif quand un camp prend un champ, négatif quand on cultive mieux. Un hectare de maraîchage se rembourse en ~9 ans, comme un toit solaire.

🔴 **Tous ces nombres sont à juger** — haut du bloc nourriture de `ville.gd`, table `CULTURES`.

**Mesuré** (`essai_campagne`, champs 1065 · 1059 · 1066 · 1057) : au départ la campagne nourrit **814 personnes** ; le champ 1065 (2,65 ha) passe de 32 à **318 nourris** pour **159 k€**, soit **−1,4 k€/mois** d'achats ; la prairie 1066 abaisse la crue de **0,7 cm** ; les trois cultures font économiser **171 k€ en dix ans**. Barre du bilan : **815 → 1 209 personnes** au mois 61.

## À regarder

`Godot_console.exe --path Godot --script res://outils/essai_campagne.gd -- --captures`, puis dans `QGIS/rendus/`, au même cadrage :
`wehrau_cultures_0_avant.png` → `..._1_chantier.png` → `..._2_un_an.png` → `..._3_cinq_ans.png` au même cadrage, puis `..._4_de_pres.png`, et les fiches `wehrau_campagne_fiche_maraichage.png`, `..._verger.png`. L'essai sort **0 échec** (24 contrôles).

- ① **maraîchage** : un patchwork de bandes vertes, rouges et brunes, visible de loin
- ② **verger** : de l'herbe au mois 13, des rangs d'arbres fruitiers au mois 61
- ③ **prairie** : un vert clair uni
- ④ **céréales** : inchangé
- au mois 1, ① ② ③ sont en **terre brune labourée**

Serait un défaut : un champ qui change de couleur hors de son contour, une culture qu'on ne reconnaît pas sans son numéro, un verger qui nourrit avant cinq ans, un camp posé sur un champ qui garde son bloc Culture, une fiche qui propose une culture pendant l'urgence.

## Ce qui reste

- 🔴 les nombres de `CULTURES`, et **si la prairie doit peser sur la crue partout ou seulement près de l'Ilse** (le lieu compte, 77c)
- les **saisons** : la couleur des champs ne change pas encore avec l'année
- les bandes du maraîchage suivent l'axe est-ouest, pas le sens du champ ; les fleurs de la prairie ne se voient que tout près
- la miniature montre le champ **entier** depuis le 2026-09-29 (le plafond de 240 m des îlots le coupait) ; elle ne plante pas encore les arbres du verger, seulement son herbe
- une **vue Campagne** sur le rail (un calque par culture) n'existe pas
- la **biodiversité** (thème séparé, 91) : la prairie et le verger devraient y compter
- serre et pâture, le jour où l'on en ouvre plus que quatre
