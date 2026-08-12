# CHANTIERS.md — ce qui est connu, pas encore fait

> Sorti de [ETAT.md](ETAT.md) le 2026-08-12. `ETAT.md` dit **où on en est et quoi faire maintenant** ; ici on garde **tout ce qui attend**, avec sa raison d'attendre.
> Rien ici n'empêche de jouer ni d'avancer. Ce qui bloque vraiment est dans `ETAT.md`.
> Trois familles : les **défauts visibles** de la ville · la **dette** des formules et des seuils · le **matériel de level design** à regarder à l'œil.

---

## 1. Les défauts visibles de la ville

Ils ne sont pas cachés : `07_exporter_godot.py` les imprime à chaque export. Aucun n'empêche de jouer.

| | Le défaut | Ce qu'on voit |
|---|---|---|
| 1 | ⚠️ **17 bâtiments sur 702 mordent sur la rue**, jusqu'à 5,5 m | pic de mitre sur angle rentrant, borné par le recul du tissu. Sans commune mesure avec les 258 m de la session 9, mais **un bâtiment sur la chaussée ment** |
| 2 | 🟠 **434 bâtiments sur 702 prennent un toit plat faute d'empreinte** | dont **381 pour pli des pans**, 50 concaves, 3 sans profondeur. Ce n'est plus un défaut mais un **réglage** : `GAUCHISSEMENT_MAX` en haut de `07`, à trancher devant l'image → `Godot/README.md` |
| 3 | ☐ **194 pans de toit (4 %) sont réorientés à l'émission** | c'était 794. ⚠️ conséquence inchangée : la colonne « toits dehors » du contrôle est vraie **par construction** et ne prouve plus rien. Le chiffre qui informe est celui des réorientations |
| 4 | ✅ ~~**La vallée ne se lit à aucune des quatre exagérations**~~ | **réglé en supprimant la vallée** le 2026-08-12 : la carte est plate, les touches `1..4` sont retirées |
| 5 | ☐ **Le trafic, le sol, la lumière** | inchangés depuis la session 9 |
| 6 | ☐ **Le fond du chenal ne se voit jamais** | l'eau est opaque, donc des deux mètres du chenal on n'en voit qu'**un** — le mur au-dessus de la nappe. Le fond à −2 m coûte 43 triangles et sert d'assurance, pas d'image |

## 2. Les quatre tables de level design

Ce sont **elles, et pas le code**, qui décident de ce qu'on voit. Une ligne changée, on relance, on regarde.
Le contrôle n'est pas « est-ce juste » mais ***« est-ce qu'on croirait y habiter »***.

| La table | Où | Ce qu'elle décide |
|---|---|---|
| les listes de `fid` | haut de `02_qualifier.py` | quel îlot est quoi — dont **`PONTS_SUPPRIMES`** désormais |
| `TISSU` | `04_deriver_attributs.py` | densité, hauteur, imperméabilisation, canopée, fragilité, parking — **le comportement de la carte** |
| `TISSU` | `04c_parcelles.py` | largeur de façade et profondeur visées — **le grain de toute la ville** |
| `BATI` | `07_exporter_godot.py` | recul de rue, jeu au voisin, profondeur bâtie, pente du toit |

🆕 **Un cinquième réglage, qui n'est pas une table mais un seuil** : `GAUCHISSEMENT_MAX` en haut de `07` — le pli qu'un pan de toit a le droit d'avoir avant qu'on lui préfère un toit plat. 0,35 m aujourd'hui, soit 250 toits à deux pentes ; 1,20 m en donnerait ~460, mais qui se plient.

🔴 Dans `BATI`, le `jeu` à 0 fait le mitoyen, et il n'est **réversible que dans un sens** (décision 61).

## 3. La dette — formules, seuils, définitions

Aucune n'est sur le chemin critique du prototype énergie, mais chacune ment tant qu'elle n'est pas payée.

- [ ] 🔴 **Calibrer les deux formules de budget** — recettes ∝ `logements`, charges ∝ mètres de voirie (décision 59). Le contrôle est nommé : *une stratégie de densification pure ne doit pas s'autofinancer*, sinon le piège de l'exponentielle est rouvert pour de bon. C'est aussi ce qui doit faire **mordre** un budget qui ne mord jamais (418 pts sur 500, +152 de solde, aucune décision refusée sur trois parties).
- [ ] 🔴 **Repondérer les trois moyennes** — `canopee_moy` et `impermeabilise_moy` par la **surface**, `riverain_moy` par la **population** (ce qui supprime au passage le cas particulier « îlots habités seulement »). À faire dans `08_jouer.py` **et** dans `ville.gd`, puis refaire le contrôle de recoupement. Les chiffres du classeur bougeront. → `Décisions arrêtées` **63**
- [ ] 🔴 **`largeur_m >= 20`, la cible de D05, rate quatre des cinq rues les plus chargées.** Les tronçons 13, 21, 54 et 55 font **18 m** et portent 0,87 à 1,00 de charge. « Retirer la voiture de l'axe de transit » n'attrape que le tronçon 11. **Deux mètres de seuil décident si la décision existe.**
- [ ] 🔴 **La montée de D07 est de 60 mois** : sur l'horizon d'une partie, l'arbre ne reprend jamais ses mètres à la noue. La concurrence arbre/noue, qui est le sujet de D07 et D08, ne se joue pas.
- [ ] **`stationnement` porte deux sens** — part de surface sur l'îlot, places sur rue sur le tronçon — et « l'emprise voiture » agrège déjà les deux (4 587 places **et** 17,6 % de voirie). **À renommer avant d'écrire la formule de l'indicateur**, sinon quelque chose les additionnera.
- [ ] **Vérifier que chaque indicateur a un antagoniste.** Ceux qui n'en ont pas sont mal conçus — les bornes sont la ceinture, le frein ce sont les antagonismes.
- [ ] **Trois valeurs à t0 manquent** : la ville exposée, le CO2, la desserte. Calculables sur les attributs existants, côté Windows.
- [ ] **`confort_ete` n'existe pas dans le `.gpkg`** et c'est la seule variable de D10, seule décision du thème `energie`. `08_jouer.py` la crée à 0 et le signale ; Godot y répond par la **surchauffe**, dérivée du sol. Soit on la dérive dans `04`, soit D10 s'exprime autrement.
- [ ] **Trois chiffres attendent l'œil de l'auteur**, tous commentés dans le code et listés dans `Godot/README.md` : la **surchauffe** (`3,5 × imperméabilisé − 2,5 × canopée`, +1,59 °C à t0), le **+0,25 de canopée** de D07 (alors que la canopée d'une rue plafonne à 0,18 dans les données), et **`CANOPEE_ALIGNEMENT_MAX`** (rendu seulement). ⏸️ En sommeil : D07 est archivée (66).
- [ ] **La deuxième décision dans Godot.** La candidate est **D06 supprimer le stationnement** : c'est elle qui libère l'emprise de D07 et D08, donc c'est elle qui rend la chaîne intéressante. Il ne manque qu'une entrée dans `DECISIONS` de `chantiers.gd` et une portée `voisins` pour le report de charge.
- [ ] **Les réparations de boucle de `04b`** — passées de 4 à **7 îlots** avec la carte à trois ponts. Les quatre signalées « à regarder » sont les mêmes qu'avant (**55, 13, 16, 21** — deux cœurs anciens, deux fronts commerçants ; le 16 tombe de 2 132 à 560 m²). Les trois neuves (9, 11, 62) ne sont pas signalées.

## 4. Le classeur — à retrancher ou à entretenir

⚠️ **Le rôle du classeur est à trancher.** Il n'a jamais été étendu à l'énergie, et le recoupement des deux moteurs est suspendu (`PLAN_energie.md` §9 c) depuis que D07 est archivée. Banc d'essai des seuils, ou archive ? **Un deuxième moteur à moitié entretenu ment sans qu'on le sache.**

🔴 Rappel de ce que la coupe a coûté : le **contrôle de recoupement** entre Godot et `08_jouer.py` a disparu avec D07. Il avait déjà attrapé un vrai bug (le décalage d'un mois du budget). Une formule fausse dans le noyau ne sera plus attrapée par personne avant qu'on la voie à l'écran.

## 5. Sans urgence

- [ ] **Digérer le brainstorm importé du 2026-08-11** (refs / positionnement / UI) — 9 décisions et 7 questions à remonter.
- [ ] **Le tag `jeu/brightvale`** du brainstorm importé — nom de travail abandonné, autre projet, ou candidat à verser dans `Marketing et Steam` ?
- [ ] **Les conséquences de 5 350 habitants** sur trois équipements : le lycée devient une Realschule, la galerie de 1971 un supermarché, la barre de 1974 un petit Neubau. Acté dans la décision 13d, pas encore écrit dans `Ville/Wehrau.md`.
- [ ] **Les six dérives connues du dossier QGIS** → `QGIS/README.md` §8. Aucune bloquante.

---

**Voir aussi** : [ETAT.md](ETAT.md) · [HISTORIQUE.md](HISTORIQUE.md) · [PLAN_energie.md](PLAN_energie.md) · `QGIS/README.md` · `Godot/README.md`
