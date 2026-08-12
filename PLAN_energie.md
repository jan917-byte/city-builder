# Le prototype énergie — la colonne vertébrale du jeu

> 🎯 **Ce n'est plus une session d'essai.** Tranché par l'auteur le 2026-08-12 : le prototype énergie **devient le prototype principal**, tout le reste s'y branche ensuite, et la 3D et l'UI avancent en parallèle, tirées par lui. → `Décisions arrêtées` **64 · 64b · 64c** · `Plan 3 mois`
>
> Écrit depuis le Mac, **à exécuter sous Windows**. Plan de travail, pas source de vérité — le vault reste la source, et rien ici n'entre dans `Décisions arrêtées` tant que l'auteur n'a pas vu tourner le résultat.
> Cadre : `CLAUDE.md` §3 (Claude écrit le code Godot) et §3 bis (l'auteur juge à l'écran, pas sur le code).

## 0. Ce que ce document est devenu

Il a été écrit comme un test d'une session. Il est maintenant **le gabarit** de tous les thèmes qui suivront.

| | |
|---|---|
| **Ce qui reste vrai** | tout ce qui suit — les coefficients, les deux décisions, les contrôles à l'écran |
| **Ce qui change** | le §2 « périmètre » n'est plus une amputation temporaire, c'est **l'ordre de construction**. Les six autres indicateurs ne sont pas éteints, ils **ne sont pas encore arrivés** |
| **Ce que ça ajoute** | trois pièces réutilisables, listées ci-dessous |

**Les trois pièces d'un thème** — c'est ça, « scalable », et c'est vérifiable :

| | |
|---|---|
| une **table de coefficients** par `sous_type` | même forme que `TISSU`, treize lignes |
| **une ou deux décisions de nature opposée** | l'une qui rapporte, l'autre qui coûte — sinon il n'y a pas d'arbitrage, seulement un tri |
| **un calque par indicateur** | règle 53, sans exception |

Rien dans la machinerie (rampe, chantier, coût étalé, capital comptant, calque, fiche, vue chantiers) **ne parle d'énergie**. C'est ce qui rend le gabarit vrai plutôt qu'espéré.

### 🔗 Où ce prototype et la piste 3D se rejoignent : le toit

Le §4 estime la surface de toit par un **coefficient** par `sous_type`. Le générateur de parcelles puis de toits la produira **pour de vrai**. Donc :

- la **3D alimente** ce prototype — le toit cesse d'être estimé ;
- ce prototype **donne au générateur son critère de réussite** — le potentiel solaire calculé sur les vrais toits remplace le coefficient **sans que le jeu change de forme**.

**L'interface se pose maintenant**, pas après (décision 41) : un objet bâti expose *surface de toit · pente · orientation · ombrage*. Aujourd'hui une table les fabrique, demain le générateur, et **le code d'énergie ne doit pas savoir lequel des deux parle.**

🔴 **Le sens de la dépendance ne se renverse jamais : l'énergie n'attend jamais la 3D.** Ce prototype reste jouable avec les toits estimés quoi qu'il arrive au générateur. C'est ça, et rien d'autre, qui protège le calendrier. → **64b**

---

## 1. Ce qu'on teste

Une seule question, et ce n'est pas celle de l'argent : **est-ce que choisir _où_ investir, et _quand_, fait un jeu ?**

L'énergie n'est que le prétexte le plus court pour la poser. Un thème, quatre nombres, **deux décisions de nature opposée**, tout le reste éteint. Si le choix du lieu est ennuyeux avec l'énergie seule, il le sera avec sept indicateurs — on l'aura su en une session au lieu de trois mois.

**Pourquoi deux décisions et pas une** : une seule ne teste rien. Poser des panneaux, c'est rentable partout, donc la réponse est toujours oui et le seul choix est l'ordre. Il faut une deuxième décision qui **coûte au lieu de rapporter** — l'isolation (§5 bis) — pour que « où investir » soit un arbitrage et pas un tri.

> **La thèse de l'auteur, posée le 2026-08-12 :** *pour être efficient, il faut investir au bon endroit au bon moment — c'est la base du métier.* La décision spatiale n'est pas une conséquence du système, elle **est** le jeu.

**Le moment qu'on cherche à produire**, et qui sort tout seul des données de Wehrau :

> Les panneaux sont rentables en 7 ans sur **la barre de 1974** et en 6 ans sur **la dalle commerciale** — les deux objets les plus laids et les plus contestés de la ville. Ils ne sont **jamais** rentables dans le cœur ancien (24 ans, au-delà de la partie).
> La question cesse d'être *« est-ce que je pose des panneaux ? »* — évidemment oui — et devient **« où, et est-ce que j'assume ? »**

Si ce moment n'apparaît pas à l'écran en fin de session, la session a échoué, même si tout le code marche.

### 🔴 Et le piège qui vient avec, immédiatement

**Montrer la rentabilité, c'est risquer de résoudre le jeu.** Si la carte affiche 6 ans ici et 24 ans là, la stratégie optimale est **triable au tour 1** : du plus vert au plus rouge, dans l'ordre, jusqu'à épuisement. Le joueur n'arbitre plus, il exécute un tri. C'est le piège *Democracy 4* déjà nommé dans `Pièges connus` : le pourcentage affiché change un arbitrage en optimisation.

Il faut donc que la carte de la rentabilité **ne suffise pas à répondre**. Deux choses s'en chargent, et c'est le §6 bis qui les porte. Sans elles, cette session livre un tableur colorié.

---

## 2. Le périmètre — ce qui est allumé, ce qui est éteint

| | État | Comment |
|---|---|---|
| **Consommation · Production locale · Achat · CO2** | 🟢 allumés | les quatre seuls nombres du bandeau |
| Canopée, surchauffe, imperméabilisé, stationnement | ⚫ éteints | **masqués, pas supprimés** — une constante en haut de `interface.gd` liste les indicateurs affichés |
| **D07 planter l'alignement** | ⚫ éteinte | reste entière dans `chantiers.gd`, retirée de l'UI par une liste `DECISIONS_ACTIVES` |
| **Le capital politique** | 🟢 allumé | ce n'est pas un indicateur d'énergie, mais sans lui la rentabilité gouverne seule et le choix du lieu n'existe pas → §6 bis a |
| Les calques thématiques existants | ⚫ éteints | remplacés par les deux calques de l'énergie (§7, étape 5) |
| Le classeur (`08_jouer.py`) | ⚫ pas touché | voir §9 — exception assumée au recoupement |
| Le `.gpkg` | 🔒 **pas d'écriture** | seul `07` est relancé, et il ne fait que lire |

⚠️ **Rien n'est supprimé, et depuis la décision 64 ce n'est même plus une réduction : c'est l'ordre de construction.** Les six autres indicateurs ne sont pas éteints, **ils ne sont pas encore arrivés** — chacun reviendra par les trois pièces du §0, un à la fois. Tout se rallume en remettant une entrée dans deux listes.

---

## 3. Les quatre nombres, et leur t0

Affichés **en écart au départ**, comme les sept — règle de `Indicateurs globaux`.

| | Le nombre | t0 ville | t0 sur chaque îlot | Sa famille |
|---|---|---|---|---|
| ⚡ | **Consommation** | ~51 GWh/an → indice **100** | **100 %** de sa propre conso | stock |
| ☀️ | **Production locale** | **0 %** | **0 %** | taux |
| 💶 | **Achat d'énergie** | **100 %** | **100 %** | taux |
| 🏭 | **CO2** | ~12,8 kt/an | sa part | stock |

**Achat = Consommation − Production.** Ce n'est pas un troisième chiffre indépendant, c'est le complément du deuxième — on l'affiche quand même parce que c'est celui-là que le joueur paie, et que « 100 % acheté » est une phrase qui pique.

🔴 **Le piège du bornage** : la production locale d'un îlot **peut dépasser 100 %**. La friche industrielle et la dalle commerciale ont un grand toit et zéro logement — elles exportent. Si on ajoute `production` à la liste des champs bornés à 0..1 dans `ville.gd`, ces îlots-là seront écrêtés en silence et le total de ville sera faux. **Ne pas borner.**

---

## 4. Les chiffres de départ, et d'où ils sortent

Aucun n'est inventé pour l'occasion : chacun se dérive d'un attribut existant. *Une formule sur des attributs existants n'est pas une sous-simulation* → `Décisions arrêtées` 56.

### La consommation

Chauffage **compris** — c'est le poste majoritaire, et l'exclure rendrait le solaire trop facile.

⚠️ **Elle n'est pas uniforme, et c'est indispensable depuis que l'isolation existe** (§5 bis). Un logement de 1974 et une maison mitoyenne du cœur ancien ne consomment pas la même chose : l'un a du béton sans isolant et des ponts thermiques partout, l'autre des murs épais et **trois façades sur quatre contre le voisin**. Sans cet écart, l'isolation n'aurait aucune raison de se faire ici plutôt que là.

| `sous_type` | MWh/an par logement | Pourquoi |
|---|---|---|
| `barre_1970` | **24** | béton d'avant le choc pétrolier, ponts thermiques, aucun isolant |
| `pavillonnaire` | **22** | détaché : le pire rapport surface/volume de la ville |
| `coeur_ancien` | **21** | murs pleins et fenêtres médiocres, mais compact et mitoyen |
| `front_commercant` | **18** | mitoyen, vitrines en rez-de-chaussée |
| `maisons_de_ville` | **17** | le mitoyen fait le gros du travail |
| Tertiaire (`equipement`, `dalle_commerciale`, `friche_industrielle`) | **9 par emploi** | 878 emplois → 7,9 GWh |

- **Total attendu ≈ 51 GWh/an**, soit ~9,6 MWh par habitant.
- **Contrôle** : si le total sort hors de la fourchette 45–58 GWh, c'est la répartition des logements par tissu qui commande, pas les coefficients. On imprime le tableau et on ajuste une ligne, pas six.

### Le toit disponible

La couche `emprises` donne 76,5 ha d'**emprise** — mais une emprise n'est pas un toit : elle contient les cours, les jardins et les parkings. Il faut deux coefficients, et ils sont du **design**, pas de la mesure. Même forme que la table `TISSU` de `04_deriver_attributs.py`, treize lignes, à poser au même endroit dans le code pour que l'auteur les retrouve.

| `sous_type` | Part réellement bâtie | Part du toit équipable | Coût × | Rendement × | **Rentabilité** |
|---|---|---|---|---|---|
| `dalle_commerciale` | 0,60 | 0,75 | 0,7 | 1,10 | **6 ans** |
| `barre_1970` | 0,20 | 0,70 | 0,8 | 1,10 | **7 ans** |
| `friche_industrielle` | 0,45 | 0,65 | 0,8 | 1,00 | 8 ans |
| `equipement` | 0,40 | 0,55 | 0,9 | 1,05 | 9 ans |
| `pavillonnaire` | 0,20 | 0,40 | 1,2 | 1,00 | 12 ans |
| `maisons_de_ville` | 0,55 | 0,30 | 1,3 | 0,95 | 14 ans |
| `front_commercant` | 0,80 | 0,25 | 1,4 | 0,90 | 16 ans |
| `coeur_ancien` | 0,70 | 0,15 | 1,8 | 0,75 | **24 ans** |
| `place_minerale` · `parc` · `jardins_familiaux` · `champ` · `riviere` | 0 | — | — | — | pas de toit, décision indisponible |

Ce que disent les deux dernières colonnes : un petit toit pentu, mitoyen, avec des cheminées et une contrainte patrimoniale **coûte plus cher au m² et produit moins**. Un hangar plat coûte moins et produit plus. C'est ce double écart, et lui seul, qui fait passer la rentabilité de 6 à 24 ans.

**Ombrage en prime** : le rendement se multiplie encore par `1 − 0,4 × canopee` de l'îlot. Gratuit, réel, et ça réintroduit l'antagonisme arbre/panneau que le vault a déjà nommé — sans avoir besoin de rallumer la canopée.

### La production et le CO2

| | Valeur | Note |
|---|---|---|
| Rendement de référence | **140 kWh/m²/an** | Allemagne du sud-ouest, pertes et ombrage moyen compris |
| Potentiel total attendu | **25 à 40 %** de la consommation | à imprimer à l'étape 1 — si on sort de cette fourchette, on tourne le rendement, pas la table |
| Facteur d'émission de l'énergie achetée | **0,25 kg CO2/kWh** | mix + chauffage |
| Carbone gris d'un panneau | **120 kg CO2/m²**, en une fois au chantier | → `Décisions arrêtées`, le carbone gris |

🎯 **Le potentiel plafonne autour de 30 %.** Wehrau **ne devient pas autonome par ses toits**, et c'est le bon résultat : le jalon « autonome en énergie » reste hors de portée, ce qui laisse une raison d'exister aux décisions d'isolation et de réseau de chaleur qui viendront.

> 🔄 **Mesuré le 2026-08-12 (session 18), sur les vrais toits : le potentiel équipable est ~9,5 %, pas 25–40 %.** La fourchette ci-dessus avait été calibrée sur les 76,5 ha d'*emprise* ; les toits réels exportés par `07` font **11,7 ha**, et même équiper 100 % de chaque m² plafonnerait vers 28 %. La leçon du plafond sort **renforcée**, les blocages croisés tiennent (vérifié en aveugle par `essai_energie.gd`), mais les ordres de grandeur du §5 changent d'échelle : ville équipée **~350 pts** (pas ~1 000), retour plein **~27 pts/an** (pas ~90). Monter le rendement à ~480 kWh/m²/an pour retrouver 30 % serait non physique — **l'arbitrage est à l'auteur** : assumer ~9,5 %, ou regonfler la colonne `equip` de la table. → `ETAT.md`

---

## 5. La décision — « Poser des panneaux »

Elle se branche sur la machinerie qui existe déjà (rampe, seuil, coût étalé, capital comptant). Rien de neuf à inventer côté mécanique.

| | |
|---|---|
| **Couche** | l'îlot (aujourd'hui `chantiers.gd` ne sait viser que la rue — c'est le seul vrai changement de plomberie) |
| **Cible** | les îlots dont le **toit équipable dépasse X m²** — le curseur de seuil existant est réutilisé tel quel, 0 à 5 000 m², défaut 500 |
| **Ce qui bouge** | un champ neuf sur l'îlot, `part_toit_equipe`, qui monte de 0 à 1 par la rampe habituelle |
| **Délai** | 6 mois d'études et de marché |
| **Montée** | 6 mois de pose |
| **Coût** | **1 point par 120 m² de panneau**, multiplié par le coût relatif du tissu |
| **Retour** | **6 points par an et par GWh produit**, à partir de la fin des travaux |
| **Capital politique** | −1 point ; **−3** dans le `coeur_ancien` et le `front_commercant` (patrimoine) |

**Les deux molettes de la rentabilité sont là, et il n'y en a que deux** : les 120 m² par point et les 6 points par GWh. Leur rapport *est* la rentabilité de 10 ans. On en change une, tout bouge — et c'est ce qu'on veut voir.

Ordres de grandeur qui tombent de ces réglages :

| | |
|---|---|
| Îlot médian | ~1 800 m² de panneaux → **15 points**, 4 mois de budget |
| Ville entière équipée | **~1 000 points** — la moitié du budget de vingt ans |
| Retour à pleine puissance | **~90 points/an**, contre 100 de budget annuel |

---

## 5 bis. La deuxième décision — « Isoler les bâtiments »

> Demandée par l'auteur le 2026-08-12 : *coût élevé, mais réduction de la consommation.*

### 🎯 Ce qu'elle change au jeu entier, en une ligne

Les toits plafonnent à **~30 %** de la consommation : le §4 en concluait que le jalon « autonome en énergie » est hors de portée. L'isolation ne produit **rien** — le toit fait la taille qu'il fait — mais elle fait tomber le dénominateur. À −40 % de consommation, **les mêmes panneaux couvrent 51 %**.

> **On ne va pas vers l'autonomie en produisant plus. On y va en consommant moins.**
> Le kilowattheure le moins cher est celui qu'on ne consomme pas.

C'est la leçon centrale du métier, et elle sort de l'arithmétique — personne n'a besoin de l'écrire dans un texte de jeu.

### Les deux décisions ont des natures opposées, pas seulement des coûts différents

| | ☀️ **Panneaux** | 🧱 **Isolation** |
|---|---|---|
| Rentable ? | **oui**, 6 à 24 ans | **non — jamais**, dans aucun tissu |
| Ce que ça touche | un toit, personne dessous | **les gens qui habitent là** : la facture, le froid |
| Capital politique | **il en coûte** (esthétique, patrimoine) | **il en rapporte** |
| Ce que ça produit | de l'**argent** | de la **légitimité** |
| Ce que ça déplace | la production | la **consommation** |
| Durée | 12 mois | **27 mois** |

> **Les panneaux achètent de l'argent, l'isolation achète de la légitimité.**
> L'argent sans légitimité bute sur le capital politique. La légitimité sans argent ne finance rien. **Jouer une seule des deux cartes ne marche pas** — c'est la contrainte qui remplace une règle qu'on aurait dû écrire.

⚠️ **Que l'isolation ne soit jamais rentable est un fait, pas un réglage à corriger.** En vrai non plus elle ne l'est pas : on la fait pour le confort, la précarité énergétique, le carbone, et pour ne plus dépendre du prix. Un jeu qui la rendrait rentable mentirait sur le métier.

### La table — mêmes treize lignes, deux colonnes de plus

| `sous_type` | Gain d'isolation | Coût × | Ce qui commande |
|---|---|---|---|
| `barre_1970` | **−45 %** | 0,7 | façades planes, un seul propriétaire, tout par l'extérieur |
| `pavillonnaire` | −40 % | 1,5 | gros gain, mais 20 logements/ha : **on ne rénove pas un lotissement par décret** |
| `maisons_de_ville` | −35 % | 1,0 | mitoyen, façades simples |
| `front_commercant` | −25 % | 1,3 | vitrines, activité en pied d'immeuble |
| `coeur_ancien` | **−20 %** | **1,6** | **patrimoine : rien par l'extérieur.** Isolation par l'intérieur seulement — plus cher, moins efficace, et on perd des mètres carrés |
| Tertiaire, `place_minerale`, `parc`, `champ`… | — | — | pas de logements, décision indisponible |

**Les deux cartes de rentabilité sont presque inverses.** Le solaire va vers les grands toits plats sans habitants — dalle, friche. L'isolation va vers les enveloppes catastrophiques et pleines de gens. Un seul objet où les deux convergent : **la barre de 1974**, grand toit plat *et* béton de 1974. Elle devient l'objet central du jeu — et c'est aussi le plus chargé socialement.

### Les réglages

| | |
|---|---|
| **Couche** | l'îlot |
| **Cible** | les îlots de plus de X **logements** — le curseur de seuil réutilisé, 0 à 200, défaut 20 |
| **Ce qui bouge** | un champ neuf, `part_isolee`, de 0 à 1 par la rampe habituelle |
| **Délai** | **9 mois** — études, marché, **et concertation : des gens habitent là** |
| **Travaux** | **18 mois** (§6 ter) |
| **Maturation** | aucune : un mur isolé l'est le jour où l'échafaudage part |
| **Coût** | **1 point par logement rénové**, × le coût relatif du tissu |
| **Retour** | **aucun en argent** |
| **Capital politique** | **+3 par chantier, +1 par tranche de 30 logements** |
| **Carbone gris** | présent mais **modeste** — remboursé en 2 ans environ, contre 3 à 4 pour un panneau |

**Ce que ces réglages produisent, et qui est voulu :**

| | |
|---|---|
| Îlot médian (~40 logements) | **~36 points**, contre 15 pour le solaire sur le même îlot |
| Ville entière isolée | **~2 550 points** — **plus que le budget de vingt ans** |
| Donc | 🔴 **isoler toute la ville est impossible par construction.** On ne choisit pas quand s'arrêter, on choisit **où** |
| Capital | un chantier d'isolation finance en capital **deux à trois** chantiers solaires |

### 🔴 Le piège d'affichage à ne pas rater

**Isoler fait monter « production locale % » sans produire un seul kilowattheure de plus.** C'est arithmétiquement juste et c'est même la leçon — mais à l'écran, ça peut passer pour une triche.

**La fiche doit pouvoir dire lequel des deux a bougé** : *« +6 points de couverture, dont 2 produits et 4 économisés »*. Sinon le joueur apprendra la bonne stratégie sans jamais comprendre pourquoi elle marche, ce qui est exactement l'échec visé par la règle 60b — *formule cachée ≠ causalité cachée*.

### ☐ Une question qu'on ouvre et qu'on ne traite pas

Si les panneaux appartiennent à une **régie** (§6), alors **la régie perd des recettes quand les gens isolent**. Le conflit d'intérêt est réel, il est même classique — et il est trop beau pour être improvisé dans une session de test. **Noté, pas construit.**

---

## 6. Ce que la rentabilité ouvre, et ce qui la freine

**La boucle de renforcement est réelle et volontaire** : l'argent gagné rachète des panneaux, qui rapportent, etc. C'est exactement le piège de l'exponentielle contre lequel `Décisions arrêtées` 59 met en garde. On le laisse tourner, pour trois raisons, dans cet ordre :

1. **Le frein est géométrique, pas réglementaire.** Il y a 76,5 ha de toits et pas un de plus. La boucle sature toute seule vers 30 % — aucune règle n'a besoin de l'interdire. *La rareté est dans le calendrier, pas dans les règles.*
2. **Le capital politique règle le rythme.** 63 îlots à −1 (et −3 en centre ancien) contre 50 de capital au départ : on ne peut pas tout équiper vite, même avec l'argent.
3. **La rentabilité varie de 6 à 24 ans.** Les îlots rentables partent les premiers ; ce qui reste ensuite ne se paie plus. La boucle ralentit d'elle-même.

⚠️ **Ce qu'il faut regarder en face pendant le test** : sur un horizon de 20 ans, un chantier décidé après le mois 120 ne se rembourse jamais. **La décision a une date de péremption**, et ça devrait se lire sur la fiche.

🔴 **Un point que je signale avant qu'on code** : la ville ne paie pas la facture d'énergie de ses habitants. Pour que le retour au budget soit défendable, il faut que les panneaux appartiennent à quelqu'un de public — une **régie municipale** (des *Stadtwerke*, ce qui colle à Wehrau). Ça ne demande aucun code, mais ça demande une phrase dans le vault, sinon le mécanisme est un raccourci comptable qu'on ne saura plus justifier dans six mois. **À trancher par l'auteur, pas par moi.**

---

## 6 bis. La dimension spatiale — le cœur de la session

C'est ici que se joue le §1. Trois pièces, dans l'ordre d'importance.

### a. Deux cartes qui pointent en sens inverse

| La carte | Elle envoie où | Parce que |
|---|---|---|
| 💶 **La rentabilité** | vers les hangars, la dalle, la friche, la barre | grands toits plats, accès facile, pas d'enjeu patrimonial |
| 👁️ **La visibilité** | vers le cœur ancien et le front commerçant | c'est là qu'on passe, c'est là que ça se remarque |

**Le capital politique se regagne parce que ça s'est vu.** Un chantier rend du capital en proportion de la fréquentation de l'îlot — pas de sa production. Donc :

> **Investir efficacement épuise le capital politique. Investir visiblement épuise le budget.**

Aucune des deux cartes ne donne la réponse seule, et c'est la seule raison pour laquelle le choix du lieu est un choix. Sans ce contrepoids, la rentabilité est un tri.

Ce que ça règle en prime : `Indicateurs globaux` laisse ouvert *« comment le capital politique se regagne n'a aucune forme à l'écran — un nombre nu ne dit pas ça revient parce que ça s'est vu »*. **La réponse est spatiale**, et elle se lit sur la carte.

⚠️ **Ajout au périmètre du §2.** Le capital politique est une ressource, pas un indicateur d'énergie — mais sans lui la session ne teste rien. Proxy de visibilité à partir des attributs existants, sans rien créer : la `charge` du tronçon riverain et la `densite` de l'îlot. On passe devant, ou on y habite. **Si l'auteur refuse cet ajout, le repli est de le dire explicitement dans le compte rendu : le test aura mesuré un tri, pas une décision.**

### b. Le temps déplace la carte

| Levier | Valeur | Effet |
|---|---|---|
| Coût du panneau | **−6 % par an** | ce qui est trop cher aujourd'hui ne l'est plus dans dix ans |
| Prix de l'énergie achetée | **+2 % par an** | ne rien faire coûte de plus en plus cher |

L'arithmétique donne un résultat qu'on n'a pas eu à forcer : **attendre n'est gagnant que sur les îlots dont la rentabilité dépasse ~17 ans** (le seuil est `1 ÷ 6 %`). Les bons toits disent *maintenant*, les mauvais disent *pas encore*, et le seuil balaie la carte au fil des années.

- **« Pas encore » devient une réponse valide** — mais seulement là où c'est vrai, ce qui empêche l'attente d'être une stratégie générale.
- **Ça se voit à l'écran sans un seul chiffre** : la zone rouge rétrécit d'année en année. C'est le « bon moment » rendu visuel.
- Équiper toute la ville la première année coûte **près du double** de l'étaler. Ne rien équiper ne produit rien. L'optimum est entre les deux, et il n'est pas calculable de tête.

### c. Montrer *un peu*, pas tout

L'auteur a écrit *« montrer **un peu** la rentabilité »*. On tient le *un peu* :

| Où | Ce qu'on montre | Pourquoi |
|---|---|---|
| **Sur la carte** | **quatre classes, aucun nombre** — se rembourse vite · dans la partie · tout juste · jamais | assez pour décider, pas assez pour trier finement |
| **Sur la fiche d'un îlot** | l'année précise du remboursement, une ligne | la précision se paie d'un clic et d'une attention |
| **Nulle part** | un classement des 63 îlots | ce serait la liste de courses que le vault refuse partout |

Cohérent avec la règle 53 — *le chiffre dit que ça bouge, le calque dit où* — et avec la décision 60 : **un état non chiffré ne s'optimise pas.**

### c bis. Un troisième axe est arrivé avec l'isolation : **le bon ordre**

Le §1 disait *au bon endroit au bon moment*. Avec deux décisions de nature opposée, il faut ajouter **dans quel ordre**.

| Ce qui pousse à | Pourquoi |
|---|---|
| **Le solaire d'abord** | c'est la seule des deux qui rapporte de l'argent — elle finance la suite |
| **Alterner** | le solaire **coûte** du capital politique, l'isolation en **rend**. Un joueur qui n'installe que des panneaux **se bloque sur le capital** avant d'avoir dépensé son budget |
| **L'isolation d'abord, par endroits** | elle fait tomber la consommation, donc les panneaux posés ensuite couvrent une part plus grande — l'indicateur monte deux fois |

**Aucun des trois n'est faux, et c'est le but.** Le solaire seul stalle sur le capital ; l'isolation seule vide le budget sans rien produire ; il n'y a pas d'ordre optimal, il y a un rythme à tenir. C'est la même leçon que « la rareté est dans le calendrier ».

⚠️ **Contrôle à faire à l'écran** : une partie « panneaux uniquement » doit **se bloquer sur le capital politique**, et une partie « isolation uniquement » doit **se bloquer sur le budget**. Si les deux vont jusqu'au bout sans buter, la paire ne tient pas et les deux décisions sont indépendantes — donc décoratives l'une pour l'autre.

### d. Le joueur pense en quartiers, et la carte les montrera toute seule

La rentabilité dérive du `sous_type`, et les tissus de Wehrau sont **contigus** : le cœur ancien est un bloc, le pavillonnaire une couronne, les deux friches un secteur. Le calque sortira donc des **zones, pas des confettis** — sans qu'on code le moindre découpage. C'est ce qui permet la phrase *« c'est là qu'il faut commencer »* au lieu de *« l'îlot 43 »*.

☐ **Ce qui manque pour la dire à voix haute : un nom.** Wehrau n'a pas de quartiers nommés. *« Investir dans le Ried avant la rive gauche »* n'existe pas encore comme phrase. **Question de vault, pas de code — non tranchée, pas dans cette session** → `Ville/Wehrau.md`.

---

## 6 ter. La vue chantiers — le troisième temps

> Proposée par l'auteur le 2026-08-12 : *quand on commence un chantier, le jeu propose une vue chantiers ; on voit sur quel îlot ou quelle rue il y en a un, et en cliquant, le chantier apparaît sous forme d'une barre d'état.*

### Pourquoi ce n'est pas de la décoration

`Indicateurs globaux` laisse ouvert : *« le temps et les chantiers en cours n'ont pas de place dans le bandeau, alors que c'est l'anti-spectateur »*. La réponse est qu'**ils n'ont pas leur place dans le bandeau du tout**.

| La forme | Ce qu'elle dit | Son temps |
|---|---|---|
| Le **bandeau** (indicateurs) | ce que tu as fait | le **passé** |
| Les **ressources** (compteurs) | ce que tu peux faire | le **futur** |
| 🆕 **La vue chantiers** (la carte) | ce qui est **en train** de se faire | le **présent** |

Trois temps, trois formes. C'est ce qui justifie une troisième au lieu de tasser les chantiers dans une des deux autres.

Et ça ferme une boucle du §6 bis : décider *au bon endroit au bon moment* suppose de voir **ce qu'on a déjà engagé**. Sans cette vue, le joueur ne voit pas son propre pipeline. Ce n'est pas l'habillage de la décision, **c'est sa moitié manquante**.

Bonus structurel : `Décisions arrêtées` 58 donne trois nombres au budget — ce que tu as, **ce qui est engagé**, ce qui est libre. Le deuxième n'avait pas de carte. **La vue chantiers est le calque de « ce qui est engagé »** — règle 53 satisfaite sans effort.

### 🔴 Le point dur : une barre continue mentirait

La mécanique a **deux phases qui ne se ressemblent pas** — le délai (études, marché : il ne se passe rien) puis la montée (l'effet arrive). Une barre 0→100 % d'un seul tenant dirait que l'effet monte pendant le délai.

Or *« on décide, et il ne se passe rien pendant six mois »* est une des vérités que ce jeu a à enseigner. **La barre a deux segments visiblement différents**, et leur proportion se lit d'un coup d'œil.

### Un nombre qui manque à chaque décision : la durée des travaux

Le code confond aujourd'hui « montée de l'effet » et « chantier ». Faux dans un cas sur deux :

| Décision | Délai | **Travaux** | Maturation | Sur la carte |
|---|---|---|---|---|
| ☀️ **Panneaux** | 6 mois | **6 mois** | — | chantier pendant 12 mois, puis fini |
| 🌳 **D07 alignement** | 3 mois | **2 mois** | 58 mois | chantier 5 mois, puis un arbre qui pousse |

Sans ce nombre, 64 tronçons resteraient « en travaux » pendant cinq ans : faux, et illisible. **Un chantier fini n'est plus un chantier, même si son effet monte encore.**

### Ce que la barre d'état dit, et ce qu'elle ne dit pas

| ✅ Elle dit | ❌ Elle ne dit pas |
|---|---|
| dans quelle phase on est, et la part écoulée | un pourcentage global d'avancement en un seul nombre |
| **la date de livraison** — un mois, pas un % | une estimation qui glisse |
| ce que ça produira une fois fini | un rappel de la rentabilité (elle a déjà son calque) |
| ce qu'il reste à payer — le lien vers « ce qui est engagé » | |

### 🔴 Le garde-fou : jamais une liste

Une vue chantiers qui devient un **panneau listant tous les chantiers avec leurs barres** est un écran de gestion de projet — *Cities: Skylines*, contre le but affiché *« inspirer, pas simuler la bureaucratie »*.

La formulation de l'auteur protège déjà contre ça et il faut la tenir littéralement : **c'est un calque sur la carte, et la barre n'apparaît qu'en cliquant un objet.** Aucun inventaire, aucun tri, aucune vue d'ensemble textuelle. Si on veut savoir où sont ses chantiers, **on regarde la ville**.

### Deux effets secondaires gagnés au passage

- 🚧 **La règle « un objet déjà engagé n'est pas re-ciblable » devient visible.** Elle existe dans le code (`chantiers.gd` tient la liste des engagés) mais se manifeste aujourd'hui par un refus muet. Elle devient un état qu'on voit.
- 🏗️ **Le chantier peut se voir dans la 3D, pas seulement dans un calque.** Une teinte ou des hachures de chantier sur l'objet — **une recette, pas un asset**, conformément à la règle de production 52 : *si je devais en faire 200, est-ce que je tiendrais ?* Un seul traitement de matériau réutilisé par les 237 objets. Pas d'échafaudages modélisés.

### Quand la vue s'ouvre

L'auteur écrit « le jeu **propose** » — donc pas d'imposition. Recommandation :

- **Bascule automatique une seule fois**, au tout premier chantier de la partie : c'est l'apprentissage, et il ne se répète pas.
- **Ensuite, un compteur discret sur le bouton du calque** (« 3 »). Il suffit à rappeler que quelque chose tourne, sans jamais prendre la main.

☐ **À trancher devant l'écran, pas ici.**

---

## 7. Le travail, étape par étape

Chaque étape se termine par **quelque chose qui se regarde**. Pas de « c'est fait ».

### Étape 1 — sortir la surface de toit (QGIS, lecture seule)

`07_exporter_godot.py` connaît déjà la couche `emprises` mais n'exporte pas son aire. Il doit la joindre à chaque îlot, et **imprimer un tableau** : par `sous_type`, l'emprise, le toit équipable, la production potentielle, et le total en % de la consommation.

- ✅ **Ce qui prouve que c'est fait** : le tableau imprimé, et le total entre 25 et 40 %.
- 🔒 `07` **n'écrit pas** dans le `.gpkg`. Aucune relance de la chaîne 02→03→04→04b. Le passage QGIS en attente sur les ponts (`ETAT.md` point 1) **n'est pas concerné et reste à faire séparément**.

### Étape 2 — l'énergie dans le noyau

Un fichier neuf à côté de `ville.gd`, qui porte **la table des treize lignes** et rien d'autre que des nombres — même discipline que le reste du noyau : aucun accès aux nœuds. `ville.gd` y branche consommation, production, achat et CO2, par îlot et pour la ville, exactement comme il calcule déjà la surchauffe.

Le même fichier porte les **deux dérives du temps** du §6 bis b — coût du panneau −6 %/an, prix de l'énergie +2 %/an — parce que ce sont deux nombres, pas un système.

- ✅ **Ce qui prouve que c'est fait** : la console imprime les quatre chiffres de ville au mois 0, et ils correspondent au §3. Puis la **rentabilité du cœur ancien aux mois 0, 60 et 120** : elle doit descendre d'environ **24 → 16 → 11 ans**. (Les deux dérives se composent : la rentabilité affichée fond d'environ 7,8 % par an.)

### Étape 3 — les deux décisions

L'entrée dans `chantiers.gd`, plus la seule vraie plomberie de la session : le bouton « décider » doit accepter un **îlot** et pas seulement une rue.

**Deux entrées, pas une** : poser des panneaux et **isoler** (§5 bis). Les écrire ensemble et pas l'une après l'autre — la deuxième est ce qui prouve que la première n'a pas été codée en dur autour d'un seul cas.

Une décision gagne aussi **un nombre neuf, la durée des travaux** (§6 ter), distincte de la montée de l'effet. Le journal des chantiers doit le porter, sinon la vue chantiers ne saura pas quand un chantier s'arrête. **À renseigner aussi sur D07 pendant qu'on y est** (3 · 2 · 58), même si elle est éteinte — c'est deux minutes maintenant, et une reprise plus tard sinon.

⚠️ **Le capital politique doit pouvoir être positif** : `chantiers.gd` traite aujourd'hui le capital comme un coût. L'isolation en **rend**. Vérifier qu'un gain ne passe pas dans un contrôle qui refuserait une décision « trop chère » en capital.

- ✅ **Ce qui prouve que c'est fait** : cliquer la barre de 1974, poser des panneaux, voir la production décoller au bout de six mois. Puis **isoler la même barre** et voir la **consommation** tomber — deux courbes, deux formes.

### Étape 4 — le budget qui encaisse

Le coût se paie étalé (mécanique existante). Le retour arrive en crédit mensuel à partir de la fin des travaux.

- ⚠️ **Le contrôle de refus doit compter les retours déjà engagés, mais pas celui du chantier qu'on est en train d'accepter.** Sinon un chantier se finance lui-même et le budget ne mord plus jamais — le défaut exact que la session 10 avait mesuré.
- ✅ **Ce qui prouve que c'est fait** : le solde plonge pendant douze mois, puis remonte plus haut qu'avant.

### Étape 5 — ce qui se voit — **l'étape principale**

Ce n'est pas l'habillage du système, **c'est le système**. Le §1 dit que le jeu est le choix du lieu ; le choix du lieu se fait sur une carte ou ne se fait pas. Si le temps manque, c'est ici qu'il faut le prendre, quitte à sacrifier l'étape 6.

| Priorité | | Ce qu'on ajoute |
|---|---|---|
| **1** | 🗺️ **Calque « rentabilité solaire »** | **quatre classes, aucun nombre sur la carte.** L'écran principal du jeu, celui qu'on regarde **avant** de décider. Il doit faire dire « c'est là » en trois secondes |
| **1 bis** | 🗺️ **Calque « gain d'isolation »** | la carte presque inverse de la précédente : là où l'enveloppe est mauvaise et où il y a des gens. **Ces deux-là se regardent en alternance, c'est le geste central du jeu** |
| **2** | 🗺️ **Calque « visibilité »** | la troisième carte, celle du capital politique regagné. Sa valeur se juge en la comparant aux deux autres : **si les trois se ressemblent, il n'y a pas de dilemme et le contrepoids est raté** |
| **3** | 🚧 **Vue chantiers** (§6 ter) | la carte de ce qui est **en train** de se faire, plus la **barre à deux segments** au clic. Sans elle, le joueur ne voit pas son propre pipeline et le « au bon moment » est aveugle |
| **4** | 🏠 **Les toits** | ils **noircissent** au fur et à mesure de la pose. La preuve que quelque chose s'est passé, sans ouvrir un menu |
| **5** | 📋 **La fiche** | l'année du remboursement, en une ligne — la seule précision chiffrée du jeu. Plus toit équipable, production, part couverte, dans l'ordre du bandeau (règle 63b) |
| **6** | 🗺️ **Calque « toits qui produisent »** | la carte de ce qui a été fait |
| **7** | 📊 **Le bandeau** | les quatre nombres du §3, en écart à t0 |

- ✅ **Ce qui prouve que c'est fait** : une capture avant / après vingt ans, où la différence se voit **sans lire un seul chiffre**.
- ✅ **Et le contrôle propre à cette session** : deux captures du **même** état, calque rentabilité et calque visibilité. **Elles doivent être différentes.** Si elles se superposent, le §6 bis n'existe pas et la session a produit un tri.

### Étape 6 — le contrôle imprimé

Aux mois 0, 12, 60, 120 et 240 : consommation, production, achat, CO2, solde, capital. Plus trois invariants qui doivent tenir à chaque ligne :

1. achat + production = consommation, à l'échelle de la ville
2. la production ne dépasse jamais le potentiel total
3. un îlot équipé au mois 0 à 10 ans de rentabilité a remboursé son coût **au mois 132** (12 de travaux + 120), à 2 % près

- ✅ **Ce qui prouve que c'est cassé** : un des trois invariants qui dérive, ou une production qui monte alors qu'aucun chantier n'est en cours.

---

## 8. Ce qu'il faut regarder à l'écran, dans l'ordre

Les trois premiers points sont **le test**. Les trois derniers vérifient que la mécanique ne ment pas.

1. 🎯 **Le calque rentabilité, au mois 0, avant toute décision.** Est-ce que la carte donne envie de cliquer quelque part en particulier, **et est-ce qu'on saurait dire pourquoi à voix haute** ? Si elle est uniforme, la table des treize lignes est trop plate et c'est elle qu'il faut corriger — pas le code.
2. 🎯 **Basculer sur le calque gain d'isolation, puis sur celui de la visibilité, sans rien décider entre les trois.** La question est nue : *est-ce que ça change d'avis ?* Si oui, le jeu existe. Si non, le contrepoids est mal réglé et la rentabilité gouverne seule. Les deux premières cartes doivent être **presque inverses**, avec la barre de 1974 en rouge sur les deux.
2 bis. 🎯 **Deux parties entières, en aveugle : « panneaux uniquement » et « isolation uniquement ».** La première doit **se bloquer sur le capital politique**, la seconde **sur le budget**. Si les deux vont au bout sans buter, la paire ne tient pas — les deux décisions sont indépendantes, donc décoratives l'une pour l'autre. **C'est le contrôle le plus important de la session.**
3. 🎯 **Avancer de dix ans sans rien faire, puis regarder le calque rentabilité à nouveau.** La zone rouge doit avoir visiblement reculé. C'est le « bon moment » : s'il ne se voit pas, les −6 % par an sont trop timides.
4. 🚧 **Décider un chantier, puis avancer mois par mois en restant sur la vue chantiers.** Deux choses à vérifier : pendant les six premiers mois **rien ne bouge sauf la barre** — c'est le délai, et il doit se sentir — puis le chantier **disparaît de la carte au mois 12** alors que la production, elle, reste. Si l'objet reste marqué « en travaux » après la livraison, la durée des travaux n'est pas branchée.
5. **Équiper la barre de 1974 et la dalle commerciale, rien d'autre.** Passer vingt ans. Le budget doit finir plus haut qu'au départ, la production autour de 8 % — et le capital politique doit avoir **peu bougé**, puisqu'on a joué la carte de l'argent.
6. **Tout équiper aussi vite que possible.** Deux choses à surveiller : le mois où le capital politique bloque, et le plateau final de la production. S'il n'y a pas de blocage, la décision est gratuite et le jeu n'existe pas. ⚠️ **Regarder aussi si la vue chantiers reste lisible** avec vingt chantiers simultanés — si elle devient une bouillie, c'est le signal qu'il faut limiter le nombre de chantiers en parallèle, ce qui serait un vrai frein plutôt qu'un défaut d'affichage.
7. **Ne rien faire pendant vingt ans.** Production et CO2 doivent rester plats. ⚠️ **La consommation et l'achat, eux, ne le seront plus** : le prix de l'énergie monte de 2 % par an, donc la facture grimpe toute seule. C'est voulu — *ne rien faire a un coût* — mais il faut le voir venir, sinon on le prendra pour un bug.
8. **Le CO2 pendant les travaux.** Il doit **monter** d'abord (carbone gris), puis redescendre plus bas. Si la courbe descend tout de suite, le carbone gris n'est pas branché.

---

## 9. Quatre choses que je signale avant de commencer

**a. 🔴 Le contrepoids du §6 bis n'est pas négociable, il est seulement à valider.** Le capital politique regagné par la visibilité déborde du thème énergie — c'est un ajout au périmètre que l'auteur a le droit de refuser. Mais il faut savoir ce que le refus produit : **sans lui, la session teste un tri par colonne, pas une décision d'urbanisme**, et la réponse à la question du §1 sera fausse dans le sens optimiste. Si on le refuse, on l'écrit dans le compte rendu au lieu de l'oublier.

**b. ✅ Le défaut « trois nombres pour un seul mouvement » est réglé.** Il était réel : avec le solaire seul, la consommation ne bougeait pas, donc achat = 100 − production et CO2 = 0,25 × achat — un mouvement affiché trois fois. **L'isolation (§5 bis) fait bouger la consommation**, le carbone gris fait bosser le CO2 au moment des travaux. Les quatre nombres sont maintenant quatre.
→ ⚠️ **Ce qu'il faut vérifier en retour** : sur une partie mixte, les quatre courbes doivent avoir des **formes différentes**. Si elles restent parallèles, c'est que le gain d'isolation est trop faible pour peser et il faut monter la table du §5 bis.

**c. Le classeur ne double pas Godot cette fois.** `08_jouer.py` reste au repos et le contrôle de recoupement des deux moteurs n'est pas fait. C'est une **exception assumée** : le sujet tient en une formule et l'étape 6 la vérifie par trois invariants imprimés. Si le thème énergie est retenu après le test, le classeur devra rattraper — sinon la duplication ment sans qu'on le sache.

**d. La régie municipale n'est pas tranchée** (§6). Le code marche sans, mais le mécanisme n'est pas défendable tant que personne n'a dit à qui appartiennent les panneaux.

---

## 9 bis. Ce que cette session propose au vault, si le test passe

**Rien n'entre dans `Décisions arrêtées` avant que l'auteur ait vu tourner le résultat** — `CLAUDE.md` §3. Mais deux formulations sont prêtes, pour ne pas les reperdre :

| | Candidat | Statut |
|---|---|---|
| 🎯 | **La décision spatiale est le jeu.** *Pour être efficient, il faut investir au bon endroit au bon moment.* Un système qui ne produit pas ce choix-là est une décoration, quel que soit son réalisme. Corollaire opérationnel : **toute décision doit avoir un lieu où elle est bonne et un lieu où elle est mauvaise** — sinon elle se prend une fois, globalement, et n'appelle jamais la carte | énoncé par l'auteur le 2026-08-12, **à confirmer après le test** |
| 👁️ | **Le capital politique se regagne par la visibilité du chantier**, donc par le lieu. Ferme un point ouvert de `Indicateurs globaux` (*« un nombre nu ne dit pas ça revient parce que ça s'est vu »*) | proposé, **non tranché** |
| 🔋 | **On ne va pas vers l'autonomie énergétique en produisant plus, mais en consommant moins.** Les toits de Wehrau plafonnent à 30 % ; c'est l'isolation, pas le solaire, qui met le jalon à portée de vue. Corollaire de conception : **une décision qui réduit un besoin vaut mieux qu'une décision qui augmente une offre**, et le jeu doit le faire sentir plutôt que l'écrire | sort de l'arithmétique du §5 bis, **à confirmer après le test** |
| 🚧 | **Les chantiers en cours ne vont pas dans le bandeau, ils vont sur la carte.** Trois temps, trois formes : le bandeau le passé, les ressources le futur, **la vue chantiers le présent**. Ferme l'autre point ouvert de `Indicateurs globaux` (*« le temps et les chantiers en cours n'ont pas de place dans le bandeau »*), et donne enfin sa carte au deuxième nombre du budget, « ce qui est engagé » (58) | énoncé par l'auteur le 2026-08-12, **à confirmer après le test** |
| ⏱️ | **Un chantier fini n'est plus un chantier, même si son effet monte encore.** Une décision porte trois durées et non deux : délai · **travaux** · maturation | conséquence technique de la vue chantiers, **à valider** |

☐ Et une question à ouvrir, pas à fermer : **les quartiers de Wehrau n'ont pas de nom** (§6 bis d).

---

## 10. Ce qui n'est pas dans cette session

Le réseau de chaleur · l'éolien · le conflit d'intérêt de la régie qui perd des recettes quand on isole (§5 bis, noté et non construit) · l'inconfort des habitants pendant dix-huit mois de travaux chez eux · la saisonnalité (un bilan annuel équilibré n'est pas une autonomie en janvier — vrai, connu, hors sujet ici) · le rallumage des six autres indicateurs · le générateur de parcelles · les deux ponts à supprimer sous QGIS · toute écriture dans le `.gpkg`.

**Voir aussi** : `ETAT.md` · `Systèmes/Indicateurs globaux.md` · `Décisions arrêtées` 53 · 56 · 59 · 63 · `Godot/README.md`
