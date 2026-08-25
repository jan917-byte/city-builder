# CLAUDE.md — les règles du projet

> Chargé à chaque session. Ici, **ce qui ne change pas**. Où on en est → [ETAT.md](ETAT.md).
> **Plafond : 100 lignes.** Ce qui déborde est de l'histoire, et l'histoire va dans [HISTORIQUE.md](HISTORIQUE.md).

## 1. Le projet

City-builder PC de **transformation urbaine**. Le joueur ne construit pas, il **décide**. Une ville moyenne fictive et voiture-dépendante — **Vallmar**, 112 000 hab. — qu'on transforme sur 20 ans. But : inspirer, pas simuler la bureaucratie. Ton : ***dur mais possible, jamais cynique***.

**Prototype : Wehrau**, une petite ville entière (~5 350 hab., 0,93 km², 71 îlots) — pas un quartier de Vallmar (13b · 13d). Cadre : solo, 3–5 ans, ~15 000 €, Godot 4.

🎯 **Le travail se juge sur ce qui tourne** : `QGIS/scripts/` (la chaîne qui fabrique la carte), `Godot/` (la maquette), `Prototype/` (les étapes). Le vault reste la source de vérité du design.

## 2. Où est quoi, et ce que chaque fichier a le droit de peser

| Fichier | Ce qu'il porte | Plafond |
|---|---|---|
| **CLAUDE.md** | les règles | 100 l. |
| **[ETAT.md](ETAT.md)** | le signet : étape ouverte · prochaine action · ce qui attend l'auteur | **40 l.** |
| **[HISTORIQUE.md](HISTORIQUE.md)** | **3 lignes par session** | on y cherche, on ne le lit pas |
| `Vault - Jeu urbanisme/` | 🧠 le design — idées, arbitrages, références | — |
| `Prototype/00 - Prototype.md` | le tableau des étapes, les tables de level design, la dette | 60 l. |
| `Prototype/⟨étape ouverte⟩.md` | le chantier vivant : mesures, ce qui reste, quoi regarder | **140 l.** |
| `Prototype/⟨étapes fermées⟩.md` | figées le jour où l'étape passe à ✅ | — |
| `⟨dossier⟩/README.md` | **le mode d'emploi du dossier, rien d'autre** : à quoi il sert, quoi lancer, ce qui va me mordre | **120 l.** |

**Six règles d'écriture, et c'est elles qui tiennent les plafonds :**
1. **Un fait, un seul endroit.** `ETAT.md` *pointe* vers la note d'étape, il ne la résume pas.
2. **Ce qui se remesure ne s'archive pas** — la chaîne ressort tous les chiffres en 0,7 s. Même logique que « on ne committe pas un dérivé », appliquée à la prose.
3. **Les règles s'écrivent au présent.** L'histoire d'une règle — ce qu'elle remplace, pourquoi — va dans `HISTORIQUE.md`.
4. **Quand le vault et `Prototype/` disent la même chose, c'est dans `Prototype/` qu'on efface.**
5. `Prototype/` **n'est pas le vault** : markdown ordinaire, pas de frontmatter, pas de wikilinks.
6. 🔴 **Un README reste simple, et il ne porte aucun chiffre mesuré.** Il dit ce que fait le dossier, quoi lancer, et les pièges permanents qu'aucune relance ne rattraperait. Pas d'état, pas de défauts, pas d'arbitrage, pas d'historique de ce qui a été essayé : ça vit dans `ETAT.md`, `Prototype/`, le vault et `HISTORIQUE.md`. Un README qui raconte la session qui l'a écrit est déjà faux.

**Une seule étape ouverte à la fois.** Une étape se termine quand **son critère de réussite est vu à l'écran**, pas quand le code compile. Ça protège le risque **52** — *que la 3D mange le calendrier*.

Dans le vault, quatre notes commandent les autres : `00 - Index.md` · `Méta/Décisions arrêtées.md` (ce qui est tranché) · `Méta/Questions ouvertes.md` · `Méta/Journal.md` (**à l'auteur seul** — je peux proposer une entrée, il la valide).
Écrire dans le vault : frontmatter (`tags:` minuscules, `statut:`, `maj:`), wikilinks `[[Nom]]` par nom seul — donc **deux notes ne portent jamais le même nom** —, une ligne `**Voir aussi**` en fin de note. Cible ~10 000 mots de texte de jeu, pas 30 000.

## 3. Mon rôle

**Délégué** : les scripts de données — je les **écris et je les exécute** (65) · **le code Godot, noyau et architecture compris** (40b), le générateur de géométrie restant isolé derrière une interface propre (41) · tableurs, outillage, structuration de notes, relecture.

**Non délégué** : aucun **plugin IA dans QGIS** · **les arbitrages de design** — je pose les options et je recommande, l'auteur tranche, et une question se ferme dans `Questions ouvertes.md` **et** `Décisions arrêtées.md`, jamais au détour d'une réponse · **le level design** : les listes de `fid` de `02`, les tables `TISSU`, le tracé des chemins. Un outil peut *proposer* ; la proposition se corrige à la main et ne s'écrase jamais toute seule.

**Les garde-fous avant d'écrire dans `QGIS/data/source/`** — ils remplacent la relecture, ils ne sont pas optionnels : ① arbre git propre ; ② passe `--blanc` d'abord pour les trois scripts qui touchent la source (`00`, `00b`, `tracer_chemins`) — c'est du level design ; ③ les contrôles imprimés en français. Écrire un `.gpkg` ne demande rien : il est dérivé.

## 4. L'auteur n'est pas développeur — il ne lit pas le code

Fait de départ, pas une préférence. Il juge sur ce qu'il voit. Donc **rien n'est expliqué tant que ça n'est pas montré autrement que par du code**.

- 🔴 **Court et simple, toujours.** Une réponse tient en quelques lignes : ce qui a changé, quoi regarder, ce qui reste. Pas de survol des options écartées, pas de récit de ce que j'ai essayé, pas de jargon quand un mot ordinaire suffit. Si c'est long, c'est que je n'ai pas fini de trier.
- 🔴 **Jamais de code dans mes réponses.** Pour désigner un endroit, je le nomme (fichier + à quoi il sert), je ne le recopie pas.
- **Montrer, dans cet ordre** : ① à l'écran — la maquette, une capture, un avant/après ; ② un tableau ; ③ un schéma ; ④ deux phrases en français, en dernier recours.
- **Après une modification** : dire quoi lancer, quoi regarder, ce qui doit avoir changé, **et ce qui prouverait que c'est cassé**. Pas « c'est fait ».
- **Décrire les effets, pas l'implémentation.**
- **Numéroter les objets sur les aperçus** : l'auteur désigne les défauts sur l'image, et le contour qu'il trace dessus est la spécification.

## 5. Les commentaires du code s'adressent à moi

L'auteur n'ouvre pas les fichiers ; moi si, à froid, sans souvenir de la session qui les a écrits. Les commentaires sont la seule mémoire qui survit **dans** le code — et une mémoire ne se lit que si elle est courte.

🔴 **Le plus court possible, jamais redondant.** Un commentaire ne dit que ce que le code ne peut pas dire : d'où sort un **nombre mesuré**, quel **piège est déjà payé**, quelle **décision du vault** est appliquée (avec son numéro), quel **avertissement de level design** tient. Le reste s'efface. Une ligne suffit presque toujours, un en-tête de fichier trois. Pas de paragraphes, pas de récit, pas de code reformulé en français.

Un **retour en arrière se signale** au lieu de s'effacer ; un commentaire devenu faux est pire qu'absent — il se corrige **dans la même modification que le code**.

## 6. Deux machines, un dépôt

Windows principal, Mac occasionnel, **à égalité**. `git pull` en début de session, `git push` en fin. Dépôt : `jan917-byte/city-builder` (privé).

**Un commit se nomme comme on le cherchera** : un titre **factuel**, préfixé par la zone touchée (`chaine:` `godot:` `proto:` `vault:` `doc:`), qui dit **ce qui change** ; puis **une ligne** en dessous, qui dit **pourquoi** et porte les chiffres mesurés. Pas de titre imagé — le `git log` sert à retrouver, pas à relire.

> 🔴 **La source est du texte** — `QGIS/data/source/*.geojson`, une entité par ligne, triée par `fid`, donc git la fusionne. **Tout GeoPackage est un dérivé, et aucun n'est suivi par git.**
> `python QGIS/scripts/chaine.py` refait tout en 0,7 s. **Si un fichier est calculé, ne pas le committer.**

Pièges de cet environnement, tous vécus : committer **en nommant les fichiers**, jamais `git add -A` (le `.DS_Store`) · créer et renommer les noms accentués **par un outil d'édition ou Python**, jamais par une redirection shell (mojibake CP850, qui casse tous les wikilinks d'un coup) · `.gitattributes` impose **LF** partout, ne pas le supprimer · fermer **Obsidian** avant de renommer des fichiers · `.mcp.json` est écrit **pour Windows** et n'est pas portable · sous Windows, l'attribut lecture seule du dossier est **volontaire**.

## 7. Protocole de session

**Début** : ce fichier → `ETAT.md` → `Prototype/00 - Prototype.md` → la note de l'étape ouverte.
**Fin**, dans cet ordre : ① la **note d'étape** (les chiffres, ce qui reste) ; ② **`ETAT.md`**, qui doit rester **sous 40 lignes** ; ③ **3 lignes** dans `HISTORIQUE.md`. Quand une étape se termine, sa note reste et passe à ✅ dans le tableau ; on n'ouvre pas la suivante avant.
