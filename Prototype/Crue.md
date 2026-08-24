# La crue — le faubourg sinistré

> **Branche `crue`, pas `master`.** L'étape ouverte du prototype reste la **4 — Toits et sol**.
> Ce chantier est une reprise de la décision **23b**, suspendue depuis le 2026-08-12. Il ne se fusionne pas tant que l'auteur n'a pas tranché les deux questions du § 5.
> Critère de réussite visé : **on ouvre la maquette et on voit tout de suite ce que l'eau a pris.**

## 1. Où ça en est

| | | |
|---|---|---|
| la donnée | ✅ | `04e_crue.py`, dans la chaîne après `04d` |
| les dégâts au bâti | ✅ **à regarder** | touche `F` |
| le pont emporté | ✅ **vu à l'écran** | touche `N` : deux moignons affaissés par coupure |
| le diagnostic d'ensemble | ✅ **vu à l'écran** | bouton ou touche `D` |
| `alea` rallumé | ✅ | l'îlot dit ce qu'il risque, pas seulement ce qu'il a pris |
| **le choix du joueur** | ☐ | les trois postures — § 4, à arbitrer avant d'écrire |
| **les deux jauges** | ✅ **vu à l'écran** | Adaptation active · Réduction verrouillée, sans décision solaire |
| **la fin de l'urgence** | ✅ **prototype** | logements relevés + ponts rétablis ; seuil définitif ouvert — question 23 du vault |

```bash
python QGIS/scripts/chaine.py --godot
```

Puis lancer la maquette, `D` d'abord, `F` et `N` ensuite. **Ce qu'il faut voir** : en une image, le passage de l'eau en bleu, le bâti touché en orange et les trois franchissements bloqués en rouge · de près, des murs à crête cassée et ouverts au ciel en rive gauche · la rive touchée 1 m plus bas et la rive intacte 1 m plus haut · deux moignons de tablier affaissés à chaque coupure.
**Ce qui prouverait que c'est cassé** : une des trois couleurs absente du diagnostic · une ruine en rive droite · zéro ruine (`04e` n'est pas passé — l'export le dit en clair) · l'eau inclinée · un pont emporté réduit à un trou sans vestige, ou encore franchissable.

## 2. Le modèle, et pourquoi il n'est pas celui d'avant

L'essai du 2026-08-12 cherchait une **portée en mètres** et retombait sur la même carte de risque que l'altitude — *« la règle changeait, pas la carte »*. Celui-ci met la **hauteur d'eau en mètres** au centre : c'est elle, et rien d'autre, qui sépare une maison mouillée d'une maison perdue.

Le sol monte quand on s'éloigne de l'eau. **La rive gauche est la plaine, la rive droite est la terrasse** — deux pentes et un décrochement. C'est le décrochement, et lui seul, qui tient la décision 23b : la ville regarde le faubourg se noyer. La plaine s'élargit vers l'aval, donc la pente de rive gauche se couche avec `position_fil_eau`.

Le profil de calcul reste dans `04e`, sans réintroduire `altitude_relative`. Le rendu en donne une coupe lisible : **−1 m sur la rive gauche touchée, +1 m sur la terrasse droite intacte**, tandis que la nappe reste horizontale. Toute géométrie terrestre lit la même fonction ; ce n'est pas un déplacement posé îlot par îlot.

**Une seule règle, deux niveaux d'eau** : la crue d'ouverture est ce qui **est** arrivé, la crue annoncée est ce qui **peut** arriver — donc `alea`. Sur le même îlot le joueur lit les deux, et c'est ça le calcul que 23b réclame.

## 3. Ce que la carte dit maintenant

Tout se réimprime à chaque passage de `04e` : rien de ce qui suit ne s'archive.

| | rive gauche | rive droite |
|---|---|---|
| bâtiments ruinés | 68 | **0** |
| bâtiments sinistrés | 71 | 0 |
| mouillés · intacts | 0 · 0 | 0 · 618 |
| `alea` moyen (crue annoncée) | **0,81** | 0,01 |

**Les 417 logements du faubourg sont sinistrés.** Le vault annonçait un aléa de 0,75 en rive gauche : la nouvelle règle tombe à 0,81.

La moitié du bâti reste debout : **71 bâtiments sinistrés entre 68 ruines**. Les îlots 61, 62 et 64 ne perdent aucun bâtiment, tandis que 68 et 69 sont entièrement ruinés : le faubourg garde des vestiges sans devenir une tache uniforme. Le tableau complet sort de `04e`.

**36 tronçons sur 178** ont gardé du limon.

## 4. Les trois postures — à arbitrer avant d'écrire une ligne

Le brainstorm du 2026-08-10 les pose ; personne ne les a chiffrées. **C'est du level design : les nombres ci-dessous sont une proposition, pas une décision.**

| Posture | Ce que ça fait | Prix proposé | Ce que ça coûte vraiment |
|---|---|---|---|
| **Reconstruire** | le bâti revient à l'identique | ? k€ / m² ruiné | `alea` inchangé — la crue annoncée reprend **jusqu'à 100 %** de l'îlot (colonne « si on rebâtit ») |
| **Adapter** | RDC non habités, surélévation | ? k€ / logement | des logements en moins, tout de suite ; dégâts bornés ensuite |
| **Rendre à l'eau** | rien ne se rebâtit, l'îlot devient prairie inondable | démolition + relogement | tout le parc de l'îlot, définitivement — et **le pont 168 devient inutile** |

🎯 **« Rendre à l'eau » est la décision signature** (brainstorm § 2) : choisir de **ne pas** construire, et que ce soit valorisant. Elle a besoin de deux choses qu'aucune autre décision du prototype ne demande :
1. **Une contrepartie chiffrée** — l'expansion de crue doit faire **baisser le niveau en aval**, donc l'`alea` des autres. Sans ça c'est un renoncement, pas un choix.
2. **Un rendu qui change** — le vide doit devenir un paysage, et *la mémoire des parcelles doit rester perceptible sous le nouveau sol*.

⚠️ **Ce que le rendu demande, et qui n'existe pas** : la maquette construit sa géométrie **une fois** au chargement. Faire disparaître un bâtiment n'est pas un changement de couleur. Le chemin le moins cher est que `07` exporte, pour les seuls îlots du faubourg, **un second maillage « après »** (le sol rendu à l'eau) que Godot montre à la place du premier — un nœud caché, un nœud montré. Chiffré à vue : ~30 lignes dans `07`, ~20 dans `maquette.gd`. **Rien n'est écrit tant que le tableau ci-dessus n'est pas rempli.**

## 5. Les deux réponses de l'auteur

- ✅ **La rive droite reste hors d'atteinte.** La terrasse monte avec la crue : le front de quai regarde le faubourg se noyer sans boire lui-même. Le vault annonce encore 0,43 en face ; le modèle donne 0,01.
- ✅ **Les trois franchissements 145, 168 et 169 sont coupés.** Le faubourg n'a plus d'accès routier. Cela contredit volontairement 30c : « rendre à l'eau » peut désormais économiser trois ponts au lieu d'un.

## 6. La dette de ce chantier

- 🔴 **Le passage à la réduction est financièrement inaccessible en vingt ans avec les prix actuels.** Les logements sinistrés et les trois ponts essentiels coûtent plus que la caisse de départ et vingt ans de dotation réunis. Le verrou et les jauges fonctionnent ; leur seuil économique est du level design, pas un défaut d'interface.
- 🟠 **Une seule hauteur d'eau par tronçon**, prise à son milieu. La limite du limon tombe donc sur un carrefour, jamais au milieu d'une rue. Invisible sur les rues courtes du faubourg ; ça se verrait sur une radiale de 300 m.
- 🟠 **Le marquage au sol survit au pont emporté** : les passages piétons et les lignes d'axe s'arrêtent au bord de l'eau, peints jusqu'au vide. Défendable (la peinture reste), mais ça n'a pas été choisi.
- 🟠 **Les logements sinistrés se déduisent de la surface touchée**, faute de lien entre `logements` et l'emprise bâtie. C'est la dette « `logements` est inventé » du prototype, vue sous un autre angle — et la crue lui donne enfin une raison d'être payée.
- 🟠 **`04e` écrit dans `ilots.alea`, que `04` remet à 0 au passage précédent.** Ça marche parce que l'ordre de la chaîne est tenu par `chaine.py`. Lancer `04` seul après `04e` efface la crue sans rien dire.

## 7. Les réglages, tous au même endroit

En tête de `04e_crue.py`. Une ligne changée, on relance, on lit le tableau imprimé.

| | Ce que ça décide |
|---|---|
| `PENTE_GAUCHE` · `PENTE_DROITE` | combien de mètres de sol pour 1 m de hauteur — grand = plat = noyé |
| `BERGE_DROITE_M` | 🔴 le décrochement de la terrasse. **À 0, la crue mord la ville** |
| `NIVEAU_OUVERTURE_M` | la crue qui a eu lieu — l'état de départ |
| `NIVEAU_ANNONCE_M` | celle qu'on annonce : c'est elle qui fait `alea` |
| `SEUIL_RUINE` | 🔴 la hauteur sous plafond d'un rez-de-chaussée. Au-dessus, on rase |
| `SEUIL_SINISTRE` · `SEUIL_MOUILLE` | l'eau passe la porte · l'eau a touché |
| `PONTS_CASSES` | 🎚️ level design pur, corrigé à la main |

Le rendu, lui, se règle dans `palette.py` (`LIMON`, `RUINE_MUR`, `GRAVATS`, `salir`) et dans `07` (`RUINE_PANS`, `RIVE_GAUCHE_Y`, `RIVE_DROITE_Y`, `PONT_COUPE_MARGE`, `PONT_RUINE_BOUT`, `PONT_RUINE_CHUTE`).
