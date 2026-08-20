# QGIS — la carte de Wehrau

Ce dossier fabrique la carte du prototype. Le design est dans le vault, l'avancement dans `ETAT.md`, les tables que l'auteur règle dans `Prototype/00 - Prototype.md`.

🔴 **Aucun chiffre mesuré dans ce fichier.** La chaîne les ressort tous en 0,7 s, et `06_etat_zero.py` sort la ville entière en HTML. Un nombre écrit ici serait faux avant d'être lu.

QGIS ne fait plus partie de la chaîne — le dossier garde son nom, pas sa dépendance. Les scripts n'importent ni GDAL, ni Shapely, ni QGIS : `sqlite3` et `struct` de la bibliothèque standard, plus Pillow pour les aperçus. Ils tournent sur un Python nu, sur les deux machines.

## La commande

```bash
python QGIS/scripts/chaine.py
```

Elle enchaîne **02 → 03 → 04 → 04b → 04c** et s'arrête net à la première étape qui échoue. `--godot` ajoute `07`, `--depuis 04` reprend au milieu.

🔴 **`02` rebâtit la carte de travail de zéro** et détruit tout ce que les suivants y avaient écrit, `emprises` et `parcelles` comprises. Ne jamais le lancer seul. Les autres — `03`, `04`, `04b`, `04c` et tous les lecteurs — se relancent sans risque.

## Les trois dossiers de `data/`

| | Quoi | git |
|---|---|---|
| `source/` | **la carte**, en GeoJSON : îlots, routes, et les venelles quand elles existent | ✅ suivi |
| `travail/` | `wehrau.gpkg` et les copies d'essai | ❌ ignoré |
| `archive/` | les anciens GeoPackages | ❌ ignoré |

**Ce qui est écrit à la main va dans `source/`. Tout le reste se refait.** Détail du format → `data/LISEZ-MOI.md`.

## Les scripts

| | |
|---|---|
| `chaine.py` | ▶️ LA commande |
| `carte.py` | 📖 lit et écrit la SOURCE — le seul qui connaisse le WKB |
| `00_decouper_ilots.py` · `00b_ilots_lisiere.py` · `tracer_chemins.py` | ✏️ **écrivent dans la SOURCE** |
| `02_qualifier.py` | ① le level design : les listes de `fid`, la hiérarchie et la largeur des rues |
| `03_adjacences.py` | ② le graphe : qui touche qui, et ce que la rue laisse passer |
| `04_deriver_attributs.py` | ③ les attributs dérivés, la table `TISSU`, le trafic |
| `04b_emprises_baties.py` | l'îlot après retrait de voirie |
| `04c_parcelles.py` | le découpage en parcelles |
| `04d_emprises_batiments.py` | l'empreinte de chaque bâtiment |
| `05_exporter_classeur.py` | → `Classeur/*.csv` |
| `06_etat_zero.py` | 👁 la ville entière en HTML |
| `07_exporter_godot.py` | → `Godot/data/wehrau.json`, toute la géométrie 3D |
| `08_jouer.py` | rejoue les parties du classeur |
| `apercu_carte.py` · `apercu_parcelles.py` | 👁 PNG légendés, lecture seule |
| `palette.py` | les matériaux du bâti |
| `01_champs_et_valuemaps.py` · `classification.json` · `00b_mettre_a_echelle.py` | vestiges, hors chaîne — le dernier vise encore `Vallmar2.gpkg`, qui n'existe plus |

🔴 **Trois scripts écrivent dans la SOURCE**, et ce qu'ils touchent est du level design : passer `--blanc` d'abord, toujours. `02` rebâtit la carte de travail depuis la source, donc **un tracé fait à la main ne survit que dans la source**. `tracer_chemins` refuse en plus d'écraser une couche existante sans `--refaire`.

## Ce qui casse la chaîne sans prévenir

- les noms de couches **`ilots`** et **`routes`** sont codés en dur — les renommer casse tout en silence. La couche s'appelle `routes`, pas `rues` comme dit le vault : le fichier prime.
- un `sous_type` écrit par `02` sans ligne dans `TISSU` → `04` s'arrête en nommant les manquants.
- la table `adjacences` absente → `04` refuse de démarrer.
- les déclencheurs d'index spatial du GeoPackage appellent des fonctions que SQLite seul n'a pas : **écrire le moindre attribut échoue sans elles**. Les scripts les rebranchent en Python.
- les coordonnées sont en **EPSG:25832** et ne sont **jamais arrondies** — voir l'en-tête de `carte.py`.

## Regarder, sans rien écrire

```bash
python QGIS/scripts/apercu_carte.py --calque=charge
```

`--adjacences` affiche le graphe par-dessus la carte effacée, `--calque=<champ>` met n'importe quel champ numérique en dégradé. C'est ce qui permet de vérifier un attribut **en le regardant**.

`--blanc` sur `04` et `04b` calcule tout, affiche tout, n'écrit rien.

`QGIS/rendus/` est gitignoré, donc absent d'un clone frais.

---

**Voir aussi** — le vault : `Technique/Pipeline QGIS.md` · `Technique/Géométrie et données.md`. À la racine : `CLAUDE.md` · `ETAT.md` · `Prototype/00 - Prototype.md`.
