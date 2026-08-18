---
tags: [technique, données, architecture]
statut: arrêté — schéma réel depuis 2026-08-10
maj: 2026-08-10
---

# Géométrie et données

## L'entité de base : l'îlot

**Îlot, pas grille.** Arrêté.

- Une couche **ligne** (`routes`) → **polygonisation** → les îlots (les îlots ne sont jamais dessinés directement)
- **L'adjacence passe par la rue**, dont le caractère module l'effet
- C'est ça qui permet d'exprimer la **coupure urbaine** : une autoroute et une rue de desserte ne transmettent pas les mêmes effets entre deux îlots voisins
- Concrètement : une table `adjacences` (`id_a`, `id_b`, `hierarchie_separatrice`, `longueur_m`, `permeabilite`). ✅ **Construite le 2026-08-10 : 179 paires** → [[Pipeline QGIS]]
- ✅ **Contrôle** : la ville privée de sa rivière tombe en deux morceaux (45 et 11 îlots). La coupure urbaine est dans la géométrie.
- ⚠️ **Le bord de l'emprise n'est pas une rue.** Il ne produit aucune adjacence ; il est stocké à part, en `bord_carte_m` sur l'îlot — sinon « pas de voisin » et « donnée manquante » deviennent indiscernables.

### Les sept nombres qui décident du comportement de la carte

`permeabilite` : 0 = coupure totale, 1 = les deux îlots se comportent comme un seul. **C'est du design, pas de la mesure.**

| Séparateur | | |
|---|---|---|
| `ruelle` | 1,00 | on traverse sans y penser |
| `sans_rue` | 0,90 | deux arrières qui se touchent |
| `rue` | 0,80 | |
| `boulevard` | 0,40 | on traverse, mais on y pense |
| `rive` | 0,10 | on longe l'eau, on ne la franchit pas |
| `voie ferree` | 0,10 | |
| `autoroute` | 0,05 | la coupure franche |

Deux règles par-dessus : la perméabilité d'une paire est la **moyenne pondérée par la longueur** de ses morceaux de frontière, et **au-delà de 20 m de largeur la perméabilité est divisée par deux** — une rue large coupe plus qu'une rue étroite. C'est ce qui fait que la voie rapide de berge, à 22 m, coupe deux fois plus qu'un boulevard ordinaire.

C'est la décision qui rend la carte non décorative. Deux îlots collés séparés par une voie rapide ne sont pas voisins.

## La grille — usage restreint

Réservée aux **champs continus dérivés** : chaleur, ruissellement.

- Calculés **au runtime**
- **Jamais édités à la main**

## Attributs d'îlot — le schéma réel

**Saisis à la main** (2 champs seulement) :
- `fonction` → freiraum / habitation / industrie / mixte / **riviere**
- `sous_type` → **13 valeurs**, listées dans [[Wehrau]]

⚠️ **Une caractéristique de voirie ne devient jamais un type d'îlot.** La voie rapide de berge a d'abord été encodée en `sous_type`, à tort : c'est une `largeur_m` sur des tronçons de rive. Règle à tenir quand la liste des sous-types voudra grossir.

**Dérivés par script** — `04_deriver_attributs.py`. La règle qui a présidé au choix : **une colonne qui ne débloque aucune décision n'est pas écrite.**

| Champ | Ce qu'il rend possible |
|---|---|
| `densite` · `logements` · `hauteur` | densifier · le seuil de viabilité du TC et du commerce |
| `impermeabilise` | désimperméabiliser · le ruissellement |
| `canopee` | planter · le confort d'été |
| `desserte_tc` | le seuil que la densité doit atteindre |
| `riverain` | fragilité sociale — la seule boucle de gentrification du prototype |
| `stationnement` | le coût politique de la place-parking, chiffré |
| `altitude_relative` · `alea` | reconstruire / adapter / **rendre à l'eau** |
| `position_fil_eau` | la digue protège ici et **aggrave en aval** |
| `rive` | l'asymétrie des deux rives |

**Techniques** : `exception` (entier) · `surface_m2` (réel)

**Principe** : je saisis deux champs, le script dérive le reste, et je ne modifie à la main que **les exceptions — environ vingt**. Ces vingt exceptions **sont le level design réel**. Sur [[Wehrau]] : **16 exceptions**, la cible tient.

Le flag `exception = 1` protège définitivement une saisie manuelle contre le re-calcul.

### La table de correspondance — 12 lignes

Une ligne par `sous_type`, six colonnes : densité nette (log/ha), hauteur (étages), part imperméabilisée, part sous canopée, fragilité du riverain, part de la surface en stationnement. **C'est le fichier le plus dense en design de tout le projet** : douze lignes qui décident du comportement de la carte entière.

Les densités sont calées sur du tissu allemand réel — emprise au sol × niveaux ÷ surface par logement — et non choisies pour atteindre un chiffre de population. → [[Questions ouvertes]] n°13

## L'eau — comment on la mesure sans MNT

Il n'y a pas de modèle de terrain. Le relief est donc **du design assumé**, pas une mesure :

- `position_fil_eau` — 0 en amont, 1 en aval. L'Ilse traverse toute la carte **du nord au sud** en décrivant un grand S ; le fil de l'eau se lit donc en latitude. Un axe droit se tromperait de rive sur les méandres.
- `rive` — gauche / droite / lit, calculé sur la **direction locale** de la berge la plus proche, orientée vers l'aval.
- `altitude_relative` — la vallée remonte en s'éloignant de l'eau. La pente **n'est pas constante** : raide en amont (3,2 %), plate en aval (1,3 %), parce qu'une vallée s'élargit en descendant. C'est ce qui met l'injustice géographique dans le terrain lui-même, et pas seulement dans un coefficient.
- `alea` — 0 à 1. Décroît avec l'altitude, et **augmente vers l'aval à altitude égale** (× 0,80 en amont, × 1,20 en aval). C'est ce qui donne du mordant à « la digue protège ici et aggrave là ».

## Attributs de rue

- `hierarchie` → autoroute / boulevard / rue / ruelle / **rive** / voie ferrée
- `largeur_m` — base du profil en travers
- `emprise_libre_m` — ce qui reste une fois retirés la chaussée et les trottoirs. **L'entrée de la doctrine à seuil** : « je plante au-delà de X m ».
- `stationnement` — places sur rue, déduites de l'emprise libre
- `charge` — 0 à 1, affectation de trafic minimale (plus court chemin en temps, demande d'échange par les radiales + demande locale entre carrefours). Ce n'est pas une simulation : c'est le socle sur lequel « fermer une rue reporte sa charge » devient calculable.
- `canopee` — l'alignement existant, quasi nul à t0

Valeurs de base : boulevard 18 m · rue 12 m · ruelle 7 m · quai bâti 10 m · rive nue 0 m. Deux exceptions qui portent tout le problème : **la voie rapide de berge à 22 m** et **l'axe de transit à 20 m**.

⚠️ **Les rues et les ruelles varient autour de leur base** — selon le tissu qu'elles desservent (parcellaire ancien −2 m, normes des années 60 +2 m, route de campagne +1 m) et selon leur longueur (les percées rectilignes sont celles qu'on a élargies). Sans cette variation, `rue` vaut 12 m partout, l'emprise libre vaut 3,5 m partout, et **aucun seuil ne discrimine quoi que ce soit**. → [[Décisions arrêtées]] 31d

Les boulevards, eux, gardent leur largeur posée à la main : seuls le quai et l'axe de transit doivent dépasser 20 m, sinon la pénalité de coupure perd son sens.

⚠️ La couche de lignes s'appelle `routes` dans le fichier, pas `rues`. Le nom du fichier prime sur celui du vault. → [[Décisions arrêtées]] 31c

## 🔄 La rivière est un îlot (décision révisée)

**Ancienne version** : le fleuve était une entité de la couche `rues`.
**Version actuelle** : les **deux rives** sont des lignes (`hierarchie = 'rive'`) ; le polygone qui en résulte est un **îlot avec `fonction = 'riviere'`**.

### Ce que ça gagne

- La rivière a une **surface**, donc elle entre dans les champs continus : rafraîchissement, capacité d'expansion de crue, rapport de la ville à l'eau
- Elle devient **cliquable et diagnosticable** comme n'importe quel îlot
- Elle peut **changer d'état** — canalisée en béton → renaturée. Un fleuve-ligne ne peut pas se transformer ; un fleuve-îlot oui. Vu que le jeu porte sur la transformation, c'est décisif

### Ce que ça change dans l'adjacence

Les deux rives **ne sont plus voisines l'une de l'autre**. Elles sont chacune voisines de l'îlot rivière.

```
   îlot A ─── rive ─── [ RIVIÈRE ] ─── rive ─── îlot B
                            │
                          pont
```

La traversée ne se fait que par les **ponts** — des segments de `rues` qui franchissent le polygone. La coupure urbaine du fleuve n'est plus une convention de code, elle est **dans la géométrie**. C'est plus propre que l'ancienne version, et ça rend « ajouter une passerelle » mécaniquement lisible.

> 🔴 **Un pont se reconnaît à ce qu'il sépare deux morceaux de rivière.** Il longe le polygone comme une berge, et une règle naïve (« borde la rivière → c'est une rive ») l'avale : la ville se retrouve alors avec deux réseaux routiers étanches, sans que rien ne le signale. C'est arrivé, et seul un test de connexité du réseau l'a révélé. Le critère est net : c'est le franchissement qui a **découpé** la rivière en plusieurs polygones, donc il en touche deux. → [[Décisions arrêtées]] 30b

## Le profil en travers

Mécanique centrale identifiée : **le joueur redistribue des largeurs de bandes** dans une section de rue, il ne construit pas. C'est le geste le plus « métier » du jeu.

⚠️ **Les carrefours sont le problème procédural le plus difficile** à résoudre. → [[Génération procédurale]]

## ❌ OSM écarté comme donnée de production

- Ville **fictive**
- OSM éventuellement en fond de plan, ou en mode « joue ta ville » **post-lancement**

La tension est close : la carte du prototype est générée, pas relevée. → [[Questions ouvertes]]

**Voir aussi** : [[Pipeline QGIS]] · [[Diagnostic et calques]]
