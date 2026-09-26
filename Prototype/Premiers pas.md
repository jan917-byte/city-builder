# Premiers pas après la crue

> Étape 6 ouverte le 2026-09-06 à la demande de l'auteur. L'étape 5 reste en pause, à juger.
> Design : `Vault - Jeu urbanisme/Systèmes/Premiers pas après la crue.md`. Les lieux proposés restent à essayer par l'auteur.

## À jouer
**Retour du 18 septembre :** compteur permanent en bas à droite, carte sans pictogrammes ni numéros, pont reconnu seulement après rétablissement des accès routiers. Coût agricole dès l'engagement ; livraisons et conséquences dans les notifications et le journal sauvegardé. Design → décision 85 et `Vault - Jeu urbanisme/Systèmes/Premiers pas après la crue.md`. Montage progressif et verrou à zéro restent proposés.

Au lancement, un écran demande le mode : **histoire** ou **auteur**. Le mode auteur livre tout chantier engagé au clic — les prix, la caisse et la dotation ne changent pas. Les drapeaux `-- --histoire` et `-- --auteur` sautent l'écran pour les contrôles, et le récit avec.

Le mode choisi, le récit passe quatre pages à la flèche. Puis départ à ×1 sur le relogement, faubourg et champs dans la même image. Tout le monde abrité : vue Trafic → examiner librement les ponts → engager dans la fiche → rétablir les accès. DÉBUT rouvre l'accompagnement ; le guide des ponts remplace la légende pendant cette découverte.

| Repère de l'essai | Ce qui est mesuré |
|---|---|
| Sinistrés à reloger | 260 logements perdus, 7 îlots, faubourg de rive gauche |
| ① champ des Luzernes, 1082 | 119 logements · 238 personnes · 179 k€ au maximum |
| ② champ des Bleuets, 1083 | 77 logements · 154 personnes · 116 k€ au maximum |
| ③ champ de l’Orge, 1084 | 65 logements · 130 personnes · 98 k€ au maximum |
| ① Rue des Forgerons, tronçon 148 | 14,3 k€, 1 mois |
| ② Maisons des Forgerons, îlot 59 | 734,4 k€, 12 mois ; 43 logements sinistrés, 24 restés habitables |
| Protection, berge 3 | 1 019 k€, 18 mois ; bief des maisons des Forgerons |

## Le relogement — 2026-09-17
**Aucune liste de fid** : `07` écrit le morceau de réseau de chaque îlot une fois les trois ponts retirés, et un champ n'est proposé que s'il partage celui du faubourg. Redessiner un pont ou une desserte déplace la scène sans toucher au code. Un champ sans bord commun avec une rue hérite du morceau de la route la plus proche sous 30 m.

**Deux champs quelconques suffisent, aucun seul** (auteur, 2026-09-18) : deux places par container. Après le plus grand camp, 22 personnes restent dehors ; le suivant ne commande que 11 logements. Au total, 130 containers coûtent 195 k€. Empreintes, allées et berges restent identiques ; l'interface sépare logements et personnes. `essai_relogement.gd` vérifie les six ordres, la reprise et un besoin impair ; zéro échec, comme l'ouverture rendue. Les neuf contrôles géométriques Python passent.

**Un champ de l'autre rive se pose quand même** (arbitrage de l'auteur) : la fiche prévient, le bouton reste actif, le camp se monte, personne n'y va. La livraison d'un pont le remplit désormais : `07` exporte les morceaux de réseau réunis par chaque pont, et les occupants suivent leur accès au mois courant.

## Trafic et premier pont — 2026-09-18
Le diagnostic ne s'ouvre qu'une fois **tout le monde abrité** (voir « Premier retour de jeu »). Chaque fiche calcule le coût du pont et des accès, le délai minimal et la rue qui reçoit le plus de trafic supplémentaire, sans dépense ni choix imposé. Une réparation engagée directement est reconnue. Le pont 169 entièrement emporté retrouve sélection et miniature.
**Deux chantiers par pont** (décision 87, 2026-09-24) : **en dur**, 145 **2 825 k€**, 168 **2 860 k€**, 169 **1 498 k€**, **8 mois** ; ou **provisoire**, 25 % du prix (706 · 715 · 375 k€), **3 mois**, une voie en alternat qui sature deux fois plus vite (169 : 61 % → 100 %). **Il ne ressemble pas au pont en dur** (auteur, 2026-09-24) : une seule voie de 5,6 m entre deux poutres en treillis vert type Bailey (2,4 m de haut), plancher de madriers, portiques d'entrée rouges et blancs, palées d'acier ; le pont en dur garde sa dalle, ses trottoirs et son garde-corps. Maillage à part (`ponts_provisoires`), montré à la place du tablier neuf, en ville comme dans la miniature. 🔴 Les piétons marchent encore sur la ligne des trottoirs du pont en dur, donc au-dessus de l'eau à côté du treillis. 🔴 Ces trois réglages du provisoire sont à juger. Pendant le chantier, la fenêtre propose les rues d'accès à déblayer. Le tablier livré peut rester inaccessible aux voitures ; le guide attend un chemin continu de chaque côté vers un carrefour praticable. La marche garde sa règle propre. Voir les accès souligne temporairement les rues ouvertes et celles à déblayer. **La liste de gauche ne nomme que les trois ponts, sans prix** (auteur, 2026-09-26) : on ouvre chaque pont pour lire et comparer ses deux prix dans sa fiche. **Sur le calque Trafic, un pont emporté se montre coupé** — ses deux moignons en violet, un pictogramme rouge de pont cassé au-dessus du trou — et non plus avec le tablier rebâti peint en violet ; le pictogramme part à la livraison. **Le bas de chaque fiche dit les conséquences en pictogrammes, sans phrase** (auteur, 2026-09-26) : prix, durée, puis ce que la ville gagne ou perd une fois le chantier livré (logements, abrités, pont, crue, énergie, CO₂, nourris, arbres), mesuré sur une ville d'essai jamais montrée ; vert si c'est un gain, rouge si c'est une perte ; ↺ remet tout, « Mettre en place » lance. Provisoire du pont d'Aval : 375 k€ · 3 mois · +1 pont ; camp des Luzernes : 179 k€ · 6 jours · +238 abrités · −8 nourris. **Guide et fiches tiennent en une phrase par bloc** (auteur, 2026-09-26) : ce que les conséquences disent déjà (nourris, crue d'une berge) quitte le texte ; restent les avertissements irréversibles.
Contrôles : ouverture rendue, sauvegarde/reprise, trafic et travaux ; export relogement **10 cas**. Captures `wehrau_ouverture_09_decouvrir_trafic.png` → `..._14_pont_rouvert.png`, dont `..._12a_pont_travaux_acces.png` (l'accès à déblayer pendant le chantier), `..._13b_provisoire_sature.png`, puis la paire au même cadrage `..._13c_provisoire_treillis.png` → `..._13d_pont_en_dur_meme_cadrage.png`. Défauts : camp rempli ou traversée ouverte avant livraison, pictogramme ailleurs qu'au-dessus d'un pont coupé du calque Trafic, tablier entier sur un pont pas encore livré, comparaison payante, choix ou cadrage perdus après reprise.

## Budget des premières réparations — 2026-09-20
La caisse finance le relogement complet, un pont au choix et toutes les routes à déblayer dès le début (décision 86). Mesure : **195 + 2 859,5 + 201,5 = 3 256 k€**, soit **244 k€ restants** avec le pont le plus cher ; 22 routes. Aucun mois de dotation ni argent d'essai nécessaire. Le choix d'un pont moins cher laisse davantage pour la suite.
Contrôle : `essai_relogement.gd` engage les camps, chacun des trois ponts séparément et toutes les routes ; `essai_ouverture.gd` et `essai_progression.gd` jouent désormais les ponts sans crédit d'essai. Les trois contrôles passent à zéro échec. Les captures de cette passe présentent des panneaux sans texte : validation visuelle à refaire. À regarder après Recommencer : **3 500 k€**, puis un bouton de réparation actif après les camps. Un pont ou un déblaiement refusé faute d'argent sur ce parcours serait un défaut.

## Les abris, la miniature et les pictogrammes — 2026-09-18
**Un abri par logement payé**, au lieu de deux caisses écartées de 1,55 m alors qu'elles font 2,9 m de large : elles s'interpénétraient, et un camp de cinq logements montrait dix boîtes emmêlées. Ce qui est à l'écran est désormais le nombre que la fiche annonce — cinq personnes tiennent sur un coin de champ, 130 couvrent le champ 1082.

**Le container habitable remplace le petit toit à deux pentes** (demande de l’auteur, 2026-09-18) : toit plat, ossature métallique, plots, tôle nervurée, vitrages encadrés, porte, seuil et casquette. Un modèle de 240 triangles instancié ; nervures et ouvertures sont dessinées par la matière. Quatre teintes proches, une par rangée. L’orientation suit maintenant réellement les rangées semées : son signe était inversé entre la carte et Godot.

**Le camp entre dans la miniature de la fiche.** C'était le seul chantier qu'on engageait sans l'avoir vu : le bouton AVANT montre le champ nu, APRÈS le champ couvert, et le survol du bouton suffit. Même MultiMesh et mêmes places que la ville, donc l'image ne peut pas promettre autre chose que ce qui sera posé.

## Le récit d'ouverture — 2026-09-18
Quatre pages et une flèche, **en bas au centre pour ne pas couvrir ce qu'elles montrent** : Wehrau, la crue, ce qu'elle a laissé, le premier soir. Chaque page cadre son sujet, la carte reste sans pictogramme, et les chiffres sortent de `ville.degats`. « Passer » saute à la fin.

**Les trois champs ne sont plus désignés** (demande de l'auteur) : ni chiffre sur la carte, ni bouton dans le panneau. Le panneau demande un endroit atteignable à pied, la fiche répond — seul un champ ouvre le bloc de relogement, et un champ de l'autre rive prévient sans refuser. Après trois lieux ouverts sans en trouver un, le panneau rappelle qu'un camp demande un terrain nu (`INDICE_REGARDS`, haut de `ouverture.gd`).

**Et rien d'autre ne s'engage tant que personne n'est relogé** : réparation, trafic, panneaux, toits, arbres, berge et les deux portes quittent la fiche, et un lieu qui ne peut rien accueillir le dit en une ligne. C'est ce qui oriente vers les champs sans les montrer.

## Le temps part à la fin des cartes — 2026-09-18

Pendant les quatre pages, **il n'y a pas de jeu à l'écran** : ni compteurs, ni rail, ni commandes du temps, ni fiche — donc rien qui propose de poser des panneaux avant d'avoir su ce qui s'est passé. L'écran de choix du mode est rangé de la même façon.

La dernière page rend le tableau de bord **et lance le temps à ×1** : un mois dure une minute, la caisse monte de 30 k€ pendant que 260 personnes dorment dehors. La première décision devient une urgence au lieu d'un menu ; la pause reste à un clic.

## Ce que les champs nourrissent — 2026-09-18

Un camp pose des logements sur un champ : voilà ce que ça coûte. La **surface est mesurée** (68,1 ha sur 88 champs), la conversion est du level design — `NOURRITURE_PERSONNES_HA`, haut de `ville.gd`.

| | |
|---|---|
| Rendement posé | 12 personnes nourries par hectare et par an |
| Toute la campagne | **817 personnes**, soit **15 %** des 5 350 habitants |
| Champ 1082 (0,69 ha) | 8 personnes nourries · capacité du camp dans la table en tête |
| Champ 1083 (0,54 ha) | 7 personnes nourries |
| Champ 1084 (0,46 ha) | 6 personnes nourries |

**Le camp prend le champ entier, et pour de bon** : la perte suit l'engagement du chantier, et rien ne la rend. Trois endroits le disent — la ligne « Nourrit » de la fiche, la phrase au-dessus du bouton, et le récapitulatif qui porte les deux prix (k€ sur le bouton, personnes ici). Le compteur **Campagne** du tableau de bord ne remonte jamais.

🔴 **Le rendement est à juger, et c'est lui qui décide si le coût se voit.** À 3 pers./ha — la moyenne française toutes productions confondues — la campagne ne couvrirait que 4 % de la ville et le camp ne coûterait rien de lisible. À 12, le plus grand champ vaut 9 personnes nourries contre 130 logées : le coût reste petit devant l'urgence, et c'est l'**irréversibilité** qui porte la leçon, pas le montant.

## Progression et retours — 2026-09-18
Le compteur reste visible avec le guide réduit ou une fiche ouverte. Les places en construction sont séparées ; seuls les abris livrés et accessibles diminuent le besoin. Les chantiers gardent leurs palissades et grues physiques, sans pastille flottante.
Notifications sobres (huit secondes, deux messages au maximum) ; le journal conserve les cent derniers constats et suit la sauvegarde. Une reprise ne rejoue pas une livraison passée. Camps, réparations, toits, étages, plantations, stationnement, recherche et subventions partagent ces retours.
Accès proposés sur la carte actuelle : amont 145 → rues 147/148 ; centre 168 → 167 ; aval 169 → 172. Tout autre parcours continu convient. Le réseau recolle le bout du pont aval arrêté à 4,25 m du carrefour rendu, dans sa demi-largeur ; aucun tracé source modifié.
`essai_progression.gd -- --ouverture --captures` : compteur, coûts, trois ponts livrés sans accès puis reconnectés, prévisions, voitures, journal et reprise ; zéro échec en rendu. `essai_ouverture`, `essai_trafic` et `essai_relogement` passent également. Images : `wehrau_ouverture_progression_01_engagement.png` → `..._06_journal.png`.
Défaut à signaler : compteur caché par la fiche, baisse avant livraison, voiture sur un pont inaccessible, réussite sans accès, notification répétée à la reprise. Les prix et durées des ponts restent ceux de la carte ; leur équilibre reste à juger.

## Premier retour de jeu — 2026-09-22
**L'attente se paie** (auteur) : **0,4 k€ par personne dehors et par mois**, en haut de `ville.gd` — 260 dehors = **104 k€/mois**, affiché sous le compteur. 🔴 Sans aucun abri, la caisse est vide vers le **mois 34**, et plus rien ne se commande : le prix est à juger.
🔒 **Les premières minutes se jouent dans l'ordre** (auteur) : rien ne s'engage hors d'un champ tant qu'une personne est dehors ; puis rien hors d'un pont coupé et des rues qui barrent son accès, tant qu'aucun pont ne relie les rives ; la mairie et l'université restent grisées jusque-là. Le verrou ne revient plus après « Choisir la suite ». Un camp se taille sur les places **non encore commandées** : les deux camps se commandent d'affilée, 119 puis 11 containers. Un camp sur l'autre rive ne compte pas et le guide le dit. **Diagnostic Trafic** : une rue coupée (boue, pont emporté) sort de la rampe en **violet**, et le tablier manquant des trois ponts s'y dessine ; un brun se confondait avec « saturé ».
Guide : un bouton par pont, ×12 en premier, « Relever les logements » dit combien rentrent chez eux. Noms proposés dans `lieux.json` : ponts d’Amont, du Centre, d’Aval ; champs des Luzernes, des Bleuets, de l’Orge. Corrigé : un seul bandeau en haut, vitesse enfoncée, icônes mairie et université, virgules, îlot relevé à 0 logement perdu, textes raccourcis. À regarder : `02_camp`, `09`, `10_comparer_ponts`, `12`. Défaut : un chantier engageable hors séquence, une rue coupée bleu nuit sur le calque, un second camp surdimensionné.

## Contrôles

`Godot --path Godot --script res://outils/essai_ouverture.gd -- --ouverture --captures` joue le relogement, le mauvais champ, les deux débuts par clics, la comparaison sans dépense, le refus financier, l'épargne, la livraison, les piétons, la protection, le mode auteur, la sauvegarde et la reprise. Ajouter `--headless` et retirer `--captures` pour le contrôle sans image. `python QGIS/scripts/verifier_relogement.py` contrôle l'export (9 cas).

Dettes indépendantes : `essai_energie` échoue sur la barre au mois 12 ; `verifier_berges` attend 8 berges et en trouve 9 ; `essai_sauvegarde` compte 91 lieux sans nom et attend encore un titre en capitales ; les clics simulés des deux parcours échouent parfois au premier lancement.

## Ce qui attend le joueur

- Après une livraison, a-t-on envie de regarder le résultat puis de choisir la suite ?
- Le déblaiement et la remise en état font-ils deux débuts suffisamment différents ?
- La renaturation demande-t-elle trop d'épargne après la première réparation ?
- Le camp est-il assez laid, et le champ assez perdu, pour qu'on veuille relever les logements ? Les abris sont plus soignés qu'avant : est-ce qu'ils le sont trop ?
- 1,5 k€ le logement de containers : la moitié de la caisse est-elle le bon prix ?
- Le récit dure-t-il le bon temps, et la dernière page donne-t-elle envie de chercher plutôt que d'attendre une flèche ?
- Le temps qui part tout seul après la dernière carte presse-t-il, ou gêne-t-il le premier coup d'œil ?
- 12 personnes nourries par hectare : le champ pris se sent-il, ou faut-il un autre effet que la nourriture ?
- Trois lieux muets avant l'indice : est-ce trop tôt, trop tard ?
- Défauts à signaler : compteur ou commande visible pendant le récit, temps qui reste en pause après la dernière carte, campagne qui remonte après un camp, champ désigné par le jeu, page de récit qui couvre son sujet, chantier engageable pendant l'urgence, réussite avant livraison, rue toujours vide, dépense dès la comparaison, premiers pas perdus après reprise, guide qui masque les commandes, camp qui déborde du champ, pictogramme flottant sur la carte.

## Campagne du SVG vers Godot — 2026-09-15

Les 88 champs gardent leur contour importé, leur teinte et des bandes parallèles à leur grand côté. La grille agricole globale est retirée ; prairies et cultures se distinguent davantage. Les deux massifs portent des croupes boisées et se prolongent dans le décor extérieur, sans seconde ceinture de champs.

Les quatre sorties principales suivent exclusivement les limites communes de deux champs existants (623 m) et s'arrêtent à la lisière. Chaque angle du SVG est conservé ; aucun prolongement ne traverse la forêt ou les montagnes. Les dessertes 177 et 178 s'arrêtent avec les îlots, à la demande de l'auteur. Les prolongements sont du décor ; les décisions et le trafic restent sur les tronçons existants. Les arbres sont écartés des nouvelles chaussées.

Contrôles : `verifier_campagne.py` (6 cas), `verifier_voirie.py` (3 cas), chaîne complète et aires des 88 champs exportés vérifiées (écart maximal 0,013 %), axes des prolongements contrôlés sur les limites communes (écart inférieur à 1 mm), et trois cadrages Godot via `--script res://outils/apercu_campagne.gd`. Aperçus : `QGIS/rendus/wehrau_campagne_dessus_apres.png`, `..._relief_apres.png`, `..._champs_apres.png` ; `..._avant.png` garde le même cadrage avant correction.

À regarder : ① contours des champs, ② sortie ouest posée sur la limite des champs, ③a/b montagnes. Défauts à signaler : route coupant un champ ou dépassant sa lisière, champ réapparu derrière un massif, rupture rectangulaire du paysage. Les chemins d'accès aux fermes restent à dessiner. Les alertes d'export concernant les anciens ponts et les effectifs attendus de l'ancienne carte restent un chantier distinct.

## Emprise de boue — 2026-09-16

Le contour annoté par l'auteur limite le dépôt à l'est, indépendamment des îlots. Le nord et l'ouest de l'Ilse restent propres ; les dégâts des bâtiments et la boue lisent le même champ spatial. La route 177, ancienne desserte traversant le nouveau lit au sud, est retirée de la carte de travail. Aperçu numéroté : `QGIS/rendus/wehrau_emprise_crue_apres.png`.

Chaîne régénérée ; 20 contrôles Python passent et le rendu des trois zones est vérifié. Les premiers lieux passent aux Forgerons, avec la berge de leur bief. **Reste : deux échecs du parcours d'ouverture sur la réparation des logements ; le bouton d'engagement dépasse le bas de la fiche.** Tests arrêtés à la demande de l'auteur avant correction de cette interface ; la passe générale n'est pas déclarée validée.

## Quai aval le long de l'Ilse — 2026-09-17

À la demande de l'auteur, la route 178 suit la rive est jusqu'au bord sud du champ 1082 : six sommets, 235,7 m, raccord au réseau conservé. Son ancien tracé droit disparaît. Les champs rendus cèdent désormais la place aux chaussées qui les traversent ; leur contour source reste intact.
Chaîne régénérée, neuf contrôles voirie/campagne passent ; aucun centre des 120 triangles du quai n'est masqué par un champ. Aperçu numéroté : `QGIS/rendus/wehrau_quai_aval_apres.png`, reproductible avec `--script res://outils/apercu_quai_aval.gd`. À regarder : ① raccord, ② route continue au bord de l'Ilse, ③ arrêt au dernier champ ; une chaussée recouverte par le champ ou prolongée dans la forêt serait un défaut.

## La desserte passe à la lisière — 2026-09-18

La coupe est **Ilse → berge naturelle → trois champs → route → bois** (demande de l'auteur sur capture) : la route ne s'intercale plus entre le fleuve et les cultures. Son tracé dans `routes.geojson` est désormais la limite commune des trois champs et du bois — 5 sommets, 237,0 m contre 235,7, raccordée au coude de la rue 174 — donc `04b` lui retire sa demi-chaussée comme à n'importe quel îlot, et il n'y a plus rien à caler à l'export. Les arbres du bois s'écartent de la chaussée neuve.

**Les trois champs ont rétréci de 9 %**. Le recul de berge reste de 30 m (`LIMITE_CULTURE_M`, haut de `faubourg.py`) ; le besoin de prendre les trois champs est levé par l'occupation des containers, sans redessiner la rive.

À regarder : `wehrau_lisiere_apres.png` (`--script res://outils/apercu_lisiere.gd`), quatre repères numérotés. Défaut à signaler : chaussée dans un champ ou dans l'Ilse, arbre sur la chaussée, raccord manquant à la rue du faubourg.

## Rive et containers — 2026-09-18

Les talus voisins ne remontent plus à chaque limite de champ.
La surface cultivée, les emplacements de containers, le contour de sélection et le déboisement utilisent la même limite intérieure : poser un camp conserve les arbres de la rive. Capacités dans la table en tête ; le réglage d'occupation est décrit dans « Le relogement ».
Contrôlé : chaîne complète, 18 cas Python (relogement/voirie/campagne), parcours d’ouverture avec captures à zéro échec, contrôle Godot de l’orientation et de la matière à zéro erreur. Les alertes d’effectifs héritées de l’ancienne carte persistent.
À regarder avec `--script res://outils/apercu_faubourg.gd -- --histoire` : `wehrau_faubourg_01_rive.png`, `..._02_camp.png`, `..._03_module.png`. `essai_camp.gd` vérifie les matrices avec le vrai rendu (sans `--headless`). Défaut à signaler : route ou container sur la berge, champ recouvrant la route, arbre traversant un module.
