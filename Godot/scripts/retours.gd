extends RefCounted
## Compteur permanent et constats de chantier, sans élément posé sur la carte.

var ui
var compteur: PanelContainer
var besoin: Label
var preparation: Label
var avis: PanelContainer
var texte: Label
var historique: RichTextLabel
var journal: Array[String] = []
var _en_cours := {}
var _ponts := {}
var _sans_toit := -1
var _recent: Array[String] = []
var _expiration := 0
var _historique_ouvert := false
## 🎚️ LEVEL DESIGN : dès quelle durée l'engagement rappelle ×12 — à ×1, un pont
## de 18 mois dure 18 minutes.
const ACCELERER_MOIS := 3.0


func batir(interface) -> void:
	ui = interface
	compteur = PanelContainer.new()
	compteur.theme = ui._theme_ui
	ui._poser_boite(compteur)
	compteur.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	compteur.offset_left = -352
	compteur.offset_right = -16
	compteur.offset_bottom = -16
	compteur.grow_vertical = Control.GROW_DIRECTION_BEGIN
	ui.add_child(compteur)
	var lignes := VBoxContainer.new()
	compteur.add_child(lignes)
	besoin = ui._label("", 16, ui.TEXTE)
	lignes.add_child(besoin)
	preparation = ui._label("", 12, ui.GRIS)
	lignes.add_child(preparation)
	var bouton := Button.new()
	bouton.text = "Dernières décisions"
	bouton.pressed.connect(func() -> void:
		_historique_ouvert = not _historique_ouvert
		actualiser_affichage())
	lignes.add_child(bouton)
	avis = PanelContainer.new()
	avis.theme = ui._theme_ui
	ui._poser_boite(avis)
	avis.anchor_left = 0.5
	avis.anchor_right = 0.5
	avis.offset_left = -205
	avis.offset_right = 205
	avis.offset_top = 20
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
	avis.visible = compteur.visible and (_historique_ouvert or Time.get_ticks_msec() < _expiration)
	historique.visible = _historique_ouvert
	texte.text = "Dernières décisions · cette partie" if _historique_ouvert else "\n\n".join(_recent)
	if _historique_ouvert:
		var inverse := journal.duplicate()
		inverse.reverse()
		historique.text = "\n\n".join(inverse) if not inverse.is_empty() else "Aucune décision engagée."
	avis.modulate.a = 1.0 if _historique_ouvert else clampf(float(_expiration - Time.get_ticks_msec()) / 700.0, 0.0, 1.0)


func _chantiers(mois: float) -> Dictionary:
	var resultat := {}
	for c in ui.ville.chantiers(mois)["en_cours"]:
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
	_ponts.clear()
	for pont in ui.ville.ponts_coupes():
		_ponts[pont] = ui.trafic.pont_fonctionnel(pont, mois)
	actualiser(mois)


func engagement(couche: String, fid: int, r: Dictionary, duree: float, mois: float) -> void:
	var lieu: String = ui.lieux.nom(couche, fid, "Champ" if couche == "i" and ui.ville.est_champ(fid) else "")
	var prix: String = "−%s k€" % ui._milliers(r["cout_ke"]) if r["cout_ke"] > 0.0 else "décision engagée"
	var message := "%s : %s · %s" % [lieu, prix, ui._duree(duree) if duree > 0.0 else "effet immédiat"]
	if "relogement" in r["faits"]:
		message += "\n%s personnes nourries en moins." % ui._nb(ui.ville.champ_nourriture(fid), 0)
	elif duree >= ACCELERER_MOIS:
		message += "\n×12 : environ %d s." % int(ceil(duree * 5.0))
	notifier(message, mois)
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
		resultat = "Pont rebâti."
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
	var courants := _chantiers(mois)
	for cle in _en_cours:
		if not courants.has(cle):
			livraison(_en_cours[cle], mois)
	_en_cours = courants
	if _sans_toit >= 0 and n < _sans_toit:
		notifier("%d personnes abritées · %d encore dehors." % [_sans_toit - n, n] if n > 0
			else "%d personnes abritées · plus personne dehors." % (_sans_toit - n), mois)
	_sans_toit = n
	for pont in ui.ville.ponts_coupes():
		var ouvert: bool = ui.trafic.pont_fonctionnel(pont, mois)
		if ouvert and _ponts.has(pont) and not _ponts[pont]:
			notifier("%s : les deux rives sont reliées." % ui.lieux.nom("r", pont), mois)
		_ponts[pont] = ouvert
	actualiser_affichage()
