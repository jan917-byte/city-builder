extends PanelContainer
## Première boucle d'essai : les étapes se déduisent des chantiers réellement livrés.

const Ville := preload("res://scripts/ville.gd")
const Livre := preload("res://scripts/livre.gd")
# Lieux touchés dans l’emprise corrigée le 2026-09-16.
const RUE := 148
const MAISONS := 59
const BERGE := 3
const SOLAIRE := 32
# 🎚️ Les exemples de la prochaine crue, PROPOSÉS, à régler par l'auteur : le plus
# grand toit plat de Wehrau, un champ quelconque — la baisse vaut pour toute la ville.
const TOIT_PLAT := 31
const PRE := 1065
const PARKING := 19   # la place-parking, le sol qu'on rend perméable (101)

var jeu
var suite := false
var termine := false
var ouvert := true
var trafic_vu := false
var pont_termine := false
## Le mois où l'on quitte la carte du pont rouvert : une rue engagée avant appartient au pont.
var pont_termine_mois := 0.0
## 🎓 L'étude de l'université paraît en quittant cette carte (auteur,
## 2026-09-30) : on l'a lue, puis on a ouvert Dangers › Prochaine crue.
var etude_lue := false
var prochaine_vue := false
## ⏳ La carte du pont attend 5 s réelles, le temps qui court (auteur, 2026-10-06) :
## on voit le pont s'ouvrir et les voitures passer avant l'étude.
const ATTENTE_ETUDE_MS := 5000
var pont_livre_ms := 0
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
## 🧹 L'annonce du chemin dégagé : -1 après une reprise, 0 à dire, 1 dite.
var _degage_annonce := 0
## 🎓 Les cartes au centre (auteur, 2026-10-02) : « pont » remplace « Choisir la
## suite » et mène à l'étude ; « camp » dit que le camp use la confiance.
var annonce: Control
var annonce_principal: Button
var annonce_second: Button
var carte := ""
var _annonce_titre: Label
var _annonce_texte: Label
## 🚿 La plainte du camp : 0 à venir, 1 affichée, 2 passée. Elle tombe quand
## l'usure commence (`Ville.CAMP_USURE_APRES_PONT_MOIS`).
var plainte := 0
var deblaiement_vu := false
## 📖 Les pages du livre déjà ouvertes : « nouveau » sur les autres (101).
var pages_lues := {}


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
	_corps = VBoxContainer.new()
	_corps.add_theme_constant_override("separation", 10)
	add_child(_corps)
	# 🔄 Le « − » sur la ligne du titre (auteur, 2026-09-28) : seul en tête, il
	# creusait une ligne vide au-dessus.
	var entete := HBoxContainer.new()
	_corps.add_child(entete)
	_titre = ui._label("", 22, ui.TEXTE)
	_titre.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_titre.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	entete.add_child(_titre)
	var fermer := Button.new()
	fermer.text = "−"
	fermer.tooltip_text = "Réduire les premiers pas. Le bouton Début les rouvre."
	fermer.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	fermer.pressed.connect(func() -> void:
		ouvert = false
		actualiser(true))
	entete.add_child(fermer)
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
	_batir_annonce(ui)
	_reperes = Node3D.new()
	_reperes.name = "PremiersLieux"
	jeu.monde.add_child(_reperes)
	actualiser(true)


## Modale : le temps est en pause et rien d'autre ne se clique tant qu'on n'a pas choisi.
func _batir_annonce(ui) -> void:
	annonce = Control.new()
	annonce.name = "AnnonceEtude"
	annonce.theme = ui._theme_ui
	annonce.mouse_filter = Control.MOUSE_FILTER_STOP
	annonce.visible = false
	jeu.interface.add_child(annonce)
	# 🎈 Au-dessus des chiffres qui montent (auteur, 2026-10-05) : ils passaient devant le texte.
	annonce.z_index = 1
	# ⚠️ Ancres ET marges, comme le récit : sinon le rectangle reste nul.
	annonce.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var voile := ColorRect.new()
	voile.color = Color(0, 0, 0, 0.25)
	voile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	annonce.add_child(voile)
	voile.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var centre := CenterContainer.new()
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	annonce.add_child(centre)
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var boite := PanelContainer.new()
	ui._poser_boite(boite)
	boite.custom_minimum_size.x = 440
	centre.add_child(boite)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	boite.add_child(v)
	_annonce_titre = ui._label("", 22, ui.TEXTE)
	_annonce_titre.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_annonce_titre)
	_annonce_texte = ui._label("", 14, ui.TEXTE)
	_annonce_texte.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_annonce_texte)
	annonce_principal = Button.new()
	ui._habiller_principal(annonce_principal)
	annonce_principal.pressed.connect(_sur_carte.bind(true))
	v.add_child(annonce_principal)
	annonce_second = Button.new()
	annonce_second.pressed.connect(_sur_carte.bind(false))
	v.add_child(annonce_second)
	ui._sans_focus(annonce)


## 🔴 Textes de prototype, flaggables (90).
func _remplir_carte() -> void:
	match carte:
		"pont":
			_annonce_titre.text = "Les deux rives sont reliées"
			_annonce_texte.text = "%s est rouvert.\nL'université vient de publier son étude sur la prochaine crue de l'Ilse. Trouvez-la dans la ville." \
				% _nom("r", premier["fid"])
			annonce_principal.text = "Trouver l'université"
			annonce_second.text = "Voir d'abord le pont"
		"camp":
			_annonce_titre.text = "Les habitants du camp sont mécontents"
			_annonce_texte.text = "Ils ont un toit, pas de quoi vivre. Tant qu'ils restent au camp, la confiance baisse chaque mois.\nPlus tard, c'est elle qui ouvrira les règles de la mairie."
			annonce_principal.text = "Voir le campement"
			annonce_second.text = "Plus tard"


func _sur_carte(principal: bool) -> void:
	if carte == "pont":
		var fid := int(premier["fid"])
		publier_etude()
		if principal:
			chercher_universite()
		else:
			examiner("r", fid)
		return
	plainte = 2
	if principal:
		examiner("i", camp_le_plus_plein())
	else:
		actualiser(true)


## Le camp où vivent le plus de gens : c'est lui que la plainte ouvre.
func camp_le_plus_plein() -> int:
	var meilleur := -1
	var plus := -1.0
	for fid in jeu.ville._camps:
		var n: float = jeu.ville.camp_occupants(int(fid), jeu.mois)
		if n > plus:
			plus = n
			meilleur = int(fid)
	return meilleur


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
## coupé ou une rue qui barre l'accès à l'un d'eux pendant la phase du pont, et
## toute rue boueuse dès qu'un pont est engagé (auteur, 2026-09-26). Les îlots
## sinistrés attendent l'étude : on rebâtit en sachant la prochaine crue (auteur,
## 2026-10-02, retour en arrière sur le 2026-09-26).
func autorise(couche: String, fid: int) -> bool:
	match verrou():
		"":
			return true
		"reloger":
			return couche == "i" and jeu.ville.camp_possible(fid)
	if couche == "i":
		return jeu.ville.camp_pose(fid)
	if couche != "r":
		return false
	if fid in _rues_du_pont():
		return true
	return _pont_engage() and not fid in jeu.ville.ponts_coupes() \
		and jeu.ville.base("r", fid, "cout_reparation_ke") > 0.0


func _pont_engage() -> bool:
	for p in jeu.ville.ponts_coupes():
		if jeu.ville.est_repare("r", p):
			return true
	return false


var _rues_cle := ""
var _rues := []
var _degage := false


func _rues_du_pont() -> Array:
	# Recalculé au jour ou à la commande : la fiche le demande à chaque image.
	var cle := "%d/%d" % [int(jeu.mois * 30.0), jeu.ville._repare.hash()]
	if cle != _rues_cle:
		_rues_cle = cle
		_rues = []
		_degage = false
		for p in jeu.ville.ponts_coupes():
			_rues.append(p)
			var acces: Dictionary = jeu.trafic.acces_pont(p, jeu.mois)
			if jeu.ville.est_repare("r", p) and acces["possible"] and acces["obstacles"].is_empty():
				_degage = true
			for rue in acces["obstacles"]:
				if not rue in _rues:
					_rues.append(rue)
	return _rues


## 🧹 Un pont engagé dont le chemin ne passe plus par la boue, livré ou non.
func acces_degage() -> bool:
	_rues_du_pont()
	return _degage


## 🧭 La colonne de gauche s'ouvre au fil du guide (auteur, 2026-10-02) : une
## tuile reste grise tant que le guide ne l'a pas demandée, puis reste ouverte.
func rail_ouvert(id: String) -> bool:
	if suite or termine or prochaine_vue or id == "":
		return true
	match id:
		"trafic":
			return not etape in ["", "reloger", "camp_attente"]
		"universite":
			return etude_lue
		"dangers":
			return etude_lue
	return false


## La tuile que le guide demande, entourée jusqu'au clic.
func rail_appel() -> String:
	# 🧹 Trafic s'entoure quand il propose de tout déblayer, jusqu'à ce qu'on l'ouvre.
	if not deblaiement_vu and jeu.theme != "trafic" and jeu.interface.deblaiement_propose():
		return "trafic"
	if not ouvert:
		return ""
	match etape:
		"trafic":
			return "trafic" if jeu.theme != "trafic" else ""
		"prochaine":
			return "dangers" if jeu.theme != "dangers" else ""
	return ""


## 🎓 La tuile de l'université n'apparaît qu'une fois trouvée sur la carte (auteur, 2026-10-05).
func rail_visible(id: String) -> bool:
	if id == "sols":
		return concept_ouvert("eponge")
	return id != "universite" or rail_ouvert(id)


func examiner(couche: String, fid: int, reglage := "", valeur: Variant = true) -> void:
	jeu.examiner(couche, fid, reglage, valeur)


## 🎓 TROUVER L'UNIVERSITÉ (auteur, 2026-10-05) : toute la ville à l'écran,
## l'université entourée par le trait de sélection, et c'est le clic sur elle
## qui ouvre l'étude — le joueur apprend où elle est.
func chercher_universite() -> void:
	jeu.interface._fermer_fiche()
	jeu.selection.sel_couche = "i"
	jeu.selection.sel_fid = _universite()
	var ville: Dictionary = jeu.donnees["reperes"]["ville"]
	jeu.pivot.viser(Vector2(float(ville["cible"][0]), float(ville["cible"][1])), CADRAGE_UNIVERSITE)
	jeu._dernier_peint = -1.0
	jeu._rafraichir(true)


## 🎚️ La ville bâtie sans ses champs (auteur, 2026-10-05 : « pas besoin de dézoomer autant ») ;
## le repère « ville » vaut 1 200 m.
const CADRAGE_UNIVERSITE := 600.0


func _universite() -> int:
	return int(jeu.interface.LIEUX["universite"]["fid"])


## Le clic sur la ville pendant la recherche : l'université ouvre l'étude.
func trouve(couche: String, fid: int) -> void:
	if etape == "etude" and couche == "i" and fid == _universite():
		jeu.interface.ouvrir_lieu("universite")


## Le premier pont est derrière nous : l'étude paraît, la suite commence.
func publier_etude() -> void:
	pont_termine = true
	pont_termine_mois = jeu.mois
	jeu.interface.retours.consigner("Université : une étude annonce une crue plus forte d'ici 6 à 8 ans.", jeu.mois)
	jeu._sur_theme("")
	jeu.interface._detail_ouvert = false
	jeu.interface._placer_detail()
	actualiser(true)


## L'université ouverte après la parution, ou l'onglet de la prochaine crue.
func etude_ouverte() -> void:
	if pont_termine and not etude_lue:
		etude_lue = true
		actualiser(true)


func prochaine_ouverte() -> void:
	if pont_termine and not prochaine_vue:
		etude_lue = true
		prochaine_vue = true
		actualiser(true)


# ==========================================================================
# 📖 LE LIVRE DES CONCEPTS (101) — une page ouvre ses leviers
# ==========================================================================
# 🎚️ LEVEL DESIGN : quand chaque page s'ouvre. La ville-éponge à l'étude ; « ne
# pas aggraver » quand la ville est réparée (A, auteur, 2026-10-06 ; n°23) ;
# l'îlot de chaleur avec la canicule, plus tard (102). Sans guide, tout est ouvert.

func concept_ouvert(id: String) -> bool:
	match id:
		"eponge":
			return pont_termine
		"attenuer":
			return ville_reparee()
	return false


## « La ville réparée », vue sur la carte et non sur un mois (n°23 : les
## fonctions vitales). [texte, tenu]. Un pont rouvert suffit à ne couper aucun
## quartier : les trois réunissent les deux mêmes morceaux.
func conditions_reparee() -> Array:
	var v = jeu.ville
	# ⚠️ Demandé plusieurs fois par image (fiche, livre) : une fois par état.
	var cle := "%f/%d/%d" % [jeu.mois, v._repare.size(), v._camps.size()]
	if cle == _reparee_cle:
		return _reparee
	var coupe := false
	var acces: Dictionary = v.morceaux_accessibles(jeu.mois)
	for fid in v.ilots:
		if v.base("i", fid, "logements") > 0.0 and not acces.has(v.morceau("i", fid)):
			coupe = true
			break
	var releve := false
	for fid in v.ilots:
		if v.base("i", fid, "logements_sinistres") > 0.0 and v.reparation_finie("i", fid, jeu.mois):
			releve = true
			break
	_reparee_cle = cle
	_reparee = [
		["Tout le monde à l'abri", v.sans_toit(jeu.mois) < 0.5],
		["Aucun quartier habité coupé du reste", not coupe],
		["Un îlot sinistré relevé, quelle que soit la façon", releve],
	]
	return _reparee


var _reparee_cle := ""
var _reparee := []


func ville_reparee() -> bool:
	for c in conditions_reparee():
		if not c[1]:
			return false
	return true


## "" si le levier est ouvert ; sinon ce qui l'ouvrira, en clair.
func levier_ferme(levier: String) -> String:
	var id := Livre.concept_du_levier(levier)
	if id == "" or concept_ouvert(id):
		return ""
	match id:
		"eponge":
			return "S'ouvre avec la page « La ville-éponge », à la bibliothèque."
		"attenuer":
			return "S'ouvre quand la ville sera réparée : voir la page « Ne pas aggraver » à la bibliothèque."
	return "Plus tard."


## 📖 Une page qui s'ouvre se dit une fois, au bandeau et au journal.
var _pages_dites := {}


func _annoncer_pages() -> void:
	for id in Livre.ORDRE:
		if id == "eponge" or _pages_dites.has(id) or not concept_ouvert(id):
			continue
		_pages_dites[id] = true
		if pages_lues.has(id):
			continue
		jeu.interface.retours.annoncer("Bibliothèque de l'université : une nouvelle page, « %s »." % Livre.CONCEPTS[id]["titre"], jeu.mois)


func page_nouvelle(id: String) -> bool:
	return concept_ouvert(id) and not pages_lues.has(id)


func page_lue(id: String) -> void:
	if concept_ouvert(id) and not pages_lues.has(id):
		pages_lues[id] = jeu.mois
		actualiser(true)


func _reparation(couche: String, fid: int, titre: String) -> void:
	var v = jeu.ville
	var texte := titre
	# ⚖️ Un îlot sinistré s'ouvre sans façon posée : le joueur choisit (95).
	var reglage := "" if couche == "i" and v.base("i", fid, "logements_sinistres") > 0.0 else "reparer"
	if v.reparation_finie(couche, fid, jeu.mois):
		texte += "\nLivré · voir le lieu"
		reglage = ""
	elif v.est_repare(couche, fid):
		texte += "\nEn travaux · voir l'avancement"
		reglage = ""
	elif reglage != "":
		texte += "\n%.0f k€ · %s" % [v.cout_reparation_ke(couche, fid),
			jeu.interface._duree(v.duree_reparation_mois(couche, fid))]
	if couche == "i" and reglage == "" and not v.est_repare(couche, fid):
		_bouton(texte, func() -> void:
			examiner(couche, fid)
			jeu.interface.ouvrir_onglet("crue"))
		return
	_bouton(texte, examiner.bind(couche, fid, reglage))


## Un pont coupé, son nom seul : les prix se lisent et se comparent dans sa
## fiche, en l'ouvrant (auteur, 2026-09-26).
func _bouton_pont(fid: int) -> void:
	if jeu.ville.est_repare("r", fid):
		_reparation("r", fid, _nom("r", fid))
		return
	_bouton(_nom("r", fid), examiner.bind("r", fid))


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


## Les lieux ouverts pendant le relogement. L'indice « terrain nu » est retiré
## (auteur, 2026-10-07) : le guide dit déjà « un champ ».
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
		# 🧹 Une rue déblayée pour le pont n'est pas le premier lieu relevé : la suite
		# félicitait la rue à 2 k€ au lieu du pont.
		if couche == "r" and pont_termine and jeu.ville._repare[cle] < pont_termine_mois:
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
	if jeu.interface.deblaiement_propose():
		deblaiement_vu = true
	# Muet pendant le chantier du pont : le calque garde son propre panneau.
	if not _camp_pose() or pont_termine or suite or termine or etape == "pont_travaux":
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
	if not jeu.trafic.acces_pont(fid, jeu.mois)["possible"]:
		return "Aucun accès continu : une rue voisine est fermée."
	# 🔄 Ni les accès ni leur prix (auteur, 2026-09-26) : le joueur découvre à la
	# livraison que la boue barre le chemin, et cherche lui-même la route.
	return "Provisoire : une voie, en alternat." if jeu.ville.pont_provisoire(fid) else ""


## 🌉 La fiche s'ouvre SANS choix posé (auteur, 2026-09-24) : provisoire ou en
## dur, c'est le joueur qui tranche.
func _choisir_pont(fid: int) -> void:
	examiner("r", fid)


## Ouvert, sans panneau de détail ni carte au centre, et muet pendant le
## chantier du pont (auteur, 2026-10-05) comme pendant l'attente de sa carte.
func paraitre() -> bool:
	return ouvert and not jeu.interface._detail_ouvert and not annonce.visible \
		and etape not in ["pont_travaux", "pont_livre"]


func actualiser(force := false) -> void:
	visible = paraitre()
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
	elif premier.is_empty() and not etude_lue:
		etape = "etude"
	elif premier.is_empty() and not prochaine_vue:
		etape = "prochaine"
	elif premier.is_empty():
		etape = "choix"
	elif jeu.mois < float(premier["fin"]):
		etape = "travaux"
	else:
		etape = "livraison"
	var degage := etape == "pont_travaux" and acces_degage()
	if degage and _degage_annonce == 0:
		jeu.interface.retours.annoncer("Chemin du pont dégagé : on passera dès la fin du chantier.", jeu.mois)
	# Une reprise ne rejoue pas l'annonce : -1 attend le premier constat.
	_degage_annonce = 1 if degage else (0 if etape == "pont_travaux" else _degage_annonce)
	# Le guide remplaçait le panneau du calque Trafic : muet, il le rend.
	if etape == "pont_travaux" and ancienne != "pont_travaux" and jeu.theme == "trafic":
		jeu.interface._detail_ouvert = true
		jeu.interface._placer_detail()
	if etape == "pont_livre" and ancienne != "pont_livre":
		pont_livre_ms = Time.get_ticks_msec()
		# Sans échelle de temps : la pause ne doit pas geler l'attente.
		get_tree().create_timer(ATTENTE_ETUDE_MS / 1000.0, true, false, true) \
			.timeout.connect(actualiser.bind(true))
	var carte_pont := etape == "pont_livre" \
		and Time.get_ticks_msec() - pont_livre_ms >= ATTENTE_ETUDE_MS
	var rouvert := carte_pont and carte != "pont"
	if (etape == "livraison" and ancienne == "travaux" or rouvert or
			etape == "pont_acces" and ancienne == "pont_travaux") and (ouvert or rouvert):
		jeu._sur_vitesse(0.0)
		jeu.interface._detail_ouvert = false
		jeu.interface._placer_detail()
		visible = true
	# 🚿 Le pont passe d'abord : la plainte attend qu'il soit quitté.
	if plainte == 0 and etape != "pont_livre" \
			and jeu.ville.usure_camp_mois(jeu.mois) > 0.0:
		plainte = 1
		jeu._sur_vitesse(0.0)
		jeu.interface._detail_ouvert = false
		jeu.interface._placer_detail()
	carte = "pont" if carte_pont else ("camp" if plainte == 1 else "")
	annonce.visible = carte != ""
	_remplir_carte()
	# Recalculé : la carte a pu se fermer pendant cet appel.
	visible = paraitre()
	_legende.visible = jeu.theme == "trafic" and etape.begins_with("pont")
	_caisse.text = "Caisse : " + jeu.interface._millions(jeu.ville.caisse_ke(jeu.mois))
	_progression.visible = etape == "travaux"
	_detail.visible = _progression.visible or etape == "suite"
	if _progression.visible:
		var duree: float = jeu.ville.duree_reparation_mois(premier["couche"], premier["fid"])
		var reste: float = float(premier["fin"]) - jeu.mois
		_progression.value = (1.0 - reste / duree) * 100.0
		_detail.text = "Encore %s · ×12 ≈ %d s" % [jeu.interface._duree(reste), int(ceil(reste * 5.0))]
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
	signature += "/%d/%s/%s/%d/%d/%s" % [_regards.size(), _champ_vu, jeu.trafic._indisponibles_connues,
		jeu.ville._camps.size(), jeu.ville._repare.size(), acces_degage()]
	_annoncer_pages()
	signature += "/%s" % concept_ouvert("attenuer")
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
			_titre.text = "Les deux rives sont coupées"
			# 🧭 Sans bouton (auteur, 2026-10-02) : la tuile entourée de la colonne y mène.
			_texte.text = "Tout le monde est à l'abri. Ouvrez le trafic, dans la colonne de gauche, pour choisir un pont."
		"pont_choix":
			_titre.text = "Rebâtir un pont"
			_texte.text = "Trois ponts emportés. Ouvrez-en un pour comparer ses deux chantiers."
			# 🌉 Un bouton par pont (auteur, 2026-09-22) : on les trouvait mal sur
			# la carte. Les repères restent dans l'interface (85), la carte reste nue.
			for fid in jeu.ville.ponts_coupes():
				_bouton_pont(fid)
		"pont_acces":
			# 🔄 Aucun nom de rue ni bouton (auteur, 2026-09-26) : la boue se voit
			# sur la carte, et seule la fiche d'une route qui barre le pont répond.
			_titre.text = "Le pont est prêt, personne ne passe"
			_texte.text = description_pont(int(premier["fid"]))
			if jeu.trafic.acces_pont(int(premier["fid"]), jeu.mois)["possible"]:
				_texte.text = "La boue bloque encore le chemin jusqu'au pont."
		"pont_travaux":
			# 🔇 Le guide se tait (auteur, 2026-10-05) : le bandeau dit la boue puis
			# le chemin dégagé, les chantiers en cours portent l'avancement.
			_poser_reperes([])
		"pont_livre":
			_poser_reperes([])
		"etude":
			# 🎓 La menace après la première victoire, jamais pendant l'urgence.
			_poser_reperes([])
			_titre.text = "Une nouvelle étude"
			_texte.text = "L'université vient de publier une étude sur l'Ilse. Trouvez-la dans la ville et cliquez dessus."
			_bouton("Montrer l'université", chercher_universite)
		"prochaine":
			# 🔴 Aucun bouton (auteur, 2026-09-30) : le joueur apprend où vit la prévision.
			_poser_reperes([])
			_titre.text = "Où irait l'eau ?"
			_texte.text = "La carte de l'étude est dans Dangers, dans la colonne de gauche."
		"reloger":
			# 🧭 ON NE MONTRE PAS LES TROIS CHAMPS (auteur, 2026-09-17) :
			# ni chiffre sur la carte, ni bouton qui y mène. Le joueur cherche
			# un endroit, et c'est la fiche qui répond — seul un champ ouvre le
			# bloc de relogement, et un champ de l'autre rive le prévient.
			var sans_toit: float = jeu.ville.sans_toit(jeu.mois)
			var coupes: int = int(jeu.ville.degats(jeu.mois)["franchissements_coupes"])
			var commandees: int = jeu.ville.places_commandees(jeu.mois)
			_titre.text = "%d personnes sont dehors" % int(sans_toit)
			_texte.text = "%d ponts coupés : elles restent sur leur rive. Cliquez sur un champ pour les abriter." % coupes
			if commandees > 0:
				_texte.text = "Abris commandés : %d places. Il manque encore %d places." % [
					commandees, int(jeu.ville.besoin_non_couvert(jeu.mois))]
			for fid in jeu.ville._camps:
				if not jeu.ville.camp_accessible(int(fid), jeu.mois):
					_texte.text += "\n%s est sur l'autre rive. Elle n'est pas accessible tant qu'un pont n'a pas été rebâti." % _nom_champ(int(fid))
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
			_texte.text = "Rue des Forgerons envasée, %.0f logements inhabitables à côté. La prochaine crue y mettrait %s m d'eau. Par où commencer ?" % [
				logements, jeu.interface._nb(jeu.ville.valeur("i", MAISONS, "hauteur_eau_annonce", jeu.mois), 1)]
			# 💶 Dit une fois, ici : la caisse ne relève pas tout (auteur, 2026-10-02).
			var autres := _sinistres_restants() - 1
			if autres > 0:
				_texte.text += "\n%d autres îlots attendent. La caisse ne les relèvera pas tous." % autres
			_reparation("r", RUE, "① Déblayer la rue")
			_reparation("i", MAISONS, "② Relever les logements" + (
				" · %d personnes peuvent rentrer" % abrites if abrites > 0 else ""))
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
				_texte.text = "%s est praticable. Réparer ne protège pas de la prochaine crue." % _nom("r", premier["fid"])
			else:
				_texte.text = _livraison_ilot(int(premier["fid"]))
			_bouton("Voir le résultat", examiner.bind(premier["couche"], premier["fid"]))
			_bouton("Et maintenant ?", func() -> void:
				suite = true
				actualiser(true))
		"suite":
			_titre.text = "Réparer, protéger ou investir ?"
			_texte.text = "Tout se paie sur la même caisse."
			_reparation("i", MAISONS, "Poursuivre les réparations")
			if not jeu.ville.est_repare("r", RUE):
				_reparation("r", RUE, "Rendre aussi la rue praticable")
			_proteger = _bouton("Protéger · renaturer la berge",
				examiner.bind("b", BERGE, "berge", Ville.BERGE_RENATUREE))
			# 📖 Investir est l'autre chapitre : il attend la ville réparée (101).
			var investir := _bouton("Investir · comparer les toits solaires",
				examiner.bind("i", SOLAIRE, "solaire", 0.3))
			if levier_ferme("solaire") != "":
				investir.text = "Investir · quand la ville sera réparée"
				investir.disabled = true
			_bouton("Continuer à mon rythme", func() -> void:
				termine = true
				ouvert = false
				actualiser(true))
			_maj_protection()
		"libre":
			_titre.text = "À vous de choisir la suite"
			_texte.text = "Votre premier lieu est relevé. La suite est à vous."
			_bouton("Revoir les pistes", func() -> void:
				termine = false
				suite = true
				actualiser(true))
	reset_size()


func _sinistres_restants() -> int:
	var n := 0
	for fid in jeu.ville.ilots:
		if jeu.ville.base("i", fid, "logements_sinistres") > 0.0 and not jeu.ville.est_repare("i", fid):
			n += 1
	return n


## 🏗️ Ce que la livraison dit, selon la façon de relever.
func _livraison_ilot(fid: int) -> String:
	var n: float = jeu.ville.base("i", fid, "logements_sinistres")
	match jeu.ville.facon_reparation(fid):
		"moderne":
			return "%s : rebâti en moderne, %.0f logements. La prochaine crue les atteindra aussi." % [
				_nom("i", fid), n * float(Ville.RECONSTRUCTIONS["moderne"]["logements"])]
		"pilotis":
			return "%s : %.0f logements sur pilotis. L'eau passera dessous, sauf la plus haute." % [_nom("i", fid), n]
		"parc":
			return "%s : rendu à l'eau. Ses habitants restent au camp tant qu'on ne les loge pas ailleurs." % _nom("i", fid)
	return "%s : %.0f logements remis en état. Réparer ne les protège pas de la prochaine crue." % [_nom("i", fid), n]


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
		_texte.text = "L'eau attendue aux Forgerons a baissé ; le secteur reste exposé."
	elif jeu.ville.berge_en_cours(BERGE, jeu.mois):
		prix = "En travaux"
	_proteger.text = "Protéger · renaturer la berge\n" + prix


func exporter() -> Dictionary:
	return {"suite": suite, "termine": termine, "ouvert": ouvert,
		"trafic_vu": trafic_vu, "pont_termine": pont_termine,
		"pont_termine_mois": pont_termine_mois,
		"etude_lue": etude_lue, "prochaine_vue": prochaine_vue, "plainte": plainte,
		"pages_lues": pages_lues.duplicate()}


func reprendre(etat: Dictionary) -> void:
	_regards.clear()
	_champ_vu = false
	suite = bool(etat.get("suite", false))
	termine = bool(etat.get("termine", false))
	ouvert = bool(etat.get("ouvert", true))
	trafic_vu = bool(etat.get("trafic_vu", false))
	pont_termine = bool(etat.get("pont_termine", suite or termine))
	pont_termine_mois = float(etat.get("pont_termine_mois", 0.0))
	# Une partie d'avant l'étude l'a déjà dépassée : on ne la rejoue pas.
	etude_lue = bool(etat.get("etude_lue", pont_termine))
	prochaine_vue = bool(etat.get("prochaine_vue", pont_termine))
	plainte = int(etat.get("plainte", 2 if pont_termine else 0))
	pages_lues = {}
	_pages_dites = {}
	var lues: Variant = etat.get("pages_lues", {})
	if lues is Dictionary:
		for id in lues:
			if Livre.CONCEPTS.has(id):
				pages_lues[id] = float(lues[id])
	_degage_annonce = -1
	etape = ""
	_signature = ""
	actualiser(true)
