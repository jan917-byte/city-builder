extends RefCounted
## Compteur permanent et constats de chantier, sans élément posé sur la carte.

var ui
## Colonne bas-droite : les chantiers au-dessus, le compteur des sans-logement en bas.
var pile: VBoxContainer
var compteur: PanelContainer
var besoin: Label
var preparation: Label
## 🚧 Les chantiers ont leur boîte, hors du compteur : deux thèmes (auteur, 2026-09-30).
var chantiers: PanelContainer
var chantiers_bloc: VBoxContainer
var chantiers_titre: Label
var chantiers_lignes := []   # {bloc, nom, quoi, reste, jauge}, bâties une fois
var chantiers_deborde: Label
const CHANTIERS_MAX := 5
var avis: PanelContainer
var texte: Label
var historique: RichTextLabel
var journal: Array[String] = []
var _en_cours := {}
var _nb_chantiers := 0
var _ponts := {}
var _sans_toit := -1
## 🗳️ Les mouvements de capital déjà dits, par identité et non par date : en mode
## auteur un gain tombe au mois même de la décision.
var _capital_dits := {}
var _recent: Array[String] = []
var _expiration := 0
var _historique_ouvert := false
## 🎚️ LEVEL DESIGN : dès quelle durée l'engagement rappelle ×12 — à ×1, un pont
## de 18 mois dure 18 minutes.
const ACCELERER_MOIS := 3.0


func batir(interface) -> void:
	ui = interface
	pile = VBoxContainer.new()
	pile.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	pile.offset_left = -352
	pile.offset_right = -16
	pile.offset_bottom = -16
	pile.grow_vertical = Control.GROW_DIRECTION_BEGIN
	pile.add_theme_constant_override("separation", 8)
	pile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(pile)
	chantiers = PanelContainer.new()
	chantiers.theme = ui._theme_ui
	ui._poser_boite(chantiers)
	chantiers.visible = false
	pile.add_child(chantiers)
	_batir_chantiers(chantiers)
	compteur = PanelContainer.new()
	compteur.theme = ui._theme_ui
	ui._poser_boite(compteur)
	pile.add_child(compteur)
	var lignes := VBoxContainer.new()
	compteur.add_child(lignes)
	# 🔄 Le journal est une icône sur la ligne du compteur (auteur, 2026-09-28) :
	# « Dernières décisions » prenait une ligne pleine largeur.
	var tete := HBoxContainer.new()
	lignes.add_child(tete)
	besoin = ui._label("", 16, ui.TEXTE)
	besoin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	besoin.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	tete.add_child(besoin)
	var bouton := Button.new()
	bouton.icon = ui._icone("journal", 18)
	bouton.tooltip_text = "Dernières décisions"
	bouton.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bouton.pressed.connect(func() -> void:
		_historique_ouvert = not _historique_ouvert
		actualiser_affichage())
	tete.add_child(bouton)
	preparation = ui._label("", 12, ui.GRIS)
	lignes.add_child(preparation)
	pile.minimum_size_changed.connect(ui._clamper_fiche)
	avis = PanelContainer.new()
	avis.theme = ui._theme_ui
	ui._poser_boite(avis)
	# Largeur nulle, croissance des deux côtés : le bandeau épouse son texte,
	# centré (`_ajuster_largeur`). À 410 px fixes, un message court laissait un vide.
	avis.anchor_left = 0.5
	avis.anchor_right = 0.5
	avis.grow_horizontal = Control.GROW_DIRECTION_BOTH
	avis.offset_top = 66   # sous la barre des compteurs (interface._barre_compteurs)
	ui.add_child(avis)
	var contenu := VBoxContainer.new()
	avis.add_child(contenu)
	texte = ui._label("", 14, ui.TEXTE)
	texte.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	contenu.add_child(texte)
	historique = RichTextLabel.new()
	historique.custom_minimum_size = Vector2(380, 250)
	historique.bbcode_enabled = false
	contenu.add_child(historique)
	avis.hide()


func notifier(message: String, mois: float) -> void:
	journal.append("Mois %s · %s" % [ui._nb(mois, 1), message])
	if journal.size() > 100:
		journal.pop_front()
	signaler(message)


## 💾 Même bandeau, hors du journal : sauvegarder n'est pas une décision. Un
## seul bandeau en haut — celui de la sauvegarde restait affiché des mois et
## s'écrivait par-dessus celui-ci.
func signaler(message: String) -> void:
	if Time.get_ticks_msec() > _expiration:
		_recent.clear()
	_recent.append(message)
	while _recent.size() > 2:
		_recent.pop_front()
	_expiration = Time.get_ticks_msec() + 8000
	actualiser_affichage()


func actualiser_affichage() -> void:
	if avis == null:
		return
	chantiers.visible = compteur.visible and _nb_chantiers > 0
	avis.visible = compteur.visible and (_historique_ouvert or Time.get_ticks_msec() < _expiration)
	historique.visible = _historique_ouvert
	# Une ligne par message : la ligne blanche entre deux creusait le bandeau.
	var nouveau := "Dernières décisions · cette partie" if _historique_ouvert else "\n".join(_recent)
	if nouveau != texte.text:
		texte.text = nouveau
		_ajuster_largeur()
	if _historique_ouvert:
		var inverse := journal.duplicate()
		inverse.reverse()
		historique.text = "\n\n".join(inverse) if not inverse.is_empty() else "Aucune décision engagée."
	avis.modulate.a = 1.0 if _historique_ouvert else clampf(float(_expiration - Time.get_ticks_msec()) / 700.0, 0.0, 1.0)


## ⚠️ Un Label qui passe à la ligne n'a pas de largeur propre : sans celle-ci,
## il tomberait à un caractère. On mesure la ligne la plus longue, plafonnée.
const LARGEUR_MAX := 380.0


func _ajuster_largeur() -> void:
	var police := texte.get_theme_font("font")
	var taille := texte.get_theme_font_size("font_size")
	var large := 0.0
	for ligne in texte.text.split("\n"):
		large = maxf(large, police.get_string_size(ligne, HORIZONTAL_ALIGNMENT_LEFT, -1, taille).x)
	texte.custom_minimum_size.x = minf(ceilf(large) + 2.0, LARGEUR_MAX)


func _batir_chantiers(boite: PanelContainer) -> void:
	chantiers_bloc = VBoxContainer.new()
	chantiers_bloc.add_theme_constant_override("separation", 4)
	boite.add_child(chantiers_bloc)
	chantiers_titre = ui._label("", 14, ui.TEXTE)
	chantiers_bloc.add_child(chantiers_titre)
	for i in CHANTIERS_MAX:
		var bloc := VBoxContainer.new()
		bloc.add_theme_constant_override("separation", 1)
		chantiers_bloc.add_child(bloc)
		var nom: Label = ui._label("", 12, ui.TEXTE)
		nom.clip_text = true
		nom.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		bloc.add_child(nom)
		var h := HBoxContainer.new()
		bloc.add_child(h)
		var quoi: Label = ui._label("", 11, ui.GRIS)
		quoi.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(quoi)
		var reste: Label = ui._label("", 11, ui.GRIS)
		h.add_child(reste)
		var jauge: Control = ui._jauge_chantier()
		bloc.add_child(jauge)
		chantiers_lignes.append({"bloc": bloc, "nom": nom, "quoi": quoi, "reste": reste, "jauge": jauge})
	chantiers_deborde = ui._label("", 12, ui.GRIS)
	chantiers_bloc.add_child(chantiers_deborde)


## Le plus proche de sa fin en tête, comme `ville.chantiers` les trie.
func _maj_chantiers(en_cours: Array) -> void:
	_nb_chantiers = en_cours.size()
	chantiers.visible = compteur.visible and _nb_chantiers > 0
	chantiers_titre.text = "Chantiers en cours · %d" % en_cours.size()
	for i in chantiers_lignes.size():
		var l: Dictionary = chantiers_lignes[i]
		(l["bloc"] as Control).visible = i < en_cours.size()
		if i >= en_cours.size():
			continue
		var c: Dictionary = en_cours[i]
		var couche := str(c["couche"])
		var fid := int(c["fid"])
		var genre := str(c["genre"])
		(l["quoi"] as Label).text = "Pont provisoire" if genre == "pont" and ui.ville.pont_provisoire(fid) else ui.CHANTIER_MOTS.get(genre, genre.capitalize())
		var lieu: String = ui.lieux.nom(couche, fid, "Champ" if couche == "i" and ui.ville.est_champ(fid) else "")
		(l["nom"] as Label).text = lieu
		(l["reste"] as Label).text = "encore %s" % ui._duree(float(c["reste_mois"]))
		l["jauge"].regler(float(c["part"]), float(c["part"]))
	var deborde := en_cours.size() - chantiers_lignes.size()
	chantiers_deborde.visible = deborde > 0
	chantiers_deborde.text = "… et %d de plus" % deborde


func _chantiers(mois: float, en_cours: Array = []) -> Dictionary:
	var resultat := {}
	if en_cours.is_empty():
		en_cours = ui.ville.chantiers(mois)["en_cours"]
	for c in en_cours:
		resultat["%s:%s:%s" % [c["couche"], c["fid"], c["genre"]]] = c
	for cle in ui.ville._recherche:
		if not ui.Recherche.acquis(ui.ville, cle, mois):
			resultat["recherche:" + cle] = {"genre": "recherche", "cle": cle}
	return resultat


func reprendre(mois: float, messages: Array = []) -> void:
	journal.clear()
	for message in messages:
		if message is String:
			journal.append(message)
	_recent.clear()
	_expiration = 0
	_historique_ouvert = false
	_en_cours = _chantiers(mois)
	_sans_toit = int(ui.ville.sans_toit(mois))
	_capital_dits.clear()
	for m in ui.ville.capital_mouvements():
		if float(m["mois"]) <= mois:
			_capital_dits[_cle_capital(m)] = true
	_ponts.clear()
	for pont in ui.ville.ponts_coupes():
		_ponts[pont] = ui.trafic.pont_fonctionnel(pont, mois)
	actualiser(mois)


func engagement(couche: String, fid: int, r: Dictionary, duree: float, mois: float) -> void:
	var lieu: String = ui.lieux.nom(couche, fid, "Champ" if couche == "i" and ui.ville.est_champ(fid) else "")
	var prix: String = "−%s k€" % ui._milliers(r["cout_ke"]) if r["cout_ke"] > 0.0 else "décision engagée"
	var message := "%s : %s · %s" % [lieu, prix, ui._duree(duree) if duree > 0.0 else "effet immédiat"]
	if float(r.get("capital", 0.0)) >= 0.5:
		message += " · −%s confiance" % ui._nb(r["capital"], 0)
	if "relogement" in r["faits"]:
		message += " · −%s nourris" % ui._nb(ui.ville.champ_nourriture(fid, mois), 0)
	elif duree >= ACCELERER_MOIS:
		message += " · ×12 ≈ %d s" % int(ceil(duree * 5.0))
	notifier(message, mois)
	if couche == "r" and fid in ui.ville.ponts_coupes() and not ui.trafic.acces_pont(fid, mois)["obstacles"].is_empty():
		notifier("La boue bloque le chemin jusqu'au pont : déblayez-le pendant le chantier.", mois)
	if duree <= 0.0:
		for genre in r["faits"]:
			livraison({"couche": couche, "fid": fid, "genre": genre}, mois)
	actualiser(mois)


func livraison(c: Dictionary, mois: float) -> void:
	if c["genre"] == "recherche":
		var sujet: Dictionary = ui.Recherche.SUJETS[c["cle"]]
		notifier("%s : recherche achevée · %s." % [sujet["nom"], sujet["quoi"]], mois)
		return
	var fid := int(c["fid"])
	var couche := str(c["couche"])
	var nom: String = ui.lieux.nom(couche, fid, "Champ" if couche == "i" and ui.ville.est_champ(fid) else "")
	var resultat := "Travaux terminés : %s." % str(c["genre"])
	if c["genre"] == "relogement":
		resultat = "%d containers livrés · %d personnes accueillies." % [
			ui.ville.camp_taille(fid, mois), int(ui.ville.camp_occupants(fid, mois))]
	elif couche == "r" and fid in ui.ville.ponts_coupes():
		resultat = "Pont provisoire posé." if ui.ville.pont_provisoire(fid) else "Pont rebâti."
		if not ui.trafic.pont_fonctionnel(fid, mois):
			resultat += " Ses accès restent coupés."
	elif c["genre"] in ["deblaiement", "reparation"] and couche == "r":
		resultat = "Rue déblayée."
	elif c["genre"] in ["reconstruction", "reparation"] and couche == "i":
		resultat = "%.0f logements réhabilités." % ui.ville.base("i", fid, "logements_sinistres")
	elif c["genre"] == "densification":
		resultat = "Surélévation livrée · %.0f logements ajoutés au total ici." % ui.ville.etat_dense(fid, mois)["logements"]
	elif c["genre"] == "solaire":
		resultat = "Panneaux en service · %.0f %% du toit équipé." % (100.0 * ui.ville.valeur("i", fid, "part_toit_equipe", mois))
	elif c["genre"] == "culture":
		var k: int = ui.ville.champ_culture(fid, mois)
		var attente: float = ui.ville.recolte_dans_mois(fid, mois)
		var culture: String = ui.Ville.CULTURES[k]["nom"]
		resultat = "%s en place · %s." % [culture.substr(0, 1).to_upper() + culture.substr(1),
			("première récolte dans %s" % ui._duree(attente)) if attente > 0.0
			else "%s nourris" % ui._nb(ui.ville.champ_rendement(fid, mois), 0)]
	elif c["genre"] == "toit vert":
		resultat = "Toiture végétalisée · %.0f %% du toit retient la pluie." % (100.0 * ui.ville.valeur("i", fid, "part_toit_vert", mois))
	notifier("%s : %s" % [nom, resultat], mois)


func actualiser(mois: float) -> void:
	var n := int(ui.ville.sans_toit(mois))
	besoin.text = "Personnes sans logement : %d" % n
	var aide: float = ui.ville.aide_mensuelle_ke(mois)
	var places := 0
	for fid in ui.ville._camps:
		if not ui.ville.camp_livre(fid, mois) and ui.ville.camp_accessible(fid, mois):
			places += ui.ville.camp_taille(fid, mois) * ui.ville.CAMP_PERSONNES_LOGEMENT
	var lignes := []
	if aide > 0.0:
		lignes.append("Aide d'urgence : −%s k€ par mois" % ui._milliers(aide))
	if places > 0:
		lignes.append("%d places en construction" % places)
	preparation.text = "\n".join(lignes)
	preparation.visible = not lignes.is_empty()
	var en_cours: Array = ui.ville.chantiers(mois)["en_cours"]
	_maj_chantiers(en_cours)
	var courants := _chantiers(mois, en_cours)
	for cle in _en_cours:
		if not courants.has(cle):
			livraison(_en_cours[cle], mois)
	_en_cours = courants
	if _sans_toit >= 0 and n < _sans_toit:
		notifier("%d personnes abritées · %d encore dehors." % [_sans_toit - n, n] if n > 0
			else "%d personnes abritées · plus personne dehors." % (_sans_toit - n), mois)
	_sans_toit = n
	_dire_capital(mois)
	for pont in ui.ville.ponts_coupes():
		var ouvert: bool = ui.trafic.pont_fonctionnel(pont, mois)
		if ouvert and _ponts.has(pont) and not _ponts[pont]:
			notifier("%s : les deux rives sont reliées." % ui.lieux.nom("r", pont), mois)
		_ponts[pont] = ouvert
	actualiser_affichage()


static func _cle_capital(m: Dictionary) -> String:
	return "%s:%s:%s" % [m["quoi"], m["couche"], m["fid"]]


## 🗳️ LE COMPTEUR NE BOUGE JAMAIS SANS PHRASE (Ressources, ☐ « comment il se
## regagne n'a aucune forme à l'écran »). La dépense est dite à l'engagement.
func _dire_capital(mois: float) -> void:
	for m in ui.ville.capital_mouvements():
		if float(m["mois"]) > mois:
			break
		var cle := _cle_capital(m)
		if _capital_dits.has(cle):
			continue
		_capital_dits[cle] = true
		var pourquoi := ""
		match str(m["quoi"]):
			"rentres":
				pourquoi = "%s : les habitants rentrent chez eux" % ui.lieux.nom("i", int(m["fid"]))
			"pont":
				pourquoi = "%s rouvert" % ui.lieux.nom("r", int(m["fid"]))
			"abrites":
				pourquoi = "plus personne ne dort dehors"
			"places_retour":
				var rue: String = ui.lieux.nom("r", int(m["fid"]))
				if float(m["report_part"]) >= 0.5:
					pourquoi = "%s : le trafic s'est reporté sur %s" % [rue, ui.lieux.nom("r", int(m["report_rue"]))]
				elif float(m["videe"]) >= 0.5:
					pourquoi = "%s : la rue s'est remplie de piétons" % rue
				else:
					pourquoi = "%s : la rue est restée aux voitures" % rue
		if pourquoi != "":
			notifier("%s · %+d confiance." % [pourquoi, int(roundf(float(m["montant"])))], mois)
