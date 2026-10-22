extends RefCounted
## ⚙️ Les réglages graphiques, au bouton à côté de la boussole. Ce qui coûte à la carte
## graphique d'après `outils/sonde_perfs.gd` (2026-10-19, RX 9060 XT, 1080p, ville
## entière : 6,2 ms dont 3,2 d'ombres). Gardés dans `user://graphismes.cfg`, sauf en contrôle.
const CHEMIN := "user://graphismes.cfg"

## Taille de la carte d'ombre, filtre des bords. 4096 : −1,2 à −2,3 ms ; filtre bas : −1,8 à −2,2.
const OMBRES := {
	"fines": [8192, RenderingServer.SHADOW_QUALITY_SOFT_ULTRA],
	"moyennes": [4096, RenderingServer.SHADOW_QUALITY_SOFT_MEDIUM],
	"legeres": [4096, RenderingServer.SHADOW_QUALITY_SOFT_LOW],
	"aucune": [4096, RenderingServer.SHADOW_QUALITY_SOFT_LOW],
}
const ANTICRENELAGE := {"fort": Viewport.MSAA_4X, "leger": Viewport.MSAA_2X, "non": Viewport.MSAA_DISABLED}
const ECHELLES := {"100": 1.0, "85": 0.85, "70": 0.7}
## ① Courbe de couleurs : [mode, exposition, blanc, contraste, saturation]. La palette est réglée
## en linéaire ; l'exposition rend aux tons moyens ce que la courbe leur prend (filmique et AgX
## plus forts : délavés, 2026-10-20). « douce » écartée par l'auteur
## (2026-10-20) : hors panneau, gardée pour les planches.
const COULEURS := {
	"non": [Environment.TONE_MAPPER_LINEAR, 1.0, 1.0, 1.25, 1.0],
	"douce": [Environment.TONE_MAPPER_AGX, 1.15, 3.0, 1.45, 1.07],
}
## ② Flou de maquette : force du flou de profondeur, voir `CameraAxo.regler_flou`.
const MAQUETTE := {"non": 0.0, "leger": 0.04}

## 🔴 Textes affichés, flaggables (90), en termes techniques (auteur, 2026-10-20). [clé, nom, [[valeur, mot]…]]
const LIGNES := [
	["ombres", "Qualité des ombres", [["fines", "Ultra"], ["moyennes", "Haute"], ["legeres", "Basse"], ["aucune", "Aucune"]]],
	["bois", "Ombres de la végétation", [[true, "Oui"], [false, "Non"]]],
	["recoins", "Occlusion ambiante (SSAO)", [[true, "Oui"], [false, "Non"]]],
	["rebonds", "Illumination indirecte (SSIL)", [[true, "Oui"], [false, "Non"]]],
	["ciel", "Éclairage ambiant du ciel", [[true, "Oui"], [false, "Non"]]],
	["brume", "Brouillard de distance", [[true, "Oui"], [false, "Non"]]],
	["maquette", "Profondeur de champ", [["leger", "Oui"], ["non", "Non"]]],
	["anticrenelage", "Anticrénelage (MSAA)", [["fort", "4×"], ["leger", "2×"], ["non", "Non"]]],
	["echelle", "Échelle de rendu 3D (FSR)", [["100", "100 %"], ["85", "85 %"], ["70", "70 %"]]],
]
## Le rendu d'avant les réglages, plus le rebond (aimé par l'auteur le 2026-10-20).
const DEFAUT := {"ombres": "fines", "bois": true, "recoins": true, "rebonds": true, "ciel": false,
	"brume": false, "anticrenelage": "fort", "echelle": "100",
	"couleurs": "non", "maquette": "non"}

var reglages := DEFAUT.duplicate()
var panneau: VBoxContainer
var _jeu
var _boutons := {}
## Un contrôle joue au rendu par défaut et n'écrase pas le fichier du joueur.
var _persistant := false


func batir(jeu) -> void:
	_jeu = jeu
	_persistant = not "--script" in OS.get_cmdline_args()
	for a in ["--essai", "--banc", "--interface"]:
		_persistant = _persistant and not a in OS.get_cmdline_user_args()
	if _persistant:
		_lire()
	_construire_panneau()
	appliquer()


func choisir(cle: String, valeur: Variant) -> void:
	reglages[cle] = valeur
	appliquer()
	if _persistant:
		var f := ConfigFile.new()
		for k in reglages:
			f.set_value("graphismes", k, reglages[k])
		f.save(CHEMIN)


func appliquer() -> void:
	var o: Array = OMBRES[reglages["ombres"]]
	RenderingServer.directional_shadow_atlas_set_size(int(o[0]), true)
	RenderingServer.directional_soft_shadow_filter_set_quality(int(o[1]))
	_jeu.soleil.shadow_enabled = reglages["ombres"] != "aucune" \
		and not "--sans-ombre" in OS.get_cmdline_user_args()
	# Les bois portent 4,5 M des 10 M de triangles de la vue entière : presque tout en ombre.
	if _jeu.paysage != null:
		for n in _jeu.paysage.get_children():
			if str(n.name).begins_with("Foret"):
				(n as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON \
					if reglages["bois"] else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_jeu._environnement.ssao_enabled = reglages["recoins"]
	# GPU (sonde_perfs --reglages, 2026-10-20) : rebond +0,4 à +0,6 ms, ciel 0, brume −0,2 à +0,5.
	_jeu._environnement.ssil_enabled = reglages["rebonds"]
	_jeu._environnement.ambient_light_source = Environment.AMBIENT_SOURCE_SKY if reglages["ciel"] \
		else Environment.AMBIENT_SOURCE_COLOR
	var vp: Viewport = _jeu.get_viewport()
	vp.msaa_3d = ANTICRENELAGE[reglages["anticrenelage"]]
	var e: float = ECHELLES[reglages["echelle"]]
	vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR if e >= 1.0 else Viewport.SCALING_3D_MODE_FSR
	vp.scaling_3d_scale = e
	appliquer_couleurs(_jeu.theme != "")
	_jeu.pivot.regler_flou(MAQUETTE[reglages["maquette"]])
	_marquer_boutons()


func appliquer_couleurs(diagnostic: bool) -> void:
	var c: Array = COULEURS["non" if diagnostic else reglages["couleurs"]]
	var env: Environment = _jeu._environnement
	env.tonemap_mode = int(c[0])
	env.tonemap_exposure = float(c[1])
	env.tonemap_white = float(c[2])
	env.tonemap_agx_white = float(c[2])
	env.tonemap_agx_contrast = float(c[3])
	env.adjustment_enabled = float(c[4]) != 1.0
	env.adjustment_saturation = float(c[4])
	env.fog_enabled = reglages["brume"] and not diagnostic
	_jeu.pivot.regler_brume(env if env.fog_enabled else null)


func basculer() -> void:
	panneau.visible = not panneau.visible


func _lire() -> void:
	var f := ConfigFile.new()
	if f.load(CHEMIN) != OK:
		return
	for l in LIGNES:
		var v: Variant = f.get_value("graphismes", l[0], DEFAUT[l[0]])
		# Une valeur qui n'est plus au menu (fichier ancien ou retouché) reprend le défaut.
		if (l[2] as Array).any(func(c): return typeof(c[0]) == typeof(v) and c[0] == v):
			reglages[l[0]] = v


func _construire_panneau() -> void:
	var ui = _jeu.interface
	var boutons: HBoxContainer = ui._camera_nord.get_parent()
	var cle := Button.new()
	cle.name = "Graphismes"
	cle.custom_minimum_size = Vector2(44, 36)
	cle.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cle.focus_mode = Control.FOCUS_NONE
	cle.icon = ui._icone("graphismes", 20)
	cle.tooltip_text = "Graphismes"
	cle.pressed.connect(basculer)
	boutons.add_child(cle)

	# Dans le panneau de la caméra, au-dessus des boutons : il se cache avec lui pendant le récit.
	panneau = VBoxContainer.new()
	panneau.name = "PanneauGraphismes"
	panneau.add_theme_constant_override("separation", 6)
	panneau.visible = false
	var v: VBoxContainer = boutons.get_parent()
	v.add_child(panneau)
	v.move_child(panneau, 0)
	panneau.add_child(ui._titre("Graphismes", 15, ui.TEXTE))
	for l in LIGNES:
		var rangee := HBoxContainer.new()
		rangee.add_theme_constant_override("separation", 3)
		# Oui/Non sur la ligne du nom : à dix lignes, le panneau passait sous le rail (2026-10-20).
		var court := (l[2] as Array).size() == 2
		var nom: Control = ui._etiquette(String(l[1]), 12, ui.GRIS)
		if court:
			nom.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			rangee.add_child(nom)
		else:
			panneau.add_child(nom)
		panneau.add_child(rangee)
		for c in l[2]:
			var b := Button.new()
			b.text = String(c[1])
			b.focus_mode = Control.FOCUS_NONE
			b.add_theme_font_size_override("font_size", ui._taille(13))
			b.pressed.connect(choisir.bind(l[0], c[0]))
			rangee.add_child(b)
			_boutons[b] = [l[0], c[0]]
	var filet := Control.new()
	filet.custom_minimum_size = Vector2(0, 4)
	panneau.add_child(filet)


func _marquer_boutons() -> void:
	for b in _boutons:
		var cv: Array = _boutons[b]
		var v: Variant = reglages[cv[0]]
		_jeu.interface._marquer(b, typeof(v) == typeof(cv[1]) and v == cv[1])
