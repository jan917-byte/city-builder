# ETAT.md — où on en est

> Mis à jour par Claude en fin de session. Complément de [CLAUDE.md](CLAUDE.md).
> Source de vérité du design = le vault. Source de vérité de la carte = `QGIS/Prototype_qualifie.gpkg`. Ici, seulement des signets et l'avancement.

**Dernière mise à jour : 2026-08-10**

---

## Position dans le plan

**Mois 1, semaine 1** — la carte, presque bouclée. → `Production/Plan 3 mois.md`

🔄 **Le prototype n'est plus l'Altstadt de Vallmar.** C'est **Wehrau**, une petite ville de 18 000 habitants qu'on voit en entier. Vallmar reste la ville du jeu complet, intacte dans le vault. → `Ville/Wehrau.md`

Ce que ça gagne : une ville entière, même petite, a **un amont et un aval**. Un quartier n'en a pas. L'injustice géographique entre dans le prototype.

**La carte est qualifiée.** 0,93 km² · 69 polygones (56 îlots bâtis, 7 champs, 6 morceaux de rivière) · 178 tronçons · 13 sous-types · **17 exceptions** (cible du vault : ~20).

Les cinq phrases de la sortie de semaine sont écrites → `Ville/Wehrau.md`

✅ **La table d'adjacence existe** : 179 paires, 13,60 km de frontières partagées — exactement le linéaire de voirie, donc aucune frontière sans rue. Voisins par îlot : min 3 · médiane 5 · max 13.

> **Le contrôle qui compte** : la ville privée de sa rivière et de ses champs tombe en **deux morceaux (45 et 11 îlots)**. La rivière coupe pour de bon.

## Prochaine action concrète

1. ☐ **Attributs dérivés** — 13 lignes de table de correspondance `sous_type` → `densite`, `impermeabilise`, `canopee`, `hauteur`, `desserte_tc`, `riverain`, `altitude_relative`. `exception = 1` protège les 17 saisies. C'est la dernière étape avant que la carte soit simulable.
2. ☐ Export GeoJSON (mois 2)
3. ☐ Semaine 2 du plan : le classeur des 10 décisions

**Boucle de contrôle** :
`python "QGIS/apercu_carte.py" Prototype_qualifie.gpkg` → la carte
`python "QGIS/apercu_carte.py" Prototype_qualifie.gpkg --adjacences` → le graphe, rouge = coupure, vert = on passe

**Les outils** (dans `QGIS/`, aucun n'écrit dans la source) :
`apercu_carte.py` la vue · `02_qualifier.py` le level design en listes de `fid` · `03_adjacences.py` le graphe · `01_champs_et_valuemaps.py` pour qualifier à la souris dans QGIS.

## Ce qui bloque

🔴 **Combien de temps dure une partie ?** Sans réponse, le classeur de la semaine 2 ne peut pas être équilibré. Se découvre en jouant les 5 parties du mois 1.

🟠 À trancher pendant le mois 1 : capital politique · d'où vient l'argent · le deuxième axe des fins · le premier clic.
🟢 Détendue : « quand tracer le deuxième quartier » — Wehrau teste déjà l'amont/aval.

→ `Méta/Questions ouvertes.md`

## En attente d'une décision de l'auteur

- [ ] **Le nom.** « Wehrau » et la rivière « l'Ilse » sont mes propositions, marquées comme telles dans la note. Se renomment en une commande tant que rien n'est codé.
- [ ] **Cinq franchissements pour la rivière**, alors que le vault en voulait deux au maximum. Trop de ponts = la rivière ne coupe plus rien, et « ajouter une passerelle » cesse d'être une décision. → `Méta/Questions ouvertes.md` n°12
- [ ] **Relire la qualification.** Tout est dans les listes de `fid` en haut de `QGIS/02_qualifier.py` : une ligne changée, on relance, on regarde. C'est du level design fait par moi — il doit passer sous tes yeux.
- [ ] **Le brainstorm du 2026-08-10** (`Brainstorming/…inondation-rive-droite.md`) est toujours en `brut`. Trois choses y valent d'être remontées : la **doctrine à seuil**, le **modèle de trafic minimal** (charge → report → seuil), et « **rendre à l'eau** ». Le reste parle d'une ville qui n'existe plus dans le projet.

## Historique des sessions Claude

### 2026-08-10 (session 2)
- Audit du GeoPackage, puis **qualification complète** : `fonction`, `sous_type`, `exception`, `surface_m2` sur 69 îlots ; `hierarchie`, `largeur_m` sur 178 tronçons. Quatre plaies de 1965 placées consciemment.
- Trois scripts écrits dans `QGIS/`. Aucun n'écrit dans `Vallmar2.gpkg`.
- **Table d'adjacence construite** (`03_adjacences.py`) : 179 paires, perméabilité par hiérarchie, contrôle de coupure de la rivière réussi.
- **Vault modifié** (sauvegarde zip préalable) : note neuve `Ville/Wehrau.md` ; révisions de `Décisions arrêtées` (13b, 13c, 26, 27, 28, 28b, 31, 31b, 31c, 32, 32b, 32c), `Pipeline QGIS`, `Géométrie et données`, `Périmètre et coupes`, `Altstadt`, `Questions ouvertes`, `Plan 3 mois`, `00 - Index`. Vérification : **0 wikilink cassé**.

### 2026-08-10 (session 1)
- Icône du dossier `City Builder` et raccourci Obsidian (lecture seule volontaire, ne pas défaire).
- **Encodage réparé** : 11 dossiers/fichiers renommés, `.obsidian/workspace.json` nettoyé.
- Mise en place de `CLAUDE.md` et de ce fichier.

*(`Méta/Journal.md` reste vierge de ma main — c'est le fichier de l'auteur.)*
