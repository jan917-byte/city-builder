---
tags: [production, périmètre]
statut: tranché pour le prototype
maj: 2026-08-10
---

# Périmètre et coupes

## 🔄 Révisé le 2026-08-10 — le prototype est une petite ville entière

**Le prototype n'est plus un quartier de [[Vallmar]], c'est [[Wehrau]]** : une petite ville de ~5 350 habitants sur 0,93 km², qu'on voit **en entier**. → [[Questions ouvertes]] n°13

La coupe est la même en coût — une carte d'un kilomètre carré, 69 polygones — mais elle est **meilleure en rendement**, pour une raison qui n'avait pas été vue : une ville entière, même petite, a un **amont et un aval**. Un quartier n'en a pas.

⚠️ **Le jeu complet reste à l'échelle de Vallmar**, ville moyenne à six quartiers. La coupe porte sur le prototype, pas sur l'ambition. Ne pas laisser la décision glisser silencieusement de l'un à l'autre.

## ✅ Ce que Wehrau peut tester

- **La forme des décisions** — coût, délai, montée en charge, effet de bord → [[Décisions]]
- **L'arbitrage des deux ressources**, notamment face aux commerçants organisés → [[Ressources]]
- **La canicule** comme happening, sur un cœur ancien minéral → [[Happenings]]
- **Le profil en travers** : la ruelle trop étroite pour tout accueillir
- **La spécificité spatiale à l'échelle de l'îlot**
- 🆕 **L'injustice amont/aval** — la rivière traverse la ville ; le grand ensemble de 1974 et les friches sont en aval. Celui qui décide et celui qui prend l'eau sont dans le même écran
- 🆕 **La crue** comme happening à part entière, et « rendre à l'eau » comme réponse
- 🆕 **Le rapport ville/campagne** : les champs autour ne sont pas un décor, c'est la réserve d'expansion de crue
- **Le critère de réussite** : est-ce que j'hésite ?

## ❌ Toujours non testable

- **Le contraste de pouvoir entre quartiers** — [[Hochfeld]] qui vote contre. Wehrau est trop petite pour avoir des quartiers qui s'opposent
- **La question la plus lourde du jeu** : que faire de [[La Fonderie]]. Les deux friches de Wehrau en sont une version miniature, pas l'équivalent
- **Le pluralisme des fins** → [[Fins et pluralisme]]
- **Le changement d'échelle lui-même** : ce qui hésite dans une petite ville hésitera-t-il à 112 000 ?

**Conséquence à assumer** : le prototype valide la maille fine **et une partie de la thèse**. Il ne valide pas le passage à l'échelle. C'est un risque plus petit que celui qu'on avait avant.

## Liste des coupes restantes, par ordre de rendement

1. ~~Ville entière → un seul quartier~~ → **une petite ville entière** ✅ **fait**, et mieux que prévu
2. **Abandonner l'importateur OSM générique** → une seule ville en dur ✅ *acquis, la carte est générée*
3. **Caméra axonométrique fixe** au lieu d'une caméra libre → élimine le LOD et la question des façades
4. **Kit de ~15 volumes paramétriques** au lieu d'une grammaire procédurale ouverte
5. **Un seul axe de progression, 2–3 issues** → [[Fins et pluralisme]]
6. **Un seul événement climatique scripté** au lieu d'un système d'événements
7. **Externaliser / licencier** l'audio et les assets marketing

## 🚫 Les deux piliers non négociables

### 1. La lisibilité de la transformation
Parcelles persistantes, avant/après visible. → [[Génération procédurale]]

### 2. La spécificité spatiale
**La même décision ne doit pas produire le même résultat partout.** Dans [[Wehrau]], ce pilier se teste à deux échelles : **d'îlot à îlot** (cœur ancien contre pavillonnaire), et **d'amont à aval**. À ne pas oublier au moment d'écrire les 10 décisions.

## Ce qui peut attendre (réversible)

Style graphique · moteur · nom · modèle économique

**Voir aussi** : [[Décisions arrêtées]] · [[Wehrau]] · [[Plan 3 mois]]
