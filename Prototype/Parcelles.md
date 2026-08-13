# Étape 2 — Les parcelles 🎯

> **L'étape en cours.** Le point dur du pipeline : ce qui sépare 70 pâtés pleins d'une ville où on croirait habiter.
> La doctrine — *pourquoi* la parcelle est une partition, ce qu'on ne fera jamais — est dans le vault : `Technique/Génération procédurale.md`. **Ici, le chantier seulement.**

**Dernière mesure : 2026-08-13** (session 19, sous Windows)

---

## 1. Ce que l'étape doit produire

Une couche `parcelles` dans le GeoPackage, écrite **une fois**, qui pave l'emprise bâtie de chaque îlot sans trou ni recouvrement. Le générateur : `QGIS/scripts/04c_parcelles.py`.

**Les deux décisions qui commandent, et qu'aucun réglage ne peut contredire :**

| | |
|---|---|
| **61** — la parcelle est une **partition** de l'emprise | le générateur **découpe**, il ne pose pas des formes dans un vide. Deux voisines partagent une arête exactement : le mitoyen sort de la géométrie, ce n'est pas un raccord à faire |
| **35** — la parcelle est l'**entité persistante**, seedée individuellement | régénérer le bâtiment d'une parcelle n'en touche aucune autre. La partition est calculée ici puis **écrite** : ⚠️ elle ne se rejoue **jamais** à l'affichage, sinon on ré-effondre le voisinage à chaque clic, comme Townscaper |

## 2. Où c'en est — les chiffres mesurés

| | |
|---|---|
| parcelles | **1 096**, dont **987 sur rue** — qui porteront une maison |
| cœurs d'îlot | 102, voulus (ce qu'aucune rue n'a réclamé) |
| reliquat de rue sans façade | **7** — c'est le seul vrai déchet |
| plus petite parcelle | **45,2 m²** — aucune sous le plancher, 48 éclats réunis à leur voisine |
| partition | **100,00 %** de l'aire de l'emprise sur chacun des 54 îlots, écart max 9,3·10⁻⁷ |

**La forme, qui était le vrai défaut.** L'aire tombait juste depuis le début ; c'est l'élancement qui était faux — un cœur ancien sortait en carré de 10,6 m au lieu d'une lanière de 7 × 16. Le **peigne sur rue** (méthode Vanegas et al., Eurographics 2012) l'a corrigé :

| élancement (profondeur ÷ façade) | avant | après | visé |
|---|---|---|---|
| `coeur_ancien` | 1,59 | **2,19** | 2,29 |
| `maisons_de_ville` | 1,46 | **2,44** | 2,50 |
| `pavillonnaire` | 1,51 | **2,09** | 2,07 |
| `front_commercant` | 1,59 | **1,64** | 1,64 |
| parcelles sans façade | 30 % | **7 %** | — |

## 3. Le critère de réussite — et il ne se juge pas ici

L'étape n'est pas finie parce que le script tourne. Elle finit sur **deux images** :

1. 🔴 **La surface de toit mesurée retombe sur le coefficient de l'énergie** — au-delà de ~15 % d'écart, le potentiel solaire du prototype bouge, et c'est ce chiffre-là qui fait des parcelles autre chose qu'un embellissement. → [Énergie.md](Énergie.md) §4
2. 👁️ **Le cœur ancien ressemble à un cœur ancien** — pas « est-ce que le nombre est juste », mais ***est-ce qu'on croirait y habiter***.

**Comment on regarde** : `python "QGIS/scripts/apercu_parcelles.py"` sort le parcellaire en PNG (`--avant` compare deux versions côte à côte). La lecture tient en deux couleurs — **en couleur de tissu, la parcelle portera une maison ; en vert, elle repart au jardin**. Le vert dispersé au milieu des maisons est le défaut ; le vert rassemblé en cœur d'îlot est le résultat.

## 4. Ce qui reste, dans l'ordre

1. 🔴 **Relancer `07_exporter_godot.py`, sous Windows.** La chaîne s'arrête au `.gpkg` : la maquette Godot affiche encore l'ancienne ville. Ce qu'il faut lire dans ce que `07` imprime — le nombre de volumes bâtis (987 parcelles sur rue là où l'ancienne découpe en donnait 705), des cœurs d'îlot moins nombreux et plus grands, et **les deux défauts ci-dessous qui devraient reculer sans qu'on les vise** (des parcelles plus rectangulaires font des empreintes plus rectangulaires). À vérifier, pas à promettre.
2. **Regarder le résultat en 3D**, puis les trois défauts imprimés à chaque export :

   | Le défaut | Ce que c'est |
   |---|---|
   | **18 bâtiments sur 690 mordent sur la rue**, jusqu'à 4,8 m | pic de mitre sur angle rentrant. Sans commune mesure avec les 258 m de la session 9, mais **un bâtiment sur la chaussée ment** |
   | **47 empreintes concaves prennent un toit plat** | la recette du faîtage suppose qu'un versant avance dans un seul sens. ⚠️ Un repli plus large a été essayé le 2026-08-12 et **retiré devant l'image** |
   | **748 pans de toit réorientés à l'émission (7 %)** | conséquence : le contrôle « faces vers l'extérieur » est vrai **par construction** côté toits et ne prouve plus rien. Le chiffre qui informe est celui des réorientations |

3. **Régler la table `TISSU` de `04c` devant l'image** — c'est du level design, il appartient à l'auteur (§5).
4. ⏸️ **Puis trancher le potentiel solaire** — voir « Ce qui attend l'auteur ».

## 5. Les manettes — la table `TISSU` de `04c_parcelles.py`

C'est **elle, et pas le code**, qui décide du grain de toute la ville. Une ligne changée, on relance, on regarde. Depuis le peigne, les deux premières colonnes disent enfin ce qu'elles disent : la boîte ne respectait que leur **produit**.

| `sous_type` | façade (m) | profondeur (m) | méthode | |
|---|---|---|---|---|
| `coeur_ancien` | 7,0 | 16,0 | peigne | fin, très mitoyen |
| `maisons_de_ville` | 8,0 | 20,0 | peigne | le tissu majoritaire |
| `front_commercant` | 11,0 | 18,0 | peigne | vitrines en rez-de-chaussée |
| `pavillonnaire` | 13,5 | 28,0 | peigne | détaché, jardins |
| `barre_1970` | 60,0 | 15,0 | peigne | la barre couchée le long de la rue |
| `equipement` | 45,0 | 35,0 | boîte | un ou deux objets |
| `dalle_commerciale` | 80,0 | 60,0 | boîte | un hangar |
| `friche_industrielle` | 55,0 | 45,0 | boîte | des halles |

`place_minerale`, `parc`, `champ`, `jardins_familiaux` et `riviere` ne se découpent pas : ce sont des sols.

**Les quatre réglages de bord**, à ne toucher qu'en sachant pourquoi : plancher de parcelle **45 m²** · jeu de coupe **0,25** (l'irrégularité, sans quoi tout est au cordeau) · dent minimale **0,60 × façade** · arête de moins de **6 m** ne porte pas de rue.

## 6. Ce que la méthode a appris, et qu'il ne faut pas reperdre

- **La rue la plus longue prend le coin.** Sinon le coin est orphelin et finit en éclats — 82 morceaux de cœur sur le seul îlot 35.
- **On ne coupe que ce qui touche la rue.** Sinon les droites de chaque arête viennent tailler le cœur à l'autre bout de l'îlot : 236 confettis pour 32 îlots.
- **Un seuil serré n'est pas un seuil sûr.** Le contrôle d'aire des réunions était réglé sur le bruit du flottant (2,4·10⁻⁴ m², soit 2⁻¹² sur des coordonnées à six chiffres) et refusait onze fusions justes. Un tracé faux se trompe de m², le bruit de cm² : deux ordres de grandeur séparent les deux.
- **On coupe par l'aire, pas au milieu géométrique.** L'îlot 34 ne remplit que 67 % de son rectangle englobant ; la coupe médiane le partageait en 927 et 1 685 m², et le tissu sortait deux à trois fois trop fin.
- 🏔️ **Le joint en toiture n'a demandé aucun travail** — les pignons sont verticaux, donc deux mitoyennes de hauteurs différentes se décrochent franc. C'était le seul reste de 61.

## 7. Ce qui attend l'auteur

- [ ] 🔴 **Le potentiel solaire réel est ~9,5 %, pas les 25–40 % du plan.** ⏸️ **Suspendu : le chiffre va bouger.** La fourchette avait été calibrée sur 76,5 ha d'*emprise* ; les vrais toits font 11,7 ha. Le peigne fait passer les parcelles bâtissables de 705 à 987, donc **relancer `07` avant de trancher** — sinon on arbitre sur les toits d'une ville qui n'existe plus. **À trancher ensuite : assumer ~9,5 %, ou regonfler la colonne `equip` de la table d'énergie.**
- [ ] **La table `TISSU` de `04c`** (§5) — c'est du level design, il n'est pas délégué.
- [ ] **Les réparations de boucle de `04b`** — passées de 4 à **7 îlots** avec la carte à trois ponts. Les quatre anciennes (55, 13, 16, 21) sont signalées ; les trois neuves (9, 11, 62) ne le sont pas.

## 8. Les commandes

```
python "QGIS/scripts/04c_parcelles.py" --blanc     calcule et affiche, n'écrit rien
python "QGIS/scripts/04c_parcelles.py"             écrit la couche `parcelles`
python "QGIS/scripts/apercu_parcelles.py"          le parcellaire en PNG
python "QGIS/scripts/07_exporter_godot.py"         alimente la maquette 3D
```

⚠️ **Chaîne dans l'ordre : 02 → 03 → 04 → 04b → 04c**, puis `07`. Le `02` repart de `Vallmar2.gpkg` et **écrase** `Prototype_qualifie.gpkg`, `emprises` et `parcelles` comprises.

🔴 **Depuis le Mac, on n'écrit pas dans le `.gpkg`** — `--blanc`, ou une copie dans `QGIS/data/bac/`.

---

**Voir aussi** : [00 - Prototype.md](00%20-%20Prototype.md) · [Énergie.md](Énergie.md) · `Vault - Jeu urbanisme/Technique/Génération procédurale.md` · `QGIS/README.md`
