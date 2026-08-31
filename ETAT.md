# ETAT.md — où on en est

> **Signet, pas source.** Design → le vault · carte → `QGIS/data/source/` · détail de l'étape → sa note · ce qui s'est passé → [HISTORIQUE.md](HISTORIQUE.md).
> **Plafond : ~40 lignes.** Ce qui ne tient pas ici tient ailleurs.

**2026-08-31 (session 70).** Étape ouverte : **5 — [Le trafic visible](Prototype/Trafic.md)**, critère *une rue à `charge = 1,00` est désagréable à regarder* — **jamais jugé à l'écran**. L'étape 4 est en pause. L'interface est passée au papier : pictogrammes et nombres en bandeau, fiche locale à droite, vues à gauche ; `--interface` sort ses deux captures de contrôle. → [Trafic](Prototype/Trafic.md) § Les deux vues
🅿️ **Les 3 310 places de rue sont peintes** et s'effacent quand la rue les perd ; les mètres libres du corridor reçoivent l'asphalte — la bande de sol nu entre le trottoir et la chaussée n'existe plus.
🌊 **La berge est devenue un objet du jeu** (73) : **8 morceaux**, un par rive et par bief, **trois états francs** (asphalte → quai apaisé → berge renaturée). Le mur de quai n'appartient plus à la rue. Une berge rendue au fleuve **abaisse la prochaine crue dans son bief, sur les deux rives** (74) : l'aléa, la reprise annoncée et *la prochaine crue au pire* suivent. Restent le trafic et le sol → [Décisions arrêtées](Vault%20-%20Jeu%20urbanisme/M%C3%A9ta/D%C3%A9cisions%20arr%C3%AAt%C3%A9es.md) 73 · [Questions ouvertes](Vault%20-%20Jeu%20urbanisme/M%C3%A9ta/Questions%20ouvertes.md) n°24

## Prochaine action — juger le trafic à l'écran

D'abord `python QGIS/scripts/chaine.py --godot`, **puis la passe rendue** : `Godot_console.exe --path Godot -- --essai` (Windows) ou `/Applications/Godot.app/Contents/MacOS/Godot --path Godot -- --essai` (Mac). Elle échoue au premier manque, et sort les images dans `QGIS/rendus/`.
Juger ensuite dans cet ordre : ① le **critère de l'étape 5**, sans thème — `wehrau_essai_axe.png` → `..._axe_ferme.png`, `..._rue_calme.png` → `..._stationnement_retire.png` ; ② les **deux vues**, sept captures au même cadrage → [Trafic](Prototype/Trafic.md) ; ③ la **berge**, trois captures au même cadrage — `..._berge_asphalte.png` → `..._apaisee.png` → `..._renaturee.png`.

## Ce qui attend l'auteur

- 🔴 **La barre ne fait pas la hauteur décidée** : 6 niveaux arrêtés le 2026-08-19, **5 à l'écran** — le ±1 niveau de `04c` a tiré −1 sur ses trois parcelles, et 13,5 m est exactement la hauteur refusée ce jour-là, celle qui passe sous les faîtages du cœur ancien. `04c` l'affiche désormais à chaque passage. Le critère « une barre de 9 niveaux » (`Plan 3 mois.md:48`) reste périmé par la même occasion.
- 🔴 **La berge ne rachète plus rien au stade « quai apaisé »**, et c'est la contrepartie du 2026-08-31 : le corridor des rues de berge est passé **sur la terre**, donc l'asphalte au-dessus de l'Ilse tombe de **6 043 m² à 13** — or c'est lui que `berge_largeur_rendue_m` rendait au fleuve. Avec les six nombres de `ville.gd` (0 / 1,2 / 3,4 k€ le mètre, 0 / 6 / 18 mois, **0,12 m de crue par mètre de rive rendue**), la berge 6 passe de **−0,53 puis −0,95 m** de crue à **−0,00 puis −0,42** pour les mêmes 416 puis 763 k€. **C'est ce nombre qui décide si une berge vaut trois ans de dotation, et il vient d'être divisé par deux.** La carte offre un remplaçant mesuré : `rive_m`, la rive minérale entre la chaussée et l'eau — **1,4 · 2,1 · 3,5 · 10,2 m** selon la berge. → [Trafic](Prototype/Trafic.md)
- 🟠 **Une rue et une berge se montrent par un morceau droit fabriqué** (`echantillon.gd`), plus par un bout de la ville : bonne largeur, bon type, angle fixe, et l'eau du côté du regard. La berge 6 y porte **10,2 m de quai minéral** entre la chaussée et l'eau ; la renaturer verdit les 3,5 m du bord et laisse le reste. Un îlot, lui, reste le maillage de la ville, et un pont cassé aussi. À juger sur `--interface` (rue, îlot, berge, **berge 4 en talus**) et sur les trois captures de berge de `--essai`. 🔴 **Reste un arbitrage** : un morceau droit ne dit plus OÙ l'on est — deux rues de même largeur et même hiérarchie donnent la même image, et c'est le prix de la lisibilité.
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
