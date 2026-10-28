extends Control
# 🗳️ LA FENÊTRE DE JANVIER (décision 124) : le budget de l'an, et pourquoi il fait ce montant.
# Elle s'ouvre seule le 1er janvier, le temps en pause (`interface.grande_fenetre_ouverte`).
# 🔴 Tous ses textes sont les miens, flaggables (90).

const Budget := preload("res://scripts/budget.gd")

const NOMS := {"logements": "Logements rendus", "trafic": "Trafic", "economie": "Économie", "confiance": "Confiance"}
const ICONES := {"logements": "logement", "trafic": "trafic", "economie": "usine", "confiance": "capital"}

var ui
var _corps: VBoxContainer
var _an := 0
var _mois := 0.0


func batir(interface) -> void:
	ui = interface
	name = "FenetreBudget"
	theme = ui._theme_ui
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	# Au-dessus des chiffres qui montent et de la fenêtre des lieux, comme les cartes de l'ouverture.
	z_index = 3
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var voile := ColorRect.new()
	voile.color = Color(0, 0, 0, 0.25)
	voile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(voile)
	voile.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var centre := CenterContainer.new()
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(centre)
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var boite := PanelContainer.new()
	ui._poser_boite(boite)
	boite.custom_minimum_size.x = 500
	centre.add_child(boite)
	_corps = VBoxContainer.new()
	_corps.add_theme_constant_override("separation", 6)
	boite.add_child(_corps)


func ouvrir(an: int, mois: float) -> void:
	_an = an
	_mois = mois
	for n in _corps.get_children():
		n.queue_free()
	_remplir()
	visible = true
	ui._sans_focus(self)


func _remplir() -> void:
	var v = ui.ville
	var b := Budget.bilan(v, _an)
	var regles: float = v.stationnement_mensuel_ke(_mois)
	var total: float = Budget.AIDE_KE_AN + float(b["prime_ke"]) + regles * 12.0

	# ✂️ Court (auteur, 2026-10-28) : ni date (l'horloge la dit), ni sous-titres, ni total de la prime.
	var tete := HBoxContainer.new()
	var titre: Label = ui._label("Budget de l'an %d" % _an, 21, ui.TEXTE)
	titre.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tete.add_child(titre)
	var droite := VBoxContainer.new()
	var somme: Label = ui._label("%s k€" % ui._milliers(total), 24, ui.ARGENT)
	somme.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	droite.add_child(somme)
	# L'écart avec l'an passé ; l'an 2 n'en a pas, l'an 1 n'avait que la caisse de départ.
	if _an >= 3:
		var avant: float = Budget.AIDE_KE_AN + Budget.prime_ke_an(v, _an - 1) \
			+ v.stationnement_mensuel_ke(Budget.debut_an(_an - 1)) * 12.0
		var e: float = total - avant
		if absf(e) >= 0.5:
			var ecart: Label = ui._label("%s %s k€ depuis l'an %d" % ["↑" if e > 0.0 else "↓",
				ui._milliers(absf(e)), _an - 1], 12, ui.FAIT_TEXTE if e > 0.0 else ui.ALERTE)
			ecart.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			droite.add_child(ecart)
	tete.add_child(droite)
	_corps.add_child(tete)

	var marge_aide := Control.new()
	marge_aide.custom_minimum_size.y = 8
	_corps.add_child(marge_aide)
	_ligne("caisse", "Aide fixe de l'État et de la ville", "", Budget.AIDE_KE_AN, "")

	_section("Prime de résultats")
	for c in Budget.CRITERES:
		var note := int(b[c]["note"])
		var teinte: Color = ui.ALERTE if note <= 2 else (ui.FAIT_TEXTE if note >= 4 else ui.GRIS_FORT)
		_ligne(ICONES[c], NOMS[c], _raison(c, b[c]), float(b[c]["ke"]), "", note, teinte)

	# 🪜 Pas de section vide (119) : elle paraît avec la première règle signée.
	if regles >= 0.05:
		_section("Règles")
		_ligne("parking", "Stationnement payant", "", regles, "/mois")

	var voter := Button.new()
	voter.text = "Voter le budget"
	voter.focus_mode = Control.FOCUS_NONE
	ui._habiller_gratuit(voter)
	voter.size_flags_horizontal = Control.SIZE_SHRINK_END
	voter.pressed.connect(_voter)
	var marge := Control.new()
	marge.custom_minimum_size.y = 6
	_corps.add_child(marge)
	_corps.add_child(voter)


func _section(titre: String) -> void:
	var marge := Control.new()
	marge.custom_minimum_size.y = 8
	_corps.add_child(marge)
	_corps.add_child(ui._label(titre, 12, ui.GRIS_FORT))
	_corps.add_child(HSeparator.new())


## Une ligne : icône, nom (et sa raison dessous), la note en cinq cases s'il y en a une, le montant.
func _ligne(icone: String, nom: String, raison: String, ke: float, suffixe: String,
		note := -1, teinte := Color.BLACK) -> void:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	var ic := TextureRect.new()
	ic.texture = ui._icone(icone, 20, ui.TEXTE)
	ic.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	ic.custom_minimum_size = Vector2(22, 22)
	h.add_child(ic)
	var mots := VBoxContainer.new()
	mots.add_theme_constant_override("separation", 0)
	mots.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mots.add_child(ui._label(nom, 14, ui.TEXTE))
	if raison != "":
		var r: Label = ui._label(raison, 12, teinte)
		r.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		mots.add_child(r)
	h.add_child(mots)
	if note >= 0:
		h.add_child(_cases(note))
	var somme: Label = ui._label("+%s k€%s" % [ui._milliers(ke), suffixe], 14, ui.TEXTE)
	somme.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	somme.custom_minimum_size.x = 76 if suffixe == "" else 110
	h.add_child(somme)
	_corps.add_child(h)


## La note en cinq cases carrées, pleines en couleur d'argent : pas un pourcentage (60).
func _cases(note: int) -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 3)
	h.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	for i in Budget.NOTE_MAX:
		var c := ColorRect.new()
		c.custom_minimum_size = Vector2(9, 9)
		c.color = ui.ARGENT if i < note else Color(ui.GRIS, 0.25)
		h.add_child(c)
	return h


## Pourquoi cette note, en une phrase : la formule reste cachée, jamais la raison (60b).
func _raison(c: String, d: Dictionary) -> String:
	match c:
		"logements":
			if int(d["dehors"]) > 0:
				return "%d dehors" % int(d["dehors"])
			if int(d["au_camp"]) > 0:
				return "%d encore au camp" % int(d["au_camp"])
			return "Tous rentrés"
		"trafic":
			var coupes: Array = d["coupes"]
			if coupes.size() == 1:
				return "%s coupé" % ui.lieux.nom("r", int(coupes[0]))
			if coupes.size() > 1:
				return "%d ponts coupés" % coupes.size()
			var sat: Array = d["saturees"]
			if sat.size() == 1:
				return "%s saturée" % ui.lieux.nom("r", int(sat[0]))
			if sat.size() > 1:
				return "%s et %d autres rues saturées" % [ui.lieux.nom("r", int(sat[0])), sat.size() - 1]
			return "Fluide"
		"economie":
			return str(d["phrase"])
		"confiance":
			var m: Dictionary = d["marquant"]
			if m.is_empty():
				return "Une année sans éclat"
			if str(m["quoi"]) == "usure":
				return "Le camp s'use"
			var p: String = ui.retours.phrase_capital(m)
			return p.left(1).to_upper() + p.substr(1) if p != "" else "Une année sans éclat"
	return ""


func _voter() -> void:
	visible = false
	ui.retours.consigner("Budget de l'an %d voté : %s k€ d'aide, %s k€ de prime." % [_an,
		ui._milliers(Budget.AIDE_KE_AN), ui._milliers(Budget.prime_ke_an(ui.ville, _an))], _mois)
	ui.bulles.gain_lieu("i", int(ui.LIEUX["mairie"]["fid"]), "caisse",
		"+%s k€" % ui._milliers(Budget.AIDE_KE_AN), Budget.AIDE_KE_AN)
