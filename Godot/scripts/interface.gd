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

# Les champs de la fiche : (champ, libellé, unité, décimales, inversé).
#
# Le cinquième drapeau dit que le vert va vers le BAS — la consommation qui
# tombe est une bonne nouvelle. Il vit ici ET dans le bandeau : sinon la fiche
# contredit le bandeau.
#
# Les champs préfixés `_` sont CALCULÉS (servis par `ville.valeur` via
# l'énergie) : ils n'existent pas dans le dictionnaire de l'objet, la fiche ne
# doit donc pas les chercher dedans. L'énergie entre DANS L'ORDRE DU BANDEAU —
# décision 63b, le joueur apprend un seul vocabulaire.
const FICHE := {
	"i": [
		["logements", "Logements", "", 0, false],
		["emplois", "Emplois", "", 0, false],
		["hauteur", "Hauteur", " niv.", 0, false],
		["surface_m2", "Surface", " m²", 0, false],
		["_conso_mwh", "Consommation", " MWh", 0, true],
		["_production_mwh", "Production", " MWh", 0, false],
		["_toit_equipable_m2", "Toit équipable", " m²", 0, false],
		["_gain_isolation_mwh", "Gain d'isolation", " MWh", 0, true],
	],
	"r": [
		["largeur_m", "Largeur", " m", 1, false],
		["longueur_m", "Longueur", " m", 0, false],
		["charge", "Charge", "", 2, false],
	],
}

# Les trois calques de l'énergie (règle 53 : aucun chiffre global sans son
# calque). La rentabilité est peinte en QUATRE CLASSES, sans un chiffre sur la
# carte (décision 60 : un état non chiffré ne s'optimise pas) — la précision se
# paie d'un clic, sur la fiche. Pas de calque visibilité : refusé (66c).
const CALQUES := [
	["", "", "Aucun"],
	["i", "_classe_solaire", "Rentabilité solaire"],
	["i", "_gain_isolation_mwh", "Gain d'isolation"],
	["i", "part_toit_equipe", "Toits qui produisent"],
]

# Les quatre nombres du bandeau : (clé, libellé). Leur calcul est dans `maj` —
# consommation et achat en INDICE 100 sur le mois 0, l'achat est la FACTURE
# (le volume × le prix qui monte de 2 % par an : ne rien faire coûte).
const INDICATEURS := [
	["conso", "Consommation"],
	["production", "Production locale"],
	["achat", "Achat d'énergie"],
	["co2", "CO2"],
]

var ville: Ville
var chantiers

var _stats := {}          # clé -> Label
var _fiche_titre: Label
var _fiche_grille: GridContainer
var _fiche_energie: Label
var _fiche_vide: Label
var _seuils := {}         # id décision -> HSlider
var _seuil_libelles := {} # id décision -> Label
var _devis_libelles := {} # id décision -> Label
var _lecture: Button
var _curseur: HSlider
var _date: Label
var _message: Label
var _msg_delai := 0.0

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
	# Les deux RESSOURCES d'abord (ce qu'on peut faire), puis les quatre
	# INDICATEURS de l'énergie (ce qu'on a fait) — deux familles, un seul
	# bandeau, l'écart au mois 0 partout.
	for c in [["budget", "Budget"], ["capital", "Capital"]] + INDICATEURS:
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

	# La ligne de synthèse de l'énergie : la couverture décomposée (« dont X
	# produits, Y économisés » — sans elle, isoler ressemble à une triche,
	# PLAN §5 bis) et l'année du remboursement, la SEULE précision chiffrée
	# du jeu, payée d'un clic.
	_fiche_energie = _label("", 11, GRIS)
	_fiche_energie.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_fiche_energie)

	# Le panneau de décision : une BOUCLE sur `chantiers.DECISIONS`, jamais un
	# accès par clé — c'est ce qui prouve que la machinerie n'est pas codée en
	# dur autour d'un seul cas. Deux décisions de nature opposée : l'une
	# rapporte de l'argent, l'autre de la légitimité.
	for id in chantiers.DECISIONS:
		var D: Dictionary = chantiers.DECISIONS[id]
		v.add_child(HSeparator.new())
		v.add_child(_label(D["nom"], 13, ACCENT))
		var resume := _label(D["resume"], 11, GRIS)
		resume.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(resume)

		var seuil_l := _label("", 11, GRIS)
		v.add_child(seuil_l)
		var curseur := HSlider.new()
		curseur.min_value = D["seuil_min"]
		curseur.max_value = D["seuil_max"]
		curseur.value = D["seuil_defaut"]
		curseur.step = 1.0
		_seuils[id] = curseur
		_seuil_libelles[id] = seuil_l
		v.add_child(curseur)

		var devis_l := _label("", 12, TEXTE)
		devis_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_devis_libelles[id] = devis_l
		v.add_child(devis_l)

		var b := Button.new()
		b.text = "Décider"
		var id_fige: String = id   # capturé pour la lambda
		b.pressed.connect(func() -> void:
			decide.emit(id_fige, chantiers.eligibles(id_fige,
				_seuils[id_fige].value, _t)))
		v.add_child(b)

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
	if CALQUES.is_empty():
		return
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

func maj(t: float, en_lecture: bool, indic: Dictionary) -> void:
	_t = t
	_curseur.set_value_no_signal(t)
	_lecture.text = "⏸" if en_lecture else "▶"
	@warning_ignore("integer_division")
	var an := int(t) / 12
	var mo := int(t) % 12
	_date.text = "an %d · mois %d" % [an + 1, mo + 1]

	# Le mois 0 ne bouge jamais : le calculer à chaque image coûterait plus
	# cher que tout le reste de l'interface. `indic` est vide tant que les
	# quatre nombres de l'énergie ne sont pas là ; le geste reste en place.
	if _i0.is_empty() and not indic.is_empty():
		_i0 = ville.indicateurs(0.0)
	# Pas d'écart sur le budget : il n'a pas de valeur de référence, il monte
	# tout seul de 8,3 pts par mois. Ce qui compte est son NIVEAU.
	_stats["budget"].text = _nb(chantiers.solde(t), 0) + " pts"
	_stats["budget_ecart"].text = ""
	_stat("capital", chantiers.capital(t), 0, "", Ville.CAPITAL_DEPART, false)

	# Les quatre nombres, en écart à t0 (PLAN §3). Consommation et achat en
	# indice 100 ; l'achat est la FACTURE, elle grimpe toute seule de 2 % par
	# an — c'est voulu, ne rien faire a un coût. Le CO2 additionne le carbone
	# gris des chantiers en cours : il doit MONTER pendant les travaux.
	if not _i0.is_empty():
		_stat("conso", 100.0 * indic["conso_mwh"] / _i0["conso_mwh"],
			0, "", 100.0, true)
		_stat("production", 100.0 * indic["production_mwh"] / indic["conso_mwh"],
			0, " %", 0.0, false)
		_stat("achat", 100.0 * indic["facture"] / _i0["facture"],
			0, "", 100.0, true)
		_stat("co2", indic["co2_kt"] + chantiers.co2_gris_an(t),
			1, " kt", _i0["co2_kt"], true)

	# Le devis de chaque décision suit le curseur et le temps : n cibles, le
	# coût, le capital — signé, parce que l'isolation en REND.
	for id in _seuils:
		var D: Dictionary = chantiers.DECISIONS[id]
		var seuil: float = _seuils[id].value
		_seuil_libelles[id].text = "%s %s%s" \
			% [D["libelle_seuil"], _nb(seuil, 0), D["unite_seuil"]]
		var fids: Array = chantiers.eligibles(id, seuil, t)
		if fids.is_empty():
			_devis_libelles[id].text = "Aucune cible à ce seuil."
		else:
			var dv: Dictionary = chantiers.devis(id, fids, t)
			_devis_libelles[id].text = "%d îlots · %s pts · capital %s%s" \
				% [fids.size(), _nb(dv["cout"], 0),
				"+" if dv["capital"] > 0.0 else "", _nb(dv["capital"], 0)]

	if _msg_delai > 0.0:
		_msg_delai -= get_process_delta_time()
		if _msg_delai <= 0.0:
			_message.text = ""

	if _fiche_fid >= 0:
		montrer(_fiche_couche, _fiche_fid, false)


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
		# Un champ calculé (`_`) n'est pas dans le dictionnaire de l'objet : on
		# le garde s'il a quelque chose à dire — maintenant ou au départ. Le
		# parc n'affiche pas un toit de 0 m² ; l'îlot entièrement isolé garde
		# sa ligne de gain, tombée à zéro ; la production s'affiche dès qu'un
		# toit PEUT produire, pour que la ligne soit déjà là quand ça décolle.
		if champ.begins_with("_"):
			var pertinent: bool = ville.valeur(couche, fid, champ, _t) != 0.0 \
				or ville.valeur(couche, fid, champ, 0.0) != 0.0
			if champ == "_production_mwh":
				pertinent = ville.valeur(couche, fid, "_toit_equipable_m2", _t) > 0.0
			if not pertinent:
				continue
		elif not o.has(champ):
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
		var v := ville.valeur(_fiche_couche, _fiche_fid, champ, _t)
		# La référence est la VALEUR au mois 0, pas la base : un champ calculé
		# n'a pas de base (elle vaudrait 0 et l'écart afficherait la valeur
		# entière). À t = 0 aucune rampe n'agit, les deux coïncident.
		var v0 := ville.valeur(_fiche_couche, _fiche_fid, champ, 0.0)
		(l["v"] as Label).text = _nb(v, ligne[3]) + ligne[2]
		var d := v - v0
		var e: Label = l["e"]
		if absf(d) < 5e-4:
			e.text = ""
			e.add_theme_color_override("font_color", GRIS)
		else:
			e.text = ("+" if d > 0.0 else "") + _nb(d, ligne[3])
			# Un indicateur INVERSÉ voit son vert aller vers le bas — même
			# drapeau que dans `_stat`, sinon la fiche contredit le bandeau.
			var bon := (d < 0.0) if bool(ligne[4]) else (d > 0.0)
			e.add_theme_color_override("font_color", MONTE if bon else BAISSE)
	_maj_fiche_energie()


## La synthèse d'énergie de l'îlot : la couverture décomposée, puis l'année du
## remboursement — la date de péremption de la décision se lit ici (PLAN §6 :
## après le mois 120, un chantier ne se rembourse plus dans la partie).
func _maj_fiche_energie() -> void:
	_fiche_energie.text = ""
	if _fiche_couche != "i":
		return
	var conso := ville.valeur("i", _fiche_fid, "_conso_mwh", _t)
	var toit := ville.valeur("i", _fiche_fid, "_toit_equipable_m2", _t)
	if conso <= 0.0 and toit <= 0.0:
		return
	var lignes := []
	var prod := ville.valeur("i", _fiche_fid, "_production_mwh", _t)
	if prod > 0.0 and conso > 0.0:
		var conso0 := ville.valeur("i", _fiche_fid, "_conso_mwh", 0.0)
		var couvert := 100.0 * prod / conso
		var produits := 100.0 * prod / conso0
		var economises := couvert - produits
		if absf(economises) >= 0.5:
			lignes.append("Couverture %s %% : %s produits, %s économisés."
				% [_nb(couvert, 0), _nb(produits, 0), _nb(economises, 0)])
		else:
			lignes.append("Couverture %s %% de la consommation." % _nb(couvert, 0))
	var annees := ville.valeur("i", _fiche_fid, "_rentabilite_annees", _t)
	if toit > 0.0 and not is_inf(annees):
		lignes.append("Panneaux décidés ce mois-ci : remboursés en %s ans."
			% _nb(annees, 0))
	_fiche_energie.text = " ".join(lignes)


func dire(txt: String, secondes := 5.0) -> void:
	_message.text = txt
	_msg_delai = secondes
