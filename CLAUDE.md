# CLAUDE.md — contexte permanent du projet

> Ce fichier est chargé automatiquement à chaque session. Il contient ce qui **ne change pas** (le projet, mon rôle, les règles).
> Ce qui change — l'avancement, les décisions en attente — est dans **[ETAT.md](ETAT.md)**, à lire juste après celui-ci.

---

## 1. Le projet en cinq lignes

City-builder PC de **transformation urbaine**. Le joueur ne construit pas, il **décide**. Une ville moyenne fictive et voiture-dépendante — **Vallmar**, 112 000 hab. — qu'on transforme sur 20 ans.

- **But affiché** : inspirer, pas simuler la bureaucratie.
- **Règle mère de ton** : *dur mais possible, jamais cynique*.
- **Prototype en cours** : **Wehrau**, une petite ville entière (~5 350 hab., 0,93 km², 70 îlots) — pas un quartier de Vallmar. → `Décisions arrêtées` 13b · 13d
- **Cadre** : solo, 3–5 ans, ~15 000 €, Godot 4.

🎯 **Le centre de gravité est le prototype** (2026-08-13). Le vault continue de porter toutes les idées et reste la source de vérité du design — mais le travail se juge désormais sur ce qui tourne : `QGIS/scripts/` (la chaîne qui fabrique la carte), `Godot/` (la maquette 3D de Wehrau à t0), et `Prototype/` (les étapes, une note chacune). Le `.gpkg` est la source de vérité de la carte.

## 2. Où est quoi

**Deux dossiers vivent côte à côte, et ils ne font pas le même métier.**

```
City Builder/
├─ CLAUDE.md                  ← ce fichier (règles, stable)
├─ ETAT.md                    ← LE signet : où on en est, la prochaine action (je le mets à jour)
│   ├─ CHANTIERS.md           ← ce qui attend : défauts connus, dette, tables de level design
│   └─ HISTORIQUE.md          ← les sessions passées, une par entrée
├─ Vault - Jeu urbanisme/     ← 🧠 LA TÊTE : le vault Obsidian, source de vérité du design
├─ Prototype/                 ← 🔨 LE CHANTIER : ce qu'on construit, une note par étape
│   ├─ 00 - Prototype.md      ← l'index : la règle, les étapes dans l'ordre, où on en est
│   ├─ Parcelles.md           ← 🎯 l'étape en cours
│   └─ Énergie.md             ← le premier thème complet (ex-`PLAN_energie.md`)
└─ Ouvrir le vault dans Obsidian.lnk
```

`ETAT.md` reste court **par construction** : il pointe vers les autres au lieu de les absorber. Si une chose n'est ni « où on en est » ni « quoi faire maintenant », elle va dans `CHANTIERS.md` ou `HISTORIQUE.md`.

### Le vault et le prototype — la frontière

| | Le vault | `Prototype/` |
|---|---|---|
| **Ce qu'on y met** | les idées, le design, les arbitrages, les références — tout ce qui reste vrai quel que soit le code | ce qu'on construit : où en est l'étape, ses chiffres mesurés, ce qui lui reste, ce qu'on regarde à l'écran |
| **Ce qui y répond** | *pourquoi* c'est comme ça | *où on en est* |
| **Durée de vie** | durable | vivant, réécrit à chaque mesure |
| **Format** | frontmatter + wikilinks `[[Nom]]` (§4) | markdown ordinaire, **pas de frontmatter, pas de wikilinks** — ce n'est pas un vault |

🔴 **Quand les deux disent la même chose, c'est dans `Prototype/` qu'on efface.** Le vault est la source ; une note de chantier **pointe** vers lui au lieu de le recopier. Et une note de chantier ne ferme **jamais** un arbitrage toute seule : ça se fait dans `Questions ouvertes.md` **et** `Décisions arrêtées.md` (§3).

### La règle du prototype : une seule étape ouverte à la fois

Le prototype avance **pas à pas**. Une étape se termine quand **son critère de réussite est vu à l'écran**, pas quand le code compile. Le tableau des étapes et leur ordre sont dans `Prototype/00 - Prototype.md` — c'est lui qui dit laquelle est ouverte, et c'est le premier fichier à ouvrir quand le travail touche le prototype.

Ce que ça protège : le risque nommé en **52**, *que la 3D mange le calendrier*. Deux étapes ouvertes en même temps, c'est ce risque qui revient par la porte de derrière.

Dans le vault, quatre notes commandent toutes les autres :

| Note | Ce qu'on y trouve |
|---|---|
| `00 - Index.md` | MOC d'entrée, l'état affiché du projet, les 3 trucs à trancher |
| `Méta/Décisions arrêtées.md` | le registre — ce qui est tranché, et ce qui est réversible ou non |
| `Méta/Questions ouvertes.md` | ce qui n'est pas tranché, dont **une bloquante** |
| `Méta/Journal.md` | ce que l'auteur **apprend**, une entrée par session |

Les autres dossiers : `Vision/` (fondations), `Systèmes/` (mécaniques), `Ville/` (Vallmar et ses quartiers), `Technique/` (QGIS, Godot, DA), `Production/` (plan, budget, périmètre, Steam).

## 3. Mon rôle — ce qui est explicitement délégué, et ce qui ne l'est pas

Ces règles viennent du vault lui-même, pas de moi. Elles ne se négocient pas sans que l'auteur les change dans le vault.

**Délégué :**
- **Les scripts de données : je les écris ET je les exécute**, y compris sur le vrai `.gpkg`. 🔄 *Révisé le 2026-08-12 — l'ancienne règle réservait l'exécution à l'auteur, dans la console QGIS, sur une copie.* → `Méta/Décisions arrêtées.md` **65**
  - Ce qui a rendu l'ancienne règle vide : **la chaîne ne passe plus par QGIS**. Les douze scripts de `QGIS/scripts/` sont du Python pur avec `sqlite3` — aucun PyQGIS, aucun GDAL, et l'en-tête GeoPackage de `04b` est encodée à la main. Le dossier garde son nom, pas sa dépendance.
  - **Trois garde-fous qui remplacent la relecture, et qui ne sont pas optionnels :**
    1. le dépôt est le filet — `git status` propre et commit **avant** toute écriture dans un `.gpkg`, qui est un binaire que git ne fusionne pas ;
    2. tout script qui écrit garde son mode `--blanc`, et **la passe à blanc tourne toujours d'abord** ;
    3. les **contrôles imprimés en français** sont le compte rendu — §3 bis ne bouge pas.
  - Ce qui reste à l'auteur : le **level design** (les listes de `fid` de `02`, la table `TISSU` de `04`, **le tracé des chemins dans les îlots**). C'est l'exécution qui est déléguée, pas les choix de carte. Un outil peut *proposer* — `tracer_chemins.py` le fait — mais la proposition se corrige à la main et ne s'écrase jamais toute seule.
- Tableurs, tables de correspondance, outillage, structuration de notes, relecture.
- **Le code Godot, noyau de simulation et architecture compris.** L'auteur teste, itère et revient sur mes décisions. 🔄 *Révisé le 2026-08-11 — l'ancienne règle réservait le noyau à l'auteur.* → `Méta/Décisions arrêtées.md` 40b · `Technique/Moteur et architecture.md`
  - Corollaire : ce que l'ancienne règle protégeait était la **compréhension**. Donc j'explique ce que je code au moment où je le code, et je signale les endroits où l'auteur doit revenir — mais **jamais en montrant le code** (§3 bis).
  - Le noyau de génération de géométrie reste **isolé derrière une interface propre** (décision 41), pour rester basculable en C# — et réécrivable.

**Non délégué :**
- **Aucun plugin IA dans QGIS.**
- Les arbitrages de design : je peux poser les options et recommander, l'auteur tranche. Une question ouverte se ferme dans `Questions ouvertes.md` **et** se consigne dans `Décisions arrêtées.md` — jamais implicitement au détour d'une réponse.

## 3 bis. L'auteur n'est pas développeur — il ne lit pas le code

C'est un fait de départ, pas une préférence à négocier. **L'auteur ne relit pas les scripts ligne à ligne et ne saura pas dire si un bout de code est juste.** Il juge sur ce qu'il voit. Donc la règle : **rien n'est « expliqué » tant que ça n'est pas montré autrement que par du code.**

Ce que ça change concrètement :

- **Ne pas coller de code dans mes réponses** pour expliquer quelque chose. Un extrait de code n'est pas une explication — c'est du bruit. Si je dois désigner un endroit, je le nomme (fichier + à quoi il sert), je ne le recopie pas.
- **Montrer, dans cet ordre de préférence :**
  1. **Dans le jeu** — la maquette Godot lancée, une capture d'écran, un avant/après. C'est la preuve la plus forte : si ça ne se voit pas à l'écran, ça ne compte pas encore.
  2. **Un tableau** — chiffres, correspondances, états, coûts, comptages d'objets. Le format par défaut pour tout ce qui n'est pas visuel.
  3. **Un schéma ou une visualisation** — quand c'est un enchaînement ou une structure.
  4. **Deux phrases en français** — en dernier recours, et seulement si ça tient en deux phrases.
- **Après une modification, dire ce que l'auteur doit regarder** : quoi lancer, où cliquer, ce qui doit avoir changé à l'écran, et ce qui prouverait que c'est cassé. Pas « c'est fait » tout court.
- **Décrire les effets, pas l'implémentation.** « Les toits sont maintenant inclinés selon l'époque du bâtiment » — pas le nom de la fonction qui le calcule.
- **Corollaire pour les scripts de données** : depuis la décision 65 je les exécute moi-même, donc l'auteur ne voit plus passer le script — il ne voit que **ce qu'il a fait à la carte**. Le contrôle imprimé en français et en tableaux n'est plus un préalable poli, c'est **le seul endroit où une erreur peut encore se voir**. Une passe à blanc avant chaque écriture, et le tableau des écarts après.

Ce n'est pas une dispense de rigueur, c'est l'inverse : le code n'étant relu par personne, **c'est à moi de le rendre vérifiable à l'œil**.

## 3 ter. Les commentaires du code s'adressent à moi, pas à l'auteur

Conséquence directe de §3 bis, et elle va à contre-courant de l'intuition : puisque l'auteur n'ouvre pas les fichiers, **alléger les commentaires ne lui fait rien gagner**. Ça ne coûte qu'à moi — je relis ces scripts à froid, sans aucun souvenir de la session qui les a écrits. Les commentaires sont la seule mémoire qui survit entre deux sessions à l'intérieur du code.

| Lecteur | Ce qu'il lit | Ce qui le sert |
|---|---|---|
| L'auteur | les contrôles imprimés, les aperçus PNG, la maquette Godot | ce que le script **a fait à la carte** |
| Moi, la session suivante | le fichier, à froid | ce que le script **a essayé d'éviter** |

**Donc :**

- 🔴 **Aucun commentaire qui redit le code.** « boucle sur les parcelles » au-dessus d'une boucle sur les parcelles est du bruit — à supprimer à vue.
- ✅ **Commentaire obligatoire** partout où il y a : un **nombre mesuré** (dire d'où il sort et ce qu'il produit), un **piège déjà payé** (sens de parcours, signe d'une aire, dédoublonnage), une **décision du vault appliquée** (avec son numéro), ou un **avertissement de level design**.
- 🔄 Un retour en arrière se **signale** au lieu de s'effacer : marquer ce qui était fait avant et pourquoi ça ne l'est plus. C'est ce qui m'empêche de réintroduire un bug déjà corrigé.
- ⚠️ **Le vrai risque n'est pas le volume, c'est la dérive.** Un commentaire devenu faux est pire qu'un commentaire absent : il se corrige **dans la même modification que le code**, jamais plus tard.

Repère mesuré le 2026-08-13 : ~940 lignes de commentaires pour ~6 400 lignes de code dans `QGIS/scripts/`, soit 13 %. Ce n'est pas un quota à tenir — c'est le point de comparaison si un fichier se met à enfler sans raison.

## 4. Écrire dans le vault

- **Frontmatter obligatoire** : `tags:` en minuscules, `statut:`, et `maj: AAAA-MM-JJ` sur les notes actives.
- **Wikilinks `[[Nom de la note]]`**, par nom seul, sans chemin. Corollaire : **deux notes ne doivent jamais porter le même nom** — le lien devient ambigu.
- Chaque note se termine par une ligne `**Voir aussi** : [[…]] · [[…]]`.
- Le français du vault est celui du jeu : concret, pas de jargon de consultant. Ton *dur mais possible*.
- **Cible ~10 000 mots de texte de jeu**, pas 30 000 — un effet doit être lisible à l'écran avant d'être écrit.
- Ne pas paraphraser le vault dans `ETAT.md` : y **pointer**. Le vault est la source, `ETAT.md` est un signet.

## 5. Deux machines, un dépôt

Le travail se fait **principalement sous Windows**, parfois sur un Mac. Le pont entre les deux est le dépôt git [`jan917-byte/city-builder`](https://github.com/jan917-byte/city-builder) (privé). Donc, avant de commencer : `git pull`. Avant de changer de machine : `git push`. Ce n'est pas une formalité — voir le piège du GeoPackage ci-dessous.

**Ce qui tourne sur le Mac, et ce qui n'y tourne pas.** 🔄 *Révisé le 2026-08-13 — l'ancienne règle disait « le clone Mac ne sert pas à coder ». La décision 65 l'a rendue fausse sans qu'on le remarque : les douze scripts de `QGIS/scripts/` sont du Python pur avec `sqlite3`, aucun PyQGIS, aucun GDAL. Ils tournent partout.*

| | Mac |
|---|---|
| Le vault — écrire, relire, trancher | ✅ c'est sa raison d'être |
| Les douze scripts de `QGIS/scripts/` | ✅ rien à installer (`apercu_*` et `06` demandent Pillow) |
| **Écrire dans `QGIS/data/*.gpkg`** | ❌ **jamais** — voir la règle ci-dessous |
| QGIS lui-même, Godot | ❌ pas installés, donc `.mcp.json` n'a pas besoin d'être adapté |

🔴 **La règle qui remplace l'ancienne, et qui neutralise le piège du GeoPackage :**

> **Le script voyage entre les deux machines. La carte, non.**
> `QGIS/data/*.gpkg` ne s'écrit que **sous Windows**.

Sur le Mac on travaille donc en `--blanc`, ou sur une copie posée dans **`QGIS/data/bac/`** — un dossier ignoré par git, fait pour ça, avec sa notice dedans. Et au moment de committer depuis le Mac : **nommer les fichiers, jamais `git add -A`**. Tant que ça tient, le seul conflit possible reste du `.md` et du `.py` — que git fusionne très bien.

**Le dépôt est le filet de sécurité.** Avant une opération de masse (renommage, réécriture), vérifier que l'arbre est propre (`git status`) et committer ce qui traîne — plus besoin de copier le vault en zip.

## 5 bis. Pièges de cet environnement (vécus, pas théoriques)

- 🔴 **Les GeoPackages ne se fusionnent pas.** `QGIS/data/*.gpkg` sont des binaires : si la carte est modifiée sur les deux machines sans passer par un `push`/`pull`, git ne fusionne rien — il faut **choisir une version et jeter l'autre**. Ce qui neutralise le piège n'est plus « le Mac ne code pas » — il code maintenant (§5) — mais **« la carte ne s'écrit que sous Windows »**, et le dossier `QGIS/data/bac/` qui donne un endroit sûr pour les essais ailleurs.
- **Encodage des noms de fichiers.** Créés depuis un shell Windows en codepage OEM (CP850), les noms accentués arrivent en mojibake (`Systèmes` → `Syst├¿mes`) et cassent tous les wikilinks d'un coup. Créer et renommer les fichiers accentués **via les outils d'édition ou Python**, jamais par une redirection shell. Côté git c'est sain : les noms sont stockés en **NFC** (ce que Windows attend) et `core.precomposeunicode` tient le Mac aligné. Le contenu des `.md` reste en **UTF-8 sans BOM**.
- **Fins de ligne.** `.gitattributes` impose **LF** partout dans le dépôt et marque les `.gpkg` comme binaires. Sans lui, un aller-retour Windows↔Mac fait apparaître le vault entier comme modifié. Ne pas le supprimer.
- **Obsidian ouvert** pendant qu'on renomme des fichiers : le fermer d'abord, et corriger `.obsidian/workspace.json` si des chemins morts y traînent. Ce fichier est gitignoré — l'état de session ne se synchronise pas d'une machine à l'autre, et c'est voulu.
- **Windows uniquement** : le dossier du projet est en lecture seule côté attribut — c'est **volontaire** (`desktop.ini` + `folder-icon.ico` pour l'icône bleue, tous deux gitignorés). Ne pas « corriger » cet attribut.
- **Les chemins des commandes** diffèrent selon la machine (`python` vs `python3`). Les scripts, eux, sont indifférents : chemins relatifs à la racine du dépôt, pas de séparateur codé en dur.
- **`.mcp.json` est écrit pour Windows.** Le serveur MCP Godot y est lancé par `cmd /c npx` — sans le `cmd /c`, Node refuse de démarrer un `.cmd` (`EINVAL`). Et `GODOT_PATH` y pointe l'exécutable du Bureau, que le serveur ne sait pas deviner tout seul. C'est le seul fichier du dépôt qui n'est pas portable. Tant que le Mac ne sert qu'au vault (§5), ça n'a aucune conséquence : le serveur Godot n'y est simplement pas lancé. **Si un jour Godot tourne sur le Mac**, remplacer `"command": "cmd"` / `"args": ["/c", "npx", …]` par `"command": "npx"` / `"args": ["-y", …]`, et `GODOT_PATH` par le chemin de `Godot.app` — à la main, sans committer la version Mac.

## 6. Protocole de session

**En début de session :** lire ce fichier puis `ETAT.md`.
- Si le travail touche **le prototype** — c'est le cas par défaut : ouvrir `Prototype/00 - Prototype.md`, puis la note de l'étape ouverte.
- Si le travail touche **le design** : ouvrir `00 - Index.md` et `Méta/Questions ouvertes.md` — ce sont eux qui disent où en est vraiment le projet.

**En fin de session**, deux mises à jour, et elles ne disent pas la même chose :
1. **La note de l'étape ouverte**, dans `Prototype/` — les chiffres mesurés, ce qui reste, ce qui attend l'auteur. C'est là que vit le détail.
2. **`ETAT.md`** — la date, ce qui a bougé, la prochaine action. **Il ne garde que les deux dernières sessions** ; la troisième descend dans `HISTORIQUE.md`, en tête, sans être raccourcie. Ce qui devient « à faire plus tard » descend dans `CHANTIERS.md`, avec sa raison d'attendre. **Rien ne s'écrase, tout descend d'un cran.**

Quand une étape se termine, sa note **reste** : elle passe à ✅ dans le tableau de `00 - Prototype.md`, et l'étape suivante s'ouvre. On n'ouvre pas la suivante avant.

**Ce que je ne fais pas tout seul :** écrire dans `Méta/Journal.md`. C'est le fichier de l'auteur, à la première personne, et il consigne ce qu'*il* a appris. Je peux proposer une entrée ; il la valide.
