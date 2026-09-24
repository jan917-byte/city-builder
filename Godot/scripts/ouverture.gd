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
var trafic_vu := false
var pont_termine := false
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
var _legende: VBoxContainer
var _dernier_mois := -1.0
var _proteger: Button
var _reperes: Node3D
var _reperes_poses := ""
var _champs := []
## 🧭 Les lieux déjà ouverts pendant le relogement, et si l'un d'eux était un
## champ : c'est ce qui décide de l'indice.
var _regards := {}
var _champ_vu := false


func batir(maquette) -> void:
	jeu = maquette
	var ui = jeu.interface
	theme = ui._theme_ui
	ui._poser_boite(self)
	offset_left = ui.DETAIL_X
	offset_right = ui.DETAIL_X + ui.DETAIL_LARGEUR
	offset_top = ui.HAUT
	custom_minimum_size.x = ui.DETAIL_LARGEUR
	minimum_size_changed.connect(func() -> void: size.y = get_combined_minimum_size().y)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	add_child(v)
	var entete := HBoxContainer.new()
	# Sans titre de chapitre (auteur, 2026-09-18) : le titre de l'étape suffit.
	entete.alignment = BoxContainer.ALIGNMENT_END
	v.add_child(entete)
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
	_legende_trafic(ui)
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
	actualiser(true)


## 🌉 Pendant la phase du pont, ce panneau remplace celui du calque Trafic :
## il en porte donc la légende, mêmes couleurs, mêmes mots.
func _legende_trafic(ui) -> void:
	var t: Dictionary = {}
	for th in jeu.THEMES:
		if th["id"] == "trafic":
			t = th
	_legende = VBoxContainer.new()
	_legende.add_theme_constant_override("separation", 4)
	_corps.add_child(_legende)
	var barre := TextureRect.new()
	barre.texture = ui._texture_rampe()
	barre.custom_minimum_size = Vector2(0, 13)
	barre.stretch_mode = TextureRect.STRETCH_SCALE
	barre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_legende.add_child(barre)
	var h := HBoxContainer.new()
	h.add_child(ui._label(str(t.get("bas", "")), 12, ui.GRIS))
	var haut: Label = ui._label(str(t.get("haut", "")), 12, ui.GRIS)
	haut.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	haut.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(haut)
	_legende.add_child(h)
	ui._legende(_legende, jeu.COUPEE, "Coupée par la crue · pont emporté ou boue")


# Les repères du guide restent dans l'interface (décision 85).
func _poser_reperes(_lieux: Array) -> void:
	pass


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


func _nom_champ(fid: int) -> String:
	return jeu.interface.lieux.nom("i", fid, "Champ")


## 🔒 LES PREMIÈRES MINUTES SE JOUENT DANS L'ORDRE (auteur, 2026-09-22) :
## « reloger » tant qu'une personne est dehors, « pont » tant qu'aucun pont ne
## relie les rives avec ses accès, puis plus rien. Levé pour de bon dès que le
## joueur choisit la suite : fermer une rue plus tard ne le remet pas.
func verrou() -> String:
	if pont_termine or suite or termine:
		return ""
	if jeu.ville.sans_toit(jeu.mois) > 0.0:
		return "reloger"
	for p in jeu.ville.ponts_coupes():
		if jeu.trafic.pont_fonctionnel(p, jeu.mois):
			return ""
	return "pont"


## Ce que le verrou laisse engager : un champ pendant le relogement ; un pont
## coupé ou une rue qui barre l'accès à l'un d'eux pendant la phase du pont.
func autorise(couche: String, fid: int) -> bool:
	match verrou():
		"":
			return true
		"reloger":
			return couche == "i" and jeu.ville.camp_possible(fid)
	return couche == "r" and fid in _rues_du_pont()


var _rues_cle := ""
var _rues := []


func _rues_du_pont() -> Array:
	# Recalculé au jour ou à la commande : la fiche le demande à chaque image.
	var cle := "%d/%d" % [int(jeu.mois * 30.0), jeu.ville._repare.hash()]
	if cle != _rues_cle:
		_rues_cle = cle
		_rues = []
		for p in jeu.ville.ponts_coupes():
			_rues.append(p)
			for rue in jeu.trafic.acces_pont(p, jeu.mois)["obstacles"]:
				if not rue in _rues:
					_rues.append(rue)
	return _rues


func examiner(couche: String, fid: int, reglage := "", valeur: Variant = true) -> void:
	# Une proposition ouvre la vraie fiche et sa miniature ; seul son bouton paie.
	if couche != "r" or not fid in jeu.ville.ponts_coupes():
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


## 🌉 Les champs que les sinistrés peuvent atteindre, du plus grand au plus
## petit. Aucune liste de fid : c'est le morceau de réseau mesuré par `07`, donc
## redessiner un pont déplace la scène sans toucher à ce fichier.
func _champs_accessibles() -> Array:
	if not _champs.is_empty():
		return _champs
	for fid in jeu.ville.ilots:
		if jeu.ville.camp_possible(int(fid)) and jeu.ville.camp_accessible(int(fid)):
			_champs.append(int(fid))
	_champs.sort_custom(func(a, b) -> bool:
		return jeu.ville.camp_places_max(a) > jeu.ville.camp_places_max(b))
	return _champs


## 🧭 CE QUI ORIENTE SANS DIRE OÙ : le panneau ne rappelle ce qu'un camp
## demande qu'après quelques lieux ouverts, et jamais si le joueur a déjà
## ouvert un champ. 🎚️ LEVEL DESIGN : le nombre de lieux regardés.
const INDICE_REGARDS := 3


func regarde(couche: String, fid: int) -> void:
	if etape != "reloger":
		return
	var cle := "%s%d" % [couche, fid]
	if _regards.has(cle):
		return
	_regards[cle] = true
	if couche == "i" and jeu.ville.camp_possible(fid):
		_champ_vu = true
	actualiser(true)


func _camp_pose() -> bool:
	for fid in _champs_accessibles():
		if jeu.ville.camp_pose(fid):
			return true
	# Un camp posé ailleurs compte aussi : c'est une décision prise, même ratée.
	for fid in jeu.ville.ilots:
		if jeu.ville.camp_pose(int(fid)):
			return true
	return false


func _premiere_reparation() -> Dictionary:
	var out := {}
	var fin := INF
	for cle in jeu.ville._repare:
		var morceaux: PackedStringArray = str(cle).split(":")
		var couche := morceaux[0]
		var fid := int(morceaux[1])
		if couche == "r" and fid in jeu.ville.ponts_coupes():
			continue
		var livraison: float = jeu.ville._repare[cle] + jeu.ville.duree_reparation_mois(couche, fid)
		if livraison < fin:
			fin = livraison
			out = {"couche": couche, "fid": fid, "fin": fin}
	return out


func _premier_pont() -> Dictionary:
	var out := {}
	for fid in jeu.ville.ponts_coupes():
		if not jeu.ville.est_repare("r", fid):
			continue
		var fin: float = jeu.ville._repare["r:%d" % fid] + jeu.ville.duree_reparation_mois("r", fid)
		if jeu.trafic.pont_fonctionnel(fid, jeu.mois):
			return {"couche": "r", "fid": fid, "fin": fin}
		if out.is_empty() or fin < float(out["fin"]):
			out = {"couche": "r", "fid": fid, "fin": fin}
	return out


func voir_trafic() -> void:
	if not _camp_pose() or pont_termine or suite or termine:
		return
	var premiere_fois := not trafic_vu
	trafic_vu = true
	if ouvert:
		jeu.interface._detail_ouvert = false
		jeu.interface._placer_detail()
		if premiere_fois:
			jeu._repere("ville")
	actualiser(true)


func description_pont(fid: int) -> String:
	if jeu.trafic.pont_fonctionnel(fid, jeu.mois):
		return "Les deux rives sont reliées."
	var p: Dictionary = jeu.trafic.prevoir_pont(fid, jeu.mois)
	var acces: Dictionary = p["acces"]
	var cout := 0.0
	var delai := 0.0
	for route in [fid] + acces["obstacles"]:
		if not jeu.ville.est_repare("r", route):
			cout += jeu.ville.cout_reparation_ke("r", route)
			delai = maxf(delai, jeu.ville.duree_reparation_mois("r", route))
		else:
			delai = maxf(delai, jeu.ville.reste_reparation_mois("r", route, jeu.mois))
	var ui = jeu.interface
	if not acces["possible"]:
		return "Aucun accès continu aux routes principales : vérifier les fermetures voisines."
	# Trois lignes au plus : le prix total, ce qui reste à déblayer, la rue qui
	# prendra les voitures.
	var lignes := []
	if cout > 0.0:
		lignes.append("Pont et accès : %s k€ · %s." % [ui._milliers(cout), ui._duree(delai)])
	var n: int = acces["obstacles"].size()
	if n > 0:
		lignes.append("%d rue%s à déblayer pour y accéder." % [n, "s" if n > 1 else ""])
	elif jeu.ville.reparation_finie("r", fid, jeu.mois):
		lignes.append("Accès encore coupés.")
	if int(p["rue"]) >= 0:
		lignes.append("%s : trafic %d → %d %%." % [_nom("r", int(p["rue"])),
			int(roundf(100.0 * float(p["avant"]))), int(roundf(100.0 * float(p["apres"])))])
	return "\n".join(lignes)


func voir_acces(fid: int) -> void:
	var acces: Dictionary = jeu.trafic.acces_pont(fid, jeu.mois)
	jeu._sur_theme("trafic")
	var groupe := Node3D.new()
	groupe.name = "AccesTemporaires"
	jeu.monde.add_child(groupe)
	var limites := AABB()
	var premier_lieu := true
	for rue in [fid] + acces["rues"]:
		if not jeu.donnees["couloirs"].has(str(rue)):
			continue
		var c: Array = jeu.donnees["couloirs"][str(rue)]
		var ruban := MeshInstance3D.new()
		ruban.mesh = jeu.Constructeur.couloir(c[1], 3.0, 3.0)
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color = Color(0.85, 0.25, 0.15, 0.65) if rue in acces["obstacles"] else Color(0.1, 0.65, 0.48, 0.65)
		ruban.material_override = mat
		ruban.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		groupe.add_child(ruban)
		limites = ruban.get_aabb() if premier_lieu else limites.merge(ruban.get_aabb())
		premier_lieu = false
	if not premier_lieu:
		jeu.pivot.viser(Vector2(limites.get_center().x, limites.get_center().z), maxf(220.0, limites.size.length() * 1.3))
	jeu.get_tree().create_timer(8.0).timeout.connect(func() -> void:
		if is_instance_valid(groupe):
			groupe.queue_free())


func _choisir_pont(fid: int) -> void:
	examiner("r", fid, "" if jeu.ville.est_repare("r", fid) else "reparer")


func actualiser(force := false) -> void:
	visible = ouvert and not jeu.interface._detail_ouvert
	if _reperes != null:
		_reperes.visible = visible and jeu.theme in ["", "trafic"] and not suite and not termine
		# Même règle que les pastilles : taille constante à l'écran.
		for r in _reperes.get_children():
			(r as Label3D).pixel_size = jeu.pivot.taille * 0.0012
	# Deux fois : changer de calque ne fait pas avancer le temps, et l'étape change après.
	_legende.visible = jeu.theme == "trafic" and etape.begins_with("pont")
	if not force and absf(jeu.mois - _dernier_mois) < 0.02:
		return
	_dernier_mois = jeu.mois
	if _camp_pose() and jeu.theme == "trafic":
		trafic_vu = true
	premier = _premiere_reparation()
	var pont := _premier_pont()
	var ancienne := etape
	if termine:
		etape = "libre"
	elif suite:
		etape = "suite"
	elif jeu.ville.besoin_non_couvert(jeu.mois) > 0.0:
		# 🏕️ LA PREMIÈRE DÉCISION DE LA PARTIE : 260 personnes sont dehors, et
		# le seul terrain qu'elles peuvent atteindre est celui que la rivière
		# reprend en premier. Elle passe AVANT le budget des réparations.
		# 🔒 Et elle dure tant qu'une seule personne n'a pas de place (auteur,
		# 2026-09-22) : le pont n'est proposé qu'ensuite.
		etape = "reloger"
	elif not pont_termine:
		if not pont.is_empty():
			premier = pont
			if jeu.mois < float(pont["fin"]):
				etape = "pont_travaux"
			else:
				etape = "pont_livre" if jeu.trafic.pont_fonctionnel(int(pont["fid"]), jeu.mois) else "pont_acces"
		elif jeu.ville.sans_toit(jeu.mois) > 0.0:
			etape = "camp_attente"
		else:
			etape = "pont_choix" if trafic_vu else "trafic"
	elif premier.is_empty():
		etape = "choix"
	elif jeu.mois < float(premier["fin"]):
		etape = "travaux"
	else:
		etape = "livraison"
	if (etape == "livraison" and ancienne == "travaux" or
			etape == "pont_livre" and ancienne != "pont_livre") and ouvert:
		jeu._sur_vitesse(0.0)
		jeu.interface._detail_ouvert = false
		jeu.interface._placer_detail()
		visible = true
	_legende.visible = jeu.theme == "trafic" and etape.begins_with("pont")
	_caisse.text = "Caisse : %.0f k€" % jeu.ville.caisse_ke(jeu.mois)
	_progression.visible = etape in ["travaux", "pont_travaux"]
	_detail.visible = _progression.visible or etape == "suite"
	if _progression.visible:
		var duree: float = jeu.ville.duree_reparation_mois(premier["couche"], premier["fid"])
		var reste: float = float(premier["fin"]) - jeu.mois
		_progression.value = (1.0 - reste / duree) * 100.0
		_detail.text = "Encore %s · ×12 : environ %d s" % [jeu.interface._duree(reste), int(ceil(reste * 5.0))]
	elif etape == "suite":
		_detail.text = "Eau attendue aux maisons des Forgerons : %s m → %s m." % [
			jeu.interface._nb(jeu.ville.base("i", MAISONS, "hauteur_eau_annonce"), 2),
			jeu.interface._nb(jeu.ville.valeur("i", MAISONS, "hauteur_eau_annonce", jeu.mois), 2)]
		_maj_protection()
	# Les boutons restent en place sous le doigt ; seuls les changements de décision les refont.
	var signature := "%s/%s/%s/%s/%s/%s/%s/%s/%d" % [etape, premier,
		jeu.ville.est_repare("r", RUE), jeu.ville.est_repare("i", MAISONS),
		jeu.ville.reparation_finie("r", RUE, jeu.mois),
		jeu.ville.reparation_finie("i", MAISONS, jeu.mois),
		jeu.ville.berge_etat(BERGE, jeu.mois), jeu.ville._solaire.has(SOLAIRE),
		int(jeu.ville.sans_toit(jeu.mois) * 1000.0 + jeu.ville.besoin_non_couvert(jeu.mois))]
	signature += "/%d/%s/%s/%d" % [_regards.size(), _champ_vu, jeu.trafic._indisponibles_connues,
		jeu.ville._camps.size()]
	if signature == _signature:
		return
	_signature = signature
	_proteger = null
	for enfant in _actions.get_children():
		_actions.remove_child(enfant)
		enfant.queue_free()
	match etape:
		"camp_attente":
			_poser_reperes([])
			_titre.text = "Les premiers abris arrivent"
			_texte.text = "Les containers sont en route."
			_bouton("Laisser avancer · ×12", func() -> void: jeu._sur_vitesse(12.0))
		"trafic":
			_poser_reperes([])
			_titre.text = "Pourquoi les deux rives restent-elles séparées ?"
			_texte.text = "Tout le monde est à l'abri. Plus aucun pont ne relie les deux rives : ouvrez le trafic pour choisir lequel rebâtir."
			_bouton("Ouvrir le trafic", func() -> void: jeu.interface._sur_rail("trafic"))
		"pont_choix":
			_titre.text = "Rebâtir un pont"
			_texte.text = "Comparez les trois, puis engagez-en un dans sa fiche. Rien d'autre ne s'engage avant qu'un pont soit rouvert."
			# 🌉 Un bouton par pont (auteur, 2026-09-22) : on les trouvait mal sur
			# la carte. Les repères restent dans l'interface (85), la carte reste nue.
			for fid in jeu.ville.ponts_coupes():
				_reparation("r", fid, _nom("r", fid))
		"pont_acces":
			_titre.text = "Le pont attend ses accès"
			_texte.text = description_pont(int(premier["fid"]))
			_bouton("Voir les accès", voir_acces.bind(int(premier["fid"])))
			for fid in jeu.trafic.acces_pont(int(premier["fid"]), jeu.mois)["obstacles"]:
				_reparation("r", fid, _nom("r", fid))
		"pont_travaux":
			_poser_reperes([["r", premier["fid"], str(jeu.ville.ponts_coupes().find(premier["fid"]) + 1)]])
			_titre.text = "Le pont se reconstruit"
			_texte.text = "%s : la traversée reste coupée jusqu'à la livraison." % _nom("r", premier["fid"])
			_bouton("Laisser avancer · ×12", func() -> void: jeu._sur_vitesse(12.0))
			_bouton("Voir mon pont", examiner.bind("r", premier["fid"]))
			_bouton("Voir les accès", voir_acces.bind(int(premier["fid"])))
		"pont_livre":
			_poser_reperes([["r", premier["fid"], str(jeu.ville.ponts_coupes().find(premier["fid"]) + 1)]])
			_titre.text = "Les deux rives sont reliées"
			_texte.text = "%s est rouvert. Les autres rues envasées restent à déblayer." % _nom("r", premier["fid"])
			_bouton("Voir le pont rouvert", func() -> void:
				jeu._sur_theme("")
				examiner("r", premier["fid"]))
			_bouton("Observer le trafic", func() -> void: jeu._sur_theme("trafic"))
			_bouton("Choisir la suite", func() -> void:
				pont_termine = true
				jeu._sur_theme("")
				jeu.interface._detail_ouvert = false
				jeu.interface._placer_detail()
				actualiser(true))
		"reloger":
			# 🧭 ON NE MONTRE PAS LES TROIS CHAMPS (auteur, 2026-09-17) :
			# ni chiffre sur la carte, ni bouton qui y mène. Le joueur cherche
			# un endroit, et c'est la fiche qui répond — seul un champ ouvre le
			# bloc de relogement, et un champ de l'autre rive le prévient.
			var sans_toit: float = jeu.ville.sans_toit(jeu.mois)
			var coupes: int = int(jeu.ville.degats(jeu.mois)["franchissements_coupes"])
			var commandees: int = jeu.ville.places_commandees(jeu.mois)
			_titre.text = "%d personnes sont dehors" % int(sans_toit)
			_texte.text = "Les %d ponts sont coupés : elles ne peuvent pas quitter leur rive.

Cliquez sur un lieu pour voir ce qu'il peut accueillir." % coupes
			if commandees > 0:
				_texte.text = "Les abris commandés en accueilleront %d. Il manque encore %d places : trouvez un autre terrain." % [
					commandees, int(jeu.ville.besoin_non_couvert(jeu.mois))]
			for fid in jeu.ville._camps:
				if not jeu.ville.camp_accessible(int(fid), jeu.mois):
					_texte.text += "\n\nPersonne ne peut rejoindre %s : il est sur l'autre rive." % _nom_champ(int(fid))
			if _regards.size() >= INDICE_REGARDS and not _champ_vu:
				_texte.text += "

Un camp de containers demande un terrain nu : rien de bâti, rien à démolir."
			_poser_reperes([])
		"choix":
			_poser_reperes([["r", RUE, "①"], ["i", MAISONS, "②"]])
			_titre.text = "Un premier lieu à relever"
			# ⚖️ LE CHOIX SE LIT DANS SES EFFETS (auteur, 2026-09-22) : la rue coûte
			# peu et ne rend personne chez soi ; les logements coûtent cher et
			# vident d'autant les camps.
			var logements: float = jeu.ville.base("i", MAISONS, "logements_sinistres")
			# Tout le monde est abrité à ce stade : ceux qui rentrent quittent un camp.
			var abrites := int(minf(logements, jeu.ville.sans_toit(jeu.mois) + jeu.ville.reloges(jeu.mois)))
			_texte.text = "La rue des Forgerons est envasée ; à côté, %.0f logements sont inhabitables. Par quoi commencer ?" % logements
			_reparation("r", RUE, "① Déblayer la rue")
			_reparation("i", MAISONS, "② Relever les logements" + (
				" · %d personnes rentrent chez elles" % abrites if abrites > 0 else ""))
		"travaux":
			_titre.text = "Le premier chantier avance"
			_texte.text = "%s : chantier en cours." % _nom(premier["couche"], premier["fid"])
			_bouton("Laisser avancer · ×12", func() -> void: jeu._sur_vitesse(12.0))
			_bouton("Voir mon chantier", examiner.bind(premier["couche"], premier["fid"]))
			if premier["couche"] == "r":
				_reparation("i", MAISONS, "Comparer les logements")
			else:
				_reparation("r", RUE, "Comparer la rue")
		"livraison":
			_titre.text = "Un lieu reprend vie"
			if premier["couche"] == "r":
				_texte.text = "%s est de nouveau praticable.\n\nRéparer ne diminue pas l'exposition à une prochaine crue." % _nom("r", premier["fid"])
			else:
				_texte.text = "%s : %.0f logements remis en état.\n\nRéparer n'a pas diminué leur exposition à une prochaine crue." % [_nom("i", premier["fid"]), jeu.ville.base("i", premier["fid"], "logements_sinistres")]
			_bouton("Voir le résultat", examiner.bind(premier["couche"], premier["fid"]))
			_bouton("Et maintenant ?", func() -> void:
				suite = true
				actualiser(true))
		"suite":
			_titre.text = "Réparer, protéger ou investir ?"
			_texte.text = "Réparer rend les lieux habitables, renaturer la berge baisse l'eau attendue, le solaire rapporte. Tout se paie sur la même caisse."
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
		_texte.text = "L'eau attendue aux maisons des Forgerons a baissé, mais le secteur reste exposé."
	elif jeu.ville.berge_en_cours(BERGE, jeu.mois):
		prix = "En travaux · la protection attend la livraison"
	_proteger.text = "Protéger · renaturer la berge\n" + prix


func exporter() -> Dictionary:
	return {"suite": suite, "termine": termine, "ouvert": ouvert,
		"trafic_vu": trafic_vu, "pont_termine": pont_termine}


func reprendre(etat: Dictionary) -> void:
	_regards.clear()
	_champ_vu = false
	suite = bool(etat.get("suite", false))
	termine = bool(etat.get("termine", false))
	ouvert = bool(etat.get("ouvert", true))
	trafic_vu = bool(etat.get("trafic_vu", false))
	pont_termine = bool(etat.get("pont_termine", suite or termine))
	etape = ""
	_signature = ""
	actualiser(true)
