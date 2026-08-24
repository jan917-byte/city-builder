# ETAT.md — où on en est

> **Signet, pas source.** Design → le vault · carte → `QGIS/data/source/` · détail de l'étape → sa note · ce qui s'est passé → [HISTORIQUE.md](HISTORIQUE.md).
> **Plafond : ~40 lignes.** Ce qui ne tient pas ici tient ailleurs.

**2026-08-24 (session 59).** Étape ouverte : **5 — [Le trafic visible](Prototype/Trafic.md)**, critère *une rue à `charge = 1,00` est désagréable à regarder*. L'étape 4 est en pause.
Les 37 routes endommagées sont vides jusqu'à leur réparation ; retirer la voiture vide l'axe dès le clic puis reporte le flux en six mois. Le travail du Mac est fusionné : `04e` chiffre le **report de trafic** une fois pour toutes — la rue qui encaisse le plus ne prend que **+0,05**, l'argument de 23b — et la maquette gagne une **deuxième vue d'ensemble**, touche `X`, les chantiers. → [Crue](Prototype/Crue.md) § 6

## Prochaine action — juger le trafic à l'écran

```bash
python QGIS/scripts/chaine.py --godot
```

Regarder l'avant/après `wehrau_essai_axe.png` → `wehrau_essai_axe_ferme.png`, puis `wehrau_essai_rue_calme.png` → `wehrau_essai_stationnement_retire.png`, et enfin `wehrau_essai_pont_casse.png`. L'axe 55 doit se vider ; aucune voiture ne doit flotter sur le pont absent. `H` ne sert qu'au diagnostic. → [Trafic](Prototype/Trafic.md)
Puis lancer la maquette et ouvrir la **vue chantiers** (`X`) et le **diagnostic** (`D`) — les deux se ferment l'une l'autre. La vue `X` arrive du Mac : elle compile et la passe la capture, mais **elle n'a encore été jugée par personne**.

## Ce qui attend l'auteur

- 🔴 **La barre ne fait pas la hauteur décidée** : 6 niveaux arrêtés le 2026-08-19, **5 à l'écran** — le ±1 niveau de `04c` a tiré −1 sur ses trois parcelles, et 13,5 m est exactement la hauteur refusée ce jour-là, celle qui passe sous les faîtages du cœur ancien. `04c` l'affiche désormais à chaque passage. Le critère « une barre de 9 niveaux » (`Plan 3 mois.md:48`) reste périmé par la même occasion.
- 🔴 **L'asphalte des quais prend 6 m à l'Ilse** — plus un défaut visible, mais un **choix de carte** : une Ilse plus large veut dire reculer le **tracé** des voies de berge.
- 🔴 **Le potentiel solaire réel est bas** — 11,0 ha de toiture réelle pour les 25–40 % annoncés au plan. **L'assumer, ou regonfler la colonne `equip`** de la table.
- 🔴 **Cinq arbitrages de rendu du 2026-08-18 ne sont consignés nulle part** : la couleur suit l'époque et non la typologie · le calque « tissu » est la contrepartie · zéro asset · l'étape 4 s'ouvre et la 2 passe en pause · et la DA dit **encore** « un `sous_type` = une teinte », faux depuis. À fermer dans `Questions ouvertes.md` **et** `Décisions arrêtées.md`.
- 🟠 **Découper `07_exporter_godot.py`** — 5 500 lignes, 110 fonctions, un `main()` de 944 l., **79 000 tokens** : plus lourd que tous les markdown du dépôt réunis, et il faut le charger pour toucher à l'étape 4. Cinq fichiers par thème, contrôle nommé : **l'export doit sortir identique**. C'est du code, donc délégué (40b).
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
