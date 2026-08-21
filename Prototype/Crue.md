# La crue — le faubourg sinistré

> **Branche `crue`, pas `master`.** L'étape ouverte du prototype reste la **4 — Toits et sol**.
> Ce chantier est une reprise de la décision **23b**, suspendue depuis le 2026-08-12. Il ne se fusionne pas tant que l'auteur n'a pas tranché les deux questions du § 5.
> Critère de réussite visé : **on ouvre la maquette et on voit tout de suite ce que l'eau a pris.**

## 1. Où ça en est

| | | |
|---|---|---|
| la donnée | ✅ | `04e_crue.py`, dans la chaîne après `04d` |
| les dégâts au bâti | ✅ **à regarder** | touche `F` |
| le pont emporté | ✅ **à regarder** | touche `N` |
| `alea` rallumé | ✅ | l'îlot dit ce qu'il risque, pas seulement ce qu'il a pris |
| **le choix du joueur** | ☐ | les trois postures — § 4, à arbitrer avant d'écrire |

```bash
python QGIS/scripts/chaine.py --godot
```

Puis lancer la maquette, `F` d'abord, `N` ensuite. **Ce qu'il faut voir** : des murs **sans toit**, gris pâle, le long de l'eau en rive gauche · le limon sur les rues et les jardins du faubourg, et **une limite** quelque part au lieu d'une rive entièrement sale · la ville d'en face **intacte** · la chaussée qui s'arrête net des deux côtés du pont 168, sans tablier au-dessus du vide.
**Ce qui prouverait que c'est cassé** : une ruine en rive droite · zéro ruine (`04e` n'est pas passé — l'export le dit en clair) · un tablier ou un parapet qui flotte au milieu de l'Ilse · le faubourg entier gris (alors la couleur ne dit plus l'époque, et l'étape 4 est perdue).

## 2. Le modèle, et pourquoi il n'est pas celui d'avant

L'essai du 2026-08-12 cherchait une **portée en mètres** et retombait sur la même carte de risque que l'altitude — *« la règle changeait, pas la carte »*. Celui-ci met la **hauteur d'eau en mètres** au centre : c'est elle, et rien d'autre, qui sépare une maison mouillée d'une maison perdue.

Le sol monte quand on s'éloigne de l'eau. **La rive gauche est la plaine, la rive droite est la terrasse** — deux pentes et un décrochement. C'est le décrochement, et lui seul, qui tient la décision 23b : la ville regarde le faubourg se noyer. La plaine s'élargit vers l'aval, donc la pente de rive gauche se couche avec `position_fil_eau`.

🔴 **La carte reste plate.** Ce profil est un profil de **calcul** ; aucune géométrie ne monte, `altitude_relative` reste à 0.

**Une seule règle, deux niveaux d'eau** : la crue d'ouverture est ce qui **est** arrivé, la crue annoncée est ce qui **peut** arriver — donc `alea`. Sur le même îlot le joueur lit les deux, et c'est ça le calcul que 23b réclame.

## 3. Ce que la carte dit maintenant

Tout se réimprime à chaque passage de `04e` : rien de ce qui suit ne s'archive.

| | rive gauche | rive droite |
|---|---|---|
| bâtiments ruinés | 18 | **0** |
| bâtiments sinistrés | 100 | 0 |
| mouillés · intacts | 20 · 1 | 0 · 618 |
| `alea` moyen (crue annoncée) | **0,77** | 0,02 |

**369 logements sinistrés sur les 417 du faubourg.** Le vault annonçait un aléa de 0,75 en rive gauche : la nouvelle règle retombe à 0,77 sans avoir été calée dessus — c'est le contrôle le plus solide qu'on ait sur le modèle.

Les îlots vont de **69** (72 % de son bâti détruit, 4 bâtiments) à **61** (rien de ruiné, 6 logements touchés) : le faubourg n'est pas une tache uniforme, et c'est ce qui rend le § 4 possible. Le tableau complet sort de `04e`.

**35 tronçons sur 178** ont gardé du limon.

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

## 5. Les deux questions pour l'auteur

- 🔴 **La rive droite est-elle vraiment hors d'atteinte ?** Le vault annonçait un aléa de **0,43** en face ; le modèle en donne **0,02**. Les deux se défendent : soit la ville est sur une terrasse et ne risque rien — ce qui rend le faubourg d'autant plus injuste, et colle à 23b — soit la crue annoncée doit mordre le front de quai, et alors `BERGE_DROITE_M` descend. **Le second indicateur « ville exposée » (54) n'a pas le même sens selon la réponse.**
- 🔴 **Quels ponts, et dans quel état ?** La proposition coupe **168** et fragilise **169**. 168 est celui que `02_qualifier.py` déclare intouchable — *seul accès des 279 logements du faubourg*. Le couper est exactement l'intérêt : la crue prend au joueur ce qui reliait le faubourg à la ville, et « rendre à l'eau » cesse d'être une lubie pour devenir l'option qui **économise un pont**. Mais ça contredit la contrainte écrite en 30c (*le faubourg garde un accès qui n'est pas le quai*). **Une ligne de `04e` suffit à changer d'avis.**

## 6. La dette de ce chantier

- 🔴 **Le report de trafic n'existe pas.** Un pont coupé reste dans `routes` : `charge` ne bouge pas, l'axe de transit non plus. Le réseau routier n'est donc plus d'un seul tenant **à l'écran** alors qu'il l'est **dans les données** — le contrôle de connexité de `03` passe toujours, et il a raison de passer, mais il ne dit plus la vérité de l'image.
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

Le rendu, lui, se règle dans `palette.py` (`LIMON`, `RUINE_MUR`, `RUINE_TOIT`, `salir`) et dans `07` (`RUINE_NIVEAUX`, `PONT_COUPE_MARGE`).
