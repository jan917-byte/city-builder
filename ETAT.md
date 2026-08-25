# ETAT.md — où on en est

> **Signet, pas source.** Design → le vault · carte → `QGIS/data/source/` · détail de l'étape → sa note · ce qui s'est passé → [HISTORIQUE.md](HISTORIQUE.md).
> **Plafond : ~40 lignes.** Ce qui ne tient pas ici tient ailleurs.

**2026-08-25 (session 61).** Étape ouverte : **5 — [Le trafic visible](Prototype/Trafic.md)**, critère *une rue à `charge = 1,00` est désagréable à regarder*. L'étape 4 est en pause. La décision 12 est précisée : **la fiche prévisualise le futur d'un îlot ou d'un tronçon ; la ville attend la livraison du chantier**. → [Chantiers et temps](Vault%20-%20Jeu%20urbanisme/Systèmes/Chantiers%20et%20temps.md)
La maquette a maintenant **deux vues** : la ville vivante, et un **diagnostic en maquette blanche** dont on choisit le thème **au menu** — dangers, chantiers, énergie, trafic, tissu. Les quatre touches `C` `D` `H` `X` sont supprimées, un thème neuf coûte une ligne, et le thème **énergie** existe enfin. **Écrit sur un Mac sans Godot : ni compilé, ni vu.** → [Trafic](Prototype/Trafic.md) § Les deux vues

## Prochaine action — juger le trafic à l'écran

```bash
python QGIS/scripts/chaine.py --godot
```

**D'abord la passe rendue**, sur la machine qui a Godot : `Godot_console.exe --path Godot -- --essai`. Elle échoue au premier manque, et sort les images.
Puis juger, dans cet ordre : ① le **critère de l'étape 5**, sans thème — `wehrau_essai_axe.png` → `..._axe_ferme.png`, `..._rue_calme.png` → `..._stationnement_retire.png` ; ② les **deux vues**, sept captures au même cadrage, la liste et les défauts qui les trahiraient sont dans la note. → [Trafic](Prototype/Trafic.md)

## Ce qui attend l'auteur

- 🔴 **La barre ne fait pas la hauteur décidée** : 6 niveaux arrêtés le 2026-08-19, **5 à l'écran** — le ±1 niveau de `04c` a tiré −1 sur ses trois parcelles, et 13,5 m est exactement la hauteur refusée ce jour-là, celle qui passe sous les faîtages du cœur ancien. `04c` l'affiche désormais à chaque passage. Le critère « une barre de 9 niveaux » (`Plan 3 mois.md:48`) reste périmé par la même occasion.
- 🔴 **L'asphalte des quais prend 6 m à l'Ilse** — plus un défaut visible, mais un **choix de carte** : une Ilse plus large veut dire reculer le **tracé** des voies de berge.
- 🔴 **Le potentiel solaire réel est bas** — 11,0 ha de toiture réelle pour les 25–40 % annoncés au plan. **L'assumer, ou regonfler la colonne `equip`** de la table.
- 🔴 **Six arbitrages de rendu ne sont consignés nulle part** — les cinq du 2026-08-18, plus **« deux vues »**, pris et appliqué le 2026-08-25 : la couleur suit l'époque et non la typologie · le calque « tissu » est la contrepartie · zéro asset · l'étape 4 s'ouvre et la 2 passe en pause · et la DA dit **encore** « un `sous_type` = une teinte », faux depuis. À ouvrir puis fermer dans `Questions ouvertes.md` **et** `Décisions arrêtées.md`.
- 🟠 **Découper `07_exporter_godot.py`** — 5 500 lignes, 110 fonctions, un `main()` de 944 l., **79 000 tokens** : plus lourd que tous les markdown du dépôt réunis, et il faut le charger pour toucher à l'étape 4. Cinq fichiers par thème, contrôle nommé : **l'export doit sortir identique**. C'est du code, donc délégué (40b).
- 🟠 **Les deux nombres de la percée sont du level design** — l'îlot compact n'est plus un anneau fermé : `04d` interrompt son mur mitoyen tous les **60 m** par une ouverture de **9 m**. Îlot 49 : mur le plus long 85 → 61 m, cinq percées, 80 % du tour bâti. À juger sur `--ilots 49` ; `04d` imprime « mur d'un seul tenant ».
- 🟠 **Les quatre nombres de l'économie sont du level design** : 260 €/m², 150 €/MWh, 800 k€ de caisse, 30 k€/mois. Ce sont eux qui décident si le jeu est *dur mais possible*.
- 🟠 **Le nom des quartiers de Wehrau** — sans lui, « investir dans le Ried avant la rive gauche » n'existe pas comme phrase.
- 🔴 **La crue est reprise sur la branche `crue`** → [Crue](Prototype/Crue.md). Deux jauges rendent **adaptation → réduction** visible ; toute décision solaire disparaît pendant l'urgence et le noyau la refuse. Le seuil prototype est logements relevés + ponts rétablis, mais leurs prix actuels le rendent inaccessible en vingt ans : seuil et prix restent du level design (72 · question 23).
- 🟠 **Le rôle du classeur** : banc d'essai des seuils, ou archive ? Il n'a jamais été étendu à l'énergie, et le recoupement des deux moteurs est suspendu. **Un deuxième moteur à moitié entretenu ment sans qu'on le sache.**
- ⏸️ **L'étape 2 est en pause**, pas finie : 118 parcelles de rue sur 809 ont un sommet rentrant, et c'est **le peigne de `04c`**. **Ne pas la rouvrir tant que la 4 est ouverte.** → [Parcelles](Prototype/Parcelles.md) § 7

## Les commandes du quotidien

```
python QGIS/scripts/chaine.py                → LA commande : la carte et les bâtiments
python QGIS/scripts/chaine.py --godot        → … et alimenter la maquette 3D
python QGIS/scripts/apercu_parcelles.py      → le parcellaire en PNG, numéroté
python QGIS/scripts/08_jouer.py --toutes     → rejouer les parties du classeur
```

Le détail des scripts et leurs pièges → `QGIS/README.md` · l'organisation des données → `QGIS/data/LISEZ-MOI.md` · la maquette et ses touches → `Godot/README.md`.
