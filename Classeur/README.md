# Classeur — le système de décisions

> Semaine 2 du mois 1. → `Vault - Jeu urbanisme/Production/Plan 3 mois.md`
> Le design est dans le vault (`Systèmes/Décisions.md`, `Systèmes/Happenings.md`), ce dossier ne fait que le **chiffrer**.
> Les valeurs de `decisions.csv` et `effets.csv` sont une **première proposition de Claude, à corriger**. Rien n'y a été validé.

---

## 1. Les sept feuilles

| Feuille | Lignes | Qui l'écrit | Ça change quand ? |
|---|---|---|---|
| `ilots.csv` | 69 | 🔁 dérivé du `.gpkg` | quand la carte change |
| `routes.csv` | 178 | 🔁 dérivé du `.gpkg` | quand la carte change |
| `adjacences.csv` | 179 | 🔁 dérivé du `.gpkg` | quand la carte change |
| **`decisions.csv`** | **11** | ✍️ **toi — c'est tout le design** | quand tu changes d'avis |
| **`effets.csv`** | **37** | ✍️ **toi** | idem |
| `chantiers.csv` | grandit | ✍️ toi, **en jouant** | à chaque décision prise |
| `partie.csv` | 60 | 🧮 calculée | toute seule |

Les trois dérivées se regénèrent, elles ne s'éditent **jamais** à la main :

```bash
python3 QGIS/scripts/05_exporter_classeur.py
```

Séparateur **`;`** partout (Excel FR/DE l'ouvre au double-clic, sans assistant d'import). Encodage UTF-8, fins de ligne LF. **Ne pas enregistrer en `.xlsx`** : c'est un binaire, il ne se fusionne pas entre les deux machines — le piège du `.gpkg`. → `CLAUDE.md` §5 bis

## 2. Les unités

- **`pts`** — le budget d'investissement de Wehrau vaut **100 pts par an**, soit 8,3 pts par mois, 500 pts sur les 60 mois. Ça évite de trancher « d'où vient l'argent » (question ouverte 🟠) tout en gardant des coûts comparables.
- **`capital`** — un seul chiffre, de 0 à 100, qui part à 50. → `Décisions arrêtées` 16b
- Positif = **gagné**, négatif = **dépensé**. `D04` rapporte du capital, `D06` en brûle.

## 3. Comment une ligne de `decisions.csv` devient un coût

Le coût n'est jamais écrit : il se **calcule à partir de la carte**.

```
quantite   = SOMME(unite) sur les lignes de <couche> qui vérifient <cible>
cout_pts   = cout_base_pts   + cout_unitaire_pts * quantite
capital    = capital_base    + capital_unitaire  * quantite
```

C'est toute la différence avec un arbre de décision : la même ligne coûte 42 pts ou 115 pts selon un seuil, et tu le vois en changeant une cellule.

**D07 — planter tout tronçon dont l'emprise libre dépasse S** (chiffres réels, `routes.csv`) :

| S | tronçons | mètres linéaires | coût | le cœur ancien ? |
|---|---|---|---|---|
| 9 m | 15 | 969 | 21 pts | jamais |
| 8 m | 21 | 2 147 | 42 pts | jamais |
| 7 m | 53 | 5 025 | 93 pts | jamais |
| **6 m** | **64** | **6 217** | **115 pts** | jamais |
| 5 m | 83 | 7 270 | 134 pts | jamais |

Deux mètres de moins entre 8 et 6, le coût triple. Et les ruelles ne sont **jamais** concernées : leur emprise libre plafonne à 1,2 m. Tu ne l'as pas décidé — la carte le dit.

Même mécanique sur les postures, avec le seuil d'aléa `A` sur la rive gauche :

| A | rendus à l'eau (D03) | logements perdus | reconstruits (D01) |
|---|---|---|---|
| 0.85 | 4 îlots | 68 | 8 îlots |
| **0.80** | **6 îlots** | **201** | **6 îlots** |
| 0.70 | 9 îlots | 291 | 3 îlots |
| 0.55 | 11 îlots | 400 | 1 îlot |

(D03 ramasse aussi la friche et les deux champs, qui n'ont pas de logements. C'est voulu : le lit de crue a besoin d'eux.)

## 4. Comment un effet arrive — la rampe

Un chantier commencé au mois `d`, avec un délai `L` et une montée en charge `M` :

```
avancement(t) = 0                        si t < d + L
              = (t - d - L) / M          si d + L <= t < d + L + M
              = 1                        au-delà
```

et pour chaque ligne de `effets.csv` :

```
valeur(t) = valeur_t0 + effet * avancement(t)
```

**Le budget se paie étalé** sur `L + M` mois. **Le capital politique se paie en entier au mois `d`.** C'est ça, la structure du jeu : on encaisse le coût politique tout de suite et on récolte huit ans plus tard. Si cette asymétrie disparaît du classeur, il n'y a plus de jeu — il n'y a qu'une liste de courses. → `Systèmes/Chantiers et temps.md`

## 5. La colonne `portee` de `effets.csv`

Une décision ne touche pas que sa cible. C'est ce qu'un arbre ne peut pas dessiner.

| `portee` | Sur quoi | À quoi ça sert |
|---|---|---|
| `cible` | les objets qui vérifient `cible` | l'effet direct |
| `voisins` | leurs voisins par `adjacences.csv`, pondérés par `permeabilite` | le report de charge, l'ombre qui déborde |
| `aval` | les îlots dont `position_fil_eau` est supérieur | **la digue qui protège ici et aggrave là** |
| `ville` | une colonne de `partie.csv` | la dette de relogement |

`=quantite` dans la colonne `valeur` veut dire « autant que la quantité calculée en §3 » — `D03` verse ses 201 logements dans `logements_a_reloger`, et `D09` est la seule ligne qui les reprend.

## 6. Ce qui est faux exprès, et ce qui attend une décision

- **Les valeurs sont posées, pas calibrées.** `Plan 3 mois` le demande : chercher la forme, pas les valeurs. Ne pas équilibrer avant d'avoir joué.
- **11 décisions, pas 10.** La onzième est `D00 Indemniser et attendre` — le « ne rien transformer » de ton arbre, qui est la mécanique même des happenings. Si tu veux revenir à 10, la candidate au retrait est `D10` (rénovation thermique) : c'est la seule hors sujet par rapport à la crue, mais c'est aussi la seule qui couvre le thème `energie` et la seule boucle de gentrification.
- **`confort_ete` n'existe pas** dans le `.gpkg` (dernière ligne d'`effets.csv`). Soit on l'ajoute à `04_deriver_attributs.py`, soit `D10` s'exprime autrement.
- **`D04` cible les 21 tronçons de rive d'un coup.** Une digue devrait se poser par tronçon choisi — donc `parametre` devrait devenir une liste de `fid`. Laissé grossier volontairement : à trancher en jouant.
- **`partie.csv` n'est pas calculée.** Les 60 lignes existent, l'état du mois 0 est réel, le reste est vide. C'est la boucle des §4 — celle que tu retraduiras en Godot au mois 2, et que `Technique/Moteur et architecture.md` réserve à ta main. Dis un mot si tu veux que je l'écrive quand même.

## 7. La boucle de travail

1. `python3 QGIS/scripts/05_exporter_classeur.py` si la carte a bougé
2. ouvrir `decisions.csv`, changer un délai ou un seuil
3. relancer les 60 mois
4. regarder le mois 34, quand tombe la seconde crue

Le critère de la semaine 4 est le **ratio hésitation / ennui**, pas la justesse des chiffres.
