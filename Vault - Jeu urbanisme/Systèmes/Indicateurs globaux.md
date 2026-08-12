---
tags: [système, ui, indicateurs]
statut: arrêté (paramètres ouverts)
maj: 2026-08-12
---

# Indicateurs globaux

> Ce que le joueur a sous les yeux en permanence. **Sept indicateurs et deux ressources.**
> Issu du brainstorm du 2026-08-12 → [[Décisions arrêtées]] 53 à 59

## 🎯 La règle qui commande tout

> **Aucun chiffre global sans son calque.**
> Le chiffre dit *que* ça bouge, le calque dit *où*.

Un indicateur global est une **moyenne**, et une moyenne efface l'injustice géographique — précisément ce que [[Wehrau]] a été choisie pour porter. Planter dans le cœur ancien ou planter au Ried donnerait le même écart à l'écran.

Le calque est ce qui répare ça. Sans lui, le chiffre est une jauge qu'on optimise ; avec lui, c'est une **porte d'entrée vers la carte** — donc vers l'activité principale du jeu. → [[Diagnostic et calques]]

**Corollaire de sélection** : un indicateur dont on ne saurait pas dessiner la carte ne doit pas exister. C'est le filtre qui a taillé dix-neuf candidats à sept.

## Les sept

Tous affichés **en écart au départ**, jamais en valeur absolue — « +3 pts de canopée », pas « 14 % ». C'est le mode qui a rendu `parties.html` lisible : un mouvement de 0,4 pt sur 14 % est invisible autrement.

| | Indicateur | t0 | Son calque | Son max |
|---|---|---|---|---|
| 🌡️ | **Surchauffe** | +1,59 °C | îlot de chaleur | ❓ pas de jalon |
| 💧 | **La ville exposée** | *à calculer* | aléa + fil de l'eau | ville-éponge |
| 🚗 | **L'emprise voiture** | 4 587 places · 17,6 % de voirie | stationnement + charge | zéro voiture |
| 🏠 | **Les habitants d'origine** | 100 % | riverain | « personne n'a été chassé » |
| 🏭 | **CO2** | *à calculer* | trafic + chauffage | zéro carbone |
| ☀️ | **Les toits qui produisent** | 0 % | potentiel solaire | autonome en énergie |
| 🚋 | **Ce qui est desservi** | *à calculer* | desserte TC | ❓ pas de jalon |

**En contexte, pas en objectif** : population (5 353), densité, la date, et **l'état de l'économie** — une barre sans nombre, parce qu'un état non chiffré ne s'optimise pas. On ne joue à faire monter aucun des quatre. → [[Décisions arrêtées]] 60 · [[Ressources]]

⚠️ **Ne sont pas des indicateurs** : l'argent et le capital politique. Ce sont les deux **ressources** → [[Ressources]].

## Ce qu'on a écarté, et pourquoi

**Toute l'économie chiffrée** — chômage, revenu, productivité, taux d'imposition, loyer moyen, taux de vacance. Aucun n'a de donnée derrière, tous demandent une sous-simulation, et mis bout à bout ils font *Cities: Skylines*. Le but affiché est **« inspirer, pas simuler la bureaucratie »** ; ces six-là en sont le cœur.

Le taux d'imposition, en plus, n'est pas un indicateur — **c'est un levier**.

Ce qui la remplace : **une barre sans nombre**, en contexte, et un budget qui en dépend — *un état non chiffré ne s'optimise pas.* Plus deux formules pour la part que le joueur maîtrise. → [[Ressources]] · [[Décisions arrêtées]] 60

## Dérivé, pas simulé

Le CO2 et le renouvelable ont été **gardés sans économie** parce qu'ils n'en ont pas besoin. Ce sont des **formules sur des attributs existants**, exactement comme la surchauffe, qui n'est rien d'autre que `3,5 × imperméabilisé − 2,5 × canopée`.

| Indicateur | Ce dont il se dérive |
|---|---|
| **CO2** | trafic (`charge`) + chauffage (`logements` × `hauteur` × époque) |
| **Renouvelable** | la **surface de toit** — 76,5 ha bâtis dans `emprises`, × orientation × ombrage |

Le renouvelable devient **« la part des toits qui produit »** : il se voit littéralement à l'écran, il a une carte, et il tombe sur le chantier des toits déjà prévu → [[Génération procédurale]].

> **Une formule sur des attributs existants n'est pas une sous-simulation.** C'est la manœuvre qui a sauvé trois indicateurs et le budget.

## 🔥 Ce qui pousse contre quoi

**Si deux indicateurs ne se poussent pas dessus, ce sont des décorations.**

| Ce que tu montes | Ce qui descend tout seul |
|---|---|
| Densité (→ TC viable, commerces) | habitants d'origine (loyers) · imperméabilisé |
| Canopée en rue | places de stationnement |
| Protection contre la crue | **l'aval** — quelqu'un prend l'eau à ta place |
| Vitesse de transformation | capital politique |
| Les toits qui produisent | **la forme urbaine** — un toit qui produit est plat et plein sud, contre les volumes doux de Townscaper |
| Densité (encore) | le **ratio production/besoin** : plus de m² à chauffer sous la même surface de toit |
| Reconstruire du performant | **le carbone gris** |

**« Habitants d'origine » ne monte jamais.** Toute transformation chasse quelqu'un. C'est l'indicateur qui empêche le bandeau de devenir une liste de courses. → [[Ton et règles d'écriture]]

☐ **Contrôle à faire** : passer les sept en revue et vérifier que chacun a bien un antagoniste. Ceux qui n'en ont pas sont mal conçus.

## ⚫ Le carbone gris

Démolir-reconstruire émet **un gros coup immédiat**, que la performance du neuf met des années à rembourser.

Ce que ça produit : **« adapter » devient mécaniquement défendable face à « reconstruire »** — et ces deux mots sont déjà deux des trois postures adossées à `alea` (reconstruire / adapter / **rendre à l'eau**). L'indicateur ne mesure pas seulement, **il rend chiffrable un dilemme qui existait déjà**.

⚠️ **Le risque symétrique** : si le carbone gris pèse trop lourd, le jeu dit « ne touche à rien ». Un city-builder de transformation qui récompense l'immobilisme se contredit. À calibrer devant les chiffres.

## 📊 La forme à l'écran

### Les bornes

Chaque indicateur est **borné**, et le max n'est pas un 100 % abstrait : **c'est un jalon qui a déjà un nom**. Cinq des sept finissent sur un [[Milestones|milestone]] existant.

Borner un indicateur, c'est nommer l'état où il sature — la définition même d'un milestone. **Le bandeau et le système de progression sont le même objet vu de deux côtés.**

⚠️ **Borner ne soigne pas une spirale, ça la cache.** Une valeur clampée à 100 reste emballée, elle est seulement garée contre le mur. Ce qui soigne une spirale est une **contre-réaction** — le tableau ci-dessus.

> **Les bornes sont la ceinture de sécurité. Le frein, ce sont les antagonismes.**

### La barre : trois repères, pas un remplissage

```
     pire            t0              maintenant                    ?
      │               ▼                    │
  ────┴───────────────┼════════════════════┫ · · · · · · · · · · ·
                       ce que tu as fait      pas encore en vue
```

| Le repère | Ce qu'il fait |
|---|---|
| **t0 marqué en dur** | le zéro de l'écart |
| **De la place à gauche** | on peut empirer — *« on ne perd pas la partie, on perd des quartiers »* → [[Déclin et défaite]] |
| **Le bout en pointillés** | la borne existe en logique dès le début, le jalon ne s'affiche qu'à l'approche |

Le pointillé résout un piège nommé dans [[Milestones]] : *« un jalon annoncé à l'avance devient une liste de tâches »*. Si la barre montrait son bout, on annoncerait les sept cibles au tour 1.

### 🏠 Une barre ne ressemble pas aux autres

**« Habitants d'origine » part pleine et ne peut que s'entamer.** Dessinée comme les six autres — vide qui se remplit — elle mentirait sur sa nature.

Proposition : la sortir de la rangée et la poser **dessous, en travers, comme la ligne du prix**. Tout ce qui se remplit en haut se paie là. Le bandeau se lit alors comme une **transaction**, et non comme une check-list — seule réponse trouvée au problème des six barres qui pointent dans le même sens.

### Ressources et indicateurs ne se dessinent pas pareil

| | Indicateur | Ressource |
|---|---|---|
| Ce qu'il dit | **ce que tu as fait** | **ce que tu peux faire** |
| Sa forme | une **barre**, écart à t0, bornée par un jalon | un **compteur**, stock qui monte et descend |
| Son bout | un milestone nommé | aucun — un stock n'a pas de but |
| Son délai | des années | immédiat |

> **Les indicateurs regardent en arrière, les ressources en avant.**

## ⚠️ Ce qui n'est pas résolu

- 🟠 **Onze nombres permanents** (7 indicateurs + capital + 3 nombres de budget). Le seuil défendu au départ était de l'ordre de six ; trois élargissements successifs, chacun défendable seul, jamais regardés ensemble. **À trancher devant une maquette d'UI.** Rappel : ⚠️ l'UI blanche sur neige blanche de Frostpunk est le risque direct avec une palette pastel → [[Direction artistique]]
- 🔴 **Conflit avec [[Déclin et défaite]]**, qui refuse la jauge globale : *« une note de résilience sur 100 ne dit rien et ne se joue pas »*. La barre **ville exposée** tombe dessus. Résolution proposée : ce que la note refusait est une jauge *sans carte* — la règle du haut de page la lève. **Non confirmé.**
- ☐ **Surchauffe et desserte n'ont pas de jalon.** Candidats : *« la ville n'est plus plus chaude que ses champs »* et *« tout le monde à moins de 300 m d'un arrêt »*. Tous deux passent le test de la capture sans interface → [[Milestones]]
- ☐ **Trois valeurs à t0 manquent** : la ville exposée, le CO2, la desserte. Calculables sur les attributs existants.
- ☐ **Le temps et les chantiers en cours** n'ont pas de place dans le bandeau, alors que c'est l'anti-spectateur → [[Chantiers et temps]]
- ☐ **Comment le capital politique se regagne** n'a aucune forme à l'écran. Un nombre nu ne dit pas *« ça revient parce que ça s'est vu »* → [[Ressources]]

**Voir aussi** : [[Diagnostic et calques]] · [[Ressources]] · [[Milestones]] · [[Pièges connus]] · [[Fins et pluralisme]]
