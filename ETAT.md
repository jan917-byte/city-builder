# ETAT.md — où on en est

> Mis à jour par Claude en fin de session. Complément de [CLAUDE.md](CLAUDE.md).
> **Ce fichier est un signet, pas une source.** Design = le vault. Carte = `QGIS/data/source/*.geojson`.

| Si tu cherches | Va voir |
|---|---|
| **le prototype, ses étapes, celle qui est ouverte** | [Prototype/00 - Prototype.md](Prototype/00%20-%20Prototype.md) |
| ce qui attend, les défauts connus, les tables à régler | [CHANTIERS.md](CHANTIERS.md) |
| ce qui s'est passé, et pourquoi c'est comme ça | [HISTORIQUE.md](HISTORIQUE.md) |
| ce qui est tranché | `Méta/Décisions arrêtées.md` (vault) |

**Dernière mise à jour : 2026-08-18 (session 45)**

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
**82 en vitrine** sur le front commerçant et **36 en bandeau filant** sur la
barre de 1974. Les travées sont **centrées sur chaque façade** et leur entraxe
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
| **Le rendu réaliste** — toit ≠ mur, matériau par époque, teinte par bâtiment, débord de toit, cheminées, **trottoirs à bordure qui tournent les coins**, **rues courbes**, **marquage au sol procédural** (axe, rives, 260 passages piétons), champs rayés, arbres à tronc — et la touche `C` qui rend la lecture par tissu | 🎯 **étape ouverte** → [Prototype/Toits et sol.md](Prototype/Toits%20et%20sol.md) |
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

🪟 **Regarde d'abord LES FAÇADES**, c'est ce qui a bougé aujourd'hui — et
elles ont leur propre vue, `wehrau_essai_facades.png` (cadrage de 150 m, 14°
au-dessus, la hauteur d'un piéton au bout de la rue) :

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
près — le trait monte sur les deux barres au lieu de rester au sol),
`wehrau_essai_eglise.png` et `wehrau_essai_caisse.png` (à l'échelle de la
ville : même épaisseur, et c'est le seul élément qui ressort de l'image). Ce
qui prouverait que c'est cassé : un trait qui ne se referme pas, qui reste au
sol pendant que les bâtiments en sortent, ou qui change d'épaisseur au zoom.

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

**2026-08-18 (session 44) — les murs se percent.** Une phrase de l'auteur :
*« fais aussi la génération procédurale des fenêtres »*. La note d'étape les
avait écartées le matin même, avec une raison qui s'est révélée être la clé du
problème plutôt qu'un obstacle : *« il faudrait que le shader connaisse la
hauteur d'étage »*. Il la connaît maintenant — elle lui est **passée depuis les
données**, et pas recopiée dans son code, parce que c'est le seul nombre qu'il
partage avec la géométrie. Ce que ça achète : les murs montent à un multiple
exact de la hauteur d'étage, donc les rangées de fenêtres tombent sur les
planchers réels et **aucune n'est coupée par l'égout**, sans que le matériau ait
jamais à connaître la hauteur d'un bâtiment. 🔴 Le partage est le même que pour
les panneaux : l'export sait ce qu'est une rue, un mur mitoyen, un front
commerçant, et il n'en envoie qu'un **genre de percement** par mur, plus la
longueur de ce mur ; le matériau dessine et ne décide rien. Cette longueur n'est
pas un détail — sans elle les travées se poseraient sur une grille mondiale et
laisseraient des demi-fenêtres dans les angles, la faute exacte que la grille de
panneaux avait coûté à corriger la veille. Mesuré : **2 552 murs percés sur
3 547** (23,99 km), dont **995 aveugles**, **697 portes** — une par bâtiment,
sur sa plus longue façade sur rue —, **82 vitrines** et **36 bandeaux**. 🔴
Deux pièges payés le jour même : ① le test « la rue est-elle devant ce mur ? »
mesurait si un pas vers le dehors *rapprochait* de la rue, ce qui est faux dès
qu'un bâtiment est bâti à l'alignement — la distance vaut alors zéro, tout pas
l'augmente, et la façade la plus commerçante de la ville sortait « arrière » :
**2 vitrines pour 49 volumes**. On regarde maintenant le signe et non la
variation, et il y en a 82. ② à 1,75 m d'entraxe, la barre de 1974 sortait
criblée de petits carrés — une carte perforée, pas un bandeau ; ce qui fait la
bande, c'est que l'ouverture soit deux fois plus large que haute. De loin, le
percement s'efface en un mur un peu plus sombre au lieu de grésiller — même
geste que les rangs de tuile, et ce qui tombe avec lui, c'est le prix assumé de
la caméra ouverte du 2026-08-17 : *« sous 15°, on regarde la ville par ses
façades, qui sont des murs nus »*. Nouvelle capture `wehrau_essai_facades.png`,
sans quoi rien de tout ça ne se voit. **0 triangle ajouté, 0,2 s d'export** ;
chaîne complète, contrôle énergie et essai Godot au vert.

**2026-08-18 (session 43) — l'Ilse descend de 2 m, et les champs avec elle.**
Demandé avec une coupe dessinée : la rivière 2 m sous la ville, la ville plate,
et une topographie simple pour les champs qui la bordent. 🔴 Ce qui change
vraiment n'est pas la profondeur, c'est qu'il y a maintenant **deux bords
d'eau** — et c'est la même ligne de code qui fait les deux : le mur de quai
monte jusqu'à la **surface du sol**, quelle qu'elle soit. Là où la ville tient
la rive, le sol est à 0 et le mur fait 2,6 m ; là où c'est un champ, le sol est
déjà au ras de l'eau et il n'en reste qu'une lèvre noyée. Le relief tient dans
**une seule fonction**, que la plaque, le champ, ses bandes de fauche, ses
arbres, ses alignements et le haut du mur interrogent tous — elles partagent la
même vérité au lieu d'en recopier une, donc aucune ne peut se fendre sur une
autre. La moitié difficile de cette fonction n'est pas la pente mais le
**fondu** : le relief se relève à 0 dès qu'on approche d'un autre bord du champ,
ce qui supprime trois cas particuliers d'un coup — la marche au raccord
ville/champ devient une remontée sur 10 m, un pont qui traverse un champ garde
sa terre à 0 sans qu'une ligne parle de pont, et rien ne déborde de l'emprise,
donc ni la voirie ni les trottoirs n'ont à savoir que le relief existe. Mesuré :
**4 champs riverains, 984 m de rive en pente à 22 %** sur 2 475 m de berge,
**2 019 mailles**, sol à **−2,15 m** (15 cm sous la nappe), plaque de sol à
−2,85 m dessous. 🔴 Un piège payé le jour même et visible à l'écran : un point
posé **sur** la ligne de berge n'est ni dedans ni dehors pour un test
d'appartenance, et il ressortait à 0 pendant que ses voisins descendaient — la
berge se hérissait de **dents grises d'un mètre**, une par sommet. La pente
douce avait déjà été essayée et rejetée le 2026-08-12 (« se lisait comme un
talus, donc comme rien ») : ce qui change, c'est que le creux double et surtout
que la pente ne remplace plus le mur partout — c'est le contraste qui les fait
lire tous les deux. Nouvelle vue `G` et nouvelle capture
`wehrau_essai_berge.png`, parce que les quatre autres repères sont tous posés
sur la ville, où le sol est plat : sans elle le relief ne se voit nulle part,
donc il n'existe pas. Chaîne complète et essai Godot au vert, **73 359
triangles**, toutes les captures régénérées.


→ **[HISTORIQUE.md](HISTORIQUE.md)** pour les sessions précédentes.
