extends CanvasLayer
# L'interface du prototype énergie simplifié.
#
# Deux niveaux sans mélange : la ville à gauche, l'îlot choisi à droite, et le
# survol ne change jamais la fiche. Un seul geste, augmenter la part de toit
# équipée — qui prend du temps, se voit avancer, et se paie.
#
# 💶 Quatre nombres à l'écran, pas un de plus : caisse et recette à gauche,
# coût de la pose visée et amortissement à droite. Le capital politique reste
# hors du test.

signal solaire_demande(fid: int, part: float)
signal vitesse_demandee(vitesse: float)
signal temps_remis()

const Ville := preload("res://scripts/ville.gd")

const FOND := Color(0.106, 0.118, 0.141, 0.94)
const BORD := Color(0.173, 0.192, 0.227)
const TEXTE := Color(0.902, 0.910, 0.925)
const GRIS := Color(0.604, 0.635, 0.694)
const ACCENT := Color(0.910, 0.769, 0.416)
# Le seul refus du prototype : la caisse ne suit pas. Un bouton grisé sans
# raison écrite est une panne, pas une règle.
const ALERTE := Color(0.878, 0.451, 0.376)


## Ce qui est POSÉ, et vers quoi ça va. Un `ProgressBar` ne montre qu'un
## nombre : il en faut deux pour distinguer « 40 % posés » de « 40 % en route
## vers 72 % ». Elle ne se touche pas — le réglage est le curseur d'en dessous.
class Jauge extends Control:
	const RESTE := Color(0.153, 0.169, 0.204)   # le toit encore nu
	const VISEE := Color(0.404, 0.349, 0.212)   # l'objectif demandé, pas encore atteint
	const POSE := Color(0.957, 0.867, 0.596)    # le jaune clair des panneaux réellement en place
	const CADRE := Color(0.290, 0.318, 0.373)   # le filet qui dessine la jauge quand elle est vide

	var pose := 0.0   # 0 → 1
	var cible := 0.0  # 0 → 1, toujours ≥ pose

	func regler(p: float, c: float) -> void:
		if is_equal_approx(p, pose) and is_equal_approx(c, cible):
			return  # ⚠️ appelé à chaque image : ne repeindre que sur un vrai changement
		pose = p
		cible = c
		queue_redraw()

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), RESTE)
		if cible > pose:
			draw_rect(Rect2(0.0, 0.0, size.x * cible, size.y), VISEE)
		if pose > 0.0:
			draw_rect(Rect2(0.0, 0.0, size.x * pose, size.y), POSE)
		# Sans ce filet, une jauge à 0 % est un rectangle sombre de plus dans un
		# panneau sombre.
		draw_rect(Rect2(Vector2.ZERO, size), CADRE, false, 1.0)


var ville: Ville

var _ville_valeurs := {}
var _fiche_valeurs := {}
var _fiche_titre: Label
var _fiche_vide: Label
var _fiche_grille: GridContainer
var _solaire_bloc: VBoxContainer
var _solaire_valeur: Label
var _solaire_cout: Label
var _solaire_curseur: HSlider
var _solaire_jauge: Jauge
var _solaire_bouton: Button
var _message: Label
var _camera_vue: Label
var _temps_label: Label
var _vitesses := {}

var _fiche_fid := -1
var _mois := 0.0
var _caisse_ke := Ville.CAISSE_DEPART_KE
var _cout_en_alerte := false

# La position posée par l'auteur et pas encore validée ; -1 = la fiche commande.
# ⚠️ Sans ce souvenir, `_maj_fiche()` (à chaque image) reposait la valeur sous
# le doigt et la barre était intraînable (défaut du 2026-08-17).
var _solaire_choix := -1.0
# Vrai pendant que la fiche écrit dans le curseur : une montée de `min_value`
# déplacerait la valeur et émettrait le signal, donc inventerait un choix.
var _ecrit_curseur := false


func batir() -> void:
	_panneau_ville()
	_panneau_ilot()
	_panneau_camera()
	_controles_temps()


func _boite() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = FOND
	sb.border_color = BORD
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(12)
	return sb


## Le curseur par défaut de Godot est un trait gris sans remplissage : on y lit
## une position, pas une quantité.
func _habiller_curseur(s: HSlider) -> void:
	var gouttiere := StyleBoxFlat.new()
	gouttiere.bg_color = Jauge.RESTE
	gouttiere.set_corner_radius_all(3)
	# ⚠️ Chez Slider, c'est la MARGE de la boîte qui fait l'épaisseur du rail :
	# il n'y a pas de hauteur à régler ailleurs.
	gouttiere.content_margin_top = 3.0
	gouttiere.content_margin_bottom = 3.0
	s.add_theme_stylebox_override("slider", gouttiere)

	var rempli := StyleBoxFlat.new()
	rempli.bg_color = Jauge.VISEE
	rempli.set_corner_radius_all(3)
	rempli.content_margin_top = 3.0
	rempli.content_margin_bottom = 3.0
	s.add_theme_stylebox_override("grabber_area", rempli)
	s.add_theme_stylebox_override("grabber_area_highlight", rempli)

	var poignee := _pastille(Jauge.POSE)
	s.add_theme_icon_override("grabber", poignee)
	s.add_theme_icon_override("grabber_highlight", poignee)
	s.add_theme_icon_override("grabber_disabled", _pastille(GRIS.darkened(0.4)))


static func _pastille(coul: Color) -> ImageTexture:
	var img := Image.create_empty(7, 20, false, Image.FORMAT_RGBA8)
	img.fill(coul)
	return ImageTexture.create_from_image(img)


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
		# La petite économie APRÈS l'énergie : c'est elle qu'on transforme,
		# l'argent ne fait que limiter le rythme.
		["caisse", "Caisse"],
		["recette", "Recette solaire"],
	]:
		if ligne[0] == "caisse":
			v.add_child(HSeparator.new())
		var h := HBoxContainer.new()
		h.add_child(_label(ligne[1], 12, GRIS))
		var valeur := _label("", 14, TEXTE)
		valeur.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		valeur.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(valeur)
		_ville_valeurs[ligne[0]] = valeur
		v.add_child(h)

	# Le seul nombre de l'écran qui puisse dire non : couleur d'accent.
	(_ville_valeurs["caisse"] as Label).add_theme_color_override("font_color", ACCENT)


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
	for ligne in [
		["tissu", "Tissu"],
		["logements", "Logements"],
		["conso", "Consommation"],
		["production", "Production"],
		["toit", "Toit équipable"],
		# L'amortissement est une propriété de l'îlot, pas de la part visée
		# (`energie.rentabilite_annees`) : sa place est dans la grille.
		["retour", "Se rembourse en"],
	]:
		_fiche_grille.add_child(_label(ligne[1], 12, GRIS))
		var valeur := _label("", 12, TEXTE)
		valeur.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		_fiche_grille.add_child(valeur)
		_fiche_valeurs[ligne[0]] = valeur

	_solaire_bloc = VBoxContainer.new()
	_solaire_bloc.add_theme_constant_override("separation", 6)
	_solaire_bloc.visible = false
	v.add_child(_solaire_bloc)
	_solaire_bloc.add_child(HSeparator.new())
	_solaire_bloc.add_child(_label("Panneaux solaires", 13, ACCENT))
	_solaire_valeur = _label("", 13, TEXTE)
	_solaire_bloc.add_child(_solaire_valeur)

	# La lecture d'abord, le réglage ensuite. L'une est pleine et muette,
	# l'autre a une poignée : elles ne se ressemblent pas.
	_solaire_jauge = Jauge.new()
	_solaire_jauge.custom_minimum_size = Vector2(0, 15)
	_solaire_jauge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_solaire_bloc.add_child(_solaire_jauge)

	_solaire_bloc.add_child(_label("Objectif", 11, GRIS))

	_solaire_curseur = HSlider.new()
	# 🔴 Échelle FIXE 0→100. Monter `min_value` avec la pose faisait changer un
	# même pixel de sens en cours de partie ; le plancher se tient par un
	# rattrapage dans `_sur_curseur`.
	_solaire_curseur.min_value = 0.0
	_solaire_curseur.max_value = 100.0
	_solaire_curseur.step = 1.0
	# ⚠️ Sinon le curseur garde le focus après un clic et AVALE les flèches :
	# la caméra ne tourne plus tant qu'on n'a pas cliqué ailleurs.
	_solaire_curseur.focus_mode = Control.FOCUS_NONE
	_habiller_curseur(_solaire_curseur)
	_solaire_curseur.value_changed.connect(_sur_curseur)
	_solaire_bloc.add_child(_solaire_curseur)

	# Hors de la grille parce qu'elle suit le curseur : elle parle de la CIBLE,
	# pas de l'îlot.
	_solaire_cout = _label("", 12, GRIS)
	_solaire_cout.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_solaire_bloc.add_child(_solaire_cout)

	_solaire_bouton = Button.new()
	_solaire_bouton.text = "Augmenter"
	_solaire_bouton.pressed.connect(func() -> void:
		solaire_demande.emit(_fiche_fid, _solaire_curseur.value / 100.0))
	_solaire_bloc.add_child(_solaire_bouton)

	_message = _label("", 12, GRIS)
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_message)


# Le lacet 0 place la caméra AU SUD : repère fixé par « Z vers le sud » dans
# `07_exporter_godot.py:680`, pas ici.
const AZIMUTS := ["du sud", "du sud-est", "de l'est", "du nord-est",
	"du nord", "du nord-ouest", "de l'ouest", "du sud-ouest"]


func _panneau_camera() -> void:
	# Les gestes de caméra ne se devinent pas, et un jeu qui oblige à ouvrir un
	# fichier pour les connaître n'en est pas un.
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", _boite())
	p.anchor_top = 1.0
	p.anchor_bottom = 1.0
	p.offset_left = 16
	p.offset_bottom = -16
	p.grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_child(p)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	p.add_child(v)
	v.add_child(_label("Caméra", 12, ACCENT))
	_camera_vue = _label("", 14, TEXTE)
	v.add_child(_camera_vue)
	v.add_child(HSeparator.new())
	for ligne in [
		"clic droit glissé : tourner autour de la ville",
		"clic milieu glissé : déplacer · molette : zoom",
		"Q E : quart de tour · flèches : ajuster",
		"T : vue de dessus · V B R I G : les cinq repères",
		"C : recolorer par tissu",
	]:
		v.add_child(_label(ligne, 11, GRIS))


func maj_camera(lacet: float, hauteur: float) -> void:
	if _camera_vue == null:
		return
	var l := fmod(fmod(lacet, 360.0) + 360.0, 360.0)
	var i := int(roundf(l / 45.0)) % 8
	_camera_vue.text = "vue %s, %d° au-dessus" % [AZIMUTS[i], int(roundf(hauteur))]


func _controles_temps() -> void:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", _boite())
	p.anchor_left = 0.5
	p.anchor_right = 0.5
	p.anchor_top = 1.0
	p.anchor_bottom = 1.0
	# 430 de large : le contenu occupe 409 px marges comprises, mesuré sur
	# `wehrau_essai_reset.png` après l'ajout du bouton de retour à zéro.
	p.offset_left = -215
	p.offset_right = 215
	p.offset_top = -66
	p.offset_bottom = -16
	p.grow_horizontal = Control.GROW_DIRECTION_BOTH
	p.grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_child(p)

	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	p.add_child(h)
	_temps_label = _label("Mois 0", 13, TEXTE)
	_temps_label.custom_minimum_size.x = 92
	h.add_child(_temps_label)
	for choix in [["Pause", 0.0], ["×1", 1.0], ["×4", 4.0], ["×12", 12.0]]:
		var b := Button.new()
		b.text = choix[0]
		var v: float = choix[1]
		b.pressed.connect(_demander_vitesse.bind(v))
		h.add_child(b)
		_vitesses[v] = b

	# Rejouer un geste demandait trois secondes de rechargement. Le bouton remet
	# le temps ET la ville : un temps qui recule seul laisserait des toits noirs
	# sous un compteur à « Mois 0 ».
	var raz := Button.new()
	raz.text = "Recommencer"
	raz.tooltip_text = "Remet le temps au mois 0 et annule les poses décidées."
	raz.pressed.connect(func() -> void: temps_remis.emit())
	h.add_child(raz)


func _demander_vitesse(v: float) -> void:
	vitesse_demandee.emit(v)


func maj(indic: Dictionary, mois: float, vitesse: float) -> void:
	if indic.is_empty():
		return
	_mois = mois
	var conso: float = indic["conso_mwh"]
	var prod: float = indic["production_mwh"]
	_ville_valeurs["conso"].text = _nb(conso / 1000.0, 1) + " GWh/an"
	_ville_valeurs["production"].text = _nb(prod / 1000.0, 1) + " GWh/an"
	_ville_valeurs["achat"].text = _nb(indic["achat_mwh"] / 1000.0, 1) + " GWh/an"
	_ville_valeurs["co2"].text = _nb(indic["co2_kt"], 1) + " kt/an"
	# ⚠️ Mémorisée ici : `_maj_fiche()` en a besoin à chaque image, et la
	# recalculer parcourrait la ville une seconde fois par image.
	_caisse_ke = indic["caisse_ke"]
	_ville_valeurs["caisse"].text = _milliers(_caisse_ke) + " k€"
	_ville_valeurs["recette"].text = "+" + _milliers(indic["recette_ke_an"]) + " k€/an"
	_temps_label.text = "Mois %s" % _nb(mois, 1)
	for v in _vitesses:
		(_vitesses[v] as Button).disabled = is_equal_approx(float(v), vitesse)
	if _fiche_fid >= 0:
		_maj_fiche()


func montrer(couche: String, fid: int, _garder := true) -> void:
	# La fiche appartient au seul îlot cliqué : rues et survol se surlignent
	# dans la ville sans jamais en prendre possession.
	if couche != "i" or fid < 0:
		return
	if fid != _fiche_fid:
		_solaire_choix = -1.0  # changer d'îlot abandonne le réglage non validé
	_fiche_fid = fid
	_fiche_vide.visible = false
	_solaire_bloc.visible = true
	_maj_fiche()


func _maj_fiche() -> void:
	var o: Dictionary = ville.ilots.get(_fiche_fid, {})
	if o.is_empty():
		return
	_fiche_titre.text = "Îlot %d" % _fiche_fid

	var conso := ville.valeur("i", _fiche_fid, "_conso_mwh", _mois)
	var prod := ville.valeur("i", _fiche_fid, "_production_mwh", _mois)
	var toit := ville.valeur("i", _fiche_fid, "_toit_equipable_m2", _mois)
	var etat := ville.etat_solaire(_fiche_fid, _mois)
	var pct := float(etat["actuel"]) * 100.0
	var cible_pct := float(etat["cible"]) * 100.0
	(_fiche_valeurs["tissu"] as Label).text = str(o.get("sous_type", "?")).replace("_", " ")
	(_fiche_valeurs["logements"] as Label).text = _nb(float(o.get("logements", 0.0)), 0)
	(_fiche_valeurs["conso"] as Label).text = _nb(conso, 0) + " MWh/an"
	(_fiche_valeurs["production"] as Label).text = _nb(prod, 0) + " MWh/an"
	(_fiche_valeurs["toit"] as Label).text = _nb(toit, 0) + " m²"
	var ans := ville.valeur("i", _fiche_fid, "_rentabilite_annees", _mois)
	(_fiche_valeurs["retour"] as Label).text = \
		"—" if is_inf(ans) else "%d ans" % int(roundf(ans))

	# 🔴 On passe ici À CHAQUE IMAGE : le curseur ne se repositionne que sans
	# choix en cours, sinon on garde la position de l'auteur, remontée au
	# niveau déjà posé.
	# ⚠️ Il se VERROUILLE pendant les travaux : une pose engagée est payée, et
	# ce verrou permet aux rampes de s'additionner sans réécrire l'histoire
	# d'un toit (`ville.lancer_solaire`).
	_ecrit_curseur = true
	_solaire_curseur.editable = toit > 0.0 and pct < 100.0 and not etat["en_cours"]
	if _solaire_choix < 0.0:
		_solaire_curseur.set_value_no_signal(maxf(pct, cible_pct))
	else:
		_solaire_choix = maxf(_solaire_choix, pct)
		_solaire_curseur.set_value_no_signal(_solaire_choix)
	_ecrit_curseur = false
	# L'objectif visé est celui du curseur tant qu'il n'est pas validé, celui de
	# la pose en cours sinon.
	_solaire_jauge.regler(pct / 100.0,
		maxf(pct, _solaire_choix if _solaire_choix >= 0.0 else cible_pct) / 100.0)

	var recette := ville.valeur("i", _fiche_fid, "_recette_ke_an", _mois)
	_alerter_cout(false)
	if toit <= 0.0:
		_solaire_valeur.text = "Église protégée — panneaux solaires interdits." \
			if int(o.get("solaire_possible", 1)) == 0 else "Aucun toit équipable."
		_solaire_cout.text = ""
		_solaire_bouton.text = "Augmenter"
		_solaire_bouton.disabled = true
	elif _solaire_choix >= 0.0:
		_afficher_choix(pct, _solaire_choix)
	elif etat["en_cours"]:
		_solaire_valeur.text = "%d %% posés → cible %d %% · encore %s" % [
			int(roundf(pct)), int(roundf(cible_pct)), _duree(float(etat["reste_mois"]))]
		_solaire_cout.text = "Travaux engagés : %s k€ payés" % _milliers(float(etat["cout_ke"]))
		_solaire_bouton.text = "Chantier en cours"
		_solaire_bouton.disabled = true
	else:
		_solaire_valeur.text = "%d %% du toit équipé" % int(roundf(pct))
		_solaire_cout.text = "Rapporte %s k€/an" % _milliers(recette) if pct > 0.0 \
			else "Aucun panneau posé."
		if etat["a_commence"]:
			_message.text = "Pose terminée. Les toits et les totaux ont atteint leur cible."
		_solaire_bouton.text = "Toit entièrement équipé" if pct >= 99.95 else "Augmenter"
		_solaire_bouton.disabled = true


## Tant que le réglage n'est pas validé.
## 🔴 Le seul endroit où le jeu dit non : un bouton grisé sans phrase est une
## panne, sous « il manque 214 k€ » c'est une règle.
func _afficher_choix(actuel: float, cible: float) -> void:
	var duree := ville.duree_solaire_mois(actuel / 100.0, cible / 100.0)
	var cout := ville.cout_solaire_ke(_fiche_fid, cible / 100.0, _mois)
	_solaire_valeur.text = "%d %% posés → cible %d %% · durée : %s" % [
		int(roundf(actuel)), int(roundf(cible)), _duree(duree)]
	_solaire_bouton.text = "Augmenter à %d %%" % int(roundf(cible))
	_solaire_bouton.disabled = cible <= actuel + 0.01

	var manque := cout - _caisse_ke
	if manque > 0.001:
		_solaire_cout.text = "Coût %s k€ · il manque %s k€ en caisse" % [
			_milliers(cout), _milliers(manque)]
		_solaire_bouton.disabled = true
	else:
		_solaire_cout.text = "Coût %s k€ · reste %s k€ en caisse" % [
			_milliers(cout), _milliers(_caisse_ke - cout)]
	_alerter_cout(manque > 0.001)


## ⚠️ Appelé à chaque image : reposer un `theme_color_override` identique fait
## retraiter le thème du Label pour rien.
func _alerter_cout(alerte: bool) -> void:
	if alerte == _cout_en_alerte:
		return
	_cout_en_alerte = alerte
	_solaire_cout.add_theme_color_override("font_color", ALERTE if alerte else GRIS)


## L'entrée de l'essai automatisé dans le curseur. Passe par `value_changed`,
## donc par le même chemin qu'un doigt : la capture prouve ce que le joueur
## verra, pas ce que le code croit.
func viser(pct: float) -> void:
	_solaire_curseur.value = pct


func _sur_curseur(v: float) -> void:
	if _fiche_fid < 0 or _ecrit_curseur:
		return
	var actuel := ville.valeur("i", _fiche_fid, "part_toit_equipe", _mois) * 100.0
	# Déposer des panneaux n'est pas une décision de ce prototype (`Énergie` §1).
	# Rattrapé ici plutôt qu'en montant `min_value`, pour garder l'échelle fixe.
	if v < actuel:
		v = actuel
		_ecrit_curseur = true
		_solaire_curseur.set_value_no_signal(v)
		_ecrit_curseur = false
	_solaire_choix = v
	_solaire_jauge.regler(actuel / 100.0, v / 100.0)
	_afficher_choix(actuel, v)


## Après un retour au mois 0 : réglage non validé et compte rendu périmés.
func remis_a_zero() -> void:
	_solaire_choix = -1.0
	_message.text = "Retour au mois 0. La ville est comme au premier jour, caisse à %s k€." \
		% _milliers(Ville.CAISSE_DEPART_KE)
	if _fiche_fid >= 0:
		_maj_fiche()


func confirmer_solaire(cout_ke := 0.0) -> void:
	_solaire_choix = -1.0  # la demande est partie : la fiche reprend la main
	_message.text = "La pose a commencé — %s k€ engagés. Accélérez le temps pour la suivre." \
		% _milliers(cout_ke)
	_maj_fiche()


static func _duree(mois: float) -> String:
	if mois < 1.0:
		return "%d jour(s)" % int(ceil(mois * 30.0))
	return "%s mois" % _nb(mois, 1)


static func _nb(v: float, dec: int) -> String:
	return (("%%.%df" % dec) % v).replace(".", ",")


## Avec l'espace des milliers : la caisse passe les 10 000 k€ en vingt ans, et
## « 10240 » se lit de travers.
static func _milliers(v: float) -> String:
	var s := "%d" % int(roundf(absf(v)))
	var out := ""
	for i in s.length():
		if i > 0 and (s.length() - i) % 3 == 0:
			out += " "
		out += s[i]
	return ("−" if v < -0.5 else "") + out
