---
tags: [système, ui, da]
statut: arrêté
maj: 2026-10-12
---

# Diagnostic et calques

## Le rôle stratégique

**Le diagnostic est l'activité principale entre deux décisions.** C'est ce qui résout le risque de spectateur en temps continu : pendant que ça se construit, le joueur lit ses cartes thermiques, repère un effet de bord, prépare l'intervention suivante. **L'attente devient de l'observation.**

Cadeau caché : ces vues thématiques sont **belles**, elles sont mon métier, et elles règlent en partie le problème de style graphique. Une ville qui bascule en carte de chaleur, c'est un moment visuel fort et pas cher.

## Les calques se rangent sous les thèmes

🔄 **Depuis le 2026-09-29, les calques suivent les six thèmes** (91) — il n'y a plus trois calques parents (25, retirée). Chaque thème ouvre ses cartes, et le bandeau devient le sommaire du diagnostic.

| Le thème | Ses calques, dans la maquette ou à venir |
|---|---|
| 🏭 CO₂ | trafic · chauffage · carbone gris |
| ⚡ Énergie | potentiel solaire · production · consommation |
| 🚗 Mobilité | charge du trafic · rues coupées · stationnement · desserte |
| 🌾 Agriculture | champs et cultures · ce qu'ils nourrissent |
| 🦋 Biodiversité | berges · toits verts · arbres · haies et bois |
| 🌊 Dangers naturels | **prochaine crue** (eau attendue îlot par îlot) · **dégâts** · sols (ce qui boit l'eau) · surchauffe |
| 🏠 Habitants | relogement · logements · habitants d'origine |

## 🎯 Chaque calque est apparié à un chiffre — arrêté le 2026-08-12

> **Aucun chiffre global sans son calque.** Le chiffre dit *que* ça bouge, le calque dit *où*.

Sans cet appariement, un chiffre global est une **moyenne**, et une moyenne efface l'injustice géographique — planter au cœur ancien ou au Ried donnerait le même écart à l'écran. C'est aussi ce qui empêche le bandeau de devenir un tableau de bord qu'on optimise. → [[Décisions arrêtées]] 53 · [[Pièges connus]]

### 🔗 Un calque n'illustre pas un indicateur, il **est** l'indicateur

Arrêté le 2026-08-12. Le calque, c'est la **valeur locale** du même indicateur, coloriée sur la carte ; la fiche d'un îlot, c'est cette valeur lue sur un seul objet ; le bandeau, c'est la même chose remontée à la ville. Trois vues, un seul nombre.

Deux conséquences ici :
- **La fiche reprend l'ordre et les icônes du bandeau** — un seul vocabulaire, et l'écart à t0 se lit aux deux échelles → [[Décisions arrêtées]] 63b
- **Comment ça remonte n'est pas au choix** : les stocks s'additionnent, les taux se pondèrent par la surface, la population ou les mètres de voirie selon ce dont ils sont le taux → [[Indicateurs globaux]] · [[Décisions arrêtées]] 63

## Hiérarchie de lecture

1. **Les cartes thématiques font le travail de diagnostic primaire** (heat maps)
2. **Le clic sur un îlot ou un bâtiment** devient une vérification, une curiosité, une histoire — **pas la mécanique obligatoire de collecte d'info**

Cette hiérarchie est importante : elle évite le jeu où il faut cliquer 40 bâtiments pour comprendre quelque chose.

## Le mode « plan »

La ville peut être vue en 3D complète, ou filtrée pour ne montrer qu'une couche de données. Basculer entre monde et plan est aussi une **proposition narrative**, pas seulement une limite technique. → [[Direction artistique]]

**Voir aussi** : [[Indicateurs globaux]] · [[Boucle de jeu]] · [[Géométrie et données]]
