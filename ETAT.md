# ETAT.md — où on en est

> **Signet, pas source.** Design → le vault · carte → `QGIS/data/source/` · détail de l'étape → sa note · ce qui s'est passé → [HISTORIQUE.md](HISTORIQUE.md).
> **Plafond : ~40 lignes.** Ce qui ne tient pas ici tient ailleurs.

**2026-08-26 (session 65).** Étape ouverte : **5 — [Le trafic visible](Prototype/Trafic.md)**, critère *une rue à `charge = 1,00` est désagréable à regarder* — **jamais jugé à l'écran**. L'étape 4 est en pause. Godot est installé sur le Mac : la passe `--essai` compile, tourne et sort ses images **ici**, y compris les deux vues de la session 61. → [Trafic](Prototype/Trafic.md) § Les deux vues
🌊 **La berge est devenue un objet du jeu** (73) : **8 morceaux**, un par rive et par bief, **trois états francs** (asphalte → quai apaisé → berge renaturée). Le mur de quai n'appartient plus à la rue. Une berge rendue au fleuve **abaisse la prochaine crue dans son bief, sur les deux rives** (74) : l'aléa, la reprise annoncée et *la prochaine crue au pire* suivent. Restent le trafic et le sol → [Décisions arrêtées](Vault%20-%20Jeu%20urbanisme/M%C3%A9ta/D%C3%A9cisions%20arr%C3%AAt%C3%A9es.md) 73 · [Questions ouvertes](Vault%20-%20Jeu%20urbanisme/M%C3%A9ta/Questions%20ouvertes.md) n°24

## Prochaine action — juger le trafic à l'écran

D'abord `python QGIS/scripts/chaine.py --godot`, **puis la passe rendue** : `Godot_console.exe --path Godot -- --essai` (Windows) ou `/Applications/Godot.app/Contents/MacOS/Godot --path Godot -- --essai` (Mac). Elle échoue au premier manque, et sort les images dans `QGIS/rendus/`.
Juger ensuite dans cet ordre : ① le **critère de l'étape 5**, sans thème — `wehrau_essai_axe.png` → `..._axe_ferme.png`, `..._rue_calme.png` → `..._stationnement_retire.png` ; ② les **deux vues**, sept captures au même cadrage → [Trafic](Prototype/Trafic.md) ; ③ la **berge**, trois captures au même cadrage — `..._berge_asphalte.png` → `..._apaisee.png` → `..._renaturee.png`.

## Ce qui attend l'auteur

- 🔴 **La barre ne fait pas la hauteur décidée** : 6 niveaux arrêtés le 2026-08-19, **5 à l'écran** — le ±1 niveau de `04c` a tiré −1 sur ses trois parcelles, et 13,5 m est exactement la hauteur refusée ce jour-là, celle qui passe sous les faîtages du cœur ancien. `04c` l'affiche désormais à chaque passage. Le critère « une barre de 9 niveaux » (`Plan 3 mois.md:48`) reste périmé par la même occasion.
- 🔴 **L'asphalte des quais prend 6 m à l'Ilse** — **4 819 m² au total**, dont **1 541 sur la seule berge 6**, et la fiche de chaque berge le dit maintenant. Reste un **choix de carte** : une Ilse plus large veut dire reculer le **tracé** des voies de berge.
- 🔴 **Les six nombres de la berge sont du level design** (haut de `ville.gd`) : 0 / 1,2 / 3,4 k€ le mètre, 0 / 6 / 18 mois, et **0,12 m de crue rachetée par mètre de rive rendue**. Mesuré sur la berge 6 : **416 k€ puis 763 k€**, **−0,53 puis −0,95 m** de crue — l'îlot 61 passe de 100 à 50 % de reprise, l'îlot 69 reste à 100 %, il lui faudrait 3 m. **C'est ce nombre qui décide si une berge vaut trois ans de dotation.**
- 🟠 **La miniature de la fiche est à juger à l'écran** — elle est dans toutes les captures d'`--essai`, en haut à droite. Ce qui **ne se vérifie pas sans souris** : survoler « Reconstruire » ou un bouton de berge doit changer la miniature **avant** de presser. Le maillon faible est la **berge** — une bande de 2 m sur 400, elle reste un ruban ; c'est son changement de teinte qui se lit, pas sa forme.
- 🔴 **Le potentiel solaire réel est bas** — 11,0 ha de toiture réelle pour les 25–40 % annoncés au plan. **L'assumer, ou regonfler la colonne `equip`** de la table.
- 🔴 **Six arbitrages de rendu ne sont consignés nulle part** — les cinq du 2026-08-18, plus **« deux vues »**, pris et appliqué le 2026-08-25 : la couleur suit l'époque et non la typologie · le calque « tissu » est la contrepartie · zéro asset · l'étape 4 s'ouvre et la 2 passe en pause · et la DA dit **encore** « un `sous_type` = une teinte », faux depuis. À ouvrir puis fermer dans `Questions ouvertes.md` **et** `Décisions arrêtées.md`.
- 🟠 **Découper `07_exporter_godot.py`** — 5 500 lignes, 110 fonctions, un `main()` de 944 l., **79 000 tokens** : plus lourd que tous les markdown du dépôt réunis, et il faut le charger pour toucher à l'étape 4. Cinq fichiers par thème, contrôle nommé : **l'export doit sortir identique**. C'est du code, donc délégué (40b).
- 🟠 **Les deux nombres de la percée sont du level design** — l'îlot compact n'est plus un anneau fermé : `04d` interrompt son mur mitoyen tous les **60 m** par une ouverture de **9 m**. Îlot 49 : mur le plus long 85 → 58 m, cinq percées, 81 % du tour bâti, empreintes plus régulières qu'avant. À juger sur `--ilots 49` ; `04d` imprime « mur d'un seul tenant ».
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
