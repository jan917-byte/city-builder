# ETAT.md — où on en est

> Mis à jour par Claude en fin de session. Complément de [CLAUDE.md](CLAUDE.md).
> Source de vérité du design = le vault. Source de vérité de la carte = `QGIS/data/Prototype_qualifie.gpkg`. Ici, seulement des signets et l'avancement.

**Dernière mise à jour : 2026-08-11 (session 7)**

---

## Position dans le plan

**Mois 1, semaine 1 bouclée. On entre en semaine 2** — le classeur des 10 décisions. → `Production/Plan 3 mois.md`

🔄 **Le prototype n'est plus l'Altstadt de Vallmar.** C'est **Wehrau**, une petite ville qu'on voit en entier. Vallmar reste la ville du jeu complet, intacte dans le vault. → `Ville/Wehrau.md`

Ce que ça gagne : une ville entière, même petite, a **un amont et un aval**. Un quartier n'en a pas. L'injustice géographique entre dans le prototype.

**La carte est simulable.** Les cinq étapes du pipeline sont faites. 0,93 km² · 69 polygones · 178 tronçons · 13 sous-types · **17 exceptions** (cible : ~20) · 179 paires d'adjacence · **5 franchissements de l'Ilse**.

Chaque îlot porte 12 attributs, chaque tronçon 4 — et chacun répond à « quelle décision devient possible ? ». → `Technique/Géométrie et données.md`

> **Les trois contrôles qui comptent**
> — la ville privée de sa rivière tombe en **deux morceaux (45 et 11 îlots)** : la coupure est dans la géométrie
> — le réseau routier, lui, est **d'un seul tenant** : les cinq ponts existent enfin
> — l'**axe de transit sort tout seul** de l'affectation de trafic, sans qu'on l'ait désigné

## 🔴 À FAIRE EN PREMIER SUR LE PC : le raccorder au dépôt

Constaté le 2026-08-11 : **le dossier du projet sur le PC n'est pas un clone de GitHub**, c'est le dossier d'origine. Tant que ce n'est pas réglé, `git pull` n'y fonctionne pas et les deux machines divergent en silence.

**Étape 1 — savoir dans quel cas on est.** Dans le dossier du projet, sous Git Bash ou PowerShell :

```
git status
```

- Ça répond (branche, fichiers) → le dossier *est* un dépôt. Aller à l'étape 2.
- `fatal: not a git repository` → aller à l'étape 3.

**Étape 2 — le dossier est déjà un dépôt.** La distinction « original / clone » n'existe pas pour git : un dossier avec un `origin` configuré tire exactement comme un clone. Vérifier :

```
git remote -v
```

S'il affiche `https://github.com/jan917-byte/city-builder` → committer ce qui traîne, puis `git pull`. C'est fini.
S'il n'affiche **rien** → pas de remote, deux historiques sans ancêtre commun. Ne pas bricoler un `git remote add` : aller à l'étape 3.

**Étape 3 — repartir d'un clone frais.** C'est la voie sûre, à cause des pièges de `CLAUDE.md` §5 bis : un clone applique `.gitattributes` (LF) et récupère les noms accentués en NFC. Ré-initialiser git par-dessus l'original ferait apparaître tout le vault comme modifié, avec un risque de mojibake sur `Systèmes/`.

1. Renommer l'original en sauvegarde (**ne pas le supprimer**) : `City Builder` → `City Builder - ORIGINAL`
2. `git clone https://github.com/jan917-byte/city-builder.git` à côté
3. Comparer les deux dossiers, rapatrier à la main **ce qui n'existe que dans l'original** — le travail fait sur le PC jamais poussé
4. Committer + pousser depuis le clone, puis garder la sauvegarde quelques jours avant de l'archiver

⚠️ Deux points de vigilance à l'étape 3 :
- **`QGIS/data/*.gpkg`** : si la carte a été retouchée sur le PC après le dernier push, c'est cette version-là qui écrase celle du clone. Aucune fusion possible — il faut choisir.
- **Ne pas recopier** `.obsidian/workspace.json`, `desktop.ini`, `folder-icon.ico` : gitignorés volontairement.

*(Supprimer cette section une fois le PC raccordé.)*

## Prochaine action concrète

0. 🔴 **Raccorder le PC au dépôt** — voir la section ci-dessus. Bloque le travail à deux machines
1. 🔴 **Lancer `04_deriver_attributs.py` sans `--blanc`.** La colonne `emplois` est écrite dans le script mais **pas encore dans le `.gpkg`** — tant que ce n'est pas fait, `05` et `06` s'arrêtent avec un message qui le dit. Relire d'abord la table `TISSU`, elle a une 7ᵉ colonne
2. ☐ **Stabiliser l'état zéro avant de revenir aux décisions.** L'ordre a changé : la crue est une *perturbation d'un état*, et l'état n'existait pas. → `Classeur/README.md`
3. ☐ **Semaine 2 du plan : le classeur.** Écrit et chiffré dans `Classeur/`, jamais joué — les valeurs sont posées, pas calibrées
4. ☐ Digérer le brainstorm importé du 2026-08-11 (refs / positionnement / UI) — 9 décisions et 7 questions à remonter
5. ☐ Export GeoJSON (mois 2)

**Deux machines** : Windows principal, Mac occasionnel. `git pull` en début de session, `git push` en fin. ⚠️ Les `.gpkg` ne se fusionnent pas — le travail QGIS se fait sur une machine à la fois. → `CLAUDE.md` §5

**Boucle de contrôle** :
`python "QGIS/scripts/apercu_carte.py" "QGIS/data/Prototype_qualifie.gpkg"` → la carte
`python "QGIS/scripts/apercu_carte.py" "QGIS/data/Prototype_qualifie.gpkg" --adjacences` → le graphe, rouge = coupure, vert = on passe
`python "QGIS/scripts/apercu_carte.py" "QGIS/data/Prototype_qualifie.gpkg" --calque=alea` → n'importe quel attribut en dégradé (`charge`, `emprise_libre_m`, `densite`, `riverain`…)
`python "QGIS/scripts/04_deriver_attributs.py" --blanc` → tout recalculer sans rien écrire

`python "QGIS/scripts/06_etat_zero.py"` → **la ville entière dans une page** : 22 calques cliquables, les stocks à côté, un seul fichier HTML sans dépendance. C'est la boucle « je vois donc je corrige ».

**Les outils** (dans `QGIS/scripts/`, aucun n'écrit dans la source) :
`apercu_carte.py` la vue en PNG · `02_qualifier.py` le level design en listes de `fid` · `03_adjacences.py` le graphe · `04_deriver_attributs.py` la table de correspondance · `05_exporter_classeur.py` la carte en CSV · `06_etat_zero.py` la vue interactive · `01_champs_et_valuemaps.py` pour qualifier à la souris dans QGIS.

`04` et `06` acceptent un chemin de `.gpkg` en argument — pour essayer un changement de `TISSU` sur une copie avant de l'écrire.

⚠️ **Chaîne à relancer dans l'ordre** : 02 → 03 → 04. Le 02 repart de `Vallmar2.gpkg` et écrase `Prototype_qualifie.gpkg`.

## Ce qui bloque

**Rien.** La semaine 2 peut s'écrire.

⏸️ La durée d'une partie est **mise de côté volontairement** : pas de fin imposée, on joue jusqu'à l'ennui puis on recommence dans une autre direction. Hypothèse de travail non fixée : ~20 ans en ~2 h. → `Décisions arrêtées` 14b · 14c

🟠 À trancher pendant le mois 1 : d'où vient l'argent · le deuxième axe des fins · le premier clic.
🟢 Détendue : « quand tracer le deuxième quartier » — Wehrau teste déjà l'amont/aval.

→ `Méta/Questions ouvertes.md`

## En attente d'une décision de l'auteur

- [x] ✅ **Wehrau porte ~5 350 habitants** (2026-08-11, prototype seulement — Vallmar garde ses 112 000) → `Décisions arrêtées` 13d
- [x] ✅ **Le jeu s'ouvre sur une crue, sur la rive gauche** (2026-08-11) → `Décisions arrêtées` 23b
- [ ] **Le grand ensemble de 1974 est à 200 m de l'eau**, pas « contre l'eau ». J'ai corrigé la phrase du vault ; l'autre option est de déplacer la barre. → n°14
- [ ] **Cinq franchissements pour la rivière**, alors que le vault en voulait deux au maximum. Ils sont maintenant typés dans les données. → n°12
- [ ] **Le nom.** « Wehrau » et la rivière « l'Ilse » sont mes propositions, marquées comme telles dans la note. Se renomment en une commande tant que rien n'est codé.
- [ ] **Relire deux fichiers de level design** : les listes de `fid` en haut de `QGIS/scripts/02_qualifier.py`, et la table de correspondance `TISSU` en haut de `QGIS/scripts/04_deriver_attributs.py` — treize lignes qui décident du comportement de toute la carte. Une ligne changée, on relance, on regarde.
- [ ] **Le tag `jeu/brightvale`** du brainstorm importé — nom de travail abandonné, autre projet, ou candidat à verser dans `Marketing et Steam` ?
- [ ] **Les conséquences de 5 350 habitants** sur trois équipements : le lycée devient une Realschule, la galerie de 1971 un supermarché, la barre de 1974 un petit Neubau. Acté dans la décision, pas encore écrit dans `Ville/Wehrau.md`.

## Ce que le brainstorm a donné

Le brainstorm du 2026-08-10 (`Brainstorming/…inondation-rive-droite.md`) a servi de plan pour l'étape 5 : ses trois idées transférables sont maintenant **dans les données**, pas dans une note.

| L'idée | Ce qui l'implémente |
|---|---|
| la **doctrine à seuil** (« je plante au-delà de X m ») | `emprise_libre_m`, qui a exigé que les largeurs de rue varient |
| le **modèle de trafic minimal** (charge → report → seuil) | `charge`, une affectation par plus court chemin en temps |
| « **rendre à l'eau** » | `alea`, `altitude_relative`, `position_fil_eau`, `rive` |

Reste en `brut` : le tableau `decisions` et les trois postures (reconstruire / adapter / rendre à l'eau), qui sont la semaine 2.

## Historique des sessions Claude

### 2026-08-11 (session 7)
- 🔄 **L'ordre a été corrigé en cours de route.** On a d'abord chiffré la crue (`Classeur/`, 11 décisions, 37 effets), puis constaté qu'une crue est une **perturbation d'un état** — et que l'état n'existait pas. Retour à l'état zéro. Le classeur reste, il repassera devant quand l'état sera stable.
- ❌ **L'arbre de décision (Miro) écarté comme format de travail**, gardé comme croquis de complétude par happening. Un arbre ne porte ni le délai, ni le lieu, ni les liens `ouvre`/`ferme`. Le format retenu : des CSV `;` dans le dépôt — jamais de `.xlsx`, c'est un binaire qui ne fusionne pas.
- 🆕 **`06_etat_zero.py`** : la ville entière dans **une page HTML autonome**, 22 calques cliquables, les stocks calculés à côté. Répond à « quand je vois, je corrige ».
- 🆕 **Les emplois** : 7ᵉ colonne de `TISSU`, uniquement sur `industrie` + `mixte`. **878 emplois pour 5 353 habitants — 0,16 par habitant.** Ce n'est pas un coefficient trop bas : la ville n'a que 10,4 ha d'activité sur 38 ha bâtis. **Wehrau est un dortoir**, ce qui explique l'axe de transit saturé et les 0,86 place de parking par habitant. Pour changer ça il faut dessiner du sol d'activité, pas régler un chiffre.
- 🐞 **`HABITANTS_VAULT` valait encore 18 000** (Vallmar) : le contrôle de fin de `04` criait à 30 % d'écart depuis que le prototype est Wehrau. Remis à 5 350.
- 🆕 **`05_exporter_classeur.py`** : la carte en CSV (69 · 178 · 179 lignes) pour que le classeur ne devienne pas une quatrième source de vérité.

### 2026-08-11 (session 6)
- 🎯 **Trois questions fermées par l'auteur** : population de Wehrau (~5 350, prototype seulement) · **crue d'ouverture sur la rive gauche** · **capital politique = un chiffre**. Consignées dans `Décisions arrêtées` (13d, 23b, 16b), fermées dans `Questions ouvertes` (13, 15, 2), répercutées dans `Wehrau.md`, `Ressources.md` et `00 - Index`.
- 🆕 **Système des milestones** (`Systèmes/Milestones.md`, décision 9b) : des jalons **cumulables**, pas des fins — zéro voiture, ville-éponge, autonomies. Ce qui les rend durs est un **coût d'opportunité**, pas une interdiction : *la rareté est dans le calendrier, pas dans les règles*. Conséquence notée dans `Ressources` : un capital politique en chiffre unique règle le **rythme**, jamais la **direction** — l'arbitrage vient du sol et du temps.
- ⏸️ **La durée d'une partie est reportée, pas tranchée** (14b, 14c) : **pas de fin imposée**, on joue jusqu'à l'ennui puis on recommence dans une autre direction. Les milestones deviennent le marqueur de progression. Hypothèse de travail assumée : ~20 ans en ~2 h.
- **Brainstorm importé** dans `Brainstorming/2026-08-11_brainstorm_refs-positionnement-ui.md` — positionnement, veille concurrentielle, DA et UI. Déposé brut avec un encart de provenance : il vient d'un autre vault, son vocabulaire diffère (table de correspondance dans l'encart). Non digéré.
- **Le vault rattrape la réalité** : `00 - Index` et `Plan 3 mois` annonçaient encore l'adjacence et les attributs dérivés comme « à faire » — faits depuis la session 3. Semaine 1 marquée bouclée.
- **Travail sur deux machines assumé** : `CLAUDE.md` §5 réécrite (elle décrivait un environnement Windows sans dépôt git), `README.md` corrigé (il s'intitulait « Vallmar » alors que le prototype est Wehrau), `.gitattributes` ajouté — LF partout, `.gpkg` marqués binaires. Vérifié : aucune renormalisation provoquée, le dépôt était déjà propre.

### 2026-08-10 (session 5)
- **Restructuration du dépôt** (recommandations de la session) : doublon `Vault - Jeu urbanisme/Production/ETAT.md` supprimé ; skill projet déplacé `SKILLS/` → `.claude/skills/solo-dev-systems/` ; `QGIS/` scindé en `scripts/`, `data/`, `rendus/` (préviews régénérables gitignorées, chemins des scripts recâblés sur `data/` et `rendus/`) ; `README.md` racine ajouté. Les scripts tournent (`apercu_carte.py` et `04 --blanc` vérifiés).

### 2026-08-10 (session 4)
- **Dépôt GitHub créé** : [jan917-byte/city-builder](https://github.com/jan917-byte/city-builder) (privé). 60 fichiers, commit initial. `.gitignore` exclut `__pycache__`, config locale Claude, raccourcis Windows, `workspace.json` Obsidian.

### 2026-08-10 (session 3)
- **Étape 5 faite** : `04_deriver_attributs.py`, 12 attributs d'îlot + 4 de rue, tous justifiés par une décision nommée. Table de correspondance de 13 lignes.
- Le dry-run a sorti **quatre défauts réels**, tous corrigés : aucun pont dans le réseau (5 franchissements typés comme des rives) ; graphe de rues construit sur les extrémités au lieu des sommets ; largeurs constantes rendant tout seuil inopérant ; axe droit se trompant de rive sur les méandres de l'Ilse.
- Nouveau mode `--calque=<champ>` dans `apercu_carte.py` : voir n'importe quel attribut en dégradé.
- **Trois questions ouvertes neuves** (13, 14, 15), dont deux à trancher avant la semaine 2.

### 2026-08-10 (sessions 1 et 2)
- Encodage réparé (11 dossiers/fichiers renommés), `CLAUDE.md` et ce fichier mis en place, icône du dossier et raccourci Obsidian.
- **Qualification complète de la carte** : 69 îlots, 178 tronçons, quatre plaies de 1965 placées consciemment. Trois scripts écrits, aucun n'écrit dans la source. Table d'adjacence construite. **Vault** : note neuve `Ville/Wehrau.md`, douze décisions révisées dans `Décisions arrêtées`, **0 wikilink cassé**.

*(`Méta/Journal.md` reste vierge de ma main — c'est le fichier de l'auteur.)*
