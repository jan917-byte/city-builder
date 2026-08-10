---
tags: [technique, moteur]
statut: privilégié, pas verrouillé
---

# Moteur et architecture

## Godot 4 — recommandé

**Pourquoi ça colle :**
- La simulation est **agrégée**, pas à base d'agents → la génération de géométrie est **ponctuelle**, pas par frame
- Le jeu est **lourd en UI** (overlays, heat maps, indicateurs) → les nœuds `Control` de Godot sont solides là-dessus
- Solo, PC, open source

**Le caveat sérieux :**
> Les boucles géométriques lourdes en **GDScript vont goulotter**.

**Décision d'architecture à prendre dès le départ** : isoler le noyau de génération de géométrie derrière une **interface propre**, pour pouvoir le basculer en **C#** sans tout casser.

## Simulation agrégée

**Flux agrégés, pas simulation d'agents individuels.** Pour la performance et pour la cohérence.

Ce choix conditionne tout le reste : il rend Godot viable et la génération procédurale ponctuelle.

## Vibe coding — où ça marche et où ça ne marche pas

### ✅ Bien
UI · logique de simulation · pipelines de données · prototypes jetables

### ❌ Mal
Architecture · performance · game feel · **GDScript spécifiquement** (données d'entraînement plus faibles + pollution des API Godot 3 → 4, danger connu)

### La règle

> **J'écris et je comprends le noyau de simulation moi-même. Le reste est de l'échafaudage jetable.**

Prototyper librement en vibe coding, puis reconstruire le noyau **avec compréhension**.

### L'effet réel sur le calendrier

Le code représente ~35 % du temps de dev total. Comprimer ça ne comprime ni l'itération, ni l'équilibrage, ni le feel. Un projet de 3–5 ans devient 2,5–3,5 ans — **pas une fraction**.

## Fichiers d'échange

- QGIS → **GeoJSON** → Godot (mois 2)
- `.qml` = référence couleur unique partagée

**Voir aussi** : [[Génération procédurale]] · [[Plan 3 mois]] · [[Calendrier et budget]]
