# CLAUDE.md — contexte permanent du projet

> Ce fichier est chargé automatiquement à chaque session. Il contient ce qui **ne change pas** (le projet, mon rôle, les règles).
> Ce qui change — l'avancement, les décisions en attente — est dans **[ETAT.md](ETAT.md)**, à lire juste après celui-ci.

---

## 1. Le projet en cinq lignes

City-builder PC de **transformation urbaine**. Le joueur ne construit pas, il **décide**. Une ville moyenne fictive et voiture-dépendante — **Vallmar**, 112 000 hab. — qu'on transforme sur 20 ans.

- **But affiché** : inspirer, pas simuler la bureaucratie.
- **Règle mère de ton** : *dur mais possible, jamais cynique*.
- **Prototype en cours** : l'**Altstadt** seule (~1 km², 50–120 îlots).
- **Cadre** : solo, 3–5 ans, ~15 000 €, Godot 4, moteur de simu écrit à la main.

Le projet est **du design, pas encore du code** : à ce jour il n'existe ni dépôt Godot ni script versionné, seulement le vault et un travail QGIS en cours.

## 2. Où est quoi

```
City Builder/
├─ CLAUDE.md                  ← ce fichier (règles, stable)
├─ ETAT.md                    ← avancement + décisions en attente (je le mets à jour)
├─ Vault - Jeu urbanisme/     ← le vault Obsidian : LA source de vérité du design
└─ Ouvrir le vault dans Obsidian.lnk
```

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
- **PyQGIS** : j'écris les scripts. L'auteur les relit, puis les exécute lui-même dans la console QGIS **sur une copie** du GeoPackage. Je n'exécute rien sur les données réelles. → `Technique/Pipeline QGIS.md`
- Tableurs, tables de correspondance, outillage, structuration de notes, relecture.

**Non délégué :**
- **Le noyau de simulation Godot est écrit par l'auteur, pas vibe-codé.** → `Technique/Moteur et architecture.md`
- **Aucun plugin IA dans QGIS.**
- Les arbitrages de design : je peux poser les options et recommander, l'auteur tranche. Une question ouverte se ferme dans `Questions ouvertes.md` **et** se consigne dans `Décisions arrêtées.md` — jamais implicitement au détour d'une réponse.

## 4. Écrire dans le vault

- **Frontmatter obligatoire** : `tags:` en minuscules, `statut:`, et `maj: AAAA-MM-JJ` sur les notes actives.
- **Wikilinks `[[Nom de la note]]`**, par nom seul, sans chemin. Corollaire : **deux notes ne doivent jamais porter le même nom** — le lien devient ambigu.
- Chaque note se termine par une ligne `**Voir aussi** : [[…]] · [[…]]`.
- Le français du vault est celui du jeu : concret, pas de jargon de consultant. Ton *dur mais possible*.
- **Cible ~10 000 mots de texte de jeu**, pas 30 000 — un effet doit être lisible à l'écran avant d'être écrit.
- Ne pas paraphraser le vault dans `ETAT.md` : y **pointer**. Le vault est la source, `ETAT.md` est un signet.

## 5. Deux machines, un dépôt

Le travail se fait **principalement sous Windows**, parfois sur un Mac. Le pont entre les deux est le dépôt git [`jan917-byte/city-builder`](https://github.com/jan917-byte/city-builder) (privé). Donc, avant de commencer : `git pull`. Avant de changer de machine : `git push`. Ce n'est pas une formalité — voir le piège du GeoPackage ci-dessous.

**Le dépôt est le filet de sécurité.** Avant une opération de masse (renommage, réécriture), vérifier que l'arbre est propre (`git status`) et committer ce qui traîne — plus besoin de copier le vault en zip.

## 5 bis. Pièges de cet environnement (vécus, pas théoriques)

- 🔴 **Les GeoPackages ne se fusionnent pas.** `QGIS/data/*.gpkg` sont des binaires : si la carte est modifiée sur les deux machines sans passer par un `push`/`pull`, git ne fusionne rien — il faut **choisir une version et jeter l'autre**. Le travail QGIS se fait sur une machine à la fois.
- **Encodage des noms de fichiers.** Créés depuis un shell Windows en codepage OEM (CP850), les noms accentués arrivent en mojibake (`Systèmes` → `Syst├¿mes`) et cassent tous les wikilinks d'un coup. Créer et renommer les fichiers accentués **via les outils d'édition ou Python**, jamais par une redirection shell. Côté git c'est sain : les noms sont stockés en **NFC** (ce que Windows attend) et `core.precomposeunicode` tient le Mac aligné. Le contenu des `.md` reste en **UTF-8 sans BOM**.
- **Fins de ligne.** `.gitattributes` impose **LF** partout dans le dépôt et marque les `.gpkg` comme binaires. Sans lui, un aller-retour Windows↔Mac fait apparaître le vault entier comme modifié. Ne pas le supprimer.
- **Obsidian ouvert** pendant qu'on renomme des fichiers : le fermer d'abord, et corriger `.obsidian/workspace.json` si des chemins morts y traînent. Ce fichier est gitignoré — l'état de session ne se synchronise pas d'une machine à l'autre, et c'est voulu.
- **Windows uniquement** : le dossier du projet est en lecture seule côté attribut — c'est **volontaire** (`desktop.ini` + `folder-icon.ico` pour l'icône bleue, tous deux gitignorés). Ne pas « corriger » cet attribut.
- **Les chemins des commandes** diffèrent selon la machine (`python` vs `python3`). Les scripts, eux, sont indifférents : chemins relatifs à la racine du dépôt, pas de séparateur codé en dur.

## 6. Protocole de session

**En début de session :** lire ce fichier puis `ETAT.md`. Si le travail touche le design, ouvrir aussi `00 - Index.md` et `Méta/Questions ouvertes.md` — ce sont eux qui disent où en est vraiment le projet.

**En fin de session**, mettre à jour `ETAT.md` : la date, ce qui a bougé, la prochaine action, ce qui attend une décision de l'auteur. Y garder au plus ~10 lignes d'historique — au-delà, on écrase.

**Ce que je ne fais pas tout seul :** écrire dans `Méta/Journal.md`. C'est le fichier de l'auteur, à la première personne, et il consigne ce qu'*il* a appris. Je peux proposer une entrée ; il la valide.
