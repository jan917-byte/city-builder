extends Control
## 📖 LE RÉCIT D'OUVERTURE, et il ne fait qu'une chose : poser la situation
## avant que le joueur ait une décision à prendre. Quatre pages, une flèche.
##
## 🔴 CHAQUE PAGE CADRE CE QU'ELLE RACONTE — le texte ne dit rien que l'image
## ne montre, sans pictogrammes sur la carte. Aucun
## chiffre écrit à la main : ils sortent de `ville.degats`.
##
## 🔴 LA DERNIÈRE PAGE NE MONTRE PAS LES CHAMPS (demande de l'auteur,
## 2026-09-17) : elle demande un endroit atteignable, le joueur cherche. Ce qui
## l'oriente, c'est la fiche — seul un champ ouvre le bloc de relogement.

## 🎚️ LEVEL DESIGN : ce que la carte laisse libre en bas, au-dessus des
## commandes du temps.
const HAUTEUR_BAS := 104.0

var jeu
var page := 0
var _pages := []
var _titre: Label
var _texte: Label
var _compte: Label
var _passer: Button
var _fleche: Button


func batir(maquette) -> void:
	jeu = maquette
	# ⚠️ ANCRES *ET* MARGES : posé dans l'arbre, un `set_anchors_preset` seul
	# garde le rectangle nul du départ et le panneau se colle en haut à gauche.
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# Le récit prend la souris : la ville se regarde, elle ne se clique pas
	# encore.
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	var ui = jeu.interface
	theme = ui._theme_ui
	var boite := PanelContainer.new()
	ui._poser_boite(boite)
	boite.custom_minimum_size.x = 420
	# 🔴 LA CARTE NE COUVRE PAS CE QU'ELLE RACONTE : centrée en largeur,
	# posée au-dessus des commandes du temps, elle laisse la ville visible.
	# 🎚️ LEVEL DESIGN : sa hauteur au-dessus du bas de l'écran.
	boite.anchor_left = 0.5
	boite.anchor_right = 0.5
	boite.anchor_top = 1.0
	boite.anchor_bottom = 1.0
	boite.grow_horizontal = Control.GROW_DIRECTION_BOTH
	boite.grow_vertical = Control.GROW_DIRECTION_BEGIN
	boite.offset_bottom = -HAUTEUR_BAS
	add_child(boite)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	boite.add_child(v)
	_titre = ui._label("", 22, ui.TEXTE)
	_titre.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_titre)
	_texte = ui._label("", 14, ui.TEXTE)
	_texte.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_texte)
	v.add_child(HSeparator.new())
	var bas := HBoxContainer.new()
	bas.add_theme_constant_override("separation", 10)
	v.add_child(bas)
	_compte = ui._label("", 11, ui.GRIS)
	_compte.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_compte.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bas.add_child(_compte)
	_passer = Button.new()
	_passer.text = "Passer"
	_passer.pressed.connect(terminer)
	bas.add_child(_passer)
	_fleche = Button.new()
	_fleche.text = "→"
	_fleche.tooltip_text = "La suite"
	_fleche.add_theme_font_size_override("font_size", 20)
	_fleche.custom_minimum_size.x = 56
	_fleche.pressed.connect(suivant)
	bas.add_child(_fleche)
	ui._sans_focus(self)


## Les pages, dans l'ordre. `cadrage` est un repère de la carte, sauf la
## dernière, qui reprend le cadrage de la première décision.
func _batir_pages() -> void:
	var d: Dictionary = jeu.ville.degats(0.0)
	# Les seuls franchissements de la ville sont ceux que la crue a pris : le
	# compte des coupés est donc aussi celui des ponts.
	var ponts: int = int(d["franchissements_coupes"])
	var touches := 0
	for fid in jeu.ville.ilots:
		if jeu.ville.base("i", fid, "logements_sinistres") > 0.0:
			touches += 1
	_pages = [
		{
			"titre": "Wehrau",
			"texte": "Cinq mille habitants sur les deux rives de l'Ilse."
				+ " Le centre ancien d'un côté, le faubourg ouvrier de"
				+ " l'autre, les champs tout autour."
				+ "\n\n%d ponts la tiennent ensemble." % ponts,
			"repere": "batie", "lacet": 35.0, "hauteur": 55.0,
		},
		{
			"titre": "La crue",
			"texte": "L'Ilse est sortie de son lit. Sur la rive gauche, l'eau"
				+ " est montée dans le faubourg et y a laissé la boue."
				+ "\n\n%d îlots ont perdu des logements." % touches,
			"repere": "faubourg", "lacet": 22.0, "hauteur": 38.0,
		},
		{
			"titre": "Ce qu'elle a laissé",
			"texte": "%d personnes n'ont plus de toit, et les %d"
				% [int(d["logements_perdus"]), ponts]
				+ " ponts sont coupés : de ce côté de l'eau, on ne"
				+ " sort plus qu'à pied.",
			"repere": "pont_casse", "taille": 340.0, "lacet": 40.0, "hauteur": 26.0,
		},
		{
			"titre": "Le premier soir",
			"texte": "Ces personnes dorment dehors. Trouvez-leur un endroit où"
				+ " s'installer, qu'elles puissent rejoindre à pied."
				# 🔒 Vrai depuis le verrou des premières minutes (auteur, 2026-09-22).
				+ "\n\nChaque mois dehors se paie en aide d'urgence, et rien"
				+ " d'autre ne s'engage tant que tout le monde n'est pas abrité.",
			"repere": "", "lacet": 35.0, "hauteur": 42.0,
		},
	]


## Les îlots bâtis, champs exclus.
func _batie() -> Array:
	var fids := []
	for fid in jeu.ville.ilots:
		if str(jeu.ville.ilots[fid].get("sous_type", "")) != "champ":
			fids.append(int(fid))
	return fids


func en_cours() -> bool:
	return visible


func commencer() -> void:
	if _pages.is_empty():
		_batir_pages()
	page = 0
	visible = true
	# Le guide des premiers pas attend la fin du récit : jamais deux panneaux
	# de texte ensemble.
	jeu.ouverture.ouvert = false
	jeu.ouverture.actualiser(true)
	jeu.interface._debut.visible = false
	# 📖 ET RIEN D'AUTRE À L'ÉCRAN : le tableau de bord, le rail et les
	# commandes du temps ne reviennent qu'à la dernière page.
	jeu.interface.montrer_jeu(false)
	jeu._sur_vitesse(0.0)
	_afficher()


func suivant() -> void:
	if page + 1 >= _pages.size():
		terminer()
		return
	page += 1
	_afficher()


## 🕰️ LA FIN DES CARTES EST LE DÉBUT DE LA PARTIE (auteur, 2026-09-18) : le
## tableau de bord revient, et le temps part. Les sinistrés dorment dehors
## pendant que les mois passent — c'est ce qui fait de la première décision
## une urgence plutôt qu'un menu.
func terminer() -> void:
	visible = false
	jeu.interface.montrer_jeu(true)
	jeu.interface._debut.visible = true
	jeu.ouverture.ouvert = true
	jeu._cadrer_relogement()
	jeu.ouverture.actualiser(true)
	jeu._sur_vitesse(1.0)


func _afficher() -> void:
	var p: Dictionary = _pages[page]
	_titre.text = String(p["titre"])
	_texte.text = String(p["texte"])
	_compte.text = "%d / %d" % [page + 1, _pages.size()]
	_passer.visible = page + 1 < _pages.size()
	jeu.pivot.caler(float(p["lacet"]), float(p["hauteur"]))
	match String(p["repere"]):
		"":
			jeu._cadrer_relogement()
		"batie":
			# Mesuré : l'emprise des îlots qui ne sont pas des champs. Le repère
			# « ville » vise l'origine de la carte, forêt comprise.
			jeu._viser_ensemble(_batie(), 260.0)
		_:
			jeu._repere(String(p["repere"]))
			# Le repère porte sa distance ; une page peut la desserrer pour
			# montrer autour de son sujet.
			if float(p.get("taille", 0.0)) > 0.0:
				jeu.pivot.viser(Vector2(jeu.pivot.position.x, jeu.pivot.position.z),
					float(p["taille"]))
