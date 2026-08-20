# Classeur — le système de décisions

Le design est dans le vault (`Systèmes/Décisions.md`, `Systèmes/Happenings.md`) ; ce dossier ne fait que le **chiffrer**. Les valeurs de `decisions.csv` et `effets.csv` sont une proposition à corriger — rien n'y a été validé.

🔴 **Aucun chiffre mesuré dans ce fichier.** `08_jouer.py --toutes` les rejoue tous, et `parties.html` les montre. Ce qui reste en attente est dans `Prototype/00 - Prototype.md`.

## Les sept feuilles

| Feuille | Qui l'écrit | Ça change quand ? |
|---|---|---|
| `ilots.csv` · `routes.csv` · `adjacences.csv` | 🔁 dérivées du `.gpkg` | quand la carte change |
| **`decisions.csv`** | ✍️ **l'auteur — c'est tout le design** | quand il change d'avis |
| **`effets.csv`** | ✍️ **l'auteur** | idem |
| `chantiers.csv` | ✍️ l'auteur, **en jouant** | à chaque décision prise |
| `partie.csv` | 🧮 calculée par `08_jouer.py` | toute seule |

Les trois dérivées ne s'éditent **jamais** à la main :

```bash
python QGIS/scripts/05_exporter_classeur.py
```

Séparateur **`;`** partout (Excel FR/DE l'ouvre au double-clic), UTF-8, fins de ligne LF. 🔴 **Ne pas enregistrer en `.xlsx`** : c'est un binaire, il ne se fusionne pas entre les deux machines — le piège du `.gpkg`.

## Les unités

- **`pts`** — le budget d'investissement, en points par an. Ça évite de trancher « d'où vient l'argent » tout en gardant des coûts comparables.
- **`capital`** — un seul chiffre, de 0 à 100, qui part à 50 (16b).
- Positif = **gagné**, négatif = **dépensé**.

## Comment une ligne devient un coût

Le coût n'est jamais écrit : il se **calcule à partir de la carte**.

```
quantite   = SOMME(unite) sur les lignes de <couche> qui vérifient <cible>
cout_pts   = cout_base_pts + cout_unitaire_pts * quantite
capital    = capital_base  + capital_unitaire  * quantite
```

C'est toute la différence avec un arbre de décision : **la même ligne coûte du simple au triple selon un seuil, et ça se voit en changeant une cellule.** Deux mètres de seuil sur l'emprise libre décident si une décision existe ou pas — l'auteur ne l'a pas décidé, la carte le dit.

## Comment un effet arrive — la rampe

Un chantier commencé au mois `d`, avec un délai `L` et une montée en charge `M` :

```
avancement(t) = 0                    si t < d + L
              = (t - d - L) / M      pendant la montée
              = 1                    au-delà

valeur(t) = valeur_t0 + effet * avancement(t)
```

🔴 **Le budget se paie étalé sur `L + M` mois ; le capital politique se paie en entier au mois `d`.** C'est ça, la structure du jeu : on encaisse le coût politique tout de suite et on récolte des années plus tard. Si cette asymétrie disparaît du classeur, il n'y a plus de jeu — il n'y a qu'une liste de courses.

## La colonne `portee`

Une décision ne touche pas que sa cible — c'est ce qu'un arbre ne peut pas dessiner.

| `portee` | Sur quoi | À quoi ça sert |
|---|---|---|
| `cible` | les objets qui vérifient `cible` | l'effet direct |
| `voisins` | leurs voisins, pondérés par `permeabilite` | le report de charge, l'ombre qui déborde |
| `aval` | les îlots dont `position_fil_eau` est supérieur | **la digue qui protège ici et aggrave là** |
| `ville` | une colonne de `partie.csv` | la dette de relogement |

`=quantite` dans la colonne `valeur` veut dire « autant que la quantité calculée ci-dessus ».

## Faux exprès

**Les valeurs sont posées, pas calibrées.** Le plan le demande : chercher la forme, pas les valeurs. **Ne pas équilibrer avant d'avoir joué.** Le critère n'est pas la justesse des chiffres, c'est le **ratio hésitation / ennui**.

## La boucle de travail

1. `python QGIS/scripts/05_exporter_classeur.py` si la carte a bougé
2. ouvrir `decisions.csv`, changer un délai ou un seuil
3. `python QGIS/scripts/08_jouer.py --toutes`
4. ouvrir `QGIS/rendus/parties.html` et pousser le curseur

Une partie est un fichier de `parties/` : trois colonnes, `mois_debut;decision_id;parametre`. Le résultat s'écrit à côté en `_resultat.csv`, et les parties se superposent dans la page.
