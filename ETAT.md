# ETAT.md — où on en est

> Mis à jour par Claude en fin de session. Complément de [CLAUDE.md](CLAUDE.md).
> **Ce fichier est un signet, pas une source.** Design = le vault. Carte = `QGIS/data/source/*.geojson`.

| Si tu cherches | Va voir |
|---|---|
| **le prototype, ses étapes, celle qui est ouverte** | [Prototype/00 - Prototype.md](Prototype/00%20-%20Prototype.md) |
| ce qui attend, les défauts connus, les tables à régler | [CHANTIERS.md](CHANTIERS.md) |
| ce qui s'est passé, et pourquoi c'est comme ça | [HISTORIQUE.md](HISTORIQUE.md) |
| ce qui est tranché | `Méta/Décisions arrêtées.md` (vault) |

**Dernière mise à jour : 2026-08-19 (session 48)**

🅿️ **La place du marché montre enfin ses 123 places.** Demandé en une phrase :
*« dessine des places de parc sur la place centrale. regarde comment faire de
manière procédurale. »* L'îlot 19 est le seul îlot de **sol** qui porte du
stationnement — `04` lui compte **127 places** depuis toujours, et ce nombre
n'existait que dans la fiche : à l'écran, la place la plus centrale de la ville,
celle qui **est** le sujet du jeu, était un aplat gris de 5 800 m². Cinq règles
et aucune ne nomme un îlot : la **direction** est celle de la plus longue arête
de l'emprise (donc la plus longue façade sur rue) ; le **module** est une allée
de 6 m et deux rangées de 5 m dos à dos, soit 16 m répétés ; la trame **glisse**
en 80 positions et on garde celle qui range le plus ; une place tient si ses
**quatre coins** sont dans l'emprise retirée de 3 m ; et elle doit avoir **3 m
d'allée devant elle**, sinon elle est enclavée. Mesuré : **123 places rangées
contre 127 annoncées, écart −3 %** — et c'est le **seul contrôle du projet qui
confronte deux chaînes**, la géométrie répondant à un nombre que `04` a calculé
sans elle. 78 traits, **156 triangles**, 24,9 m² par place. Le **dos des deux
rangées est un seul trait** (peint deux fois, il clignoterait sur toute la
longueur), la peinture est 1 cm au-dessus du **sol** et non de la chaussée
(reprise telle quelle, elle passait 6 cm dessous, invisible), et les **2 arbres
de la place tiennent le bord** par un rejet de plus dans le semis — sans quoi un
sur deux poussait au milieu d'une place peinte. Nouvelle vue `M` et capture
`wehrau_essai_place.png`. Chaîne complète et essai Godot au vert.
→ [Prototype/Toits et sol.md](Prototype/Toits%20et%20sol.md) § 3 nonies

🌉 **Les parapets des ponts s'arrêtent au bord de l'eau.** Demandé juste
après le quai : *« les murs des ponts sont encore dans les routes des berges.
Ils doivent s'arrêter aux berges. »* Le pont était resté sur son ancienne
règle : son muret courait sur **toute la plage du tablier, culées comprises**,
donc 2,5 m au-delà de la berge géométrique — et le bord de l'eau qu'on voit est
encore ~5 m plus loin, au nu du quai qui porte la voie de berge. Le muret
finissait **7 m après la rive apparente**, en travers du carrefour, à chaque bout
de chaque pont. La règle ne mesure plus rien : **le parapet d'un pont ne borde
que l'eau libre** — ni la terre, ni ce que le quai porte déjà. Le tablier, lui,
garde ses culées : seul ce qui dépasse du sol s'arrête. Mesuré : **56 m de
muret retirés de la voie de berge** et 2 m de la terre, **180 m gardés sur l'eau
en 6 bouts** (un par joue, 6 attendus pour 3 ponts), 8 158 triangles au lieu de
8 368 ; l'asphalte porté reste à **100,0 %** et le dépassement visible à 0,17 m.
Les deux parapets se rejoignent **en équerre au coin de la culée**, et le bout
est coupé par dichotomie et non à la station — 2 m de trop remettaient le mur
sur la chaussée. Chaîne complète et essai Godot au vert, captures régénérées.
→ [Prototype/Toits et sol.md](Prototype/Toits%20et%20sol.md) § 3 octies

🧱 **Le mur de quai suit maintenant la berge, plus la route.** Demandé sur
capture : *« les murs au bord des routes au bord du fleuve ne fonctionnent pas
bien. Ils doivent seulement longer le fleuve. »* Il était un **décalé de la
chaussée**, donc il héritait de ses **évasements de carrefour** — d'où des bouts
de mur en travers du débouché de chaque rue perpendiculaire, **21 morceaux** à
bouts francs dont un de 3,2 m tout seul dans l'eau, et un tracé qui s'écartait
jusqu'à **47°** de la direction de la rive. Les arêtes de berge sont désormais
**recousues en polylignes continues** et le mur y est bâti directement ; il ne
s'avance sur l'eau que là où l'asphalte y déborde, et **seule une rue qui longe**
(45° au plus) peut le déplacer — sans quoi le quai partait en festons, essayé et
vu. Mesuré : **1,37 km de quai en 4 longueurs continues** au lieu de 21
morceaux, **100,0 %** de l'asphalte porté (98,7 % avant), le seul dépassement
visible tombe de **4,22 m à 0,17 m**, 8 368 triangles au lieu de 9 338, et
**150 lignes** de détection à la volée ont disparu — la berge, elle, sait où elle
est. Le morceau de quai reste dans le **groupe de sa rue** : cliquer un parapet
ouvre toujours sa fiche. Chaîne complète et essai Godot au vert, captures
régénérées.
→ [Prototype/Toits et sol.md](Prototype/Toits%20et%20sol.md) § 3 septies

🏢 **Les barres redescendent à la taille de Wehrau.** Demandé devant la
capture : *« surdimensionnées pour une petite ville, moins larges et haute, et
mets-en 3 »*. L'îlot 32 porte maintenant **trois dalles de 46, 57 et 58 m** au
lieu de deux de 116 et 93, **à 6 niveaux au lieu de 9** — 2 003 m² d'emprise au
sol contre 2 674, 99 logements contre 198, et Wehrau retombe à **5 517
habitants, 103 % de la cible du vault** au lieu de 107 %. Trois nombres
seulement : le produit `façade × profondeur` fait le **compte** (trois parcelles
au lieu de deux), la profondeur seule fait le **sens de la découpe** — sous 76 m
il sortait une lanière de 136 m de long, une barre de Großstadt — et la densité
**suit** la hauteur au lieu de se choisir à part. 🔴 **6 et pas 5, et c'est
l'image qui a tranché** : à 5 niveaux les barres passaient sous les faîtages du
cœur ancien et l'îlot 32 cessait d'être le point haut de la ville. ⚠️ **Un
critère du vault dit toujours « 9 niveaux »** (`Plan 3 mois.md:48`) : à
réécrire ou à annuler, et ça ne se tranche pas ici. Un contrôle énergie est
tombé au rouge — son seuil était calé en dur sur les 198 anciens logements ; il
compare désormais la baisse à ce que la table promet, et les 25 sont au vert.
Captures refaites : `wehrau_essai_barre.png` (touche `B`) et
`parcelles_ilot_32.png`.
→ [Prototype/Toits et sol.md](Prototype/Toits%20et%20sol.md) § 3 sexies

🌉 **Les routes ne volent plus sur l'eau.** Demandé en trois phrases : un
mur entre l'eau et la route, un parapet qui dépasse d'un mètre, et les
franchissements transformés en ponts. **7 212 m² d'asphalte flottaient au-dessus
du chenal**, sur 42 tronçons — mesuré avant de toucher à quoi que ce soit. La
règle ne nomme aucune rue : on regarde, station par station, si l'eau est sous
**un** bord de la chaussée (on longe → un **quai porté**) ou sous **les deux** sur
au moins 8 m (on traverse → un **pont**, avec tablier, joues et pile). Une seule
ligne de mur suit la route, et sa distance à l'axe est le plus dehors des deux :
la berge, ou le bord de l'asphalte. Ce qui change, c'est jusqu'où elle descend.
Mesuré : **3 ponts** (119 m de tablier, 3 piles), **1,51 km de quai porté**,
**1,74 km de parapet**, 9 338 triangles — et **98,7 % de l'asphalte est
porté**, le reste étant masqué derrière un parapet sauf **5 m²**. Les quais
prennent **6 m** à l'Ilse (38 m de large en médiane, 32 m après) : c'est le prix
de porter la rue là où elle est tracée. Nouvelle vue `O` et deux captures,
`wehrau_essai_pont.png` et `wehrau_essai_quai.png`.
→ [Prototype/Toits et sol.md](Prototype/Toits%20et%20sol.md) § 3 quinquies

⏸️ **Point de sauvegarde, pas fin des travaux.** Trois sujets sont encore en
chantier au moment de ce commit. La session s'arrête parce que la **limite de
tokens a été atteinte** ; ils sont à reprendre et à vérifier avant d'ouvrir un
quatrième sujet. → [CHANTIERS.md](CHANTIERS.md) § « Point de reprise »

🪟 **Les murs sont percés, et la ville se met à l'échelle humaine.** Demandé
en une phrase — *« fais aussi la génération procédurale des fenêtres »*. Aucune
fenêtre n'est un triangle : elles sont dessinées par le matériau, comme les
rangs de tuile et les panneaux. L'export décide, mur par mur, **le genre de
percement** — **2 552 murs percés sur 3 547**, soit **23,99 km de façade** :
**995 aveugles** (les pignons mitoyens, qui font la rangée du cœur ancien),
**1 737 en fenêtres**, **697 avec la porte** (une par bâtiment, jamais deux),
**82 en vitrine** sur le front commerçant et **40 en bandeau filant** sur les
trois barres de 1974 (36 quand elles n'étaient que deux). Les travées sont **centrées sur chaque façade** et leur entraxe
est tiré du bâtiment, donc deux mitoyennes n'ont pas le même rythme ; les
rangées s'alignent sur les planchers réels, donc aucune n'est coupée par
l'égout. De loin, le percement **s'efface** en un mur un peu plus sombre au
lieu de grésiller. Nouvelle capture `wehrau_essai_facades.png` — sans elle le
lot ne se voit sur aucune image. **0 triangle ajouté, 0,2 s d'export.**
→ [Prototype/Toits et sol.md](Prototype/Toits%20et%20sol.md) § 2 bis

🌊 **L'Ilse coule 2 m sous la ville, et les champs y descendent.** Demandé avec
une coupe dessinée. La ville reste plate ; ce qui change vraiment, c'est qu'il y
a maintenant **deux bords d'eau** au lieu d'un seul — et c'est la même règle qui
fait les deux : *le mur de quai monte jusqu'à la surface du sol*. Là où la ville
tient la rive, le mur fait **2,6 m** ; là où c'est un champ, le sol est déjà au
ras de l'eau et il n'en reste qu'une lèvre noyée. Mesuré : **4 champs riverains,
984 m de rive en pente à 22 %** sur 2 475 m de berge, **2 019 mailles de talus**,
le sol descend à **−2,15 m** — 15 cm sous la nappe, pour que le trait d'eau
tombe *dans* la pente. Le talus tient dans **une seule fonction** que tout ce
qui touche le sol interroge (plaque, champ, bandes de fauche, arbres, haut du
mur), donc aucune de ces surfaces ne peut se fendre sur une autre. Nouvelle vue
`G` et nouvelle capture `wehrau_essai_berge.png` : les quatre autres repères
sont tous posés sur la ville, où le sol est plat.
→ [Prototype/Toits et sol.md](Prototype/Toits%20et%20sol.md) § 3 quater

📈 **La maquette montre maintenant son propre coût.** Un panneau compact en
haut donne les ips, le temps d'image et CPU, les triangles, appels de rendu,
nœuds et mémoires ; `F3` le masque. Les seuils sont visibles sans lire un log :
vert, orange sous **55 ips**, rouge sous **30**. Mesure sur la ville entière :
**180 ips · 5,6 ms/image · 496 appels · 258 Mio**. Il disparaît pendant
`--essai`, donc les captures de référence restent propres et comparables.
→ [Prototype/Toits et sol.md](Prototype/Toits%20et%20sol.md) § 5 quater

🏡 **Le pavillonnaire est vert, accessible et clos.** Les **174 parcelles
bâties sur 174** sont maintenant vertes : l'ancien tirage qui en laissait 8 %
en gris ne s'applique plus à ce tissu. Chacune reçoit le plus court chemin
maison→route parmi ceux qui arrivent perpendiculairement à la rue : **174
accès, 749,4 m**, écart maximal **0,0000°**. La haie fait tout le tour de la
parcelle sauf à cette ouverture : **820 tronçons, 10,32 km**. Aucun autre tissu
n'est touché. Chaîne complète et essai Godot au vert ; captures régénérées.
→ [Prototype/Toits et sol.md](Prototype/Toits%20et%20sol.md) § 3 bis

🌞 **Les panneaux se posent maintenant pan par pan et tournent avec chaque
bâtiment.** La grille mondiale a été remplacée par l'axe de faîtage déjà
calculé pour chacun des **756 volumes**. Sur un toit incliné, le versant le
mieux exposé se remplit de 0 à 50 %, puis l'autre de 50 à 100 % ; un toit plat
reste un seul pan. La capture `wehrau_essai_solaire_pans.png` arrête l'îlot 22
à **50 %** : un pan bleu entier, l'autre encore en tuile, avec des rangées qui
changent de direction d'une maison à sa voisine. Surface solaire, économie et
durée inchangées ; chaîne complète et essai Godot au vert.
→ [Prototype/Toits et sol.md](Prototype/Toits%20et%20sol.md) § 5 ter

🌳 **Aucun tronc ne reste dans l'asphalte.** Les arbres d'alignement savaient
s'écarter de leur propre rue, mais pas de la chaussée qui la croise au
carrefour ni de son axe une fois arrondi. L'export contrôle maintenant toutes
les chaussées affichées, rallonges de carrefour et largeur du tronc comprises :
**1 arbre semé et 150 emplacements écartés**, dont **42 visibles à t0** ; il
reste **0 arbre dans la chaussée et 0 dans l'eau**. Chaîne complète et essai
Godot au vert ; `wehrau_essai_ville.png` régénérée.
→ [Prototype/Toits et sol.md](Prototype/Toits%20et%20sol.md) § 3

🚦 **Les rues ont leur marquage, et personne n'a posé un seul trait.**
Demandé en une phrase — *« dessine les lignes blanches et les passages piétons,
procédural avec des règles, pas à la main »*. Le marquage est donc une petite
voirie de **sept règles** qui ne lisent que des choses déjà dans la donnée : la
largeur de chaussée décide s'il y a une ligne d'axe (**5,5 m**, sinon la rue
n'a qu'une voie), la hiérarchie décide des **lignes de rive** (boulevard et
quai seulement), le **nombre de branches à chaque nœud** décide où le marquage
s'arrête et où se posent les traversées, et la **courbure de l'axe** décide où
la ligne du milieu devient pleine — on ne double pas dans un virage.
Mesuré : **260 passages piétons (2 171 bandes)**, **999 traits d'axe**, **23
portions pleines de virage**, **110 lignes de rive**, pour **7 232 triangles**
sur 56 698. 🔴 **La règle qui fait le tri toute seule** est celle du passage
piéton : elle exige un trottoir des deux côtés, donc elle exclut d'un coup les
**35 tronçons** trop étroits — les ruelles de 5 m, *et les rues de 10 m*, où il
ne reste que 65 cm entre l'asphalte et la parcelle. Ce n'est pas une liste
d'exceptions, c'est la conséquence d'un seuil déjà arrêté pour le trottoir : si
le centre manque de traversées, c'est **la largeur des rues** qu'il faut
regarder. ⚠️ **Un défaut de carte est sorti au passage** : **22 passages ont été
refusés au-dessus de l'eau**, et les trois ponts n'en expliquent qu'une part —
l'axe des **quais** passe par endroits au-dessus du chenal. Essai Godot au vert,
captures régénérées.
→ [Prototype/Toits et sol.md](Prototype/Toits%20et%20sol.md) § 3 ter

🌿 **Le pavillonnaire a maintenant ses haies.** Les **174 parcelles
bâties sur 174** portent une haie basse sur leurs limites latérales et
arrière ; la rue reste ouverte et une limite partagée n'est dessinée qu'une
fois. Mesure de l'export : **430 tronçons uniques, 7,91 km**, zéro autre tissu
touché. Chaîne complète, contrôles et essai Godot au vert ; capture
`wehrau_essai_ville.png` régénérée. → [Prototype/Toits et sol.md](Prototype/Toits%20et%20sol.md) § 3 bis

✏️ **L'objet choisi est cerné d'un trait jaune clair qui épouse sa
silhouette.** L'éclaircissement ne suffisait plus : sur les toits clairs du
nouveau rendu, ou sous la touche `C` qui repeint tout, « un peu plus lumineux »
ne se distingue pas d'une variation de matériau. 🔴 **Le premier essai s'est
trompé de géométrie** : un ruban posé **au sol** le long de l'anneau de l'îlot
— les bâtiments en sortaient, et dans le cœur ancien ils le cachaient (l'îlot
22 n'en montrait qu'un tiers). Aucune ligne au sol ne peut entourer un volume.
Le trait est maintenant calculé **à l'écran** : l'objet choisi est redessiné
seul dans une petite vue à part, avec la même caméra, et un shader allume les
pixels vides à moins de **3 pixels** de cette silhouette. Il suit donc les
pignons, les débords de toit et les cheminées, il fait le tour de la cour
d'îlot et il garde la **même épaisseur à tous les zooms**. 🔴 **Une rue fait
exception** : un tronçon est fait de morceaux disjoints — chaussée, mètres
libres, un bout de trottoir par îlot riverain, séparés de 2,6 m — et il
ressortait en bandes parallèles. `07` exporte donc son **couloir** (axe +
largeur façade à façade, 14,6 m en moyenne sur 174 tronçons), dont Godot fait
un ruban plat jamais affiché qui n'existe que pour être détouré. Essai complet
au vert, captures régénérées.
🔴 **Deuxième correction, dans la foulée** : *« il y a des trous dans les zones
grises »*. La silhouette **rendue** ne connaît que ce qui est dessiné, et un
îlot bâti **ne dessine pas son sol** — sous les barres de l'îlot 32 il n'y a
que la plaque de terrain, qui n'appartient à personne. Le trait collait donc
aux bâtiments et laissait le gris dehors. `07` exporte maintenant aussi
l'**emprise au sol** (**65 îlots, 491 sommets**), dont Godot fait une plaque
plate jamais affichée, posée dans le masque **à côté** de la silhouette : le
trait suit l'**union des deux** — le sol de l'îlot *et* ce qui le dépasse en
hauteur. Ce n'est pas le ruban du premier essai qui revient : celui-là
remplaçait la silhouette, celle-ci la complète.
→ [Prototype/Toits et sol.md](Prototype/Toits%20et%20sol.md) § 5 bis

🛣️ **La rue a un bord, et elle tourne.** Demandé en deux phrases —
*« séparation chaussée trottoirs, courbes au lieu d'angles (sauf aux
croisements) »*. 🔴 **Ce que la version d'avant cachait** : le trottoir n'était
pas un trottoir, mais un quadrilatère **plus large que la chaussée, glissé
dessous** à 3 cm — ce qui dépassait en tenait lieu. Donc ni bordure, ni coin de
rue, et un carrefour noyé sous le recouvrement des deux rubans. Le trottoir
**appartient maintenant à l'îlot** : c'est un anneau de 2 m posé le long de la
limite de parcelle, avec une **bordure de 14 cm**, et il **tourne les coins
tout seul** — aucune ligne du code de voirie ne parle de carrefour, exactement
comme aucune ne parle de pont. **17,78 km de bordure, 65 îlots, 338 coins.**
Côté courbes : **25 des 33 coudes marqués sont arrondis**, les **122
carrefours** gardent leur angle. 🔴 **Le rayon n'est pas un goût, c'est ce que
le corridor accepte** : arrondir pousse le tracé vers l'intérieur du virage,
donc le trottoir extérieur gonfle et l'intérieur maigrit — quatre plafonds
mesurés par coude, 6 à 20 m de rayon. **Les coudes très serrés restent des
angles**, et c'est juste : dans une rue de 13 m, un virage à 90° est un angle
du tissu, les maisons le font aussi. ⚠️ **Deux défauts trouvés en chemin** : la
chaussée était **éclairée à l'envers** (3 060 normales sur 3 060 vers le bas —
elle ne recevait que l'ambiant), et le trottoir avait **la couleur du sol nu**
(2 % de valeur d'écart), donc il était invisible partout sauf contre
l'asphalte. → [Prototype/Toits et sol.md](Prototype/Toits%20et%20sol.md) §3 bis

🎨 **La couleur des bâtiments ne suit plus la typologie — Wehrau a des toits
en tuile.** L'auteur ouvre l'**étape 4, « Les toits et le sol »** devant une
photo aérienne de petite ville allemande. La règle qui saute est la plus
ancienne du rendu — *« un `sous_type` = une teinte »* — parce qu'elle posait la
**même couleur sur les murs et sur le toit** : chaque bâtiment était un solide
d'une seule teinte, et la ville sortait en blocs de pâte à modeler. Ce qui la
remplace n'est pas une peinture mais trois règles : **le toit et le mur sont
deux matériaux**, **le matériau découle de l'époque** (tuile sur l'ancien,
étanchéité sombre sur la barre de 1974, bac acier sur la halle, ardoise sur
l'équipement) et **chaque bâtiment tire sa teinte de sa position** (35), donc
deux maisons mitoyennes ne sont plus jumelles. Dans la même passe : le **débord
de toit** (0,40 m — c'est LUI qui fait qu'un volume cesse d'être une boîte),
l'**acrotère** des toits plats, **452 souches de cheminée**, les rangs de
tuiles dans le shader, les **trottoirs sur 174 tronçons sur 178**, les **198
bandes de fauche** des 7 champs, des arbres à tronc et à trois lobes (**1 150
feuillus, 170 conifères**) et le retour des **321 arbres d'alignement**,
exportés depuis toujours et jamais affichés. **Zéro asset.** Les trois ponts ne
plantent plus l'Ilse : **98 emplacements** écartés, dont **11 arbres visibles à
t0**, et contrôle bloquant à **0 arbre dans l'eau**.
🔴 La contrepartie, et c'était la condition : la **touche `C`** repeint la
ville par tissu, la palette d'avant, le temps d'un coup d'œil.
→ [Prototype/Toits et sol.md](Prototype/Toits%20et%20sol.md)

🏘️⛪ **La galerie a disparu ; l'église est protégée.** Le trait dessiné coupe
l'îlot 45 en **45 (0,51 ha) + 72 (0,42 ha)** par la nouvelle rue 181, avec un
écart de surface nul. Les deux moitiés sont des **fronts commerçants** ; la
catégorie de l'ancienne galerie disparaît, donc Wehrau retombe à **12
sous-types**. L'îlot **16** est maintenant l'église : son toit réel mesure
**172 m²**, mais la protection laisse **0 m² solaire équipable** ; curseur
verrouillé et refus du noyau. Chaîne
complète, contrôle énergie et essai visuel au vert ; capture
`wehrau_essai_eglise.png`. → [Prototype/Parcelles.md](Prototype/Parcelles.md) ·
[Prototype/Énergie.md](Prototype/Énergie.md) · `Décisions arrêtées` **71**

🏛️ **La ville possède tout — le logement compris.** Tranché pour simplifier :
il n'y a plus de toit des autres, donc plus de loyer de toiture, plus de
copropriété qui refuse, plus de deux régimes selon le tissu. **La question
n°22 est close le lendemain de son ouverture, et aucune ligne de calcul ne
bouge** : la décision ratifie ce que l'économie de la veille avait dû supposer
pour tourner. ⚠️ Une seule chose à tenir : **posséder un logement n'est pas
payer sa facture** — la ville est propriétaire-bailleur, ses locataires paient
leur électricité. Sans ça, les 7,9 M€/an d'énergie de Wehrau tomberaient dans
une caisse dotée de 0,36 M€/an. → `Décisions arrêtées` **70**

🆕 **La décision solaire se paie.** Une petite économie est revenue dans le
prototype : **260 €/m² posé** (× le coefficient de coût du tissu) et **150 €/MWh
produit**, et rien d'autre. La mairie a une **caisse** — 800 k€ au départ,
30 k€/mois de dotation — qui n'encaisse que les panneaux, jamais la facture des
habitants. La fiche annonce le prix avant de valider et **dit combien il manque**
quand la caisse ne suit pas. Mesuré après la restructuration : équiper les 54
îlots autorisés coûte **11,135 M€** pour **644 k€/an**, et l'amortissement classe
les tissus — **barre 10 ans, friche et équipement 11, pavillonnaire 18, maisons de ville 19,
front commerçant 20, cœur ancien 31**. Six contrôles imprimés au vert, capture
du refus comprise. → [Prototype/Énergie.md](Prototype/Énergie.md) ·
`Décisions arrêtées` **69**

🆕 **La décision solaire prend maintenant du temps — et le temps a ralenti
soixante fois.** La fiche annonce la durée avant validation ; la pose avance
ensuite vers la cible, en assombrissant les toits et en recalculant les deux
échelles au même rythme. **0 → 100 % prend 1 mois maximum** ; à mi-pose, l'îlot
32 affiche **50 % réalisés et 15 jours restants**. L'échelle de base est
désormais **une minute réelle pour un mois** (c'était une seconde : la pose
était finie avant qu'on ait relâché la souris). Le bandeau du bas donne pause,
×1, ×4 et ×12 ; `Espace` alterne lecture et pause. Contrôle Godot et captures à
0 %, 50 % et 100 % au vert.
→ [Prototype/Énergie.md](Prototype/Énergie.md)

🆕 **Le prototype énergie tient maintenant en une décision.** À gauche, quatre
conséquences pour toute la ville ; à droite, seulement l'îlot cliqué. Le
curseur augmente sa part solaire de sa valeur actuelle jusqu'à 100 %, sans
budget, capital, isolation ou calque. Contrôle réel sur l'îlot 32 :
**0 → 100 %**, production de ville **0,0 → 0,3 GWh/an**, achat **53,9 → 53,6**,
CO₂ **13,5 → 13,4 kt/an** ; les toits passent visiblement à l'ardoise sombre.
→ [Prototype/Énergie.md](Prototype/Énergie.md) · `Décisions arrêtées` **68**

🆕 **Godot montre les bâtiments de la carte restructurée.** `07_exporter_godot.py` lit directement la couche `batiments` de `04d` au lieu de recalculer sa propre ville. Résultat vérifié dans les captures : **756 volumes sur 751 parcelles bâties**, cours et jardins visibles sous les volumes, **zéro bâtiment hors parcelle**, **11,0 ha de toiture réelle pente comprise**. Les captures ont été régénérées. → [Prototype/Parcelles.md](Prototype/Parcelles.md) §2 septies

🆕 **Le bâtiment n'a plus droit qu'à UNE équerre.** L'auteur a regardé les îlots 40 et 41 : *« l'îlot 40 a encore des parcelles bizarres avec des formes de bâtiment pas réalistes, et l'îlot 41 a des coins encore à corriger »*. C'était la suite annoncée la veille — les doigts de cour et les ressauts en escalier. Le critère n'est pas une largeur mais **le nombre de décrochements rentrants** : mesuré sur les 701 empreintes, 542 n'en ont aucun, **131 en ont un** (l'équerre : immeuble d'angle, maison + aile arrière — les deux voulues), 28 en ont deux ou trois, et **aucune de ces 28 n'a d'excuse**. Deux règles : ① **l'aile arrière est enfin vérifiée adossée** — sa docstring le promettait depuis le premier jour sans que rien ne le contrôle, et sur une parcelle d'angle elle s'adossait à son propre bâtiment, au milieu de la cour ; ② **l'encoche se referme**, après l'aile et pas avant, la plus petite poche d'abord. **28 → 15** empreintes à deux décrochements, **2 → 0** en C, **52 encoches refermées**. R0 (0), R2 bis (16), emprises, cour du cœur ancien et partition inchangés ; toit 9,00 → **9,02 ha**. → [Prototype/Parcelles.md](Prototype/Parcelles.md) §2 nonies

🔴 **Et l'îlot 40 n'est réparé qu'à moitié : ce qu'il reste est dans la PARCELLE.** Le bout sud-est que l'auteur a entouré garde une parcelle en flèche (435), une lanière (443) et deux replis (438). **118 parcelles de rue sur 809 ont un sommet rentrant**, et le compte ne bouge pas quand on éteint la soudure des coins (119 → 118) : **c'est le peigne de `04c`, pas la soudure**. Une empreinte propre dans une parcelle en dard laisse quand même le dard en beige à l'écran. → [CHANTIERS.md](CHANTIERS.md) §1 n°8

🆕 **Le coin d'îlot tourne enfin.** L'auteur a dessiné trois fois l'emprise voulue par-dessus l'image (îlots 40, 41, 59) : *« c'est surtout les coins d'îlots que je trouve encore problématiques »*. Deux causes, une par script. ① **`04c`** — la rue la plus longue prend le coin, donc la parcelle d'angle n'avait qu'un **flanc** sur l'autre rue : façade faible **7,4 m** en médiane. La parcelle du coin absorbe maintenant sa voisine du côté faible (**118 soudures sur 36 îlots**) → façade faible **12,6 m**, et **122 coins sur 163** ont leurs deux bras, contre 48. ② **`04d`** — la réunion des deux bandes laissait une cour **au milieu** de la masse, d'où le bâtiment en C ; une tranche enfermée par le bâtiment y repart désormais (**152 poches comblées**) → **7 → 2** bâtiments à trois coins rentrants. Emprises, cour du cœur ancien, R0 et partition inchangés. **927 → 809 parcelles**, toit 8,86 → **9,00 ha**. → [Prototype/Parcelles.md](Prototype/Parcelles.md) §2 octies

🆕 **Le bâtiment n'est plus la parcelle.** L'auteur a relu `parcelles_ilot_14.png` : *« les bâtiments ressemblent trop aux parcelles »*. La cause était la table de `04d`, où le cœur ancien et les maisons de ville n'avaient **aucune règle de profondeur** — l'empreinte *était* la parcelle, à **0,96** près. Maintenant le bâtiment est une **bande mesurée depuis chaque limite sur rue**, et le reste est cour ou jardin. **Cour en cœur ancien : 4 % → 24 %** · emprises 0,96 → **0,76** (cœur ancien), 0,65 → **0,56** (maisons de ville) · façades reculées 22 → **19** · **0 bâtiment hors de sa parcelle** · **81 ailes arrière**, **18 pointes rendues au jardin**, **37 parcelles traversantes qui portent deux bâtiments**. La surface de toit passe de 10,12 à **8,86 ha**. → [Prototype/Parcelles.md](Prototype/Parcelles.md) §2 septies

🆕 **`04d` est dans la chaîne et alimente maintenant Godot.** La chaîne est **02 → 03 → 04 → 04b → 04c → 04d → 07** avec `--godot` ; l'aperçu 2D et la maquette 3D lisent la même empreinte. → [CHANTIERS.md](CHANTIERS.md) §0

🆕 **Les venelles sont réintégrées dans la chaîne procédurale.** Après la passe à blanc, les six tracés récupérés ont été écrits dans `QGIS/data/source/chemins.geojson`, puis la chaîne complète a tourné jusqu'à Godot. Résultat : **6 venelles sur les îlots 22, 24, 26, 38, 44 et 63 · 588 m² pavés · 927 parcelles dont 912 sur rue · zéro reliquat enclavé · partition 100,00 % · 892 volumes bâtis · 12,1 ha de toit réel**. Le septième tracé annoncé autrefois sur l'îlot 40 n'avait jamais été enregistré et ne passe plus le seuil de rectangularité. → [Prototype/Parcelles.md](Prototype/Parcelles.md) §4 · §4 bis

🆕 **QGIS est sorti du projet, et la carte est devenue du texte.** L'auteur ayant acté qu'il n'ouvrirait plus QGIS, plus rien n'obligeait la source à être un GeoPackage. Elle est maintenant **`QGIS/data/source/*.geojson`** — 66 ko de texte, une entité par ligne, que **git fusionne**. Tout `.gpkg` est un dérivé, gitignoré, refait par **`python QGIS/scripts/chaine.py`** en **0,7 s**. Ce que ça supprime : la règle « la carte ne s'écrit que sous Windows », les six commandes à lancer dans l'ordre, et le risque qu'une carte du dépôt soit plus vieille que le code. → [QGIS/data/LISEZ-MOI.md](QGIS/data/LISEZ-MOI.md) · `CLAUDE.md` §5

🆕 **Les deux derniers défauts désignés sur l'image sont corrigés** — *« c'est bien mieux »*. ① **La direction des parcelles** (îlots 63 et 26) : le petit côté d'un îlot allongé réclamait 58 m de fond pour 28 visés, et le bout de l'îlot sortait en dalles couchées en travers du tissu. Le plafond de profondeur vaut maintenant **même en pavillonnaire** (`PROF_MAX = 1,3`). ② **Deux triangles qui font un rectangle** (îlot 13) : la coupe en diagonale s'efface, **2 fois en ville**, là où l'ancien seuil de pointe coûtait 14 % des maisons. **893 → 912 parcelles sur rue**, zéro enclavée, partition toujours à 100,00 %. → [Prototype/Parcelles.md](Prototype/Parcelles.md) §2 quinquies · §2 sexies

🆕 **Le chemin dans l'îlot** — quand le peigne bute sur un îlot en L, on ne coupe plus l'îlot : on y dessine une **venelle de 3 à 5 m**, retirée de l'emprise avant la découpe. 70 îlots restent 70, et le coude a enfin un devant et un derrière. **6 chemins sur Wehrau, 588 m².** → [Prototype/Parcelles.md](Prototype/Parcelles.md) §4 bis · `Décisions arrêtées` **67 · 67b · 67c**

🆕 **Le prototype a sa catégorie, à côté du vault** : [`Prototype/`](Prototype/00%20-%20Prototype.md) — une note par étape, **une seule ouverte à la fois**. L'étape en cours est [**les parcelles**](Prototype/Parcelles.md). Le vault garde toutes les idées et reste la source de vérité du design ; `Prototype/` porte le chantier. → `CLAUDE.md` §2

---

## Ce qui existe aujourd'hui

| | Où |
|---|---|
| **La carte simulable** — 0,93 km², **71 îlots, 178 tronçons**, 12 sous-types, 16 exceptions, **3 franchissements** | source : `QGIS/data/source/` · travail : `QGIS/data/travail/wehrau.gpkg` |
| **La ville bâtie** — **870 parcelles logiques dont 851 sur rue** — plus **6 chemins** dans la couche —, aucune sous 45 m², **zéro reliquat de rue enclavé**, partition à 100,00 %, 16 cœurs d'îlot en 18 morceaux et **6 venelles** | source : `chemins.geojson` · dérivés : `emprises`, `parcelles` |
| **Les bâtiments** — **756 empreintes sur 751 parcelles**, une bande depuis la rue, une cour derrière, **un immeuble d'angle qui tourne la rue** et **au plus une équerre par empreinte**, **9,50 ha d'emprise de toit / 11,0 ha de toiture pente comprise**, zéro hors parcelle. **Godot lit cette couche directement** | dérivé : couche `batiments` de `04d` · `Godot/data/wehrau.json` |
| **La maquette 3D cliquable** — 239 objets cliquables, fiche à l'îlot et au tronçon, **ville plate**, l'Ilse **2 m plus bas** avec ses quais droits, **le talus des 4 champs riverains** et ses trois ponts | `Godot/` → `Godot/README.md` |
| **Le rendu réaliste** — toit ≠ mur, matériau par époque, teinte par bâtiment, débord de toit, cheminées, **trottoirs à bordure qui tournent les coins**, **rues courbes**, **marquage au sol procédural** (axe, rives, 260 passages piétons), **123 places de parc peintes sur la place du marché**, champs rayés, arbres à tronc — et la touche `C` qui rend la lecture par tissu | 🎯 **étape ouverte** → [Prototype/Toits et sol.md](Prototype/Toits%20et%20sol.md) |
| **Le classeur** — 3 parties jouées sur 60 mois, courbes et carte au mois M | `Classeur/` · `QGIS/rendus/parties.html` |
| **Le système énergie** — une décision à l'îlot, part solaire 0–100 %, ville à gauche et îlot cliqué à droite, **et une caisse qui limite le rythme** | ✅ **économie branchée et capturée, à regarder** → [Prototype/Énergie.md](Prototype/Énergie.md) |
| D07, la surchauffe, les quatre moyennes de ville, les six calques | ✂️ **supprimés** (66), archivés dans `Godot/archive/` |

**Les trois contrôles qui comptent, au vert** : la ville privée de sa rivière tombe en **deux morceaux (45 et 11 îlots)** · le réseau routier est **d'un seul tenant** · l'**axe de transit sort tout seul** de l'affectation de trafic.

## Ce qui commande le reste

- 🎯 **Le prototype énergie teste le lien local → global** (68), **et depuis
  la 69 il teste aussi « où investir ? »** : une seule décision, mais elle a un
  prix et un rendement qui dépendent du tissu. La paire de décisions opposées,
  le capital politique et l'isolation restent une ambition du jeu complet.
- 🔗 **La 3D et l'énergie se rejoignent sur le toit** (41 · 56 · 64) : la 3D produit `toit_m2`, `toit_pente`, `toit_plat` et l'ombrage ; l'énergie les lit sans savoir qui parle. **L'énergie n'attend jamais la 3D.**
- 🔓 **Claude écrit ET exécute les scripts de données** (65). Les garde-fous ont maigri le 2026-08-17 avec le passage en texte : arbre git propre avant d'écrire **la source** · passe `--blanc` d'abord **pour les trois scripts qui la touchent** (`00`, `00b`, `tracer_chemins` — c'est du level design) · contrôles imprimés en français, qui eux ne bougent pas. Écrire un `.gpkg` ne demande plus rien : il est dérivé. → `CLAUDE.md` §3
- 🏘️ **Le prototype est Wehrau**, une petite ville qu'on voit en entier (13b · 13d). Vallmar reste la ville du jeu complet, intacte dans le vault. Une ville entière, même petite, a **un amont et un aval** ; un quartier n'en a pas.
- 🎨 **Townscaper pour le rendu** (42b), et **Wehrau est pastel au sol minéral** (42c). 🔄 **Depuis le 2026-08-18, le pastel est celui des MURS seulement** : le toit est un matériau, et c'est lui qui rend le pastel des murs visible. ⚠️ La ligne *« un `sous_type` = une teinte »* de la DA est à réécrire
- 🗺️ **La carte est plate** (2026-08-12) — dans l'image ET dans la donnée. Le seul relief est le **chenal de l'Ilse** : murs verticaux, fond à −2 m, plan d'eau à −1 m. Ce que ça a supprimé : le champ d'altitude, la vallée, l'exagération verticale, la subdivision des sols et des chaussées. **La voirie reste à 0** : au-dessus du chenal elle passe au-dessus du vide, donc les trois ponts existent sans qu'une ligne de code parle de pont.
- 💧 **La crue sort du prototype** (2026-08-12, demandé en cours de session) : `alea` et `altitude_relative` restent dans le `.gpkg` **à 0**, ne sont plus exportés vers Godot, et leurs calques et stocks sont retirés de `06`. Ce qui reste de l'eau est ce qui reste vrai sans elle — **deux rives inégales et trois ponts**. ⚠️ À reporter dans le vault : le jeu s'ouvrait sur une crue rive gauche (**23b**).
- 🔴 **Ce que la coupe a coûté, et ce qui en est revenu** : le dilemme
  panneaux/isolation n'est toujours pas testé. Le temps est revenu comme durée
  de pose visible (31), et l'argent comme coût et rendement (32) — mais **en
  euros, pas en points** : l'ancien noyau à points reste isolé comme trace et
  ne se réactive pas. Les deux dérives de prix restent écrites et débranchées.

## Prochaine action

### 👁️ Juger l'échange : la ville est-elle plus belle, et reste-t-elle lisible ?

```bash
python QGIS/scripts/chaine.py --godot
```

```bash
"C:/Users/janha/Desktop/Godot_v4.7.1-stable_win64.exe/Godot_v4.7.1-stable_win64_console.exe" --path Godot -- --essai
```

🅿️ **Regarde d'abord LA PLACE-PARKING**, c'est ce qui a bougé aujourd'hui —
touche `M` dans la maquette, ou `wehrau_essai_place.png` (cadrage de 130 m,
**68° au-dessus** : un marquage au sol se juge de dessus, et une place de
2,5 m tient sur un demi-pixel à la vue par défaut) :

| Ce qu'il faut voir | Ce qui prouverait que c'est cassé |
|---|---|
| **quatre bandes de places dos à dos**, inclinées comme la plus longue façade | des rangées parallèles au cadre de l'écran, ou à une seule direction du monde |
| les rangées qui **s'effilochent** contre les bords obliques | une trame coupée au carré, ou qui déborde sur le trottoir |
| **un seul trait** entre les deux rangées d'une bande | un trait qui **clignote** au zoom — deux peintures au même endroit |
| les **2 arbres au bord** de la place | un arbre planté au milieu d'une place peinte |
| le contrôle imprimé par `07` : **123 rangées / 127 annoncées, −3 %** | un écart de plus de 10 % — l'un des deux ment |

🪟 **Puis LES FAÇADES**, qui ont leur propre vue,
`wehrau_essai_facades.png` (cadrage de 150 m, 14° au-dessus, la hauteur d'un
piéton au bout de la rue) :

| Ce qu'il faut voir | Ce qui prouverait que c'est cassé |
|---|---|
| les fenêtres **alignées d'un étage à l'autre**, la rangée du haut s'arrêtant sous la gouttière | une rangée **coupée en deux** par l'égout, ou qui déborde sur le toit |
| deux maisons mitoyennes avec **deux rythmes de travées** | une trame unique qui traverse les façades sans voir les angles |
| un **pignon plein** entre deux maisons de la même rangée | des fenêtres sur un mur qui touche le voisin |
| **une** porte par maison, au rez, sur la rue | deux portes sur un bâtiment d'angle, ou une porte sur la cour |
| la barre de 1974 en **bandes horizontales** (`wehrau_essai_barre.png`) | un damier de petits carrés |
| en dézoomant, les fenêtres **s'effacent** en un mur plus sombre | un grésillement qui court sur les façades quand la caméra tourne |

Et vérifie les images: `F3` dans la vraie fenêtre donne la cadence — le
matériau a grossi, la géométrie non.

🌊 **Puis LA BERGE**, qui a bougé hier — `wehrau_essai_berge.png` (touche `G`,
vue basse à 18°, parce qu'une pente se juge de profil) :

| Ce qu'il faut voir | Ce qui prouverait que c'est cassé |
|---|---|
| le champ jaune pâle rayé, puis une **bande verte qui descend**, puis l'eau | une bande verte **plate**, posée comme un tapis |
| le **trait d'eau qui tombe dans la pente**, pas sur son bord | une lèvre de terre qui affleure l'eau sur tout le linéaire |
| au raccord ville/champ, le talus **remonte sur 10 m** et le mur de quai sort du sol | une **marche verticale** de 2 m en travers de la rive |
| les arbres de rive **plantés dans la pente** | un arbre en lévitation au-dessus du talus |
| vue de dessus, l'Ilse traverse les champs **bordée d'un liseré vert** | des **dents grises** le long de la rive — la plaque de sol qui ressort |

Et en ville, sur `wehrau_essai_ilse.png` : le mur de quai fait maintenant **deux
mètres au-dessus de l'eau** au lieu d'un. S'il manque quelque part le long d'un
quai, c'est le défaut n° 11 de [CHANTIERS.md](CHANTIERS.md) — l'axe de la rue
qui mord le chenal — et il est deux fois plus visible qu'hier.

🔴 **Puis LA RUE**, qui n'a pas bougé aujourd'hui mais qui est le gros de
l'étape. Sur `wehrau_essai_ilse.png` et `wehrau_essai_dessus.png` :

| Ce qu'il faut voir | Ce qui prouverait que c'est cassé |
|---|---|
| une **bande claire continue** le long de chaque pâté, qui **tourne les coins de rue** | une bande qui s'arrête à chaque carrefour, ou qui passe sur les maisons |
| la **marche** entre le trottoir et le sol : une ligne d'ombre, pas un changement de teinte | un trottoir posé à plat, ou un trottoir qui flotte |
| les rues qui **tournent en courbe** — bien visible sur la ceinture, vue de dessus | une courbe qui déborde sur un trottoir, ou un trottoir qui se retourne dans un virage |
| les **carrefours nets**, en angle | un carrefour arrondi en flaque |
| l'**asphalte plus clair qu'avant** : il reçoit enfin le soleil | — |

🔴 **Puis LA PAIRE** — même vue, même instant :

| L'image | Ce qu'elle montre |
|---|---|
| `QGIS/rendus/wehrau_essai_materiaux.png` | la ville **en matériaux** : une masse de toits rouges sur des murs clairs |
| `QGIS/rendus/wehrau_essai_tissu.png` | **la même image, touche `C`** : la palette par tissu, celle d'avant |

**Si la première est belle et que la seconde reste lisible, l'échange est bon.
Si la seconde te manque tout le temps, la lecture par époque ne suffit pas et
il faut rediscuter** — c'est le seul vrai risque de cette passe.

**Puis de près**, `wehrau_essai_ilse.png` : aucun tronc ne doit sortir de la
surface bleue de l'Ilse. Le débord de toit doit se voir comme un liseré sombre
autour de chaque maison, les souches comme de petits points bruns sur les
faîtages, les trottoirs comme deux bandes claires de part et d'autre de
l'asphalte, et deux maisons mitoyennes ne doivent plus avoir la même façade.

**Et de haut**, `wehrau_essai_dessus.png` : les halles et les barres en gris
sombre au sud, les champs rayés autour.

✏️ **Et le trait de sélection** : `wehrau_essai_barre.png` (l'îlot 32, de
près — le trait fait le tour du **gris autour des barres** et **monte sur les
toits** là où ils dépassent de l'emprise ; aucun trou, une seule ligne fermée),
`wehrau_essai_eglise.png` et `wehrau_essai_caisse.png` (à l'échelle de la
ville : même épaisseur, et c'est le seul élément qui ressort de l'image). Ce
qui prouverait que c'est cassé : un trait qui ne se referme pas, qui reste au
sol pendant que les bâtiments en sortent, qui laisse le sol de l'îlot **dehors**,
ou qui change d'épaisseur au zoom.

### 🎚️ Ce qui se règle en une ligne, si l'image ne va pas

| Si tu trouves que… | La ligne à changer |
|---|---|
| il y a trop de toits sombres | la liste `TOITURES["tuile"]` de `palette.py` — elle est **pondérée par répétition** |
| les murs sont trop gris à l'ombre | `AMBIANT` dans `palette.py`, et l'énergie du soleil dans `maquette.gd` |
| le débord est trop discret ou trop gros | `DEBORD_TOIT` dans `07_exporter_godot.py` |
| les cheminées se voient trop | `PART_CHEMINEES`, ou `CHEMINEE` dans `palette.py` |
| les trottoirs mangent la rue | `LARGEUR_TROTTOIR` dans `07_exporter_godot.py` |
| la bordure est trop haute ou trop basse | `HAUTEUR_BORDURE` dans `07_exporter_godot.py` |
| le trottoir est trop clair ou trop sombre | `TROTTOIR` dans `palette.py` |
| les rues serpentent, ou pas assez | `RAYON_MAX` et `COUDE_MIN_DEG` dans `07_exporter_godot.py` |
| les virages élargissent trop le trottoir | `ELARGISSEMENT_MAX` — c'est lui qui décide combien de coudes s'arrondissent |
| le talus est trop raide, ou trop mou | `TALUS_LARGEUR` dans `07_exporter_godot.py` — 10 m aujourd'hui, donc 22 % |
| l'eau n'est pas assez basse | `NAPPE_ILSE`, et `TALUS_BAS` juste en dessous (le sol doit rester sous la nappe) |
| la berge est trop verte, ou pas assez | le mélange vers `SOLS["parc"]` dans la branche `champ` de `07_exporter_godot.py` |

### 👁️ Puis regarder le geste énergie, son temps et son prix

Ouvrir la maquette, cliquer un îlot bâti et déplacer le curseur à droite.
Regarder d'abord le temps : la durée est annoncée avant « Augmenter » — **1 mois
pour 0 → 100 %**, en jours pour une hausse plus petite ; la barre et le toit
avancent ensemble vers la cible ; les totaux de gauche suivent ; pause, ×1, ×4
et ×12 changent le rythme sans changer la durée en mois.

Puis l'argent. **Cliquer un cœur ancien, puis la barre de 1974** et comparer la
ligne « Se rembourse en » : **31 ans contre 10**. Sur l'**îlot 31** — la friche,
869 k€ — la ligne sous le curseur passe au rouge, dit *« il manque 69 k€ »*, et
le bouton refuse. C'est le seul non que le prototype sache prononcer.

Les captures de référence sont
`wehrau_essai_barre.png` (0 %), `wehrau_essai_caisse.png` (**le refus**),
`wehrau_essai_solaire_pose.png` (50 %) et `wehrau_essai_solaire_100.png`.

### ⏸️ Ce qui attend dans l'étape 2, mise en pause

Le bout sud-est de l'**îlot 40** garde une parcelle en flèche (435), une
lanière (443) et deux replis (438) : **118 parcelles de rue sur 809** ont un
sommet rentrant, et c'est **le peigne de `04c`**, pas la soudure des coins ni
le bâtiment. La piste à essayer et la mesure faite sont dans
[CHANTIERS.md](CHANTIERS.md) §1 n°8. **Ne pas rouvrir l'étape 2 tant que la 4
est ouverte.**

## Ce qui attend l'auteur

- [ ] 🔴 **Le potentiel solaire réel est bien inférieur aux 25–40 % du plan.** La suspension est levée : la mesure unique est maintenant **11,0 ha de toiture réelle pente comprise** sur les 756 volumes de `04d`. Le jeu tient (blocages, rentabilités par îlot, « pas d'autonomie par les toits » renforcé). **À trancher maintenant : assumer ce potentiel bas, ou regonfler la colonne `equip` de la table.**
- [x] ✅ ~~**Qui possède les panneaux ?**~~ **Tout appartient à la ville**,
  logement compris (70). À rouvrir **avant Vallmar**, pas avant : le
  propriétaire qui dit non est une tension que le jeu complet devra porter —
  une transformation urbaine où personne ne peut refuser n'est pas une
  transformation, c'est un plan.
- [ ] 🟠 **Les quatre nombres de l'économie sont du level design, pas de la
  physique** : 260 €/m², 150 €/MWh, 800 k€ de caisse, 30 k€/mois de dotation.
  Ce sont eux qui décident si le jeu est « dur mais possible ». Le tableau
  mesuré pour les juger est imprimé par `-- --essai` et recopié dans
  [Prototype/Énergie.md](Prototype/Énergie.md) §4.
- [ ] 🔴 **La direction artistique du vault dit encore « un `sous_type` = une
  teinte, rien à peindre jamais »** — et c'est faux depuis aujourd'hui. Quatre
  arbitrages ont été pris en ouvrant l'étape 4 et **aucun n'est consigné** :
  ① la couleur suit l'époque et la position, pas la typologie ; ② le calque
  « tissu » est la contrepartie ; ③ zéro asset, tout reste une recette ;
  ④ l'étape 4 s'ouvre et l'étape 2 passe en pause. À fermer dans
  `Questions ouvertes.md` **et** `Décisions arrêtées.md` — pas au détour d'une
  note de chantier.
- [ ] 🟠 **Le nom des quartiers de Wehrau** — sans lui, « investir dans le Ried avant la rive gauche » n'existe pas comme phrase. Les calques sortent bien des **zones**, pas des confettis : la phrase attend son vocabulaire.
- [x] ✅ ~~**L'exagération verticale**~~ — **close par la mise à plat** le 2026-08-12. Il n'y a plus de relief à exagérer ; les touches `1..4` sont retirées de la maquette.
- [ ] 🟠 **La crue dans le vault** — la décision **23b** (le jeu s'ouvre sur une crue rive gauche) est en contradiction avec « pas de crue pour ce prototype ». Suspendue ou abandonnée ? À écrire dans `Décisions arrêtées`, pas à laisser implicite.
- [ ] **Les quatre tables de level design** → [CHANTIERS.md](CHANTIERS.md) §2. Une ligne changée, on relance, on regarde.
- [ ] ⏸️ **La décision spatiale comme dilemme** — l'ancien prototype la
  testait par la rentabilité et l'isolation ; le prototype actuel ne la teste
  volontairement plus.

🖥️ **Trois questions se tranchent en dessinant l'écran, pas dans le vault** : **n°19** onze nombres permanents, est-ce que ça tient ? · **n°20** `Déclin et défaite` refuse la jauge globale que « la ville exposée » vient d'introduire · **n°21** comment le joueur comprend que l'économie commande son budget, alors que les deux sont loin l'un de l'autre à l'écran. → `Méta/Questions ouvertes.md`

⏸️ **La durée d'une partie est mise de côté volontairement** : pas de fin imposée, on joue jusqu'à l'ennui puis on recommence dans une autre direction. Hypothèse non fixée : ~20 ans en ~2 h. → `Décisions arrêtées` 14b · 14c

## Les commandes du quotidien

```
python "QGIS/scripts/chaine.py"                        → LA commande : refaire la carte ET les bâtiments, 3,2 s
python "QGIS/scripts/chaine.py" --godot                → … et alimenter la maquette 3D
python "QGIS/scripts/apercu_parcelles.py"              → le parcellaire en PNG, numéroté
python "QGIS/scripts/apercu_carte.py"                  → la carte en PNG
python "QGIS/scripts/06_etat_zero.py"                  → la ville entière en HTML, 20 calques
python "QGIS/scripts/08_jouer.py" --toutes             → rejouer les parties du classeur
python "QGIS/scripts/tracer_chemins.py" --blanc        → proposer les venelles, sans rien écrire
```

✅ **L'ordre de la chaîne est tenu par `chaine.py`**, plus par la mémoire : il lance 02 → 03 → 04 → 04b → 04c → **04d** et **s'arrête net** à la première étape qui échoue. La passe `--blanc` n'y sert plus — la carte de travail est dérivée et jetable. Elle reste obligatoire pour les **trois scripts qui écrivent la source** (`00`, `00b`, `tracer_chemins`) : eux touchent du level design.

Le détail des scripts, leurs modes et leurs pièges → **`QGIS/README.md`** (§4 et §9). L'organisation des données → **`QGIS/data/LISEZ-MOI.md`**. La maquette et ses touches (`V` `B` `R` `I` `G` `P`) → **`Godot/README.md`**.

**Deux machines** : Windows principal, Mac occasionnel, **et depuis le 2026-08-17 elles font le même travail**. `git pull` en début de session, `git push` en fin. La carte est du texte que git fusionne ; aucun `.gpkg` n'est suivi. → `CLAUDE.md` §5

## Les deux dernières sessions

**2026-08-19 (session 48) — la place du marché montre ses places.** Une phrase
de l'auteur : *« dessine des places de parc sur la place centrale. regarde
comment faire de manière procédurale. »* Le point de départ n'était pas une
page blanche : `04` compte **127 places** sur l'îlot 19 depuis toujours — sa
surface × la part de parking de son tissu ÷ 25 m² — et ce nombre n'avait jamais
touché l'image. La question n'était donc pas « comment dessiner un parking »
mais **« est-ce que la géométrie sait retomber sur le chiffre du tableur ? »**.
🔴 Cinq règles, et aucune ne nomme un îlot ni un sous-type : le déclencheur est
*un îlot de SOL qui porte des places*, et il n'y en a qu'un — la barre et
l'équipement en portent aussi, mais ils ont une hauteur et sont partis dans une
autre branche bien avant. La **direction** est celle de la plus longue arête de
l'emprise ; comme une emprise est l'îlot moins la voirie, ses arêtes sont des
façades sur rue, et la plus longue est la façade principale. ⚠️ **Elle n'est
PAS choisie sur le compte**, et c'est mesuré : les neuf directions possibles ne
s'écartent que de **119 à 129 places**, donc le compte les départagerait sur du
bruit. Le **module** est de la voirie ordinaire — allée de 6 m, deux rangées de
5 m dos à dos, 16 m répétés — la trame **glisse** en 80 positions et on garde
celle qui range le plus, une place tient si ses **quatre coins** sont dans
l'emprise retirée de 3 m, et il lui faut **3 m d'allée devant elle**. Résultat :
**123 places contre 127 annoncées, −3 %**, deux chaînes qui ne s'étaient jamais
parlé et qui tombent l'une sur l'autre — c'est le seul contrôle du projet qui
ne soit pas vrai par construction. Trois pièges payés : le **dos des deux
rangées** est un seul trait (deux peintures coplanaires clignotent sur toute la
longueur de la place), la peinture est 1 cm au-dessus du **sol** et non de la
chaussée (le marquage de rue vit à −0,01 m, la place est un cap à +0,05 : il
serait passé **6 cm dessous**, invisible, et rien ne l'aurait dit), et le semis
d'arbres a reçu **un rejet de plus** — sans lui, un arbre sur deux de la place
poussait au milieu d'une place peinte. Le retrait de 3 m n'est pas une marge de
dessin : à 0,5 m la trame monte à 153 places et bute sur le trottoir, à 6 m elle
tombe à 96. **156 triangles**, nouvelle vue `M`, capture
`wehrau_essai_place.png`, chaîne complète et essai Godot au vert. Reste le
stationnement **de rue** : 3 310 places, toujours invisibles.

**2026-08-19 (session 46) — les routes ne volent plus sur l'eau.** Trois
phrases de l'auteur : un mur entre l'eau et la route, un parapet d'un mètre, et
les routes qui passent sur l'eau transformées en ponts. Ce qui volait a été
mesuré avant de coder — **7 212 m² d'asphalte au-dessus du chenal, 42
tronçons** — et surtout séparé en deux causes, parce qu'elles ne se réparent pas
pareil : la voie de berge est **tracée sur la ligne d'eau** et déborde de 3,25 m
(une voie `rive`) à 7,00 m (le boulevard de quai) sans rien traverser ; trois
tronçons, eux, **traversent** vraiment sur 35 à 40 m. 🔴 La règle qui les sépare
ne nomme aucune rue : station par station le long de la chaussée, l'eau sous
**un** bord veut dire qu'on longe, sous **les deux** sur au moins 8 m qu'on
traverse. Le seuil de 8 m n'est pas décoratif — sans lui, les ~35 amorces de rue
qui débouchent sur un quai (la demi-largeur d'asphalte que chaque chaussée
ajoute pour remplir son carrefour) devenaient chacune un petit pont de 4 m.
**Une seule ligne de mur suit la route**, et sa distance à l'axe est le plus
dehors des deux : la berge, ou le bord de l'asphalte plus sa bande. Un seul
`max`, et il fait les deux cas ; ce qui change, c'est jusqu'où le mur descend —
au fond du chenal pour un quai, à la sous-face du tablier pour un pont. Le
parapet est le même muret des deux côtés, avec un chaperon plus clair : vu d'en
haut, c'est lui qui dit qu'il y a une barrière. Mesuré : **3 ponts**, 119 m de
tablier, **3 piles**, **1,51 km de quai porté**, **1,74 km de parapet**, 9 338
triangles. 🔴 Le gros défaut trouvé en chemin : le boulevard de quai a son
**axe posé sur la ligne d'eau**, donc la berge est à distance **nulle des deux
côtés**, et la mesure seule concluait « bord de l'eau » du côté des façades
aussi — un mur de 2,65 m debout au milieu de la ville. Une distance ne dit pas
de quel côté est la rivière ; la question qui manquait (*y a-t-il de l'eau 30 cm
au-delà du bord trouvé ?*) a supprimé **la moitié du mur**, 2,98 → 1,51 km. Le
contrôle imprimé range désormais tout l'asphalte au-dessus du chenal en trois
familles — **porté 98,7 %**, 87 m² masqués derrière un parapet, **5 m² au-delà**
(six coins de carrefour d'un mètre carré au plus) : c'est ce qui permet de dire
« ✅ » sans mentir. Conséquence assumée et chiffrée : les quais prennent **6 m**
à l'Ilse, 38 m de large en médiane contre 32 après. Nouvelle vue `O`, deux
captures neuves, chaîne complète et essai Godot au vert.

→ **[HISTORIQUE.md](HISTORIQUE.md)** pour les sessions précédentes.
