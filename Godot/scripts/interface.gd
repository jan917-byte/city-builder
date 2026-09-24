extends CanvasLayer
# L'interface du prologue climatique : adaptation, puis réduction.
# 🔄 Le verrou de l'urgence est tombé le 2026-08-31 (voir `ville.lancer_solaire`). Les
# réparations font avancer la jauge d'adaptation.

signal vitesse_demandee(vitesse: float)
signal temps_remis()
signal sauvegarde_demandee()
signal reprise_demandee()
signal nord_demande()
signal dessus_demande()
## "" ramène à la ville vivante, sinon c'est un `id` de `maquette.THEMES`.
signal theme_demande(id: String)
## 🔴 UNE SEULE DEMANDE, ET C'EST TOUT CE QUE LA FICHE ÉMET (2026-08-31). On
## règle, on compare l'avant et l'après, puis on met en place : les réglages
## posés partent ensemble, au format que `ville.commander` lit.
## 🔄 Cinq boutons émettaient cinq demandes AU CLIC — rien à essayer, rien à
## reprendre, et chacun disait « il manque 214 k€ » de son côté.
signal commande_demandee(couche: String, fid: int, reglages: Dictionary)
## 🛠️ Le mode choisi au lancement : histoire, ou auteur (chantiers livrés au clic).
signal mode_choisi(auteur: bool)

const Ville := preload("res://scripts/ville.gd")
## 🪜 Pour le seul remboursement de la tranche : la fiche annonce ce que la
## progressivité change, et le nombre se calcule là où sont les deux courbes.
const Energie := preload("res://scripts/energie.gd")
const Apercu := preload("res://scripts/apercu.gd")
const Recherche := preload("res://scripts/recherche.gd")
const Politiques := preload("res://scripts/politiques.gd")
const Lieux := preload("res://scripts/lieux.gd")
var lieux := Lieux.new()
var _reprendre: Button

## 🔤 LA POLICE, À TRANCHER DEVANT L'IMAGE. Trois candidates dans
## `Godot/polices/`, toutes sous licence SIL OFL (leur `*-OFL.txt` est à côté du
## fichier) — donc libres pour un jeu vendu. `-- --police <clé>` en essaie une
## sans toucher au fichier ; « godot » est la police d'origine.
const POLICES := {
	"godot": "",
	"rubik": "res://polices/Rubik.ttf",
	"grotesk": "res://polices/SpaceGrotesk.ttf",
	"barlow": "res://polices/BarlowSemiCondensed.ttf",
	"nunito": "res://polices/Nunito.ttf",
	"fredoka": "res://polices/Fredoka.ttf",
	"baloo": "res://polices/Baloo2.ttf",
}
const POLICE := "rubik"
## 🔷 VERRE BLEU (auteur, 2026-09-20), en remplacement du papier crème. Le fond
## des panneaux n'est plus une couleur mais la ville floutée (`shaders/verre`) ;
## `FOND` ne sert donc que de secours si le verre est coupé.
const VERRE := true
## 🔴 LEVEL DESIGN, RELEVÉ LE 2026-09-20 après les captures : à 0,66 le petit
## texte gris se perdait sur les toits rouges. C'est la lisibilité qui tranche,
## pas l'effet — sous 0,70 on ne lit plus, au-dessus de 0,85 ce n'est plus du verre.
const VERRE_TEINTE := Color(0.90, 0.94, 1.00, 0.78)
const FOND := Color8(238, 244, 251, 190)
const FOND_FORT := Color8(210, 227, 245, 168)
const BORD := Color8(255, 255, 255, 150)
const TEXTE := Color8(23, 40, 61)
const GRIS := Color8(72, 94, 122)
## 🔠 Le gris des ÉTIQUETTES en capitales : plus sombre que celui des phrases,
## parce qu'un mot de 10 px en capitales a moins de forme à offrir à l'œil.
const GRIS_FORT := Color8(46, 74, 108)
const ACCENT := Color8(26, 88, 148)
## L'azur des bandeaux, des filets et du bouton qui engage : c'est lui qui
## fait « jeu » plutôt que « document ». Jamais sous du texte long.
const ACCENT_VIF := Color8(46, 141, 224)
# Le seul refus du prototype : la caisse ne suit pas. Un bouton grisé sans
# raison écrite est une panne, pas une règle.
const ALERTE := Color8(198, 76, 66)
## 🌑 LE RAIL EST SOMBRE, LE VERRE RESTE CLAIR (2026-09-03, image de l'auteur).
## C'est le seul endroit du prototype qui n'est pas translucide : la barre
## d'outils est la MACHINE, les panneaux sont le DOCUMENT. Sans ce contraste,
## une colonne d'icônes claires sur une ville pastel disparaît.
const RAIL_FOND := Color8(21, 38, 61, 244)
const RAIL_TUILE := Color8(38, 60, 90, 255)
const RAIL_SURVOL := Color8(60, 94, 136, 255)
const RAIL_ICONE := Color8(223, 235, 250)
# 🔧 LES TROIS COULEURS DE LA VUE CHANTIERS, aussi dans le shader
# (`materiaux.objet`, en linéaire) : n'en changer qu'une fait mentir la légende.
const CASSE := Color8(220, 58, 48)
const EN_TRAVAUX := Color8(232, 170, 48)
const FAIT := Color8(91, 174, 117)
## Les genres de `ville.chantier` en clair, pour la barre de la fiche.
const CHANTIER_MOTS := {
	"reconstruction": "Reconstruction", "pont": "Tablier rebâti",
	"deblaiement": "Déblaiement", "solaire": "Pose de panneaux",
	"berge": "Rive transformée", "stationnement": "Retrait des places",
	"densification": "Étages ajoutés",
	"relogement": "Installation des abris",
}


## Ce qui est POSÉ, et vers quoi ça va. Un `ProgressBar` ne montre qu'un
## nombre : il en faut deux pour distinguer « 40 % posés » de « 40 % en route
## vers 72 % ». Elle ne se touche pas — le réglage est le curseur d'en dessous.
class Jauge extends Control:
	const RESTE := Color8(196, 212, 232, 190)    # le toit encore nu
	const VISEE := Color8(174, 147, 74)          # l'objectif demandé, pas encore atteint
	const POSE := Color8(221, 171, 49)           # les panneaux réellement en place

	var pose := 0.0   # 0 → 1
	var cible := 0.0  # 0 → 1, toujours ≥ pose
	var couleur_reste := RESTE
	var couleur_visee := VISEE
	var couleur_pose := POSE
	# 🔄 EN PILULE depuis le 2026-09-03, et le filet qui l'entourait est parti
	# avec : sur le papier clair, la gouttière se voit toute seule. Les trois
	# boîtes sont refaites à `colorer()`, jamais dans `_draw()`.
	var _sb_reste: StyleBoxFlat
	var _sb_visee: StyleBoxFlat
	var _sb_pose: StyleBoxFlat

	static func _pilule(coul: Color) -> StyleBoxFlat:
		var sb := StyleBoxFlat.new()
		sb.bg_color = coul
		sb.set_corner_radius_all(99)
		return sb

	func _refaire() -> void:
		_sb_reste = _pilule(couleur_reste)
		_sb_visee = _pilule(couleur_visee)
		_sb_pose = _pilule(couleur_pose)

	func colorer(rempli: Color, vide := RESTE) -> void:
		if rempli == couleur_pose and vide == couleur_reste and _sb_pose != null:
			return
		couleur_pose = rempli
		couleur_visee = rempli.darkened(0.35)
		couleur_reste = vide
		_refaire()
		queue_redraw()

	func regler(p: float, c: float) -> void:
		if is_equal_approx(p, pose) and is_equal_approx(c, cible):
			return  # ⚠️ appelé à chaque image : ne repeindre que sur un vrai changement
		pose = p
		cible = c
		queue_redraw()

	func _draw() -> void:
		if _sb_reste == null:
			_refaire()
		draw_style_box(_sb_reste, Rect2(Vector2.ZERO, size))
		# ⚠️ Plancher à `size.y` : sous une largeur d'un rond, la pilule
		# s'écrase en trait et 2 % ressemble à 0 %.
		if cible > pose:
			draw_style_box(_sb_visee,
				Rect2(0.0, 0.0, maxf(size.y, size.x * cible), size.y))
		if pose > 0.0:
			draw_style_box(_sb_pose,
				Rect2(0.0, 0.0, maxf(size.y, size.x * pose), size.y))


## 🧭 LA COLONNE D'ICÔNES, ET LE PANNEAU QUI S'OUVRE À CÔTÉ (2026-09-03, demande
## de l'auteur). Elle remplace le bandeau de neuf tuiles ET la barre du bas : le
## mot d'une icône est passé en infobulle. Les trois abscisses tiennent ici et
## nulle part ailleurs — un panneau qui s'ancre tout seul se décale du rail.
const RAIL_X := 14.0
const RAIL_LARGEUR := 90.0
const DETAIL_X := RAIL_X + RAIL_LARGEUR + 10.0
const DETAIL_LARGEUR := 312.0
const HAUT := 14.0


## Une quantité comptée en jetons plutôt qu'en phrase : dix pastilles, k
## allumées. La texture est dessinée EN BLANC — c'est la teinte qui la colore,
## sinon la modulation multiplierait deux couleurs.
class Pictos extends Control:
	const NB := 10
	const PALE := Color8(198, 212, 230)

	var texture: Texture2D
	var teinte := Color.WHITE
	var part := 0.0

	func regler(p: float) -> void:
		p = clampf(p, 0.0, 1.0)
		if is_equal_approx(p, part):
			return
		part = p
		queue_redraw()

	func _draw() -> void:
		if texture == null:
			return
		var allumes := int(roundf(part * float(NB)))
		var pas := size.x / float(NB)
		for i in NB:
			draw_texture_rect(texture, Rect2(i * pas, 0.0, size.y, size.y),
				false, teinte if i < allumes else PALE)


var ville: Ville
var trafic
var ouverture
var retours := preload("res://scripts/retours.gd").new()
var _acces_boutons: VBoxContainer
var _debut: Button
## 🔎 La texture de la miniature, posée par `maquette.gd` avant `batir()`.
var apercu: Texture2D
var themes := []     # `maquette.THEMES`, passée : pas d'import croisé
var rampe := []      # `maquette.RAMPE`, en sRGB

var _ville_valeurs := {}
var _ville_jauges := {}
## Le repère du mois 0 pour les deux seuls chiffres qui n'ont pas de part
## naturelle — la conso et le CO₂ —, mémorisé au premier `maj()`.
var _conso_zero := 0.0
var _co2_zero := 0.0
var _adaptation_jauge: Jauge
var _adaptation_valeur: Label
var _adaptation_pictos: Pictos
var _reduction_jauge: Jauge
var _reduction_valeur: Label
var _reduction_pictos: Pictos
var _fiche_valeurs := {}
var _fiche_titre: Label
## Le type de l'objet, sous son nom : une identité, jamais une mesure.
var _fiche_soustitre: Label
var _fiche_vide: Label
## 🗂️ LA FICHE EST À ONGLETS (auteur, 2026-09-18) : une ligne de résumé, puis
## une rangée d'icônes, et UN SEUL thème ouvert à la fois — ses chiffres ET son
## réglage. Ce qui suit est tout le mécanisme.
## `_dispo` dit quels onglets l'objet courant mérite ; `_bloc_onglet` range
## chaque bloc de réglage sous son thème ; `_bloc_dispo` garde son droit à
## s'afficher indépendamment de l'onglet ouvert — sans quoi la phrase de
## l'urgence ne saurait plus si le camp existe.
var _resume_ligne: HBoxContainer
var _resume_icone: TextureRect
var _resume_texte: Label
var _resume_dessin := ""
var _onglets: HBoxContainer
var _onglet_boutons := {}
var _onglet_grilles := {}
var _onglet_actif := ""
var _dispo := {}
var _bloc_onglet := {}
var _bloc_dispo := {}
var _chantier_bloc: VBoxContainer
var _chantier_quoi: Label
var _chantier_reste: Label
var _chantier_jauge: Jauge
var _solaire_bloc: VBoxContainer
var _solaire_valeur: Label
var _solaire_curseur: HSlider
var _solaire_jauge: Jauge
## 🌿 Le second usage du même toit. Bloc jumeau du solaire — même curseur, même
## jauge, même mémoire de position — parce que les deux se partagent un 100 %.
var _vert_bloc: VBoxContainer
var _dense_bloc: VBoxContainer
var _dense_valeur: Label
var _dense_boutons: Array[Button] = []
var _dense_curseur: HSlider
var _dense_jauge: Jauge
var _vert_valeur: Label
var _vert_curseur: HSlider
var _vert_jauge: Jauge
var _arbres_bloc: VBoxContainer
var _arbres_valeur: Label
var _arbres_curseur: HSlider
var _arbres_jauge: Jauge
## Le récapitulatif et LE bouton : ce que la commande coûte, ce qu'elle dure, et
## le seul refus du jeu quand la caisse ne suit pas.
var _recap_bloc: VBoxContainer
var _recap_texte: Label
var _recap_bouton: Button
## Les deux boutons de la miniature. 🔎 Ils n'apparaissent que lorsque les deux
## images DIFFÈRENT : sans réglage posé ni chantier en cours, « avant » et
## « après » montreraient la même chose et le geste ne voudrait rien dire.
var _apercu_boutons: HBoxContainer
var _avant_bouton: Button
var _apres_bouton: Button
var _message: Label
var _camera_nord: Button
var _camera_dessus: Button
var _temps_label: Label
var _vitesses := {}
## 📖 Les deux panneaux du bas, rangés pendant le récit avec tout le reste.
var _temps_panneau: PanelContainer
var _camera_panneau: PanelContainer
var _ville_panneau: PanelContainer
var _menu_panneau: PanelContainer
var _menu_boutons := {}
## 🔒 Les tuiles de la mairie et de l'université, grisées pendant le verrou.
var _rail_lieux: Array[Button] = []
## 🎓🏛️ LES DEUX MENUS QUI ONT UN LIEU (décision 81). `_lieu_ouvert` vaut ""
## quand la fiche d'îlot est en place : les deux ne s'affichent jamais ensemble.
var _lieu_panneau: PanelContainer
var _lieu_titre: Label
var _lieu_intro: Label
var _lieu_message: Label
var _lieu_lignes := {}
var _lieu_ouvert := ""
var _lieu_bouton: Button
var _diagnostic_panneau: PanelContainer
var _chantiers_panneau: PanelContainer
var _calque_panneau: PanelContainer
var _calque_bas: Label
var _calque_haut: Label
var _calque_barre: TextureRect
var _calque_note: Label
## Les trois panneaux de thème portent le MÊME en-tête, tiré de la table :
## le nom et le résumé ne sont écrits qu'une fois, dans `maquette.THEMES`.
var _entetes := {}
## Rouvrir le diagnostic doit rendre le thème qu'on regardait, pas le premier
## de la liste : sinon comparer deux mois coûte deux clics au lieu d'un.
var _chantiers_valeurs := {}
var _chantiers_lignes := []
var _fiche_panneau: PanelContainer
var _depart_panneau: CenterContainer
var _fiche_defilement: ScrollContainer
var _fiche_contenu: VBoxContainer
var _apercu_cadre: PanelContainer

var _fiche_fid := -1
var _fiche_couche := "i"
var _rue_valeurs := {}
var _repare_bloc: VBoxContainer
var _camp_bloc: VBoxContainer
var _camp_texte: Label
var _camp_bouton: Button
var _repare_texte: Label
var _repare_bouton: Button
var _repare_provisoire: Button   # 🌉 l'autre choix d'un pont coupé (auteur, 2026-09-24)
## 🎚️ LES BASCULES POSÉES SUR L'OBJET COURANT, pas encore mises en place. Les
## deux curseurs gardent leur propre mémoire, plus bas, parce qu'ils doivent
## survivre à une image sans se replacer sous le doigt ; `_reglages()` réunit
## les trois et c'est LUI seul que la commande et la miniature lisent.
var _pose := {}
## Vrai quand la miniature montre la ville d'AUJOURD'HUI au lieu de ce qui sera
## livré. Retombe à faux dès qu'on change d'objet : on veut voir sa promesse.
var _apercu_avant := false
var _trafic_bloc: VBoxContainer
var _trafic_stationnement: Button
var _trafic_axe: Button
var _berge_valeurs := {}
var _berge_bloc: VBoxContainer
var _berge_texte: Label
var _berge_boutons := []
var _degats := {}
var _degats_valeurs := {}
var _mois := 0.0
var _caisse_ke := Ville.CAISSE_DEPART_KE
var _cout_en_alerte := false

# La position posée par l'auteur et pas encore validée ; -1 = la fiche commande.
# ⚠️ Sans ce souvenir, `_maj_fiche()` (à chaque image) reposait la valeur sous
# le doigt et la barre était intraînable (défaut du 2026-08-17).
var _solaire_choix := -1.0
## 🏢 En BÂTIMENTS, pas en pourcents : c'est ce que le curseur compte, et c'est
## ce qui monte à l'écran. −1 = l'auteur n'y a pas touché.
var _dense_choix := -1.0
## Même mémoire, même raison, pour le curseur des toits verts.
var _vert_choix := -1.0
## Même mémoire, même raison, pour le curseur des arbres.
var _arbres_choix := -1.0
# Vrai pendant que la fiche écrit dans le curseur : une montée de `min_value`
# déplacerait la valeur et émettrait le signal, donc inventerait un choix.
var _ecrit_curseur := false
## La vue courante et son panneau. 🔴 Recliquer l'icône active REFERME le
## panneau, et c'est ici que ça se décide : `maquette._sur_theme` sort tout de
## suite quand le thème ne change pas, donc il ne rappellera pas `montrer_theme`.
var _theme_courant := ""
var _theme_actuel := {}
var _detail_ouvert := true
var _theme_ui: Theme
var _fonte_grasse: FontVariation
var _police: Font
var _fonte_texte: FontVariation
var _fonte_titre: FontVariation
var _icones := {}


func batir() -> void:
	_police = _charger_police()
	# 🔴 TOUT EST PLUS GRAS DEPUIS LE 2026-09-20 (auteur, sur captures) : sur du
	# verre, un texte maigre disparaît dès qu'un toit rouge passe dessous. Le
	# corps du texte est déjà en demi-gras, et les trois graisses se suivent.
	_fonte_texte = _peser(600, 0.16)
	_fonte_titre = _peser(750, 0.38)
	_fonte_titre.spacing_glyph = 1
	# Les nombres du bilan sont gras : dans un panneau sans mots, c'est le seul
	# poids typographique qui dit lequel des trois éléments d'une ligne compte.
	_fonte_grasse = _peser(700, 0.34)
	_theme_ui = _creer_theme()
	_panneau_bilan()
	_panneau_ilot()
	_panneau_lieu()
	_panneau_rail()
	_panneau_diagnostic()
	_panneau_chantiers()
	_panneau_calque()
	_panneau_camera()
	_controles_temps()
	retours.batir(self)
	_sans_focus(self)


## La police demandée, ou celle de Godot si le fichier manque — une police
## absente ne doit pas empêcher la maquette de s'ouvrir.
func _charger_police() -> Font:
	var nom := POLICE
	var args := OS.get_cmdline_user_args()
	var i := args.find("--police")
	if i >= 0 and i + 1 < args.size():
		nom = args[i + 1]
	var chemin := str(POLICES.get(nom, ""))
	if chemin == "" or not ResourceLoader.exists(chemin):
		if chemin != "":
			push_warning("police introuvable : %s" % chemin)
		return ThemeDB.fallback_font
	return load(chemin) as Font


## ⚠️ DEUX FAÇONS DE GRAISSER, ET UNE SEULE EST BONNE PAR POLICE : une police
## variable porte ses vrais dessins de graisse (`wght`) ; une police fixe n'a
## que le grossissement du contour, qui empâte. Les appliquer toutes les deux
## donnerait un gras double.
## 🔴 PIÈGE PAYÉ LE 2026-09-20 : `variation_opentype` n'accepte PAS `{"wght": …}`,
## la clé doit être le TAG ENTIER — mesuré, « Densifier » en 60 px fait 235 px
## avec la chaîne quel que soit le poids, 293 px avec le tag à 900. La graisse
## était silencieusement ignorée, et Rubik se dessinait à son défaut, 300.
func _peser(poids: int, grossir: float) -> FontVariation:
	var f := FontVariation.new()
	f.base_font = _police
	if _police != null and not _police.get_supported_variation_list().is_empty():
		var tag := TextServerManager.get_primary_interface().name_to_tag("wght")
		f.variation_opentype = {tag: poids}
	else:
		f.variation_embolden = grossir
	return f


## 🔴 Un bouton qui garde le focus MANGE le clavier du jeu : Espace le
## represse au lieu de mettre en pause, les flèches sautent au bouton voisin
## au lieu de tourner la caméra. Aucun champ de saisie ici — personne n'a
## besoin du focus.
func _sans_focus(n: Node) -> void:
	if n is Control:
		(n as Control).focus_mode = Control.FOCUS_NONE
	for e in n.get_children():
		_sans_focus(e)


const RAYON := 14
const Verre := preload("res://shaders/verre.gdshader")


func _boite() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	# ⚠️ AUCUN FOND QUAND LE VERRE EST LÀ : le `StyleBox` se dessine PAR-DESSUS
	# le verre, et un fond même à moitié transparent rebouche le flou.
	sb.bg_color = Color(FOND, 0.0) if VERRE else FOND
	# Le liseré clair est l'arête du verre : c'est lui, et non le fond, qui
	# donne l'épaisseur. Le verre s'arrête 1 px en deçà pour le laisser voir.
	sb.border_color = BORD
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(RAYON)
	sb.set_content_margin_all(13)
	# L'ombre portée est ce qui décolle le panneau de la ville : à 3 px elle
	# n'existait pas, et tout avait l'air imprimé sur la carte.
	sb.shadow_color = Color(0.05, 0.10, 0.20, 0.26)
	sb.shadow_size = 18
	sb.shadow_offset = Vector2(0, 7)
	return sb


## 🔷 Le fond flouté d'un panneau. ⚠️ DEUX PIÈGES DÉJÀ PAYÉS : `top_level` est
## ce qui empêche le conteneur de le ranger avec le contenu, mais il le fait
## aussi passer AU-DESSUS de tout — d'où le `z_index` négatif, qui le remet
## sous le panneau et son contenu.
func _vitrer(p: Control) -> void:
	if not VERRE:
		return
	var fond := ColorRect.new()
	fond.name = "Verre"
	fond.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fond.set_as_top_level(true)
	fond.z_index = -1
	var mat := ShaderMaterial.new()
	mat.shader = Verre
	mat.set_shader_parameter("teinte", VERRE_TEINTE)
	mat.set_shader_parameter("rayon", float(RAYON) - 1.0)
	fond.material = mat
	p.add_child(fond)
	p.move_child(fond, 0)
	var suivre := func() -> void:
		fond.global_position = p.global_position + Vector2.ONE
		fond.size = p.size - Vector2(2.0, 2.0)
		mat.set_shader_parameter("taille", fond.size)
	p.item_rect_changed.connect(suivre)
	suivre.call()


## Le fond et le verre d'un coup : les quatorze panneaux du jeu passent par là.
func _poser_boite(p: Control) -> void:
	p.theme = _theme_ui
	p.add_theme_stylebox_override("panel", _boite())
	_vitrer(p)


func _creer_theme() -> Theme:
	var t := Theme.new()
	# La police de TOUT ce qui hérite du thème : les panneaux la posent en même
	# temps que leur fond (`_poser_boite`), donc un seul endroit à changer.
	t.default_font = _fonte_texte
	var normal := StyleBoxFlat.new()
	# Sur du verre, un bouton n'est pas un aplat : c'est une plaque un peu plus
	# claire que le panneau, sinon il disparaît dans le fond flouté.
	normal.bg_color = Color8(255, 255, 255, 132)
	normal.border_color = Color8(255, 255, 255, 170)
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(9)
	normal.set_content_margin_all(9)
	normal.content_margin_left = 12
	normal.content_margin_right = 12
	var survol := normal.duplicate()
	survol.bg_color = Color8(180, 214, 248, 190)
	survol.border_color = Color(ACCENT_VIF, 0.85)
	# 🔧 Un réglage CHOISI est un azur pâle, pas l'azur plein : le seul azur
	# plein du jeu est le bouton qui engage la caisse (`_habiller_principal`),
	# et deux pleins côte à côte ne disent plus lequel paie.
	var presse := normal.duplicate()
	presse.bg_color = Color8(158, 203, 243, 235)
	presse.border_color = Color(ACCENT_VIF, 0.9)
	var inactif := normal.duplicate()
	inactif.bg_color = Color8(226, 234, 244, 90)
	inactif.border_color = Color8(255, 255, 255, 80)
	t.set_stylebox("normal", "Button", normal)
	t.set_stylebox("hover", "Button", survol)
	t.set_stylebox("pressed", "Button", presse)
	t.set_stylebox("hover_pressed", "Button", presse)
	t.set_stylebox("disabled", "Button", inactif)
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_color("font_color", "Button", TEXTE)
	t.set_color("font_hover_color", "Button", TEXTE)
	t.set_color("font_pressed_color", "Button", ACCENT.darkened(0.25))
	t.set_color("font_disabled_color", "Button", GRIS.lightened(0.15))
	t.set_font("font", "Button", _fonte_grasse)
	t.set_font_size("font_size", "Button", 14)
	t.set_constant("h_separation", "Button", 8)
	t.set_constant("icon_max_width", "Button", 30)
	var ligne := StyleBoxFlat.new()
	ligne.bg_color = Color(0, 0, 0, 0)
	ligne.border_color = Color8(140, 172, 206, 110)
	ligne.border_width_top = 1
	ligne.content_margin_top = 5
	ligne.content_margin_bottom = 5
	t.set_stylebox("separator", "HSeparator", ligne)
	return t


## 🔠 LA RÈGLE DES CAPITALES (auteur, 2026-09-20, après les captures) :
## **une capitale ÉTIQUETTE, elle ne nomme pas et elle ne parle pas.**
## Donc en capitales espacées et grasses : les étiquettes de données
## (SURFACE, NIVEAUX), les titres de bloc (DENSIFIER), le mois, les deux mots
## du rail. Jamais : un nom de lieu, un titre de page, une phrase, un bouton.
## Ce sont ces deux fonctions qui tiennent la règle — pas les chaînes.
func _etiquette(txt: String, taille: int, coul: Color) -> Label:
	var l := _label(txt.to_upper(), taille, coul)
	l.add_theme_font_override("font", _fonte_titre)
	return l


## L'autre moitié de la règle : ce qui NOMME. Casse normale, gras, plus grand.
func _titre(txt: String, taille: int, coul: Color) -> Label:
	var l := _label(txt, taille, coul)
	l.add_theme_font_override("font", _fonte_grasse)
	return l


## Le bandeau qui coiffe un panneau : filet azur à gauche, titre.
func _bandeau(parent: Control, txt: String) -> Label:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = FOND_FORT
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(7)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.border_width_left = 4
	sb.border_color = ACCENT_VIF
	p.add_theme_stylebox_override("panel", sb)
	parent.add_child(p)
	var l := _titre(txt, 15, ACCENT)
	p.add_child(l)
	return l


## Le titre d'un bloc DANS la fiche : un filet jaune, puis le mot. Plus léger
## qu'un bandeau, qui coifferait un panneau entier.
func _titre_section(parent: Control, txt: String) -> void:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 7)
	var filet := ColorRect.new()
	filet.color = ACCENT_VIF
	filet.custom_minimum_size = Vector2(3, 13)
	filet.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(filet)
	h.add_child(_etiquette(txt, 11, ACCENT))
	parent.add_child(h)


# ==========================================================================
# 🗂️ LA FICHE À ONGLETS (auteur, 2026-09-18)
# ==========================================================================

## 🔴 L'ORDRE EST CELUI DE LA PRIORITÉ, pas seulement celui de la rangée : le
## premier onglet disponible s'ouvre, donc un îlot sinistré s'ouvre sur la crue
## et un champ sur la campagne. Trois colonnes : l'identifiant, le dessin, le
## mot de l'infobulle — l'onglet n'affiche que l'icône.
## 🔴 L'ORTHOGRAPHE DES TISSUS, ET RIEN D'AUTRE : la chaîne les exporte sans
## accent (`ilot_compact`), et « ilot compact » sous le nom d'un lieu se lit
## comme une faute. La TABLE des tissus, elle, est du level design et reste
## dans `QGIS/scripts/`. À corriger à la main si un mot ne convient pas.
const TISSUS := {
	"maisons_de_ville": "maisons de ville",
	"coeur_ancien": "cœur ancien",
	"front_commercant": "front commerçant",
	"ilot_compact": "îlot compact",
	"place_minerale": "place minérale",
	"friche_industrielle": "friche industrielle",
	"jardins_familiaux": "jardins familiaux",
	"equipement": "équipement",
	"riviere": "rivière",
}


const ONGLETS := [
	["crue", "dangers", "Après la crue"],
	["campagne", "nourriture", "Campagne"],
	["bati", "logement", "Bâti"],
	["trafic", "trafic", "Voitures"],
	["berge", "eau", "Berge"],
	["energie", "energie", "Énergie"],
	["vert", "feuille", "Vert"],
]


## 🗂️ UNE TUILE : l'étiquette au-dessus, le nombre en dessous, tout collé à
## gauche. 🔄 REMPLACE LA GRILLE « étiquette à gauche, valeur à droite » : sur
## 310 px, « Toit ········ 0 m² » creusait un vide au milieu de chaque ligne,
## et c'est ce vide que l'auteur a refusé le 2026-09-18.
func _tuile(parent: GridContainer, etiquette: String, valeurs: Dictionary,
		cle: String) -> void:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 1)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(v)
	v.add_child(_etiquette(etiquette, 10, GRIS_FORT))
	var l := _label("", 14, TEXTE)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(l)
	valeurs[cle] = l


## La clé d'une grille est `onglet_couche` : « après la crue » ne dit pas la
## même chose d'un îlot et d'une rue.
func _grille_onglet(parent: Control, cle: String, colonnes: int,
		valeurs: Dictionary, lignes: Array) -> void:
	var g := GridContainer.new()
	g.columns = colonnes
	g.add_theme_constant_override("h_separation", 12)
	g.add_theme_constant_override("v_separation", 10)
	g.visible = false
	parent.add_child(g)
	for l in lignes:
		_tuile(g, l[1], valeurs, l[0])
	_onglet_grilles[cle] = g


func ouvrir_onglet(id: String) -> void:
	_onglet_actif = id
	_appliquer_onglets()
	_clamper_fiche()


## L'onglet ouvert est un verre plus dense sous un filet azur ; les autres sont
## transparents sur un trait clair. C'est le seul fond de la fiche qui dit « ici ».
func _habiller_onglet(b: Button, ouvert: bool, dessin: String) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = FOND_FORT if ouvert else Color(0, 0, 0, 0)
	sb.set_corner_radius_all(8)
	sb.corner_radius_bottom_left = 0
	sb.corner_radius_bottom_right = 0
	sb.set_content_margin_all(4)
	sb.border_width_bottom = 3
	sb.border_color = ACCENT_VIF if ouvert else Color(BORD, 0.55)
	var survol := sb.duplicate()
	survol.bg_color = Color(FOND_FORT, 0.6) if not ouvert else FOND_FORT
	for etat in ["normal", "pressed", "focus", "disabled"]:
		b.add_theme_stylebox_override(etat, sb)
	b.add_theme_stylebox_override("hover", survol)
	b.add_theme_stylebox_override("hover_pressed", survol)
	b.icon = _icone(dessin, 27, ACCENT if ouvert else GRIS)


## Ce que l'objet courant mérite comme onglets. Un onglet qui ne dirait rien
## n'existe pas : il ne se grise pas — un onglet gris est une porte fermée,
## une absence est une priorité.
func _calculer_dispo() -> Dictionary:
	var d := {}
	var fid := _fiche_fid
	if _fiche_couche == "i":
		var champ := ville.est_champ(fid)
		d["crue"] = bool(_bloc_dispo.get(_repare_bloc, false))
		d["campagne"] = champ
		d["bati"] = not champ
		d["energie"] = not _solaire_verrouille() 			and ville.valeur("i", fid, "_toit_equipable_m2", _mois) > 0.0
		d["vert"] = ville.valeur("i", fid, "_part_plate", _mois) > 0.001
	elif _fiche_couche == "r":
		d["crue"] = bool(_bloc_dispo.get(_repare_bloc, false))
		d["trafic"] = true
		d["vert"] = ville.arbres_plantables(fid) > 0
	elif _fiche_couche == "b":
		d["berge"] = true
	# 🏕️ PENDANT L'URGENCE, IL N'Y A QU'UN THÈME : reloger. C'est ce qui rend
	# un îlot bâti muet et oriente vers les champs sans les désigner.
	# 🌉 Puis un seul : la crue, sur un pont coupé ou une rue qui y mène.
	var verrou := _verrou()
	var garde: String = {"reloger": "campagne", "pont": "crue"}.get(verrou, "")
	var permis := verrou == "" or _autorise(_fiche_couche, fid)
	for id in d.keys():
		if not d[id] or not permis or (garde != "" and id != garde):
			d.erase(id)
	return d


## Ce qui s'affiche, une fois `_dispo` connu. Trois choses : les boutons, la
## grille de l'onglet ouvert, et les blocs de réglage rangés sous leur thème.
func _appliquer_onglets() -> void:
	# On GARDE l'onglet d'avant tant qu'il existe sur le nouvel objet : comparer
	# deux îlots sur l'énergie ne doit pas coûter un clic par îlot.
	if not _dispo.get(_onglet_actif, false):
		_onglet_actif = ""
		for ligne in ONGLETS:
			if _dispo.get(ligne[0], false):
				_onglet_actif = ligne[0]
				break
	for ligne in ONGLETS:
		var id: String = ligne[0]
		var b: Button = _onglet_boutons[id]
		b.visible = bool(_dispo.get(id, false))
		if b.visible:
			_habiller_onglet(b, id == _onglet_actif, ligne[1])
	# Un onglet seul n'est pas un choix : la rangée disparaît (la berge).
	_onglets.visible = _dispo.size() > 1
	var ouverte := "%s_%s" % [_onglet_actif, _fiche_couche]
	for cle in _onglet_grilles:
		(_onglet_grilles[cle] as Control).visible = cle == ouverte
	for bloc in _bloc_onglet:
		(bloc as Control).visible = bool(_bloc_dispo.get(bloc, false)) 			and String(_bloc_onglet[bloc]) == _onglet_actif


## 🔢 CE QUE L'OBJET REND, EN UNE LIGNE. Un îlot compte des logements, un champ
## des repas, une rue des voitures : une unité, jamais deux à la fois.
func _maj_resume(dessin: String, texte: String) -> void:
	if dessin != _resume_dessin:
		_resume_dessin = dessin
		_resume_icone.texture = _icone(dessin, 23, ACCENT)
	_resume_texte.text = texte
	_resume_ligne.visible = true


## 🔴 LA TABLE DES DESSINS EST HORS DE `_icone` depuis le 2026-09-17 : les
## pastilles posées sur la ville (`pastilles.gd`) y puisent pour fabriquer leur
## propre image, contour compris. Deux tables finiraient par diverger.
const DESSINS := {
	"ville": "<path d='M3 21h18M5 21V9h5v12M10 21V4h6v17M16 21v-9h4v9M7 12h1m-1 3h1m-1 3h1m5-11h1m-1 4h1m-1 4h1m4 0h1m-1 3h1'/>",
	"diagnostic": "<path d='M4 20h16M6 18v-6h3v6m3 0V6h3v12m3 0v-9h3v9'/>",
	"adaptation": "<path d='M12 3l7 3v5c0 5-3 8-7 10-4-2-7-5-7-10V6l7-3zM8 12c2-2 6-2 8 0m-8 3c2-2 6-2 8 0'/>",
	"reduction": "<path d='M20 4C10 4 5 9 5 15c0 3 2 5 5 5 7 0 10-8 10-16zM5 20c3-6 7-9 12-12'/>",
	"conso": "<path d='M13 2L5 14h6l-1 8 9-13h-6V2z'/>",
	"production": "<circle cx='12' cy='12' r='4'/><path d='M12 2v3m0 14v3M2 12h3m14 0h3M5 5l2 2m10 10l2 2M19 5l-2 2M7 17l-2 2'/>",
	"achat": "<path d='M9 3v7m6-7v7m-8 0h10v2a5 5 0 01-5 5v4m-3 0h6'/>",
	"co2": "<path d='M7 18h11a4 4 0 000-8 6 6 0 00-11-2 5 5 0 000 10z'/>",
	"caisse": "<circle cx='12' cy='12' r='9'/><path d='M15 8c-1-1-5-1-5 1 0 3 5 1 5 4 0 2-4 3-6 1m3-9v14'/>",
	"dangers": "<path d='M12 3L2 21h20L12 3zm0 6v5m0 3v1'/>",
	"chantiers": "<rect x='2' y='6' width='20' height='8' rx='1'/><path d='M17 14v7M7 14v7M17 3v3M7 3v3M10 14L2.3 6.3M14 6l7.7 7.7M8 6l8 8'/>",
	"energie": "<path d='M13 2L5 14h6l-1 8 9-13h-6V2z'/>",
	"trafic": "<path d='M5 17h14l-1-6-2-3H8l-2 3-1 6zm1 0v3m12-3v3M7 13h10M8 17h1m6 0h1'/>",
	"tissu": "<path d='M3 3h7v7H3zM14 3h7v7h-7zM3 14h7v7H3zM14 14h7v7h-7z'/>",
	# 🏛️🎓 Les deux lieux du rail (Lucide « landmark », « graduation-cap ») :
	# sans dessin, ils prenaient celui du diagnostic, deux fois.
	# Lucide « book-open » : DÉBUT rouvre le récit des premiers pas.
	"debut": "<path d='M12 7v14M3 18a1 1 0 01-1-1V4a1 1 0 011-1h5a4 4 0 014 4 4 4 0 014-4h5a1 1 0 011 1v13a1 1 0 01-1 1h-6a3 3 0 00-3 3 3 3 0 00-3-3z'/>",
	"mairie": "<path d='M3 22h18M6 18v-7m4 7v-7m4 7v-7m4 7v-7M12 2l8 5H4z'/>",
	"universite": "<path d='M21.42 10.922a1 1 0 00-.019-1.838L12.83 5.18a2 2 0 00-1.66 0L2.6 9.08a1 1 0 000 1.832l8.57 3.908a2 2 0 001.66 0zM22 10v6M6 12.5V16a6 3 0 0012 0v-3.5'/>",
	# 🗂️ LES TROIS DESSINS DES ONGLETS DE FICHE (auteur, 2026-09-18), repris de
	# Lucide (licence ISC) comme le reste de la table : même grille 24, même
	# trait. L'immeuble ne reprend pas « ville » — une silhouette de commune sur
	# la fiche d'UN îlot désignerait le mauvais objet.
	"logement": "<rect x='4' y='2' width='16' height='20' rx='2'/><path d='M9 22v-3a1 1 0 011-1h4a1 1 0 011 1v3'/><path d='M8 6h.01M12 6h.01M16 6h.01M8 10h.01M12 10h.01M16 10h.01M8 14h.01M12 14h.01M16 14h.01'/>",
	"feuille": "<path d='M11 20a10 10 0 0010-10 25.9 25.9 0 00-1.04-7.281 1 1 0 00-1.755-.325C15.833 5.5 13 5.5 9.8 6.1A7 7 0 0011 20'/><path d='M2 21a5 5 0 012.911-4.544C7.613 15.212 8.351 15.24 11 13'/>",
	"eau": "<path d='M2 6c.6.5 1.2 1 2.5 1 2.5 0 2.5-2 5-2 2.6 0 2.4 2 5 2 2.5 0 2.5-2 5-2 1.3 0 1.9.5 2.5 1'/><path d='M2 12c.6.5 1.2 1 2.5 1 2.5 0 2.5-2 5-2 2.6 0 2.4 2 5 2 2.5 0 2.5-2 5-2 1.3 0 1.9.5 2.5 1'/><path d='M2 18c.6.5 1.2 1 2.5 1 2.5 0 2.5-2 5-2 2.6 0 2.4 2 5 2 2.5 0 2.5-2 5-2 1.3 0 1.9.5 2.5 1'/>",
}


func _icone(nom: String, taille := 25, coul := TEXTE) -> Texture2D:
	var cle := "%s_%d_%s" % [nom, taille, coul.to_html(false)]
	if _icones.has(cle):
		return _icones[cle]
	# 🎨 `@` = LA COULEUR DU TRAIT : c'est ce qui permet un aplat (`fill='@'`)
	# dans une table qui est sinon tout en traits.
	var corps: String = str(DESSINS.get(nom, DESSINS["diagnostic"])) 		.replace("@", "#" + coul.to_html(false))
	var svg := "<svg xmlns='http://www.w3.org/2000/svg' width='24' height='24' viewBox='0 0 24 24' fill='none' stroke='#%s' stroke-width='2.0' stroke-linecap='round' stroke-linejoin='round'>%s</svg>" % [coul.to_html(false), corps]
	var img := Image.new()
	var erreur := img.load_svg_from_string(svg, float(taille) / 24.0)
	if erreur != OK:
		return null
	var texture := ImageTexture.create_from_image(img)
	_icones[cle] = texture
	return texture


## L'icône dans sa pastille teintée : c'est elle qui remplace le mot. Le fond
## reprend la couleur du compteur à 15 % — assez pour retrouver la caisse ou le
## CO₂ du coin de l'œil, trop peu pour concurrencer le nombre.
func _puce(nom: String, teinte: Color, taille := 26) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(teinte, 0.15)
	sb.set_corner_radius_all(9)
	sb.set_content_margin_all(6)
	p.add_theme_stylebox_override("panel", sb)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pic := TextureRect.new()
	pic.texture = _icone(nom, taille, teinte)
	pic.custom_minimum_size = Vector2(taille, taille)
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(pic)
	return p


## Tous les panneaux de détail occupent LA MÊME case, à droite du rail : ils se
## remplacent, ils ne s'empilent pas.
func _ancrer_detail(p: Control) -> void:
	p.offset_left = DETAIL_X
	p.offset_right = DETAIL_X + DETAIL_LARGEUR
	p.offset_top = HAUT


## Une tuile du rail : sombre, carrée, sans mot. L'azur de l'état enfoncé est
## le même que celui du bouton qui engage la caisse — un seul accent dans le jeu.
func _habiller_tuile_rail(b: Button) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = RAIL_TUILE
	normal.set_corner_radius_all(11)
	normal.set_content_margin_all(6)
	var survol := normal.duplicate() as StyleBoxFlat
	survol.bg_color = RAIL_SURVOL
	var presse := normal.duplicate() as StyleBoxFlat
	presse.bg_color = ACCENT_VIF
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", survol)
	b.add_theme_stylebox_override("pressed", presse)
	b.add_theme_stylebox_override("hover_pressed", presse)
	# ⚠️ Sans lui, le thème dessine un cadre pointillé autour de la mairie et
	# de l'université verrouillées : la tuile pâlit, elle ne change pas de forme.
	var eteint := normal.duplicate() as StyleBoxFlat
	eteint.bg_color = Color(RAIL_TUILE, 0.45)
	b.add_theme_stylebox_override("disabled", eteint)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	for etat in ["font_color", "font_hover_color", "icon_normal_color", "icon_hover_color"]:
		b.add_theme_color_override(etat, RAIL_ICONE)
	for etat in ["font_pressed_color", "font_hover_pressed_color", "icon_pressed_color",
			"icon_hover_pressed_color"]:
		b.add_theme_color_override(etat, Color.WHITE)
	b.add_theme_color_override("font_disabled_color", Color(RAIL_ICONE, 0.35))
	b.add_theme_color_override("icon_disabled_color", Color(RAIL_ICONE, 0.35))
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 54)


## Le curseur par défaut de Godot est un trait gris sans remplissage : on y lit
## une position, pas une quantité.
func _habiller_curseur(s: HSlider) -> void:
	var gouttiere := StyleBoxFlat.new()
	gouttiere.bg_color = Jauge.RESTE
	gouttiere.set_corner_radius_all(3)
	# ⚠️ Chez Slider, c'est la MARGE de la boîte qui fait l'épaisseur du rail :
	# il n'y a pas de hauteur à régler ailleurs.
	gouttiere.content_margin_top = 3.0
	gouttiere.content_margin_bottom = 3.0
	s.add_theme_stylebox_override("slider", gouttiere)

	var rempli := StyleBoxFlat.new()
	rempli.bg_color = Color(ACCENT_VIF, 0.75)
	rempli.set_corner_radius_all(3)
	rempli.content_margin_top = 3.0
	rempli.content_margin_bottom = 3.0
	s.add_theme_stylebox_override("grabber_area", rempli)
	s.add_theme_stylebox_override("grabber_area_highlight", rempli)

	var poignee := _pastille(ACCENT)
	s.add_theme_icon_override("grabber", poignee)
	s.add_theme_icon_override("grabber_highlight", poignee)
	s.add_theme_icon_override("grabber_disabled", _pastille(GRIS.darkened(0.4)))


static func _pastille(coul: Color) -> ImageTexture:
	var img := Image.create_empty(7, 20, false, Image.FORMAT_RGBA8)
	img.fill(coul)
	return ImageTexture.create_from_image(img)


func _label(txt: String, taille: int, coul: Color) -> Label:
	var l := Label.new()
	l.text = txt
	l.add_theme_font_size_override("font_size", taille)
	l.add_theme_color_override("font_color", coul)
	return l


## 🔄 LE BANDEAU DE NEUF TUILES EST DEVENU CE PANNEAU (2026-09-03) : il s'ouvre
## à côté du rail, sur l'icône VILLE. Une ligne = une pastille, une jauge, un
## nombre ; le mot est dans l'infobulle. Rien de neuf n'est mesuré — ce sont les
## sept mêmes chiffres, rangés.
func _panneau_bilan() -> void:
	var p := PanelContainer.new()
	p.theme = _theme_ui
	_poser_boite(p)
	_ancrer_detail(p)
	add_child(p)
	_ville_panneau = p

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 9)
	p.add_child(v)

	# 🔧 UNE TEINTE PAR COMPTEUR, et c'est ce qui distingue un tableau de bord
	# de jeu d'un tableau : on retrouve la caisse à la couleur, pas au mot.
	_titre_section(v, "Données")
	var adaptation := _ligne_bilan(v, "adaptation", Color8(46, 122, 146),
		"Adaptation — la part de la ville relevée après la crue.", true, "adaptation")
	_adaptation_jauge = adaptation["jauge"]
	_adaptation_valeur = adaptation["valeur"]
	_adaptation_pictos = adaptation["pictos"]
	var reduction := _ligne_bilan(v, "reduction", Color8(88, 128, 60),
		"Réduction — la part des émissions déjà évitées.", true, "reduction")
	_reduction_jauge = reduction["jauge"]
	_reduction_valeur = reduction["valeur"]
	_reduction_pictos = reduction["pictos"]

	_titre_section(v, "Énergie")
	for ligne in [
		["conso", "conso", Color8(198, 126, 32),
			"Ce que la ville consomme. La jauge se lit contre le mois 0."],
		["production", "production", Color8(214, 158, 44),
			"Ce que les panneaux produisent, sur la consommation de la ville."],
		["achat", "achat", Color8(122, 112, 96),
			"Ce qu'il faut encore acheter au réseau."],
		["co2", "co2", Color8(104, 116, 108),
			"Les émissions de l'électricité achetée. La jauge se lit contre le mois 0."],
	]:
		var l := _ligne_bilan(v, ligne[1], ligne[2], ligne[3], true)
		_ville_valeurs[ligne[0]] = l["valeur"]
		_ville_jauges[ligne[0]] = l["jauge"]

	# 🌾 LA CAMPAGNE EST UN COMPTEUR, PAS UN DÉCOR : c'est elle qui rend
	# visible le prix d'un logement posé sur un champ. La jauge ne remonte
	# jamais — un champ bâti ne se rend pas.
	_titre_section(v, "Campagne")
	var nourriture := _ligne_bilan(v, "nourriture", Color8(150, 128, 44),
		"Ce que les champs de Wehrau nourrissent, sur les 5 350 habitants. Bâtir un champ le retire pour de bon.", true)
	_ville_valeurs["nourriture"] = nourriture["valeur"]
	_ville_jauges["nourriture"] = nourriture["jauge"]

	_titre_section(v, "Caisse")
	# Pas de jauge : une caisse n'a pas de plein. Le nombre prend toute la
	# largeur, et la recette reste son petit écart, comme dans la référence.
	var caisse := _ligne_bilan(v, "caisse", Color8(78, 121, 67),
		"La caisse, et ce que le solaire lui rapporte chaque année.", false)
	_ville_valeurs["caisse"] = caisse["valeur"]
	(caisse["valeur"] as Label).add_theme_color_override("font_color", ACCENT)
	(caisse["valeur"] as Label).add_theme_font_size_override("font_size", 20)
	var recette := _label("", 11, Color8(78, 121, 67))
	recette.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	(caisse["colonne"] as VBoxContainer).add_child(recette)
	_ville_valeurs["recette"] = recette

	# 🧪 LE BOUTON D'ESSAI, ET IL DIT QU'IL EN EST UN. Il sert à atteindre en un
	# clic un état que vingt ans de dotation mettraient à payer — donc à juger
	# une ville équipée, pas à juger l'économie.
	# À retirer en même temps que `ville.crediter_essai_ke`.
	var triche := Button.new()
	triche.text = "Essai · +1 000 k€"
	triche.theme = _theme_ui
	triche.focus_mode = Control.FOCUS_NONE
	triche.add_theme_font_size_override("font_size", 11)
	triche.add_theme_color_override("font_color", GRIS)
	triche.tooltip_text = "Outil d'essai : remplit la caisse, hors règles du jeu."
	triche.pressed.connect(func() -> void:
		ville.crediter_essai_ke(1000.0)
		_message.text = "Essai : 1 000 k€ versés.")
	v.add_child(triche)
	triche.visible = "--outils" in OS.get_cmdline_user_args()


## Une ligne du bilan : la pastille dit QUOI, la jauge dit OÙ ON EN EST, le
## nombre dit COMBIEN. Les pastilles du dessous comptent la même part en jetons
## — c'est ce qui remplace la phrase qui traînait sous les deux jauges de climat.
func _ligne_bilan(parent: VBoxContainer, icone: String, teinte: Color,
		bulle: String, avec_jauge := true, pictos := "") -> Dictionary:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	h.tooltip_text = bulle
	# 🔴 La ligne est la SEULE à prendre la souris : sans ça l'infobulle
	# n'existe pas, et avec elle sur les enfants elle clignoterait.
	h.mouse_filter = Control.MOUSE_FILTER_STOP
	parent.add_child(h)
	h.add_child(_puce(icone, teinte))

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(col)

	var rang := HBoxContainer.new()
	rang.add_theme_constant_override("separation", 10)
	rang.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(rang)
	var jauge: Jauge = null
	if avec_jauge:
		jauge = Jauge.new()
		jauge.custom_minimum_size = Vector2(0, 10)
		jauge.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		jauge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		jauge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		jauge.colorer(teinte)
		rang.add_child(jauge)
	var valeur := _label("—", 15, TEXTE)
	valeur.add_theme_font_override("font", _fonte_grasse)
	valeur.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	# ⚠️ Sans jauge, le nombre prend la ligne ; avec, il garde 104 px fixes et
	# c'est la jauge qui s'étire — sinon les deux se partagent la place et
	# aucune colonne de nombres n'est alignée d'une ligne à l'autre.
	valeur.size_flags_horizontal = Control.SIZE_FILL if avec_jauge \
		else Control.SIZE_EXPAND_FILL
	valeur.custom_minimum_size.x = 104
	rang.add_child(valeur)

	var jetons: Pictos = null
	if pictos != "":
		jetons = Pictos.new()
		jetons.texture = _icone(pictos, 15, Color.WHITE)
		jetons.teinte = teinte
		jetons.custom_minimum_size = Vector2(0, 15)
		jetons.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_child(jetons)
	return {"valeur": valeur, "jauge": jauge, "pictos": jetons, "colonne": col}


# ============================================== LA DEUXIÈME VUE, ET SON MENU
#
# 🩶 La ville vivante d'un côté, le diagnostic de l'autre (2026-08-25). Le rail
# porte le choix, et un seul panneau de détail est ouvert à la fois : deux vues,
# jamais deux tableaux de bord à l'écran ensemble.


## 🔄 LA BARRE DU BAS EST DEVENUE UNE COLONNE À GAUCHE (2026-09-03) : icônes
## seules, mot en infobulle. Elle porte aussi les DEUX LIEUX (81) — mairie et
## université — qui étaient deux boutons de plus dans le bandeau du haut.
func _panneau_rail() -> void:
	_menu_panneau = PanelContainer.new()
	_menu_panneau.theme = _theme_ui
	var sb := StyleBoxFlat.new()
	sb.bg_color = RAIL_FOND
	sb.set_corner_radius_all(16)
	sb.set_content_margin_all(10)
	# La même ombre que les panneaux de verre : sans elle, le rail sombre est
	# un trou dans la ville au lieu d'un objet posé dessus.
	sb.shadow_color = Color(0.04, 0.09, 0.18, 0.40)
	sb.shadow_size = 12
	sb.shadow_offset = Vector2(0, 6)
	_menu_panneau.add_theme_stylebox_override("panel", sb)
	_menu_panneau.offset_left = RAIL_X
	_menu_panneau.offset_right = RAIL_X + RAIL_LARGEUR
	_menu_panneau.offset_top = HAUT
	add_child(_menu_panneau)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	_menu_panneau.add_child(v)

	# ⚠️ `allow_unpress` à false : sans lui, recliquer la vue active l'éteint
	# À L'ÉCRAN alors que la ville reste peinte — le rail mentirait. La
	# fermeture du panneau passe par `_sur_rail`, pas par le groupe.
	var groupe := ButtonGroup.new()
	groupe.allow_unpress = false

	# 🏙️ L'EN-TÊTE EST AUSSI LE BOUTON DE LA VILLE VIVANTE : azur quand on y est.
	var accueil := _tuile_rail("ville", "Ville",
		"Ville — retrouver la matière, les arbres et les voitures.")
	accueil.toggle_mode = true
	accueil.button_group = groupe
	accueil.pressed.connect(func() -> void: _sur_rail(""))
	v.add_child(accueil)
	_menu_boutons[""] = accueil

	for t in themes:
		var id := str(t["id"])
		var b := _tuile_rail(id, str(t.get("court", t["nom"])),
			"%s — %s" % [str(t["nom"]), str(t.get("resume", ""))])
		b.toggle_mode = true
		b.button_group = groupe
		b.pressed.connect(func() -> void: _sur_rail(id))
		v.add_child(b)
		_menu_boutons[id] = b

	# 🎓🏛️ LES DEUX PORTES PERMANENTES (81) : un menu s'ouvre sans aller sur
	# place. L'autre porte est le bouton de la fiche d'îlot ; le lieu est un
	# raccourci, jamais le seul chemin. Hors du groupe — un lieu n'est pas une
	# vue : il ouvre une fiche à droite et ne repeint pas la ville.
	v.add_child(_filet_rail())
	for lieu in LIEUX_ORDRE:
		var cle: String = lieu
		var b := _tuile_rail(cle, String(LIEUX[cle]["court"]), "%s (îlot %d) — %s" % [String(LIEUX[cle]["nom"]),
			int(LIEUX[cle]["fid"]), String(LIEUX[cle]["quoi"])])
		b.pressed.connect(func() -> void: ouvrir_lieu(cle))
		v.add_child(b)
		_rail_lieux.append(b)
	accueil.set_pressed_no_signal(true)
	v.add_child(_filet_rail())
	var debut := _tuile_rail("debut", "Début", "Revoir les premiers pas après la crue.")
	_debut = debut
	debut.pressed.connect(func() -> void:
		if ouverture != null:
			var ouvrir: bool = not ouverture.visible
			theme_demande.emit("")
			_detail_ouvert = false
			_placer_detail()
			ouverture.ouvert = ouvrir
			ouverture.actualiser(true))
	v.add_child(debut)


## 🔄 L'ICÔNE ET SON MOT (auteur, 2026-09-24) : toutes les tuiles ont la même
## taille, le même dessin au-dessus, la même étiquette en capitales dessous —
## VILLE et DÉBUT ne sont plus des mots seuls au milieu des icônes.
func _tuile_rail(icone: String, mot: String, bulle: String) -> Button:
	var b := Button.new()
	# Dessin BLANC : ce sont les couleurs d'état du bouton qui le teintent.
	b.icon = _icone(icone, 24, Color.WHITE)
	b.expand_icon = false
	b.text = mot.to_upper()
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	b.add_theme_font_override("font", _fonte_titre)
	b.add_theme_font_size_override("font_size", 10)
	b.add_theme_constant_override("h_separation", 3)
	b.tooltip_text = bulle
	_habiller_tuile_rail(b)
	return b


## Le trait qui sépare les vues des lieux : sans lui, sept tuiles identiques
## laissent croire que la mairie repeint la ville.
func _filet_rail() -> Control:
	# `trait` est un mot réservé de GDScript : ne pas renommer la variable.
	var filet := ColorRect.new()
	filet.color = Color(RAIL_ICONE, 0.22)
	filet.custom_minimum_size = Vector2(0, 1)
	filet.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return filet


## 🔴 LE SEUL ENDROIT OÙ LE PANNEAU SE FERME. `maquette._sur_theme` sort tout de
## suite quand le thème ne change pas, donc recliquer l'icône active ne
## rappellerait jamais `montrer_theme` : c'est ici, et pas là-bas.
func _sur_rail(id: String) -> void:
	if id == _theme_courant:
		_detail_ouvert = not _detail_ouvert
		_placer_detail()
		return
	_detail_ouvert = true
	theme_demande.emit(id)


## Un seul panneau de détail à l'écran, et il tombe par le `genre` du thème —
## un thème neuf n'écrit rien de plus ici.
func _placer_detail() -> void:
	var genre := str(_theme_actuel.get("genre", ""))
	if _theme_courant == "" and _bilan_differe():
		_detail_ouvert = false
	_ville_panneau.visible = _detail_ouvert and _theme_courant == ""
	_diagnostic_panneau.visible = _detail_ouvert and genre == "crue"
	_chantiers_panneau.visible = _detail_ouvert and genre == "chantiers"
	_calque_panneau.visible = _detail_ouvert and (genre == "calque" or genre == "tissu")
	if ouverture != null:
		ouverture.visible = ouverture.ouvert and not _detail_ouvert


## Les données générales attendent la fin de la découverte du premier pont.
func _bilan_differe() -> bool:
	return ouverture != null and not ouverture.pont_termine \
		and not ouverture.suite and not ouverture.termine


## Le panneau des thèmes CONTINUS — énergie, trafic — et du tissu. Un thème
## neuf n'écrit rien de plus : il tombe ici par son `genre`.
func _panneau_calque() -> void:
	_calque_panneau = PanelContainer.new()
	_calque_panneau.theme = _theme_ui
	_poser_boite(_calque_panneau)
	_ancrer_detail(_calque_panneau)
	_calque_panneau.visible = false
	add_child(_calque_panneau)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	_calque_panneau.add_child(v)
	_entetes["_calque"] = _entete(v)
	v.add_child(HSeparator.new())
	_calque_barre = TextureRect.new()
	_calque_barre.custom_minimum_size = Vector2(0, 13)
	_calque_barre.stretch_mode = TextureRect.STRETCH_SCALE
	_calque_barre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(_calque_barre)
	var h := HBoxContainer.new()
	_calque_bas = _label("", 12, GRIS)
	h.add_child(_calque_bas)
	_calque_haut = _label("", 12, GRIS)
	_calque_haut.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_calque_haut.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(_calque_haut)
	v.add_child(h)
	_calque_note = _label("", 11, GRIS)
	_calque_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_calque_note)


func _entete(parent: VBoxContainer) -> Array:
	var titre := _bandeau(parent, "")
	var resume := _label("", 18, TEXTE)
	parent.add_child(resume)
	return [titre, resume]


func _ecrire_entete(e: Array, t: Dictionary) -> void:
	(e[0] as Label).text = str(t["nom"])
	(e[1] as Label).text = str(t.get("resume", ""))


## La rampe des thèmes continus, dessinée une fois. ⚠ En sRGB : `maquette`
## convertit en linéaire pour le SHADER, jamais pour l'interface.
func _texture_rampe() -> Texture2D:
	var g := Gradient.new()
	var pos := PackedFloat32Array()
	var teintes := PackedColorArray()
	for i in rampe.size():
		pos.append(float(i) / maxf(1.0, float(rampe.size() - 1)))
		teintes.append(rampe[i])
	g.offsets = pos
	g.colors = teintes
	var t := GradientTexture1D.new()
	t.gradient = g
	t.width = 256
	return t


## L'unique entrée de la deuxième vue : `maquette` dit quel thème, l'interface
## en tire tout le reste. `id` vide = la ville vivante.
func montrer_theme(id: String, t: Dictionary) -> void:
	_theme_courant = id
	_theme_actuel = t
	# Changer de vue rouvre le panneau : on vient de demander à voir quelque
	# chose, et le refermer serait exactement le contraire du clic.
	_detail_ouvert = true
	# Les deux lieux sont dans le rail mais hors du groupe : ils n'ont pas de
	# bascule, donc pas d'état à remettre.
	for vue in _menu_boutons:
		var b := _menu_boutons[vue] as Button
		if b.toggle_mode:
			b.set_pressed_no_signal(vue == id)
	_placer_detail()
	var genre := str(t.get("genre", ""))
	if id != "":
		var cle := "_calque" if _calque_panneau.visible else id
		_ecrire_entete(_entetes[cle], t)
	if _calque_panneau.visible:
		_calque_note.text = str(t.get("note", ""))
		_calque_note.visible = _calque_note.text != ""
		# Le tissu n'a pas d'échelle : une teinte par sous_type, donc ni rampe
		# ni bornes. C'est la seule différence entre les deux genres ici.
		var continu := genre == "calque"
		if continu and _calque_barre.texture == null:
			_calque_barre.texture = _texture_rampe()
		_calque_barre.visible = continu
		_calque_bas.visible = continu
		_calque_haut.visible = continu
		_calque_bas.text = str(t.get("bas", ""))
		_calque_haut.text = str(t.get("haut", ""))


func _panneau_diagnostic() -> void:
	_diagnostic_panneau = PanelContainer.new()
	_diagnostic_panneau.theme = _theme_ui
	_poser_boite(_diagnostic_panneau)
	_ancrer_detail(_diagnostic_panneau)
	_diagnostic_panneau.visible = false
	add_child(_diagnostic_panneau)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	_diagnostic_panneau.add_child(v)
	_entetes["dangers"] = _entete(v)
	v.add_child(HSeparator.new())
	_legende(v, Color8(38, 157, 196), "Passage de la crue · sols et rues noyés")
	_legende(v, Color8(232, 126, 48), "Bâtiments touchés · sinistrés ou ruinés")
	_legende(v, Color8(220, 58, 48), "Routes bloquées · franchissements coupés")
	v.add_child(HSeparator.new())
	# 🔧 CE QUE LA CRUE COÛTE ENCORE. Ces trois nombres BAISSENT quand on
	# répare : sans eux, reconstruire un îlot ne changerait rien de visible
	# ailleurs que sur cet îlot, et la décision n'aurait pas de contrepartie.
	# 🌊 Le quatrième regarde DEVANT, et c'est le seul que la berge déplace.
	for ligne in [
		["logements", "Logements perdus"],
		["ponts", "Franchissements coupés"],
		["reste", "Reste à réparer"],
		["eau", "La prochaine crue, au pire"],
	]:
		var h := HBoxContainer.new()
		h.add_child(_label(ligne[1], 12, GRIS))
		var val := _label("—", 14, TEXTE)
		val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		val.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(val)
		_degats_valeurs[ligne[0]] = val
		v.add_child(h)


func _legende(parent: VBoxContainer, couleur: Color, texte: String) -> void:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	var carre := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = couleur
	sb.set_corner_radius_all(4)
	carre.add_theme_stylebox_override("panel", sb)
	carre.custom_minimum_size = Vector2(15, 15)
	carre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(carre)
	h.add_child(_label(texte, 12, TEXTE))
	parent.add_child(h)


# ===================================================== la ville en travaux
#
# 🔧 CE QUE LE THÈME « DANGERS » NE DIT PAS. Lui montre ce que l'eau A PRIS,
# une fois pour toutes ; celui-ci montre l'état COURANT — ce qui est encore
# cassé, ce qui est en travaux, ce qui est fait.

## Six chantiers listés, le septième dit combien débordent. Au-delà, le
## panneau couvrirait la ville qu'il commente.
const CHANTIERS_LIGNES := 7


func _panneau_chantiers() -> void:
	_chantiers_panneau = PanelContainer.new()
	_chantiers_panneau.theme = _theme_ui
	_poser_boite(_chantiers_panneau)
	_ancrer_detail(_chantiers_panneau)
	_chantiers_panneau.visible = false
	add_child(_chantiers_panneau)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	_chantiers_panneau.add_child(v)
	_entetes["chantiers"] = _entete(v)
	v.add_child(HSeparator.new())
	_legende(v, CASSE, "Cassé · rien d'engagé")
	_legende(v, EN_TRAVAUX, "Chantier en cours")
	_legende(v, FAIT, "Fait · la ville est réparée là")
	v.add_child(HSeparator.new())
	for ligne in [
		["casses", "Encore cassé"],
		["reste", "Reste à payer"],
		["en_cours", "Chantiers en cours"],
		["faits", "Chantiers finis"],
	]:
		var h := HBoxContainer.new()
		h.add_child(_label(ligne[1], 12, GRIS))
		var val := _label("—", 14, TEXTE)
		val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		val.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(val)
		_chantiers_valeurs[ligne[0]] = val
		v.add_child(h)
	v.add_child(HSeparator.new())
	# Les lignes sont créées UNE fois et remplies ensuite : bâtir des Labels à
	# chaque image ferait tomber la maquette pour un panneau de texte.
	for i in CHANTIERS_LIGNES:
		var l := _label("", 12, TEXTE)
		l.visible = false
		_chantiers_lignes.append(l)
		v.add_child(l)


## ⚠️ Appelé seulement quand le panneau est ouvert : `ville.chantiers` parcourt
## les 69 îlots et les 178 tronçons, et ce serait une troisième traversée par
## image pour un panneau que personne ne regarde.
func maj_chantiers(d: Dictionary) -> void:
	var g: Dictionary = d["casses_par_genre"]
	(_chantiers_valeurs["casses"] as Label).text = "%d îlots · %d ponts · %d rues" % [
		int(g["reconstruction"]), int(g["pont"]), int(g["deblaiement"])]
	(_chantiers_valeurs["reste"] as Label).text = _milliers(
		float(d["reste_ke"])) + " k€"
	var liste: Array = d["en_cours"]
	(_chantiers_valeurs["en_cours"] as Label).text = "%d" % liste.size()
	(_chantiers_valeurs["faits"] as Label).text = "%d" % int(d["faits"])
	for i in _chantiers_lignes.size():
		var texte := ""
		if liste.is_empty():
			texte = "Aucun chantier en cours." if i == 0 else ""
		elif i == CHANTIERS_LIGNES - 1 and liste.size() > CHANTIERS_LIGNES:
			texte = "… et %d de plus" % (liste.size() - i)
		elif i < liste.size():
			texte = _ligne_chantier(liste[i])
		var l: Label = _chantiers_lignes[i]
		if l.text != texte:
			l.text = texte
		l.visible = texte != ""


## Le même nom que la fiche pour retrouver un chantier dans la ville.
func _ligne_chantier(c: Dictionary) -> String:
	var genre: String = {"pont": "tablier", "deblaiement": "déblaiement",
		"solaire": "panneaux", "berge": "transformation"}.get(c["genre"], c["genre"])
	return "%s · %s · encore %s" % [lieux.nom(c["couche"], int(c["fid"])), genre,
		_duree(float(c["reste_mois"]))]


## 🔄 RETOUR EN ARRIÈRE SIGNALÉ, 2026-08-25 : la fiche se retirait dès qu'un
## panneau du haut s'ouvrait. Elle reste maintenant dans LES DEUX VUES — c'est
## elle qui porte les décisions, et le diagnostic ne change que ce qu'on voit.
## ⚠️ Elle croise le panneau de thème en dessous de ~1 100 px de large.
func _panneau_ilot() -> void:
	var p := PanelContainer.new()
	_fiche_panneau = p
	p.theme = _theme_ui
	_poser_boite(p)
	p.anchor_left = 1.0
	p.anchor_right = 1.0
	p.offset_left = -336
	p.offset_right = -16
	# 🔄 Remontée à 14 px le 2026-09-03 : le bandeau de tuiles qui l'écartait
	# du haut n'existe plus.
	p.offset_top = HAUT
	p.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	add_child(p)

	# 🔴 LA FICHE DÉFILE, sinon son bouton d'engagement sort de l'écran : sept
	# réglages, le récapitulatif et la miniature dépassent 900 px de haut. Elle
	# épouse son contenu tant qu'il tient, et ne défile qu'au-delà (`_clamper`).
	var defil := ScrollContainer.new()
	defil.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	p.add_child(defil)
	_fiche_defilement = defil

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	defil.add_child(v)
	_fiche_contenu = v
	v.minimum_size_changed.connect(_clamper_fiche)
	get_viewport().size_changed.connect(_clamper_fiche)
	_fiche_titre = _bandeau(v, "Sélection")
	# Le type se lit sous le nom, jamais dans les chiffres : « champ »,
	# « habitat collectif », « voie de desserte » sont une identité, pas une
	# mesure — et à cette place ils ne prennent aucune ligne de tuile.
	_fiche_soustitre = _label("", 12, GRIS)
	_fiche_soustitre.visible = false
	v.add_child(_fiche_soustitre)

	# 🎓🏛️ LA DEUXIÈME PORTE (81), et elle ne change rien à la fiche : celle-ci
	# reste la fiche de L'ÎLOT — surface, logements, toits, curseurs. Le menu
	# est une autre fiche, qui prend la place de celle-ci.
	_lieu_bouton = Button.new()
	_lieu_bouton.visible = false
	_lieu_bouton.theme = _theme_ui
	_lieu_bouton.focus_mode = Control.FOCUS_NONE
	_lieu_bouton.pressed.connect(func() -> void:
		ouvrir_lieu(String(_lieu_du_fid(_fiche_fid))))
	v.add_child(_lieu_bouton)

	# 🔎 AVANT / APRÈS (2026-08-31). La miniature est la seule image où les deux
	# états d'un même objet peuvent se comparer : la ville, elle, ne peut montrer
	# que celui du jour. Deux boutons plutôt qu'un rideau ou une bascule
	# automatique — on s'arrête sur le détail qu'on veut regarder.
	_apercu_boutons = HBoxContainer.new()
	_apercu_boutons.add_theme_constant_override("separation", 4)
	_apercu_boutons.visible = false
	v.add_child(_apercu_boutons)
	for choix in [["Avant", true], ["Après", false]]:
		var b := Button.new()
		b.text = choix[0]
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var avant: bool = choix[1]
		b.pressed.connect(func() -> void: _apercu_avant = avant)
		_apercu_boutons.add_child(b)
		if avant:
			_avant_bouton = b
		else:
			_apres_bouton = b

	# 🔎 LA MINIATURE (décision 12). Elle montre l'objet dans l'état qui SERA
	# livré — le réglage suit le curseur avant même d'être validé — pendant que
	# la ville derrière garde son état réel.
	_apercu_cadre = PanelContainer.new()
	var fond := StyleBoxFlat.new()
	# Du papier, pas une lucarne noire : la miniature a un fond transparent et
	# l'objet s'y pose comme sur le reste de la fiche.
	# 🔄 SANS FILET depuis le 2026-08-28 : le trait fermait la miniature comme
	# une vignette collée, au lieu de la laisser être un dessin sur la page.
	fond.bg_color = FOND_FORT
	fond.set_corner_radius_all(6)
	_apercu_cadre.add_theme_stylebox_override("panel", fond)
	_apercu_cadre.visible = false
	v.add_child(_apercu_cadre)
	var vue := TextureRect.new()
	vue.texture = apercu
	# 🔴 `EXPAND_IGNORE_SIZE` : sans lui le rectangle EXIGE la taille de sa
	# texture — rendue trois fois plus grande — et la miniature déborde la fiche
	# au lieu d'y être réduite.
	vue.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	vue.custom_minimum_size = Vector2(0, Apercu.TAILLE.y)
	# ⚠️ Sans ça, la miniature avale les clics destinés à la ville derrière.
	vue.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vue.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_apercu_cadre.add_child(vue)

	# 🔧 L'AVANCEMENT, SOUS LA MINIATURE : celle-ci montre l'objet LIVRÉ, la
	# barre dit combien il reste à attendre avant que la ville le montre aussi.
	# Ambre de la vue chantiers : la même chose se dit de la même couleur.
	_chantier_bloc = VBoxContainer.new()
	_chantier_bloc.add_theme_constant_override("separation", 2)
	_chantier_bloc.visible = false
	v.add_child(_chantier_bloc)
	var chantier_ligne := HBoxContainer.new()
	_chantier_bloc.add_child(chantier_ligne)
	_chantier_quoi = _label("Chantier", 11, ACCENT)
	_chantier_quoi.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chantier_ligne.add_child(_chantier_quoi)
	_chantier_reste = _label("", 12, GRIS)
	_chantier_reste.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	chantier_ligne.add_child(_chantier_reste)
	_chantier_jauge = Jauge.new()
	_chantier_jauge.custom_minimum_size = Vector2(0, 9)
	_chantier_jauge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_chantier_jauge.colorer(EN_TRAVAUX)
	_chantier_bloc.add_child(_chantier_jauge)

	_fiche_vide = _label("Cliquez un îlot.", 13, GRIS)
	_fiche_vide.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_fiche_vide)

	# 🔢 LA LIGNE DU HAUT : UN SEUL CHIFFRE, celui qui dit ce que l'objet rend —
	# des logements, des repas, des voitures (auteur, 2026-09-18). Tout le reste
	# est rangé dans les onglets du dessous.
	_resume_ligne = HBoxContainer.new()
	_resume_ligne.add_theme_constant_override("separation", 9)
	_resume_ligne.visible = false
	v.add_child(_resume_ligne)
	_resume_icone = TextureRect.new()
	_resume_icone.custom_minimum_size = Vector2(23, 23)
	_resume_icone.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	_resume_icone.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_resume_ligne.add_child(_resume_icone)
	_resume_texte = _label("", 16, TEXTE)
	_resume_texte.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_resume_texte.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_resume_ligne.add_child(_resume_texte)

	# 🗂️ LA RANGÉE D'ONGLETS. Une icône, pas un mot : cinq mots ne tiennent pas
	# sur 310 px, et le mot revient dans l'infobulle. L'ordre de `ONGLETS` est
	# aussi l'ordre de PRIORITÉ — c'est lui qui décide lequel s'ouvre en premier,
	# donc la crue passe avant l'énergie.
	_onglets = HBoxContainer.new()
	_onglets.add_theme_constant_override("separation", 4)
	_onglets.visible = false
	v.add_child(_onglets)
	for ligne in ONGLETS:
		var b := Button.new()
		b.tooltip_text = ligne[2]
		b.focus_mode = Control.FOCUS_NONE
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, 40)
		var id: String = ligne[0]
		b.pressed.connect(func() -> void: ouvrir_onglet(id))
		_onglets.add_child(b)
		_onglet_boutons[id] = b

	# 🗂️ LES GRILLES DE TUILES, une par onglet ET par couche : « après la crue »
	# ne dit pas la même chose d'un îlot et d'une rue, « vert » non plus. La clé
	# est `onglet_couche`, et c'est elle qui décide laquelle s'affiche.
	# 🔴 AUCUNE TUILE NE REPÈTE LA LIGNE DU HAUT : les logements et les repas y
	# sont déjà, et deux fois le même nombre à deux lignes d'écart se lit comme
	# deux nombres. La rive est ici parce qu'elle décide qui peut atteindre le
	# champ une fois les ponts coupés.
	_grille_onglet(v, "bati_i", 3, _fiche_valeurs, [
		["surface", "Surface"], ["niveaux", "Niveaux"], ["emplois", "Emplois"]])
	_grille_onglet(v, "campagne_i", 2, _fiche_valeurs, [
		["surface_champ", "Surface"], ["rive", "Rive"]])
	_grille_onglet(v, "energie_i", 3, _fiche_valeurs, [
		["conso", "Conso./an"], ["production", "Solaire/an"], ["retour", "Retour"]])
	# 🌿 La part PLATE se lit ici et nulle part ailleurs : c'est elle qui décide
	# si l'onglet vert existe sur cet îlot.
	_grille_onglet(v, "vert_i", 3, _fiche_valeurs, [
		["toit", "Toit"], ["plat", "Dont plat"], ["verdi", "Verdi"]])
	_grille_onglet(v, "crue_i", 2, _fiche_valeurs, [
		["perdus", "Logements perdus"], ["detruits", "Bâtiments détruits"],
		["annonce", "Crue annoncée"], ["reprise", "Reprise annoncée"]])

	# 🔧 LA FICHE D'UNE RUE. La hiérarchie est passée sous le nom, la charge dans
	# la ligne de résumé : il ne reste ici que ce qu'une décision consomme.
	_grille_onglet(v, "trafic_r", 2, _rue_valeurs, [
		["largeur", "Largeur"], ["places", "Places"]])
	_grille_onglet(v, "vert_r", 2, _rue_valeurs, [
		["arbres", "Arbres"], ["canopee", "Canopée"]])
	_grille_onglet(v, "crue_r", 1, _rue_valeurs, [["etat", "Après la crue"]])

	# 🌊 LA FICHE D'UNE BERGE. 🔄 Le nombre qui portait la décision était les m²
	# d'asphalte posés au-dessus de l'Ilse ; il est tombé à ~0 le 2026-08-31,
	# quand le corridor des rues de berge est passé sur la terre. Ce qui reste
	# à montrer, c'est la RIVE : les mètres de quai entre la chaussée et l'eau.
	# Le bief se lit en îlots, pas en fil d'eau : « 7 îlots » décide, « 0,31 à
	# 0,61 » n'est qu'une coordonnée.
	_grille_onglet(v, "berge_b", 2, _berge_valeurs, [
		["mur", "Mur de quai"], ["rive", "Rive minérale"],
		["rues", "Voies portées"], ["crue", "Crue au pire"],
		["etat", "État"], ["bief", "Bief"]])

	# 🔴 DEUX BOUTONS, PAS TROIS : l'asphalte est l'état de départ et on n'y
	# revient pas. Démolir un mur de quai est irréversible dans le jeu comme
	# sur le terrain — c'est ce qui donne son poids à la décision.
	_berge_bloc = VBoxContainer.new()
	_berge_bloc.add_theme_constant_override("separation", 6)
	_berge_bloc.visible = false
	v.add_child(_berge_bloc)
	_berge_bloc.add_child(HSeparator.new())
	_berge_texte = _label("", 12, TEXTE)
	_berge_texte.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_berge_bloc.add_child(_berge_texte)
	for cible in [Ville.BERGE_APAISEE, Ville.BERGE_RENATUREE]:
		var b := Button.new()
		# Exclusives : une berge n'a qu'un état visé. Reposer le même l'enlève.
		b.pressed.connect(func() -> void: _basculer("berge", cible))
		_berge_bloc.add_child(b)
		_berge_boutons.append(b)

	# 🔧 LE BLOC DE RÉPARATION, le même pour un îlot et pour une rue.
	_repare_bloc = VBoxContainer.new()
	_repare_bloc.add_theme_constant_override("separation", 6)
	_repare_bloc.visible = false
	v.add_child(_repare_bloc)
	_repare_bloc.add_child(HSeparator.new())
	_titre_section(_repare_bloc, "Crue")
	_repare_texte = _label("", 12, TEXTE)
	_repare_texte.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_repare_bloc.add_child(_repare_texte)
	_repare_bouton = Button.new()
	_repare_bouton.pressed.connect(func() -> void: _basculer("reparer", true))
	_repare_provisoire = Button.new()
	_repare_provisoire.visible = false
	_repare_provisoire.pressed.connect(func() -> void: _basculer("reparer", "provisoire"))
	_repare_bloc.add_child(_repare_provisoire)
	_repare_bloc.add_child(_repare_bouton)
	_acces_boutons = VBoxContainer.new()
	_repare_bloc.add_child(_acces_boutons)

	# 🏕️ ACCUEILLIR LES SINISTRÉS. Le bloc n'existe que sur un champ, et il ne
	# dit jamais non : un champ que personne ne peut atteindre se pose quand
	# même, avec l'avertissement au-dessus du bouton (auteur, 2026-09-17).
	_camp_bloc = VBoxContainer.new()
	_camp_bloc.add_theme_constant_override("separation", 6)
	_camp_bloc.visible = false
	v.add_child(_camp_bloc)
	_camp_bloc.add_child(HSeparator.new())
	_titre_section(_camp_bloc, "Relogement")
	_camp_texte = _label("", 12, TEXTE)
	_camp_texte.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_camp_bloc.add_child(_camp_texte)
	_camp_bouton = Button.new()
	_camp_bouton.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_camp_bouton.pressed.connect(func() -> void: _basculer("camp", true))
	_camp_bloc.add_child(_camp_bouton)

	_trafic_bloc = VBoxContainer.new()
	_trafic_bloc.add_theme_constant_override("separation", 6)
	_trafic_bloc.visible = false
	v.add_child(_trafic_bloc)
	_trafic_bloc.add_child(HSeparator.new())
	_titre_section(_trafic_bloc, "Voitures")
	_trafic_stationnement = Button.new()
	_trafic_stationnement.text = "Retirer les places"
	_trafic_stationnement.icon = _icone("trafic", 22)
	_trafic_stationnement.pressed.connect(func() -> void: _basculer("places", true))
	_trafic_bloc.add_child(_trafic_stationnement)
	_trafic_axe = Button.new()
	_trafic_axe.text = "Fermer aux voitures"
	_trafic_axe.pressed.connect(func() -> void: _basculer("axe", true))
	_trafic_bloc.add_child(_trafic_axe)

	# 🌳 PLANTER. Le curseur compte des ARBRES, pas des pourcents : c'est ce
	# qu'on paie et c'est exactement ce qui apparaît à l'écran. Il est ici et
	# pas sur l'îlot parce qu'un îlot bâti n'a pas de sol visible sous lui —
	# 8,78 ha de canopée que la maquette de masses ne peut pas dessiner.
	_arbres_bloc = VBoxContainer.new()
	_arbres_bloc.add_theme_constant_override("separation", 6)
	_arbres_bloc.visible = false
	v.add_child(_arbres_bloc)
	_arbres_bloc.add_child(HSeparator.new())
	_titre_section(_arbres_bloc, "Arbres")
	_arbres_valeur = _label("", 13, TEXTE)
	_arbres_valeur.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_arbres_bloc.add_child(_arbres_valeur)
	_arbres_jauge = Jauge.new()
	_arbres_jauge.custom_minimum_size = Vector2(0, 15)
	_arbres_jauge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_arbres_jauge.colorer(FAIT)
	_arbres_bloc.add_child(_arbres_jauge)
	_arbres_curseur = HSlider.new()
	# Échelle fixe 0 → tous les emplacements, même raison que le solaire : un
	# même pixel doit garder son sens d'un bout à l'autre de la partie.
	_arbres_curseur.min_value = 0.0
	_arbres_curseur.max_value = 100.0
	_arbres_curseur.step = 1.0
	_arbres_curseur.focus_mode = Control.FOCUS_NONE
	_habiller_curseur(_arbres_curseur)
	_arbres_curseur.value_changed.connect(_sur_curseur_arbres)
	_arbres_bloc.add_child(_arbres_curseur)

	_solaire_bloc = VBoxContainer.new()
	_solaire_bloc.add_theme_constant_override("separation", 6)
	_solaire_bloc.visible = false
	v.add_child(_solaire_bloc)
	_solaire_bloc.add_child(HSeparator.new())
	_titre_section(_solaire_bloc, "Solaire")
	_solaire_valeur = _label("", 13, TEXTE)
	_solaire_bloc.add_child(_solaire_valeur)

	# La lecture d'abord, le réglage ensuite. L'une est pleine et muette,
	# l'autre a une poignée : elles ne se ressemblent pas.
	_solaire_jauge = Jauge.new()
	_solaire_jauge.custom_minimum_size = Vector2(0, 15)
	_solaire_jauge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_solaire_bloc.add_child(_solaire_jauge)

	_solaire_curseur = HSlider.new()
	# 🔴 Échelle FIXE 0→100. Monter `min_value` avec la pose faisait changer un
	# même pixel de sens en cours de partie ; le plancher se tient par un
	# rattrapage dans `_sur_curseur`.
	_solaire_curseur.min_value = 0.0
	_solaire_curseur.max_value = 100.0
	_solaire_curseur.step = 1.0
	# ⚠️ Sinon le curseur garde le focus après un clic et AVALE les flèches :
	# la caméra ne tourne plus tant qu'on n'a pas cliqué ailleurs.
	_solaire_curseur.focus_mode = Control.FOCUS_NONE
	_habiller_curseur(_solaire_curseur)
	_solaire_curseur.value_changed.connect(_sur_curseur)
	_solaire_bloc.add_child(_solaire_curseur)

	# 🌿 LE MÊME TOIT, L'AUTRE USAGE. Bloc jumeau du solaire, à trois détails
	# près : il ne rapporte rien, il est borné par la part plate du toit, et son
	# effet est celui de TOUTE la ville — d'où le total affiché en dessous.
	_vert_bloc = VBoxContainer.new()
	_vert_bloc.add_theme_constant_override("separation", 6)
	_vert_bloc.visible = false
	v.add_child(_vert_bloc)
	_vert_bloc.add_child(HSeparator.new())
	_titre_section(_vert_bloc, "Toits verts")
	_vert_valeur = _label("", 13, TEXTE)
	_vert_valeur.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_vert_bloc.add_child(_vert_valeur)
	_vert_jauge = Jauge.new()
	_vert_jauge.custom_minimum_size = Vector2(0, 15)
	_vert_jauge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vert_jauge.colorer(FAIT)
	_vert_bloc.add_child(_vert_jauge)
	_vert_curseur = HSlider.new()
	# 🔴 Échelle FIXE 0→100, la même que le solaire, et c'est tout le propos :
	# les deux curseurs mesurent LE MÊME toit, donc le même pixel dit la même
	# surface. Les plafonds se rattrapent dans les deux `_sur_curseur`.
	_vert_curseur.min_value = 0.0
	_vert_curseur.max_value = 100.0
	_vert_curseur.step = 1.0
	_vert_curseur.focus_mode = Control.FOCUS_NONE
	_habiller_curseur(_vert_curseur)
	_vert_curseur.value_changed.connect(_sur_curseur_vert)
	_vert_bloc.add_child(_vert_curseur)

	# 🏢 DENSIFIER. Deux boutons pour la HAUTEUR — « un étage ou deux » est un
	# choix —, un curseur pour COMBIEN DE BÂTIMENTS. 🪜 Un cran, un bâtiment :
	# le curseur compte des toits, comme celui des arbres compte des arbres, et
	# non des pourcents. Le bloc ne s'ouvre que là où quelque chose peut monter
	# — le patrimoine n'a donc jamais de bouton grisé à expliquer.
	# 🔴 LES ÉTAGES SE CHOISISSENT UNE FOIS PAR ÎLOT : le shader n'a qu'une
	# hauteur pour tout l'îlot. Les deux boutons se verrouillent au premier
	# chantier, le curseur, lui, reprend au cran atteint.
	_dense_bloc = VBoxContainer.new()
	_dense_bloc.add_theme_constant_override("separation", 6)
	_dense_bloc.visible = false
	v.add_child(_dense_bloc)
	_dense_bloc.add_child(HSeparator.new())
	_titre_section(_dense_bloc, "Densifier")
	_dense_valeur = _label("", 13, TEXTE)
	_dense_valeur.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_dense_bloc.add_child(_dense_valeur)
	var etages_ligne := HBoxContainer.new()
	etages_ligne.add_theme_constant_override("separation", 6)
	_dense_bloc.add_child(etages_ligne)
	for n in [1, 2]:
		var b := Button.new()
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(func() -> void: _basculer("dense", n))
		etages_ligne.add_child(b)
		_dense_boutons.append(b)
	_dense_jauge = Jauge.new()
	_dense_jauge.custom_minimum_size = Vector2(0, 15)
	_dense_jauge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dense_jauge.colorer(FAIT)
	_dense_bloc.add_child(_dense_jauge)
	_dense_curseur = HSlider.new()
	# ⚠️ L'échelle n'est PAS fixe ici, au contraire des trois autres curseurs :
	# elle compte des bâtiments, et chaque îlot n'en a pas le même nombre. Le
	# pas d'un cran garde son sens — un toit —, ce qui est le propos.
	_dense_curseur.min_value = 0.0
	_dense_curseur.step = 1.0
	_dense_curseur.focus_mode = Control.FOCUS_NONE
	_habiller_curseur(_dense_curseur)
	_dense_curseur.value_changed.connect(_sur_curseur_dense)
	_dense_bloc.add_child(_dense_curseur)

	# 🗂️ CHAQUE BLOC DE RÉGLAGE SOUS SON THÈME. C'est ce qui fait qu'un onglet
	# porte les chiffres ET la décision : `vert` en tient deux, parce qu'un toit
	# et un alignement d'arbres sont le même thème sur deux couches.
	_bloc_onglet = {
		_repare_bloc: "crue", _camp_bloc: "campagne", _dense_bloc: "bati",
		_solaire_bloc: "energie", _vert_bloc: "vert", _arbres_bloc: "vert",
		_trafic_bloc: "trafic", _berge_bloc: "berge",
	}

	# 🔴 LE RÉCAPITULATIF ET LE BOUTON, EN BAS ET UNE SEULE FOIS. Tous les
	# réglages posés y arrivent : un prix, une durée, un refus. C'est aussi le
	# seul endroit où le jeu dit non — un bouton grisé sans phrase est une
	# panne, sous « il manque 214 k€ » c'est une règle.
	_recap_bloc = VBoxContainer.new()
	_recap_bloc.add_theme_constant_override("separation", 6)
	_recap_bloc.visible = false
	v.add_child(_recap_bloc)
	_recap_bloc.add_child(HSeparator.new())
	_recap_texte = _label("", 12, GRIS_FORT)
	_recap_texte.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_recap_bloc.add_child(_recap_texte)
	_recap_bouton = Button.new()
	_recap_bouton.text = "Mettre en place"
	_habiller_principal(_recap_bouton)
	_recap_bouton.pressed.connect(_mettre_en_place)
	_recap_bloc.add_child(_recap_bouton)

	_message = _label("", 12, GRIS)
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_message)
	_clamper_fiche()


## 📖 TANT QUE LES CARTES DU DÉBUT PASSENT, IL N'Y A PAS DE JEU À L'ÉCRAN
## (auteur, 2026-09-18) : ni compteurs, ni rail, ni commandes du temps. On
## regarde Wehrau, on ne lit pas encore un tableau de bord — et surtout on ne
## voit pas de quoi poser des panneaux avant d'avoir su ce qui s'est passé.
## Les panneaux qui s'ouvrent au clic (fiche, diagnostic, chantiers, calque)
## se referment et reviendront par leur propre chemin.
func montrer_jeu(oui: bool) -> void:
	for panneau in [_ville_panneau, _menu_panneau, _camera_panneau,
			_temps_panneau, retours.compteur]:
		if panneau != null:
			(panneau as Control).visible = oui
	if oui:
		_placer_detail()
	retours.actualiser_affichage()
	if not oui:
		for panneau in [_fiche_panneau, _diagnostic_panneau,
				_chantiers_panneau, _calque_panneau, _lieu_panneau]:
			if panneau != null:
				(panneau as Control).visible = false


## 🛠️ L'ÉCRAN DE DÉPART, ET IL NE PROPOSE QUE DEUX CHOSES. « Auteur » ne
## change ni les prix ni la caisse : il livre les chantiers au clic, pour qu'on
## puisse juger la vingtième minute sans la jouer vingt fois.
## Refermer l'écran de départ : le mode a été choisi, au clic ou en drapeau.
func cacher_depart() -> void:
	if _depart_panneau != null:
		_depart_panneau.visible = false
		montrer_jeu(true)


func montrer_depart() -> void:
	# 📖 L'écran de choix fait partie de l'ouverture : pas de compteurs
	# derrière lui non plus.
	montrer_jeu(false)
	if _depart_panneau != null:
		_depart_panneau.visible = true
		return
	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(centre)
	_depart_panneau = centre
	var p := PanelContainer.new()
	p.theme = _theme_ui
	_poser_boite(p)
	p.custom_minimum_size.x = 380
	centre.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	p.add_child(v)
	v.add_child(_titre("Wehrau, après la crue", 17, ACCENT))
	var mot := _label("La ville est sinistrée et la caisse est courte."
		+ " Choisissez comment vous voulez jouer.", 13, TEXTE)
	mot.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(mot)
	for choix in [["Mode histoire", false,
			"La partie normale : les chantiers prennent le temps qu'ils prennent."],
			["Mode auteur", true,
			"Pour essayer : tout chantier engagé est livré immédiatement."
			+ " Les prix et la dotation ne changent pas."]]:
		var b := Button.new()
		b.text = String(choix[0])
		b.tooltip_text = String(choix[2])
		b.focus_mode = Control.FOCUS_NONE
		if not bool(choix[1]):
			_habiller_principal(b)
		var auteur: bool = choix[1]
		b.pressed.connect(func() -> void:
			centre.visible = false
			mode_choisi.emit(auteur))
		v.add_child(b)
		var sous := _label(String(choix[2]), 11, GRIS)
		sous.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(sous)
	_sans_focus(centre)


## La fiche hésite entre deux besoins : hugger son contenu quand il est court,
## ne jamais dépasser le bas de l'écran quand il est long. Le ScrollContainer
## n'a pas de hauteur propre, donc on la lui donne ici — 26 px de marges de
## boîte, 16 px de bord bas.
func _clamper_fiche() -> void:
	if _fiche_defilement == null or _fiche_contenu == null:
		return
	var dispo: float = get_viewport().get_visible_rect().size.y - HAUT - 166.0
	_fiche_defilement.custom_minimum_size.y = minf(
		_fiche_contenu.get_combined_minimum_size().y, maxf(160.0, dispo))


# Le lacet 0 place la caméra AU SUD : repère fixé par « Z vers le sud » dans
# `07_exporter_godot.py:680`, pas ici.
const AZIMUTS := ["du sud", "du sud-est", "de l'est", "du nord-est",
	"du nord", "du nord-ouest", "de l'ouest", "du sud-ouest"]


## LE bouton du jeu, et il se voit : jaune plein, texte sombre, pleine largeur.
## Les autres boutons sont du papier ; celui-là engage la caisse.
func _habiller_principal(b: Button) -> void:
	var plein := StyleBoxFlat.new()
	plein.bg_color = ACCENT_VIF
	plein.border_color = Color8(22, 96, 166)
	plein.set_border_width_all(1)
	plein.set_corner_radius_all(9)
	plein.set_content_margin_all(11)
	var survol := plein.duplicate()
	survol.bg_color = Color8(74, 163, 240)
	var presse := plein.duplicate()
	presse.bg_color = Color8(28, 106, 180)
	b.add_theme_stylebox_override("normal", plein)
	b.add_theme_stylebox_override("hover", survol)
	b.add_theme_stylebox_override("pressed", presse)
	b.add_theme_font_size_override("font_size", 15)
	b.add_theme_color_override("font_color", Color.WHITE)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_pressed_color", Color.WHITE)


# ==========================================================================
# 🎓🏛️ L'UNIVERSITÉ ET LA MAIRIE — deux menus, deux portes (79 · 80 · 81)
# ==========================================================================
# Les deux îlots restent des îlots ordinaires : leurs toits, leurs curseurs et
# leur part dans les totaux ne changent pas. Seul un bouton s'ajoute à leur
# fiche, et le menu qu'il ouvre est une AUTRE fiche.

const LIEUX := {
	"mairie": {"fid": 20, "nom": "Mairie", "court": "Mairie",
		"quoi": "Une politique n'est pas un chantier : elle dure, et elle se paie tous les mois tant qu'elle tient."},
	"universite": {"fid": 36, "nom": "Université", "court": "Univ.",
		"quoi": "On finance un sujet, on attend, le palier tombe — et il vaut pour toute la ville, panneaux déjà posés compris."},
}
const LIEUX_ORDRE := ["mairie", "universite"]


func _lieu_du_fid(fid: int) -> String:
	for cle in LIEUX_ORDRE:
		if int(LIEUX[cle]["fid"]) == fid:
			return cle
	return ""


func _panneau_lieu() -> void:
	# Même gabarit et même place que la fiche d'îlot : c'est une fiche, et elle
	# prend la place de l'autre plutôt que de s'ajouter à côté (53).
	var p := PanelContainer.new()
	_lieu_panneau = p
	p.theme = _theme_ui
	_poser_boite(p)
	p.anchor_left = 1.0
	p.anchor_right = 1.0
	p.offset_left = -336
	p.offset_right = -16
	p.offset_top = HAUT
	p.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	p.visible = false
	add_child(p)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	p.add_child(v)
	_lieu_titre = _bandeau(v, "Mairie")
	_lieu_intro = _label("", 12, GRIS)
	_lieu_intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_lieu_intro)

	for cle in Politiques.ORDRE:
		_lieu_lignes[cle] = _ligne_lieu(v, "politique",
			String(Politiques.POLITIQUES[cle]["nom"]),
			String(Politiques.POLITIQUES[cle]["quoi"]))
	for cle in Recherche.ORDRE:
		_lieu_lignes[cle] = _ligne_lieu(v, "recherche",
			String(Recherche.SUJETS[cle]["nom"]),
			String(Recherche.SUJETS[cle]["quoi"]))

	_lieu_message = _label("", 11, GRIS)
	_lieu_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_lieu_message)

	var retour := Button.new()
	retour.text = "Fermer"
	retour.theme = _theme_ui
	retour.focus_mode = Control.FOCUS_NONE
	retour.pressed.connect(_fermer_lieu)
	v.add_child(retour)


## Une ligne de menu : ce que c'est, ce que ça fait, où ça en est, et LE bouton.
func _ligne_lieu(parent: VBoxContainer, genre: String, nom: String,
		quoi: String) -> Dictionary:
	var bloc := VBoxContainer.new()
	bloc.add_theme_constant_override("separation", 3)
	parent.add_child(bloc)
	bloc.add_child(HSeparator.new())
	bloc.add_child(_label(nom, 14, TEXTE))
	var l_quoi := _label(quoi, 11, GRIS)
	l_quoi.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bloc.add_child(l_quoi)
	var jauge := Jauge.new()
	jauge.custom_minimum_size = Vector2(0, 9)
	jauge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	jauge.colorer(ACCENT_VIF)
	jauge.visible = genre == "recherche"
	bloc.add_child(jauge)
	var etat := _label("", 12, TEXTE)
	etat.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bloc.add_child(etat)
	var b := Button.new()
	_habiller_principal(b)
	b.focus_mode = Control.FOCUS_NONE
	bloc.add_child(b)
	return {"bloc": bloc, "genre": genre, "etat": etat, "jauge": jauge, "bouton": b}


func ouvrir_lieu(cle: String) -> void:
	if not LIEUX.has(cle):
		return
	_lieu_ouvert = cle
	_lieu_panneau.visible = true
	_fiche_panneau.visible = false
	_lieu_titre.text = String(LIEUX[cle]["nom"])
	_lieu_intro.text = String(LIEUX[cle]["quoi"])
	_brancher_lieu()
	_maj_lieu()


func _fermer_lieu() -> void:
	_lieu_ouvert = ""
	_lieu_panneau.visible = false
	_fiche_panneau.visible = true


## Les boutons ne se rebranchent qu'au changement de menu : une connexion posée
## à chaque image en empilerait soixante par seconde.
func _brancher_lieu() -> void:
	for cle in _lieu_lignes:
		var l: Dictionary = _lieu_lignes[cle]
		var b: Button = l["bouton"]
		for c in b.pressed.get_connections():
			b.pressed.disconnect(c["callable"])
		var k: String = cle
		if String(l["genre"]) == "recherche":
			b.pressed.connect(func() -> void:
				if ville.financer_recherche(k, _mois):
					var sujet: Dictionary = Recherche.SUJETS[k]
					retours.notifier("%s : financement engagé, %s k€/mois pendant %s." % [sujet["nom"], _milliers(sujet["ke_mois"]), _duree(sujet["mois"])], _mois)
					retours.actualiser(_mois)
				_maj_lieu())
		else:
			b.pressed.connect(func() -> void:
				if ville.basculer_politique(k, _mois):
					var politique: Dictionary = Politiques.POLITIQUES[k]
					retours.notifier("%s : %s" % [politique["nom"], "%s k€/mois · %s" % [_milliers(politique["ke_mois"]), politique["quoi"]] if Politiques.active(ville, k) else "subvention arrêtée, prélèvements terminés."], _mois)
				_maj_lieu())


func _maj_lieu() -> void:
	if _lieu_ouvert == "":
		return
	var universite := _lieu_ouvert == "universite"
	for cle in _lieu_lignes:
		var l: Dictionary = _lieu_lignes[cle]
		var bloc: VBoxContainer = l["bloc"]
		bloc.visible = (String(l["genre"]) == "recherche") == universite
		if not bloc.visible:
			continue
		if universite:
			_maj_ligne_recherche(String(cle), l)
		else:
			_maj_ligne_politique(String(cle), l)
	# 🔴 Ce qui manque est DIT, pas simulé à moitié : les règles se paient en
	# capital politique, qui vit encore dans le classeur et pas ici.
	_lieu_message.text = "" if universite else \
		"Les règles — stationnement payant, toit vert obligatoire au neuf — " \
		+ "attendent le capital politique, qui n'est pas encore dans la maquette."


func _maj_ligne_recherche(cle: String, l: Dictionary) -> void:
	var s: Dictionary = Recherche.SUJETS[cle]
	var etat: Label = l["etat"]
	var b: Button = l["bouton"]
	var jauge: Jauge = l["jauge"]
	if Recherche.acquis(ville, cle, _mois):
		jauge.regler(1.0, 1.0)
		etat.text = "Acquis au mois %d · vaut pour toute la ville." % \
			int(roundf(Recherche.mois_palier(ville, cle)))
		b.visible = false
	elif ville.recherche_engagee(cle):
		var reste: float = Recherche.reste_mois(ville, cle, _mois)
		jauge.regler(1.0 - reste / float(s["mois"]), 1.0)
		etat.text = "En cours · %s · %s k€/mois" % [
			_duree(reste), _milliers(float(s["ke_mois"]))]
		b.visible = false
	else:
		jauge.regler(0.0, 0.0)
		etat.text = "%s k€/mois pendant %d mois · %s k€ en tout" % [
			_milliers(float(s["ke_mois"])), int(float(s["mois"])),
			_milliers(Recherche.cout_total_ke(cle))]
		b.visible = true
		b.disabled = _caisse_ke < float(s["ke_mois"])
		b.text = "Financer" if not b.disabled else "Caisse insuffisante"


func _maj_ligne_politique(cle: String, l: Dictionary) -> void:
	var pol: Dictionary = Politiques.POLITIQUES[cle]
	var etat: Label = l["etat"]
	var b: Button = l["bouton"]
	var ke_mois := float(pol["ke_mois"])
	var verse := Politiques.mois_actifs(ville, cle, _mois) * ke_mois
	b.visible = true
	if Politiques.active(ville, cle):
		etat.text = "En vigueur · %s k€/mois · %s k€ déjà versés" % [
			_milliers(ke_mois), _milliers(verse)]
		b.disabled = false
		b.text = "Retirer"
	else:
		etat.text = "%s k€/mois dès la signature" % _milliers(ke_mois)
		if verse > 0.0:
			etat.text += " · %s k€ versés avant retrait" % _milliers(verse)
		b.disabled = _caisse_ke < ke_mois
		b.text = "Signer" if not b.disabled else "Caisse insuffisante"


func _panneau_camera() -> void:
	# Les gestes de caméra ne se devinent pas, et un jeu qui oblige à ouvrir un
	# fichier pour les connaître n'en est pas un.
	var p := PanelContainer.new()
	p.theme = _theme_ui
	_poser_boite(p)
	p.anchor_top = 1.0
	p.anchor_bottom = 1.0
	p.offset_left = 16
	# Au-dessus de la barre du temps, qui tient le coin depuis le 2026-09-01.
	p.offset_bottom = -88
	p.grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_child(p)
	_camera_panneau = p

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 3)
	p.add_child(v)
	# 🔄 « vue du sud-est, 42° au-dessus » est passé dans la bulle de la
	# boussole : la flèche dit déjà où est le nord.
	var boutons := HBoxContainer.new()
	v.add_child(boutons)
	_camera_nord = Button.new()
	_camera_nord.name = "Boussole"
	_camera_nord.custom_minimum_size = Vector2(100, 32)
	_camera_nord.focus_mode = Control.FOCUS_NONE
	_camera_nord.pressed.connect(func(): nord_demande.emit())
	boutons.add_child(_camera_nord)
	_camera_dessus = Button.new()
	_camera_dessus.name = "VueDessus"
	_camera_dessus.focus_mode = Control.FOCUS_NONE
	_camera_dessus.pressed.connect(func(): dessus_demande.emit())
	boutons.add_child(_camera_dessus)
	for ligne in [
		"Glisser : déplacer · Ctrl : tourner",
		"Molette : zoom · V : toute la ville",
	]:
		v.add_child(_label(ligne, 12, GRIS))


func maj_camera(lacet: float, hauteur: float) -> void:
	if _camera_nord == null:
		return
	var l := fmod(fmod(lacet, 360.0) + 360.0, 360.0)
	var i := int(roundf(l / 45.0)) % 8
	_camera_nord.tooltip_text = "Vue %s, %d° au-dessus. Remettre le nord en haut." % [
		AZIMUTS[i], int(roundf(hauteur))]
	_camera_nord.text = "%s N" % ["↑", "↗", "→", "↘", "↓", "↙", "←", "↖"][i]
	_camera_dessus.text = "3D" if hauteur >= 89.5 else "Dessus"


func _controles_temps() -> void:
	var p := PanelContainer.new()
	p.theme = _theme_ui
	_poser_boite(p)
	# 🔄 AU COIN BAS-GAUCHE depuis le 2026-09-01 : le centre du bas est pris
	# par la barre des vues.
	p.anchor_top = 1.0
	p.anchor_bottom = 1.0
	p.offset_left = 16
	p.offset_right = 412
	p.offset_top = -72
	p.offset_bottom = -16
	p.grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_child(p)
	_temps_panneau = p

	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	p.add_child(h)
	_temps_label = _etiquette("Mois 0", 12, TEXTE)
	_temps_label.custom_minimum_size.x = 86
	_temps_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	h.add_child(_temps_label)
	for choix in [["Ⅱ", 0.0], ["▶", 1.0], ["×4", 4.0], ["×12", 12.0]]:
		var b := Button.new()
		b.text = choix[0]
		b.custom_minimum_size = Vector2(52, 40)
		b.add_theme_font_size_override("font_size", 15)
		var v: float = choix[1]
		# ⏯️ La vitesse en cours est ENFONCÉE, pas grisée : grisée, elle se lisait
		# comme un bouton en panne, et on ne savait plus si le temps courait.
		b.toggle_mode = true
		b.pressed.connect(_demander_vitesse.bind(v))
		h.add_child(b)
		_vitesses[v] = b

	# Rejouer un geste demandait trois secondes de rechargement. Le bouton remet
	# le temps ET la ville : un temps qui recule seul laisserait des toits noirs
	# sous un compteur à « Mois 0 ».
	var raz := Button.new()
	raz.text = "↺"
	raz.custom_minimum_size = Vector2(46, 40)
	raz.tooltip_text = "Remet le temps au mois 0 et annule les poses décidées."
	raz.pressed.connect(func() -> void: temps_remis.emit())
	h.add_child(raz)

	for action in [["Sauvegarder", "F5"], ["Reprendre", "F9"]]:
		var bouton := Button.new()
		bouton.text = action[0]
		bouton.tooltip_text = "%s (%s)" % action
		bouton.custom_minimum_size.y = 40
		h.add_child(bouton)
		if action[1] == "F5":
			bouton.pressed.connect(func() -> void: sauvegarde_demandee.emit())
		else:
			_reprendre = bouton
			bouton.pressed.connect(func() -> void: reprise_demandee.emit())


## 💾 Le message passe par le bandeau des retours : un seul bandeau en haut.
func informer_partie(message: String, disponible: bool) -> void:
	if message != "" and retours != null:
		retours.signaler(message)
	_reprendre.disabled = not disponible


func _titre_lieu(couche: String) -> void:
	# 🌾 Un champ s'appelle « Champ », pas « Îlot » : les 88 champs n'ont pas de
	# nom écrit, donc c'est ce mot de secours qu'on lit à l'écran.
	var genre := "Champ" if couche == "i" and ville.est_champ(_fiche_fid) else ""
	_fiche_titre.text = lieux.nom(couche, _fiche_fid, genre)
	_fiche_titre.tooltip_text = lieux.repere(couche, _fiche_fid, genre)
	_fiche_titre.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


func _demander_vitesse(v: float) -> void:
	vitesse_demandee.emit(v)


func maj(indic: Dictionary, mois: float, vitesse: float) -> void:
	retours.actualiser_affichage()
	if indic.is_empty():
		return
	_mois = mois
	var conso: float = indic["conso_mwh"]
	var prod: float = indic["production_mwh"]
	var achat: float = indic["achat_mwh"]
	var co2: float = indic["co2_kt"]
	_ville_valeurs["conso"].text = _nb(conso / 1000.0, 1) + " GWh/an"
	_ville_valeurs["production"].text = _nb(prod / 1000.0, 1) + " GWh/an"
	_ville_valeurs["achat"].text = _nb(achat / 1000.0, 1) + " GWh/an"
	_ville_valeurs["co2"].text = _nb(co2, 1) + " kt/an"
	# 🔴 CE QUE MESURENT LES QUATRE JAUGES, et c'est le seul endroit où c'est
	# écrit : le solaire et l'achat se lisent sur la consommation ; la conso et
	# le CO₂ n'ont pas de plein, donc ils se lisent contre le MOIS 0, mémorisé
	# au premier appel. Aucun nouveau chiffre — la même mesure, en image.
	if _conso_zero <= 0.0:
		_conso_zero = maxf(conso, 1.0)
		_co2_zero = maxf(co2, 0.001)
	_regler_jauge("conso", conso / _conso_zero)
	_regler_jauge("production", prod / maxf(conso, 1.0))
	_regler_jauge("achat", achat / maxf(conso, 1.0))
	_regler_jauge("co2", co2 / _co2_zero)
	# 🌾 Le nombre est en personnes, la jauge en part de la ville : les deux
	# disent la même mesure, et c'est la jauge qui rend visible ce qu'un champ
	# bâti coûte.
	var nourris: float = indic["nourriture_personnes"]
	_ville_valeurs["nourriture"].text = _nb(nourris, 0) + " pers."
	_regler_jauge("nourriture", indic["nourriture_part"])
	# ⚠️ Mémorisée ici : `_maj_fiche()` en a besoin à chaque image, et la
	# recalculer parcourrait la ville une seconde fois par image.
	_caisse_ke = indic["caisse_ke"]
	_ville_valeurs["caisse"].text = _milliers(_caisse_ke) + " k€"
	_ville_valeurs["recette"].text = "+" + _milliers(indic["recette_ke_an"]) + " k€/an"
	_maj_durabilite(indic)
	_temps_label.text = "MOIS %s" % _nb(mois, 1)
	maj_degats(ville.degats(mois))
	if _chantiers_panneau.visible:
		maj_chantiers(ville.chantiers(mois))
	var verrou := _verrou()
	for b in _rail_lieux:
		b.disabled = verrou != ""
	for v in _vitesses:
		(_vitesses[v] as Button).set_pressed_no_signal(is_equal_approx(float(v), vitesse))
	if _fiche_fid >= 0:
		_maj_fiche()
	if _lieu_ouvert != "":
		_maj_lieu()


func _regler_jauge(cle: String, part: float) -> void:
	var p := clampf(part, 0.0, 1.0)
	(_ville_jauges[cle] as Jauge).regler(p, p)


## 🔄 LES DEUX PHRASES SOUS LES JAUGES SONT PARTIES le 2026-09-03 — elles
## étaient déjà invisibles depuis que le bandeau les avait perdues, et les
## jetons disent la même part sans mot.
func _maj_durabilite(indic: Dictionary) -> void:
	var adaptation := float(indic["adaptation_part"])
	_adaptation_jauge.regler(adaptation, adaptation)
	_adaptation_valeur.text = "%d %%" % int(roundf(adaptation * 100.0))
	_adaptation_pictos.regler(adaptation)

	var reduction := float(indic["reduction_part"])
	_reduction_jauge.regler(reduction, reduction)
	_reduction_valeur.text = "%d %%" % int(roundf(reduction * 100.0))
	_reduction_pictos.regler(reduction)


func montrer(couche: String, fid: int, _garder := true) -> void:
	# 🔄 LA FICHE S'OUVRE AUSSI SUR UNE RUE depuis le 2026-08-21. Elle
	# n'appartenait qu'à l'îlot ; la crue a mis deux décisions sur la voirie —
	# déblayer, rebâtir — et une décision qu'on ne peut pas cliquer n'existe pas.
	if fid < 0 or (couche != "i" and couche != "r" and couche != "b"):
		return
	# 🎓🏛️ Cliquer la ville referme le menu : jamais deux fiches ensemble (81).
	_fermer_lieu()
	_fiche_panneau.visible = true
	var lieu := _lieu_du_fid(fid) if couche == "i" else ""
	_lieu_bouton.visible = lieu != ""
	if lieu != "":
		_lieu_bouton.text = "Ouvrir %s" % ("la mairie" if lieu == "mairie" \
			else "l'université")
	if fid != _fiche_fid or couche != _fiche_couche:
		_vider_pose()   # changer d'objet abandonne tout ce qui était posé
		_message.text = ""
	_fiche_fid = fid
	_fiche_couche = couche
	_fiche_vide.visible = false
	_apercu_cadre.visible = apercu != null
	_fiche_soustitre.visible = true
	# 🗂️ CE QUI PEUT S'AFFICHER SUR CET OBJET, onglet ouvert mis à part. Les deux
	# blocs de la crue se remettent à zéro ici : une berge ne passe jamais par
	# `_maj_reparation`, donc sans cette ligne elle hériterait du dernier îlot.
	_bloc_dispo[_repare_bloc] = false
	_bloc_dispo[_camp_bloc] = false
	# ☀️ VERROUILLÉ JUSQU'À L'ÉCRAN « investir » (auteur, 2026-09-18) : la ville
	# reloge et relève d'abord ; les panneaux ne s'ouvrent qu'ensuite.
	_bloc_dispo[_solaire_bloc] = couche == "i" and not _solaire_verrouille()
	# 🌿 Un îlot tout en versants ne verra JAMAIS ce bloc : un curseur qui ne
	# peut rien poser n'est pas une décision grisée, c'est du bruit.
	_bloc_dispo[_vert_bloc] = couche == "i" 		and ville.valeur("i", fid, "_part_plate", _mois) > 0.001
	# 🏢 Un îlot dont rien ne peut monter n'a pas de bloc : le cœur ancien,
	# le front commerçant, et tout ce qui n'est pas bâti.
	_bloc_dispo[_dense_bloc] = couche == "i" and ville.dense_logements_etage(fid) > 0
	_bloc_dispo[_trafic_bloc] = couche == "r"
	# 🌳 Seulement là où il y a la place d'un arbre entre la chaussée et la
	# limite d'emprise : `07` l'a tranché, les ruelles du cœur ancien n'en ont
	# aucune. Un curseur qui ne planterait rien n'a pas à s'afficher.
	_bloc_dispo[_arbres_bloc] = couche == "r" and ville.arbres_plantables(fid) > 0
	_bloc_dispo[_berge_bloc] = couche == "b"
	_maj_fiche()


func reprendre_fiche(couche: String, fid: int) -> void:
	_vider_pose()
	_fermer_lieu()
	_message.text = ""
	_fiche_fid = -1
	_fiche_panneau.visible = fid >= 0
	if fid >= 0:
		montrer(couche, fid)


## 🏕️ TANT QUE PERSONNE N'EST RELOGÉ, LA FICHE NE PROPOSE QUE LE CAMP
## (auteur, 2026-09-17). Le joueur clique où il veut, mais la ville n'ouvre
## aucun autre chantier pendant que les sinistrés dorment dehors : c'est ce qui
## oriente vers les champs sans les désigner.
var _message_urgence := false


## 🔒 « reloger », « pont » ou "" : le verrou des premières minutes, tenu par le
## guide (`ouverture.verrou`). Sans guide (contrôles), rien n'est verrouillé.
func _verrou() -> String:
	return ouverture.verrou() if ouverture != null else ""


func _autorise(couche: String, fid: int) -> bool:
	return ouverture == null or ouverture.autorise(couche, fid)


func _solaire_verrouille() -> bool:
	return ouverture != null and not (ouverture.suite or ouverture.termine)


func _maj_fiche() -> void:
	_maj_fiche_contenu()
	_repare_texte.visible = _repare_texte.text != ""
	var verrou := _verrou()
	if verrou != "":
		_lieu_bouton.visible = false
	# 🗂️ `_maj_fiche_contenu` vient de dire ce qui existe ; on en déduit les
	# onglets. On ne les repeint QUE s'ils ont changé : on passe ici à chaque
	# image, et refaire sept boîtes de style par image pour rien se verrait.
	# Une berge n'a pas de sous-titre : sans ça, elle garderait une ligne vide.
	_fiche_soustitre.visible = _fiche_soustitre.text != ""
	var dispo := _calculer_dispo()
	if dispo != _dispo:
		_dispo = dispo
		_appliquer_onglets()
	# La phrase de l'urgence s'efface dès qu'elle est fausse : sans ça, elle
	# survivait sous la fiche du champ qui, lui, peut accueillir.
	var muet := verrou != "" and not _autorise(_fiche_couche, _fiche_fid)
	if muet:
		_message.text = "Rien à engager ici avant d'avoir abrité les sinistrés." \
			if verrou == "reloger" else "Rien à engager ici avant d'avoir rouvert un pont et ses accès."
	elif _message_urgence:
		_message.text = ""
	_message_urgence = muet


func _maj_fiche_contenu() -> void:
	_maj_chantier()
	_maj_camp()
	if _fiche_couche == "r":
		_maj_fiche_rue()
		return
	if _fiche_couche == "b":
		_maj_fiche_berge()
		return
	var o: Dictionary = ville.ilots.get(_fiche_fid, {})
	if o.is_empty():
		return
	_titre_lieu("i")
	_maj_reparation(o)

	var conso := ville.valeur("i", _fiche_fid, "_conso_mwh", _mois)
	var prod := ville.valeur("i", _fiche_fid, "_production_mwh", _mois)
	var toit := ville.valeur("i", _fiche_fid, "_toit_equipable_m2", _mois)
	var etat := ville.etat_solaire(_fiche_fid, _mois)
	var pct := float(etat["actuel"]) * 100.0
	var cible_pct := float(etat["cible"]) * 100.0
	# 🌾 Un champ porte déjà « Champ » dans son nom : le répéter dessous ne dit
	# rien. Les autres tissus, si — « îlot compact » n'est pas dans le nom.
	var tissu := str(o.get("sous_type", "?"))
	_fiche_soustitre.text = "" if tissu == "champ" 		else str(TISSUS.get(tissu, tissu.replace("_", " ")))
	var champ := ville.est_champ(_fiche_fid)
	# 🔄 Par `ville.valeur` depuis le 2026-08-21, plus par la fiche brute :
	# `logements` BOUGE maintenant — la crue en a retiré 417, une
	# reconstruction les rend, et la base seule affichait toujours 0.
	var loges := ville.valeur("i", _fiche_fid, "logements", _mois)
	var nourris := ville.champ_nourriture(_fiche_fid)
	var hectares := float(o.get("surface_m2", 0.0)) / 10000.0
	if champ:
		# 🌾 CE QUE CE CHAMP-LÀ NOURRIT, en clair et avant toute décision.
		_maj_resume("nourriture", ("%s personnes nourries" % _nb(nourris, 0))
			if ville.champ_cultive(_fiche_fid, _mois) and nourris >= 1.5
			else "ne produit plus de nourriture")
		(_fiche_valeurs["surface_champ"] as Label).text = "%s ha" % _nb(hectares, 2)
		(_fiche_valeurs["rive"] as Label).text = str(o.get("rive", "?"))
	else:
		_maj_resume("logement", "aucun logement" if loges < 0.5
			else ("1 logement" if loges < 1.5 else "%s logements" % _nb(loges, 0)))
		(_fiche_valeurs["surface"] as Label).text = "%s ha" % _nb(hectares, 2)
		(_fiche_valeurs["niveaux"] as Label).text = _nb(
			float(o.get("hauteur", 0.0)), 0)
		(_fiche_valeurs["emplois"] as Label).text = _nb(
			float(o.get("emplois", 0)), 0)

	# 🔴 « MWh/an » COUPE LA TUILE EN DEUX sur trois colonnes : le « par an » est
	# passé dans l'étiquette, et les milliers prennent leur espace comme
	# partout ailleurs.
	(_fiche_valeurs["conso"] as Label).text = _milliers(conso) + " MWh"
	(_fiche_valeurs["production"] as Label).text = _milliers(prod) + " MWh"
	(_fiche_valeurs["toit"] as Label).text = _milliers(toit) + " m²"
	var plate := ville.valeur("i", _fiche_fid, "_part_plate", _mois)
	(_fiche_valeurs["plat"] as Label).text = "%d %%" % int(roundf(plate * 100.0))
	(_fiche_valeurs["verdi"] as Label).text = _milliers(
		ville.valeur("i", _fiche_fid, "_toit_vert_m2", _mois)) + " m²"
	# L'amortissement est une propriété de l'îlot, pas de la part visée
	# (`energie.rentabilite_annees`).
	var ans := ville.valeur("i", _fiche_fid, "_rentabilite_annees", _mois)
	(_fiche_valeurs["retour"] as Label).text = 		"—" if is_inf(ans) else "%d ans" % int(roundf(ans))

	# 🌊 CE QUE LA CRUE A PRIS. La reprise annoncée est par le noyau et non par
	# la fiche brute : une berge livrée en aval a pu la faire baisser.
	# Relevé, l'îlot n'a plus rien de perdu : les chiffres de l'export restaient.
	var releve := ville.reparation_finie("i", _fiche_fid, _mois)
	(_fiche_valeurs["perdus"] as Label).text = "0" if releve else _nb(
		float(o.get("logements_sinistres", 0)), 0)
	(_fiche_valeurs["detruits"] as Label).text = "0" if releve else _nb(
		float(o.get("batiments_ruines", 0)), 0)
	(_fiche_valeurs["annonce"] as Label).text = "%s m" % _nb(
		ville.valeur("i", _fiche_fid, "hauteur_eau_annonce", _mois), 2)
	(_fiche_valeurs["reprise"] as Label).text = "%d %%" % int(roundf(
		100.0 * ville.valeur("i", _fiche_fid, "part_ruinee_apres", _mois)))

	# 🔴 On passe ici À CHAQUE IMAGE : le curseur ne se repositionne que sans
	# choix en cours, sinon on garde la position de l'auteur, remontée au
	# niveau déjà posé.
	# ⚠️ Il se VERROUILLE pendant les travaux : une pose engagée est payée, et
	# ce verrou permet aux rampes de s'additionner sans réécrire l'histoire
	# d'un toit (`ville.lancer_solaire`).
	# 🌿 LE PLAFOND, ET IL BOUGE : ce que les toits verts prennent, les panneaux
	# ne l'ont plus. Il compte la CIBLE et non le réalisé, donc un chantier vert
	# engagé ferme la part tout de suite.
	var plafond_pct := ville.part_solaire_max(_fiche_fid, _mois) * 100.0
	if _vert_choix >= 0.0:
		plafond_pct = minf(plafond_pct, 100.0 - _vert_choix)
	_ecrit_curseur = true
	_solaire_curseur.editable = toit > 0.0 and pct < plafond_pct - 0.5 \
		and not etat["en_cours"]
	if _solaire_choix < 0.0:
		_solaire_curseur.set_value_no_signal(maxf(pct, cible_pct))
	else:
		_solaire_choix = clampf(_solaire_choix, pct, maxf(plafond_pct, pct))
		_solaire_curseur.set_value_no_signal(_solaire_choix)
	_ecrit_curseur = false
	# L'objectif visé est celui du curseur tant qu'il n'est pas validé, celui de
	# la pose en cours sinon.
	_solaire_jauge.regler(pct / 100.0,
		maxf(pct, _solaire_choix if _solaire_choix >= 0.0 else cible_pct) / 100.0)

	var recette := ville.valeur("i", _fiche_fid, "_recette_ke_an", _mois)
	if toit <= 0.0:
		_solaire_valeur.text = "Bâtiment protégé." \
			if int(o.get("solaire_possible", 1)) == 0 else "Aucun toit."
	elif _solaire_choix >= 0.0:
		_afficher_choix(pct, _solaire_choix)
	elif etat["en_cours"]:
		_solaire_valeur.text = "%d %% → %d %% · %s · %s k€ engagés" % [
			int(roundf(pct)), int(roundf(cible_pct)),
			_duree(float(etat["reste_mois"])), _milliers(float(etat["cout_ke"]))]
	else:
		_solaire_valeur.text = "%d %% équipé · +%s k€/an" % [int(roundf(pct)),
			_milliers(recette)] if pct > 0.0 else "Aucun panneau."
		if etat["a_commence"]:
			_message.text = "Pose terminée."
	_maj_vert()
	_maj_dense()
	_maj_recap()


# ==========================================================================
# LES RÉGLAGES POSÉS — on essaie, puis on met en place (2026-08-31)
# ==========================================================================

## Le libellé d'une bascule, marqué quand le réglage est posé. Une coche plutôt
## qu'une couleur : elle survit à une capture en noir et blanc, et elle se lit
## dans un bouton déjà chargé de trois nombres.
func _posee(cle: String, texte: String, valeur: Variant = true) -> String:
	return ("✓ " + texte) if _pose.has(cle) and typeof(_pose[cle]) == typeof(valeur) \
		and _pose[cle] == valeur else texte


## 🏢 CE QUE DENSIFIER DONNE, EN LOGEMENTS ET JAMAIS EN MÈTRES. La hauteur
## se voit à l'écran ; ce qui décide, c'est le parc que l'îlot gagne — et la
## consommation qui vient avec.
func _maj_dense() -> void:
	# 🗂️ L'onglet fermé n'a rien à remettre à jour ; ce qui décide reste
	# `_bloc_dispo`, et non la visibilité, qui suit l'onglet ouvert.
	if not bool(_bloc_dispo.get(_dense_bloc, false)):
		return
	var etat := ville.etat_dense(_fiche_fid, _mois)
	var n := int(etat["batiments"])
	var montes := int(etat["montes"])
	var etages := _dense_etages()
	# Les deux boutons donnent la HAUTEUR, et ils marchent en couple : l'un des
	# deux est toujours coché, parce qu'un curseur seul doit suffire à
	# densifier. Ils se figent au premier chantier — la hauteur d'un îlot ne se
	# choisit qu'une fois.
	for k in _dense_boutons.size():
		var b: Button = _dense_boutons[k]
		b.text = ("✓ " if k + 1 == etages else "") \
			+ "+%d étage%s" % [k + 1, "s" if k else ""]
		b.disabled = ville.dense_engage(_fiche_fid)

	# 🪜 Le curseur compte des BÂTIMENTS. Il repart du cran atteint : on ne
	# redescend pas un étage.
	_ecrit_curseur = true
	_dense_curseur.max_value = float(n)
	_dense_curseur.editable = montes < n and not etat["en_cours"]
	if _dense_choix < 0.0:
		_dense_curseur.set_value_no_signal(float(maxi(montes, int(etat["vises"]))))
	else:
		_dense_choix = clampf(_dense_choix, float(montes), float(n))
		_dense_curseur.set_value_no_signal(_dense_choix)
	_ecrit_curseur = false
	var vise: float = _dense_choix if _dense_choix >= 0.0 else float(etat["vises"])
	_dense_jauge.regler(float(montes) / maxf(float(n), 1.0),
		maxf(float(montes), vise) / maxf(float(n), 1.0))

	# 🏢 CE QUE DENSIFIER DONNE, EN LOGEMENTS ET JAMAIS EN MÈTRES.
	if _dense_choix >= 0.0 and _dense_choix > float(montes) + 0.01:
		var de := float(montes) / float(n)
		var vers := _dense_choix / float(n)
		_dense_valeur.text = "%d → %d bâtiments · +%d logements · %s" % [
			montes, int(_dense_choix),
			int(roundf(ville.dense_logements_tranche(_fiche_fid, de, vers, etages))),
			_duree(ville.duree_dense_mois(etages, de, vers))]
	elif etat["en_cours"]:
		_dense_valeur.text = "%d → %d bâtiments · +%d étage%s · encore %s" % [
			montes, int(etat["vises"]), etages, "s" if etages > 1 else "",
			_duree(float(etat["reste_mois"]))]
	elif montes > 0:
		_dense_valeur.text = "%d bâtiments sur %d montés · +%d logements" % [
			montes, n, int(roundf(float(etat["logements"])))]
	else:
		_dense_valeur.text = ("%d bâtiments peuvent monter, du plus bas au"
			+ " plus haut · %d logements par étage") % [
				n, ville.dense_logements_etage(_fiche_fid)]


## La hauteur retenue pour cet îlot : celle déjà engagée, sinon celle des
## boutons, sinon un étage — le curseur seul doit suffire à densifier.
func _dense_etages() -> int:
	var engage := ville.dense_etages(_fiche_fid)
	if engage > 0:
		return engage
	return int(_pose.get("dense", 1))


## 🌿 Le bloc des toits verts. Même mécanique que le solaire, à une chose près :
## ce qu'il annonce est l'effet de TOUTE la ville, parce que c'est là qu'il a
## lieu — un toit seul rachète des centimètres, le programme rachète des mètres.
func _maj_vert() -> void:
	# 🗂️ L'onglet fermé n'a rien à remettre à jour ; ce qui décide reste
	# `_bloc_dispo`, et non la visibilité, qui suit l'onglet ouvert.
	if not bool(_bloc_dispo.get(_vert_bloc, false)):
		return
	var etat := ville.etat_vert(_fiche_fid, _mois)
	var pct := float(etat["actuel"]) * 100.0
	var cible_pct := float(etat["cible"]) * 100.0
	var plafond_pct := ville.part_vert_max(_fiche_fid, _mois) * 100.0
	if _solaire_choix >= 0.0:
		plafond_pct = minf(plafond_pct, 100.0 - _solaire_choix)
	_ecrit_curseur = true
	_vert_curseur.editable = pct < plafond_pct - 0.5 and not etat["en_cours"]
	if _vert_choix < 0.0:
		_vert_curseur.set_value_no_signal(maxf(pct, cible_pct))
	else:
		_vert_choix = clampf(_vert_choix, pct, maxf(plafond_pct, pct))
		_vert_curseur.set_value_no_signal(_vert_choix)
	_ecrit_curseur = false
	_vert_jauge.regler(pct / 100.0,
		maxf(pct, _vert_choix if _vert_choix >= 0.0 else cible_pct) / 100.0)

	var ville_m := ville.baisse_crue_toits_m(_mois)
	var reste := "%s m² de toit plat libre" % _milliers(
		ville.valeur("i", _fiche_fid, "_toit_plat_equipable_m2", _mois)
		- ville.valeur("i", _fiche_fid, "_toit_vert_m2", _mois))
	if _vert_choix >= 0.0 and _vert_choix > pct + 0.01:
		_vert_valeur.text = "%d %% → %d %% · %s" % [int(roundf(pct)),
			int(roundf(_vert_choix)),
			_duree(ville.duree_vert_mois(pct / 100.0, _vert_choix / 100.0))]
	elif etat["en_cours"]:
		_vert_valeur.text = "%d %% → %d %% · %s · %s k€ engagés" % [
			int(roundf(pct)), int(roundf(cible_pct)),
			_duree(float(etat["reste_mois"])), _milliers(float(etat["cout_ke"]))]
	elif pct > 0.0:
		_vert_valeur.text = "%s m² verdis. La ville retient %s cm de crue." % [
			_milliers(ville.valeur("i", _fiche_fid, "_toit_vert_m2", _mois)),
			_nb(ville_m * 100.0, 0)]
	elif plafond_pct < 0.5:
		_vert_valeur.text = "Les panneaux prennent tout le toit plat."
	else:
		_vert_valeur.text = "%s." % reste


## 🌳 Le curseur des arbres, remis à jour à chaque image comme celui du solaire
## et avec le même verrou : sans choix en cours la fiche commande, sinon on
## garde la position de l'auteur, remontée au nombre déjà en terre.
func _maj_arbres() -> void:
	# 🗂️ L'onglet fermé n'a rien à remettre à jour ; ce qui décide reste
	# `_bloc_dispo`, et non la visibilité, qui suit l'onglet ouvert.
	if not bool(_bloc_dispo.get(_arbres_bloc, false)):
		return
	var plafond := Ville.PLANTATION_CANOPEE_MAX
	var cano := ville.valeur("r", _fiche_fid, "canopee", _mois)
	var pct := cano / plafond * 100.0
	var en_terre := ville.arbres_a(_fiche_fid, cano)
	var tous := ville.arbres_plantables(_fiche_fid)
	var en_cours := ville.plantation_en_cours(_fiche_fid, _mois)
	_ecrit_curseur = true
	_arbres_curseur.editable = not en_cours and en_terre < tous
	if _arbres_choix < 0.0:
		_arbres_curseur.set_value_no_signal(pct)
	else:
		_arbres_choix = maxf(_arbres_choix, pct)
		_arbres_curseur.set_value_no_signal(_arbres_choix)
	_ecrit_curseur = false
	var vise: float = maxf(pct, _arbres_choix if _arbres_choix >= 0.0 else pct)
	_arbres_jauge.regler(pct / 100.0, vise / 100.0)
	(_rue_valeurs["arbres"] as Label).text = "%d sur %d" % [en_terre, tous]
	(_rue_valeurs["canopee"] as Label).text = "%d %%" % int(roundf(cano * 100.0))
	if en_cours:
		_arbres_valeur.text = "%d arbres · reprise dans %s" % [
			ville.arbres_a(_fiche_fid, _arbres_choix / 100.0 * plafond) if
			_arbres_choix >= 0.0 else en_terre,
			_duree(ville.plantation_reste_mois(_fiche_fid, _mois))]
	elif _arbres_choix >= 0.0 and _arbres_choix > pct + 0.01:
		var cible := _arbres_choix / 100.0 * plafond
		_arbres_valeur.text = "%d arbres → %d · %s" % [en_terre,
			ville.arbres_a(_fiche_fid, cible), _duree(Ville.PLANTATION_MOIS)]
	elif en_terre >= tous:
		_arbres_valeur.text = "%d arbres · la rue est plantée de bout en bout" % en_terre
	else:
		_arbres_valeur.text = "%d arbres sur %d emplacements" % [en_terre, tous]


## Ce que l'objet courant a de posé, au format que `ville.commander` lit. UN
## SEUL endroit l'assemble : la miniature, le récapitulatif et la commande
## doivent parler du même réglage, sinon l'image promet autre chose que le prix.
func _reglages() -> Dictionary:
	var r: Dictionary = _pose.duplicate()
	if _fiche_couche == "i" and _solaire_choix >= 0.0:
		var actuel := ville.valeur("i", _fiche_fid, "part_toit_equipe", _mois) * 100.0
		if _solaire_choix > actuel + 0.01:
			r["solaire"] = _solaire_choix / 100.0
	if _fiche_couche == "i" and _vert_choix >= 0.0:
		var actuel_v := ville.valeur("i", _fiche_fid, "part_toit_vert", _mois) * 100.0
		if _vert_choix > actuel_v + 0.01:
			r["vert"] = _vert_choix / 100.0
	# 🏢 La densification part du curseur, et les boutons ne portent que la
	# hauteur : `dense` est un couple, pas un nombre d'étages.
	if _fiche_couche == "i":
		r.erase("dense")
		var ed := ville.etat_dense(_fiche_fid, _mois)
		if _dense_choix > float(ed["montes"]) + 0.01 and not ed["en_cours"]:
			r["dense"] = {
				"part": _dense_choix / maxf(float(ed["batiments"]), 1.0),
				"etages": _dense_etages(),
			}
	# 🅿️ Fermer aux voitures emporte les places : les deux réglages
	# ensemble feraient deux lignes de récapitulatif pour un seul chantier.
	if r.has("axe"):
		r.erase("places")
	if _fiche_couche == "r" and _arbres_choix >= 0.0:
		var cible := _arbres_choix / 100.0 * Ville.PLANTATION_CANOPEE_MAX
		if ville.arbres_a(_fiche_fid, cible) > ville.arbres_a(
				_fiche_fid, ville.valeur("r", _fiche_fid, "canopee", _mois)):
			r["arbres"] = cible
	return r


## Une bascule : reposer le même réglage l'enlève. C'est ce qui rend l'essai
## réversible — et la berge est exclusive, un seul état visé à la fois.
func _basculer(cle: String, valeur) -> void:
	if _pose.get(cle) == valeur:
		_pose.erase(cle)
	else:
		_pose[cle] = valeur
	_maj_fiche()


## Changer d'objet, ou avoir commandé : rien ne se garde. Un réglage posé sur
## l'îlot 32 qui survivrait au clic sur le 33 se paierait sur le mauvais toit.
func _vider_pose() -> void:
	_pose.clear()
	_solaire_choix = -1.0
	_vert_choix = -1.0
	_arbres_choix = -1.0
	_dense_choix = -1.0
	_apercu_avant = false


func _mettre_en_place() -> void:
	var r := _reglages()
	if r.is_empty():
		return
	commande_demandee.emit(_fiche_couche, _fiche_fid, r)


## 🔴 LE RÉCAPITULATIF, et le seul refus du jeu. Il porte le total de TOUS les
## réglages posés : le prix se calcule dans le noyau (`cout_commande_ke`), pas
## ici — deux additions dans deux fichiers finissent par diverger.
func _maj_recap() -> void:
	var r := _reglages()
	_recap_bloc.visible = not r.is_empty()
	# Les deux boutons de la miniature n'ont de sens que si les deux images
	# diffèrent : un réglage posé, ou un chantier qui court.
	var chantier: Dictionary = ville.chantier(_fiche_couche, _fiche_fid, _mois)
	_apercu_boutons.visible = _apercu_cadre.visible \
		and (not r.is_empty() or bool(chantier["actif"]))
	if not _apercu_boutons.visible:
		_apercu_avant = false
	_avant_bouton.disabled = _apercu_avant
	_apres_bouton.disabled = not _apercu_avant
	if r.is_empty():
		_alerter_cout(false)
		return
	var cout := ville.cout_commande_ke(_fiche_couche, _fiche_fid, r, _mois)
	var duree := ville.duree_commande_mois(_fiche_couche, _fiche_fid, r, _mois)
	var manque := cout - _caisse_ke
	# « 3 réglages » ne dit rien ; les nommer, si. C'est la phrase qu'on relit
	# avant d'engager trois ans de dotation.
	var quoi := []
	if r.has("solaire"):
		quoi.append("panneaux %d %%" % int(roundf(float(r["solaire"]) * 100.0)))
	if r.has("vert"):
		quoi.append("toit vert %d %%" % int(roundf(float(r["vert"]) * 100.0)))
	if r.has("arbres"):
		quoi.append("%d arbres" % (ville.arbres_a(_fiche_fid, float(r["arbres"]))
			- ville.arbres_a(_fiche_fid,
				ville.valeur("r", _fiche_fid, "canopee", _mois))))
	if r.has("dense"):
		var e := int(r["dense"]["etages"])
		var ed := ville.etat_dense(_fiche_fid, _mois)
		var de := float(ed["montes"]) / maxf(float(ed["batiments"]), 1.0)
		quoi.append("%d bâtiments à +%d étage%s, %d logements" % [
			int(roundf(float(r["dense"]["part"]) * float(ed["batiments"])
				- float(ed["montes"]))),
			e, "s" if e > 1 else "",
			int(roundf(ville.dense_logements_tranche(_fiche_fid, de,
				float(r["dense"]["part"]), e)))])
	if r.has("places"):
		quoi.append("places retirées")
	if r.has("axe"):
		quoi.append("fermeture aux voitures, places retirées"
			if ville.valeur("r", _fiche_fid, "stationnement", _mois) >= 0.5
			else "fermeture aux voitures")
	if r.has("berge"):
		quoi.append(Ville.BERGE_NOMS[int(r["berge"])])
	if r.has("camp"):
		# 🌾 Le récapitulatif porte les DEUX prix : celui de la caisse est sur
		# le bouton, celui du champ ici.
		quoi.append("%d logements · %d places, %s personnes nourries en moins" % [
			ville.camp_taille(_fiche_fid, _mois),
			ville.camp_taille(_fiche_fid, _mois) * Ville.CAMP_PERSONNES_LOGEMENT,
			_nb(ville.champ_nourriture(_fiche_fid), 0)])
	if r.has("reparer"):
		quoi.append("pont provisoire" if str(r["reparer"]) == "provisoire" else
			_verbe_reparation(_fiche_couche, ville.objets(_fiche_couche).get(_fiche_fid, {})).to_lower())
	var phrase := ", ".join(quoi)
	# Le prix est sur le bouton et nulle part ailleurs : deux fois le même
	# nombre à deux lignes d'écart se lit comme deux nombres.
	_recap_texte.text = "%s · %s · %s" % [
		phrase.substr(0, 1).to_upper() + phrase.substr(1),
		_duree(duree),
		("manque %s k€" % _milliers(manque)) if manque > 0.001
			else ("reste %s k€" % _milliers(_caisse_ke - cout))]
	_recap_bouton.text = "Mettre en place · %s k€" % _milliers(cout)
	_recap_bouton.disabled = manque > 0.001
	_alerter_cout(manque > 0.001)


## Ce que le curseur solaire annonce. 🔄 Le prix et le refus ont quitté cette
## fonction le 2026-08-31 : ils sont dans le récapitulatif, où ils portent aussi
## les autres réglages.
func _afficher_choix(actuel: float, cible: float) -> void:
	# 🪜 LE REMBOURSEMENT DE LA TRANCHE QU'ON POSE, et c'est là que la
	# progressivité se voit : sur le même toit, les premiers pour cent se
	# remboursent deux fois plus vite que les derniers.
	var ans := Energie.rentabilite_tranche_annees(ville, _fiche_fid,
		actuel / 100.0, cible / 100.0, _mois)
	_solaire_valeur.text = "%d %% → %d %% · %s%s" % [
		int(roundf(actuel)), int(roundf(cible)),
		_duree(ville.duree_solaire_mois(actuel / 100.0, cible / 100.0)),
		"" if is_inf(ans) else " · remboursé en %d ans" % int(roundf(ans))]


## 🔎 CE QUE LA MINIATURE DOIT MONTRER (décision 12) : l'ÉTAT QUI SERA LIVRÉ —
## les réglages posés devant le chantier engagé, lui-même devant l'état réel.
## Survoler un bouton montre en plus ce qu'il livrerait, avant qu'on le presse.
## 🔎 SAUF EN MODE « AVANT », où elle montre la ville d'aujourd'hui, réglages
## ignorés : c'est la moitié gauche de la comparaison.
## Lu à chaque image par `maquette._maj_apercu` : ne rien y calculer de lourd.
func apercu_demande() -> Dictionary:
	var equipe := 0.0
	var verdi := 0.0
	var plate := 0.0
	var futur := false
	var berge := 0.0
	var places := true
	var roule := true
	var arbres := 0.0
	# 🏕️ Le nombre d'abris que la miniature doit poser sur le champ.
	var camp := 0
	# 🏢 (avancement, part d'un bâtiment, mètres) — ce que le shader attend.
	# ⚠️ Un Vector4, pas une Color : une couleur passerait en espace linéaire.
	var dense := Vector4(0.0, 1.0, 0.0, 0.0)
	if _fiche_fid < 0:
		return {"couche": _fiche_couche, "fid": _fiche_fid, "equipe": equipe,
			"verdi": verdi, "plate": plate,
			"futur": futur, "berge": berge, "places": places, "roule": roule,
			"arbres": arbres, "dense": dense, "camp": camp}
	var r: Dictionary = {} if _apercu_avant else _reglages()
	if _fiche_couche == "i":
		equipe = ville.valeur("i", _fiche_fid, "part_toit_equipe", _mois)
		verdi = ville.valeur("i", _fiche_fid, "part_toit_vert", _mois)
		plate = ville.valeur("i", _fiche_fid, "_part_plate", _mois)
		var ed := ville.etat_dense(_fiche_fid, _mois)
		dense = Vector4(float(ed["avancement"]), float(ed["pas"]),
			float(ed["metres"]), 0.0)
		if not _apercu_avant:
			equipe = maxf(ville.etat_solaire(_fiche_fid, _mois)["cible"],
				float(r.get("solaire", 0.0)))
			verdi = maxf(ville.etat_vert(_fiche_fid, _mois)["cible"],
				float(r.get("vert", 0.0)))
			# 🏢 La miniature promet l'état LIVRÉ : les bâtiments VISÉS déjà
			# montés, pas la moitié d'un chantier. 🪜 Et « visés » n'est plus
			# « tous » — c'est le cran du curseur, sinon l'image promet un îlot
			# entier pour le prix de trois toits.
			var e := int(ed["etages"])
			var vise := float(ed["cible"])
			if r.has("dense"):
				e = int(r["dense"]["etages"])
				vise = maxf(vise, float(r["dense"]["part"]))
			if e > 0 and vise > 0.0:
				dense = Vector4(vise, float(ed["pas"]),
					float(e) * Ville.DENSE_ETAGE_M, 0.0)
		# 🏕️ LE CAMP DANS LA MINIATURE (auteur, 2026-09-18) : il manquait, et
		# c'était le seul chantier qu'on payait sans l'avoir vu. Même règle que
		# les autres réglages — au survol du bouton comme une fois posé — et en
		# AVANT, seul le camp déjà livré.
		if ville.camp_possible(_fiche_fid):
			if ville.camp_pose(_fiche_fid):
				if not _apercu_avant or ville.camp_livre(_fiche_fid, _mois):
					camp = ville.camp_taille(_fiche_fid, _mois)
			elif not _apercu_avant and (r.has("camp")
					or (not _camp_bouton.disabled and _camp_bouton.is_hovered())):
				camp = ville.camp_taille(_fiche_fid, _mois)
	if _fiche_couche != "b":
		futur = not _apercu_avant \
			and (ville.reparation_finie(_fiche_couche, _fiche_fid, _mois)
				or r.has("reparer") or _repare_bouton.is_hovered()
				or _repare_provisoire.is_hovered())
		if _apercu_avant:
			futur = ville.reparation_finie(_fiche_couche, _fiche_fid, _mois)
	# 🌉 Quel pont la miniature promet : le choix posé, sinon le bouton survolé.
	var provisoire := _fiche_couche == "r" and ville.pont_provisoire(_fiche_fid)
	if _fiche_couche == "r" and not _apercu_avant:
		if _repare_provisoire.is_hovered() or _repare_bouton.is_hovered():
			provisoire = _repare_provisoire.is_hovered()
		elif r.has("reparer"):
			provisoire = str(r["reparer"]) == "provisoire"
	if _fiche_couche == "b":
		var e := ville.berge_etat(_fiche_fid, _mois) if _apercu_avant \
			else ville.berge_cible(_fiche_fid)
		if not _apercu_avant:
			e = maxi(e, int(r.get("berge", 0)))
			for k in _berge_boutons.size():
				if (_berge_boutons[k] as Button).is_hovered():
					e = k + Ville.BERGE_APAISEE
		# La même règle que la ville : une berge de campagne naît renaturée, et la
		# teinte dit un CHANGEMENT, pas un état.
		berge = 0.0 if e == ville.berge_depart(_fiche_fid) else float(e)
	if _fiche_couche == "r":
		# La bordure se vide et la chaussée aussi — au survol comme une fois le
		# réglage posé. Un bouton grisé, lui, ne promet rien.
		places = ville.valeur("r", _fiche_fid, "stationnement", _mois) >= 0.5
		roule = trafic == null or not trafic.axe_ferme(_fiche_fid)
		if not _apercu_avant:
			places = places and not r.has("places") \
				and (_trafic_stationnement.disabled
					or not _trafic_stationnement.is_hovered())
			roule = roule and not r.has("axe") \
				and (_trafic_axe.disabled or not _trafic_axe.is_hovered())
		# 🅿️ La règle, en une ligne : pas de voitures, pas de places. Au
		# survol du bouton de fermeture comme une fois le réglage posé.
		places = places and roule
		# 🌳 La canopée du moment, ou celle que la commande livrerait : c'est
		# elle qui décide combien d'arbres l'échantillon plante.
		arbres = ville.valeur("r", _fiche_fid, "canopee", _mois)
		if not _apercu_avant:
			arbres = maxf(arbres, float(r.get("arbres", 0.0)))
	return {"couche": _fiche_couche, "fid": _fiche_fid, "equipe": equipe,
		"verdi": verdi, "plate": plate,
		"futur": futur, "berge": berge, "places": places, "roule": roule,
		"arbres": arbres, "dense": dense, "camp": camp, "provisoire": provisoire}


## ⚠️ Appelé à chaque image : reposer un `theme_color_override` identique fait
## retraiter le thème du Label pour rien.
func _alerter_cout(alerte: bool) -> void:
	if alerte == _cout_en_alerte:
		return
	_cout_en_alerte = alerte
	_recap_texte.add_theme_color_override("font_color", ALERTE if alerte else GRIS)


## Les trois entrées de l'essai automatisé. Elles passent toutes par le chemin
## d'un doigt — `value_changed` pour un curseur, `_basculer` pour une bascule :
## la capture prouve ce que le joueur verra, pas ce que le code croit.
func viser(pct: float) -> void:
	_solaire_curseur.value = pct


func viser_vert(pct: float) -> void:
	_vert_curseur.value = pct


func viser_arbres(pct: float) -> void:
	_arbres_curseur.value = pct


## 🏢 En BÂTIMENTS. Lu par `--essai`, qui pose un cran puis un autre pour
## montrer que le premier coûte moins cher que le dernier.
func viser_dense(batiments: int) -> void:
	_dense_curseur.value = float(batiments)


## ⚠️ `valeur` N'EST PAS UN BOOLÉEN. Écrite `valeur := true`, elle était typée
## bool par inférence : `poser("dense", 2)` posait 1, et la capture d'essai
## annonçait deux étages en en montrant un. Corrigé le 2026-09-03.
func poser(cle: String, valeur: Variant = true) -> void:
	_basculer(cle, valeur)


func regarder_avant(avant: bool) -> void:
	_apercu_avant = avant
	_maj_fiche()


func _sur_curseur(v: float) -> void:
	if _fiche_fid < 0 or _ecrit_curseur:
		return
	var actuel := ville.valeur("i", _fiche_fid, "part_toit_equipe", _mois) * 100.0
	# Déposer des panneaux n'est pas une décision de ce prototype (`Énergie` §1).
	# Rattrapé ici plutôt qu'en montant `min_value`, pour garder l'échelle fixe.
	# 🌿 Deux rattrapages et non un : on ne DÉPLANTE pas de panneaux, et on ne
	# pose rien sur un mètre carré que les toits verts ont déjà pris.
	var plafond := ville.part_solaire_max(_fiche_fid, _mois) * 100.0
	if _vert_choix >= 0.0:
		plafond = minf(plafond, 100.0 - _vert_choix)
	v = clampf(v, actuel, maxf(plafond, actuel))
	if not is_equal_approx(v, _solaire_curseur.value):
		_ecrit_curseur = true
		_solaire_curseur.set_value_no_signal(v)
		_ecrit_curseur = false
	_solaire_choix = v
	_solaire_jauge.regler(actuel / 100.0, v / 100.0)
	_afficher_choix(actuel, v)
	_maj_recap()


## 🌿 Le curseur des toits verts. Même règle que le solaire, plus le plafond de
## la pente : un substrat ne tient pas sur un versant.
func _sur_curseur_vert(v: float) -> void:
	if _fiche_fid < 0 or _ecrit_curseur:
		return
	var actuel := ville.valeur("i", _fiche_fid, "part_toit_vert", _mois) * 100.0
	var plafond := ville.part_vert_max(_fiche_fid, _mois) * 100.0
	if _solaire_choix >= 0.0:
		plafond = minf(plafond, 100.0 - _solaire_choix)
	v = clampf(v, actuel, maxf(plafond, actuel))
	if not is_equal_approx(v, _vert_curseur.value):
		_ecrit_curseur = true
		_vert_curseur.set_value_no_signal(v)
		_ecrit_curseur = false
	_vert_choix = v
	_vert_jauge.regler(actuel / 100.0, v / 100.0)
	_maj_recap()


## 🏢 Le curseur de la densification. Même règle que les trois autres — on ne
## DÉMOLIT pas un étage —, à ceci près qu'il compte des bâtiments entiers.
func _sur_curseur_dense(v: float) -> void:
	if _fiche_fid < 0 or _ecrit_curseur:
		return
	var etat := ville.etat_dense(_fiche_fid, _mois)
	v = clampf(roundf(v), float(etat["montes"]), float(etat["batiments"]))
	if not is_equal_approx(v, _dense_curseur.value):
		_ecrit_curseur = true
		_dense_curseur.set_value_no_signal(v)
		_ecrit_curseur = false
	_dense_choix = v
	_maj_fiche()


## 🌳 Le curseur des arbres. Même règle que le solaire : on ne DÉPLANTE pas, et
## le rattrapage se fait ici pour garder une échelle fixe de bout en bout.
func _sur_curseur_arbres(v: float) -> void:
	if _fiche_fid < 0 or _ecrit_curseur:
		return
	var plafond := Ville.PLANTATION_CANOPEE_MAX
	var actuel := ville.valeur("r", _fiche_fid, "canopee", _mois) / plafond * 100.0
	if v < actuel:
		v = actuel
		_ecrit_curseur = true
		_arbres_curseur.set_value_no_signal(v)
		_ecrit_curseur = false
	_arbres_choix = v
	_arbres_jauge.regler(actuel / 100.0, v / 100.0)
	_maj_recap()


## Après un retour au mois 0 : réglages posés et compte rendu périmés.
func remis_a_zero() -> void:
	_vider_pose()
	_fermer_lieu()
	_message.text = "Retour au mois 0, caisse à %s k€." \
		% _milliers(Ville.CAISSE_DEPART_KE)
	if _fiche_fid >= 0:
		_maj_fiche()


## Le compte rendu d'une commande partie. 🔄 S'appelait `confirmer_solaire` et
## ne parlait que des panneaux ; elle vaut pour les cinq réglages depuis le
## 2026-08-31. Le nom reste : `--essai` l'appelle.
func confirmer_solaire(_cout_ke := 0.0) -> void:
	_vider_pose()   # la commande est partie : la fiche reprend la main
	_message.text = "" # Le constat reste dans la notification et le journal de son lieu.
	_maj_fiche()


static func _duree(mois: float) -> String:
	if mois < 1.0:
		var j := int(ceil(mois * 30.0))
		return "1 jour" if j <= 1 else "%d jours" % j
	# Le dixième ne s'écrit que s'il n'est pas nul : « 6,0 mois » annonce une
	# précision qu'on n'a pas.
	return "%s mois" % _nb(mois, 0 if is_equal_approx(mois, roundf(mois)) else 1)


static func _nb(v: float, dec: int) -> String:
	return (("%%.%df" % dec) % v).replace(".", ",")


## Avec l'espace des milliers : la caisse passe les 10 000 k€ en vingt ans, et
## « 10240 » se lit de travers.
static func _milliers(v: float) -> String:
	var s := "%d" % int(roundf(absf(v)))
	var out := ""
	for i in s.length():
		if i > 0 and (s.length() - i) % 3 == 0:
			out += " "
		out += s[i]
	return ("−" if v < -0.5 else "") + out


# ------------------------------------------------- après la crue (04e · 23b)

## La fiche d'une rue. Elle n'a qu'un sujet : ce que la crue lui a fait.
## La barre du haut de fiche. Elle vaut pour les trois couches : c'est
## `ville.chantier` qui sait lequel des chantiers de l'objet finit le dernier.
func _maj_chantier() -> void:
	var c := ville.chantier(_fiche_couche, _fiche_fid, _mois)
	_chantier_bloc.visible = bool(c["actif"])
	if not _chantier_bloc.visible:
		return
	_chantier_quoi.text = CHANTIER_MOTS.get(str(c["quoi"]), "Chantier")
	_chantier_reste.text = "encore %s" % _duree(float(c["reste_mois"]))
	var part := float(c["part"])
	_chantier_jauge.regler(part, part)


func _maj_fiche_rue() -> void:
	var o: Dictionary = ville.routes.get(_fiche_fid, {})
	if o.is_empty():
		return
	_titre_lieu("r")
	var etat := str(o.get("etat_crue", "intact"))
	if ville.est_repare("r", _fiche_fid):
		etat = "repare"
	_fiche_soustitre.text = "pont" if _fiche_fid in ville.ponts_coupes() \
		else str(o.get("hierarchie", "?"))
	# 🚗 CE QU'UNE RUE REND, c'est le trafic qu'elle porte : c'est lui qui decide
	# si la fermer se paie, et il est le seul chiffre de sa ligne du haut.
	_maj_resume("trafic", "%d %% de trafic" % int(roundf(
		ville.trafic_vu(_fiche_fid, _mois) * 100.0)))
	(_rue_valeurs["largeur"] as Label).text = "%s m" % _nb(
		float(o.get("largeur_m", 0.0)), 0)
	(_rue_valeurs["places"] as Label).text = _nb(
		ville.valeur("r", _fiche_fid, "stationnement", _mois), 0)
	_bloc_dispo[_trafic_bloc] = true
	var stationnement_engage := ville.stationnement_en_suppression(_fiche_fid)
	var axe_ferme: bool = trafic != null and trafic.axe_ferme(_fiche_fid)
	var stationnement_fini := stationnement_engage and ville.valeur(
		"r", _fiche_fid, "stationnement", _mois) < 0.5
	var a_des_places := ville.valeur("r", _fiche_fid, "stationnement", _mois) >= 0.5
	# 🅿️ Le bouton s'efface derriere la fermeture, qui emporte deja les places.
	var emportees: bool = _pose.has("axe") and a_des_places
	_trafic_stationnement.text = ("Places retirées" if stationnement_fini 		else "Places · 2 mois") if stationnement_engage 		else ("✓ Places emportées par la fermeture" if emportees 		else _posee("places", "Retirer les places"))
	_trafic_stationnement.disabled = stationnement_engage or emportees 		or not a_des_places
	_trafic_axe.text = ("Fermée · report" if trafic.report_en_cours(
		_fiche_fid, _mois) else "Fermée") if axe_ferme 		else _posee("axe", "Fermer aux voitures")
	_trafic_axe.disabled = axe_ferme or not ville.route_praticable(_fiche_fid, _mois) 		or ville.trafic_vu(_fiche_fid, _mois) < 0.20
	_maj_arbres()
	# 🌳 Le verger se NOMME sur la fiche : c'est là qu'on comprend pourquoi
	# la rue est vide. Déblayée, elle le reste tant que le quartier l'est.
	var boue := float(o.get("part_boue", 0.0))
	var sous_boue := boue > 0.0 and etat != "repare"
	(_rue_valeurs["etat"] as Label).text = {
		"coupe": "franchissement emporté",
		"fragile": "pile déchaussée",
		"repare": "verger déblayé" if boue > 0.0 else "remise en service",
	}.get(etat, "le verger · %d %% sous la boue" % int(roundf(boue * 100.0))
		if sous_boue else ("%s m d'eau" % _nb(float(o.get("hauteur_eau", 0.0)), 1)
		if float(o.get("hauteur_eau", 0.0)) > 0.1 else "intacte"))
	if etat == "repare" and _fiche_fid in ville.ponts_coupes():
		(_rue_valeurs["etat"] as Label).text = ("liaison provisoire" if ville.pont_provisoire(_fiche_fid)
			else "liaison ouverte") if trafic.pont_fonctionnel(_fiche_fid, _mois) \
			else "pont livré · accès coupé"
	_maj_reparation(o)
	_maj_recap()


## 🌊 LA FICHE D'UNE BERGE. Le bloc de réparation ne s'ouvre pas ici : la crue
## n'a rien chiffré sur une berge, et un bouton grisé de plus n'apprendrait rien.
func _maj_fiche_berge() -> void:
	var o: Dictionary = ville.berges.get(_fiche_fid, {})
	if o.is_empty():
		return
	var etat := ville.berge_etat(_fiche_fid, _mois)
	_titre_lieu("b")
	# Le nom de la berge porte déjà sa rive : un sous-titre la répéterait.
	_fiche_soustitre.text = ""
	# 🌊 CE QU'UNE BERGE REND, c'est sa longueur : c'est elle qu'on paie au metre.
	_maj_resume("eau", "%s m de berge" % _nb(float(o.get("longueur_m", 0.0)), 0))
	(_berge_valeurs["mur"] as Label).text = "%s m" % _nb(
		float(o.get("mur_m", 0.0)), 0)
	(_berge_valeurs["rive"] as Label).text = "%s m" % _nb(
		float(o.get("rive_m", 0.0)), 1)
	var rues: Array = o.get("rues", [])
	(_berge_valeurs["rues"] as Label).text = "aucune" if rues.is_empty() 		else "%d" % rues.size()
	# 🌊 CE QU'ELLE RACHETE. Le bief se lit en ilots, pas en fil d'eau : « 7
	# ilots » decide, « 0,31 a 0,61 » n'est qu'une coordonnee.
	var bief: Array = ville.ilots_du_bief(_fiche_fid)
	(_berge_valeurs["bief"] as Label).text = "aucun îlot exposé" if bief.is_empty() 		else "%d îlot%s, dont le %d" % [bief.size(),
			"s" if bief.size() > 1 else "", int(bief[0])]
	var pire := 0.0
	for f in bief:
		pire = maxf(pire, ville.valeur("i", int(f), "hauteur_eau_annonce", _mois))
	(_berge_valeurs["crue"] as Label).text = "%s m" % _nb(pire, 2)
	var reste := ville.berge_reste_mois(_fiche_fid, _mois)
	# 🔎 L'état RÉALISÉ, et lui seul : la barre du haut de fiche porte déjà le
	# chantier en cours et ce qu'il reste à attendre.
	(_berge_valeurs["etat"] as Label).text = Ville.BERGE_NOMS[etat]

	if etat == Ville.BERGE_RENATUREE:
		_berge_texte.text = "Rive rendue au fleuve. Rien à démolir ici." 			if float(o.get("mur_m", 0.0)) <= 1.0 			else "Berge renaturée. Aucun retour en arrière."
	elif reste > 0.0:
		_berge_texte.text = ""   # la barre du haut de fiche le dit déjà
	else:
		_berge_texte.text = "%s m de quai minéral séparent la chaussée de l'Ilse." 			% _nb(float(o.get("rive_m", 0.0)), 1)
	_berge_texte.visible = _berge_texte.text != ""
	for k in _berge_boutons.size():
		var cible: int = Ville.BERGE_APAISEE + k
		var bouton: Button = _berge_boutons[k]
		var cout := ville.cout_berge_ke(_fiche_fid, cible, _mois)
		var nom: String = Ville.BERGE_NOMS[cible]
		bouton.disabled = cible <= etat or reste > 0.0
		# ⚠️ Pas de `capitalize()` : il met une majuscule à CHAQUE mot, et le
		# bouton sortait « Quai Apaisé ».
		var titre := nom.substr(0, 1).to_upper() + nom.substr(1)
		if cible <= etat:
			bouton.text = "%s · fait" % titre
		else:
			# 🌊 Le prix seul ne dit rien : c'est la baisse de crue qui fait
			# choisir entre finir un bief et effleurer les quatre.
			var gagne := (ville.berge_largeur_rendue_m(_fiche_fid, cible)
				- ville.berge_largeur_rendue_m(_fiche_fid, etat)) \
				* Ville.BERGE_BAISSE_M_PAR_M
			bouton.text = _posee("berge", "%s · %s k€ · %s · crue −%s m" % [titre,
				_milliers(cout),
				_duree(Ville.BERGE_MOIS[cible] - Ville.BERGE_MOIS[etat]),
				_nb(gagne, 2)], cible)
	_maj_recap()


## LE BLOC DE RÉPARATION, et c'est le seul endroit où le jeu dit non deux fois :
## une fois parce que la caisse ne suit pas, une fois parce qu'il n'y a rien à
## réparer. Un bouton grisé sans phrase est une panne ; sous « il manque 214 k€ »
## c'est une règle.
func _maj_reparation(o: Dictionary) -> void:
	var couche := _fiche_couche
	var pont := couche == "r" and _fiche_fid in ville.ponts_coupes()
	_maj_acces(pont)
	_repare_provisoire.visible = false
	var prix := float(o.get("cout_reparation_ke", 0.0))
	if prix <= 0.0:
		_bloc_dispo[_repare_bloc] = false
		return
	_bloc_dispo[_repare_bloc] = true
	var fini: bool = ville.reparation_finie(couche, _fiche_fid, _mois)
	var engage: bool = ville.est_repare(couche, _fiche_fid)
	var verbe := _verbe_reparation(couche, o)
	if fini:
		_repare_texte.text = "Remis en état."
		if pont:
			_repare_texte.text = ouverture.description_pont(_fiche_fid) if ouverture != null else "Pont reconstruit."
		_repare_bouton.text = "Terminé"
		_repare_bouton.disabled = true
		return
	if engage:
		# La barre du haut de fiche dit déjà le temps qui reste.
		_repare_texte.text = ""
		if pont and ouverture != null:
			_repare_texte.text = ouverture.description_pont(_fiche_fid)
		_repare_bouton.text = "Pont provisoire en cours" if pont and ville.pont_provisoire(_fiche_fid) \
			else "Chantier en cours"
		_repare_bouton.disabled = true
		return
	# 🔄 Le prix ne dit plus non ici depuis le 2026-08-31 : le refus est dans le
	# récapitulatif, où il porte le TOTAL. Réparer et poser des panneaux séparément
	# tenaient dans la caisse ; ensemble, non — et seul le total peut le dire.
	var phrase := "%s · %s k€ · %s." % [
		verbe, _milliers(prix),
		_duree(ville.duree_reparation_mois(couche, _fiche_fid))]
	_repare_texte.text = _degat_en_clair(couche, o) + "  " + phrase
	if couche == "r" and str(o.get("etat_crue", "")) == "coupe" and ouverture != null:
		# Le dégât est déjà dans la grille ; le pont et ses accès font un seul prix.
		_repare_texte.text = ouverture.description_pont(_fiche_fid)
		var manque: float = maxf(0.0, prix - ville.caisse_ke(_mois))
		if manque > 0.0:
			_repare_texte.text += "\nÀ épargner : %s k€." % _milliers(manque)
	_repare_bouton.text = _posee("reparer", "%s · %s k€" % [verbe, _milliers(prix)])
	_repare_bouton.disabled = false
	if pont:
		# 🌉 DEUX CHOIX, jamais les deux (auteur, 2026-09-24) : vite et sur une
		# voie, ou en dur et plus long. Reposer l'autre remplace le premier.
		_repare_bouton.text = _posee("reparer", "%s · %s k€ · %s" % [verbe, _milliers(prix),
			_duree(ville.duree_reparation_mois(couche, _fiche_fid))])
		_repare_provisoire.visible = true
		_repare_provisoire.text = _posee("reparer", "Pont provisoire · %s k€ · %s" % [
			_milliers(ville.cout_reparation_ke(couche, _fiche_fid, true)),
			_duree(ville.duree_reparation_mois(couche, _fiche_fid, true))], "provisoire")


func _maj_acces(pont: bool) -> void:
	_acces_boutons.visible = pont and ouverture != null
	if not _acces_boutons.visible:
		return
	var acces: Dictionary = trafic.acces_pont(_fiche_fid, _mois)
	var signature := "%s/%s" % [_fiche_fid, acces["obstacles"]]
	if _acces_boutons.get_meta("signature", "") == signature:
		return
	_acces_boutons.set_meta("signature", signature)
	for enfant in _acces_boutons.get_children():
		_acces_boutons.remove_child(enfant)
		enfant.queue_free()
	var voir := Button.new()
	voir.text = "Voir les accès"
	voir.pressed.connect(ouverture.voir_acces.bind(_fiche_fid))
	_acces_boutons.add_child(voir)
	for fid in acces["obstacles"]:
		var b := Button.new()
		b.text = "Examiner · " + lieux.nom("r", fid)
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.pressed.connect(ouverture.examiner.bind("r", fid))
		_acces_boutons.add_child(b)


## 🏕️ LE BLOC DU RELOGEMENT. Il ne dit jamais non : un champ inaccessible se
## pose et se paie, et l'avertissement est au-dessus du bouton. L'erreur coûte
## du temps et de l'argent, elle ne ferme aucune porte — un pont réparé
## remplira le camp plus tard.
## 🌾 CE QUE LE CHAMP NOURRIT, ET CE QU'IL NOURRIRA APRÈS : la même phrase
## avant et après la pose, pour que le joueur retrouve ce qu'il a payé.
func _champ_perdu(fid: int) -> String:
	var nourris := ville.champ_nourriture(fid)
	if nourris < 0.5:
		return "Ce champ ne nourrit personne."
	if ville.champ_cultive(fid, _mois):
		return "Il nourrit %s personnes, et ne sera plus jamais cultivé." % _nb(nourris, 0)
	return "Il ne nourrit plus ses %s personnes." % _nb(nourris, 0)


func _maj_camp() -> void:
	if _fiche_couche != "i" or not ville.camp_possible(_fiche_fid):
		_bloc_dispo[_camp_bloc] = false
		return
	_bloc_dispo[_camp_bloc] = true
	var fid := _fiche_fid
	if ville.camp_pose(fid):
		var occupants: float = ville.camp_occupants(fid, _mois)
		if not ville.camp_livre(fid, _mois):
			_camp_texte.text = "Les containers arrivent · %s" % _duree(
				ville.camp_reste_mois(fid, _mois))
			_camp_bouton.text = "Chantier en cours"
		elif ville.camp_accessible(fid, _mois):
			_camp_texte.text = "%d containers · %d personnes accueillies.\n%s" % [
				int(ville.camp_taille(fid, _mois)), int(occupants),
				_champ_perdu(fid)]
			_camp_bouton.text = "Camp en place"
		else:
			# 🌉 Le camp promis, et personne dedans. Ce n'est pas une panne :
			# c'est la carte, et elle peut encore changer.
			_camp_texte.text = "Camp vide : aucun pont ne mène ici. Rebâtir un pont le remplira."
			_camp_bouton.text = "Personne ne peut y venir"
		_camp_bouton.disabled = true
		return
	# Sur les places COMMANDÉES : un second champ ne se propose plus quand les
	# camps en route suffisent.
	var besoin: float = ville.besoin_non_couvert(_mois)
	if besoin <= 0.0:
		_camp_texte.text = "Tout le monde a une place."
		_camp_bouton.text = "Rien à reloger"
		_camp_bouton.disabled = true
		return
	var places: int = ville.camp_taille(fid, _mois)
	var maxi: int = ville.camp_capacite(fid)
	# Le nombre de sinistrés est déjà au compteur : la fiche dit ce que le champ tient.
	var phrase := "Accueille %d personnes : %d containers de %d places." % [
		maxi, ville.camp_places_max(fid), Ville.CAMP_PERSONNES_LOGEMENT]
	# 🌾 LE PRIX QUI N'EST PAS EN k€, annoncé avant le bouton : le camp prend
	# le champ entier, et la campagne ne le récupère pas.
	phrase += "\n%s" % _champ_perdu(fid)
	if not ville.camp_accessible(fid, _mois):
		phrase += "\n⚠ Les ponts sont coupés : personne ne pourra y aller."
	_camp_texte.text = phrase
	_camp_bouton.text = _posee("camp", "Installer %d containers · %s k€" % [
		places, _milliers(ville.cout_camp_ke(fid, _mois))])
	_camp_bouton.disabled = false


func _verbe_reparation(couche: String, o: Dictionary) -> String:
	if couche == "i":
		return "Reconstruire l'îlot"
	if str(o.get("etat_crue", "")) == "coupe":
		return "Rebâtir en dur"
	return "Déblayer la rue"

## Ce que la crue a pris à CET objet, en une phrase. Sans elle, le prix n'a
## pas de contrepartie et le joueur choisit à l'aveugle.
func _degat_en_clair(couche: String, o: Dictionary) -> String:
	if couche == "i":
		# 🌊 Par le noyau, pas par la fiche : une berge livrée en aval a pu
		# faire baisser ce pourcentage depuis l'export.
		var apres := int(roundf(100.0 * ville.valeur(
			"i", _fiche_fid, "part_ruinee_apres", _mois)))
		return "%d bâtiments détruits, %d logements perdus. La crue annoncée en reprendrait %d %%." % [
			int(o.get("batiments_ruines", 0)),
			int(o.get("logements_sinistres", 0)), apres]
	if str(o.get("etat_crue", "")) == "coupe":
		return "Le tablier est parti ; la rive gauche n'a plus d'accès routier."
	return "La rue a gardé %s m de limon." % _nb(
		float(o.get("hauteur_eau", 0.0)), 1)


## Ce que la crue coûte encore à la ville. Trois nombres, et ils baissent quand
## on répare : c'est la seule contrepartie visible d'une reconstruction tant que
## le budget ne dépend pas de `logements` (dette nommée du prototype).
func maj_degats(d: Dictionary) -> void:
	_degats = d
	if _degats_valeurs.is_empty():
		return
	(_degats_valeurs["logements"] as Label).text = _nb(
		float(d["logements_perdus"]), 0)
	(_degats_valeurs["ponts"] as Label).text = "%d sur 3" % int(
		d["franchissements_coupes"])
	(_degats_valeurs["reste"] as Label).text = _milliers(
		float(d["a_reparer_ke"])) + " k€"
	(_degats_valeurs["eau"] as Label).text = "%s m" % _nb(
		float(d.get("eau_prochaine_m", 0.0)), 2)
