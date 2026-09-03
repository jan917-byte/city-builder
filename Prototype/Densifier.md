# Densifier — un cran, un bâtiment

**Ce n'est pas une étape ouverte.** L'étape 5 (le trafic) l'est toujours. Ce chantier-ci est une décision de plus, demandée par l'auteur le 2026-09-03, posée sans toucher au trafic.

Elle a demandé de payer d'abord une dette : **`logements` était inventé** (04 : densité × hectares), donc ajouter un étage n'ajoutait aucun habitant. Il vient maintenant du **plancher mesuré**.

## Ce qui tourne

| Le geste | Ce que ça fait | Mesuré |
|---|---|---|
| **Deux boutons pour la hauteur**, +1 ou +2 étages | se choisit **une fois par îlot** et se verrouille au premier chantier : le shader n'a qu'une hauteur pour tout l'îlot | — |
| **Un curseur pour combien**, et un cran est **un bâtiment** | on densifie une tranche, on paie, on recommence plus tard au cran atteint | îlot 50 : **23 crans** |
| **Les bâtiments montent du plus bas au plus haut** | l'ordre est celui de `07`, et il ne change jamais | îlot 50 : 36 mois pour les 23 |
| **La ville gagne des logements** | `logements` monte en rampe, au rythme des bâtiments livrés | îlot 50 : **81 → 139** logements |
| **La facture suit** | la conso est proportionnelle aux logements : densifier fait remonter l'énergie | ville : **42 152 → 43 138** MWh/an |
| **Le loyer rentre, l'entretien sort** | 0,42 k€ encaissés, 0,17 k€ dépensés, par logement et par mois | 20 ans : **5 510 k€ payés, 3 218 k€ rentrés** |
| **Le patrimoine ne monte pas** | cœur ancien et front commerçant sont hors jeu (auteur) | **321 bâtiments** montables sur **23 îlots** |

Un étage partout ajouterait **371 logements** sur un parc de **2 150**, soit **+17 %**.

## 🪜 On commence par le meilleur, et le prix le dit

Demandé par l'auteur le 2026-09-03 : *« le coût doit être progressif — la première pose coûte moins cher et rapporte plus, car on pose d'abord sur les toits les plus rentables »*. Une seule règle, deux décisions, **un seul nombre de level design** — `PROGRESSIVITE`, en haut de `energie.gd`.

🔴 **Les totaux ne bougent pas, et c'est ce qui rend le changement sûr.** Faire l'îlot ENTIER, ou le toit ENTIER, coûte et rapporte exactement ce que ça coûtait et rapportait la veille. Seul l'**ordre** change — donc s'arrêter au milieu devient une décision, au lieu d'être un demi-geste.

| Le même objet, deux bouts | Le début | La fin | Le tout |
|---|---|---|---|
| **Panneaux, îlot 32** | 30 % pour **63 k€**, remboursés en **6 ans** | les 30 derniers % pour **112 k€**, en **18 ans** | 292 k€, 10 ans — *inchangé* |
| **Densifier, îlot 50, +2 étages** | 11 bâtiments : **2 080 k€**, **75 k€** le logement | les 12 derniers : **3 430 k€**, **113 k€** | 5 510 k€ — *inchangé* |

⚠️ **Ce n'est pas une remise, c'est un ordre.** Sur le toit, `07` et le shader remplissaient déjà le versant le mieux exposé en premier ; sur l'îlot, `07` range déjà les bâtiments du plus bas au plus haut. Le prix ne faisait que ne pas le dire.

⚠️ **La courbe est portée par une seconde rampe, pas par une formule relue à chaque image.** La surface couverte (`part_toit_equipe`) reste droite — c'est elle qu'on voit —, le rendement obtenu (`part_rendue`) est sa jumelle courbe. Sans ça, la recette encaissée n'était plus une intégrale exacte, et le solde changeait avec le nombre d'images par seconde.

🌿 **Le toit vert est resté plat**, volontairement : il ne rapporte rien, donc « les meilleurs d'abord » n'y veut rien dire.

## La bascule du plancher

`logements` sort désormais de l'emprise bâtie × niveaux ÷ **101 m² bruts** — le ratio auquel les deux moteurs se recoupaient déjà, mesuré le 2026-08-19. À l'échelle de la ville ça ne change presque rien (**2 705 → 2 645**, −2,2 %) : ça **redistribue** entre îlots, et c'est le but. Les trois plus gros écarts : îlot 15 **122 → 87**, îlot 72 **63 → 91**, îlot 45 **77 → 103**.

⚠️ **04 garde QUI loge, la mesure dit COMBIEN.** Un îlot que 04 ne loge pas — équipement, friche, faubourg entièrement ruiné — reste à zéro et **ne peut pas se densifier** : sans cette règle, la halle de l'îlot 31 gagnait 64 appartements et l'université 25.

## Comment ça monte, à l'écran

**Aucun triangle n'est ajouté, et aucun nœud non plus.** `07` range les bâtiments d'un îlot par nombre d'étages et pose sur chaque sommet **(rang du bâtiment, ce sommet suit-il le toit)** — canal `CUSTOM0`. Le shader lève les sommets marqués dès que le rang passe sous l'avancement : c'est **exactement la mécanique des toits verts**, appliquée aux sommets au lieu des couleurs. Le mur s'étire, donc la recette de fenêtres — qui compte les étages en hauteur réelle — en perce de nouvelles toute seule.

⚠️ **La collision ne monte pas.** Cliquer une façade surélevée vise quand même l'îlot, parce que le clic ne vise jamais autre chose. Le **trait de sélection**, lui, épouse le volume monté depuis le 2026-09-03 — il reste le cadrage de la miniature, calé sur la géométrie **d'origine**.
⚠️ **Un bâtiment reconstruit après la crue ne monte pas** : `07` ne range pas les ruines, et le maillage « réparé » ne porte pas le canal.

## Ce qui est ajouté se voit, et ne coûte rien de plus

Demandé par l'auteur le 2026-09-03 : *« qu'on puisse différencier la densification — fenêtre plus grande, murs et toits d'une autre couleur, bâti plus moderne »*. Un étage ajouté n'est pas de l'enduit de 1890, donc il ne s'en peint pas.

| Sur le neuf | Sur l'ancien, en dessous |
|---|---|
| **bardage bois clair**, lames verticales de 22 cm | enduit pastel de son époque |
| **toit zinc**, joints debout de 52 cm | tuile, rangs de 32 cm |
| **fenêtres deux fois plus larges**, allège basse, linteau haut | l'ouverture d'origine |
| une **couture d'ombre** à l'ancien égout | — |

La trame des **travées** ne change pas : les grandes fenêtres tombent à l'aplomb des petites, sinon l'immeuble se disloque au milieu.

**Toujours aucun triangle de plus.** `07` fait voyager un troisième nombre dans `CUSTOM0` — **l'égout d'origine**, en Y monde. Au-dessus, c'est neuf ; en dessous, c'est la ville. Un bâtiment qui n'est pas monté ne porte rien et ne bouge pas.

**Deux étages ajoutés font deux rangées de fenêtres, jamais trois** (auteur, 2026-09-03). Les étages ajoutés ont leur **propre trame**, accrochée à l'ancien égout : une rangée n'apparaît qu'une fois son étage livré, et aucune ne sort tranchée par le toit. La dernière rangée d'origine s'efface si elle traverse la couture — il reste un bandeau plein sous l'étage neuf.

⚠️ **Pourquoi une trame à part** : la recette de fenêtres de la ville compte les étages depuis le zéro monde, alors que les deux rives sont à **±1 m**. C'est un défaut plus ancien que la densification → la dette de `00 - Prototype.md`.

## Les nombres sont du level design

| La table | Où |
|---|---|
| le patrimoine qui ne monte pas (`DENSE_INTERDIT`) | haut de `07_exporter_godot.py` |
| le m² brut par logement (**101**) | haut de `04d_emprises_batiments.py` |
| prix, durée, loyer, entretien, plafond d'étages | haut de `ville.gd` |
| 🪜 la **progressivité** (0,4), un seul nombre pour les panneaux ET les étages | haut de `energie.gd` |
| bardage, zinc, lame, joint, cotes de la fenêtre neuve | recette de `materiaux.gd` |

Repère pour les juger : la dotation est de **30 k€/mois**, la caisse de **800 k€**, et la ville encaisse **8 000 k€** en vingt ans.

- **95 k€ le logement posé** : l'îlot médian gagne **14 logements par étage**, donc **1 330 k€** pour un étage — près de quatre ans de dotation, deux fois une berge renaturée.
- **18 mois par étage**, tous bâtiments confondus — donc **18 ÷ le nombre de bâtiments** par cran.
- 🪜 **0,4 de progressivité** : le premier logement posé coûte 0,6 fois le prix moyen, le dernier 1,4 fois. À **0**, le jeu d'avant le 2026-09-03 revient à l'identique.
- **0,42 − 0,17 = 0,25 k€ par logement et par mois** : 380 mois pour rembourser une pose, contre 240 de partie. 🔴 **C'est le contrôle nommé de la dette 59** — une densification pure ne doit pas s'autofinancer —, et il est imprimé par `--essai`.

## Quoi lancer, quoi regarder

```
python QGIS/scripts/chaine.py --godot
/Applications/Godot.app/Contents/MacOS/Godot --path Godot -- --essai
```

Trois captures au **même cadrage**, et c'est le critère :

1. `wehrau_essai_densifier_avant.png` — l'îlot 50 tel qu'il est.
2. `wehrau_essai_densifier_palier.png` — **la première tranche est livrée et la seconde n'est pas engagée : 11 bâtiments sur 23 sont montés, les 12 autres non, et ils le restent.** Si l'îlot monte d'un bloc, le rang de `07` ne passe pas jusqu'au shader.
3. `wehrau_essai_densifier_apres.png` — tout est monté, de **deux étages** et pas plus, **et le neuf se lit tout seul** : bois, zinc, grandes fenêtres, sur une base restée en enduit.

🪜 **Et deux lignes imprimées, qui sont le second critère** : la première tranche doit coûter moins cher par logement que la dernière (75 contre 113 k€), et les 30 premiers pour cent du toit 32 se rembourser plus vite que les 30 derniers (6 contre 18 ans).

Puis la fiche, par `-- --interface` : `wehrau_interface_densifier.png` — **le curseur est à 5 des 10 bâtiments de l'îlot 49, et la miniature montre un îlot à moitié monté, pas un îlot entier** — et les deux miniatures `wehrau_apercu_densifier_avant/apres.png`.

## Ce qui prouverait que c'est cassé

- Le curseur **n'a que deux crans** sur un îlot qui a vingt bâtiments : `dense_cumul` n'est pas dans l'export (une carte d'avant le 2026-09-03), ou `dense_n` est retombé à zéro.
- La **première tranche coûte aussi cher que la dernière** par logement : la progressivité n'est plus branchée — ou `PROGRESSIVITE` est à 0, ce qui est un réglage et non une panne.
- **L'îlot entier ne coûte plus 5 510 k€**, ou le toit entier plus 292 k€ : les deux courbes ne valent plus 1 en 1, et tout le level design mesuré est périmé d'un coup.
- La **recette solaire change avec le nombre d'images par seconde** : la production est relue sur `part_toit_equipe` au lieu de `part_rendue`, et l'intégrale n'est plus exacte.
- Les bâtiments montent **tous en même temps** : le rang est perdu, il ne reste qu'un interrupteur.
- Ils montent de **plus de deux étages** : la valeur passée au shader a été convertie — c'est arrivé, en `Color` au lieu de `Vector4`, et la ville poussait en tours de cinquante mètres.
- Le **toit reste en bas** pendant que le mur monte : le seuil de `07` a raté les sommets de toiture.
- `logements` bouge **à l'engagement** et non au fil du chantier : la rampe a été remplacée par une addition.
- La **conso de la ville ne bouge pas** : `logements` ne descend plus dans `energie.gd`, et densifier est redevenu gratuit.
- Une **halle ou l'université** propose de se densifier : la règle « seuls les îlots logés » est tombée.
- Le **bois descend jusqu'au sol** d'un bâtiment qui n'a pas monté, ou toute la ville se barde : l'égout d'origine n'arrive plus jusqu'au shader (un export d'avant le 2026-09-03 le laisse à zéro, ce qui veut dire « rien à peindre »).
- Une **troisième rangée de fenêtres**, ou une rangée coupée par le toit : la trame propre aux étages ajoutés est retombée sur celle du monde.
- Le **trait de sélection reste sur l'ancien volume** : le masque de sélection ne reçoit plus la montée (les deux matériaux la partagent, ils ne doivent pas divorcer).
- Le **mur est bardé mais le toit reste en tuile** : le seuil du toit et celui du mur ne lisent plus la même hauteur.

## Ce qui reste à trancher

- **Le prix.** 95 k€ le logement met un îlot moyen au niveau de trois berges. C'est un choix de programme ; c'est peut-être un choix qu'on ne fera jamais.
- **Où sont les gens ?** Densifier ajoute des logements, pas des habitants : rien ne dit encore que la ville a besoin de ces logements, ni ce qui se passe si on n'en construit aucun.
- 🪜 **La force de la progressivité.** À 0,4 le premier logement coûte 0,6 fois le prix moyen et le dernier 1,4 fois : assez pour qu'on s'arrête au milieu, pas assez pour qu'on n'aille jamais au bout. C'est un cran de difficulté, et il se juge en jouant.
- **L'ombre portée.** Un îlot de deux étages plus haut ombre ses voisins ; le solaire ne le sait pas.
