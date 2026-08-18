# Le prototype énergie — une décision, deux échelles

> 🔄 **Simplifié par l’auteur le 2026-08-17.** Le prototype ne teste plus une
> paire de décisions opposées. Il teste le geste le plus court : cliquer un
> îlot, augmenter sa part de panneaux solaires, voir l’îlot et la ville réagir.
>
> 💶 **Puis, le même jour, une petite économie y est revenue** — *« rajoute une
> petite économie simple, avec les coûts et les rendements des panneaux
> solaires »*. Le geste ne change pas ; ce qui change, c’est qu’il se paie, et
> qu’il ne se paie pas partout au même prix.
>
> Plan de chantier vivant, pas source de vérité du design. Les décisions sont
> consignées dans `Décisions arrêtées` **68**, **69** et **71**.

## 1. La boucle actuelle

1. Le joueur voit les informations de **toute la ville à gauche**.
2. Il clique un îlot.
3. La fiche de **cet îlot seulement** apparaît à droite. Le survol et les rues
   ne remplacent jamais cette fiche.
4. Il choisit une part solaire entre la valeur actuelle et **100 %**.
5. Avant de confirmer, la fiche annonce **le temps et le prix**. Passer de 0 à
   100 % demande **1 mois** ; une hausse plus petite prend la même proportion,
   et la fiche l’annonce alors **en jours** (une hausse de 50 points = 15 jours).
6. Si la caisse ne suit pas, la fiche dit **combien il manque** et le bouton
   refuse. C’est le seul non que le prototype sache prononcer.
7. Pendant la pose, une barre avance vers la cible : les toits s’assombrissent,
   la production monte, l’achat et le CO₂ baissent à l’échelle de l’îlot et de
   la ville, et la recette solaire commence à rentrer.
8. Le temps peut être mis en pause ou accéléré en **×1, ×4 ou ×12**. L'échelle
   de base est **une minute de jeu pour un mois** (changée le 2026-08-17 : elle
   était d'une seconde, et tout passait trop vite pour se voir). Donc à ×1
   équiper un îlot en entier prend **une minute de montre**, 5 secondes à ×12,
   et les 240 mois de l'horizon tiennent en 20 minutes à ×12.
9. **Recommencer** ramène au mois 0, annule les poses et rend la caisse : on
   rejoue le même geste sans relancer la maquette.

La part ne peut que monter. La redescendre serait une autre décision — déposer
des panneaux — qui n’appartient pas à ce test.

🔒 **Un chantier engagé ne se révise plus.** Tant que la pose avance, le
curseur est verrouillé et le bouton dit « chantier en cours ». Ce n’est pas une
limitation d’interface : réécrire une cible en cours de route effacerait
l’histoire de la pose, et **la recette encaissée est l’intégrale de cette
histoire**. Une révision aurait fait croire à la caisse que le toit produisait
depuis le premier jour.

## 2. Ce qui est affiché

| Gauche — toute la ville | Droite — îlot cliqué |
|---|---|
| consommation en GWh/an | tissu |
| production solaire en GWh/an | logements |
| énergie achetée en GWh/an | consommation en MWh/an |
| CO₂ en kt/an | production en MWh/an |
| **caisse en k€** | toit équipable en m² |
| **recette solaire en k€/an** | **se rembourse en … ans** |
| | part posée, cible, temps restant |
| | une jauge de lecture puis un curseur de réglage |
| | **le coût de la cible visée, et ce qu’il resterait en caisse** |

Les deux lignes d’argent viennent **après** les quatre d’énergie, séparées par
un filet, et pas avant : c’est l’énergie qu’on transforme, l’argent n’est que
ce qui limite le rythme. La caisse est le seul nombre de l’écran qui puisse
dire non — elle porte donc la couleur d’accent.

L’amortissement est dans la grille de l’îlot et pas près du curseur, parce
qu’il **ne dépend pas de la part visée** : coût et recette sont tous deux
proportionnels aux mètres carrés posés, donc leur rapport est une propriété du
tissu. Équiper un dixième d’un toit s’amortit exactement aussi vite que
l’équiper en entier. C’est un critère de **choix d’îlot**, pas de dosage.

### Le réglage solaire — deux objets, deux métiers

Arbitré par l’auteur le **2026-08-17**, après une première version où deux barres
jumelles se disputaient le même rôle et où le curseur, réécrit à chaque image,
était intraînable.

| | Ce que c’est | Ce qu’on y lit |
|---|---|---|
| **La jauge**, en haut | une lecture, elle ne se touche pas | ce qui est **posé** en jaune clair, avancé jusqu’à l’objectif en jaune éteint |
| **Le curseur**, en bas, sous « Objectif » | le seul objet qu’on attrape | l’objectif visé, au pourcent près, sur une échelle **fixe de 0 à 100 %** |

L’échelle du curseur ne bouge jamais : le même pixel veut dire la même chose du
début à la fin de la partie. La poignée refuse simplement de descendre sous ce
qui est déjà sur les toits — déposer des panneaux n’est pas une décision de ce
prototype.

Un panneau en bas de l’écran affiche le mois courant et les quatre commandes
de temps : pause, ×1, ×4 et ×12. `Espace` alterne lecture et pause.

Un cinquième bouton, **Recommencer**, remet le temps au mois 0. Il ne recule
pas seulement le compteur : les poses décidées disparaissent et la ville
retrouve son état de chargement, sinon des toits noirs resteraient affichés
sous un compteur à « Mois 0 ». Le retour se fait en pause, pour laisser le
temps de regarder avant que ça reparte.

Il n’y a plus de bandeau transversal : les deux échelles occupent deux côtés
distincts de l’écran. La fiche ne suit plus le survol.

## 3. Ce qui est volontairement absent

- pas de capital politique ;
- pas d’isolation ;
- pas de tarif de rachat, pas de subvention, pas d’emprunt ;
- pas de dérive des prix dans le temps — le panneau ne baisse pas, l’énergie ne
  monte pas ;
- pas d’études ni de délai invisible avant la pose ;
- pas de calque thématique ;
- pas de ciblage de plusieurs îlots par seuil.

🔄 **« Pas de budget » a sauté le 2026-08-17**, à la demande de l’auteur. Le
reste de la liste tient.

⚠️ **Les deux dérives du temps sont écrites dans le code et débranchées**, pas
supprimées : le panneau à −6 %/an et l’énergie à +2 %/an. Composées, elles
faisaient fondre l’amortissement d’environ 7,8 % par an — donc **attendre était
toujours le bon coup**. C’est la question *quand investir ?* ; celle qu’on teste
d’abord est *où investir ?*. Une molette à la fois.

`chantiers.gd` et l’ancien essai imprimé restent dans le dépôt comme trace
technique, mais la boucle jouable ne les appelle plus. Ils ne décrivent donc
plus le prototype actuel.

## 4. Les nombres qui restent vrais

La simplification de l’interface ne change pas la physique déjà branchée :

- consommation de départ de Wehrau : **53,9 GWh/an** ;
- production initiale : **0** ;
- rendement solaire : **140 kWh/m²/an**, modulé par le tissu et l’ombrage ;
- potentiel calculé sur les **11,0 ha de toiture réelle**, pas sur une emprise
  estimée ;
- achat = consommation − production ;
- CO₂ = énergie achetée × facteur d’émission.

### La petite économie, en deux prix

Tout le reste s’en déduit — il n’y a pas de troisième nombre à régler.

| | Valeur | D’où ça sort |
|---|---:|---|
| coût du m² posé | **260 €** | panneau, structure et pose sur une toiture existante, multiplié par le `cout_x` du tissu (0,8 sur la barre, 1,8 en cœur ancien) |
| valeur du MWh produit | **150 €** | ce que vaut le mégawattheure qu’on ne rachète pas |
| caisse au mois 0 | **800 k€** | level design — de quoi équiper deux ou trois bons toits |
| dotation | **30 k€/mois** | level design — 360 k€/an votés pour la transition |

🔴 **La facture d’énergie de la ville ne traverse jamais la caisse**, et c’est
délibéré : à 53,9 GWh/an, elle vaut **8,1 M€/an**, payés par les occupants, pas
par la mairie. Les mélanger donnerait une mairie qui paie vingt fois sa dotation
en électricité, donc un jeu sans décision. La caisse ne connaît que les
panneaux : ce qu’ils coûtent à poser, ce qu’ils rapportent.

### Un seul propriétaire — tranché le 2026-08-18

**Tout le logement et tous les panneaux appartiennent à la ville.** Il n’y a
donc pas de toit des autres : pas de loyer de toiture, pas de copropriété qui
refuse, pas de deux régimes selon le tissu. `Décisions arrêtées` **70**, qui
ferme la question n°22 ouverte la veille.

⚠️ **Posséder un logement n’est pas payer sa facture.** La ville est
**propriétaire-bailleur** : elle a les murs et les toits, ses locataires paient
leur électricité. C’est cette ligne-là qui tient le paragraphe au-dessus.

Ce qui distingue encore les îlots n’est donc plus la propriété mais le **coût
d’accès au toit** et son **rendement**, tous deux déjà dans la table. Une
exception physique s'ajoute : l'église de l'îlot 16 appartient à la ville mais
sa protection interdit les panneaux.

🔴 C’est une simplification **de prototype**, pas une thèse sur la ville. Le
propriétaire qui dit non est une tension que le jeu complet devra porter — à
rouvrir avant Vallmar.

### Ce que la ville entière coûte, mesuré au mois 0

| Tissu | Îlots | Équiper en entier | Se rembourse en |
|---|---:|---:|---:|
| barre 1970 | 1 | 389 k€ | **10 ans** |
| équipement | 1 équipable + l'église protégée | 339 k€ | **11 ans** |
| friche industrielle | 2 | 1 272 k€ | **11 ans** |
| pavillonnaire | 12 | 1 810 k€ | 18 ans |
| maisons de ville | 20 | 4 744 k€ | 19 ans |
| front commerçant | 5 | 928 k€ | 20 ans |
| cœur ancien | 13 | 1 652 k€ | **31 ans** |
| **toute la ville** | **54 équipables** | **11 135 k€** | → **644 k€/an** |

C’est là qu’est la décision, et elle est dure : les grands toits restent les
premiers choix, tandis que l'église est **hors choix**. Continuer ensuite, c’est acheter
du CO₂ évité, pas faire un placement. Le jeu peut dire ça sans être cynique —
il ne le dit pas encore, et c’est un des points à regarder à l’écran.

Deux repères de rythme : la dotation seule apporte **8 000 k€ sur vingt ans**,
donc elle ne paie pas la ville entière ; et **un seul îlot dépasse la caisse de
départ** — la friche de l’îlot 31, à 869 k€. Ce n’est donc pas la caisse qui
bloque au premier jour, c’est le rythme.

Le réglage de l’îlot 32, la barre de 1974, de 0 à 100 % produit le contrôle
actuel :

| | avant | après |
|---|---:|---:|
| production de la ville | 0,0 GWh/an | **0,3 GWh/an** |
| achat de la ville | 53,9 GWh/an | **53,6 GWh/an** |
| CO₂ de la ville | 13,5 kt/an | **13,4 kt/an** |
| part solaire de l’îlot 32 | 0 % | **100 %** |
| caisse | 800 k€ | **442 k€** — 389 k€ payés, 30 k€ de dotation, 1 k€ de recette |
| recette solaire de la ville | 0 k€/an | **+38 k€/an** |

## 5. Ce qui doit se voir

Le contrôle automatisé imprime le tableau d’économie ci-dessus, éprouve le
refus sur l’îlot le plus cher, vérifie l'église protégée, puis passe l’îlot
**32** de 0 à 100 %. Il produit notamment :

- `QGIS/rendus/wehrau_essai_barre.png` — avant ;
- `QGIS/rendus/wehrau_essai_eglise.png` — îlot 16, **0 m² équipable**, curseur
  verrouillé et raison écrite ;
- `QGIS/rendus/wehrau_essai_caisse.png` — **le refus**, îlot 31 : *« Coût
  869 k€ · il manque 69 k€ en caisse »* en rouge, bouton éteint ;
- `QGIS/rendus/wehrau_essai_solaire_100.png` — après.

La preuve attendue :

1. le panneau gauche ne parle que de la ville ;
2. le panneau droit ne parle que de l’îlot 32 ;
3. à mi-pose, la fiche affiche **50 % posés**, une cible à 100 % et **15 jours
   restants** ;
4. le toit de la barre passe progressivement du clair à l’ardoise sombre ;
5. après **1 mois**, la production de ville passe de 0,0 à 0,3 GWh/an ;
6. le bouton se ferme sur « Toit entièrement équipé » ;
7. la caisse tombe **exactement** du coût annoncé, au mois de la décision ;
8. « Recommencer » rend la caisse à 800 k€ en même temps que les toits ;
9. aucun capital politique n’apparaît.

Trois contrôles imprimés le vérifient et arrêtent la maquette s’ils tombent à
faux : la caisse payée au centime, le refus qui ne dépense rien, et un chantier
en cours qui n’accepte pas de seconde commande.

Si le curseur revient tout seul en arrière pendant qu’on le déplace, c’est
cassé — c’était le défaut du 2026-08-17, la fiche reposait sa valeur soixante
fois par seconde. Si une rue survolée remplace la fiche, c’est cassé. Si les chiffres bougent
sans que les toits changent, c’est cassé. **Si la caisse change de valeur selon
la vitesse du temps ou le nombre d’images par seconde, c’est cassé** : la
recette est une intégrale exacte, pas un compteur ajouté à chaque image.

## 6. Les fichiers actifs

| Fichier | Ce qu’il porte |
|---|---|
| `Godot/scripts/interface.gd` | les deux panneaux, la jauge solaire, son curseur, le prix et le refus |
| `Godot/scripts/ville.gd` | la cible solaire, sa progression sur un mois maximum, et **la caisse** |
| `Godot/scripts/energie.gd` | les coefficients, les quatre conséquences et **les deux prix** |
| `Godot/scripts/maquette.gd` | le clic, le branchement et le rendu avant/après |
| `Godot/scripts/materiaux.gd` | les toits qui s’assombrissent selon la part équipée |

## 7. Ce que ce prototype répond — et ce qu’il ne répond pas

Il répond à une question d’interface et de lisibilité :

> **Est-ce que le joueur comprend qu’il transforme un îlot et que cette
> transformation remonte progressivement à l’échelle de la ville ?**

Et depuis la décision **69**, il commence à répondre à une deuxième :

> **Est-ce que « où investir ? » est une question intéressante quand les
> toits ne se remboursent pas tous ?**

Il ne répond toujours pas à « quand investir ? » — les dérives de prix sont
débranchées — ni à « les panneaux et l’isolation se contraignent-ils ? ». Ces
questions restent dans le vault ; les réintroduire demandera une décision de
l’auteur, pas une réactivation silencieuse de l’ancien code.

---

**Voir aussi** : [00 - Prototype.md](00%20-%20Prototype.md) · [Parcelles.md](Parcelles.md) · `Vault - Jeu urbanisme/Méta/Décisions arrêtées.md` · `Godot/README.md`
