extends PanelContainer
## Première boucle d'essai : les étapes se déduisent des chantiers réellement livrés.

const Ville := preload("res://scripts/ville.gd")
# Lieux touchés dans l’emprise corrigée le 2026-09-16.
const RUE := 148
const MAISONS := 59
const BERGE := 3
const SOLAIRE := 32

var jeu
var suite := false
var termine := false
var ouvert := true
var etape := ""
var premier := {}
var _signature := ""
var _titre: Label
var _texte: Label
var _caisse: Label
var _actions: VBoxContainer
var _progression: ProgressBar
var _detail: Label
var _corps: VBoxContainer
var _dernier_mois := -1.0
var _proteger: Button
var _reperes: Node3D


func batir(maquette) -> void:
	jeu = maquette
	var ui = jeu.interface
	theme = ui._theme_ui
	add_theme_stylebox_override("panel", ui._boite())
	offset_left = ui.DETAIL_X
	offset_right = ui.DETAIL_X + ui.DETAIL_LARGEUR
	offset_top = ui.HAUT
	custom_minimum_size.x = ui.DETAIL_LARGEUR
	minimum_size_changed.connect(func() -> void: size.y = get_combined_minimum_size().y)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	add_child(v)
	var entete := HBoxContainer.new()
	v.add_child(entete)
	var nom: Label = ui._capitale("Après la crue", 13, ui.ACCENT)
	nom.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	entete.add_child(nom)
	var fermer := Button.new()
	fermer.text = "−"
	fermer.tooltip_text = "Réduire les premiers pas. Le bouton DÉBUT les rouvre."
	fermer.pressed.connect(func() -> void:
		ouvert = false
		actualiser(true))
	entete.add_child(fermer)
	_corps = VBoxContainer.new()
	_corps.add_theme_constant_override("separation", 10)
	v.add_child(_corps)
	_titre = _paragraphe("", 22)
	_texte = _paragraphe("", 14)
	_caisse = _paragraphe("", 13)
	_caisse.add_theme_color_override("font_color", ui.ACCENT)
	_progression = ProgressBar.new()
	_progression.custom_minimum_size.y = 8
	_progression.show_percentage = false
	_corps.add_child(_progression)
	_detail = _paragraphe("", 12)
	_actions = VBoxContainer.new()
	_actions.add_theme_constant_override("separation", 8)
	_corps.add_child(_actions)
	ui._sans_focus(self)
	_reperes = Node3D.new()
	_reperes.name = "PremiersLieux"
	jeu.monde.add_child(_reperes)
	for lieu in [["r", RUE, "①"], ["i", MAISONS, "②"]]:
		var mi: MeshInstance3D = jeu.noeuds[lieu[0]][lieu[1]]
		var boite := mi.get_aabb()
		var repere := Label3D.new()
		repere.text = lieu[2]
		repere.font_size = 64
		repere.pixel_size = 0.20
		repere.modulate = ui.ACCENT_VIF
		repere.outline_modulate = ui.TEXTE
		repere.outline_size = 12
		repere.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_reperes.add_child(repere)
		repere.global_position = mi.to_global(boite.get_center())
		repere.global_position.y = mi.global_position.y + boite.end.y + 9.0
	actualiser(true)


func _paragraphe(texte: String, taille: int) -> Label:
	var l: Label = jeu.interface._label(texte, taille, jeu.interface.TEXTE)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_corps.add_child(l)
	return l


func _bouton(texte: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = texte
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(action)
	_actions.add_child(b)
	return b


func _nom(couche: String, fid: int) -> String:
	return jeu.interface.lieux.nom(couche, fid)


func examiner(couche: String, fid: int, reglage := "", valeur: Variant = true) -> void:
	# Une proposition ouvre la vraie fiche et sa miniature ; seul son bouton paie.
	jeu._sur_theme("")
	jeu.interface._detail_ouvert = false
	jeu.interface._placer_detail()
	jeu.selection.sel_couche = couche
	jeu.selection.sel_fid = fid
	jeu.selection.survol_fid = -1
	jeu._sur_choix(couche, fid)
	if couche == "r":
		jeu._viser_route(fid, 180.0)
	else:
		jeu._viser_objet(couche, fid, 260.0 if couche == "b" else 200.0)
	jeu.interface._vider_pose()
	if reglage == "solaire":
		jeu.interface.viser(float(valeur) * 100.0)
	elif reglage != "":
		jeu.interface.poser(reglage, valeur)
	jeu._rafraichir(true)
	actualiser(true)


func _reparation(couche: String, fid: int, titre: String) -> void:
	var v = jeu.ville
	var texte := titre
	var reglage := "reparer"
	if v.reparation_finie(couche, fid, jeu.mois):
		texte += "\nLivré · voir le lieu"
		reglage = ""
	elif v.est_repare(couche, fid):
		texte += "\nEn travaux · voir l'avancement"
		reglage = ""
	else:
		texte += "\n%.0f k€ · %s" % [v.cout_reparation_ke(couche, fid),
			jeu.interface._duree(v.duree_reparation_mois(couche, fid))]
	_bouton(texte, examiner.bind(couche, fid, reglage))


func _premiere_reparation() -> Dictionary:
	var out := {}
	var fin := INF
	for cle in jeu.ville._repare:
		var morceaux: PackedStringArray = str(cle).split(":")
		var couche := morceaux[0]
		var fid := int(morceaux[1])
		var livraison: float = jeu.ville._repare[cle] + jeu.ville.duree_reparation_mois(couche, fid)
		if livraison < fin:
			fin = livraison
			out = {"couche": couche, "fid": fid, "fin": fin}
	return out


func actualiser(force := false) -> void:
	visible = ouvert and not jeu.interface._detail_ouvert
	if _reperes != null:
		_reperes.visible = visible and jeu.theme == "" and not suite and not termine
	if not force and absf(jeu.mois - _dernier_mois) < 0.02:
		return
	_dernier_mois = jeu.mois
	premier = _premiere_reparation()
	var ancienne := etape
	if termine:
		etape = "libre"
	elif suite:
		etape = "suite"
	elif premier.is_empty():
		etape = "choix"
	elif jeu.mois < float(premier["fin"]):
		etape = "travaux"
	else:
		etape = "livraison"
	if etape == "livraison" and ancienne == "travaux" and ouvert:
		jeu._sur_vitesse(0.0)
		jeu.interface._detail_ouvert = false
		jeu.interface._placer_detail()
		visible = true
	_caisse.text = "Caisse disponible : %.0f k€" % jeu.ville.caisse_ke(jeu.mois)
	_progression.visible = etape == "travaux"
	_detail.visible = etape == "travaux" or etape == "suite"
	if etape == "travaux":
		var duree: float = jeu.ville.duree_reparation_mois(premier["couche"], premier["fid"])
		var reste: float = float(premier["fin"]) - jeu.mois
		_progression.value = (1.0 - reste / duree) * 100.0
		_detail.text = "Encore %.1f mois · ×12 : environ %d s" % [reste, int(ceil(reste * 5.0))]
	elif etape == "suite":
		_detail.text = "Aux maisons des Forgerons, hauteur d'eau prévue : %.2f m → %.2f m.\nCrue de référence · sans date annoncée." % [
			jeu.ville.base("i", MAISONS, "hauteur_eau_annonce"),
			jeu.ville.valeur("i", MAISONS, "hauteur_eau_annonce", jeu.mois)]
		_maj_protection()
	# Les boutons restent en place sous le doigt ; seuls les changements de décision les refont.
	var signature := "%s/%s/%s/%s/%s/%s/%s/%s" % [etape, premier,
		jeu.ville.est_repare("r", RUE), jeu.ville.est_repare("i", MAISONS),
		jeu.ville.reparation_finie("r", RUE, jeu.mois),
		jeu.ville.reparation_finie("i", MAISONS, jeu.mois),
		jeu.ville.berge_etat(BERGE, jeu.mois), jeu.ville._solaire.has(SOLAIRE)]
	if signature == _signature and not force:
		return
	_signature = signature
	_proteger = null
	for enfant in _actions.get_children():
		_actions.remove_child(enfant)
		enfant.queue_free()
	match etape:
		"choix":
			_titre.text = "Un premier lieu à relever"
			_texte.text = "La rue des Forgerons est envasée. À côté, %.0f logements sont inhabitables. Par quoi commencer ?\n\nComparez les deux chantiers, puis engagez celui qui vous convient dans sa fiche." % jeu.ville.base("i", MAISONS, "logements_sinistres")
			_reparation("r", RUE, "① Déblayer la rue")
			_reparation("i", MAISONS, "② Relever les logements")
		"travaux":
			_titre.text = "Le premier chantier avance"
			_texte.text = "%s se répare. La ville changera à la livraison. Vous pouvez préparer un autre lieu pendant les travaux." % _nom(premier["couche"], premier["fid"])
			_bouton("Voir mon chantier", examiner.bind(premier["couche"], premier["fid"]))
			_bouton("Laisser avancer · ×12", func() -> void: jeu._sur_vitesse(12.0))
			if premier["couche"] == "r":
				_reparation("i", MAISONS, "Comparer les logements")
			else:
				_reparation("r", RUE, "Comparer la rue")
		"livraison":
			_titre.text = "Un lieu reprend vie"
			if premier["couche"] == "r":
				_texte.text = "%s est de nouveau praticable. Les piétons peuvent y revenir.\n\nRéparer les lieux ne diminue pas leur exposition à une prochaine crue." % _nom("r", premier["fid"])
			else:
				_texte.text = "%s : %.0f logements remis en état.\n\nRéparer n'a pas diminué leur exposition à une prochaine crue." % [_nom("i", premier["fid"]), jeu.ville.base("i", premier["fid"], "logements_sinistres")]
			_bouton("Voir le résultat", examiner.bind(premier["couche"], premier["fid"]))
			_bouton("Et maintenant ?", func() -> void:
				suite = true
				actualiser(true))
		"suite":
			_titre.text = "Réparer, protéger ou investir ?"
			_texte.text = "La réparation rend les lieux utilisables. La renaturation de la berge baisse l'eau attendue ici ; le solaire apporte des recettes. Ces projets se partagent votre caisse."
			_reparation("i", MAISONS, "Poursuivre les réparations")
			if not jeu.ville.est_repare("r", RUE):
				_reparation("r", RUE, "Rendre aussi la rue praticable")
			_proteger = _bouton("Protéger · renaturer la berge",
				examiner.bind("b", BERGE, "berge", Ville.BERGE_RENATUREE))
			_bouton("Investir · comparer les toits solaires",
				examiner.bind("i", SOLAIRE, "solaire", 0.3))
			_bouton("Continuer à mon rythme", func() -> void:
				termine = true
				ouvert = false
				actualiser(true))
			_maj_protection()
		"libre":
			_titre.text = "À vous de choisir la suite"
			_texte.text = "Votre premier lieu est relevé. La ville reste ouverte à vos projets."
			_bouton("Revoir les pistes", func() -> void:
				termine = false
				suite = true
				actualiser(true))
	reset_size()


func _maj_protection() -> void:
	if not is_instance_valid(_proteger):
		return
	var cout: float = jeu.ville.cout_berge_ke(BERGE, Ville.BERGE_RENATUREE, jeu.mois)
	var manque: float = maxf(0.0, cout - jeu.ville.caisse_ke(jeu.mois))
	var duree: float = jeu.ville.duree_commande_mois("b", BERGE, {"berge": Ville.BERGE_RENATUREE}, jeu.mois)
	var prix := "%.0f k€ · %.0f mois" % [cout, duree]
	if manque > 0.0:
		prix += "\nÀ épargner : %.0f k€" % manque
	if jeu.ville.berge_etat(BERGE, jeu.mois) == Ville.BERGE_RENATUREE:
		prix = "Livrée · voir la rive"
		_titre.text = "La protection commence à agir"
		_texte.text = "La rive a changé et l'eau attendue aux maisons des Forgerons a baissé. Le secteur reste exposé : regardez ce qu'il reste à protéger avant de choisir la suite."
	elif jeu.ville.berge_en_cours(BERGE, jeu.mois):
		prix = "En travaux · la protection attend la livraison"
	_proteger.text = "Protéger · renaturer la berge\n" + prix


func exporter() -> Dictionary:
	return {"suite": suite, "termine": termine, "ouvert": ouvert}


func reprendre(etat: Dictionary) -> void:
	suite = bool(etat.get("suite", false))
	termine = bool(etat.get("termine", false))
	ouvert = bool(etat.get("ouvert", true))
	etape = ""
	_signature = ""
	actualiser(true)
