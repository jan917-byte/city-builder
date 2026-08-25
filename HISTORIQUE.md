# HISTORIQUE.md — ce qui s'est passé, session par session

> **On ne lit pas ce fichier pour travailler** : on vient y chercher *pourquoi* une chose est comme elle est. Ce qui est vrai aujourd'hui est dans [ETAT.md](ETAT.md) ; ce qui est tranché est dans le vault.
> **La règle : 3 lignes par session**, en fin de session — ce qui a changé, le piège payé, le numéro de décision. Pas le récit.
> ⚠️ Les entrées d'avant le 2026-08-19 ont été **coupées à leur début** ce jour-là, quand les fichiers de contexte ont été réduits. Leur texte complet est dans l'historique git.

---

**2026-08-25 (session 60) — la maquette a deux vues, et le diagnostic a un menu.** Quatre drapeaux indépendants (`calque_tissu`, `diagnostic_crue`, `vue_chantiers`, `calque_champ`) s'éteignaient l'un l'autre à la main, une touche chacun : ils deviennent **une seule case, le thème actif**. Un cinquième thème coûtait quatre modifications, il coûte une ligne — le critère de l'étape 6, atteint avant elle.
La deuxième vue passe la ville en **maquette blanche** : plus de matière, plus d'arbres, plus de voitures, rien que le volume porté par l'AO, et seul le thème choisi en couleur. Raison de fond, pas de goût : tant que le diagnostic ressemble à la ville vivante, on ne sait plus si on juge le rendu ou le calque, et les critères d'étape se jugent sans calque. Le thème **énergie** existe enfin, sur `_classe_solaire` — « où agir ? », pas « qu'a-t-on posé ? », qui vaut 0 partout au mois 0.
🔴 Deux retours en arrière signalés, et une perte assumée : les touches `C` `D` `H` `X` sont **supprimées** — l'auteur a demandé un menu, il n'y a plus de secours au clavier — et la caméra **ne recadre plus** à l'ouverture d'un thème, ce qui rend les deux vues comparables. **Écrit sur un Mac sans Godot : ni compilé, ni lancé, ni vu.** (étape 5 · 42b)

**2026-08-24 (session 59) — les deux machines se rejoignent, et les deux trafics se composent.** Quatre sessions Windows jamais commitées (54→57) et une session Mac poussée le même jour portaient toutes deux le numéro 54 ; celle du Mac devient la **58**. Sept fichiers se heurtaient, `04e` compris.
Le chevauchement était réel et les deux côtés sont gardés : `04e` **chiffre** le report une fois pour toutes (+0,05 sur la rue qui encaisse le plus, réseau en 2 morceaux — 151 nœuds contre 45), Godot **vide** les 37 routes cassées et les rouvre à la réparation. Conséquence mesurée : l'axe 55 part désormais de **0,88** et non de 1,00, la maquette lisant la charge d'après-crue.
🔴 La vue chantiers `X` du Mac **compile enfin** — 46 cassés, 1 en cours, 1 fini, 13 495 k€ à payer — et la passe sort en 0 avec ses 14 contrôles ✅. Elle est capturée, pas encore jugée. (23b · 72)

**2026-08-24 (session 58) — le trafic se remet à compter juste, et la crue le déplace.** La charge comptait un point par **segment dessiné** et non par tronçon traversé : l'axe de transit sortait en pics isolés (4 tronçons au-dessus de 0,80, 260 m) au lieu d'un corridor continu (**16 tronçons, 799 m**).
`04e` réaffecte désormais la charge **sans les ponts coupés** et la réécrit : le réseau sort en 2 morceaux (151 nœuds contre 45), 21 tronçons tombent à zéro contre 14, et la rue qui encaisse le plus ne prend que **+0,05** — le faubourg coupé ne coûte presque rien à la ville, ce qui chiffre 23b.
Piège payé : « avant » se **recalcule** au lieu de se relire dans `routes.charge`, sinon relancer `04e` seul compare l'après à lui-même et affiche un report nul. La dette de `Crue.md` § 6 est payée ; le trafic reste aveugle aux logements et sans capacité (23b · étape 5)

**2026-08-24 (session 58) — une deuxième vue d'ensemble : les chantiers.** Le diagnostic (`D`) dit ce que l'eau **a pris** et ne bouge plus ; la vue chantiers (`X`) dit **où on en est** — rouge le cassé, ambre les travaux, vert le fait — et liste les chantiers en cours avec leur durée restante.
La pose de panneaux y figure comme les trois réparations : le noyau ne connaît toujours pas la crue, il compare un prix à la caisse. La passe automatisée capture le seul mois où les trois états coexistent.
🔴 **Rien n'a été vu à l'écran** : le Mac de cette session n'a pas Godot, donc la vue n'a même pas été compilée. (23b · 72)

**2026-08-21 (session 57) — le trafic obéit à l'état de la voirie.** Les 37 routes endommagées, dont trois ponts emportés, restent sans voiture jusqu'à la fin de leur réparation ; chaque réouverture rejoue l'affectation.
Fermer l'axe 55 le vide dès le clic, puis reporte le flux en six mois de 1,00 à 0,00 ; supprimer le stationnement nomme ses deux mois de chantier et ne s'engage qu'une fois.
🔴 Le monde visible et la simulation lisent désormais le même état praticable ; l'essai rendu contrôle zéro voiture sur chaque route cassée. (23b · 62)

**2026-08-21 (session 56) — le mouvement quitte le CPU.** Les voitures roulantes sont désormais déplacées par le GPU à la fréquence de l'écran ; aucune transform n'est réécrite par image.
Le niveau de détail suit les événements de caméra et une pulsation plafonnée à 4 Hz ne transmet que les changements de charge ; loin de la ville, elle sort immédiatement.
🔴 La simulation reste agrégée et lente ; les 414 véhicules visibles sont une animation 60 Hz, pas 414 agents. (62)

**2026-08-21 (session 55) — les voitures redeviennent une image.** Le trafic ne suit plus le framerate : 12 mises à jour par seconde, une lecture par rue, aucune réécriture d'instance cachée.
La réserve roulante tombe de 2 544 à 972 positions, le stationnement de 1 916 à 1 000 symboles ; ombres coupées, et à l'échelle de la ville tout disparaît sous le pixel avec zéro travail CPU/GPU.
🔴 `charge` et les décisions restent la simulation ; les véhicules ne sont qu'un échantillon adaptatif du résultat, conformément à 62.

**2026-08-21 (session 54) — la charge descend dans la rue.** Deux MultiMesh figurent le flux et 58 % des 3 310 places ; charge 1 tasse et ralentit la file, tandis qu'une rue calme respire.
La fiche de rue supprime le stationnement ou retire la voiture de l'axe ; la seconde décision rejoue l'affectation agrégée sur une échelle figée, et le tronçon 55 tombe de 1,00 à 0,05.
🔴 L'étape 5 s'ouvre et la 4 passe en pause ; aucune voiture ne navigue, la file est une image du flux conformément à 62.
**2026-08-21 (session 53) — les deux rives se séparent à l'écran.** La rive gauche touchée descend de **1 m**, la terrasse droite intacte monte de **1 m** ; l'eau reste horizontale et toute la géométrie terrestre lit la même coupe.
Les trois ponts emportés ne sont plus de simples trous : chacun garde **deux moignons de tablier affaissés**, tandis que la réparation montre toujours un ouvrage neuf complet. La vue `N` et la passe automatisée ont été regardées.
🔴 Le côté de rive se dérive de la coupe locale de l'Ilse, jamais d'une liste d'îlots ; six vestiges sortent donc des trois coupures. (23b)

**2026-08-21 (session 52) — le faubourg garde ses vestiges.** La crue d'ouverture redescend de 4,40 à **3,80 m** : **68 ruines et 71 bâtiments encore debout mais sinistrés**, contre 106 et 33 avant.
La terrasse droite, les 417 logements touchés et les trois ponts coupés ne bougent pas ; seule la violence visible dans les îlots est reprise. La chaîne et la passe graphique automatisée sont vertes.
🔴 Le niveau intermédiaire conserve l'effet systémique de la hauteur d'eau : aucun plafond artificiel de ruines n'est ajouté par îlot. (23b)

**2026-08-21 (session 51) — l'urgence donne l'ordre du jeu.** Deux jauges séparent l'**adaptation**, qui relève logements et ponts, de la **réduction**, qui mesure ensuite les émissions évitées.
Avant ce passage, toute décision solaire disparaît de la fiche et le noyau la refuse ; après les réparations essentielles, elle revient. Les deux états ont été vus sur les captures automatisées.
🔴 **Décision 72.** Le verrou fonctionne, mais les prix actuels rendent son ouverture inaccessible en vingt ans : seuil et coûts restent du level design (question 23).

**2026-08-21 (session 50) — la crue revient, sur une branche.** La décision **23b** repart de la hauteur d'eau : crue d'ouverture à 4,40 m, terrasse droite intacte, **106 ruines et 33 bâtiments sinistrés** en rive gauche, les 417 logements du faubourg touchés. Les trois franchissements 145, 168 et 169 sont emportés : la rive gauche n'a plus d'accès routier, contradiction volontaire avec 30c.
À l'écran, les ruines ont des crêtes cassées et un plancher ouvert ; limon, jardins, haies, arbres et marquage répondent à la même donnée. Le diagnostic `D` réunit passage de l'eau, bâti touché et routes bloquées, avec une croix au-dessus de chaque coupure ; la capture automatisée échoue si l'un des trois signaux est vide.
🐞 Le contrôle de l'asphalte lit désormais les morceaux réellement émis, pas le réseau théorique. Le choix du joueur reste à écrire : reconstruire, adapter ou rendre à l'eau, et leurs prix sont du level design.

**2026-08-20 (session 49) — les README fondent, et le poids réel change de camp.** Les six fichiers de documentation passent de **23 600 à 7 700 tokens** : partent les chiffres mesurés, les états datés, les défauts, les arbitrages et les expériences retirées ; restent le mode d'emploi, le clavier, la carte des fichiers et les pièges permanents. `CLAUDE.md` gagne une **sixième règle** et un plafond de 120 l. par README — *un README qui raconte la session qui l'a écrit est déjà faux*. Trois références vers des sections supprimées corrigées dans la même passe.
🔴 **Le vrai poids n'était pas la prose.** Mesuré : le démarrage de session pèse ≈ 13 100 tokens, mais une session sur l'étape 4 en charge ≈ 103 000 — dont **79 000 pour `07_exporter_godot.py` seul** (5 500 l., 110 fonctions, un `main()` de 944 l.). Le découpage de ce fichier est le prochain gros levier, et il est dans `ETAT.md`.
🐞 Deux dérives que `QGIS/README.md` §8 décrivait étaient elles-mêmes périmées : `HABITANTS_VAULT` est déjà passé à 5 350. Et **`00b_mettre_a_echelle.py` vise `Vallmar2.gpkg`**, disparu le 2026-08-17 — ce n'est pas un script qui écrit la source mais un vestige ; reclassé, et versé à la dette de `Prototype/00`.

**2026-08-19 (sessions 47 et 48) — le sol de Wehrau prend corps.** L'Ilse coule 2 m sous la ville et **les routes ne volent plus sur l'eau** ; le mur de quai longe la **berge** et non la chaussée ; les parapets des ponts s'arrêtent au bord de l'eau libre. La place du marché montre ses **123 places de parc**, tracées par règles et non posées à la main. Les barres redescendent au gabarit de Wehrau — **trois dalles de 46 à 58 m, 6 niveaux** — ce que 13d appelait « un petit Neubau ». ⚠️ Le critère du vault dit toujours « 9 niveaux » : il attend l'auteur.

**2026-08-19 (session 46) — les fichiers de contexte fondent.** Démarrage de session mesuré à ≈ 35 000 tokens (CLAUDE + ETAT + l'étape ouverte) ; ramené à ≈ 11 000 sans rien perdre de vérifiable. `CHANTIERS.md` est supprimé et son contenu réparti : les défauts visibles dans la note de l'étape qui les porte, les tables de level design et la dette dans `Prototype/00`, le reste dans `ETAT.md`. Chaque fichier porte maintenant **un plafond de lignes écrit dans son en-tête**, et cinq règles d'écriture les tiennent — dont *un fait, un seul endroit* et *ce qui se remesure ne s'archive pas*. `AGENTS.md` cesse d'être une copie de `CLAUDE.md`.

**2026-08-18 (session 45) — les murs se percent, l'Ilse descend, la maquette montre son coût.** Point de sauvegarde sur limite de tokens, trois travaux laissés en chantier. Les fenêtres sont dessinées par le matériau : **2 552 murs percés sur 3 547** (23,99 km), 995 aveugles, 697 portes, 82 vitrines, 36 bandeaux, **0 triangle ajouté**. La hauteur d'étage est **passée au shader depuis les données**, donc aucune rangée n'est coupée par l'égout. 🔴 Deux pièges : le test « la rue est-elle devant ce mur ? » mesurait une variation au lieu d'un signe (2 vitrines pour 49 volumes) ; un bandeau, c'est une ouverture deux fois plus large que haute.

**2026-08-18 (session 44) — l'Ilse coule 2 m sous la ville et les champs y descendent.** Demandé avec une coupe dessinée. Ce qui change n'est pas la profondeur mais qu'il y ait **deux bords d'eau**, faits par la même règle : le mur de quai monte jusqu'à la surface du sol — 2,6 m en ville, une lèvre noyée au champ. Le relief tient dans **une seule fonction** que tout ce qui touche le sol interroge, et sa moitié difficile est le **fondu**, qui supprime trois cas particuliers d'un coup. 🔴 Piège : un point posé **sur** la ligne de berge n'est ni dedans ni dehors — la rive se hérissait de dents grises d'un mètre. Mesuré : 984 m de rive à 22 %, sol à −2,15 m.

**2026-08-18 (session 43) — le pavillonnaire est vert, accessible et clos.** Les 174 parcelles bâties sur 174 sont vertes, chacune avec le plus court chemin maison→route arrivant perpendiculairement (749,4 m, écart max 0,0000°) et une haie sur tout le tour sauf à l'ouverture (820 tronçons, 10,32 km). Aucun autre tissu touché.



**2026-08-18 (session 42) — la performance devient visible.** Le moniteur est posé entre les deux fiches, sans ouvrir un nouvel écran : cadence et temps d'image, CPU, triangles, appels de rendu, nœuds, mémoire générale et vidéo. Il se rafraîchit quatre fois par seconde, se masque avec `F3` et change de couleur aux seuils de 55 et 30 ips. La vraie fenêtre Godot a été lancée et capturée : **180 ips, 5,6 ms/image, 7,2 ms CPU, 933 501 triangles, 496 appels, 810 nœuds, 258 Mio dont 252 Mio vidéo** sur la vue entière.

**2026-08-18 (session 40) — le solaire prend le sens du toit.** La grille des panneaux était calée sur les axes de la carte : elle traversait les directions de bâtiment et équipait les deux versants en même temps. Chaque volume porte maintenant jusqu'au matériau l'axe de son faîtage, déjà dérivé de sa façade sur rue ; les rangées le suivent et remontent la pente à angle droit. La pose avance par pan : le mieux exposé d'abord, le second ensuite, tandis qu'un toit plat reste un pan unique.

**2026-08-18 (session 39) — la rue prend un bord.** Deux phrases de l'auteur : *« séparation chaussée trottoirs, courbes au lieu d'angles (sauf aux croisements) »*. Trois réponses commandent le résultat : vraie bordure, trottoir contre la façade et arrondi des seuls vrais coudes. 🔴 Le trottoir d'avant était un quadrilatère plus large que la chaussée, glissé dessous à 3 cm ; ce qui dépassait en tenait lieu.

**2026-08-18 (session 37) — le trait autour de l'îlot choisi, et une leçon sur la géométrie.** Demande d'une ligne : *« quand on sélectionne un îlot, il faut une ligne blanche autour de ce qui est sélectionné »*. 🔴 **Le premier essai a été repris, et c'est lui qui apprend quelque chose.** Il posait un ruban de triangles **au sol**, le long de l'anneau d'emprise : c'était la solution évidente, et elle est fausse pour deux raisons qu'aucun réglage ne rattrape — les bâtiments **dépassent** de cet anneau (débord de toit compris), et dans le cœur ancien ils sont plantés dessus, donc ils le **cachent** ; vu du sud-est à 32°, l'îlot 22 n'en montrait qu'un tiers.

**2026-08-18 (session 36) — aucun arbre dans l'Ilse.** L'auteur voit des arbres dans la rivière. Le semis des îlots excluait déjà les six polygones d'eau ; le défaut venait des **arbres d'alignement**, qui suivaient les routes jusque sur les trois ponts puis se décalaient latéralement dans le chenal. Le filtre se fait maintenant sur le polygone exact de l'Ilse, avant l'export et pour les arbres futurs comme pour t0 : **98 emplacements écartés**, dont **11 occupés à t0**.

**2026-08-18 (session 35) — la ville cesse d'être coloriée.** L'auteur arrive avec une photo aérienne de petite ville allemande : *« la couleur des bâtiments ne doit plus suivre la typologie mais être plus réaliste »*. Quatre questions, quatre réponses — détail jusqu'au **sol et aux arbres** mais pas jusqu'aux fenêtres, lecture du tissu **par l'époque plus un calque à la touche**, **zéro asset**, et **on ouvre l'étape 4**.

**2026-08-18 (session 34) — la galerie disparaît, l'église est protégée.** Le trait dessiné par l'auteur coupe l'îlot 45 en **45 (0,51 ha) + 72 (0,42 ha)** par la nouvelle rue 181, avec un écart de surface nul. Les deux moitiés sont des **fronts commerçants** : la catégorie de l'ancienne galerie disparaît et Wehrau retombe à **12 sous-types**. L'îlot **16** devient l'église — son toit réel mesure **172 m²**, mais la protection laisse **0 m² solaire équipable**, curseur verrouillé et refus du noyau.

**2026-08-18 (session 33) — un seul propriétaire.** L'auteur ferme en une phrase la question ouverte la veille : *« pour simplifier le prototype, disons que tout le logement et tous les panneaux appartiennent à la ville »*. C'est plus court que les trois pistes examinées — il n'y a plus de toit des autres, donc plus de loyer de toiture à mettre dans la table, plus de copropriété qui refuse, plus de deux régimes selon le tissu.

**2026-08-17 (session 32) — une petite économie, deux prix.** L'auteur demande *« une petite économie simple, avec les coûts et les rendements des panneaux solaires »*. Deux prix suffisent — **260 €/m² posé** et **150 €/MWh produit** — et tout le reste s'en déduit : le coût d'une pose, sa recette annuelle, son amortissement. L'unité passe du « point » à l'euro, parce qu'un point ne se compare à rien.

**2026-08-17 (session 31) — le temps devient visible dans la décision solaire.** La cible ne s'applique plus d'un coup : **0 → 100 % prend 3 mois maximum**, proportionnellement à la part ajoutée. La fiche annonce la durée avant validation, puis montre la part posée, la cible et le temps restant ; une seconde barre avance avec les toits et les quatre totaux. Le panneau du bas donne pause, ×1, ×4 et ×12, et `Espace` alterne lecture et pause.

**2026-08-17 (session 30) — l'énergie tient en une décision et deux échelles.** L'auteur retire budget, capital, isolation, rentabilité et calques du test : à gauche restent les quatre conséquences pour toute la ville ; à droite, seulement l'îlot cliqué et sa part solaire croissante. Sur l'îlot 32, **0 → 100 %** fait passer la production de ville de **0,0 à 0,3 GWh/an**, l'achat de 51,1 à 50,9 et le CO₂ de 12,8 à 12,7 kt/an ; les toits passent à l'ardoise sombre. Cette simplification est la décision **68**.

**2026-08-17 (session 29) — la 3D lit enfin les bâtiments.** L'auteur demande à voir les nouveaux bâtiments dans Godot. Le défaut était celui déjà nommé : `04d` écrivait les 701 empreintes corrigées, mais `07` recalculait encore 892 volumes avec son ancienne table, donc l'aperçu et la maquette montraient deux villes. `07` lit maintenant la couche `batiments`, rattache chaque volume à sa parcelle et retrouve sa plus longue façade pour orienter le faîtage.

**2026-08-17 (session 28) — l'encoche du bâtiment.** L'auteur regarde `parcelles_ilot_40/41` : *« l'îlot 40 a encore des parcelles bizarres avec des formes de bâtiment pas réalistes, et l'îlot 41 a des coins encore à corriger »*. C'est la suite que la session 27 avait nommée sans l'écrire — « les doigts de cour et les ressauts en escalier demanderaient une ouverture morphologique, pas un seuil de plus ».

**2026-08-17 (session 27) — le coin d'îlot.** L'auteur regarde `parcelles_ilot_40/41/59` et tranche en une phrase : *« le reste fonctionne plutôt bien, c'est surtout les coins d'îlots que je trouve encore problématiques »*, avec l'emprise voulue **dessinée en rouge par-dessus l'image**, trois fois. Les deux causes étaient dans deux scripts différents et il fallait les deux.

**2026-08-17 (session 26) — le bâtiment cesse d'être la parcelle.** L'auteur relit `parcelles_ilot_14.png` et pose le diagnostic en une phrase : *« les bâtiments ressemblent trop aux parcelles »* — corps très profonds, trapèzes, aucun jardin, aucune cour, « une mosaïque de polygones extrudés plutôt que du véritable tissu urbain ».

**2026-08-17 (session 25) — les venelles reviennent dans la source et traversent toute la chaîne.** L'auteur demande de réintégrer les chemins montrés depuis l'ancienne version du parcellaire. Le garde-fou a joué dans l'ordre prévu : arbre propre, passe `--blanc`, puis écriture de `QGIS/data/source/chemins.geojson`. **Six tracés récupérables**, sur les îlots 22, 24, 26, 38, 44 et 63 ; le septième autrefois annoncé sur l'îlot 40 n'avait jamais été enregistré et ne passe plus le seuil de rectangularité.

**2026-08-17 (session 24) — QGIS sort du projet, et la carte devient du texte.** L'auteur ouvre la session sur un constat : *« le workflow geopackage me semble devenu compliqué »*, et une décision — plus de QGIS, Python seul. Ce qui a rendu la suite évidente, c'est de regarder ce que la source contenait vraiment : **rien que de la géométrie**, 70 polygones et 179 lignes, plus une colonne `hierarchy`.

**2026-08-15 (session 23) — les deux derniers défauts de l'image tombent, et ils n'avaient rien en commun.** L'auteur entoure deux endroits sur l'aperçu : *« la direction des parcelles »* (îlots 63 et 26, avec des traits dessinés en travers du bout de l'îlot) et *« deux triangles peuvent former un rectangle »* (îlot 13, légendé *« devrait n'être qu'une parcelle »*).

**2026-08-14 (session 21) — l'auteur regarde le parcellaire et désigne trois défauts.** Le parcellaire ne se voyait nulle part avant `apercu_parcelles.py` ; cette session est la première où quelqu'un le regarde vraiment. Trois choses en sont sorties, et elles n'ont pas eu la même réponse. **① Les îlots 64 et 69 — « la séparation doit se faire au milieu »** : une rangée prenait tout le fond (28 m sur 34 en 64), celle d'en face se contentait du reste.

## Ce que le brainstorm a donné

Le brainstorm du 2026-08-10 (`Brainstorming/…inondation-rive-droite.md`) a servi de plan pour l'étape 5 : ses trois idées transférables sont maintenant **dans les données**, pas dans une note.

| L'idée | Ce qui l'implémente |
|---|---|
| la **doctrine à seuil** (« je plante au-delà de X m ») | `emprise_libre_m`, qui a exigé que les largeurs de rue varient |
| le **modèle de trafic minimal** (charge → report → seuil) | `charge`, une affectation par plus court chemin en temps |
| « **rendre à l'eau** » | `alea`, `altitude_relative`, `position_fil_eau`, `rive` |

Reste en `brut` : le tableau `decisions` et les trois postures (reconstruire / adapter / rendre à l'eau).

---

## 2026-08-13 (session 19) — le parcellaire se débite depuis la rue

D'après **Vanegas et al., *Procedural Generation of Parcels in Urban Modeling*, Eurographics 2012**, apporté par l'auteur. Le défaut n'était pas où on l'attendait : **l'aire tombait juste, la forme était fausse**. La découpe par boîte englobante ne respectait que le **produit** façade × profondeur — un cœur ancien sortait à 111,7 m² pour 112 visés, mais en carré de 10,6 m au lieu d'une lanière de 7 × 16 ; une parcelle sur deux tournait le dos à la rue ; **30 % n'avaient aucune façade**, donc aucun bâtiment. Le **peigne** (méthode « skeleton » du papier) longe chaque rue, prend une bande profonde comme le tissu le demande, la débite en dents larges comme la façade visée, et laisse au milieu ce qu'aucune rue n'a réclamé : le cœur d'îlot. L'élancement tombe sur sa cible dans les quatre tissus de rue (2,07 / 2,39 / 2,04 / 1,48 pour 2,29 / 2,50 / 2,07 / 1,64), les parcelles sans façade passent de **30 % à 1 %**, et **987 parcelles porteront une maison contre 705**. La boîte n'est pas jetée : elle garde les deux rôles que le papier lui laisse — les gros objets, et le remplissage du cœur.

🎯 Trois trouvailles à garder : **la rue la plus longue doit prendre le coin** (sinon le coin est orphelin et finit en éclats — 82 morceaux de cœur sur le seul îlot 35) · **on ne coupe que ce qui touche la rue** (sinon les droites de chaque arête viennent tailler le cœur à l'autre bout de l'îlot) · et **un seuil serré n'est pas un seuil sûr** : le contrôle d'aire de la réunion d'éclats refusait onze fusions justes parce qu'il était réglé sur le **bruit du flottant** (2,4·10⁻⁴ m², soit exactement 2⁻¹² sur des coordonnées à six chiffres).

✂️ **Les parcelles trop petites sont réunies à leur voisine de plus long bord** (papier §4.2.3) : 48 réunies, **aucune ne survit**, la plus petite parcelle de la ville fait 45,2 m². 👁️ Et le parcellaire **se voit enfin** : `apercu_parcelles.py`, qui n'existait pas — ni `apercu_carte` ni `06` ne dessinaient les parcelles.

⚠️ La session s'est faite pendant que l'auteur redécoupait l'ouest de Wehrau dans QGIS : la carte est passée à **70 îlots et 177 tronçons**, et `02` a effacé `emprises`/`parcelles` en cours de route — elles ont été refaites sur la carte neuve (`04b` puis `04c`).

## 2026-08-12 (session 18) — le système énergie, de la table au bandeau

Tout le périmètre d'un coup : `energie.gd` (la table des treize lignes, les deux dérives), les deux décisions à l'**îlot** avec la troisième durée « travaux », les retours d'argent au **tarif figé au mois de la décision**, le refus qui contrôle le budget **et** le capital, les trois calques (les îlots sans toit ne sont **pas peints**), la fiche décomposée (« couverture 12 % : 8 produits, 4 économisés »), le bandeau à quatre nombres, les toits qui virent à l'ardoise, et `essai_energie.gd` — le contrôle imprimé qui joue **deux parties en aveugle** : panneaux seuls bloque sur le capital, isolation seule sur le budget, remboursement de la barre au mois 111 comme calculé.

🔴 La découverte de la session : **le potentiel réel des toits est ~9,5 %**, la fourchette 25–40 % du plan avait été calibrée sur l'emprise, pas sur les toits. La vue chantiers est **reportée** par l'auteur.

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
- ✂️ **Le prototype est réduit** (**66**) : D07, les arbres d'alignement, la surchauffe, les quatre moyennes de ville et les six calques sortent du code actif. **Supprimés, pas masqués** — `Prototype/Énergie.md` §2 proposait l'inverse. Tout est dans `Godot/archive/`, commenté, avec ce que coûterait le retour (une demi-journée). 🟢 `canopee` reste calculée : c'est elle qui fait l'ombrage des toits. *Une donnée n'est pas un indicateur.*
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
