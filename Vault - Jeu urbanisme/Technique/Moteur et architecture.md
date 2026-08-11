---
tags: [technique, moteur]
statut: privilégié, pas verrouillé
maj: 2026-08-11 (la réserve sur le noyau est levée — 40b)
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

🔄 **Révision du 2026-08-11 : la réserve sur le noyau est levée.** L'ancienne règle — *« j'écris et je comprends le noyau de simulation moi-même »* — tombe. → [[Décisions arrêtées]] 40b

> **Claude écrit le code, noyau et architecture compris. Je teste, j'itère, je reviens sur ses décisions.**

Ce que l'ancienne règle protégeait n'était pas la frappe, c'était la **compréhension** : au mois 18, tenir les raisons d'un système qui se met à mal se comporter. Cette compréhension n'est plus produite par la construction. Elle devient une chose à aller chercher — en relisant, en cassant volontairement, en demandant pourquoi.

Le tableau ✅/❌ ci-dessus ne dit plus où est la frontière. Il dit **où regarder** : c'est sur l'architecture, la performance, le game feel et les API Godot que les erreurs se logeront. Et la ligne ❌ sur le GDScript reste la plus concrète — les fautes prendront la forme d'appels Godot 3 obsolètes qui compilent sans broncher, pas de plantages.

La contrepartie tenue depuis le départ : le noyau de génération de géométrie reste isolé derrière une interface propre (voir plus haut). Un module dont on peut changer l'intérieur sans tout casser est aussi un module dont on peut réécrire l'intérieur à la main si le besoin s'en fait sentir.

### L'effet réel sur le calendrier

Le code représente ~35 % du temps de dev total. Comprimer ça ne comprime ni l'itération, ni l'équilibrage, ni le feel. Un projet de 3–5 ans devient 2,5–3,5 ans — **pas une fraction**.

## Fichiers d'échange

- QGIS → **GeoJSON** → Godot (mois 2)
- `.qml` = référence couleur unique partagée

**Voir aussi** : [[Génération procédurale]] · [[Plan 3 mois]] · [[Calendrier et budget]]
