---
tags: [technique, DA, réversible]
statut: direction claire, décision réversible
---

# Direction artistique

> ⚠️ **Décision réversible.** Peut attendre. Ne pas y consacrer du temps avant le vertical slice.

## La direction retenue

**Low-poly flat-shaded 3D**, référence visuelle : **Mini Motorways**.

Combiné à un **système de calques** : la ville se voit en 3D complète, ou filtrée pour n'afficher qu'une couche de données. → [[Diagnostic et calques]]

## Pourquoi ça marche pour ce projet

- **Paramétrique** — indispensable pour le « avant / après »
- Empreintes extrudées procéduralement, **zéro asset modélisé à la main**
- Le basculement monde ↔ plan est une **proposition narrative**, pas juste une limite technique

## D'où vient la qualité perçue

Pas de la complexité artistique, mais de :

1. **Une palette disciplinée** — 8–10 couleurs maximum, dérivées des conventions de zonage réelles
2. **Une typographie forte** — Inter ou IBM Plex Sans
3. **Une épaisseur de trait constante**
4. **Des micro-animations**

## ❌ Pixel art — écarté

- Pas paramétrique
- Impose une grille et une caméra fixe
- **Double le travail d'assets** à cause du avant/après
- C'est un métier de spécialiste (⚠️ *Terra Nil* en référence d'avertissement)

**Alternative si on veut la chaleur du pixel** : un shader basse résolution à palette limitée par-dessus du low-poly 3D.

## Piste alternative gardée en réserve

**L'esthétique de la maquette d'architecte** : carton, bois, ombres douces, léger tilt-shift. Distinctive, pas chère, et capable de rendre **désirable une ville de départ ordinaire** — ce qui est un vrai problème du projet.

## Autres directions explorées et écartées

Rendu axonométrique collage · risographie · plan cadastral animé

## Clichés interdits

Voir [[Ton et règles d'écriture]] — pas de Ghibli, pas de tours-forêts, pas de golden hour permanente.

**Voir aussi** : [[Génération procédurale]] · [[Périmètre et coupes]]
