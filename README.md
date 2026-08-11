# city-builder de transformation urbaine

Un city-builder PC où le joueur ne construit pas : il **décide**. Une ville moyenne fictive et voiture-dépendante qu'on transforme sur 20 ans. But : **inspirer**, pas simuler la bureaucratie. Ton : *dur mais possible, jamais cynique*.

En développement solo, Godot 4, moteur de simulation écrit à la main. → `Vault - Jeu urbanisme/Vision/Vision et prémisses.md`

**Deux villes, ne pas les confondre** : le **prototype** est **Wehrau**, une petite ville qu'on voit en entier — c'est elle qui est cartographiée dans `QGIS/`. **Vallmar** (112 000 hab.) est la ville du jeu complet, dessinée dans le vault et en réserve.

## Où est quoi

```
city-builder/
├─ CLAUDE.md                    ← contexte permanent du projet pour Claude
├─ ETAT.md                      ← avancement et prochaine action (mis à jour chaque session)
├─ Vault - Jeu urbanisme/       ← LA source de vérité du design (vault Obsidian)
│   └─ 00 - Index.md            ← l'entrée : l'état affiché, les 3 trucs à trancher
├─ QGIS/
│   ├─ scripts/                 ← le pipeline : 01…04, apercu_carte.py
│   ├─ data/                    ← les GeoPackages (source + fichier qualifié)
│   └─ rendus/                  ← préviews PNG/SVG, régénérables (gitignoré)
└─ .claude/skills/              ← skills de projet
```

## Sources de vérité

- **Design** : le vault Obsidian — `00 - Index.md` en entrée, `Méta/Décisions arrêtées.md` pour ce qui est tranché.
- **Carte** : `QGIS/data/Prototype_qualifie.gpkg` (EPSG:25832), qualifiée à la main.
- **Avancement** : `ETAT.md` à la racine, qui pointe vers le vault.

## Boucle de contrôle

Aucun script n'écrit dans la source. `--blanc` calcule tout et n'écrit rien.

```
python QGIS/scripts/apercu_carte.py QGIS/data/Prototype_qualifie.gpkg
python QGIS/scripts/04_deriver_attributs.py --blanc
```

*(sur macOS, `python3` au lieu de `python`)*

## Travailler sur deux machines

Le développement se fait principalement sous Windows, parfois sur un Mac. `git pull` avant de commencer, `git push` avant de changer de machine.

⚠️ **Les GeoPackages sont binaires : git ne les fusionne pas.** Le travail QGIS se fait sur une machine à la fois, sinon il faut choisir une version et jeter l'autre.
