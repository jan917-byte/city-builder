extends PanelContainer
## Première boucle d'essai : les étapes se déduisent des chantiers réellement livrés.

const Ville := preload("res://scripts/ville.gd")
const Livre := preload("res://scripts/livre.gd")
const Objectifs := preload("res://scripts/objectifs.gd")
const Recherche := preload("res://scripts/recherche.gd")
const Politiques := preload("res://scripts/politiques.gd")
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
# 🌉 Le choix du pont, sans le donner (auteur, 2026-10-18). 🔴 Flaggable (90).
const PONTS_DIFFERENTS := "Les ponts ne coûtent pas tous le même prix, ni le même temps."
## 🧭 LE GUIDE DIT OÙ CLIQUER, IL NE CLIQUE PLUS (auteur, 2026-10-17) : aucun bouton
## d'action dans les premiers pas, seuls restent ceux qui font avancer le guide.
## Revient sur « plus de où cliquer » du 2026-10-08, pour ce panneau seul. 🔴 Flaggable (90).
## 🎯 Le but est passé aux objectifs, en bas à gauche (auteur, 2026-10-18) : plus de titre
## qui le répète, seulement où cliquer ; un guide qui n'a rien à dire se cache.
## 🌉 Dire tout de suite qu'il faudra cliquer un pont, et pourquoi (auteur, 2026-10-19). 🔴 Flaggable (90).
const DIRE_CHANTIERS := "%d ponts sont coupés : les deux rives ne se rejoignent plus. Cliquez sur Chantiers, dans la colonne de gauche, puis sur un pont coupé."
const DIRE_PONT := "Cliquez sur un pont coupé, dans Chantiers ou sur la carte, puis choisissez comment le rebâtir dans sa fiche."
const DIRE_ILOT := "Cliquez sur un îlot qui clignote pour le rebâtir."
## 🧹 Le Lavoir d'abord, conseillé sans être imposé (auteur, 2026-10-19) : maisons debout, chantier court. 🔴 Flaggable (90).
const LAVOIR := 62
const DIRE_LAVOIR := "Commencez par les Maisons du Lavoir, qui clignotent : leurs maisons tiennent debout, il suffit de les nettoyer. C'est le chantier le plus court."
## 🎓 Ce qu'est l'université, sans le chemin (auteur, 2026-10-19 : « pas besoin de mettre des trucs en jaune »). 🔴 Flaggable (90).
const DIRE_UNIVERSITE := "Elle a trois lieux. L'université publie ses études sur Wehrau, la bibliothèque raconte comment d'autres villes s'y sont prises, l'institut met au point de nouvelles façons de bâtir. Chaque objectif atteint, en bas à gauche, rapporte un point à dépenser à la mairie ou à l'institut."
## 🏛️ LA MAIRIE D'ABORD (117, auteur 2026-10-19) : au pont rouvert, elle seule s'ouvre ; le concours
## s'y adopte en points, puis l'étude s'y commande en euros, et l'étude rendue ouvre l'université. 🔴 Flaggable (90).
const DIRE_MAIRIE := "La mairie a rouvert. Cliquez sur la mairie, dans la colonne de gauche : chaque objectif atteint, en bas à gauche, y rapporte un point."

var jeu
var suite := false
var termine := false
var ouvert := true
## 🚧 La phase du pont passe par Chantiers, plus par Trafic (auteur, 2026-10-17).
var chantiers_vu := false
var pont_termine := false
## Le mois où l'on quitte la carte du pont rouvert : une rue engagée avant appartient au pont.
var pont_termine_mois := 0.0
## 🎓 Le pont livré, l'étude est la seule carte (auteur, 2026-10-08, revient sur la carte
## du pont) ; `etude_lue` : le campus trouvé. `carte_etude` : 0 à venir, 1 affichée, 2 passée.
var etude_parue := false
var etude_mois := 0.0
var carte_etude := 0
var etude_lue := false
var prochaine_vue := false
## 🔄 Plus de visite imposée du campus (auteur, 2026-10-08) : gardés pour les sauvegardes.
var institut_vu := false
var biblio_vue := false
## ⏳ La carte du pont attend 5 s réelles, le temps qui court (auteur, 2026-10-06) :
## on voit le pont s'ouvrir et les voitures passer.
const ATTENTE_PONT_MS := 5000
var pont_livre_ms := 0
var etape := ""
var premier := {}
var _signature := ""
var _titre: Label
var _texte: Label
var _actions: VBoxContainer
var _progression: ProgressBar
var _detail: Label
var _corps: VBoxContainer
var _entete: HBoxContainer
var objectifs: Objectifs
## Rien à dire ni à cliquer : le guide se cache, les objectifs suffisent.
var _muet := false
var _dernier_mois := -1.0
var _reperes: Node3D
var _reperes_poses := ""
var _champs := []
## 🧹 L'annonce du chemin dégagé : -1 après une reprise, 0 à dire, 1 dite.
var _degage_annonce := 0
## 🎓 Les cartes au centre (auteur, 2026-10-02) : « etude » mène au campus,
## « camp » dit que le camp use la confiance.
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
var boue_vue := false
## 📖 Les pages du livre déjà ouvertes : « nouveau » sur les autres (101).
var pages_lues := {}
## 🔒 LA PREMIÈRE ANNÉE (auteur, 2026-10-18) : après les camps, seuls se rebâtissent les
## ponts, les rues et les îlots sinistrés, comme avant ; ni étude, ni université, ni levier.
## Les essais du chapitre suivant l'éteignent ; elle finit quand l'étude paraît, au pont rouvert.
var premiere_annee := true
## L'étude parue, la première année est finie : une partie d'avant le 2026-10-18 garde sa suite.
func annee_un() -> bool:
	return premiere_annee and not etude_parue


## 🔄 Dangers n'est plus demandé la première année (auteur, 2026-10-19) : gardé pour les sauvegardes.
var degats_vus := false
## 🏛️ La carte du concours : 0 à venir, 1 affichée, 2 passée. Elle paraît à la première fiche
## d'un îlot aux maisons tombées, l'étude parue (auteur, 2026-10-19 : « introduire les concours »).
var carte_concours := 0
## 🏛️ La mairie ouverte une fois après le pont ; l'étude proposée vue à la mairie (117).
var mairie_vue := false
var etude_proposee_vue := false


func batir(maquette) -> void:
	jeu = maquette
	var ui = jeu.interface
	ui._poser_histoire(self)
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
	_entete = entete
	_corps.add_child(entete)
	_titre = ui._label("", 22, ui.ENCRE_HISTOIRE)
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
	objectifs = Objectifs.new()
	objectifs.batir(jeu)
	actualiser(true)


## Modale : le temps est en pause et rien d'autre ne se clique tant qu'on n'a pas choisi.
func _batir_annonce(ui) -> void:
	annonce = Control.new()
	annonce.name = "AnnonceEtude"
	annonce.theme = ui._theme_histoire
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
	ui._poser_histoire(boite)
	boite.custom_minimum_size.x = 440
	centre.add_child(boite)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	boite.add_child(v)
	_annonce_titre = ui._label("", 22, ui.ENCRE_HISTOIRE)
	_annonce_titre.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_annonce_titre)
	_annonce_texte = ui._label("", 14, ui.ENCRE_HISTOIRE)
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
		"etude":
			# Les mots de l'auteur (2026-10-09).
			_annonce_titre.text = "Une nouvelle étude a été publiée"
			_annonce_texte.text = "Sur la prochaine crue de l'Ilse."
			annonce_principal.text = "Trouver l'université"
			annonce_second.text = ""
		"camp":
			_annonce_titre.text = "Les habitants du camp sont mécontents"
			_annonce_texte.text = "Ils ont un toit, pas de quoi vivre."
			annonce_principal.text = "Voir le campement"
			annonce_second.text = "Plus tard"
		"concours":
			# 🔴 Mes mots, flaggables (90).
			_annonce_titre.text = "Un concours d'architectes"
			_annonce_texte.text = ("Des maisons sont tombées. "
				+ "Les reconstruire comme avant, c'est les exposer de nouveau à la crue.\n\n"
				+ "Un concours demande à des architectes d'autres projets pour toute la zone sinistrée. "
				+ "Il dure %s et coûte %d k€. En attendant, on peut toujours reconstruire comme avant.") % [
				jeu.interface._duree(Ville.CONCOURS_MOIS), int(Ville.CONCOURS_KE)]
			annonce_principal.text = "Revenir à l'îlot"
			annonce_second.text = ""
	annonce_second.visible = annonce_second.text != ""


func _sur_carte(principal: bool) -> void:
	if carte == "concours":
		carte_concours = 2
		actualiser(true)
		return
	if carte == "etude":
		carte_etude = 2
		actualiser(true)
		if principal:
			chercher_campus()
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


# Les repères du guide restent dans l'interface (décision 85).
func _poser_reperes(_lieux: Array) -> void:
	pass


func _paragraphe(texte: String, taille: int) -> Label:
	var l: Label = jeu.interface._label(texte, taille, jeu.interface.ENCRE_HISTOIRE)
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
	var v := _verrou_urgence()
	return "rebatir" if v == "" and annee_un() else v


func _verrou_urgence() -> String:
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
## sinistrés attendent un pont engagé, et leur fiche fait paraître l'étude (`trouve`) :
## on rebâtit en sachant la prochaine crue (auteur, 2026-10-02 et 2026-10-06).
func autorise(couche: String, fid: int) -> bool:
	match verrou():
		"":
			return true
		"reloger":
			return couche == "i" and jeu.ville.camp_possible(fid)
	if couche == "i":
		# 🌉 Rebâtir s'engage dès qu'un pont est lancé, et commence aussitôt (auteur, 2026-10-18).
		return jeu.ville.camp_pose(fid) or annee_un() and _pont_engage() \
			and jeu.ville.base("i", fid, "cout_reparation_ke") > 0.0
	if couche != "r":
		return false
	if verrou() == "rebatir":
		return jeu.ville.base("r", fid, "cout_reparation_ke") > 0.0
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


## 🧹 Une rue boueuse barre le chemin d'un pont engagé, et personne ne la déblaie encore.
func boue_a_engager() -> bool:
	for p in jeu.ville.ponts_coupes():
		if not jeu.ville.est_repare("r", p):
			continue
		for rue in jeu.trafic.acces_pont(p, jeu.mois)["obstacles"]:
			if not jeu.ville.est_repare("r", rue):
				return true
	return false


## 🧭 La colonne de gauche s'ouvre au fil du guide (auteur, 2026-10-02) : une
## tuile reste grise tant que le guide ne l'a pas demandée, puis reste ouverte.
func rail_ouvert(id: String) -> bool:
	# 🎓 Le campus attend l'étude, même guide fermé : elle ne paraît plus d'elle-même (117).
	if id in ["universite", "dangers", "institut", "bibliotheque"] and not (etude_lue or tout_ouvert):
		return false
	if suite or termine or prochaine_vue or id == "":
		return true
	match id:
		"trafic", "chantiers":
			return not etape in ["", "reloger", "camp_attente"]
		"universite", "dangers", "institut", "bibliotheque":
			return etude_lue
		"mairie":
			return pont_termine
	return false


## 🎓 La prochaine crue vue, l'université rouvre sur la ville, sans plus clignoter (auteur, 2026-10-19).
func retour_universite() -> String:
	return "universite" if prochaine_vue and page_nouvelle("eponge") and jeu.theme == "dangers" \
		and not jeu.interface._campus_panneau.visible else ""


## La tuile que le guide demande, entourée jusqu'au clic.
func rail_appel() -> String:
	# 🧹 Chantiers s'entoure quand il propose de tout déblayer, jusqu'à ce qu'on l'ouvre.
	if not deblaiement_vu and jeu.theme != "chantiers" and jeu.interface.deblaiement_propose():
		return "chantiers"
	# 🟫 Le pont engagé, la Ville s'entoure : la boue se voit là, pas sur le calque
	# (auteur, 2026-10-06). Une fois revenu, plus d'appel.
	if etape == "pont_travaux" and not boue_vue and jeu.theme != "" and not acces_degage():
		return "ville"
	# 🏛️ La mairie s'entoure à son ouverture, puis quand elle propose l'étude (117).
	if etape == "mairie" or etude_proposee() and not etude_proposee_vue and not jeu.ville.etude_commandee():
		return "mairie" if jeu.interface._lieu_ouvert != "mairie" else ""
	# 🔄 Plus d'appel vers l'université ni vers Dangers (auteur, 2026-10-19) : le guide explique.
	if not ouvert:
		return ""
	if etape == "chantiers":
		return "chantiers" if jeu.theme != "chantiers" else ""
	return ""


## 🎓 La tuile de l'université n'apparaît qu'une fois trouvée sur la carte (auteur, 2026-10-05).
func rail_visible(id: String) -> bool:
	# 🧱 Les sols viennent avec leurs leviers, après la berge.
	if id == "sols":
		return concept_ouvert("eponge") and levier_ferme("permeable") == ""
	return not id in ["universite", "institut", "bibliotheque"] or rail_ouvert(id)


func examiner(couche: String, fid: int, reglage := "", valeur: Variant = true) -> void:
	jeu.examiner(couche, fid, reglage, valeur)


## 🎓 TROUVER LE CAMPUS (auteur, 2026-10-08) : la ville bâtie à l'écran, les trois
## îlots du campus sous un seul trait qui clignote ; le clic ouvre sa fiche.
func chercher_campus() -> void:
	jeu.interface._fermer_fiche()
	jeu.selection.sel_fid = -1
	var ville: Dictionary = jeu.donnees["reperes"]["ville"]
	jeu.pivot.viser(Vector2(float(ville["cible"][0]), float(ville["cible"][1])), CADRAGE_UNIVERSITE)
	jeu._dernier_peint = -1.0
	jeu._rafraichir(true)


## 🎚️ La ville bâtie sans ses champs (auteur, 2026-10-05 : « pas besoin de dézoomer autant ») ;
## le repère « ville » vaut 1 200 m.
const CADRAGE_UNIVERSITE := 600.0


func campus() -> Array:
	var out := []
	for cle in jeu.interface.CAMPUS:
		out.append(int(jeu.interface.LIEUX[cle]["fid"]))
	return out


## Le clic sur la ville : le campus que le guide entoure ouvre sa fiche.
func trouve(couche: String, fid: int) -> void:
	if couche != "i":
		return
	# Le guide ne désigne plus l'îlot (auteur, 2026-10-06) : celui qu'on ouvre montre sa reconstruction.
	if pont_termine and not (suite or termine) and jeu.ville.base("i", fid, "logements_sinistres") > 0.0 \
			and not jeu.ville.est_repare("i", fid):
		jeu.interface.ouvrir_onglet("crue")
	if etape == "etude" and carte_etude == 2 and fid in campus():
		jeu.interface.ouvrir_campus()


## 🌉 Le pont livré et vu cinq secondes : le bandeau le dit, la mairie s'ouvre (117).
## 🔄 Il ne publie plus l'étude (décidé le 2026-10-18) : elle se commande à la mairie.
func _pont_rouvert() -> void:
	jeu.interface.retours.annoncer("%s rouvert." % _nom("r", int(premier["fid"])), jeu.mois)
	terminer_pont()


## 🏛️ La mairie ouverte : son appel s'éteint.
func mairie_ouverte() -> void:
	if not pont_termine:
		return
	mairie_vue = true
	if etude_proposee():
		etude_proposee_vue = true
	actualiser(true)


## 🎓 L'étude se propose après le concours (117) : rendu, ou plus aucun îlot où le lancer.
func etude_proposee() -> bool:
	if not pont_termine or etude_parue:
		return false
	if jeu.ville.concours_rendu(jeu.mois):
		return true
	for fid in ilots_a_rebatir():
		if jeu.ville.concours_utile(fid):
			return false
	return true


func terminer_pont() -> void:
	pont_termine = true
	pont_termine_mois = jeu.mois
	jeu._sur_theme("")
	jeu.interface._detail_ouvert = false
	jeu.interface._placer_detail()
	actualiser(true)


## 🎓 Les îlots que le guide entoure d'un trait qui clignote, la ville nue à l'écran :
## le campus à trouver, puis les îlots sinistrés à rebâtir (auteur, 2026-10-08).
func groupe_carte() -> Array:
	if termine or not ouvert or jeu.theme != "":
		return []
	match etape:
		"etude":
			return campus() if carte_etude == 2 else []
		# 🧭 Le guide dit « l'îlot qui clignote » à la place des boutons (auteur, 2026-10-17).
		"choix", "suite":
			return _a_faire_clignoter()
		"pont_travaux":
			return _a_faire_clignoter() if guide_rebatir() else []
		"livraison":
			return [int(premier["fid"])] if premier["couche"] == "i" else []
	return []


## Le Lavoir seul tant que le guide le conseille ; les autres restent cliquables.
func _a_faire_clignoter() -> Array:
	return [LAVOIR] if lavoir_conseille() else ilots_a_rebatir()


func lavoir_conseille() -> bool:
	return annee_un() and not _ilot_engage() and LAVOIR in ilots_a_rebatir()


func ilots_a_rebatir() -> Array:
	var out := []
	for fid in jeu.ville.ilots:
		if jeu.ville.base("i", fid, "logements_sinistres") > 0.0 and not jeu.ville.est_repare("i", fid):
			out.append(int(fid))
	return out


## Le campus trouvé, sa fiche ouverte : l'étude est lue.
func campus_ouvert() -> void:
	if etude_parue and not etude_lue:
		etude_lue = true
		actualiser(true)


func publier_etude() -> void:
	etude_parue = true
	etude_mois = jeu.mois
	carte_etude = 1
	jeu._sur_vitesse(0.0)
	jeu.interface.retours.consigner("Université : une étude annonce une crue plus forte d'ici 6 à 8 ans.", jeu.mois)
	actualiser(true)


## L'onglet de la prochaine crue ouvert : « nouveau » s'efface.
func prochaine_ouverte() -> void:
	if etude_parue and not prochaine_vue:
		prochaine_vue = true
		actualiser(true)


# ==========================================================================
# 📖 LE LIVRE DES CONCEPTS (101) — une page ouvre ses leviers
# ==========================================================================
# 🎚️ LEVEL DESIGN : quand chaque page s'ouvre. La ville-éponge à l'étude ; « ne
# pas aggraver » quand la ville est réparée (A, auteur, 2026-10-06 ; n°23) ;
# l'îlot de chaleur avec la canicule, plus tard (102). Sans guide, tout est ouvert.
# 🌳 Les leviers s'achètent à l'institut (auteur, 2026-10-18), plus par les pages.
## 🔓 Pour les essais seuls : tout levier ouvert hors urgence, sans rien acheter.
var tout_ouvert := false

func concept_ouvert(id: String) -> bool:
	match id:
		"eponge":
			return etude_parue
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
	if annee_un():
		return "Plus tard."
	if tout_ouvert and verrou() == "":
		return ""
	if Recherche.SUJETS.has(levier) and not Recherche.ouvre(jeu.ville, levier, jeu.mois):
		return "S'achète à l'institut."
	return ""


## Une berge que le joueur a rendue à l'Ilse, chantier livré.
func berge_rendue() -> bool:
	var v = jeu.ville
	for b in v._berge:
		if v.berge_depart(b) != Ville.BERGE_RENATUREE \
				and v.berge_etat(b, jeu.mois) == Ville.BERGE_RENATUREE:
			return true
	return false


## 🏛️ Le concours s'adopte à la mairie, avant l'étude (117) ; les essais l'ouvrent hors première année.
func concours_offert() -> bool:
	return jeu.ville.concours_lance() or Politiques.adopte(jeu.ville, "concours", jeu.mois) \
		or tout_ouvert and not annee_un()


## 🏛️ La fiche d'un îlot aux maisons tombées, le campus trouvé, annonce le concours une fois.
func annoncer_concours() -> void:
	if carte_concours != 0 or jeu.ville.concours_lance():
		return
	carte_concours = 1
	jeu._sur_vitesse(0.0)
	actualiser(true)


## 🚪 Ce qui s'ouvre se dit une fois, au bandeau et au journal.
var _portes_dites := {}


func _annoncer_portes() -> void:
	if not "leviers" in _portes_dites and etude_parue and berge_rendue():
		_portes_dites["leviers"] = true
		jeu.interface.retours.annoncer("Berge rendue.", jeu.mois)
	# 🔴 Flaggable (90).
	if not "etude" in _portes_dites and etude_proposee() and not jeu.ville.etude_commandee():
		_portes_dites["etude"] = true
		jeu.interface.retours.annoncer("La mairie peut commander une étude à l'université.", jeu.mois)


## 📖 Une page qui s'ouvre se dit une fois, au bandeau et au journal.
var _pages_dites := {}


func _annoncer_pages() -> void:
	for id in Livre.ORDRE:
		if id == "eponge" or _pages_dites.has(id) or not concept_ouvert(id):
			continue
		_pages_dites[id] = true
		if pages_lues.has(id):
			continue
		jeu.interface.retours.annoncer("Nouvelle page : « %s »." % Livre.CONCEPTS[id]["titre"], jeu.mois)


func page_nouvelle(id: String) -> bool:
	return concept_ouvert(id) and not pages_lues.has(id)


func page_lue(id: String) -> void:
	if concept_ouvert(id) and not pages_lues.has(id):
		pages_lues[id] = jeu.mois
		actualiser(true)


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


func voir_ville() -> void:
	if etape == "pont_travaux":
		boue_vue = true


## 🚧 Le panneau Chantiers reste ouvert : il porte la liste des ponts coupés (auteur, 2026-10-17).
func voir_chantiers() -> void:
	if jeu.interface.deblaiement_propose():
		deblaiement_vu = true
	if not _camp_pose() or pont_termine or suite or termine or etape == "pont_travaux":
		return
	if not chantiers_vu and ouvert:
		# La fiche du dernier camp restait à côté de la liste des ponts (partie jouée, 2026-10-10).
		jeu.interface._fermer_fiche()
		jeu.selection.sel_fid = -1
		jeu._repere("ville")
	chantiers_vu = true
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


## Ouvert, sans panneau de détail, carte au centre ni fenêtre du campus, et muet pendant
## le chantier du pont (auteur, 2026-10-05) comme pendant l'attente de sa carte.
func paraitre() -> bool:
	return ouvert and not _muet and not jeu.interface._detail_ouvert and not annonce.visible \
		and not jeu.interface._campus_panneau.visible \
		and (etape not in ["pont_travaux", "pont_livre"] or guide_rebatir())


## 🌉 La première année, le guide propose de rebâtir dès le chemin du pont dégagé.
func guide_rebatir() -> bool:
	return annee_un() and (etape == "choix" or etape == "pont_travaux" and acces_degage())


## Un îlot sinistré déjà engagé.
func _ilot_engage() -> bool:
	for fid in jeu.ville.ilots:
		if jeu.ville.base("i", fid, "cout_reparation_ke") > 0.0 and jeu.ville.est_repare("i", fid):
			return true
	return false


func actualiser(force := false) -> void:
	if objectifs != null:
		objectifs.actualiser(force)
	visible = paraitre()
	if _reperes != null:
		_reperes.visible = visible and jeu.theme in ["", "chantiers"] and not suite and not termine
		# Même règle que les pastilles : taille constante à l'écran.
		for r in _reperes.get_children():
			(r as Label3D).pixel_size = jeu.pivot.taille * 0.0012
	if not force and absf(jeu.mois - _dernier_mois) < 0.02:
		return
	_dernier_mois = jeu.mois
	# 🎓 Commandée à la mairie, rendue : elle paraît, sa carte au centre (117).
	if not etude_parue and jeu.ville.etude_rendue(jeu.mois):
		publier_etude()
		return
	if _camp_pose() and jeu.theme == "chantiers":
		chantiers_vu = true
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
			etape = "pont_choix" if chantiers_vu else "chantiers"
	elif etude_parue and not etude_lue:
		etape = "etude"
	elif not mairie_vue:
		etape = "mairie"
	elif premier.is_empty():
		etape = "choix"
	elif jeu.mois < float(premier["fin"]):
		etape = "travaux"
	else:
		etape = "livraison"
	var degage := etape == "pont_travaux" and acces_degage()
	if degage and _degage_annonce == 0:
		# 🔄 Plus d'invitation au ×4 (auteur, 2026-10-18). 🔴 Flaggable (90).
		jeu.interface.retours.annoncer("Chemin du pont dégagé.", jeu.mois)
	# Une reprise ne rejoue pas l'annonce : -1 attend le premier constat.
	_degage_annonce = 1 if degage else (0 if etape == "pont_travaux" else _degage_annonce)
	# La fiche du pont avait fermé le panneau Chantiers : le guide muet le rend.
	# Pont engagé depuis la ville : la boue est déjà sous les yeux.
	if etape == "pont_travaux" and jeu.theme == "":
		boue_vue = true
	if etape == "pont_travaux" and ancienne != "pont_travaux" and jeu.theme == "chantiers":
		jeu.interface._detail_ouvert = true
		jeu.interface._placer_detail()
	if etape == "pont_livre" and ancienne != "pont_livre":
		pont_livre_ms = Time.get_ticks_msec()
		# Sans échelle de temps : la pause ne doit pas geler l'attente.
		get_tree().create_timer(ATTENTE_PONT_MS / 1000.0, true, false, true) \
			.timeout.connect(actualiser.bind(true))
	if etape == "pont_livre" and Time.get_ticks_msec() - pont_livre_ms >= ATTENTE_PONT_MS:
		_pont_rouvert()
		return
	if (etape == "livraison" and ancienne == "travaux" or
			etape == "pont_acces" and ancienne == "pont_travaux") and ouvert:
		# 🔄 Le temps ne s'arrête plus seul ici (auteur, 2026-10-18) : seules les cartes au centre l'arrêtent.
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
	carte = "etude" if carte_etude == 1 else ("concours" if carte_concours == 1
		else ("camp" if plainte == 1 else ""))
	annonce.visible = carte != ""
	_remplir_carte()
	# Recalculé : la carte a pu se fermer pendant cet appel.
	visible = paraitre()
	_progression.visible = etape == "travaux"
	_detail.visible = _progression.visible
	if _progression.visible:
		var duree: float = jeu.ville.duree_reparation_mois(premier["couche"], premier["fid"])
		var reste: float = float(premier["fin"]) - jeu.mois
		_progression.value = (1.0 - reste / duree) * 100.0
		_detail.text = "Encore %s" % jeu.interface._duree(reste)
	# Les boutons restent en place sous le doigt ; seuls les changements de décision les refont.
	var signature := "%s/%s/%s/%s/%s/%s/%s/%s/%d" % [etape, premier,
		jeu.ville.est_repare("r", RUE), jeu.ville.est_repare("i", MAISONS),
		jeu.ville.reparation_finie("r", RUE, jeu.mois),
		jeu.ville.reparation_finie("i", MAISONS, jeu.mois),
		jeu.ville.berge_etat(BERGE, jeu.mois), jeu.ville._solaire.has(SOLAIRE),
		int(jeu.ville.sans_toit(jeu.mois) * 1000.0 + jeu.ville.besoin_non_couvert(jeu.mois))]
	signature += "/%s/%d/%d/%s" % [jeu.trafic._indisponibles_connues,
		jeu.ville._camps.size(), jeu.ville._repare.size(), acces_degage()]
	_annoncer_pages()
	_annoncer_portes()
	signature += "/%s/%s/%s/%s" % [concept_ouvert("attenuer"), etude_parue, degats_vus, mairie_vue]
	if signature == _signature:
		return
	_signature = signature
	for enfant in _actions.get_children():
		_actions.remove_child(enfant)
		enfant.queue_free()
	match etape:
		"camp_attente":
			_poser_reperes([])
			_titre.text = ""
			_texte.text = ""
		"chantiers":
			_poser_reperes([])
			_titre.text = ""
			# 🧭 La tuile Chantiers s'entoure, et le guide la nomme.
			_texte.text = DIRE_CHANTIERS % int(jeu.ville.degats(jeu.mois)["franchissements_coupes"])
		"pont_choix":
			_titre.text = ""
			# 🌉 Les ponts se trouvent mal sur la carte (auteur, 2026-09-22) : leur liste est dans
			# Chantiers, et leur pictogramme clignote.
			_texte.text = DIRE_PONT + "\n\n" + PONTS_DIFFERENTS
		"pont_acces":
			# 🔄 Aucun nom de rue ni bouton (auteur, 2026-09-26) : la boue se voit
			# sur la carte, et seule la fiche d'une route qui barre le pont répond.
			_titre.text = ""
			_texte.text = description_pont(int(premier["fid"]))
			if jeu.trafic.acces_pont(int(premier["fid"]), jeu.mois)["possible"]:
				_texte.text = "La boue bloque encore le chemin jusqu'au pont : cliquez sur une rue boueuse pour la déblayer."
		"pont_travaux":
			# 🔇 Le guide se tait (auteur, 2026-10-05) : le bandeau dit la boue puis
			# le chemin dégagé, les chantiers en cours portent l'avancement.
			# 🌉 Sauf la première année, le chemin dégagé : on rebâtit pendant le pont.
			_poser_reperes([])
			if guide_rebatir():
				_texte.text = ""
				_texte_rebatir()
		"pont_livre":
			_poser_reperes([])
		"mairie":
			_poser_reperes([])
			_titre.text = ""
			_texte.text = DIRE_MAIRIE
		"etude":
			# 🎓 Le nom seul : le contour qui clignote y mène (auteur, 2026-10-08).
			_poser_reperes([])
			_titre.text = "L'université"
			_texte.text = DIRE_UNIVERSITE
		"reloger":
			# 🧭 Ni chiffre sur la carte ni bouton qui mène aux champs (auteur, 2026-09-17) ;
			# le guide dit « un champ » et les ponts coupés (tableau de l'auteur, 2026-10-07).
			_titre.text = ""
			var coupes: int = int(jeu.ville.degats(jeu.mois)["franchissements_coupes"])
			# 🔴 Texte du tableau de l'auteur (2026-10-07), flaggable (90).
			_texte.text = "%d ponts coupés : les sinistrés restent sur leur rive. Cliquez sur un champ de cette rive pour y poser un camp." % coupes
			if jeu.ville.places_commandees(jeu.mois) > 0:
				_texte.text = "Il manque encore %d places : cliquez sur un autre champ." % \
					int(jeu.ville.besoin_non_couvert(jeu.mois))
			for fid in jeu.ville._camps:
				if not jeu.ville.camp_accessible(int(fid), jeu.mois):
					_texte.text += "\n%s est sur l'autre rive." % _nom_champ(int(fid))
			_poser_reperes([])
		"choix":
			# 🔄 LE JOUEUR CHOISIT SON ÎLOT (auteur, 2026-10-06) : ni bouton ni lieu
			# désigné ; la fiche d'îlot sinistré le compare par ses tuiles.
			# 🏠 Rebâtir d'abord (auteur, 2026-10-08) : les îlots sinistrés clignotent. 🔴 Flaggable (90).
			_texte.text = ""
			_texte_rebatir()
		"travaux":
			_titre.text = "Le premier chantier avance"
			_texte.text = "%s : chantier en cours." % _nom(premier["couche"], premier["fid"])
		"livraison":
			_titre.text = "Un lieu reprend vie"
			if premier["couche"] == "r":
				_texte.text = "%s est praticable." % _nom("r", premier["fid"])
			else:
				# 🔴 Flaggable (90).
				_texte.text = _livraison_ilot(int(premier["fid"])) \
					+ "\n\nCliquez sur l'îlot qui clignote pour voir le résultat."
			_bouton("Et maintenant ?", func() -> void:
				suite = true
				actualiser(true))
		"suite":
			# 🏠 Plus de « renaturer la berge » ici (auteur, 2026-10-08) : rebâtir d'abord,
			# la berge reste dans sa fiche.
			_titre.text = "Réparer ou investir ?"
			# 🔴 Flaggable (90).
			var lignes := []
			if not ilots_a_rebatir().is_empty():
				lignes.append("Pour réparer, cliquez sur un îlot qui clignote.")
			# 📖 Investir est l'autre chapitre : il attend la ville réparée (101).
			if annee_un():
				lignes.append("Le prochain budget arrivera en janvier.")
			else:
				lignes.append("Pour agir autrement, cliquez sur l'institut, dans la colonne de gauche." if levier_ferme("solaire") != ""
				else "Pour investir, cliquez sur Énergie, dans la colonne de gauche : elle montre où le solaire s'amortit.")
			_texte.text = "\n\n".join(lignes)
			_bouton("Continuer à mon rythme", func() -> void:
				termine = true
				ouvert = false
				actualiser(true))
		"libre":
			_titre.text = "À vous de choisir la suite"
			_texte.text = ""
			_bouton("Revoir les pistes", func() -> void:
				termine = false
				suite = true
				actualiser(true))
	_texte.visible = _texte.text != ""
	_titre.visible = _titre.text != ""
	_texte_en_tete(not _titre.visible)
	_muet = _titre.text == "" and _texte.text == "" and _actions.get_child_count() == 0
	visible = paraitre()
	reset_size()


## Sans titre, le texte prend sa place, à côté du « − » : sinon une ligne vide au-dessus.
func _texte_en_tete(oui: bool) -> void:
	var parent: Container = _entete if oui else _corps
	if _texte.get_parent() == parent:
		return
	_texte.get_parent().remove_child(_texte)
	parent.add_child(_texte)
	parent.move_child(_texte, 0 if oui else 1)
	_texte.size_flags_horizontal = Control.SIZE_EXPAND_FILL if oui else Control.SIZE_FILL


## 🌉 Le guide de la reconstruction, la première année. 🔴 Flaggable (90).
func _texte_rebatir() -> void:
	_titre.text = ""
	var lignes := [] if _texte.text == "" else [_texte.text]
	if not (_ilot_engage() and etape == "pont_travaux"):
		lignes.append(DIRE_LAVOIR if lavoir_conseille() else DIRE_ILOT)
	_texte.text = "\n\n".join(lignes)


## 🏗️ Ce que la livraison dit, selon la façon de relever.
func _livraison_ilot(fid: int) -> String:
	var n: float = jeu.ville.base("i", fid, "logements_sinistres")
	match jeu.ville.facon_reparation(fid):
		"moderne":
			return "%s : rebâti en moderne, %.0f logements." % [
				_nom("i", fid), n * float(Ville.RECONSTRUCTIONS["moderne"]["logements"])]
		"pilotis":
			return "%s : %.0f logements sur pilotis." % [_nom("i", fid), n]
		"parc":
			return "%s : rendu à l'eau." % _nom("i", fid)
	return "%s : %.0f logements remis en état." % [_nom("i", fid), n]


func exporter() -> Dictionary:
	return {"suite": suite, "termine": termine, "ouvert": ouvert,
		"chantiers_vu": chantiers_vu, "pont_termine": pont_termine,
		"pont_termine_mois": pont_termine_mois,
		"etude_parue": etude_parue, "etude_mois": etude_mois, "carte_etude": carte_etude,
		"etude_lue": etude_lue, "prochaine_vue": prochaine_vue, "plainte": plainte,
		"institut_vu": institut_vu, "biblio_vue": biblio_vue,
		"pages_lues": pages_lues.duplicate(), "degats_vus": degats_vus,
		"carte_concours": carte_concours, "mairie_vue": mairie_vue,
		"etude_proposee_vue": etude_proposee_vue}


func reprendre(etat: Dictionary) -> void:
	# Deux appels du rail, rejoués à la reprise : ils ne coûtent qu'un clic.
	boue_vue = false
	deblaiement_vu = false
	suite = bool(etat.get("suite", false))
	termine = bool(etat.get("termine", false))
	ouvert = bool(etat.get("ouvert", true))
	# Avant le 2026-10-17, la phase du pont passait par Trafic.
	chantiers_vu = bool(etat.get("chantiers_vu", etat.get("trafic_vu", false)))
	pont_termine = bool(etat.get("pont_termine", suite or termine))
	pont_termine_mois = float(etat.get("pont_termine_mois", 0.0))
	# Avant le 2026-10-06, l'étude paraissait avec le pont : on ne la rejoue pas.
	etude_parue = bool(etat.get("etude_parue", pont_termine))
	etude_mois = float(etat.get("etude_mois", pont_termine_mois))
	carte_etude = int(etat.get("carte_etude", 2 if etude_parue else 0))
	etude_lue = bool(etat.get("etude_lue", etude_parue))
	prochaine_vue = bool(etat.get("prochaine_vue", etude_parue))
	institut_vu = bool(etat.get("institut_vu", prochaine_vue))
	biblio_vue = bool(etat.get("biblio_vue", prochaine_vue))
	plainte = int(etat.get("plainte", 2 if pont_termine else 0))
	degats_vus = bool(etat.get("degats_vus", false))
	carte_concours = int(etat.get("carte_concours", 0))
	# Avant 117, l'étude paraissait au pont : une partie d'avant n'a rien à voir à la mairie.
	mairie_vue = bool(etat.get("mairie_vue", etude_parue))
	etude_proposee_vue = bool(etat.get("etude_proposee_vue", etude_parue))
	pages_lues = {}
	_pages_dites = {}
	_portes_dites = {}
	var lues: Variant = etat.get("pages_lues", {})
	if lues is Dictionary:
		for id in lues:
			if Livre.CONCEPTS.has(id):
				pages_lues[id] = float(lues[id])
	_degage_annonce = -1
	# Une reprise ne rejoue pas ce qui était déjà ouvert.
	if etude_parue and berge_rendue():
		_portes_dites["leviers"] = true
	if etude_proposee_vue or jeu.ville.etude_commandee():
		_portes_dites["etude"] = true
	etape = ""
	_signature = ""
	actualiser(true)
