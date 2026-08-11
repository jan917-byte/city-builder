---
tags: [vision, ton, DA]
statut: arrêté
maj: 2026-08-12
---

# Ton et règles d'écriture

## La règle mère

> **Dur mais possible. Jamais cynique.**

Les frictions sont réelles, les arbitrages sont durs, mais tout est surmontable. Le jeu doit faire rêver, pas désabuser. C'est ce qui le sépare de tous les jeux « climat » moralisateurs.

## Arbitrages honnêtes à assumer

- La **gentrification comme conséquence du succès** — pas comme punition
- Les **émissions exportées** (on ne les supprime pas, on les déplace)
- Le **coût de la transformation** elle-même (béton, chantier, gêne)
- Le **retrait** : rendre un quartier à la rivière. Coûteux, irréversible, ressemble à une défaite, et c'est parfois la meilleure décision. Si le jeu ose ça, il a quelque chose que personne n'a. → [[Déclin et défaite]]


## Volume de texte

**Cible ~10 000 mots, pas 30 000.** Double raison : meilleur jeu (on montre au lieu de raconter) et localisation trois fois moins chère. Voir [[Marketing et Steam]]

Corollaire de design : chaque effet doit être **lisible à l'écran** avant d'être écrit dans un texte.

## La contre-référence de ton : **Frostpunk**

Le meilleur repoussoir disponible, et il est excellent pour ça — parce qu'il fait bien ce qu'on refuse de faire.

Frostpunk pose de vrais arbitrages, les rend coûteux, et **ne laisse aucune sortie honorable** : la ville survit, on regarde ce qu'on a accepté pour ça, et l'épilogue demande si ça en valait la peine. C'est *dur*, et c'est *cynique*. La règle mère de ce projet garde la première moitié et jette la seconde.

| Frostpunk | Ici |
|---|---|
| L'arbitrage est un piège moral — chaque branche coûte quelque chose d'humain | L'arbitrage est **réel mais surmontable**. On peut faire mieux, pas seulement moins pire |
| La ville de départ est une catastrophe | La ville de départ est **ordinaire**, et plutôt jolie → [[Direction artistique]] |
| Le succès se paie en dignité | Le succès se paie en **gentrification, en gêne, en béton** — des coûts d'aménagement, pas une déchéance |
| On survit | On **transforme**, sur 20 ans, et il n'y a pas de game over → [[Déclin et défaite]] |

> À voler quand même : **son livre des lois**. Un arbre, un palier à la fois, et chaque loi adoptée **se voit dans la ville** — pas seulement dans un menu. C'est la mécanique de [[Décisions]] avec une génération d'avance sur le reste du genre.

## L'interface ne doit pas sentir la machine

S'applique à **tout texte affiché dans le jeu** : libellés, boutons, infobulles, titres de panneaux, noms de décisions, textes d'événements. *Ne s'applique pas à ce vault*, qui est un document de travail et écrit comme tel.

Le test : **si un joueur peut deviner que le libellé a été pondu par une IA, il est faux.** Deuxième test, plus utile : si on peut coller le libellé tel quel dans n'importe quel autre city-builder, il ne dit rien.

| Le tic | Pourquoi c'est un aveu | Ce qu'on écrit |
|---|---|---|
| `TOUT EN MAJUSCULES` sur un bouton ou un onglet | Personne n'écrit comme ça. C'est un cache-misère de mise en page | Capitale initiale seule : `Décisions`, `Passer l'année` |
| Le tiret cadratin `—` dans un libellé | Ponctuation anglo-saxonne, jamais tapée spontanément en français | Deux-points, virgule, ou deux phrases |
| Emoji décoratif dans un bouton (🚀 ✨ 📊) | Signature de gabarit | Rien, ou une icône dessinée qui fait partie de la DA |
| Le triptyque titre + sous-titre explicatif + bouton, partout | Chaque panneau finit identique | Un seul niveau. Si le sous-titre est nécessaire, le titre est mauvais |
| Point d'exclamation de félicitation (`Terminé !`, `Bravo !`) | Ton d'application, pas de jeu. Et c'est cynique à l'envers : ça félicite pour rien | L'état, sec : `Chantier livré` |
| Verbes d'agence (`optimisez`, `découvrez`, `gérez votre ville`) | Vocabulaire de page de vente | Un verbe concret à l'infinitif : `Élargir le trottoir` |
| Les listes de trois éléments parallèles | Rythme de machine | Deux, ou quatre, ou une phrase |
| Ponctuation française bâclée | Espace insécable avant `: ; ! ?`, guillemets `« »`. Son absence se voit | On la respecte, y compris dans les chaînes de code |

Deux règles de format qui découlent du reste :

- **Un libellé de bouton = un à trois mots**, verbe à l'infinitif quand c'est une action.
- **Aucun texte ne dit ce que l'écran montre déjà.** C'est la même règle que « cible ~10 000 mots » vue depuis l'UI. → [[Direction artistique]]

## Ce que le jeu doit dire explicitement

La prévention réussie est invisible. Il faut donc la rendre bruyante :

> « La crue de 2031 aurait coûté 4 M€ il y a six ans. »

Sans cette phrase, la meilleure mécanique du jeu est muette. → [[Happenings]]

**Voir aussi** : [[Vision et prémisses]] · [[Direction artistique]]
