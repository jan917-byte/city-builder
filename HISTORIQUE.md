# HISTORIQUE.md — ce qui s'est passé, session par session

> Sorti de [ETAT.md](ETAT.md) le 2026-08-12 pour que le signet redevienne un signet.
> Ici on ne lit rien pour travailler : on vient y chercher **pourquoi** une chose est comme elle est.
> Ce qui est vrai aujourd'hui est dans `ETAT.md` ; ce qui est tranché est dans le vault, `Méta/Décisions arrêtées.md`.
> La règle : `ETAT.md` garde les **deux dernières** sessions, le reste tombe ici.

---

## Ce que le brainstorm a donné

Le brainstorm du 2026-08-10 (`Brainstorming/…inondation-rive-droite.md`) a servi de plan pour l'étape 5 : ses trois idées transférables sont maintenant **dans les données**, pas dans une note.

| L'idée | Ce qui l'implémente |
|---|---|
| la **doctrine à seuil** (« je plante au-delà de X m ») | `emprise_libre_m`, qui a exigé que les largeurs de rue varient |
| le **modèle de trafic minimal** (charge → report → seuil) | `charge`, une affectation par plus court chemin en temps |
| « **rendre à l'eau** » | `alea`, `altitude_relative`, `position_fil_eau`, `rive` |

Reste en `brut` : le tableau `decisions` et les trois postures (reconstruire / adapter / rendre à l'eau).

---

## 2026-08-12 (session 17) — la carte devient plate, et un toit de repli est essayé puis retiré

(1) **La carte est plate**, dans l'image ET dans la donnée ; l'Ilse devient un chenal à murs verticaux ; **la crue sort du prototype**, décidé en cours de session. (2) Le toit plat de repli — *« quand la surface est trop difficile, fait un toit plat »* — a été **écrit, regardé et retiré le même jour** : devant l'image, l'auteur a préféré les toits d'avant.

🎯 Ce que l'essai a laissé, et qui reste vrai : le bon critère est le **pli d'un pan** (l'écart entre ses deux diagonales), sa distribution est **continue, sans décrochement** — donc c'était un curseur, pas un seuil à trouver ; la mesure évidente est **fausse** (574 bâtiments sur 702 se déclaraient vrillés à tort) ; et le critère « angle trop aigu » **ne se déclenche jamais**, le plus petit angle de la ville étant 70,2°.

## 2026-08-12 (session 16) — cinq corrections devant l'image
Cinq demandes de l'auteur, toutes faites en regardant la maquette. Aucune ne
demandait un système de plus : quatre tables et un champ d'altitude.
- 📦 **Les barres, hangars et halles sont des boîtes** (`RECTANGULAIRE` dans
  `07`) : 18 volumes ramenés à un rectangle aligné sur la rue. 🐞 **Le piège,
  mesuré et corrigé le jour même** : le *rectangle englobant* est immédiat à
  écrire et faux — une parcelle en L a un englobant qui sort très loin d'elle,
  **44,5 m de débordement** contre 4,8 m avant. On cherche donc le plus grand
  rectangle **qui tient dedans**. Retombé à 5,5 m.
- ✂️ **Les pointes sont coupées** — `\_/` au lieu de `\/`, sous 70° : 162
  sommets sur 119 empreintes. 🐞 **Premier essai raté, et la leçon** : couper
  2,5 m de chaque côté d'une pointe à 15° laisse un mur de **65 cm**. Ce qu'on
  vise n'est pas une longueur de coupe mais **la largeur du mur qui reste**.
  Et pour ce qu'un chanfrein ne sauve pas — une lame de bout en bout —
  `LARGEUR_MIN_BATI = 3 m`, en dessous la parcelle repart au jardin.
- 🐞 **LE VRAI BUG DE LA SESSION, et il ne se voyait que sur l'image** : dans la
  table `BATI`, `profondeur` était comptée **depuis la rue et non depuis la
  façade**. Le recul était donc pris *sur* la maison — 5,5 m de recul et 10 m de
  profondeur donnaient un pavillon de **3,5 m de creux**, et ça valait pour
  **tous** les pavillons de la ville. Médiane de largeur bâtie en
  pavillonnaire : **3,5 m → 9,2 m**. *Une table dont le nombre ne décrit pas ce
  qu'on voit est un piège, pas un réglage.*
- 🏡 **Le pavillonnaire fait enfin des maisons individuelles** : façade `TISSU`
  18 → **13,5 m**, jeu au voisin 2,8 → 2,5 m. Des maisons détachées avec un
  jardin derrière, au lieu de gros blocs.
- 🌳 **Les cœurs d'îlot sont dessinés, et pas tous verts.** Le fond de parcelle
  était calculé puis **jeté** : on voyait le terrain nu, donc du gris. 667
  espaces libres (9,4 ha), **440 plantés (66 %)**, 317 arbres. La table
  `VERDURE` donne la part par tissu — 0,05 sur une dalle commerciale, 0,92 en
  pavillonnaire, 0,30 au cœur ancien. **C'est le contraste qui fait lire le
  tissu vu d'en haut**, pas la couleur des façades. Les jardins tombent dans le
  groupe de maillage de leur îlot : ils se cliquent et se teintent avec lui.
- 🌊 **L'Ilse est creusée de 1,6 m**, berge sur 12 m. Le défaut était dans
  l'héritage de `04`, qui compte l'altitude **relative à l'eau** : son zéro
  étant le fil de l'eau, la nappe affleurait le sol de toute la ville.
  ⚠️ **La voirie garde le terrain naturel** — sans ça les trois franchissements
  plongeaient dans l'eau. Avec, les tabliers passent au-dessus : **un pont, sans
  une ligne de code qui parle de pont.**
- 🔍 **Grille du terrain 8 → 4 m**, et pour une raison précise : à 8 m la berge
  ne tombait que sur **un** point de grille et la rive ressortait en escalier.
  Le relief de la vallée, lui, n'y gagne rien — il reste trop doux pour se voir.
- ⌨️ **Une touche de plus, `I`** : le point de vue sur l'Ilse. Le lit creusé et
  les ponts ne se jugent pas de mémoire, comme le reste.

## 2026-08-12 (session 15) — le prototype se réduit, et la ville se bâtit
- 🔓 **Deux règles levées par l'auteur en cours de session.** **65** : *« je ne veux plus repasser par QGIS, tu fais tout toi maintenant »* — Claude écrit **et exécute** les scripts de données, y compris sur le vrai `.gpkg`. Ce qui rendait l'ancienne règle vide : **la chaîne ne passe plus par QGIS depuis longtemps** — onze scripts en Python pur avec `sqlite3`, aucun GDAL, aucun PyQGIS, l'en-tête GeoPackage de `04b` encodée à la main. Trois garde-fous la remplacent : arbre git propre avant toute écriture, passe `--blanc` d'abord, contrôles imprimés en français. **66b** : les parcelles passent devant l'énergie, ce qui suspend 64b.
- ✂️ **Le prototype est réduit** (**66**) : D07, les arbres d'alignement, la surchauffe, les quatre moyennes de ville et les six calques sortent du code actif. **Supprimés, pas masqués** — `PLAN_energie.md` §2 proposait l'inverse. Tout est dans `Godot/archive/`, commenté, avec ce que coûterait le retour (une demi-journée). 🟢 `canopee` reste calculée : c'est elle qui fait l'ombrage des toits. *Une donnée n'est pas un indicateur.*
- 🔴 **Ce que ça coûte pour de bon** : le **contrôle de recoupement** entre Godot et `08_jouer.py` disparaît avec D07. C'était la seule façon de savoir tout de suite si les deux moteurs divergeaient — il avait déjà attrapé un vrai bug (le décalage d'un mois du budget). Rien ne le remplace à ce jour.
- 🌉 **Trois franchissements, pas cinq** (30c). 136 et 171 sautent : 136 était un boulevard de 20 m à **20 m de 145**, atterrissant sur le même îlot — le même pont compté deux fois, et le moins chargé de tous (0,04). Les dix paires possibles ont été testées avant : aucune ne coupait le réseau. ⚠️ **L'axe de transit n'a pas bougé** — rues saturées identiques avant et après (11, 13, 21, 54, 55). Les deux ponts retirés portaient 0,04 et 0,07 : ils ne pouvaient rien déplacer. On a gagné la structure, pas la secousse.
- 🏘️ **`04c_parcelles.py` — 968 parcelles, et la décision 61 tenue ET prouvée.** La somme des aires vaut **100,00 %** de l'emprise sur les 53 îlots, écart max 8,7e-07. Deux voisines partagent une arête exactement parce qu'elles sont les deux moitiés d'une même coupe — le mitoyen n'est pas un raccord, c'est la méthode. **35** tenue aussi : la graine se dérive de la **géométrie**, pas d'un rang, et la partition est calculée une fois et écrite dans le `.gpkg` — elle ne se rejoue jamais à l'affichage.
- 🐞 **La correction qui a fait tenir le compte** : couper au milieu **géométrique** du rectangle englobant donnait n'importe quoi. L'îlot 34 ne remplit que 67 % de son rectangle ; la coupe médiane le partageait en 927 et 1 685 m², le gros morceau se redécoupait une fois de trop, et le tissu sortait **2 à 3 fois trop fin** (49 m² au cœur ancien pour une cible de 112). On coupe désormais par l'**aire**, par dichotomie. Les cibles tombent juste : 160 m² aux maisons de ville, 112 au cœur ancien, 449 en pavillonnaire.
- 🏠 **690 volumes bâtis, 624 toits à deux pentes.** Table `BATI` en haut de `07` : recul de rue, **jeu au voisin (0 = mitoyen exact)**, profondeur bâtie, pente. Les **278 parcelles enclavées** deviennent des cours et des jardins sans qu'on ait eu à les dessiner. 🟢 **Le clic n'a pas changé de niveau** : toutes les parcelles d'un îlot tombent dans le même groupe de maillage, donc toujours ~237 nœuds cliquables et rien de l'interface à refaire.
- 🏔️ **Le joint en toiture sort tout seul.** Le faîtage court **parallèlement à la rue**, chaque sommet d'égout est relié à sa projection dessus : les arêtes de bout donnent des pignons **verticaux**, donc deux maisons mitoyennes ont leurs pignons dans le même plan et le décrochement entre deux hauteurs se fait franc. C'est exactement ce que 61 laissait à faire, et ça n'a demandé aucune ligne de plus.
- 🐞 **Trois recettes ont échoué avant la bonne**, et la leçon vaut d'être gardée : pour un **mur**, le sens de l'extérieur vient du parcours de l'anneau et se vérifie ; pour un **toit**, non — un pignon n'est pas un versant, une arête presque perpendiculaire au faîtage a un sens de parcours arbitraire. **L'orientation est désormais calculée, pas déduite.** ⚠️ Conséquence : la colonne « toits dehors » du contrôle est vraie **par construction** et ne prouve plus rien ; le chiffre qui informe est **748 pans réorientés (7 %)**.
- 🔗 **L'interface du toit est posée** (41 · 64) : chaque îlot expose `toit_m2` (**11,6 ha** de surface réelle, pente comprise), `toit_pente`, `toit_plat`. L'ombrage était déjà là. C'est ce qui neutralise 66b : l'énergie lira ces nombres sans savoir si c'est le générateur ou une table qui parle.
- ⚠️ **Trois défauts connus, imprimés à chaque export** plutôt que laissés à deviner : 18 bâtiments mordent sur la rue (jusqu'à 4,8 m, pic de mitre sur angle rentrant), 47 empreintes concaves prennent un toit plat, 748 pans réorientés.
- 🔴 **L'auteur a refusé le contrepoids** du capital politique par la visibilité (**66c**). À écrire dans le compte rendu du test : sans lui, le prototype mesurera **un tri par colonne**, pas un choix de lieu — donc il répondra *oui* à la question du §1 pour une mauvaise raison.
- ⏸️ **Le système énergie n'a pas été commencé**, à la demande de l'auteur en fin de session : *« va que jusqu'à la phase 3 »*. Tout est prêt pour lui.

## 2026-08-12 (session 14) — un indicateur vit à deux échelles
- 🔗 **Ce que l'auteur a apporté et qui n'était nulle part** : les indicateurs existent **globalement et localement** (îlot, tronçon), et les deux sont liés. Le vault avait la règle 53 (« aucun chiffre global sans son calque ») mais **pas la règle de composition** — comment on passe d'un niveau à l'autre. Formulation retenue : **l'indicateur local et le calque sont le même objet vu de deux côtés**, comme le bandeau et les milestones (57). → **63**
- ⚠️ **Correction apportée à l'énoncé de départ** : « le local est un % du total » est vrai pour les **stocks** (population, places, CO2, m² de toit), faux pour les **taux** (canopée, imperméabilisé, surchauffe, riverain). Un îlot à 40 % de canopée ne détient pas 40 % de la canopée de la ville.
- 🐞 **Le défaut de session 10 était exactement ça** : `canopee_moy` et `impermeabilise_moy` en moyennes simples par îlot, où un champ de 50 ha pèse autant qu'un parc de 0,4 ha. Il était consigné comme un choix ; il devient une **dette à rembourser**.
- ⚖️ **Tranché par l'auteur** : *un taux se pondère par ce dont il est le taux* — surface pour le sol, population pour les gens, mètres de voirie pour la rue. Gain non prévu : `riverain_moy` n'a plus besoin de son cas particulier « îlots habités seulement », un îlot inhabité pèse zéro tout seul. **La règle absorbe l'exception.**
- ⚖️ **Tranché aussi** : la **fiche reprend l'ordre et les icônes du bandeau** — un seul vocabulaire, et l'écart à t0 se lit aux deux échelles. → **63b**
- 🔴 **Une collision de nom sortie au passage** : `stationnement` désigne la part de surface en parking sur un îlot **et** les places sur rue sur un tronçon, alors que « l'emprise voiture » agrège déjà les deux.

## 2026-08-12 (session 13) — la phase A est débloquée en une séance
- 🟢 **Cinq questions closes, dont les deux qui bloquaient le générateur de parcelles.** Aucune ne demandait de code : elles demandaient un arbitrage.
- 🎯 **n°16 se règle par la méthode, pas par un travail de couture** — *la parcelle est une **partition** de l'emprise de l'îlot*. Le générateur découpe au lieu de poser des formes dans un vide, donc deux voisines partagent une arête **exactement**. Ce qui a tranché : 20 îlots de `maisons_de_ville` et 12 de `coeur_ancien` — le mitoyen n'y est pas un raccord à faire, c'est **la forme urbaine**. Ce qu'il reste est le **joint en toiture**, et il tombe sur un chantier déjà prévu. Réversible dans un seul sens : écarter les parcelles redonne le non-raccord, l'inverse non. → **61**
- 🔴 **Le piège nommé avec** : la partition ne doit pas se rejouer quand une seule parcelle change, sinon on ré-effondre le voisinage à chaque clic comme Townscaper — et la décision 35 tombe avec.
- 🚗 **n°18 : un flux, pas des agents** — plus une poignée de véhicules figurés qui ne calculent rien et dont la densité se lit sur `charge`. *Le spectacle est la transformation urbaine, pas la circulation.* **Critère jugeable à l'œil** : une rue à `charge = 1,00` doit être **désagréable à regarder** ; si le flux est trop propre, la marge est l'encombrement à l'arrêt, **pas** la navigation. → **62**
- 🏭 **n°17 : le dortoir est assumé**, 0,16 emploi par habitant, aucun sol d'activité dessiné. Gain : l'axe saturé et les 0,86 place par habitant deviennent des **symptômes**, pas des anomalies — et les deux friches deviennent **le seul levier d'emploi de la ville**. Coût assumé, écrit : *une ville sans travail est une ville sans matin*, le mouvement du matin sort de la carte — cohérent avec 62. → **50b**
- 🌉 **n°12 : trois franchissements, pas cinq.** À cinq, la rivière ne coupe plus rien et « ajouter une passerelle » cesse d'être une décision. Opération propre côté données : les îlots ne se touchent jamais par-dessus l'eau. → **30c**
- 🏢 **n°14 : la barre de 1974 reste sur l'îlot 32.** C'était la phrase du vault qui était fausse, pas la carte. Ce qui l'expose n'est pas la proximité de l'eau mais d'être **en bout de chaîne** — et c'est un meilleur récit. → **13e** · **13f** : les noms Wehrau et Ilse sont arrêtés, la fenêtre du renommage gratuit se fermait avec le code.

## 2026-08-12 (session 12) — les indicateurs globaux, et l'argent enfin tranché
- 🎯 **Une règle qui commande tout le bandeau** : ***aucun chiffre global sans son calque***. Le chiffre dit *que* ça bouge, le calque dit *où*. Elle a taillé **dix-neuf indicateurs candidats à sept**, par un critère unique — un chiffre dont on ne saurait pas dessiner la carte est une jauge qu'on optimise, pas une invitation à regarder la ville. Motif de fond : un indicateur global est une **moyenne**, et une moyenne efface l'injustice géographique que Wehrau porte. → `Décisions arrêtées` **53**
- 🆕 **Note système neuve** : `Systèmes/Indicateurs globaux.md` — les sept, leurs calques, leurs bornes, et le tableau de ce qui pousse contre quoi.
- 💰 **La plus vieille question structurante tombe : d'où vient l'argent (n°3).** Deux formules — **recettes ∝ `logements`, charges ∝ mètres de voirie** — au lieu d'une économie simulée. Le déclencheur est un fait mesuré en session 10 : **le budget ne mordait jamais**. Récupère au passage les **charges d'entretien du réseau**, orphelines depuis que l'économie a été écartée. ⚠️ Rouvre le piège de l'exponentielle : contrôle nommé, *une densification pure ne doit pas s'autofinancer*. → **59**
- 🔗 **Le bandeau et les milestones sont le même objet.** En cherchant à borner les indicateurs, on trouve que **cinq des sept maxima sont des jalons qui ont déjà un nom** — zéro voiture, zéro carbone, autonome en énergie, ville-éponge, « personne n'a été chassé ». Borner, c'est nommer l'état où l'indicateur sature. Ferme deux sous-questions de `Milestones.md` : zéro carbone en compteur permanent, et **quand les jalons s'affichent** (en pointillés, révélés à l'approche). → **57**
- 🧪 **Une manœuvre réutilisable, sortie deux fois** : *une formule sur des attributs existants n'est pas une sous-simulation.* Elle a sauvé le CO2, le renouvelable **et** le budget — trois choses qui semblaient exiger une économie. Le renouvelable devient « la part des toits qui produit », donc de la géométrie, et il tombe sur le chantier des toits déjà prévu. → **56**
- ⚫ **Le carbone gris est assumé** : démolir-reconstruire émet un gros coup immédiat. Ça rend **« adapter » mécaniquement défendable face à « reconstruire »** — deux des trois postures déjà adossées à `alea`. L'indicateur ne mesure pas seulement, il rend chiffrable un dilemme qui existait déjà. ⚠️ Risque symétrique : trop lourd, il dit « ne touche à rien ».
- ❌ **Toute l'économie écartée** — chômage, revenu, productivité, imposition, loyer, vacance. Aucune donnée derrière, et mises bout à bout elles font *Cities: Skylines*, contre le but affiché. Le social passe par `riverain`. → **55**
- 🖥️ **Ressources et indicateurs ne se dessinent pas pareil** : compteurs contre barres. *Les indicateurs regardent en arrière, les ressources en avant.* Le budget passe à **trois nombres** — ce que tu as, **ce qui est engagé**, ce qui est libre — parce que le code paie étalé quand le capital est comptant. → **58**
- 🟠 **Ce que ça laisse ouvert, deux questions neuves** : **n°19** — onze nombres permanents à l'écran, alors que le seuil défendu en début de séance était de six ; trois élargissements successifs, chacun défendable seul, aucun regardé avec les autres. **n°20** — `Déclin et défaite` refuse explicitement la jauge globale (*« une note de résilience sur 100 ne dit rien »*), que l'indicateur « ville exposée » vient d'introduire. Résolution proposée, non confirmée : la règle 53 la lève, puisque la barre est appariée à la carte.
- 💡 **Puis l'économie revient par une autre porte, et en mieux — décision 60.** Le joueur ne voit que **deux choses** : une **barre sans nombre** (l'économie va bien ou mal) et son **budget annuel**, qui en dépend. Le calcul est caché. Ce que ça gagne : ***un état non chiffré ne s'optimise pas*** — tout le piège *Democracy 4* tient au pourcentage. Même geste que le capital politique en un chiffre. Ça **révise 59** au lieu de s'y ajouter : les deux formules décrivent ce que le joueur **maîtrise**, l'état de l'économie est le **multiplicateur qu'il ne maîtrise pas**. Moteur **mixte** (cycle exogène lent × part endogène modeste), place dans le **bandeau de contexte**.
- 🔴 **Deux garde-fous écrits avec — 60b.** ***Formule cachée ≠ causalité cachée*** : que le joueur ne voie pas l'équation, très bien ; qu'il ne puisse pas dire pourquoi son budget a baissé, non. Quand la barre bouge, **quelque chose le dit en une phrase et sans chiffre**. Et l'interdit explicite : **l'économie cachée ne sert jamais à ajuster la difficulté** (21) — un état qui dérive sans être vu est le terrain rêvé de la difficulté adaptative, et ça arrivera par accident si ce n'est pas nommé.
- ❓ **Question n°21, posée par l'auteur** : la barre est dans le contexte, le budget avec les ressources — **ils sont loin l'un de l'autre**, donc comment le joueur comprend-il le lien ? Trois pistes non tranchées, dont la plus forte : **le budget est voté une fois par an, pas subi** — ce qui donnerait au passage un battement annuel à un jeu qui n'a pas de tours.
- ✅ **Le brainstorm est digéré le jour même** — neuf décisions remontées, trois questions ouvertes, six notes touchées. Le fichier reste en archive : **les options écartées n'existent nulle part ailleurs.**

## 2026-08-12 (session 11) — Frostpunk et Democracy 4 sortent du brainstorm
- 🎮 **Deux jeux entrent comme références durables**, répartis là où ils portent plutôt que listés au même endroit : `Systèmes/Décisions.md` (inertie des effets, échelle du district, capital politique — et ce qu'on **ne** reprend pas : le curseur d'intensité de D4, le conseil qui vote de FP2), `Technique/Direction artistique.md` (la jauge en matière à voler ; ⚠️ l'UI blanche sur neige blanche, risque direct avec une palette pastel), `Vision/Ton et règles d'écriture.md` (Frostpunk = le repoussoir du cynisme, mais son livre des lois est à prendre), `Vision/Pièges connus.md` (D4 en cas d'école des jauges d'humeur).
- ⚠️ **Le brainstorm du 2026-08-11 reste non digéré** : seules ses références sont remontées. Ses **9 décisions et 7 questions** attendent toujours.

## 2026-08-12 (session 10) — le noyau n'est plus réservé
- 🔓 **La décision 40 est levée → 40b, tranchée par l'auteur.** Claude écrit le code, noyau **et architecture** compris ; l'auteur teste, itère et revient sur ses décisions. La règle était écrite à **cinq endroits** — tous corrigés, plus `Godot/README.md`. Ce que 40 protégeait n'était pas la frappe mais la **compréhension** : elle n'est plus produite par la construction, elle devient une chose à aller chercher. Réversible, mais le coût du retour grandit avec la base de code. → `Décisions arrêtées` 40b
- 🆕 **Serveur MCP Godot** (`.mcp.json`, `@coding-solo/godot-mcp`, MIT) : Claude lance la maquette et lit la console lui-même. Testé de bout en bout avant écriture — handshake, 14 outils, `get_godot_version` → `4.7.1.stable.official.a13da4feb`. Deux pièges vécus : `npx` seul ne démarre pas sous Windows (Node refuse un `.cmd` sans shell, `EINVAL`) d'où `cmd /c`, et `GODOT_PATH` est obligatoire — l'exécutable est sur le Bureau, hors des emplacements devinés. **Seul fichier non portable du dépôt.**
- 🐞 **`Godot/README.md` pointait `Downloads/` pour la sonde** ; l'exécutable est sur le **Bureau**. La commande de débogage ne marchait pas telle quelle.
- 🧹 **`CLAUDE.md` §1 rattrape le réel** : le prototype y était encore l'Altstadt (13b l'a remplacé par Wehrau le 2026-08-10) et le fichier affirmait qu'il n'existait « ni dépôt Godot ni script versionné ». « Moteur de simu écrit à la main » retiré — contredisait 40b.
- ✅ **Les deux écritures dans le vrai `.gpkg`**, à la demande de l'auteur : `emplois` = 878, couche `emprises` = 69/69 anneaux simples, 76,5 ha bâtis, 17,6 % de voirie. Contrôle population ✅ 5 353 hab. `04b` signale **quatre réparations de boucle à regarder** : îlots 55, 13, 16 et 21 — deux cœurs anciens, deux fronts commerçants ; le 16 tombe de 2 132 à 560 m².
- 🆕 **`08_jouer.py`, le moteur du classeur.** Rampes, budget étalé sur `L + M`, capital payé comptant au mois `d`, les quatre portées. Il calcule la quantité d'une décision **sur l'état du mois où le chantier commence**, pas sur t0 — c'est tout le mécanisme de D06, qui n'existe que parce qu'elle libère les mètres de D07 et D08.
- 🆕 **Trois liens qui n'étaient dans aucune table** : tronçon → îlots riverains (géométrique, critère de `04b` — **178/178 tronçons, 0 orphelin, 2,0 îlots par tronçon**), tronçon → tronçons voisins par sommet partagé, et l'aval d'une décision de voirie. Sans le premier, `D07;voisins;ilots;canopee` ne retombait nulle part et la spécificité spatiale disparaissait.
- 🔴 **Le résultat qui compte** : **`largeur_m >= 20` rate quatre des cinq rues les plus chargées.** Les tronçons 13, 21, 54 et 55 font 18 m et portent 0,87 à 1,00 de charge. D05 n'attrape que le tronçon 11 — et comme elle reporte +0,35 sur les voisines, elle **double le nombre de rues saturées (5 → 10) sans jamais toucher l'axe**. Le classeur a fait ce qu'on lui demandait : rendre une erreur de seuil visible en une soirée.
- 🐞 **Trois définitions de stock étaient fausses**, sorties par le contrôle du mois 0 : `canopee_moy` et `impermeabilise_moy` sont des **moyennes simples par îlot**, pas pondérées par la surface, et `riverain_moy` ne compte que les **îlots habités**.
- ⚠️ **Aucune décision n'a été refusée pour cause de budget** sur les trois parties. La contrainte réelle est le capital politique, pas l'argent.
- 🆕 **`QGIS/rendus/parties.html`** : les trois parties superposées, un curseur de 60 mois, le mode **écart au mois 0** — le seul qui rende un changement lisible — le journal des chantiers et huit courbes.
- 🎯 **Puis tout est passé dans Godot**, à la demande de l'auteur : *« je veux voir le résultat visible du code plutôt que penser à un système complexe sans pouvoir le visualiser »*. Une décision de bout en bout — D07 planter l'alignement — plutôt que onze à moitié.
- 🆕 **La ville est cliquable.** 07 exporte trois choses neuves : les **attributs par objet** (la fiche), les **plages d'indices par objet** (`groupes`) et les **emplacements d'alignement avec leur seuil de canopée**. Godot en refait **237 nœuds** — 63 îlots bâtis, 174 tronçons — chacun avec son corps de collision. On passe de 5 draw calls à ~250, et c'est le prix du jeu : un maillage fusionné ne se sélectionne pas, ne se surligne pas, ne se reteinte pas.
- 🆕 **Le noyau en GDScript** : `ville.gd` (l'état, les rampes, les indicateurs) et `chantiers.gd` (cible, coût, capital, budget étalé). Ni l'un ni l'autre ne touche un nœud — même discipline que `constructeur.gd`. Plus `selection.gd`, `interface.gd`, `alignements.gd`.
- 🔴 **Le recoupement passe.** À décision, seuil et mois identiques : Godot donne **0,2732** de canopée au mois 60, `08_jouer.py` **0,273** ; 64 tronçons, 6 217 m, 114,9 pts des deux côtés — et la table du `Classeur/README.md` §3 annonçait bien 64 · 6 217 · 115.
- 🐞 **Le budget décalait d'un mois** : `08_jouer.py` paie sur `d` à `d + étale − 1` inclus, donc une mensualité tombe au moment où l'on décide. 397 d'un côté, 399 de l'autre — assez peu pour qu'on l'ignore, ce qui est exactement le danger. Corrigé.
- 🐞 **Les arbres sautaient au lieu de pousser.** La position d'un arbre d'alignement dépendait de la densité (`t = L·(k+0,5)/n`) : faire monter la canopée redistribuait tout l'alignement. Désormais 07 exporte **tous** les emplacements avec un **seuil**, la position est fixe, et seul le seuil décide. Un arbre planté reste où il est.
- 🆕 **L'occlusion voyage dans le canal alpha** de la couleur de sommet. C'est ce qui permet de repeindre un îlot en calque thématique sans perdre ce qui le pose au sol. Aucun matériau du projet n'activait la transparence : le canal était libre.
- 🔄 **Puis l'auteur a changé le cap, en fin de session** : *« je veux d'abord avoir une ville crédible et belle — travailler le trafic, les îlots. Ensuite on prendra chaque indicateur, système et décision un à un. »* Consigné en **51**, et répercuté dans cinq notes du vault.
- ⚠️ **Ce que ce virage coûte, écrit noir sur blanc** : la limite « une semaine, pas de toits » tombe (**52**) alors qu'elle était le garde-fou contre le risque nommé *« que la 3D mange le calendrier »*. Le risque est **accepté**, pas éliminé. Ce qui le tient maintenant est une règle de production — *si je devais en faire 200, est-ce que je tiendrais ?* — et un critère d'échec : **le pari est perdu si, dans six semaines, la ville est plus belle et qu'aucune décision de plus n'a été traitée.** ⚠️ Ce critère d'échec a été **supprimé par 64**, pas surveillé.

## 2026-08-11 (session 9) — la maquette existe
- 🔴 **Le fait qui a commandé toute la session** : les 69 îlots **pavent 99,75 % de l'emprise**, et les axes de rue tombent **exactement** sur leurs bords (0,0000 m d'écart, mesuré sur 83 segments). `largeur_m` était un attribut **sans lieu**. Extrudées telles quelles, les empreintes donnaient un bloc plein de 93 ha : le critère « trouver monstrueuses les rues à 20 et 22 m » était littéralement inobservable. → décision **32f**
- 🆕 **`04b_emprises_baties.py`** : l'îlot recule de la demi-largeur de la rue, la rue devient le négatif. Nouvelle couche `emprises` dans le GeoPackage (écrite en Python pur, en-tête GPKG encodé à la main — aucun GDAL dans ce dépôt). **69/69 anneaux simples, 76,5 ha bâtis, 17,6 % de voirie.** Le pic de mitre aux sommets réflexes envoyait un sommet de l'îlot 43 à **258 m** : limite de mitre + biseau, puis réparation de boucle. Contrôle final : **aucun sommet à plus de 5 cm hors de l'îlot d'origine**.
- 🆕 **`palette.py`**, qui **ferme la décision 33** : le `.qml` désigné comme référence couleur unique n'a jamais existé, et Godot ne sait pas le lire. 9 familles pour 13 sous-types. La règle `lerp(teinte, MINERAL, impermeabilise)` donne à la place du marché (îlot 19, `imperm = 1,00`) **exactement la couleur de la chaussée** — la plaie apparaît sans avoir été peinte. → **33b**
- 🆕 **`07_exporter_godot.py`** + **le projet `Godot/`**. Terrain continu rejoué depuis la formule de `04`. Toute la géométrie est en Python ; Godot empaquette des tableaux et ne décide rien — l'« interface propre » de `Moteur et architecture:18` est **le contrat JSON**, pas une hiérarchie de classes.
- ✅ **Les trois critères sont atteints, vérifiés sur capture** : la barre de 1974 écrase ses voisines (le gris-bleu froid la rend étrangère au pastel), le quai à 22 m recule trois îlots de cœur ancien, la place-parking se lit comme une rue qui a enflé. Reste **la vallée** : 9 m sur 898 m, à arbitrer devant l'image avec les touches `1..4`.
- 🐞 **Trois pièges Godot 4.7, tous trouvés par l'expérience et pas par le raisonnement** — consignés dans `Godot/README.md` : les faces avant sont en sens **horaire** (le terrain entier était cullé, les bâtiments ne se voyaient que par leurs murs) · les couleurs de sommet sont en espace **linéaire** (tout ressortait délavé, et le contraste pastel/minéral avec) · `class_name` ne suffit pas en ligne de commande, d'où `preload()`.

## 2026-08-11 (session 8)
- ✅ **Le PC est raccordé — il l'était déjà.** Le diagnostic de la session 7 était faux : le dossier *est* un dépôt, avec `origin` correctement configuré. Il était simplement **en retard de 5 commits**, en fast-forward propre.
- ⚠️ **Deux modifications locales traînaient sur le PC**, toutes deux sans valeur, mises en stash plutôt qu'en commit : les committer aurait cassé le fast-forward et réintroduit une régression.
- 🟢 **Les `.gpkg` n'ont pas divergé** : suivis par git et non modifiés localement.
- ✂️ **Section « Clichés interdits » retirée de `Direction artistique`** (demande de l'auteur). ⚠️ **« pas de tours-forêts » n'est plus consigné nulle part**, et « pas de Ghibli » ne survit que dans le brainstorm non digéré.
- 🔍 **Les emplois vérifiés avant écriture** : **879 emplois, 10,4 ha d'activité, 0,16 par habitant**.

## 2026-08-11 (session 7, suite)
- 🎯 **La phase du prototype est réécrite dans le vault** : la ville de t0 passe devant le système de décisions (décision 49), Godot entre au mois 1 pour le rendu seul (39b), **Townscaper** remplace Mini Motorways (42b), les emplois sont consignés (50).
- ⚠️ **Les deux erreurs symétriques, tranchées par l'auteur (42c)** : une ville de départ charmante ne laisse rien à transformer ; une ville de départ grise et triste tombe dans le cliché dystopique interdit par 5 et 8. La sortie : **les bâtiments sont pastel, le sol est minéral**. Et la grisaille n'est pas un filtre, c'est une **proportion déjà présente dans les données**. Ce qui bouge en jeu est la part minérale du sol ; les teintes et la lumière ne bougent jamais.

## 2026-08-11 (session 7)
- 🔄 **L'ordre a été corrigé en cours de route.** On a d'abord chiffré la crue (`Classeur/`, 11 décisions, 37 effets), puis constaté qu'une crue est une **perturbation d'un état** — et que l'état n'existait pas. Retour à l'état zéro.
- ❌ **L'arbre de décision (Miro) écarté comme format de travail.** Un arbre ne porte ni le délai, ni le lieu, ni les liens `ouvre`/`ferme`. Le format retenu : des CSV `;` dans le dépôt — jamais de `.xlsx`, c'est un binaire qui ne fusionne pas.
- 🆕 **`06_etat_zero.py`** : la ville entière dans **une page HTML autonome**, 22 calques cliquables, les stocks calculés à côté.
- 🆕 **Les emplois** : **878 emplois pour 5 353 habitants — 0,16 par habitant.** La ville n'a que 10,4 ha d'activité sur 38 ha bâtis. **Wehrau est un dortoir.** Pour changer ça il faut dessiner du sol d'activité, pas régler un chiffre.
- 🐞 **`HABITANTS_VAULT` valait encore 18 000** (Vallmar) : le contrôle de fin de `04` criait à 30 % d'écart depuis que le prototype est Wehrau. Remis à 5 350.
- 🆕 **`05_exporter_classeur.py`** : la carte en CSV (69 · 178 · 179 lignes) pour que le classeur ne devienne pas une quatrième source de vérité.

## 2026-08-11 (session 6)
- 🎯 **Trois questions fermées par l'auteur** : population de Wehrau (~5 350, prototype seulement) · **crue d'ouverture sur la rive gauche** · **capital politique = un chiffre**. (13d, 23b, 16b)
- 🆕 **Système des milestones** (`Systèmes/Milestones.md`, décision 9b) : des jalons **cumulables**, pas des fins. Ce qui les rend durs est un **coût d'opportunité**, pas une interdiction : *la rareté est dans le calendrier, pas dans les règles*. Un capital politique en chiffre unique règle le **rythme**, jamais la **direction**.
- ⏸️ **La durée d'une partie est reportée, pas tranchée** (14b, 14c) : **pas de fin imposée**. Hypothèse de travail assumée : ~20 ans en ~2 h.
- **Brainstorm importé** dans `Brainstorming/2026-08-11_brainstorm_refs-positionnement-ui.md`. Non digéré.
- **Le vault rattrape la réalité**, et **le travail sur deux machines est assumé** : `CLAUDE.md` §5 réécrite, `.gitattributes` ajouté — LF partout, `.gpkg` marqués binaires.

## 2026-08-10 (sessions 1 à 5) — compressé
Encodage réparé · `CLAUDE.md` et `ETAT.md` posés · carte qualifiée (69 îlots, 178 tronçons, 4 plaies de 1965) · `03_adjacences` et `04_deriver_attributs` écrits, quatre défauts réels sortis par le dry-run (aucun pont, graphe sur les extrémités, largeurs constantes, axe se trompant de rive) · [dépôt GitHub](https://github.com/jan917-byte/city-builder) créé · `QGIS/` scindé en `scripts`/`data`/`rendus`. Le détail est dans l'historique git.

---

*(`Méta/Journal.md` reste vierge de ma main — c'est le fichier de l'auteur.)*
