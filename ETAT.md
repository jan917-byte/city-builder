# ETAT.md — où on en est

> **Signet, pas source.** Design → le vault · carte → `QGIS/data/source/` · détail de l'étape → sa note · ce qui s'est passé → [HISTORIQUE.md](HISTORIQUE.md).
> **Plafond : ~40 lignes.** Ce qui ne tient pas ici tient ailleurs.

**2026-08-19 (sessions 46 à 48, fusionnées).** Étape ouverte : **4 — [Les toits et le sol](Prototype/Toits%20et%20sol.md)**, critère *croire qu'on y habite*.
Deux machines en parallèle depuis le même point : ici les **fichiers de contexte** ont fondu et `CHANTIERS.md` a disparu ; là-bas **le sol a pris corps** — quai sur la berge, parapets arrêtés à l'eau, barres à 6 niveaux, **123 places** sur la place du marché → [Toits et sol](Prototype/Toits%20et%20sol.md) § 3 quater · quinquies · sexies. ⚠️ Le sol **n'a pas son entrée** dans [HISTORIQUE.md](HISTORIQUE.md), et la note d'étape **déborde : 154 l. pour 140** — signal que l'étape 4 approche de sa fin, pas qu'il faut relever le plafond.

## Prochaine action — juger l'échange à l'écran

```bash
python QGIS/scripts/chaine.py --godot
```

Puis lancer la maquette et regarder **la place-parking** d'abord (touche `M`), le **quai et les ponts** ensuite, **les façades** et **la rue** enfin. La grille de lecture — *ce qu'il faut voir* / *ce qui prouverait que c'est cassé* — et les réglages qui se changent en une ligne sont dans [Toits et sol](Prototype/Toits%20et%20sol.md) § 6 · § 7.
Puis le geste énergie : cliquer un cœur ancien puis la barre de 1974 et comparer « se rembourse en » (**31 ans contre 10**) ; sur l'îlot 31, la caisse refuse. → [Énergie](Prototype/Énergie.md)

## Ce qui attend l'auteur

- 🔴 **Le critère de réussite « une barre de 9 niveaux »** (`Plan 3 mois.md:48`) est périmé : la barre est descendue à **6** le 2026-08-19, et il y en a trois. Réécrire le critère, ou annuler la baisse.
- 🔴 **L'asphalte des quais prend 6 m à l'Ilse** — plus un défaut visible, mais un **choix de carte** : une Ilse plus large veut dire reculer le **tracé** des voies de berge.
- 🔴 **Le potentiel solaire réel est bas** — 11,0 ha de toiture réelle pour les 25–40 % annoncés au plan. **L'assumer, ou regonfler la colonne `equip`** de la table.
- 🔴 **Quatre arbitrages de rendu pris le 2026-08-18 ne sont consignés nulle part** : la couleur suit l'époque et non la typologie · le calque « tissu » est la contrepartie · zéro asset · l'étape 4 s'ouvre et la 2 passe en pause. À fermer dans `Questions ouvertes.md` **et** `Décisions arrêtées.md`.
- 🔴 **La DA dit encore « un `sous_type` = une teinte, rien à peindre jamais »** — faux depuis le 2026-08-18.
- 🟠 **Les quatre nombres de l'économie sont du level design** : 260 €/m², 150 €/MWh, 800 k€ de caisse, 30 k€/mois. Ce sont eux qui décident si le jeu est *dur mais possible*.
- 🟠 **Le nom des quartiers de Wehrau** — sans lui, « investir dans le Ried avant la rive gauche » n'existe pas comme phrase.
- 🟠 **La crue** — la décision **23b** (le jeu s'ouvre sur une crue rive gauche) contredit « pas de crue dans ce prototype ». Suspendue ou abandonnée ?
- 🟠 **Le rôle du classeur** : banc d'essai des seuils, ou archive ? Il n'a jamais été étendu à l'énergie, et le recoupement des deux moteurs est suspendu. **Un deuxième moteur à moitié entretenu ment sans qu'on le sache.**
- ⏸️ **L'étape 2 est en pause**, pas finie : 118 parcelles de rue sur 809 ont un sommet rentrant, et c'est **le peigne de `04c`**. **Ne pas la rouvrir tant que la 4 est ouverte.** → [Parcelles](Prototype/Parcelles.md) § 7

## Les commandes du quotidien

```
python QGIS/scripts/chaine.py                → LA commande : la carte et les bâtiments, 0,7 s
python QGIS/scripts/chaine.py --godot        → … et alimenter la maquette 3D
python QGIS/scripts/apercu_parcelles.py      → le parcellaire en PNG, numéroté
python QGIS/scripts/apercu_carte.py          → la carte en PNG
python QGIS/scripts/06_etat_zero.py          → la ville entière en HTML, 20 calques
python QGIS/scripts/08_jouer.py --toutes     → rejouer les parties du classeur
python QGIS/scripts/tracer_chemins.py --blanc → proposer les venelles, sans rien écrire
```

Le détail des scripts et leurs pièges → `QGIS/README.md` · l'organisation des données → `QGIS/data/LISEZ-MOI.md` · la maquette et ses touches → `Godot/README.md`.
