extends CanvasLayer
# L'interface : la fiche, la décision, le temps, les calques.
#
# Construite en code comme le reste — la scène ne contient qu'un nœud
# (`Génération procédurale.md:47`).
#
# La règle qui commande toute cette page vient de `parties.html` : **on affiche
# l'écart au mois 0 à côté de la valeur**. Sans lui, une canopée qui passe de
# 0,198 à 0,216 ne se voit pas, et on croit que rien ne bouge.

signal decide(id: String, fids: Array)
signal temps_demande(t: float)
signal lecture_basculee()
signal vitesse_demandee(v: float)
signal calque_demande(couche: String, champ: String)

const Ville := preload("res://scripts/ville.gd")

const FOND := Color(0.106, 0.118, 0.141, 0.94)
const BORD := Color(0.173, 0.192, 0.227)
const TEXTE := Color(0.902, 0.910, 0.925)
const GRIS := Color(0.604, 0.635, 0.694)
const ACCENT := Color(0.910, 0.769, 0.416)
const MONTE := Color(0.435, 0.682, 0.369)
const BAISSE := Color(0.757, 0.267, 0.235)

# Les champs de la fiche : (champ, libellé, unité, décimales).
const FICHE := {
	"i": [
		["logements", "Logements", "", 0],
		["emplois", "Emplois", "", 0],
		["hauteur", "Hauteur", " niv.", 0],
		["canopee", "Canopée", "", 2],
		["impermeabilise", "Imperméabilisé", "", 2],
		["_surchauffe", "Surchauffe", " °C", 2],
		["stationnement", "Places", "", 0],
		["riverain", "Fragilité", "", 2],
		["alea", "Aléa", "", 2],
		["surface_m2", "Surface", " m²", 0],
	],
	"r": [
		["largeur_m", "Largeur", " m", 1],
		["emprise_libre_m", "Emprise libre", " m", 1],
		["longueur_m", "Longueur", " m", 0],
		["canopee", "Canopée", "", 2],
		["charge", "Charge", "", 2],
		["stationnement", "Places", "", 0],
	],
}

const CALQUES := [
	["", "", "Aucun"],
	["i", "canopee", "Canopée"],
	["i", "_surchauffe", "Surchauffe"],
	["i", "impermeabilise", "Imperméabilisé"],
	["r", "canopee", "Canopée des rues"],
	["r", "emprise_libre_m", "Emprise libre"],
]

var ville: Ville
var chantiers

var _stats := {}          # clé -> Label
var _fiche_titre: Label
var _fiche_grille: GridContainer
var _fiche_vide: Label
var _bouton_ici: Button
var _bouton_tout: Button
var _seuil: HSlider
var _seuil_txt: Label
var _lecture: Button
var _curseur: HSlider
var _date: Label
var _message: Label
var _msg_delai := 0.0

var seuil: float = 6.0
var _fiche_couche := ""
var _fiche_fid := -1
var _lignes := []
var _i0 := {}              # les indicateurs du mois 0, calculés une fois


# ------------------------------------------------------------------ montage

func batir() -> void:
	_bandeau()
	_panneau_droite()
	_barre_temps()
	_calques()


func _boite(coul := FOND) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = coul
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


func _panneau(preset: int, marge: Vector2) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", _boite())
	p.set_anchors_and_offsets_preset(preset, Control.PRESET_MODE_MINSIZE, 0)
	p.position += marge
	add_child(p)
	return p


func _bandeau() -> void:
	var p := _panneau(Control.PRESET_TOP_LEFT, Vector2(16, 16))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 26)
	p.add_child(h)
	_date = _label("", 20, ACCENT)
	h.add_child(_date)
	for c in [["budget", "Budget"], ["capital", "Capital"],
			["canopee_moy", "Canopée"], ["surchauffe_moy", "Surchauffe"],
			["arbres", "Arbres"]]:
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 0)
		v.add_child(_label(c[1], 11, GRIS))
		var val := _label("", 17, TEXTE)
		v.add_child(val)
		var ec := _label("", 11, GRIS)
		v.add_child(ec)
		_stats[c[0]] = val
		_stats[c[0] + "_ecart"] = ec
		h.add_child(v)


func _panneau_droite() -> void:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", _boite())
	p.anchor_left = 1.0
	p.anchor_right = 1.0
	p.anchor_top = 0.0
	p.offset_left = -336
	p.offset_right = -16
	p.offset_top = 16
	p.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	add_child(p)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	p.add_child(v)

	_fiche_titre = _label("", 15, TEXTE)
	v.add_child(_fiche_titre)
	_fiche_vide = _label("Survole ou clique un îlot, une rue.", 13, GRIS)
	_fiche_vide.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_fiche_vide)

	_fiche_grille = GridContainer.new()
	_fiche_grille.columns = 3
	_fiche_grille.add_theme_constant_override("h_separation", 14)
	_fiche_grille.add_theme_constant_override("v_separation", 2)
	v.add_child(_fiche_grille)

	_bouton_ici = Button.new()
	_bouton_ici.visible = false
	_bouton_ici.pressed.connect(func() -> void:
		if _fiche_couche == "r" and _fiche_fid >= 0:
			decide.emit("D07", [_fiche_fid]))
	v.add_child(_bouton_ici)

	v.add_child(HSeparator.new())
	v.add_child(_label(chantiers.DECISIONS["D07"]["nom"], 13, ACCENT))
	var d := _label(chantiers.DECISIONS["D07"]["resume"], 12, GRIS)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(d)

	_seuil_txt = _label("", 12, TEXTE)
	v.add_child(_seuil_txt)
	_seuil = HSlider.new()
	_seuil.min_value = chantiers.DECISIONS["D07"]["seuil_min"]
	_seuil.max_value = chantiers.DECISIONS["D07"]["seuil_max"]
	_seuil.step = 0.5
	_seuil.value = seuil
	_seuil.value_changed.connect(func(x: float) -> void:
		seuil = x
		rafraichir_decision())
	v.add_child(_seuil)

	_bouton_tout = Button.new()
	_bouton_tout.pressed.connect(func() -> void:
		decide.emit("D07", chantiers.eligibles("D07", seuil, _t)))
	v.add_child(_bouton_tout)

	_message = _label("", 12, BAISSE)
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_message)


func _barre_temps() -> void:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", _boite())
	p.anchor_left = 0.5
	p.anchor_right = 0.5
	p.anchor_top = 1.0
	p.anchor_bottom = 1.0
	p.offset_left = -330
	p.offset_right = 330
	p.offset_top = -76
	p.offset_bottom = -16
	add_child(p)

	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	p.add_child(h)

	_lecture = Button.new()
	_lecture.text = "▶"
	_lecture.custom_minimum_size = Vector2(40, 0)
	_lecture.pressed.connect(func() -> void: lecture_basculee.emit())
	h.add_child(_lecture)

	for v in [1.0, 4.0, 12.0]:
		var b := Button.new()
		b.text = "×%d" % int(v)
		b.pressed.connect(func() -> void: vitesse_demandee.emit(v))
		h.add_child(b)

	_curseur = HSlider.new()
	_curseur.min_value = 0.0
	_curseur.max_value = Ville.HORIZON_MOIS
	_curseur.step = 0.0
	_curseur.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_curseur.custom_minimum_size = Vector2(300, 0)
	_curseur.value_changed.connect(func(x: float) -> void: temps_demande.emit(x))
	h.add_child(_curseur)


func _calques() -> void:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", _boite())
	p.anchor_top = 1.0
	p.anchor_bottom = 1.0
	p.offset_left = 16
	p.offset_top = -300
	p.offset_bottom = -90
	p.grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_child(p)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 3)
	p.add_child(v)
	v.add_child(_label("Calque", 12, ACCENT))
	for c in CALQUES:
		var b := Button.new()
		b.text = c[2]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.pressed.connect(func() -> void: calque_demande.emit(c[0], c[1]))
		v.add_child(b)


# ------------------------------------------------------------ mise à jour

var _t := 0.0

func maj(t: float, en_lecture: bool, indic: Dictionary, arbres: int) -> void:
	_t = t
	_curseur.set_value_no_signal(t)
	_lecture.text = "⏸" if en_lecture else "▶"
	@warning_ignore("integer_division")
	var an := int(t) / 12
	var mo := int(t) % 12
	_date.text = "an %d · mois %d" % [an + 1, mo + 1]

	# Le mois 0 ne bouge jamais : le calculer à chaque image coûterait plus
	# cher que tout le reste de l'interface.
	if _i0.is_empty():
		_i0 = ville.indicateurs(0.0)
	# Pas d'écart sur le budget : il n'a pas de valeur de référence, il monte
	# tout seul de 8,3 pts par mois. Ce qui compte est son NIVEAU.
	_stats["budget"].text = _nb(chantiers.solde(t), 0) + " pts"
	_stats["budget_ecart"].text = ""
	_stat("capital", chantiers.capital(t), 0, "", Ville.CAPITAL_DEPART, false)
	_stat("canopee_moy", indic["canopee_moy"], 3, "", _i0["canopee_moy"], false)
	# Une surchauffe qui BAISSE est une bonne nouvelle : le vert doit aller
	# vers le bas. C'est le seul indicateur inversé, d'où le drapeau.
	_stat("surchauffe_moy", indic["surchauffe_moy"], 2, " °C",
		_i0["surchauffe_moy"], true)
	_stats["arbres"].text = str(arbres)
	_stats["arbres_ecart"].text = ""

	if _msg_delai > 0.0:
		_msg_delai -= get_process_delta_time()
		if _msg_delai <= 0.0:
			_message.text = ""

	if _fiche_fid >= 0:
		montrer(_fiche_couche, _fiche_fid, false)
	rafraichir_decision()


func _stat(cle: String, v: float, dec: int, unite: String, ref: float,
		inverse: bool) -> void:
	_stats[cle].text = _nb(v, dec) + unite
	var d := v - ref
	var e: Label = _stats[cle + "_ecart"]
	# Écart nul : on n'écrit rien. Un tiret de remplissage ne dirait rien de
	# plus que la case vide, et le tiret cadratin est proscrit dans l'interface
	# (`Ton et règles d'écriture.md`).
	if absf(d) < pow(10.0, -dec) * 0.5:
		e.text = ""
		e.add_theme_color_override("font_color", GRIS)
		return
	e.text = ("+" if d > 0.0 else "") + _nb(d, dec) + unite
	var bon := (d < 0.0) if inverse else (d > 0.0)
	e.add_theme_color_override("font_color", MONTE if bon else BAISSE)


## `String.num` ne complète pas les décimales : 0,10 en ressort « 0,1 », et une
## colonne de chiffres cesse de s'aligner. D'où le format explicite.
static func _nb(v: float, dec: int) -> String:
	return (("%%.%df" % dec) % v).replace(".", ",")


## Change l'objet montré. Les lignes ne sont reconstruites QUE si la cible a
## changé : rebâtir trente labels à chaque image suffit à faire saccader la
## lecture du temps.
func montrer(couche: String, fid: int, _garder := true) -> void:
	if couche == "" or fid < 0:
		return                          # on ne vide pas la fiche en sortant
	if couche == _fiche_couche and fid == _fiche_fid:
		_maj_fiche()
		return
	_fiche_couche = couche
	_fiche_fid = fid
	_fiche_vide.visible = false

	var o: Dictionary = ville.objets(couche).get(fid, {})
	# ` ` est l'espace insécable qu'impose la ponctuation française devant
	# les deux-points (U+00A0). Elle est invisible dans le source : sans elle,
	# le « : » peut se retrouver seul en début de ligne. → `Ton et règles
	# d'écriture.md`
	if couche == "i":
		_fiche_titre.text = "Îlot %d : %s" % [fid, str(o.get("sous_type", "?"))]
	else:
		_fiche_titre.text = "Tronçon %d : %s" % [fid, str(o.get("hierarchie", "?"))]

	for n in _fiche_grille.get_children():
		_fiche_grille.remove_child(n)
		n.queue_free()
	_lignes.clear()
	for ligne in FICHE[couche]:
		var champ: String = ligne[0]
		if champ != "_surchauffe" and not o.has(champ):
			continue
		_fiche_grille.add_child(_label(ligne[1], 12, GRIS))
		var lv := _label("", 12, TEXTE)
		lv.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		lv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_fiche_grille.add_child(lv)
		var le := _label("", 12, GRIS)
		le.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		_fiche_grille.add_child(le)
		_lignes.append({"def": ligne, "v": lv, "e": le})
	_maj_fiche()


func _maj_fiche() -> void:
	for l in _lignes:
		var ligne: Array = l["def"]
		var champ: String = ligne[0]
		var v: float
		var v0: float
		if champ == "_surchauffe":
			v = ville.surchauffe(_fiche_fid, _t)
			v0 = ville.surchauffe(_fiche_fid, 0.0)
		else:
			v = ville.valeur(_fiche_couche, _fiche_fid, champ, _t)
			v0 = ville.base(_fiche_couche, _fiche_fid, champ)
		(l["v"] as Label).text = _nb(v, ligne[3]) + ligne[2]
		var d := v - v0
		var e: Label = l["e"]
		if absf(d) < 5e-4:
			e.text = ""
			e.add_theme_color_override("font_color", GRIS)
		else:
			e.text = ("+" if d > 0.0 else "") + _nb(d, ligne[3])
			# Une surchauffe qui BAISSE est une bonne nouvelle. C'est le seul
			# champ où le vert va vers le bas — le rappeler ici, sinon la
			# fiche contredit le bandeau.
			var bon := (d < 0.0) if champ == "_surchauffe" else (d > 0.0)
			e.add_theme_color_override("font_color", MONTE if bon else BAISSE)


func rafraichir_decision() -> void:
	var elig: Array = chantiers.eligibles("D07", seuil, _t)
	var dv: Dictionary = chantiers.devis("D07", elig, _t)
	_seuil_txt.text = "Au-delà de %s m d'emprise libre : %d tronçons, %s m" \
		% [_nb(seuil, 1), elig.size(), _nb(dv["quantite"] * 100.0, 0)]
	if elig.is_empty():
		_bouton_tout.text = "Rien à planter à ce seuil"
	elif elig.size() == 1:
		_bouton_tout.text = "Planter le tronçon (%s pts)" % _nb(dv["cout"], 0)
	else:
		_bouton_tout.text = "Planter les %d tronçons (%s pts)" % [elig.size(),
			_nb(dv["cout"], 0)]
	_bouton_tout.disabled = elig.is_empty()

	var ici := (_fiche_couche == "r" and _fiche_fid >= 0
		and elig.has(_fiche_fid))
	_bouton_ici.visible = ici
	if ici:
		var d1: Dictionary = chantiers.devis("D07", [_fiche_fid], _t)
		_bouton_ici.text = "Planter ce tronçon (%s pts)" % _nb(d1["cout"], 0)


func dire(txt: String, secondes := 5.0) -> void:
	_message.text = txt
	_msg_delai = secondes
