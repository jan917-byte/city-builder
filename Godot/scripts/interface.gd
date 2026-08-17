extends CanvasLayer
# L'interface du prototype énergie simplifié.
#
# Deux niveaux, et aucun mélange : la ville entière à gauche, l'îlot choisi à
# droite. Le survol ne change jamais la fiche. Pour l'instant, le seul geste
# est d'augmenter immédiatement la part de toit équipée, sans temps, budget ni
# capital politique. Ce retour en arrière est volontaire : on vérifie d'abord
# si agir sur un toit se comprend et se voit avant de reconstruire une tension.

signal solaire_demande(fid: int, part: float)

const Ville := preload("res://scripts/ville.gd")

const FOND := Color(0.106, 0.118, 0.141, 0.94)
const BORD := Color(0.173, 0.192, 0.227)
const TEXTE := Color(0.902, 0.910, 0.925)
const GRIS := Color(0.604, 0.635, 0.694)
const ACCENT := Color(0.910, 0.769, 0.416)

var ville: Ville

var _ville_valeurs := {}
var _fiche_titre: Label
var _fiche_vide: Label
var _fiche_grille: GridContainer
var _solaire_bloc: VBoxContainer
var _solaire_valeur: Label
var _solaire_curseur: HSlider
var _solaire_bouton: Button
var _message: Label

var _fiche_fid := -1


func batir() -> void:
	_panneau_ville()
	_panneau_ilot()


func _boite() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = FOND
	sb.border_color = BORD
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(12)
	return sb


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
	v.add_child(HSeparator.new())

	for ligne in [
		["conso", "Consommation"],
		["production", "Production solaire"],
		["achat", "Énergie achetée"],
		["co2", "CO₂"],
	]:
		var h := HBoxContainer.new()
		h.add_child(_label(ligne[1], 12, GRIS))
		var valeur := _label("", 14, TEXTE)
		valeur.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		valeur.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(valeur)
		_ville_valeurs[ligne[0]] = valeur
		v.add_child(h)


func _panneau_ilot() -> void:
	var p := PanelContainer.new()
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

	_solaire_bloc = VBoxContainer.new()
	_solaire_bloc.add_theme_constant_override("separation", 6)
	_solaire_bloc.visible = false
	v.add_child(_solaire_bloc)
	_solaire_bloc.add_child(HSeparator.new())
	_solaire_bloc.add_child(_label("Panneaux solaires", 13, ACCENT))
	_solaire_valeur = _label("", 13, TEXTE)
	_solaire_bloc.add_child(_solaire_valeur)

	_solaire_curseur = HSlider.new()
	_solaire_curseur.min_value = 0.0
	_solaire_curseur.max_value = 100.0
	_solaire_curseur.step = 1.0
	_solaire_curseur.value_changed.connect(_sur_curseur)
	_solaire_bloc.add_child(_solaire_curseur)

	_solaire_bouton = Button.new()
	_solaire_bouton.text = "Augmenter"
	_solaire_bouton.pressed.connect(func() -> void:
		solaire_demande.emit(_fiche_fid, _solaire_curseur.value / 100.0))
	_solaire_bloc.add_child(_solaire_bouton)

	_message = _label("", 12, GRIS)
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_message)


func maj(indic: Dictionary) -> void:
	if indic.is_empty():
		return
	var conso: float = indic["conso_mwh"]
	var prod: float = indic["production_mwh"]
	_ville_valeurs["conso"].text = _nb(conso / 1000.0, 1) + " GWh/an"
	_ville_valeurs["production"].text = _nb(prod / 1000.0, 1) + " GWh/an"
	_ville_valeurs["achat"].text = _nb(indic["achat_mwh"] / 1000.0, 1) + " GWh/an"
	_ville_valeurs["co2"].text = _nb(indic["co2_kt"], 1) + " kt/an"


func montrer(couche: String, fid: int, _garder := true) -> void:
	# Le panneau de droite appartient uniquement à l'îlot cliqué. Les rues et
	# le survol peuvent toujours être surlignés dans la ville, mais ne prennent
	# jamais possession de cette fiche.
	if couche != "i" or fid < 0:
		return
	_fiche_fid = fid
	_fiche_vide.visible = false
	_solaire_bloc.visible = true
	_maj_fiche()


func _maj_fiche() -> void:
	var o: Dictionary = ville.ilots.get(_fiche_fid, {})
	if o.is_empty():
		return
	_fiche_titre.text = "Îlot %d" % _fiche_fid
	for n in _fiche_grille.get_children():
		_fiche_grille.remove_child(n)
		n.queue_free()

	var conso := ville.valeur("i", _fiche_fid, "_conso_mwh", 0.0)
	var prod := ville.valeur("i", _fiche_fid, "_production_mwh", 0.0)
	var toit := ville.valeur("i", _fiche_fid, "_toit_equipable_m2", 0.0)
	var part := ville.valeur("i", _fiche_fid, "part_toit_equipe", 0.0)
	var lignes := [
		["Tissu", str(o.get("sous_type", "?")).replace("_", " ")],
		["Logements", _nb(float(o.get("logements", 0.0)), 0)],
		["Consommation", _nb(conso, 0) + " MWh/an"],
		["Production", _nb(prod, 0) + " MWh/an"],
		["Toit équipable", _nb(toit, 0) + " m²"],
	]
	for ligne in lignes:
		_fiche_grille.add_child(_label(ligne[0], 12, GRIS))
		var valeur := _label(ligne[1], 12, TEXTE)
		valeur.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		_fiche_grille.add_child(valeur)

	var pct := roundf(part * 100.0)
	_solaire_curseur.min_value = pct
	_solaire_curseur.set_value_no_signal(pct)
	_solaire_curseur.editable = toit > 0.0 and pct < 100.0
	_solaire_bouton.disabled = true
	_solaire_valeur.text = ("Aucun toit équipable." if toit <= 0.0
		else "%d %% du toit équipé" % int(pct))
	_solaire_bouton.text = "Toit entièrement équipé" if pct >= 100.0 else "Augmenter"


func _sur_curseur(v: float) -> void:
	if _fiche_fid < 0:
		return
	var actuel := ville.valeur("i", _fiche_fid, "part_toit_equipe", 0.0) * 100.0
	_solaire_valeur.text = "%d %% actuellement → %d %%" % [int(roundf(actuel)), int(roundf(v))]
	_solaire_bouton.text = "Augmenter à %d %%" % int(roundf(v))
	_solaire_bouton.disabled = v <= actuel + 0.01


func confirmer_solaire() -> void:
	_message.text = "Les toits et les totaux de la ville ont changé."
	_maj_fiche()


static func _nb(v: float, dec: int) -> String:
	return (("%%.%df" % dec) % v).replace(".", ",")
