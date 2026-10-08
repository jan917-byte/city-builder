extends Resource
# La fiche de réglages de l'habillage « vitre », ouverte par l'auteur dans l'inspecteur
# (`res://habillage.tres`). Les valeurs ci-dessous sont l'origine : la flèche ↺ y revient.
# Les `##` sont les bulles d'aide de l'inspecteur, donc écrits pour l'auteur.

@export_group("Texte")
## La police de toute l'interface. Les fichiers sont dans le dossier « polices ».
@export_enum("rubik", "grotesk", "barlow", "nunito", "fredoka", "baloo", "godot") var police := "rubik"
## Graisse du texte courant : 400 = normal, 700 = gras.
@export_range(100, 900, 50) var graisse_texte := 600
## Graisse des titres de fiche.
@export_range(100, 900, 50) var graisse_titres := 750
## Graisse des boutons et des nombres.
@export_range(100, 900, 50) var graisse_boutons := 700
## L'encre : titres, valeurs, texte des boutons.
@export var encre := Color8(28, 32, 35)
## Le gris des phrases secondaires.
@export var gris := Color8(92, 98, 102)
## Le gris des petites étiquettes, plus sombre parce qu'un mot de 11 px se lit mal.
@export var gris_etiquettes := Color8(70, 76, 80)

@export_group("Couleurs du jeu")
## Le vert du bouton qui engage la caisse et du remplissage des curseurs.
@export var vert := Color8(54, 122, 76)
## Les sommes d'argent, la poignée des curseurs.
@export var accent := Color8(28, 32, 35)
## Un chantier fini, écrit en texte.
@export var fini := Color8(44, 112, 56)
## Un refus : la caisse ne suit pas.
@export var alerte := Color8(198, 76, 66)
## L'anneau jaune autour de ce que le guide demande de cliquer.
@export var appel := Color8(240, 190, 40)

@export_group("Panneaux")
## La teinte posée sur la ville floutée. La transparence (A) règle combien la ville se voit :
## sous 0,70 le texte se perd sur les toits rouges.
@export var verre := Color(0.965, 0.968, 0.962, 0.74)
## Le liseré qui fait le bord du verre.
@export var lisere := Color(1, 1, 1, 0.75)
## Épaisseur du liseré, en pixels.
@export_range(0, 6) var lisere_epaisseur := 1
## L'espace entre le bord du panneau et ce qu'il contient, en pixels.
@export_range(0, 40) var marge_interieure := 14
## Les coins : 0 = angles droits, 1 = l'arrondi des anciens habillages.
@export_range(0.0, 2.0, 0.05) var arrondi := 0.0
## Le fond des bulles qui montent de la ville.
@export var fond_bulles := Color8(244, 245, 243)
## Le fond d'un onglet survolé et des cartes du concours.
@export var fond_cartes := Color8(226, 229, 226)
## Le trait entre deux sections d'une fiche.
@export var separateur := Color(0.109804, 0.12549, 0.137255, 0.12)

@export_group("Boutons")
## Taille du texte des boutons.
@export_range(8, 30) var taille := 14
@export var fond := Color(1, 1, 1, 0.55)
@export var bord := Color(0.109804, 0.12549, 0.137255, 0.16)
@export var fond_survol := Color(1, 1, 1, 0.85)
@export var bord_survol := Color(0.109804, 0.12549, 0.137255, 0.45)
## Un réglage posé : la plaque, et l'encre écrite dessus.
@export var fond_choisi := Color8(28, 32, 35)
@export var encre_choisi := Color.WHITE
@export var fond_grise := Color(1, 1, 1, 0.25)
@export var bord_grise := Color(0.109804, 0.12549, 0.137255, 0.08)
## Le fond d'une icône du rail de gauche quand la souris passe dessus.
@export var rail_survol := Color8(255, 255, 255, 140)

@export_group("Bouton qui engage")
## « Mettre en place » : le seul bouton plein du jeu. Son fond est le vert de « Couleurs du jeu ».
@export_range(8, 30) var taille_engage := 15
@export var bord_engage := Color8(38, 86, 44)
@export var survol_engage := Color8(78, 142, 86)
@export var appuye_engage := Color8(46, 100, 54)
## Quand la caisse ne suit pas : il reste vert, éteint.
@export var eteint_engage := Color8(204, 212, 188)
@export var encre_eteint_engage := Color8(96, 114, 80)

@export_group("Jauges")
## La part encore vide d'une jauge et la gouttière des curseurs.
@export var jauge_vide := Color8(168, 173, 170)
## Les petits pictogrammes pas encore atteints.
@export var pictos_pales := Color8(205, 208, 204)
