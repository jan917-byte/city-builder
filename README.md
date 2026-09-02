# city-builder de transformation urbaine

Un city-builder PC où le joueur ne construit pas : il **décide**. Une ville moyenne fictive et voiture-dépendante qu'on transforme sur 20 ans. But : **inspirer**, pas simuler la bureaucratie. Ton : *dur mais possible, jamais cynique*.

En développement solo, Godot 4, moteur de simulation écrit à la main. → `Vault - Jeu urbanisme/Vision/Vision et prémisses.md`

**Deux villes, ne pas les confondre** : le **prototype** est **Wehrau**, une petite ville qu'on voit en entier — c'est elle qui est cartographiée dans `QGIS/`. **Vallmar** (~25 000 hab., 2 à 3 fois Wehrau) est la ville du jeu complet, dessinée dans le vault et en réserve.

## Où est quoi

```
city-builder/
├─ CLAUDE.md                    ← contexte permanent du projet pour Claude
├─ ETAT.md                      ← avancement et prochaine action (mis à jour chaque session)
├─ HISTORIQUE.md                ← les sessions passées, 3 lignes chacune
├─ Prototype/                   ← le chantier : une note par étape, une seule ouverte
├─ Vault - Jeu urbanisme/       ← LA source de vérité du design (vault Obsidian)
│   └─ 00 - Index.md            ← l'entrée : l'état affiché, les 3 trucs à trancher
├─ QGIS/
│   ├─ scripts/                 ← la chaîne qui fabrique la carte
│   ├─ data/source/             ← LA carte, en GeoJSON — le seul suivi par git
│   └─ rendus/                  ← aperçus régénérables (gitignoré)
├─ Godot/                       ← la maquette 3D
├─ Classeur/                    ← le système de décisions, en CSV
└─ .claude/skills/              ← skills de projet
```

## Sources de vérité

- **Design** : le vault Obsidian — `00 - Index.md` en entrée, `Méta/Décisions arrêtées.md` pour ce qui est tranché.
- **Carte** : `QGIS/data/source/*.geojson` (EPSG:25832), du texte suivi par git. Tout `.gpkg` est un dérivé refait en 0,7 s par `chaine.py`. → `QGIS/data/LISEZ-MOI.md`
- **Avancement** : `ETAT.md` à la racine, qui pointe vers le vault.

## Boucle de contrôle

Aucun script n'écrit dans la source. `--blanc` calcule tout et n'écrit rien.

```
python QGIS/scripts/chaine.py
python QGIS/scripts/apercu_parcelles.py
```

*(sur macOS, `python3` au lieu de `python`)*

## Travailler sur deux machines

Le développement se fait principalement sous Windows, parfois sur un Mac. `git pull` avant de commencer, `git push` avant de changer de machine.

✅ **La carte est du texte que git fusionne**, et aucun GeoPackage n'est suivi (depuis le 2026-08-17). Les deux machines font le même travail : `git pull` en début de session, `git push` en fin. **QGIS ne fait plus partie de la chaîne** — le dossier garde son nom, pas sa dépendance.
