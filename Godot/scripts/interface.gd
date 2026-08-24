extends CanvasLayer
# L'interface du prologue climatique : adaptation, puis réduction.
# Tant que l'urgence tient, aucune décision solaire n'apparaît ; les
# réparations font avancer la jauge d'adaptation.

signal solaire_demande(fid: int, part: float)
signal vitesse_demandee(vitesse: float)
signal temps_remis()
signal diagnostic_demande(actif: bool)
# 🔧 Une seule demande pour les trois réparations : reconstruire un îlot,
# déblayer une rue, rebâtir un tablier. C'est `04e` qui les distingue par le
# prix, pas l'interface.
signal reparation_demandee(couche: String, fid: int)
signal trafic_demande(action: String, fid: int)

const Ville := preload("res://scripts/ville.gd")

const FOND := Color(0.106, 0.118, 0.141, 0.94)
const BORD := Color(0.173, 0.192, 0.227)
const TEXTE := Color(0.902, 0.910, 0.925)
const GRIS := Color(0.604, 0.635, 0.694)
const ACCENT := Color(0.910, 0.769, 0.416)
# Le seul refus du prototype : la caisse ne suit pas. Un bouton grisé sans
# raison écrite est une panne, pas une règle.
const ALERTE := Color(0.878, 0.451, 0.376)


## Ce qui est POSÉ, et vers quoi ça va. Un `ProgressBar` ne montre qu'un
## nombre : il en faut deux pour distinguer « 40 % posés » de « 40 % en route
## vers 72 % ». Elle ne se touche pas — le réglage est le curseur d'en dessous.
class Jauge extends Control:
	const RESTE := Color(0.153, 0.169, 0.204)   # le toit encore nu
	const VISEE := Color(0.404, 0.349, 0.212)   # l'objectif demandé, pas encore atteint
	const POSE := Color(0.957, 0.867, 0.596)    # le jaune clair des panneaux réellement en place
	const CADRE := Color(0.290, 0.318, 0.373)   # le filet qui dessine la jauge quand elle est vide

	var pose := 0.0   # 0 → 1
	var cible := 0.0  # 0 → 1, toujours ≥ pose
	var couleur_reste := RESTE
	var couleur_visee := VISEE
	var couleur_pose := POSE
	var couleur_cadre := CADRE

	func colorer(rempli: Color, vide := RESTE) -> void:
		if rempli == couleur_pose and vide == couleur_reste:
			return
		couleur_pose = rempli
		couleur_visee = rempli.darkened(0.35)
		couleur_reste = vide
		queue_redraw()

	func regler(p: float, c: float) -> void:
		if is_equal_approx(p, pose) and is_equal_approx(c, cible):
			return  # ⚠️ appelé à chaque image : ne repeindre que sur un vrai changement
		pose = p
		cible = c
		queue_redraw()

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), couleur_reste)
		if cible > pose:
			draw_rect(Rect2(0.0, 0.0, size.x * cible, size.y), couleur_visee)
		if pose > 0.0:
			draw_rect(Rect2(0.0, 0.0, size.x * pose, size.y), couleur_pose)
		# Sans ce filet, une jauge à 0 % est un rectangle sombre de plus dans un
		# panneau sombre.
		draw_rect(Rect2(Vector2.ZERO, size), couleur_cadre, false, 1.0)


var ville: Ville
var trafic

var _ville_valeurs := {}
var _adaptation_jauge: Jauge
var _adaptation_valeur: Label
var _adaptation_etat: Label
var _reduction_jauge: Jauge
var _reduction_valeur: Label
var _reduction_etat: Label
var _fiche_valeurs := {}
var _fiche_titre: Label
var _fiche_vide: Label
var _fiche_grille: GridContainer
var _solaire_bloc: VBoxContainer
var _solaire_valeur: Label
var _solaire_cout: Label
var _solaire_curseur: HSlider
var _solaire_jauge: Jauge
var _solaire_bouton: Button
var _message: Label
var _camera_vue: Label
var _temps_label: Label
var _vitesses := {}
var _diagnostic_bouton: Button
var _diagnostic_panneau: PanelContainer
var _fiche_panneau: PanelContainer

var _fiche_fid := -1
var _fiche_couche := "i"
var _rue_grille: GridContainer
var _rue_valeurs := {}
var _repare_bloc: VBoxContainer
var _repare_texte: Label
var _repare_bouton: Button
var _trafic_bloc: VBoxContainer
var _trafic_stationnement: Button
var _trafic_axe: Button
var _degats := {}
var _degats_valeurs := {}
var _mois := 0.0
var _caisse_ke := Ville.CAISSE_DEPART_KE
var _cout_en_alerte := false
var _reduction_verrouillee := true

# La position posée par l'auteur et pas encore validée ; -1 = la fiche commande.
# ⚠️ Sans ce souvenir, `_maj_fiche()` (à chaque image) reposait la valeur sous
# le doigt et la barre était intraînable (défaut du 2026-08-17).
var _solaire_choix := -1.0
# Vrai pendant que la fiche écrit dans le curseur : une montée de `min_value`
# déplacerait la valeur et émettrait le signal, donc inventerait un choix.
var _ecrit_curseur := false


func batir() -> void:
	_panneau_ville()
	_panneau_ilot()
	_panneau_diagnostic()
	_panneau_camera()
	_controles_temps()


func _boite() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = FOND
	sb.border_color = BORD
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(12)
	return sb


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
	rempli.bg_color = Jauge.VISEE
	rempli.set_corner_radius_all(3)
	rempli.content_margin_top = 3.0
	rempli.content_margin_bottom = 3.0
	s.add_theme_stylebox_override("grabber_area", rempli)
	s.add_theme_stylebox_override("grabber_area_highlight", rempli)

	var poignee := _pastille(Jauge.POSE)
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


func _panneau_ville() -> void:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", _boite())
	p.offset_left = 16
	p.offset_top = 16
	p.custom_minimum_size = Vector2(245, 0)
	add_child(p)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	p.add_child(v)
	v.add_child(_label("WEHRAU", 12, ACCENT))
	v.add_child(_label("Toute la ville", 20, TEXTE))
	_diagnostic_bouton = Button.new()
	_diagnostic_bouton.text = "Diagnostic de crue"
	_diagnostic_bouton.toggle_mode = true
	_diagnostic_bouton.tooltip_text = "Voir le passage de la crue, les routes bloquées et les bâtiments touchés."
	_diagnostic_bouton.toggled.connect(func(actif: bool) -> void:
		diagnostic_demande.emit(actif))
	v.add_child(_diagnostic_bouton)
	v.add_child(HSeparator.new())
	v.add_child(_label("DURABILITÉ", 12, ACCENT))
	var adaptation := _jauge_climat(v, "Adaptation", Color8(38, 157, 196))
	_adaptation_jauge = adaptation["jauge"]
	_adaptation_valeur = adaptation["valeur"]
	_adaptation_etat = adaptation["etat"]
	var reduction := _jauge_climat(v, "Réduction", Color8(91, 174, 117))
	_reduction_jauge = reduction["jauge"]
	_reduction_valeur = reduction["valeur"]
	_reduction_etat = reduction["etat"]
	v.add_child(HSeparator.new())

	for ligne in [
		["conso", "Consommation"],
		["production", "Production solaire"],
		["achat", "Énergie achetée"],
		["co2", "CO₂"],
		# La petite économie APRÈS l'énergie : c'est elle qu'on transforme,
		# l'argent ne fait que limiter le rythme.
		["caisse", "Caisse"],
		["recette", "Recette solaire"],
	]:
		if ligne[0] == "caisse":
			v.add_child(HSeparator.new())
		var h := HBoxContainer.new()
		h.add_child(_label(ligne[1], 12, GRIS))
		var valeur := _label("", 14, TEXTE)
		valeur.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		valeur.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(valeur)
		_ville_valeurs[ligne[0]] = valeur
		v.add_child(h)

	# Le seul nombre de l'écran qui puisse dire non : couleur d'accent.
	(_ville_valeurs["caisse"] as Label).add_theme_color_override("font_color", ACCENT)


func _jauge_climat(parent: VBoxContainer, titre: String, couleur: Color) -> Dictionary:
	var h := HBoxContainer.new()
	h.add_child(_label(titre, 13, TEXTE))
	var valeur := _label("0 %", 13, TEXTE)
	valeur.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	valeur.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(valeur)
	parent.add_child(h)
	var jauge := Jauge.new()
	jauge.custom_minimum_size = Vector2(0, 13)
	jauge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	jauge.colorer(couleur)
	parent.add_child(jauge)
	var etat := _label("", 11, GRIS)
	etat.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(etat)
	return {"jauge": jauge, "valeur": valeur, "etat": etat}


func _panneau_diagnostic() -> void:
	_diagnostic_panneau = PanelContainer.new()
	_diagnostic_panneau.add_theme_stylebox_override("panel", _boite())
	_diagnostic_panneau.anchor_left = 0.5
	_diagnostic_panneau.anchor_right = 0.5
	_diagnostic_panneau.offset_left = -205
	_diagnostic_panneau.offset_right = 205
	_diagnostic_panneau.offset_top = 16
	_diagnostic_panneau.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_diagnostic_panneau.visible = false
	add_child(_diagnostic_panneau)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	_diagnostic_panneau.add_child(v)
	v.add_child(_label("DIAGNOSTIC DE CRUE", 12, ACCENT))
	v.add_child(_label("Ce que la crue a laissé dans la ville", 18, TEXTE))
	v.add_child(HSeparator.new())
	_legende_crue(v, Color8(38, 157, 196), "Passage de la crue · sols et rues noyés")
	_legende_crue(v, Color8(232, 126, 48), "Bâtiments touchés · sinistrés ou ruinés")
	_legende_crue(v, Color8(220, 58, 48), "Routes bloquées · franchissements coupés")
	v.add_child(HSeparator.new())
	# 🔧 CE QUE LA CRUE COÛTE ENCORE. Ces trois nombres BAISSENT quand on
	# répare : sans eux, reconstruire un îlot ne changerait rien de visible
	# ailleurs que sur cet îlot, et la décision n'aurait pas de contrepartie.
	for ligne in [
		["logements", "Logements perdus"],
		["ponts", "Franchissements coupés"],
		["reste", "Reste à réparer"],
	]:
		var h := HBoxContainer.new()
		h.add_child(_label(ligne[1], 12, GRIS))
		var val := _label("—", 14, TEXTE)
		val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		val.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(val)
		_degats_valeurs[ligne[0]] = val
		v.add_child(h)
	v.add_child(_label("D ou le bouton pour fermer", 11, GRIS))


func _legende_crue(parent: VBoxContainer, couleur: Color, texte: String) -> void:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	var carre := ColorRect.new()
	carre.color = couleur
	carre.custom_minimum_size = Vector2(12, 12)
	carre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(carre)
	h.add_child(_label(texte, 12, TEXTE))
	parent.add_child(h)


func afficher_diagnostic(actif: bool) -> void:
	_diagnostic_panneau.visible = actif
	_diagnostic_bouton.set_pressed_no_signal(actif)
	_fiche_panneau.visible = not actif


func _panneau_ilot() -> void:
	var p := PanelContainer.new()
	_fiche_panneau = p
	p.add_theme_stylebox_override("panel", _boite())
	p.anchor_left = 1.0
	p.anchor_right = 1.0
	p.offset_left = -336
	p.offset_right = -16
	p.offset_top = 16
	p.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	add_child(p)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	p.add_child(v)
	v.add_child(_label("ÎLOT CLIQUÉ", 12, ACCENT))
	_fiche_titre = _label("Aucun îlot", 20, TEXTE)
	v.add_child(_fiche_titre)
	_fiche_vide = _label("Clique un îlot pour voir ses informations et régler ses panneaux solaires.", 13, GRIS)
	_fiche_vide.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_fiche_vide)

	_fiche_grille = GridContainer.new()
	_fiche_grille.columns = 2
	_fiche_grille.add_theme_constant_override("h_separation", 14)
	_fiche_grille.add_theme_constant_override("v_separation", 4)
	v.add_child(_fiche_grille)
	for ligne in [
		["tissu", "Tissu"],
		["logements", "Logements"],
		["conso", "Consommation"],
		["production", "Production"],
		["toit", "Toit équipable"],
		# L'amortissement est une propriété de l'îlot, pas de la part visée
		# (`energie.rentabilite_annees`) : sa place est dans la grille.
		["retour", "Se rembourse en"],
	]:
		_fiche_grille.add_child(_label(ligne[1], 12, GRIS))
		var valeur := _label("", 12, TEXTE)
		valeur.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		_fiche_grille.add_child(valeur)
		_fiche_valeurs[ligne[0]] = valeur

	# 🔧 LA FICHE D'UNE RUE. Quatre lignes, et la seule qui compte est l'état :
	# c'est elle qui dit si le bloc du dessous propose un déblaiement ou un
	# tablier neuf.
	_rue_grille = GridContainer.new()
	_rue_grille.columns = 2
	_rue_grille.add_theme_constant_override("h_separation", 14)
	_rue_grille.add_theme_constant_override("v_separation", 4)
	_rue_grille.visible = false
	v.add_child(_rue_grille)
	for ligne in [
		["type", "Voie"],
		["largeur", "Largeur"],
		["charge", "Trafic"],
		["etat", "Après la crue"],
	]:
		_rue_grille.add_child(_label(ligne[1], 12, GRIS))
		var val := _label("", 12, TEXTE)
		val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		_rue_grille.add_child(val)
		_rue_valeurs[ligne[0]] = val

	# 🔧 LE BLOC DE RÉPARATION, le même pour un îlot et pour une rue.
	_repare_bloc = VBoxContainer.new()
	_repare_bloc.add_theme_constant_override("separation", 6)
	_repare_bloc.visible = false
	v.add_child(_repare_bloc)
	_repare_bloc.add_child(HSeparator.new())
	_repare_bloc.add_child(_label("Après la crue", 13, ACCENT))
	_repare_texte = _label("", 12, TEXTE)
	_repare_texte.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_repare_bloc.add_child(_repare_texte)
	_repare_bouton = Button.new()
	_repare_bouton.pressed.connect(func() -> void:
		reparation_demandee.emit(_fiche_couche, _fiche_fid))
	_repare_bloc.add_child(_repare_bouton)

	_trafic_bloc = VBoxContainer.new()
	_trafic_bloc.add_theme_constant_override("separation", 6)
	_trafic_bloc.visible = false
	v.add_child(_trafic_bloc)
	_trafic_bloc.add_child(HSeparator.new())
	_trafic_bloc.add_child(_label("Transformer la rue", 13, ACCENT))
	_trafic_stationnement = Button.new()
	_trafic_stationnement.text = "Supprimer le stationnement"
	_trafic_stationnement.pressed.connect(func() -> void:
		trafic_demande.emit("stationnement", _fiche_fid))
	_trafic_bloc.add_child(_trafic_stationnement)
	_trafic_axe = Button.new()
	_trafic_axe.text = "Retirer la voiture de cet axe"
	_trafic_axe.pressed.connect(func() -> void:
		trafic_demande.emit("axe", _fiche_fid))
	_trafic_bloc.add_child(_trafic_axe)

	_solaire_bloc = VBoxContainer.new()
	_solaire_bloc.add_theme_constant_override("separation", 6)
	_solaire_bloc.visible = false
	v.add_child(_solaire_bloc)
	_solaire_bloc.add_child(HSeparator.new())
	_solaire_bloc.add_child(_label("Panneaux solaires", 13, ACCENT))
	_solaire_valeur = _label("", 13, TEXTE)
	_solaire_bloc.add_child(_solaire_valeur)

	# La lecture d'abord, le réglage ensuite. L'une est pleine et muette,
	# l'autre a une poignée : elles ne se ressemblent pas.
	_solaire_jauge = Jauge.new()
	_solaire_jauge.custom_minimum_size = Vector2(0, 15)
	_solaire_jauge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_solaire_bloc.add_child(_solaire_jauge)

	_solaire_bloc.add_child(_label("Objectif", 11, GRIS))

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

	# Hors de la grille parce qu'elle suit le curseur : elle parle de la CIBLE,
	# pas de l'îlot.
	_solaire_cout = _label("", 12, GRIS)
	_solaire_cout.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_solaire_bloc.add_child(_solaire_cout)

	_solaire_bouton = Button.new()
	_solaire_bouton.text = "Augmenter"
	_solaire_bouton.pressed.connect(func() -> void:
		solaire_demande.emit(_fiche_fid, _solaire_curseur.value / 100.0))
	_solaire_bloc.add_child(_solaire_bouton)

	_message = _label("", 12, GRIS)
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_message)


# Le lacet 0 place la caméra AU SUD : repère fixé par « Z vers le sud » dans
# `07_exporter_godot.py:680`, pas ici.
const AZIMUTS := ["du sud", "du sud-est", "de l'est", "du nord-est",
	"du nord", "du nord-ouest", "de l'ouest", "du sud-ouest"]


func _panneau_camera() -> void:
	# Les gestes de caméra ne se devinent pas, et un jeu qui oblige à ouvrir un
	# fichier pour les connaître n'en est pas un.
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", _boite())
	p.anchor_top = 1.0
	p.anchor_bottom = 1.0
	p.offset_left = 16
	p.offset_bottom = -16
	p.grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_child(p)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	p.add_child(v)
	v.add_child(_label("Caméra", 12, ACCENT))
	_camera_vue = _label("", 14, TEXTE)
	v.add_child(_camera_vue)
	v.add_child(HSeparator.new())
	for ligne in [
		"clic droit glissé : tourner autour de la ville",
		"clic milieu glissé : déplacer · molette : zoom",
		"Q E : quart de tour · flèches : ajuster",
		"T : vue de dessus · V B R I G O M : les repères",
		"C : recolorer par tissu · H : charge · D : diagnostic de crue",
	]:
		v.add_child(_label(ligne, 11, GRIS))


func maj_camera(lacet: float, hauteur: float) -> void:
	if _camera_vue == null:
		return
	var l := fmod(fmod(lacet, 360.0) + 360.0, 360.0)
	var i := int(roundf(l / 45.0)) % 8
	_camera_vue.text = "vue %s, %d° au-dessus" % [AZIMUTS[i], int(roundf(hauteur))]


func _controles_temps() -> void:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", _boite())
	p.anchor_left = 0.5
	p.anchor_right = 0.5
	p.anchor_top = 1.0
	p.anchor_bottom = 1.0
	# 430 de large : le contenu occupe 409 px marges comprises, mesuré sur
	# `wehrau_essai_reset.png` après l'ajout du bouton de retour à zéro.
	p.offset_left = -215
	p.offset_right = 215
	p.offset_top = -66
	p.offset_bottom = -16
	p.grow_horizontal = Control.GROW_DIRECTION_BOTH
	p.grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_child(p)

	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	p.add_child(h)
	_temps_label = _label("Mois 0", 13, TEXTE)
	_temps_label.custom_minimum_size.x = 92
	h.add_child(_temps_label)
	for choix in [["Pause", 0.0], ["×1", 1.0], ["×4", 4.0], ["×12", 12.0]]:
		var b := Button.new()
		b.text = choix[0]
		var v: float = choix[1]
		b.pressed.connect(_demander_vitesse.bind(v))
		h.add_child(b)
		_vitesses[v] = b

	# Rejouer un geste demandait trois secondes de rechargement. Le bouton remet
	# le temps ET la ville : un temps qui recule seul laisserait des toits noirs
	# sous un compteur à « Mois 0 ».
	var raz := Button.new()
	raz.text = "Recommencer"
	raz.tooltip_text = "Remet le temps au mois 0 et annule les poses décidées."
	raz.pressed.connect(func() -> void: temps_remis.emit())
	h.add_child(raz)


func _demander_vitesse(v: float) -> void:
	vitesse_demandee.emit(v)


func maj(indic: Dictionary, mois: float, vitesse: float) -> void:
	if indic.is_empty():
		return
	_mois = mois
	var conso: float = indic["conso_mwh"]
	var prod: float = indic["production_mwh"]
	_ville_valeurs["conso"].text = _nb(conso / 1000.0, 1) + " GWh/an"
	_ville_valeurs["production"].text = _nb(prod / 1000.0, 1) + " GWh/an"
	_ville_valeurs["achat"].text = _nb(indic["achat_mwh"] / 1000.0, 1) + " GWh/an"
	_ville_valeurs["co2"].text = _nb(indic["co2_kt"], 1) + " kt/an"
	# ⚠️ Mémorisée ici : `_maj_fiche()` en a besoin à chaque image, et la
	# recalculer parcourrait la ville une seconde fois par image.
	_caisse_ke = indic["caisse_ke"]
	_ville_valeurs["caisse"].text = _milliers(_caisse_ke) + " k€"
	_ville_valeurs["recette"].text = "+" + _milliers(indic["recette_ke_an"]) + " k€/an"
	_maj_durabilite(indic)
	_temps_label.text = "Mois %s" % _nb(mois, 1)
	maj_degats(ville.degats(mois))
	for v in _vitesses:
		(_vitesses[v] as Button).disabled = is_equal_approx(float(v), vitesse)
	if _fiche_fid >= 0:
		_maj_fiche()


func _maj_durabilite(indic: Dictionary) -> void:
	var adaptation := float(indic["adaptation_part"])
	_adaptation_jauge.regler(adaptation, adaptation)
	_adaptation_valeur.text = "%d %%" % int(roundf(adaptation * 100.0))
	_adaptation_etat.text = "%d logements à relever · %d ponts coupés" % [
		int(ceil(float(indic["adaptation_logements"]))),
		int(indic["adaptation_ponts"])] if adaptation < 0.9995 else \
		"La ville tient de nouveau."

	_reduction_verrouillee = bool(indic["reduction_verrouillee"])
	var reduction := float(indic["reduction_part"])
	_reduction_jauge.colorer(GRIS.darkened(0.25) if _reduction_verrouillee \
		else Color8(91, 174, 117))
	_reduction_jauge.regler(0.0 if _reduction_verrouillee else reduction,
		0.0 if _reduction_verrouillee else reduction)
	_reduction_valeur.text = "VERROUILLÉE" if _reduction_verrouillee else \
		"%d %%" % int(roundf(reduction * 100.0))
	if _reduction_verrouillee:
		_reduction_etat.text = "Urgence : relever les logements et les ponts."
	else:
		var ecart := float(indic["reduction_ecart_kt"])
		_reduction_etat.text = "%s kt/an évitées depuis le mois 0." % _nb(ecart, 1) \
			if ecart >= 0.0 else "Émissions +%s kt/an depuis le mois 0." % _nb(-ecart, 1)


func montrer(couche: String, fid: int, _garder := true) -> void:
	# 🔄 LA FICHE S'OUVRE AUSSI SUR UNE RUE depuis le 2026-08-21. Elle
	# n'appartenait qu'à l'îlot ; la crue a mis deux décisions sur la voirie —
	# déblayer, rebâtir — et une décision qu'on ne peut pas cliquer n'existe pas.
	if fid < 0 or (couche != "i" and couche != "r"):
		return
	if fid != _fiche_fid or couche != _fiche_couche:
		_solaire_choix = -1.0  # changer d'objet abandonne le réglage non validé
	_fiche_fid = fid
	_fiche_couche = couche
	_fiche_vide.visible = false
	_fiche_grille.visible = couche == "i"
	_rue_grille.visible = couche == "r"
	_solaire_bloc.visible = couche == "i" and not _reduction_verrouillee
	_trafic_bloc.visible = couche == "r"
	_maj_fiche()


func _maj_fiche() -> void:
	if _fiche_couche == "r":
		_maj_fiche_rue()
		return
	var o: Dictionary = ville.ilots.get(_fiche_fid, {})
	if o.is_empty():
		return
	_fiche_titre.text = "Îlot %d" % _fiche_fid
	_maj_reparation(o)
	# Avant le passage Adaptation → Réduction, il n'y a pas de décision solaire
	# grisée : elle n'existe pas encore dans le langage du jeu. La jauge de
	# gauche suffit à annoncer ce qui viendra.
	_solaire_bloc.visible = not _reduction_verrouillee

	var conso := ville.valeur("i", _fiche_fid, "_conso_mwh", _mois)
	var prod := ville.valeur("i", _fiche_fid, "_production_mwh", _mois)
	var toit := ville.valeur("i", _fiche_fid, "_toit_equipable_m2", _mois)
	var etat := ville.etat_solaire(_fiche_fid, _mois)
	var pct := float(etat["actuel"]) * 100.0
	var cible_pct := float(etat["cible"]) * 100.0
	(_fiche_valeurs["tissu"] as Label).text = str(o.get("sous_type", "?")).replace("_", " ")
	# 🔄 Par `ville.valeur` depuis le 2026-08-21, plus par la fiche brute :
	# `logements` BOUGE maintenant — la crue en a retiré 417, une
	# reconstruction les rend, et la base seule affichait toujours 0.
	(_fiche_valeurs["logements"] as Label).text = _nb(
		ville.valeur("i", _fiche_fid, "logements", _mois), 0)
	(_fiche_valeurs["conso"] as Label).text = _nb(conso, 0) + " MWh/an"
	(_fiche_valeurs["production"] as Label).text = _nb(prod, 0) + " MWh/an"
	(_fiche_valeurs["toit"] as Label).text = _nb(toit, 0) + " m²"
	var ans := ville.valeur("i", _fiche_fid, "_rentabilite_annees", _mois)
	(_fiche_valeurs["retour"] as Label).text = \
		"—" if is_inf(ans) else "%d ans" % int(roundf(ans))

	# 🔴 On passe ici À CHAQUE IMAGE : le curseur ne se repositionne que sans
	# choix en cours, sinon on garde la position de l'auteur, remontée au
	# niveau déjà posé.
	# ⚠️ Il se VERROUILLE pendant les travaux : une pose engagée est payée, et
	# ce verrou permet aux rampes de s'additionner sans réécrire l'histoire
	# d'un toit (`ville.lancer_solaire`).
	_ecrit_curseur = true
	_solaire_curseur.editable = not _reduction_verrouillee \
		and toit > 0.0 and pct < 100.0 and not etat["en_cours"]
	if _solaire_choix < 0.0:
		_solaire_curseur.set_value_no_signal(maxf(pct, cible_pct))
	else:
		_solaire_choix = maxf(_solaire_choix, pct)
		_solaire_curseur.set_value_no_signal(_solaire_choix)
	_ecrit_curseur = false
	# L'objectif visé est celui du curseur tant qu'il n'est pas validé, celui de
	# la pose en cours sinon.
	_solaire_jauge.regler(pct / 100.0,
		maxf(pct, _solaire_choix if _solaire_choix >= 0.0 else cible_pct) / 100.0)

	var recette := ville.valeur("i", _fiche_fid, "_recette_ke_an", _mois)
	_alerter_cout(false)
	if _reduction_verrouillee:
		_solaire_valeur.text = "Réduction verrouillée pendant l'urgence."
		_solaire_cout.text = "Relevez les logements sinistrés et rétablissez les ponts d'abord."
		_solaire_bouton.text = "Urgence en cours"
		_solaire_bouton.disabled = true
	elif toit <= 0.0:
		_solaire_valeur.text = "Église protégée — panneaux solaires interdits." \
			if int(o.get("solaire_possible", 1)) == 0 else "Aucun toit équipable."
		_solaire_cout.text = ""
		_solaire_bouton.text = "Augmenter"
		_solaire_bouton.disabled = true
	elif _solaire_choix >= 0.0:
		_afficher_choix(pct, _solaire_choix)
	elif etat["en_cours"]:
		_solaire_valeur.text = "%d %% posés → cible %d %% · encore %s" % [
			int(roundf(pct)), int(roundf(cible_pct)), _duree(float(etat["reste_mois"]))]
		_solaire_cout.text = "Travaux engagés : %s k€ payés" % _milliers(float(etat["cout_ke"]))
		_solaire_bouton.text = "Chantier en cours"
		_solaire_bouton.disabled = true
	else:
		_solaire_valeur.text = "%d %% du toit équipé" % int(roundf(pct))
		_solaire_cout.text = "Rapporte %s k€/an" % _milliers(recette) if pct > 0.0 \
			else "Aucun panneau posé."
		if etat["a_commence"]:
			_message.text = "Pose terminée. Les toits et les totaux ont atteint leur cible."
		_solaire_bouton.text = "Toit entièrement équipé" if pct >= 99.95 else "Augmenter"
		_solaire_bouton.disabled = true


## Tant que le réglage n'est pas validé.
## 🔴 Le seul endroit où le jeu dit non : un bouton grisé sans phrase est une
## panne, sous « il manque 214 k€ » c'est une règle.
func _afficher_choix(actuel: float, cible: float) -> void:
	var duree := ville.duree_solaire_mois(actuel / 100.0, cible / 100.0)
	var cout := ville.cout_solaire_ke(_fiche_fid, cible / 100.0, _mois)
	_solaire_valeur.text = "%d %% posés → cible %d %% · durée : %s" % [
		int(roundf(actuel)), int(roundf(cible)), _duree(duree)]
	_solaire_bouton.text = "Augmenter à %d %%" % int(roundf(cible))
	_solaire_bouton.disabled = cible <= actuel + 0.01

	var manque := cout - _caisse_ke
	if manque > 0.001:
		_solaire_cout.text = "Coût %s k€ · il manque %s k€ en caisse" % [
			_milliers(cout), _milliers(manque)]
		_solaire_bouton.disabled = true
	else:
		_solaire_cout.text = "Coût %s k€ · reste %s k€ en caisse" % [
			_milliers(cout), _milliers(_caisse_ke - cout)]
	_alerter_cout(manque > 0.001)


## ⚠️ Appelé à chaque image : reposer un `theme_color_override` identique fait
## retraiter le thème du Label pour rien.
func _alerter_cout(alerte: bool) -> void:
	if alerte == _cout_en_alerte:
		return
	_cout_en_alerte = alerte
	_solaire_cout.add_theme_color_override("font_color", ALERTE if alerte else GRIS)


## L'entrée de l'essai automatisé dans le curseur. Passe par `value_changed`,
## donc par le même chemin qu'un doigt : la capture prouve ce que le joueur
## verra, pas ce que le code croit.
func viser(pct: float) -> void:
	_solaire_curseur.value = pct


func _sur_curseur(v: float) -> void:
	if _fiche_fid < 0 or _ecrit_curseur or _reduction_verrouillee:
		return
	var actuel := ville.valeur("i", _fiche_fid, "part_toit_equipe", _mois) * 100.0
	# Déposer des panneaux n'est pas une décision de ce prototype (`Énergie` §1).
	# Rattrapé ici plutôt qu'en montant `min_value`, pour garder l'échelle fixe.
	if v < actuel:
		v = actuel
		_ecrit_curseur = true
		_solaire_curseur.set_value_no_signal(v)
		_ecrit_curseur = false
	_solaire_choix = v
	_solaire_jauge.regler(actuel / 100.0, v / 100.0)
	_afficher_choix(actuel, v)


## Après un retour au mois 0 : réglage non validé et compte rendu périmés.
func remis_a_zero() -> void:
	_solaire_choix = -1.0
	_message.text = "Retour au mois 0. La ville est comme au premier jour, caisse à %s k€." \
		% _milliers(Ville.CAISSE_DEPART_KE)
	if _fiche_fid >= 0:
		_maj_fiche()


func confirmer_solaire(cout_ke := 0.0) -> void:
	_solaire_choix = -1.0  # la demande est partie : la fiche reprend la main
	_message.text = "La pose a commencé — %s k€ engagés. Accélérez le temps pour la suivre." \
		% _milliers(cout_ke)
	_maj_fiche()


static func _duree(mois: float) -> String:
	if mois < 1.0:
		return "%d jour(s)" % int(ceil(mois * 30.0))
	return "%s mois" % _nb(mois, 1)


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
func _maj_fiche_rue() -> void:
	var o: Dictionary = ville.routes.get(_fiche_fid, {})
	if o.is_empty():
		return
	_fiche_titre.text = "Rue %d" % _fiche_fid
	var etat := str(o.get("etat_crue", "intact"))
	if ville.est_repare("r", _fiche_fid):
		etat = "repare"
	(_rue_valeurs["type"] as Label).text = str(o.get("hierarchie", "?"))
	(_rue_valeurs["largeur"] as Label).text = "%s m" % _nb(float(o.get("largeur_m", 0.0)), 0)
	(_rue_valeurs["charge"] as Label).text = "%d %%" % int(roundf(
		ville.valeur("r", _fiche_fid, "charge", _mois) * 100.0))
	_trafic_bloc.visible = true
	var stationnement_engage := ville.stationnement_en_suppression(_fiche_fid)
	var axe_ferme: bool = trafic != null and trafic.axe_ferme(_fiche_fid)
	var stationnement_fini := stationnement_engage and ville.valeur(
		"r", _fiche_fid, "stationnement", _mois) < 0.5
	_trafic_stationnement.text = ("Stationnement supprimé" if stationnement_fini \
		else "Suppression en cours · 2 mois") if stationnement_engage \
		else "Supprimer le stationnement"
	_trafic_stationnement.disabled = stationnement_engage or ville.valeur(
		"r", _fiche_fid, "stationnement", _mois) < 0.5
	_trafic_axe.text = ("Axe fermé · report en cours" if trafic.report_en_cours(
		_fiche_fid, _mois) else "Axe fermé") if axe_ferme \
		else "Retirer la voiture de cet axe"
	_trafic_axe.disabled = axe_ferme or not ville.route_praticable(_fiche_fid, _mois) \
		or ville.valeur("r", _fiche_fid, "charge", _mois) < 0.20
	(_rue_valeurs["etat"] as Label).text = {
		"coupe": "franchissement emporté",
		"fragile": "pile déchaussée",
		"repare": "remise en service",
	}.get(etat, "%s m d'eau" % _nb(float(o.get("hauteur_eau", 0.0)), 1)
		if float(o.get("hauteur_eau", 0.0)) > 0.1 else "intacte")
	_maj_reparation(o)


## LE BLOC DE RÉPARATION, et c'est le seul endroit où le jeu dit non deux fois :
## une fois parce que la caisse ne suit pas, une fois parce qu'il n'y a rien à
## réparer. Un bouton grisé sans phrase est une panne ; sous « il manque 214 k€ »
## c'est une règle.
func _maj_reparation(o: Dictionary) -> void:
	var couche := _fiche_couche
	var prix := float(o.get("cout_reparation_ke", 0.0))
	if prix <= 0.0:
		_repare_bloc.visible = false
		return
	_repare_bloc.visible = true
	var fini: bool = ville.reparation_finie(couche, _fiche_fid, _mois)
	var engage: bool = ville.est_repare(couche, _fiche_fid)
	var verbe := _verbe_reparation(couche, o)
	if fini:
		_repare_texte.text = "%s : fait." % verbe
		_repare_bouton.text = "Terminé"
		_repare_bouton.disabled = true
		return
	if engage:
		_repare_texte.text = "Chantier en cours · encore %s" % _duree(
			ville.reste_reparation_mois(couche, _fiche_fid, _mois))
		_repare_bouton.text = "Chantier en cours"
		_repare_bouton.disabled = true
		return
	var manque := prix - _caisse_ke
	var phrase := "%s coûte %s k€, et le chantier dure %s." % [
		verbe, _milliers(prix),
		_duree(ville.duree_reparation_mois(couche, _fiche_fid))]
	_repare_texte.text = _degat_en_clair(couche, o) + "  " + phrase
	if manque > 0.0:
		_repare_texte.text += "  Il manque %s k€." % _milliers(manque)
	_repare_bouton.text = "%s · %s k€" % [verbe, _milliers(prix)]
	_repare_bouton.disabled = manque > 0.0


func _verbe_reparation(couche: String, o: Dictionary) -> String:
	if couche == "i":
		return "Reconstruire l'îlot"
	if str(o.get("etat_crue", "")) == "coupe":
		return "Rebâtir le tablier"
	return "Déblayer la rue"

## Ce que la crue a pris à CET objet, en une phrase. Sans elle, le prix n'a
## pas de contrepartie et le joueur choisit à l'aveugle.
func _degat_en_clair(couche: String, o: Dictionary) -> String:
	if couche == "i":
		var apres := int(roundf(float(o.get("part_ruinee_apres", 0.0)) * 100.0))
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
