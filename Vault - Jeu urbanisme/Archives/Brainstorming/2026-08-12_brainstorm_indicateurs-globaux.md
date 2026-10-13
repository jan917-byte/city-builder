---
tags: [brainstorming, ui, système, indicateurs]
statut: digéré
date: 2026-08-12
sujet: les indicateurs globaux — ceux qui concernent toute la ville et que le joueur voit en permanence
maj: 2026-08-12
---

# 2026-08-12 — Les indicateurs globaux

**Question de départ :** quels chiffres le joueur a-t-il sous les yeux en permanence, et qu'est-ce qu'ils lui font faire ?

**Ce qui en est sorti :** une règle structurante (*un chiffre, un calque*), sept indicateurs retenus au lieu de dix-neuf, trois arbitrages tranchés par l'auteur, et deux questions neuves.

**✅ Remonté le 2026-08-12 :** neuf décisions **53 à 60b** dans [[Décisions arrêtées]] · la note système [[Indicateurs globaux]] · question **n°3 close**, **n°19**, **n°20** et **n°21** ouvertes dans [[Questions ouvertes]] · sections neuves dans [[Milestones]], [[Ressources]] et [[Diagnostic et calques]].

> Ce fichier reste comme **archive du raisonnement** : les objections, les chiffres qui les fondent et les **options écartées** y sont, et elles ne sont nulle part ailleurs.

**Notes concernées** : [[Indicateurs globaux]] · [[Diagnostic et calques]] · [[Ressources]] · [[Milestones]] · [[Pièges connus]] · [[Fins et pluralisme]] · [[Déclin et défaite]] · [[Direction artistique]]

---

## 1. Le point de départ

L'auteur arrive avec une planche de **dix-neuf indicateurs** en cinq familles : sociaux-économiques (population, croissance, densité · chômage, revenu, imposition, productivité · loyer, vacance), mobilité (usage voiture · usage et prix TP), climat (température en écart, CO2, canopée), énergie (taux de renouvelable).

La planche est juste sur le **découpage thématique**. Elle achoppe sur trois choses.

## 2. Les trois objections

### 🪤 Dix-neuf chiffres, c'est *Democracy 4*

[[Pièges connus]] nomme D4 comme cas d'école : *« le jeu devient l'optimisation de ces pourcentages »*. Le seuil n'est pas moral, il est mécanique — **au-delà d'une poignée de chiffres permanents, le joueur ne lit plus une ville, il lit un tableau de bord.** Et un tableau de bord se joue en le remontant, pas en le comprenant.

### 🔴 Une moyenne à l'échelle de la ville efface la carte

L'objection la plus dure, et elle touche un pilier non négociable : **le lieu doit changer le résultat**. Or « canopée : taux » est une moyenne sur 69 îlots. Planter dans le cœur ancien ou planter au Ried donne le même écart à l'écran.

Un indicateur global, par construction, **efface l'injustice géographique** — précisément ce que Wehrau a été choisie pour porter (amont/aval, deux rives). → [[Wehrau]]

### ⚠️ La moitié de la liste n'a aucune donnée derrière

| L'indicateur | État | Ce qu'il coûte |
|---|---|---|
| Densité · population | ✅ dans le `.gpkg` | rien |
| Canopée · température (écart) | ✅ calculée, **+1,59 °C à t0** | rien |
| Usage voiture | ⚠️ `charge` est un flux, **pas une part modale** | un modèle de choix modal |
| Usage TP | ⚠️ `desserte_tc` est une desserte, pas un usage | idem |
| Loyer · vacance | ⚠️ approchables via `riverain` | un modèle de marché du logement |
| Chômage · revenu · productivité | ❌ rien | **une sous-simulation économique entière** |
| Taux d'imposition | 🔴 ce n'est pas un indicateur, **c'est un levier** | et il ouvre le piège de l'exponentielle économique |

La colonne de droite mise bout à bout, c'est *Cities: Skylines*. Le but affiché est **« inspirer, pas simuler la bureaucratie »** — chômage, revenu et productivité en sont le cœur.

## 3. 🎯 La règle qui est sortie de la discussion

> **Aucun chiffre global sans son calque.**
> Le chiffre dit *que* ça bouge, le calque dit *où*.
> Un indicateur sans carte est une jauge ; avec sa carte, c'est une invitation à regarder la ville.

Corollaire : **un indicateur dont on ne saurait pas dessiner la carte ne devrait pas exister.** C'est le filtre qui a servi à tailler dans les dix-neuf.

C'est aussi ce qui raccorde le bandeau à [[Diagnostic et calques]] : le diagnostic étant *« l'activité principale entre deux décisions »*, chaque chiffre du haut de l'écran devient une porte d'entrée vers une carte, au lieu d'un score à faire monter.

## 4. Ce qui manquait à la planche

Trois absences, toutes remarquées pendant la discussion :

- 💧 **L'eau.** Le jeu **s'ouvre sur une crue** ([[Décisions arrêtées]] 23b), `alea` / `position_fil_eau` / `rive` sont dans les données, la digue qui protège ici et aggrave en aval est le meilleur mécanisme du prototype — et il n'y avait aucun indicateur d'eau.
- 🏠 **Les habitants d'origine.** `riverain` est *« la seule boucle de gentrification du prototype »*. C'est aussi le **prix social**, candidat au deuxième axe de [[Fins et pluralisme]]. « Loyer moyen » en est la version abstraite ; « combien des gens de 2026 sont encore là en 2046 » en est la version concrète — et celle-là se voit.
- ⏳ **Le temps** — ce qui est en chantier, ce qui n'a pas encore produit son effet. C'est ce qui empêche le joueur d'être spectateur. **Non traité ici**, à reprendre. → [[Chantiers et temps]]

## 5. ✅ Les trois arbitrages tranchés par l'auteur

### Pas d'économie simulée

Chômage, revenu, productivité, imposition, loyer, vacance : **tous écartés**. L'argent reste une dotation ; le social passe par `riverain`, pas par un marché du logement.

**Ce que ça ferme** : le piège de l'exponentielle économique, et plusieurs semaines de sous-simulation.
**Ce que ça coûte** : pas de boucle « densifier rapporte ». L'investissement ne se rembourse pas — la contrepartie proposée dans [[Ressources]] (les charges d'entretien montent avec l'étalement) reste à trancher séparément.

### Les chiffres s'affichent en écart au départ

« +3 pts de canopée », « −1 200 places », pas « 14 % » ni « 4 587 ». C'est le **mode « écart au mois 0 »** de `parties.html`, noté en session 10 comme *le seul qui rende un changement lisible*. Un mouvement de 0,4 pt sur 14 % est invisible en valeur absolue.

**Effet secondaire à assumer** : le bandeau dit ce que **le joueur** a fait, pas où en est la ville. L'état réel doit donc rester lisible ailleurs — la fiche d'îlot, les calques.

### CO2 et renouvelable restent en permanent

L'auteur les garde contre ma recommandation. **Il a raison, et j'avais tort sur un point** : j'affirmais que le CO2 n'a pas de carte. À l'échelle de la ville, non. Dérivé **par îlot** — le chauffage vient de ses bâtiments, le trafic de ses rues riveraines — il en a une.

Ce qui débloque tout : **ni l'un ni l'autre n'a besoin d'une simulation**. Ce sont des **formules sur des attributs qui existent déjà**, exactement comme la surchauffe, qui n'est rien d'autre que `3,5 × imperméabilisé − 2,5 × canopée`.

| Indicateur | De quoi on le dérive | Existe ? |
|---|---|---|
| **CO2** | trafic (`charge`) + chauffage (`logements` × `hauteur` × époque) | ✅ tout est là |
| **Renouvelable** | **la surface de toit** — 76,5 ha bâtis dans `emprises`, × orientation × ombrage | ✅ c'est de la géométrie |

Le renouvelable devient **« la part des toits qui produit »** : il se voit littéralement à l'écran, il a une carte, et il tombe sur le chantier des **toits et gabarits** déjà prévu en phase A. On ne paie pas deux fois. → [[Génération procédurale]]

### Deux rétrogradations proposées, une seule retenue

| Proposé | Décision |
|---|---|
| Sortir la **desserte TC** du bandeau (en faire un seuil de fiche d'îlot) | ❌ **refusé** — elle reste le 7ᵉ indicateur. La mobilité garde deux chiffres |
| Sortir **population et densité** du bandeau (contexte, à côté de la date) | ✅ retenu — on ne joue pas à faire monter la population |

## 6. 🎯 Les sept retenus

Été · eau · sol · gens · carbone · énergie · desserte. Tous en **écart au départ**.

| | Indicateur | t0 | Son calque |
|---|---|---|---|
| 🌡️ | **Surchauffe** | +1,59 °C | îlot de chaleur |
| 💧 | **La ville exposée** | *(à calculer sur `alea`)* | aléa + fil de l'eau |
| 🚗 | **L'emprise voiture** | 4 587 places · 17,6 % de voirie | stationnement + charge |
| 🏠 | **Les habitants d'origine** | 100 % par définition | riverain |
| 🏭 | **CO2** | *(à calculer)* | trafic + chauffage |
| ☀️ | **Les toits qui produisent** | 0 % | potentiel solaire |
| 🚋 | **Ce qui est desservi** | *(à calculer)* | desserte TC |

**En contexte, pas en objectif** : population (5 353 hab.), densité, la date.

⚠️ **Ne sont pas des indicateurs** : l'argent et le capital politique. Ce sont les deux **ressources**, déjà tranchées, et elles obéissent à d'autres règles — notamment « le capital politique ne s'achète pas ». → [[Ressources]]

Total à l'écran : **9 nombres permanents** (2 ressources + 7 indicateurs). C'est au-dessus du seuil défendu en §2. **Assumé par l'auteur**, mais c'est le point à surveiller à la première maquette d'UI.

## 7. 🔥 Ce qui pousse contre quoi

La partie qui compte : **si deux indicateurs ne se poussent pas dessus, ce sont des décorations.**

| Ce que tu montes | Ce qui descend tout seul |
|---|---|
| Densité (→ TC viable, commerces) | habitants d'origine (loyers) · imperméabilisé |
| Canopée en rue | places de stationnement |
| Protection contre la crue | **l'aval** — quelqu'un prend l'eau à ta place |
| Vitesse de transformation | capital politique |
| Les toits qui produisent | **la forme urbaine** — un toit qui produit est plat et plein sud, contre les volumes doux de Townscaper |
| Densité (encore) | le **ratio production/besoin** : plus de m² à chauffer sous la même surface de toit |
| CO2 : reconstruire du performant | **le carbone gris** — le neuf émet aujourd'hui pour économiser dans trente ans |

**« Habitants d'origine » ne monte jamais.** Toute transformation chasse quelqu'un. C'est l'indicateur qui empêche le bandeau de devenir une liste de courses — et c'est exactement *dur mais possible, jamais cynique*. → [[Ton et règles d'écriture]]

## 8. ✅ Le carbone gris est assumé

Tranché par l'auteur : démolir-reconstruire émet **un gros coup immédiat**, qui met des années à être remboursé par la performance du neuf.

Ce que ça produit, et c'est le meilleur cadeau de la session : **« adapter » devient mécaniquement défendable face à « reconstruire »** — et ces deux mots sont déjà les trois postures adossées à `alea` (reconstruire / adapter / **rendre à l'eau**), restées en `brut` depuis le brainstorm du 2026-08-10.

L'indicateur ne se contente donc pas de mesurer : **il rend chiffrable un dilemme qui existait déjà dans le vault**, sans rien ajouter au jeu. C'est aussi ce qui empêche le CO2 d'être une case à cocher.

⚠️ **Le risque symétrique** : si le carbone gris est trop lourd, le jeu dit « ne touche à rien ». Un city-builder de transformation qui récompense l'immobilisme se contredit. À calibrer devant les chiffres, pas dans le vide.

## 9. Les bornes, et la barre — deuxième moitié de séance

L'auteur arrive avec une proposition de logique **et** d'UI : chaque valeur a un minimum et un maximum (0 voiture / 100 % TP, 0 émission / max émission) *« pour éviter les spirales »* — donc des **barres** à l'écran.

### 🎯 Ce que le bornage a révélé : le max est un jalon qui a déjà un nom

C'est la trouvaille de la séance. Mis en face de [[Milestones]], les maxima ne sont pas des 100 % abstraits :

| Indicateur | Son max | Milestone existant |
|---|---|---|
| 🚗 Emprise voiture | 0 voiture | ⭐ **zéro voiture** — *« le plus lisible »* |
| 🏭 CO2 | 0 émission | **zéro carbone** — le but affiché du jeu (décision 9) |
| ☀️ Toits qui produisent | 100 % | **autonome en énergie** |
| 💧 Ville exposée | 0 exposé | ⭐ **ville-éponge** |
| 🏠 Habitants d'origine | 100 % restés | « **personne n'a été chassé** » — proposé, non tranché |
| 🌡️ Surchauffe | ❓ | *aucun* |
| 🚋 Desserte | ❓ | *aucun* |

**Cinq sur sept finissent sur un jalon déjà écrit.** Ce n'est pas un hasard : borner un indicateur, c'est nommer l'état où il sature — la définition même d'un milestone. **Le bandeau et le système de progression sont le même objet vu de deux côtés.**

✅ **Effet de bord : ça ferme une question.** [[Milestones]] disait de zéro carbone *« objectif, pas forme — piste : le garder comme compteur permanent plutôt que comme jalon à débloquer. À trancher. »* Le choix de garder le CO2 en permanent (§5) **tranche ça**.

☐ **Deux indicateurs n'ont pas de jalon.** Candidats proposés, non tranchés : la surchauffe → *« la ville n'est plus plus chaude que ses champs »* ; la desserte → *« tout le monde à moins de 300 m d'un arrêt »*. Tous deux se reconnaîtraient sur une capture sans interface, ce qui est le test de [[Milestones]].

### ⚠️ Borner ne soigne pas une spirale, ça la cache

La raison invoquée pour le max est d'éviter les spirales. Correction, parce qu'elle change ce qu'on construit : **une valeur clampée à 100 reste une valeur emballée, elle est seulement garée contre le mur.** La dynamique reste cassée, et on ne la voit plus.

Ce qui soigne une spirale est une **contre-réaction** — et elle existe déjà : le tableau §7. Densifier monte le TC *et* chasse les riverains ; planter *et* prend des places.

> **Les bornes sont la ceinture de sécurité. Le frein, ce sont les antagonismes.**

Corollaire de contrôle : **un indicateur que rien ne pousse en sens inverse est un indicateur mal conçu.** La borne est alors le symptôme, pas la solution.

### La forme de la barre

Objection : sept barres qui pointent toutes à droite, c'est *Democracy 4*. Pire, [[Milestones]] prévient que *« un jalon annoncé à l'avance devient une liste de tâches — ce que le jeu refuse d'être »*. Or si la barre montre son bout et que son bout est un jalon, **on annonce tous les milestones au tour 1**. La forme de la barre *est* la question « quand les jalons s'affichent », restée non tranchée dans [[Milestones]].

**Retenu : trois repères, pas un remplissage.**

```
     pire            t0              maintenant                    ?
      │               ▼                    │
  ────┴───────────────┼════════════════════┫ · · · · · · · · · · ·
                       ce que tu as fait      pas encore en vue
```

| Le repère | Ce qu'il fait |
|---|---|
| **t0 marqué en dur** | le zéro de l'écart — cohérent avec l'affichage en écart (§5) |
| **De la place à gauche de t0** | on peut empirer. *« On ne perd pas la partie, on perd des quartiers »* → [[Déclin et défaite]] |
| **Le bout en pointillés** ✅ | la borne existe en logique dès le début, le jalon ne s'affiche que quand il devient plausible. Garde le bornage sans donner la liste de courses |

✅ **Tranché en séance** : le max est **le jalon nommé** (pas un plafond physique, pas le fil de l'eau), et **il se révèle à l'approche**.

⏸️ **Le fil de l'eau écarté, mais pas mort.** L'option était de prendre pour repère *ce qui arrive si on ne fait rien pendant 20 ans* — le scénario tendanciel du vrai métier, qui dit que ne rien faire n'est pas neutre. Écarté pour son coût (une formule de dérive à écrire et calibrer). À rouvrir si le jeu se révèle trop indulgent avec l'inaction.

### 🏠 Une barre ne ressemble pas aux autres

**« Habitants d'origine » part pleine et ne peut que s'entamer.** Dessinée comme les six autres — vide qui se remplit — elle mentirait sur sa nature.

Proposition : la sortir de la rangée et la poser **dessous, en travers, comme la ligne du prix**. Tout ce qui se remplit en haut se paie là. Le bandeau se lit alors comme une **transaction** et non comme une check-list — ce qui est la seule réponse trouvée au problème des six barres qui pointent dans le même sens.

### 🔴 Un conflit avec le vault, à confirmer

[[Déclin et défaite]] §« Pourquoi pas de jauge globale » refuse explicitement ce dispositif : *« Une note de résilience sur 100 ne dit rien et ne se joue pas. Ce qu'il faut, c'est une exposition par quartier. »* La barre **ville exposée** tombe pile dessus.

Résolution proposée, **non confirmée par l'auteur** : la règle du §3 le règle — ce que la note refusait est une jauge *sans carte derrière*. Une barre appariée à son calque n'est pas une note sur 100.

## 10. Les deux ressources sur le bandeau — troisième moitié de séance

L'auteur confirme que **budget annuel** et **capital politique** s'affichent aussi en permanence, et hésite à reporter la question d'une économie simplifiée.

### 🔴 Le fait qui commande tout : le budget ne mord jamais

Mesuré en session 10, sur trois parties de 60 mois : **la plus dépensière consomme 418 pts sur 500 et finit à +152 de solde. Aucune décision n'a jamais été refusée pour cause de budget.**

Conséquence non cosmétique : afficher en permanence un nombre qui n'arbitre rien. Et surtout — **si l'argent ne contraint pas, le jeu n'a qu'une seule ressource**, et tout le § « l'échange entre les deux » de [[Ressources]] (dépenser de l'argent pour éviter un coût politique, et l'inverse) est décoratif.

### Indicateur et ressource ne se lisent pas pareil

| | Indicateur | Ressource |
|---|---|---|
| Ce que c'est | l'état de la ville | ce que tu as en main |
| Ce qu'il dit | **ce que tu as fait** | **ce que tu peux faire** |
| Sa forme | écart à t0, borné par un jalon | un stock qui monte et descend |
| Son bout | un milestone nommé | aucun — un stock n'a pas de but |
| Son délai | des années | immédiat |

> **Les indicateurs regardent en arrière, les ressources en avant.**

✅ **Tranché : formes distinctes.** Ressources en **compteurs**, indicateurs en **barres**, séparés à l'écran. La forme dit à quoi ça sert avant qu'on lise le chiffre. Dessinés pareil, on lirait neuf jauges à remplir.

### ✅ Tranché : le budget affiche trois nombres

Ce que tu as · **ce qui est déjà engagé** · ce qui reste libre.

C'est déjà la logique du code — **le budget est étalé sur la durée du chantier, le capital est payé comptant le mois où l'on décide.** Cette asymétrie est ce qui permet de s'engager sur ce qu'on ne peut pas encore payer ; l'argent engagé est exactement ce qui surprend un joueur. Sans les trois nombres, on croit avoir de l'argent qui est déjà parti, et on perd la lecture du calendrier.

### ✅ Tranché : deux formules, pas une économie

Même geste qu'au §5 pour le CO2 et le renouvelable — **une formule sur des attributs existants n'est pas une sous-simulation.**

| Régime | Ce qu'il demande | Ce qu'il donne |
|---|---|---|
| Dotation fixe | rien | plat, et l'argent continue de ne pas mordre |
| ✅ **Deux formules** | recettes ∝ `logements` · charges ∝ **mètres de voirie** — tout est dans le `.gpkg` | l'étalement coûte, la compacité paie. **Et le budget se met à mordre** |
| Économie complète | des semaines | *Cities: Skylines*, écarté au §5 |

**Ce que ça ressuscite** : les **charges d'entretien du réseau**, orphelines depuis que l'économie a été écartée. C'était *« la raison structurelle de préférer la ville compacte à l'étalement »* de [[Ressources]] — un vrai enseignement du métier, récupéré pour deux lignes.

⚠️ **Ce que ça coûte, écrit noir sur blanc** : ça rouvre partiellement le **piège de l'exponentielle économique**. Densifier rapporterait. La contrepartie est dans la même formule — plus de logements, plus de réseau à entretenir — mais elle demande d'être **calibrée**, pas seulement écrite. Le contrôle à faire : vérifier qu'une stratégie de densification pure ne s'autofinance pas. → [[Pièges connus]]

⚠️ **Le mot « annuel » n'est pas neutre non plus** : il suppose un budget qui se renouvelle par période, et reporter la question revenait à choisir la dotation fixe par défaut. C'est ce qui a fait trancher maintenant plutôt que plus tard.

### Le compte à l'écran monte encore

7 indicateurs + capital politique + **3 nombres de budget** = **11 nombres permanents**. Le seuil défendu au §2 était de l'ordre de six. C'est le troisième élargissement de la séance, tous assumés séparément, aucun ensemble. **À regarder d'un bloc devant la première maquette d'UI.**

## 11. L'économie revient par une autre porte — quatrième moitié de séance

Après la consolidation, l'auteur propose autre chose que ce qu'on venait d'écrire : **une barre d'état de l'économie sans chiffre**, un **budget annuel qui en dépend**, et **le calcul caché**.

### Ce qui est fort, et que je n'avais pas vu

> **Un état non chiffré ne s'optimise pas.**

Tout le piège *Democracy 4* tient au **pourcentage** — on ne min-maxe pas une barre sans nombre. On obtient une économie qui **se sent** sans qu'elle puisse être auditée au tableur. C'est exactement le geste de 16b sur le capital politique : rendre la chose réelle sans la rendre calculable.

Gain non formulé par l'auteur, et peut-être le vrai : **la prospérité de la ville n'est pas entièrement son fait.** Un budget municipal dépend d'une conjoncture qu'aucun maire ne contrôle. C'est du métier, et ça rend le jeu plus juste, pas moins.

### Comment ça compose avec 59 plutôt que de l'écraser

| | |
|---|---|
| **Ce que le joueur maîtrise** | recettes ∝ `logements` · charges ∝ mètres de voirie — visible, dérivable, **c'est sa ville** |
| **Ce qu'il ne maîtrise pas** | l'état de l'économie — le **multiplicateur** |

*Dur mais possible* : on peut faire une bonne ville dans une mauvaise décennie, ça coûte simplement plus cher.

### ✅ Tranché

**Moteur mixte** — cycle exogène lent × part endogène modeste (emplois, desserte, attractivité) : on atténue une mauvaise passe, on ne la supprime jamais. **Écarté** : l'exogène seul, qui devient de la météo et fait varier le budget sans rien vouloir dire ; et l'endogène seul, qui est une économie complète juste cachée — le piège de l'exponentielle y devient **invisible**, donc impossible à voir venir.

**Place** : le bandeau de **contexte**, avec la population et la date. Pas un 8ᵉ indicateur — on ne la pilote pas.

### 🔴 Les deux garde-fous

> **Formule cachée ≠ causalité cachée.**

Que le joueur ne voie pas l'équation, très bien. Qu'il ne puisse pas dire **pourquoi son budget a baissé**, non : il n'apprend alors plus rien, et le jeu veut *inspirer*. *Frostpunk* cache ses formules et ne cache jamais ses raisons — il envoie un événement. Donc : quand la barre bouge, **quelque chose le dit, en une phrase et sans chiffre**.

Et l'interdit : **une économie cachée est le terrain rêvé de la difficulté adaptative**, écartée par 21. Si l'état peut dériver sans être vu, la tentation de le faire dériver contre un joueur qui réussit est immédiate — et **elle arrivera par accident si elle n'est pas nommée**.

### ❓ Le problème posé par l'auteur lui-même

La barre est dans le contexte, le budget avec les ressources : **loin l'un de l'autre**. Le lien ne peut pas être porté par la proximité. Trois pistes, compatibles, **aucune tranchée** — le budget **voté** une fois par an plutôt que subi · la barre qui **nomme sa conséquence** (« les recettes rentrent mal ») plutôt que son état · le budget qui **se décompose au survol**. Recommandation : les trois. → n°21

## 12. Ce qui reste ouvert

- 🔴 **Le conflit avec [[Déclin et défaite]]** (§9) : la note refuse la jauge globale. À confirmer que la règle *un chiffre, un calque* le lève, ou à trancher autrement.
- 🟠 **Onze nombres permanents à l'écran** (§10), en barres et en compteurs. Trois élargissements assumés séparément, jamais regardés ensemble. Se tranche devant une maquette d'UI, pas ici. Rappel de [[Direction artistique]] : ⚠️ l'UI de Frostpunk (blanche sur neige blanche) est le risque direct avec une palette pastel.
- 🔴 **Calibrer les deux formules de budget** (§10) : le contrôle est qu'une stratégie de densification pure **ne s'autofinance pas**. Sinon le piège de l'exponentielle est rouvert pour de bon. Le classeur est l'endroit pour le vérifier — une soirée, pas trois semaines.
- ☐ **Surchauffe et desserte n'ont pas de jalon** pour borner leur barre. Deux candidats proposés en §9, non tranchés.
- ☐ **Le contrôle qui découle du §9** : passer les sept indicateurs en revue et vérifier que chacun a bien quelque chose qui le pousse en sens inverse. Ceux qui n'en ont pas sont mal conçus.
- 🟠 **Le toit qui produit contre les volumes doux.** Le renouvelable pousse la forme urbaine vers le toit plat plein sud ; la DA a arrêté Townscaper. C'est une **vraie tension esthétique**, donc plutôt une bonne nouvelle — mais elle n'a pas de réponse. → [[Direction artistique]] · [[Décisions arrêtées]] 42b
- ☐ **Trois valeurs à t0 manquent** : la ville exposée, le CO2, la desserte. Calculables sur les attributs existants, à faire côté Windows.
- ☐ **Le temps / les chantiers en cours** n'a pas été traité. C'est pourtant l'anti-spectateur.
- ✅ ~~Les charges d'entretien du réseau sont orphelines~~ — **récupérées au §10** par la formule « charges ∝ mètres de voirie ».

---

**Voir aussi** : [[Diagnostic et calques]] · [[Ressources]] · [[Pièges connus]] · [[Fins et pluralisme]] · [[00 - Brainstorming]]
