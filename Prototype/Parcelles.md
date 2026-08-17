# Étape 2 — Les parcelles 🎯

> **L'étape en cours.** Le point dur du pipeline : ce qui sépare 70 pâtés pleins d'une ville où on croirait habiter.
> La doctrine — *pourquoi* la parcelle est une partition, ce qu'on ne fera jamais — est dans le vault : `Technique/Génération procédurale.md`. **Ici, le chantier seulement.**

**Dernière mesure : 2026-08-17** (session 25, chaîne complète jusqu'à l'export Godot)

✅ **LA CARTE NE PEUT PLUS ÊTRE PLUS VIEILLE QUE LE CODE** (2026-08-17). Elle l'était : `Prototype_qualifie.gpkg` avait été écrit au commit `18a6b4c`, **avant** `c409680` — celui qui coupe au milieu quand l'îlot est assez profond — et une session entière est passée à décrire un défaut déjà corrigé. Ce qui a fermé le piège : le `.gpkg` n'est plus versionné, et `02` le **rebâtit depuis la source** à chaque passage de `chaine.py` (0,7 s). Les chiffres de la section 2 sont mesurés sur la carte relancée le 2026-08-17.

---

## 1. Ce que l'étape doit produire

Une couche `parcelles` dans le GeoPackage, écrite **une fois**, qui pave l'emprise bâtie de chaque îlot sans trou ni recouvrement. Le générateur : `QGIS/scripts/04c_parcelles.py`.

**Les deux décisions qui commandent, et qu'aucun réglage ne peut contredire :**

| | |
|---|---|
| **61** — la parcelle est une **partition** de l'emprise | le générateur **découpe**, il ne pose pas des formes dans un vide. Deux voisines partagent une arête exactement : le mitoyen sort de la géométrie, ce n'est pas un raccord à faire |
| **35** — la parcelle est l'**entité persistante**, seedée individuellement | régénérer le bâtiment d'une parcelle n'en touche aucune autre. La partition est calculée ici puis **écrite** : ⚠️ elle ne se rejoue **jamais** à l'affichage, sinon on ré-effondre le voisinage à chaque clic, comme Townscaper |

## 2. Où c'en est — les chiffres mesurés

| | code d'aujourd'hui | carte du dépôt (périmée) |
|---|---|---|
| parcelles | **927**, dont **912 sur rue** — plus **6 chemins** | 1 096, dont 987 sur rue |
| cœurs d'îlot | 13 îlots, 0,86 ha, en 15 morceaux **d'un seul tenant** (67c · 67d) | 102 morceaux redécoupés |
| reliquat de rue sans façade | **0** — il n'y a plus de déchet | 7 |
| réunions d'éclats | 121, **aucun ne survit** | 48 |
| coupes effacées (deux biseaux → un rectangle) | **2**, îlots 13 et 33 | — |
| partition | **100,00 %** sur chacun des 54 îlots, écart max 8,1·10⁻⁷ | idem |

🔴 **Le nombre de parcelles a BAISSÉ, et ce n'est pas une régression.** Les 1 105 d'avant comptaient les cœurs d'îlot redécoupés en dizaines de morceaux et les fonds de jardin sans façade. Depuis **67c** un cœur reste entier ; depuis **67d** ce qui reste derrière les parcelles reste un cœur au lieu d'être recollé à une parcelle de rue. Ce qui compte est le **912 sur rue** — que 67d n'a pas bougé et que le plafond de profondeur du 2026-08-15 a remonté de 893 — et le fait que les **enclavées soient tombées à zéro**. → mémoire : *le nombre de maisons n'est pas un critère*.

**L'élancement, tissu par tissu** — le rapport du grand axe au petit, qui était le vrai défaut avant le peigne :

| | mesuré | visé | |
|---|---|---|---|
| `maisons_de_ville` | 2,24 | 2,32 | ✅ |
| `coeur_ancien` | 2,08 | 2,29 | ✅ |
| `pavillonnaire` | 1,87 | 2,07 | ✅ |
| `front_commercant` | 1,48 | 1,64 | ✅ |

**La rectangularité** — aire ÷ aire du rectangle englobant, le nombre qui juge les chemins (67b) : **0,83 en moyenne** avant venelle, et de 0,84 à 0,91 sur les six îlots qui en portent une.

## 2 nonies. 🕳️ L'encoche du bâtiment — corrigé le 2026-08-17 (2)

**Ce que l'auteur a vu**, sur les mêmes îlots, avec le contour rouge par-dessus l'image : *« l'îlot 40 a encore des parcelles bizarres avec des formes de bâtiment pas réalistes, et l'îlot 41 a des coins encore à corriger »*.

C'est la suite annoncée à la fin du §2 octies — « des doigts de cour qui rentrent dans la masse, et de petits ressauts en escalier ; ça demanderait une **ouverture morphologique**, pas un seuil de plus ». Elle est écrite, du côté du bâtiment.

**Le critère est le NOMBRE de décrochements, pas une largeur.** Mesuré avant d'écrire la règle, sur les 701 empreintes :

| sommets rentrants | empreintes | ce que c'est |
|---|---|---|
| 0 | 542 | la barre, le rectangle |
| **1** | 131 | **l'équerre** : immeuble d'angle, maison + aile arrière — voulues |
| 2 | 26 | l'escalier, le U |
| 3 | 2 | le C |

🔴 **Et un seuil de largeur ne sait pas les séparer**, c'est mesuré : rallumer l'aile arrière fait passer les poches à bouche ≤ 8 m de 14 à 57. La bouche d'une équerre juste et celle d'un ressaut font la même largeur ; c'est leur **nombre** qui diffère. Une empreinte a donc droit à **un** décrochement, jamais deux — et on referme **la plus petite poche d'abord**, parce que sur une parcelle d'angle la grande poche est la cour que l'équerre entoure, et la petite est la dent qui pend dedans.

**Deux règles, dans deux fonctions.**

- 🏚️ **L'aile arrière est enfin vérifiée adossée** (`aile_arriere`). Sa docstring promettait « adossée à une limite LATÉRALE et jamais posée au milieu » depuis le premier jour — rien ne le contrôlait. L'aile se pose à un **bout de la cour** mesuré le long de la façade ; sur une parcelle de rangée ce bout est bien la limite mitoyenne, mais sur une parcelle **d'angle**, dont le bâtiment est déjà la réunion de deux bandes, c'est le mur de l'autre bande. On essaie donc les deux bouts, le tiré d'abord, et on ne garde que celui qui pose vraiment une joue sur la limite de la parcelle (`AILE_ADOS` 0,15).
- 🕳️ **L'encoche se referme** (`fermer_encoches`), **après l'aile et pas avant** — l'aile fabrique volontairement un décrochement, donc juger la forme avant elle ne verrait pas l'escalier qu'elle produit sur une parcelle d'angle.

🔴 **Le piège qui a coûté la moitié de la mise au point** : la corde qui referme une poche a ses deux bouts **sur la limite de parcelle** (le retrait latéral vaut 0 en mitoyen). Testée telle quelle, elle tombe du mauvais côté du test de parité et **toutes** les encoches se refusaient — 12 refermées au lieu de 52. On teste donc des points décalés de 10 cm **vers l'intérieur de la poche**.

**Ce que ça donne, mesuré :**

| | avant | après |
|---|---|---|
| empreintes à **deux** décrochements ou plus | 28 | **15** |
| … dont à trois (le C) | 2 | **0** |
| encoches refermées | — | **52**, sur 52 bâtiments |
| bâtiments hors de leur parcelle (R0) | 0 | **0** |
| façades reculées (R2 bis) | 16 | **16** — inchangé |
| emprises · cour du cœur ancien | 0,76 · 0,56 · 0,81 · 24 % | **inchangées** |
| surface de toit | 9,00 ha | **9,02 ha** |

⚠️ **Les 15 qui restent** sont refusées par `ENCOCHE_AIRE_MAX` (45 m²) : leur poche est plus grande que ça, donc on ne sait pas encore dire si c'est une encoche ou la cour. Îlots 13, 28, 29, 30, 40, 43, 50, 58, 62, 66.

🔴 **Et l'îlot 40 n'est réparé qu'à moitié — ce qu'il reste est dans la PARCELLE, pas dans le bâtiment.** Dans le bout sud-est que l'auteur a entouré : la parcelle **435** sort en dard (116 m², une flèche), la **443** en lanière (89 m² pour 2,0 m de façade au bout), et la **438** porte deux petits replis hérités de la découpe. Mesuré : **118 parcelles de rue sur 809 ont au moins un sommet rentrant**, et le compte ne bouge pas quand on éteint la soudure des coins (119 → 118) — **ce n'est donc pas la soudure, c'est le peigne**. → [CHANTIERS.md](CHANTIERS.md)

## 2 octies. 🏢 Le coin d'îlot — corrigé le 2026-08-17

**Ce que l'auteur a vu**, sur les îlots 40, 41 et 59, et il l'a dessiné trois fois par-dessus l'image : *« j'aimerais bien que les coins ressemblent à l'emprise du bâtiment que j'ai dessiné. Limite, tu peux fusionner plusieurs parcelles de coin (quitte à ce qu'elles soient un peu grandes) pour que les bâtiments puissent avoir cette forme. Sinon le reste fonctionne plutôt bien, c'est surtout les coins d'îlots que je trouve encore problématiques. »*

Le tracé rouge disait la même chose aux trois endroits : **une masse continue qui tourne la rue**, au lieu de deux bouts de mur et d'un trou entre eux.

**Deux causes, une par script, et il fallait les deux.**

| | Où | Ce que c'était |
|---|---|---|
| ① **le coin n'a qu'un bras** | `04c` | la rue la plus longue est servie la première et prend le coin (le débordement de `_bande`). La parcelle du coin a donc une façade normale sur la rue longue et un simple **flanc** sur la rue courte. Mesuré sur les 163 coins de rue des tissus mitoyens : façade forte 16,2 m en médiane, **façade faible 7,4 m**, et 34 coins sous la moitié de la consigne du tissu |
| ② **le bâtiment sort en C** | `04d` | la réunion des deux bandes laisse derrière elle un coin dont **la pointe vise le coin de rue**. Le bâtiment en fait le tour : une cour creusée en plein milieu de la masse au lieu d'être derrière elle. C'est exactement la forme que le tracé rouge remplace |

**Les deux règles.**

- 🏢 **La parcelle d'angle** (`souder_les_angles`, quatrième passe de `04c`) — la parcelle du coin absorbe sa voisine **du côté faible**, tant que son bras court n'atteint pas 1,5 façade. Le geste est celui de `recoller_rectangles` — `fusionner`, donc la partition (61) ne peut pas tomber — mais le critère est l'inverse : là on efface une coupe parasite, ici on **assume une parcelle plus grande** parce que le coin en demande une.
  - 🔴 **Trois garde-fous, et sans eux la règle dérive en « le coin avale la rangée »** : on ne réunit que vers la rue faible (une voisine sans façade sur cette rue-là est écartée d'office) · aucun bras au-delà de 2,6 façades · aucune parcelle au-delà de 2,2 fois l'aire visée du tissu. Mesuré sans le plafond d'aire : l'îlot 41 tombait à 9 parcelles dont deux de 460 et 630 m², un front de rue entier par parcelle.
  - 🔴 **Un coin n'est pas toujours un sommet**, et c'est la moitié des coins de Wehrau : beaucoup sont **biseautés**, deux sommets séparés par un pan coupé de deux ou trois mètres. Pris sommet par sommet, un biseau donne deux virages de 15°, donc aucun angle, donc aucun coin — la pointe de l'îlot 59 et le nord-ouest de l'îlot 40 passaient à travers. On raisonne donc sur les arêtes assez longues pour porter une rue, et le biseau reste **au milieu** du coin. 163 coins deviennent 173.
- 🕳️ **Une cour n'est pas un trou** (`bande_sur_rue`, dans `04d`) — une tranche d'arrière **enfermée par le bâtiment** repart au bâtiment. Le partage se lit sur l'**ouverture** : la part du contour de la tranche qui est du bord de parcelle et non du mur. Une cour de fond est bordée par le fond et les deux côtés (0,5 et plus) ; une poche entre deux ailes n'a qu'un côté (0,25 et moins). **152 poches comblées.**

**Ce que ça donne, mesuré :**

| | avant | après |
|---|---|---|
| coins dont les **deux** bras tiennent la consigne | 48 sur 163 | **122** |
| coins sous la moitié de la consigne | 34 | **16** |
| façade faible d'un coin, médiane | 7,4 m | **12,6 m** |
| aire de la parcelle d'angle, médiane | 148 m² | **278 m²** |
| bâtiments à **trois** coins rentrants ou plus (le C) | 7 | **2** |
| parcelles · dont sur rue | 927 · 912 | **809 · 794** |
| bâtiments · surface de toit | 810 · 8,86 ha | **701 · 9,00 ha** |
| emprise cœur ancien · maisons de ville · front commerçant | 0,76 · 0,56 · 0,81 | **0,76 · 0,56 · 0,82** — inchangées |
| cour en cœur ancien | 24 % | **24 %** |
| bâtiments hors de leur parcelle (R0) | 0 | **0** |
| façades reculées de leur rue (R2 bis) | 19 | **16** |
| partition (61) | 100,00 % | **100,00 %**, écart max 7,9·10⁻⁷ |

🔴 **Le nombre de parcelles baisse de 118, et c'est le prix affiché de la règle** — une réunion par coin soudé, 118 sur 36 îlots. L'auteur l'a autorisé dans la demande (« quitte à ce qu'elles soient un peu grandes ») et la mémoire du projet le redit : *le nombre de maisons n'est jamais un critère*. Le pavillonnaire n'est pas touché — une maison détachée ne tourne pas un coin de rue.

**Trois choses essayées et retirées, à ne pas refaire :**

1. ❌ **Un seuil de largeur de cour seul** (« sous 3 m ce n'est plus une cour »). Mesuré : **434 cours sur 701** tombaient dessous — la cour médiane du cœur ancien fait 22 m² derrière une parcelle de 9,5 m, donc 2,3 m de profondeur. Le seuil annulait la correction de la veille en une ligne. Il ne sert qu'**avec** un critère d'ouverture (le « doigt » : étroit **et** à moitié bordé de mur).
2. ❌ **Recoller les tranches d'arrière avant de les juger.** C'est pourtant l'unité qui semble juste — sauf qu'une tranche est une région de l'arrangement des demi-plans, donc soit derrière le bâtiment, soit dedans. Recollées, la poche du coin fusionne avec la cour de fond, l'ouverture repasse au-dessus du seuil, et **le C de l'îlot 40 revient tel quel**.
3. ❌ **Combler une poche sans vérifier qu'elle recolle.** `fusionner` renonce quand le bord commun n'est pas contigu, et le morceau ressortait alors en **second bâtiment posé dans la cour** — cinq parcelles comptées « traversantes » sans l'être.

⚠️ **Ce qui reste, et que l'auteur a entouré sur l'îlot 41 :** des **doigts** de cour qui rentrent encore dans la masse, et de petits ressauts en escalier. Le critère du doigt en attrape une partie ; le reste demanderait une **ouverture morphologique** de la cour, pas un seuil de plus.

## 2 septies. 🏠 Le bâtiment n'est plus la parcelle — corrigé le 2026-08-17

**Ce que l'auteur a vu, sur `parcelles_ilot_14.png` :** *« les bâtiments ressemblent trop aux parcelles »* — des corps très profonds, des trapèzes, aucun jardin, aucune cour, aucun arrière. Et sur les deux emprises supprimées de ce même îlot : *« ce ne sont pas vraiment des cours, ce sont simplement des parcelles soudainement vides »*, une grande brèche en L au lieu d'une respiration.

**La cause était dans la table `TISSU` de `04d`, pas dans la géométrie.** Le cœur ancien et les maisons de ville avaient `profondeur = None` — « aucune règle de profondeur, l'empreinte EST la parcelle ». Résultat mesuré : le cœur ancien couvrait **0,96** de son terrain, le front commerçant **0,86**.

Cette règle venait d'une demande juste — les maisons de ville ont une profondeur variable, et une profondeur comptée depuis **une seule** façade tranchait en biais les parcelles d'angle. Mais le remède avait **supprimé la profondeur au lieu de réparer le coin**.

**La correction, en une phrase :** le bâtiment est une **bande mesurée depuis chaque limite sur rue**, d'une profondeur donnée par le tissu ; tout ce qui reste derrière est cour ou jardin.

| | avant | après | visé (auteur) |
|---|---|---|---|
| emprise `coeur_ancien` | 0,96 | **0,76** | 55–80 % |
| emprise `maisons_de_ville` | 0,65 | **0,56** | 40–65 % |
| emprise `front_commercant` | 0,86 | **0,81** | 60–85 % |
| emprise `pavillonnaire` | 0,21 | **0,20** | 20–35 % |
| **cour** en cœur ancien | **4 %** | **24 %** | 15–30 % |
| bâtiments sortant de leur parcelle (R0) | 0 | **0** | 0 |
| façades reculées de leur rue (R2 bis) | 22, jusqu'à 11,7 m | **19, jusqu'à 7,7 m** | 0 |
| surface de toit | 10,12 ha | **8,86 ha** | — |

**Le coin est réparé sans supprimer la profondeur** : la bande de chaque rue est un demi-plan, le bâtiment est leur **réunion**. Une parcelle d'angle porte donc un immeuble en L qui suit ses deux rues, comme un immeuble d'angle réel. Le calcul ne demande aucune bibliothèque géométrique : la réunion des bandes est le complément de l'**intersection** des arrières, et `04c._soustraire_convexe` — écrit pour les venelles — sait déjà retirer une intersection de demi-plans.

🔴 **Ce qui a été pris pour un défaut et qui était la bonne réponse : une parcelle peut porter DEUX bâtiments.** Sur 37 parcelles la bande sort en deux morceaux qui ne se touchent nulle part (`bord_partage` = 0, vérifié). Ce sont les parcelles **traversantes** — une rue devant, une rue derrière — et deux bâtiments y sont juste : une maison sur chaque rue, le jardin entre les deux. La première version n'en gardait que le plus grand et jetait jusqu'à 87 m², ce qui reculait la façade de l'autre rue de toute la profondeur du jardin. C'était R2 bis, réintroduit par sa propre correction.

**Les trois autres points de la même relecture :**

- ✂️ **La pointe repart au jardin** — *« les pointes et angles aigus sont presque toujours bâtis. Or dans la réalité ces endroits deviennent souvent un jardinet, une cour, un passage. »* Une parcelle dont l'angle le plus aigu passe sous **30°** n'est plus bâtie, sauf une sur six gardée comme exception remarquable : **18 rendues au jardin, 7 gardées**. C'est aussi la réponse au point 4 de l'îlot 59, « traiter la pointe gauche comme un jardin ».
- 🏚️ **L'aile arrière** — 20 à 35 % demandés, **81 posées**. 🔴 Elle se **paye sur la profondeur de la bande** au lieu de s'y ajouter : posée en plus, elle n'entrait jamais dans la cour (22 m² en médiane) et, quand elle entrait, elle poussait l'emprise au-dessus du plafond que le rabot rendait aussitôt en raccourcissant **tout** le bâtiment. Même surface bâtie, cour en L au lieu de cour en bande — ce qui est exactement la demande, « éviter une cour trop régulière ».
- 🌿 **Les 15 parcelles sans façade** — mesuré avant d'écrire quoi que ce soit, et ça a annulé le travail prévu : ce sont **exactement les 15 cœurs d'îlot**. Aucune parcelle n'est enclavée par accident. Elles étaient donc déjà une catégorie assumée ; ce qui les faisait *lire* comme un résidu était leur **forme**, et c'est la règle de la pointe qui y répond.

⚠️ **Deux réserves à porter au regard de l'auteur.**

1. **La cour intérieure existe mais elle n'est pas commune.** Chaque parcelle garde sa propre tranche d'arrière, donc le cœur de l'îlot 14 sort en couloir sinueux plutôt qu'en cour unique. Aligner les fonds de bâti d'une même rangée est un travail à part — et il tire dans le sens inverse des ailes arrière, qui existent pour irrégulariser. À trancher devant l'image.
2. **Le passage étroit de la rue vers la cour n'est pas fait** — c'est une venelle, donc `tracer_chemins.py`, donc du level design qui appartient à l'auteur.

🔴 **ET LE PLUS IMPORTANT : LA 3D NE MONTRE RIEN DE TOUT ÇA.** `04d` manquait à `chaine.py` — il l'annonçait dans son propre en-tête sans y être — donc la carte de travail n'avait aucune couche `batiments` et les aperçus sortaient sans bâtiment. C'est réparé. Mais **`07_exporter_godot.py` garde son propre générateur** : sa table `BATI`, et `04b.retracter` pour l'offset, qui est la cause des « 44 bâtiments qui débordent ». Deux règles vivent donc en parallèle — celle-ci décide des **aperçus PNG**, celle de `07` décide de la **maquette Godot**, et les deux chiffres de toit ne peuvent pas coïncider (8,9 ha ici, 12,1 ha annoncés par `07`). Le branchement est écrit dans l'en-tête de `04d` ; il demande Godot sous la main, donc il ne se fait pas à l'aveugle depuis le Mac.

## 2 bis. Ce que l'auteur a vu sur l'image, le 2026-08-14

Trois défauts désignés sur l'aperçu, et ils n'ont pas eu la même réponse.

| | Ce qu'il a vu | Où ça en est |
|---|---|---|
| 1 | **îlots 64 et 69** — « la séparation doit se faire au milieu ». Une seule rangée prenait tout le fond (28 m sur 34 en 64), celle d'en face se contentait du reste | ✅ **déjà corrigé dans le code**, par `c409680`. Ce qu'il regardait était la carte périmée. Rien à écrire, tout à relancer |
| 2 | **îlot 32** — « pas de parcelles, les deux barres seront posées au milieu de l'îlot sans considération du tissu urbain bâti (urbanisme des années 70) » | ✅ **fait** — la barre passe du peigne à la **boîte** (§5). L'îlot sort en **2 parcelles de 5 579 m²** au lieu d'un anneau de 7 parcelles de rue autour d'un cœur vide |
| 3 | **îlot 24** — « parcelles bizarres, triangulaires » | ⚠️ **mesuré, pas corrigé** — deux remèdes essayés, les deux moins bons que le mal (§6 bis) |
| 4 | **îlots 10, 33, 49, 50, 66** — « les cœurs d'îlots sont fusionnés avec les parcelles » | ✅ **fait** (§2 quater) — la profondeur du tissu redevient un plafond, et ce qui reste derrière est un cœur |

## 2 bis bis. Ce que l'auteur a vu sur l'image, le 2026-08-15

Deux endroits, deux causes différentes, les deux corrigés. Verdict de l'auteur devant l'image : *« c'est bien mieux »*.

| | Ce qu'il a vu | Ce que c'était |
|---|---|---|
| 1 | **îlots 63 et 26** — « la direction des parcelles », avec des traits dessinés en travers du bout de l'îlot | le **petit côté** d'un îlot allongé réclamait 58 m de fond pour 28 visés → §2 quinquies |
| 2 | **îlot 13** — « deux triangles peuvent former un rectangle », légendé *« devrait n'être qu'une parcelle »* | une **coupe parasite** en diagonale dans un rectangle → §2 sexies |

## 2 quinquies. La direction des parcelles — corrigé le 2026-08-15

**Ce que c'était.** Le pavillonnaire est dans `SANS_COEUR` : la profondeur visée n'y est plus un plafond, pour que les deux rangées d'un lotissement se rejoignent au milieu sans rien laisser entre elles. Mais la profondeur se mesure **par rapport à l'arête servie**. Sur le petit côté d'un îlot allongé, le rayon part dans le sens de la **longueur** de l'îlot et ressort 117 m plus loin : la moitié, 58 m, devenait la profondeur de la bande.

Le bout de l'îlot sortait donc en dalles de 17 × 58 m **couchées en travers du tissu**, à contresens des deux rangées d'à côté. Mesuré : îlot 63 arêtes est à 58,6 et 59,7 m, îlot 26 à 46,7 et 36,2 m — pour 28 m visés.

**La règle.** Le plafond ne se lève que si la rue d'en face est assez près pour que les deux rangées se touchent vraiment — au-delà de `PROF_MAX` fois la consigne, la profondeur visée redevient un plafond, même en pavillonnaire.

| plafond | parcelles sur rue | trop profondes | aire > 2× la cible |
|---|---|---|---|
| éteint — l'ancien code | 893 | **18** | 9 |
| 2,0 | 901 | 12 | 5 |
| 1,6 | 911 | 9 | 5 |
| **1,3 — retenu** | **914** | **9** | 7 |
| 1,0 | 916 | 10 | 5 |

*Trop profonde* = extension perpendiculaire à la façade au-delà de 1,5 fois la consigne du tissu. 1,3 est pris au genou de la courbe : le défaut tombe de moitié, et il reste assez de marge pour qu'un lotissement dont les deux rangées se rejoignent un peu plus loin que la consigne les rejoigne quand même.

**Ce que ça donne**, avec la correction suivante par-dessus :

| | avant | après |
|---|---|---|
| parcelles sur rue | 893 | **912** |
| profondeur moyenne des rives pavillonnaires | 30,8 m | **25,7 m** (28 visés) |
| enclavées | 0 | **0** |
| cœurs d'îlot | 15 | **15** — inchangés |
| partition (61) | 100,00 % | **100,00 %**, écart max 8,1·10⁻⁷ |

## 2 sexies. Deux biseaux qui refont un rectangle — corrigé le 2026-08-15

C'est **le remède annoncé et jamais écrit du §6 bis** : celui qui ne coûte rien. Le seuil d'angle jugeait la pointe **toute seule**, la déclarait irrécupérable et la faisait avaler par sa voisine — 132 parcelles de rue perdues, 14 % des maisons. Ici on juge **la paire**, et on se contente d'effacer une coupe qui n'aurait pas dû exister.

Les deux morceaux de l'îlot 13 : 67 m² à 0,52 de rectangularité et 78 m² à 0,55, réunis en **145 m² à 1,00**, quatre sommets, angle mini 90°.

🔴 **Le critère n'est pas l'angle, c'est le gain.** Les deux parcelles de l'îlot 13 ont chacune un angle mini de **63,8°** : aucun seuil de pointe ne les aurait vues. Balayage sur les 893 parcelles de rue — la stabilité du compte dit que la règle vise juste :

| gain ≥ | réunion ≥ 0,95 | ≥ 0,90 | ≥ 0,85 |
|---|---|---|---|
| 0,30 | 1 | 1 | 1 |
| 0,20 | 1 | 1 | 1 |
| **0,15** | 1 | **2** | 2 |
| 0,10 | 1 | 2 | 2 |

**Deux paires en ville, pas deux cents** : îlots 13 et 33. La règle ne redessine rien, elle ramasse la coupe parasite là où elle est. Le compte s'imprime à chaque passage — s'il s'emballe un jour, c'est le peigne qui coupe de travers en amont, et c'est là qu'il faudra aller voir.

## 2 quater. Le cœur d'îlot rendu aux parcelles — corrigé le 2026-08-14

**Ce que l'auteur a vu** : sur les îlots 10, 33, 49, 50 et 66, une parcelle deux à trois fois plus grosse que ses voisines, qui remplissait tout le milieu de l'îlot. *« Les cœurs d'îlots sont fusionnés avec les parcelles. »*

**Ce que c'était.** Un morceau de cœur devait être large **et** sans pointe pour compter comme cour ; sinon il repartait aux parcelles de rue voisines. Sur un îlot en éventail le milieu est toujours un peu pointu, donc il repartait presque toujours — et il repartait **en bloc**, parce que la parcelle qui venait d'en avaler un morceau devenait la plus grande voisine du morceau suivant, donc gagnait encore. Effet boule de neige, mesuré : le cœur de l'îlot 33 (741 m²) finissait entier dans **une** parcelle de 651 m².

**La règle de l'auteur, qui remplace tout ça** → `Décisions arrêtées` **67d** :

> *Pour les grands îlots, les parcelles vont seulement une certaine profondeur jusqu'au centre. La surface qui reste est un cœur d'îlot.*

**Ce qui a changé dans le code**, trois choses :

| | |
|---|---|
| **Un cœur a le droit d'être pointu** | `COEUR_ANGLE_MIN` passe à **0**, éteint. Une pointe au fond d'un îlot en éventail est de la ville |
| **Le seuil de minceur descend** | `COEUR_MIN_LARGE` **10 → 8 m**. Les restes des îlots 10 (9,8 m), 49 (9,6 et 8,1) et 50 (9,2) tombaient juste sous la barre |
| **Une parcelle ne reçoit qu'un seul reste** | le garde-fou anti-boule-de-neige, dans `absorber`. Il ne sert plus que pour le pavillonnaire et les vraies lamelles, mais c'était le vrai bug |

**Ce que ça donne, mesuré sur la copie de `bac/` :**

| | avant | après |
|---|---|---|
| parcelles **sur rue** | 893 | **893** — inchangé |
| cœurs d'îlot | 9, en 9 morceaux | **15**, en 15 morceaux, 0,86 ha |
| parcelles au-delà de 2× l'aire de leur tissu | **11**, jusqu'à 3,1× | **0** sur les îlots entourés |
| partition (61) | 100,00 % | **100,00 %**, écart max 8,1·10⁻⁷ |

⚠️ **Une piste essayée et retirée, à ne pas refaire** : repeigner l'îlot **sans plafond de profondeur** quand aucun morceau n'était une cour, pour que les deux rangées se rejoignent au milieu et qu'il ne reste rien. L'image était propre — et c'est l'inverse de 67d. L'avertissement est écrit dans `04c` à l'endroit exact.

## 2 ter. La forme, qui était le vrai défaut avant le peigne

L'aire tombait juste depuis le début ; c'est l'élancement qui était faux — un cœur ancien sortait en carré de 10,6 m au lieu d'une lanière de 7 × 16. Le **peigne sur rue** (méthode Vanegas et al., Eurographics 2012) l'a corrigé, et les **parcelles sans façade sont passées de 30 % à 10 %**.

## 3. Le critère de réussite — et il ne se juge pas ici

L'étape n'est pas finie parce que le script tourne. Elle finit sur **deux images** :

1. 🔴 **La surface de toit mesurée retombe sur le coefficient de l'énergie** — au-delà de ~15 % d'écart, le potentiel solaire du prototype bouge, et c'est ce chiffre-là qui fait des parcelles autre chose qu'un embellissement. → [Énergie.md](Énergie.md) §4
2. 👁️ **Le cœur ancien ressemble à un cœur ancien** — pas « est-ce que le nombre est juste », mais ***est-ce qu'on croirait y habiter***.

**Comment on regarde** : `python "QGIS/scripts/apercu_parcelles.py"` sort le parcellaire en PNG (`--avant` compare deux versions côte à côte). La lecture tient en deux couleurs — **en couleur de tissu, la parcelle portera une maison ; en vert, elle repart au jardin**. Le vert dispersé au milieu des maisons est le défaut ; le vert rassemblé en cœur d'îlot est le résultat.

🔢 **Le numéro d'îlot est écrit sur l'image, par défaut** (`--sans-fids` pour l'enlever). Sans lui, désigner un défaut oblige à le décrire — « le bloc allongé en haut à gauche » — au lieu de le nommer, et deux personnes qui regardent la même image ne parlent pas forcément du même îlot. Une légende des tissus est en bas de chaque panneau.

## 4. Ce qui reste, dans l'ordre

✅ **Les venelles sont dans la source et la chaîne complète a tourné le 2026-08-17.** La passe à blanc a proposé six tracés, l'auteur les a fait réintégrer, puis `chaine.py --godot` a reconstruit la carte et l'export. Contrôles : **6 venelles sur 6 îlots, 588 m²**, 927 parcelles dont **912 sur rue**, zéro reliquat de rue enclavé, partition à 100,00 %, 15 cœurs et 2 coupes parasites effacées.

1. 👁️ **Juger les parcelles triangulaires en 3D, pas sur la carte** (§6 bis). Le mécanisme qui les supprime existe et il est éteint, parce qu'il coûte 14 % des maisons. La question à trancher devant l'image : est-ce qu'une parcelle en pointe donne une **maison** en pointe, alors que `07` coupe déjà la pointe des bâtiments ?
2. **Regarder le résultat en 3D**, puis les trois défauts imprimés à chaque export :

   | Le défaut | Ce que c'est |
   |---|---|
   | **44 bâtiments sur 892 débordent de leur parcelle**, jusqu'à 5,5 m | pic de mitre sur angle rentrant. Sans commune mesure avec les 258 m de la session 9, mais **un bâtiment sur la chaussée ment** |
   | **70 empreintes concaves prennent un toit plat** | la recette du faîtage suppose qu'un versant avance dans un seul sens. ⚠️ Un repli plus large a été essayé le 2026-08-12 et **retiré devant l'image** |
   | **433 pans de toit réorientés à l'émission (3 %)** | conséquence : le contrôle « faces vers l'extérieur » est vrai **par construction** côté toits et ne prouve plus rien. Le chiffre qui informe est celui des réorientations |

3. **Régler la table `TISSU` de `04c` devant l'image** — c'est du level design, il appartient à l'auteur (§5).
4. ⏸️ **Puis trancher le potentiel solaire** — voir « Ce qui attend l'auteur ».

## 4 bis. 🚶 Le chemin dans l'îlot — nouveau le 2026-08-14

Le peigne ne sait pas découper un **îlot en L** : un L n'a pas de fond. Chaque aile est servie par la rue qui la longe, et le coude reste une masse que personne ne réclame — parcelles en biseau, deux fois trop profondes.

**Ce qu'on a fait, et ce qu'on n'a pas fait.** On ne coupe **pas** l'îlot en deux : l'îlot est l'unité de décision du jeu, 70 îlots restent 70. On y dessine une **venelle**, ni rue ni parcelle, retirée de l'emprise **avant** le peigne. Ses deux parois deviennent alors du bord d'emprise, donc le peigne les sert comme une rue — le coude a un devant et un derrière. → `Décisions arrêtées` **67**

| | |
|---|---|
| **Où le tracé va** | au **pli** : un sommet rentrant de l'emprise, au-delà de 25°. Nulle part ailleurs |
| **Quel tracé** | la **plus courte** traversée qui part du pli. Une venelle courte coupe un coude ; une venelle longue traverse un îlot |
| **Ce qui l'autorise** | la **rectangularité** monte (aire ÷ aire du rectangle englobant, +0,010 au moins) |
| **Ce qui l'interdit** | elle mange plus de 5 % d'un cœur d'îlot · elle ne coupe pas vraiment l'emprise en deux |
| **Ce qui n'est PAS un critère** | 🔴 le **nombre de maisons**. Il se mesure et s'imprime, il ne décide pas → **67b** |
| **La largeur** | **3 à 5 m**, par tissu : 3,0 sente de cœur ancien · 3,5 maisons de ville · 4,0 passage de service · 5,0 desserte de lotissement. La colonne `largeur_m` de la couche prime toujours |

**Les six chemins de Wehrau, réintégrés et mesurés dans la chaîne le 2026-08-17 :**

| îlot | tissu | longueur | largeur | sol pris | rectangularité |
|---|---|---|---|---|---|
| 22 | `coeur_ancien` | 21 m | 3,0 | 38 m² | 0,831 → **0,864** |
| 24 | `front_commercant` | 31 m | 4,0 | 80 m² | 0,822 → **0,856** |
| 26 | `pavillonnaire` | 57 m | 5,0 | 201 m² | 0,850 → **0,869** |
| 38 | `coeur_ancien` | 28 m | 3,0 | 42 m² | 0,831 → **0,851** |
| 44 | `maisons_de_ville` | 61 m | 3,5 | 122 m² | 0,829 → **0,844** |
| 63 | `pavillonnaire` | 44 m | 5,0 | 105 m² | 0,821 → **0,910** |

**588 m² pris à la ville**, soit 0,06 ha de toit en moins pour le solaire. L'îlot **40** figurait dans une mesure de chantier à sept chemins, mais son tracé n'avait jamais été enregistré ; sur la chaîne reproductible il ne passe plus le seuil de rectangularité. Il n'est donc pas dans la source.

**Où vivent les chemins.** Dans **`QGIS/data/source/chemins.geojson`** — la source, seul endroit où un tracé corrigé à la main survit à `02`, qui rebâtit la carte de travail. La couche est **facultative** : sans elle, tout sort exactement comme avant. 🔄 Depuis le 2026-08-17 c'est du **texte, une venelle par ligne**, avec son numéro d'îlot et sa largeur en clair : supprimer une venelle qui tombe mal, c'est supprimer une ligne. La correction se faisait dans QGIS, qui n'existe plus.

**Ce que l'auteur a corrigé, deux fois, et qu'il ne faut pas reperdre :**

1. ❌ **Tracer par le point le plus loin de toute rue** — c'est-à-dire par le **cœur d'îlot**, que la venelle coupait alors systématiquement en deux. *« Les cœurs d'îlots sont à préserver quand c'est possible. »*
2. ❌ **Une recherche par étranglement** (l'endroit où l'îlot est localement le plus mince) : trois venelles de plus, les trois refusées sur l'image. *Un col n'est pas un coude.*
3. ❌ **Un garde-fou « ne doit pas perdre de maisons »**, de mon cru : il poussait la venelle sur la diagonale longue du coude au lieu de couper le bras en travers.

## 5. Les manettes — la table `TISSU` de `04c_parcelles.py`

C'est **elle, et pas le code**, qui décide du grain de toute la ville. Une ligne changée, on relance, on regarde. Depuis le peigne, les deux premières colonnes disent enfin ce qu'elles disent : la boîte ne respectait que leur **produit**.

| `sous_type` | façade (m) | profondeur (m) | méthode | |
|---|---|---|---|---|
| `coeur_ancien` | 7,0 | 16,0 | peigne | fin, très mitoyen |
| `maisons_de_ville` | 8,0 | 20,0 | peigne | le tissu majoritaire |
| `front_commercant` | 11,0 | 18,0 | peigne | vitrines en rez-de-chaussée |
| `pavillonnaire` | 13,5 | 28,0 | peigne | détaché, jardins |
| `barre_1970` | 80,0 | 70,0 | **boîte** | 🔄 2026-08-14 — deux objets posés au milieu |
| `equipement` | 45,0 | 35,0 | boîte | un ou deux objets |
| `dalle_commerciale` | 80,0 | 60,0 | boîte | un hangar |
| `friche_industrielle` | 55,0 | 45,0 | boîte | des halles |

`place_minerale`, `parc`, `champ`, `jardins_familiaux` et `riviere` ne se découpent pas : ce sont des sols.

🔴 **Pourquoi la barre a changé de méthode.** Le peigne la traitait comme un tissu de rue : il en sortait un anneau de parcelles le long des rues et un grand cœur vide au milieu — **l'inverse exact de ce qu'a fait l'urbanisme de 1970**, où la barre se pose en travers de l'îlot sans égard pour l'alignement. La boîte ne connaît pas les rues, donc elle donne ça. 80 × 70 = 5 600 m², soit la moitié des 11 158 m² de l'**îlot 32** — le seul îlot de barre de Wehrau — donc **deux objets**.

**Les cinq manettes du coin** (§2 octies), toutes dans `04c` : `COIN_FACADE` **1,5** (ce que chaque bras doit atteindre, en façades) · `COIN_FACADE_MAX` **2,6** (au-delà ce n'est plus un coin, c'est une rangée) · `COIN_AIRE_MAX` **2,2** (le plafond de la parcelle d'angle) · `COIN_ANGLE` **38–145°** · `COIN_BISEAU_MAX` **12 m**. Et deux dans `04d` : `COUR_OUVERTURE` **0,40** et le doigt (`COUR_LARGEUR_MIN` 3 m, `COUR_DOIGT` 0,50).

**Les trois manettes de l'encoche** (§2 nonies), dans `04d` : `ENCOCHE_RENTRANTS` **1** (le nombre de décrochements tolérés — c'est LA manette) · `ENCOCHE_AIRE_MAX` **45 m²** (au-delà la poche est une cour, pas une encoche) · `AILE_ADOS` **0,15** (ce que l'aile doit poser sur la limite de parcelle).

⚠️ **La table ci-dessus est celle de `04d` et elle n'est pas celle de `04c`** — la vraie table de `04c` dit `maisons_de_ville` **9,5 × 22,0** depuis le 2026-08-14, pas 8,0 × 20,0. Conséquence à connaître avant de toucher au coin : `COIN_AIRE_MAX` plafonne la parcelle d'angle à 2,2 × 209 = **460 m²**, pas 352.

**Les huit réglages de bord**, à ne toucher qu'en sachant pourquoi : plancher de parcelle **45 m²** · jeu de coupe **0,25** (l'irrégularité, sans quoi tout est au cordeau) · dent minimale **0,60 × façade** · arête de moins de **6 m** ne porte pas de rue · seuil de pointe **éteint** (§6 bis) · **largeur minimale d'un cœur 8 m** (`COEUR_MIN_LARGE`, §2 quater) — c'est le seul nombre qui sépare une cour d'une lamelle · **plafond de profondeur 1,3 × la consigne** (`PROF_MAX`, §2 quinquies), qui vaut même en pavillonnaire · **gain de rectangularité 0,15 pour une réunion à 0,90** (`GAIN_RECT`, `RECT_REUNION`, §2 sexies).

⚠️ `LONGUEUR_MIN_RUE` a été balayé de 6 à 15 m le 2026-08-14 : **aucun effet**, ni sur les triangles ni sur le cœur. Les contours d'emprise de Wehrau n'ont pas d'arêtes courtes parasites — ce n'est donc pas là qu'est le défaut.

## 6 bis. Les parcelles triangulaires — ce qui a été essayé, et pourquoi rien n'a été retenu

**Le compte d'abord**, parce qu'il n'existait pas : sur 1 031 parcelles, **41 ont trois côtés** et **56 portent un angle sous 35°**. Environ une sur dix. Les îlots les plus atteints : **40** (7), **13** (5), **22** et **26** (4), **24** et **67** (3).

⚠️ **La première mesure était fausse et il ne faut pas y revenir** : comparer l'aire au rectangle englobant ne bougeait pas d'un pouce quel que soit le réglage, parce qu'elle comptait aussi tous les **parallélogrammes** — qui sont légitimes dès qu'une rue n'est pas perpendiculaire à sa voisine. C'est **l'angle** qui sépare le trapèze honnête du biseau.

**Remède 1 — arrêter la bande au coin rentrant.** L'idée : au coin rentrant, la bande de la grande arête déboule à travers le repli et taille en biseau la région de l'arête suivante. C'est vrai et ça se voit sur l'îlot 24. Mais le remède coûte plus qu'il ne rapporte, et les triangles ne reculent même pas :

| débordement au coin rentrant | triangles | pointues | morceaux de cœur |
|---|---|---|---|
| 1,0 — le forfait actuel | **41** | **56** | **72** |
| 0,5 | 44 | 59 | 86 |
| 0,0 | 47 | 56 | 119 |
| la bissectrice exacte `prof / tan(θ/2)` | — | — | **137** |

La raison de fond, à garder : **une bande est ici une intersection de demi-plans, pas une cellule de squelette**, et deux demi-plans ne se rejoignent pas d'eux-mêmes. Réduire le débordement laisse le coin orphelin.

**Remède 2 — réunir la parcelle en pointe à sa voisine**, comme un éclat. Ça marche, et c'est trop cher : une pointe réunie en refabrique souvent une autre.

| seuil d'angle | parcelles | de rue | triangles | pointues |
|---|---|---|---|---|
| éteint | 1 031 | **993** | 41 | 56 |
| 20° | 958 | 923 | 36 | 31 |
| 30° | 909 | 877 | 23 | 13 |
| 35° | 892 | **861** | 14 | 3 |

Lire la ligne 35° : pour faire tomber 53 pointes on perd **132 parcelles de rue, soit 14 % des maisons de la ville** — et 14 triangles restent quand même. Or ce sont les toits qui portent la décision solaire en attente (§7).

🎯 **Ce qui reste à faire, et où le juger.** Le mécanisme est en place et éteint : `ANGLE_MIN_PARCELLE = 0.0` dans `04c`. **`07_exporter_godot.py` coupe déjà la pointe du BÂTIMENT** (`ANGLE_MIN_DEG = 70`), donc une parcelle en pointe ne donne pas forcément une maison en pointe. **Le vrai juge est la 3D, pas la carte du parcellaire** — c'est là qu'il faut regarder avant de payer 14 % des maisons.

✅ **Le remède gratuit a été écrit le 2026-08-15** → §2 sexies. Il ne rogne pas la pointe : il **efface la coupe** quand deux biseaux voisins se recollent en rectangle. Il coûte 2 parcelles en ville, pas 132. Ce qu'il ne fait pas, et qu'il ne faut pas lui demander : les 22 triangles restants **ne** se recollent **pas** en rectangle — ceux-là attendent toujours le regard en 3D.

## 6. Ce que la méthode a appris, et qu'il ne faut pas reperdre

- **La rue la plus longue prend le coin.** Sinon le coin est orphelin et finit en éclats — 82 morceaux de cœur sur le seul îlot 35.
- **On ne coupe que ce qui touche la rue.** Sinon les droites de chaque arête viennent tailler le cœur à l'autre bout de l'îlot : 236 confettis pour 32 îlots.
- **Un seuil serré n'est pas un seuil sûr.** Le contrôle d'aire des réunions était réglé sur le bruit du flottant (2,4·10⁻⁴ m², soit 2⁻¹² sur des coordonnées à six chiffres) et refusait onze fusions justes. Un tracé faux se trompe de m², le bruit de cm² : deux ordres de grandeur séparent les deux.
- **On coupe par l'aire, pas au milieu géométrique.** L'îlot 34 ne remplit que 67 % de son rectangle englobant ; la coupe médiane le partageait en 927 et 1 685 m², et le tissu sortait deux à trois fois trop fin.
- 🏔️ **Le joint en toiture n'a demandé aucun travail** — les pignons sont verticaux, donc deux mitoyennes de hauteurs différentes se décrochent franc. C'était le seul reste de 61.

## 7. Ce qui attend l'auteur

- [ ] 🔴 **Le potentiel solaire réel est ~9,5 %, pas les 25–40 % du plan.** ✅ **La suspension est levée** : `07` a été relancé sur la ville avec venelles, soit **892 volumes bâtis et 12,1 ha de toit réel**. **À trancher maintenant : assumer ce potentiel bas, ou regonfler la colonne `equip` de la table d'énergie.**
- [ ] **La table `TISSU` de `04c`** (§5) — c'est du level design, il n'est pas délégué.
- [ ] **Les réparations de boucle de `04b`** — passées de 4 à **7 îlots** avec la carte à trois ponts. Les quatre anciennes (55, 13, 16, 21) sont signalées ; les trois neuves (9, 11, 62) ne le sont pas.

## 8. Les commandes

```
python "QGIS/scripts/tracer_chemins.py" --blanc    propose les venelles, n'écrit rien
python "QGIS/scripts/tracer_chemins.py"            écrit `QGIS/data/source/chemins.geojson`
python "QGIS/scripts/04c_parcelles.py" --blanc     calcule et affiche, n'écrit rien
python "QGIS/scripts/04c_parcelles.py"             écrit la couche `parcelles`
python "QGIS/scripts/04d_emprises_batiments.py"    les emprises des bâtiments
python "QGIS/scripts/apercu_parcelles.py"          le parcellaire ET les bâtiments en PNG
python "QGIS/scripts/07_exporter_godot.py"         alimente la maquette 3D
```

⚠️ `tracer_chemins.py` écrit dans **la source** — comme `00_decouper_ilots.py` et `00b_ilots_lisiere.py`, et avec les mêmes précautions (passe `--blanc` d'abord : c'est du level design). Il refuse d'écraser une couche `chemins` existante sans `--refaire` : une fois qu'un tracé a été déplacé à la main, le script n'a plus rien à dire.

✅ **L'ordre de la chaîne est tenu par `chaine.py`** : 02 → 03 → 04 → 04b → 04c → **04d**, `--godot` pour ajouter `07`. Le `02` repart de la source et **refait la carte de travail de zéro**, `emprises` et `parcelles` comprises.

✅ **Les deux machines font le même travail** depuis le 2026-08-17 : la source est du texte que git fusionne, et tout `.gpkg` est un dérivé gitignoré.

---

**Voir aussi** : [00 - Prototype.md](00%20-%20Prototype.md) · [Énergie.md](Énergie.md) · `Vault - Jeu urbanisme/Technique/Génération procédurale.md` · `QGIS/README.md`
