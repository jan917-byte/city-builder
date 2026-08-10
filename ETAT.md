# ETAT.md — où on en est

> Mis à jour par Claude en fin de session. Complément de [CLAUDE.md](CLAUDE.md).
> Source de vérité du design = le vault. Source de vérité de la carte = `QGIS/data/Prototype_qualifie.gpkg`. Ici, seulement des signets et l'avancement.

**Dernière mise à jour : 2026-08-10 (session 5)**

---

## Position dans le plan

**Mois 1, semaine 1** — la carte, presque bouclée. → `Production/Plan 3 mois.md`

🔄 **Le prototype n'est plus l'Altstadt de Vallmar.** C'est **Wehrau**, une petite ville qu'on voit en entier. Vallmar reste la ville du jeu complet, intacte dans le vault. → `Ville/Wehrau.md`

Ce que ça gagne : une ville entière, même petite, a **un amont et un aval**. Un quartier n'en a pas. L'injustice géographique entre dans le prototype.

**La carte est simulable.** Les cinq étapes du pipeline sont faites. 0,93 km² · 69 polygones · 178 tronçons · 13 sous-types · **17 exceptions** (cible : ~20) · 179 paires d'adjacence · **5 franchissements de l'Ilse**.

Chaque îlot porte 12 attributs, chaque tronçon 4 — et chacun répond à « quelle décision devient possible ? ». → `Technique/Géométrie et données.md`

> **Les trois contrôles qui comptent**
> — la ville privée de sa rivière tombe en **deux morceaux (45 et 11 îlots)** : la coupure est dans la géométrie
> — le réseau routier, lui, est **d'un seul tenant** : les cinq ponts existent enfin
> — l'**axe de transit sort tout seul** de l'affectation de trafic, sans qu'on l'ait désigné

## Prochaine action concrète

1. ☐ **Trancher les trois questions ouvertes par le prototype** (n°13, 14, 15 dans `Méta/Questions ouvertes.md`) — le scénario d'amorce conditionne le classeur de la semaine 2
2. ☐ Semaine 2 du plan : le classeur des 10 décisions
3. ☐ Export GeoJSON (mois 2)

**Boucle de contrôle** :
`python "QGIS/scripts/apercu_carte.py" "QGIS/data/Prototype_qualifie.gpkg"` → la carte
`python "QGIS/scripts/apercu_carte.py" "QGIS/data/Prototype_qualifie.gpkg" --adjacences` → le graphe, rouge = coupure, vert = on passe
`python "QGIS/scripts/apercu_carte.py" "QGIS/data/Prototype_qualifie.gpkg" --calque=alea` → n'importe quel attribut en dégradé (`charge`, `emprise_libre_m`, `densite`, `riverain`…)
`python "QGIS/scripts/04_deriver_attributs.py" --blanc` → tout recalculer sans rien écrire

**Les outils** (dans `QGIS/scripts/`, aucun n'écrit dans la source) :
`apercu_carte.py` la vue · `02_qualifier.py` le level design en listes de `fid` · `03_adjacences.py` le graphe · `04_deriver_attributs.py` la table de correspondance · `01_champs_et_valuemaps.py` pour qualifier à la souris dans QGIS.

⚠️ **Chaîne à relancer dans l'ordre** : 02 → 03 → 04. Le 02 repart de `Vallmar2.gpkg` et écrase `Prototype_qualifie.gpkg`.

## Ce qui bloque

🔴 **Combien de temps dure une partie ?** Sans réponse, le classeur de la semaine 2 ne peut pas être équilibré. Se découvre en jouant les 5 parties du mois 1.

🟠 À trancher pendant le mois 1 : capital politique · d'où vient l'argent · le deuxième axe des fins · le premier clic.
🟢 Détendue : « quand tracer le deuxième quartier » — Wehrau teste déjà l'amont/aval.

→ `Méta/Questions ouvertes.md`

## En attente d'une décision de l'auteur

- [ ] 🔴 **Wehrau porte 5 350 habitants, pas 18 000.** La carte n'a que 38,3 ha bâtis et la table de densité est déjà au plafond du réalisme. Recommandation : descendre le chiffre. → `Méta/Questions ouvertes.md` n°13
- [ ] 🔴 **Le jeu s'ouvre-t-il sur une crue ?** (proposition du brainstorm). Si oui, elle tombe sur la **rive gauche** — le petit faubourg de 13 îlots, pas la ville. À trancher **avant** le classeur de la semaine 2. → n°15
- [ ] **Le grand ensemble de 1974 est à 200 m de l'eau**, pas « contre l'eau ». J'ai corrigé la phrase du vault ; l'autre option est de déplacer la barre. → n°14
- [ ] **Cinq franchissements pour la rivière**, alors que le vault en voulait deux au maximum. Ils sont maintenant typés dans les données. → n°12
- [ ] **Le nom.** « Wehrau » et la rivière « l'Ilse » sont mes propositions, marquées comme telles dans la note. Se renomment en une commande tant que rien n'est codé.
- [ ] **Relire deux fichiers de level design** : les listes de `fid` en haut de `QGIS/scripts/02_qualifier.py`, et la table de correspondance `TISSU` en haut de `QGIS/scripts/04_deriver_attributs.py` — treize lignes qui décident du comportement de toute la carte. Une ligne changée, on relance, on regarde.

## Ce que le brainstorm a donné

Le brainstorm du 2026-08-10 (`Brainstorming/…inondation-rive-droite.md`) a servi de plan pour l'étape 5 : ses trois idées transférables sont maintenant **dans les données**, pas dans une note.

| L'idée | Ce qui l'implémente |
|---|---|
| la **doctrine à seuil** (« je plante au-delà de X m ») | `emprise_libre_m`, qui a exigé que les largeurs de rue varient |
| le **modèle de trafic minimal** (charge → report → seuil) | `charge`, une affectation par plus court chemin en temps |
| « **rendre à l'eau** » | `alea`, `altitude_relative`, `position_fil_eau`, `rive` |

Reste en `brut` : le tableau `decisions` et les trois postures (reconstruire / adapter / rendre à l'eau), qui sont la semaine 2.

## Historique des sessions Claude

### 2026-08-10 (session 5)
- **Restructuration du dépôt** (recommandations de la session) : doublon `Vault - Jeu urbanisme/Production/ETAT.md` supprimé ; skill projet déplacé `SKILLS/` → `.claude/skills/solo-dev-systems/` ; `QGIS/` scindé en `scripts/`, `data/`, `rendus/` (préviews régénérables gitignorées, chemins des scripts recâblés sur `data/` et `rendus/`) ; `README.md` racine ajouté. Les scripts tournent (`apercu_carte.py` et `04 --blanc` vérifiés).

### 2026-08-10 (session 4)
- **Dépôt GitHub créé** : [jan917-byte/city-builder](https://github.com/jan917-byte/city-builder) (privé). 60 fichiers, commit initial. `.gitignore` exclut `__pycache__`, config locale Claude, raccourcis Windows, `workspace.json` Obsidian.

### 2026-08-10 (session 3)
- **Étape 5 faite** : `04_deriver_attributs.py`, 12 attributs d'îlot + 4 de rue, tous justifiés par une décision nommée. Table de correspondance de 13 lignes.
- Le dry-run a sorti **quatre défauts réels**, tous corrigés : aucun pont dans le réseau (5 franchissements typés comme des rives) ; graphe de rues construit sur les extrémités au lieu des sommets ; largeurs constantes rendant tout seuil inopérant ; axe droit se trompant de rive sur les méandres de l'Ilse.
- Nouveau mode `--calque=<champ>` dans `apercu_carte.py` : voir n'importe quel attribut en dégradé.
- **Trois questions ouvertes neuves** (13, 14, 15), dont deux à trancher avant la semaine 2.

### 2026-08-10 (session 2)
- Audit du GeoPackage, puis **qualification complète** : `fonction`, `sous_type`, `exception`, `surface_m2` sur 69 îlots ; `hierarchie`, `largeur_m` sur 178 tronçons. Quatre plaies de 1965 placées consciemment.
- Trois scripts écrits dans `QGIS/scripts/`. Aucun n'écrit dans `Vallmar2.gpkg`.
- **Table d'adjacence construite** (`03_adjacences.py`) : 179 paires, perméabilité par hiérarchie, contrôle de coupure de la rivière réussi.
- **Vault modifié** (sauvegarde zip préalable) : note neuve `Ville/Wehrau.md` ; révisions de `Décisions arrêtées` (13b, 13c, 26, 27, 28, 28b, 31, 31b, 31c, 32, 32b, 32c), `Pipeline QGIS`, `Géométrie et données`, `Périmètre et coupes`, `Altstadt`, `Questions ouvertes`, `Plan 3 mois`, `00 - Index`. Vérification : **0 wikilink cassé**.

### 2026-08-10 (session 1)
- Icône du dossier `City Builder` et raccourci Obsidian (lecture seule volontaire, ne pas défaire).
- **Encodage réparé** : 11 dossiers/fichiers renommés, `.obsidian/workspace.json` nettoyé.
- Mise en place de `CLAUDE.md` et de ce fichier.

*(`Méta/Journal.md` reste vierge de ma main — c'est le fichier de l'auteur.)*
