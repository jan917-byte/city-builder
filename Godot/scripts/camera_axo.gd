extends Node3D
# Caméra ORTHOGRAPHIQUE : zoom, panoramique, et orbite (lacet 360°, hauteur
# 6°–90°).
#
# 🔄 RETOUR EN ARRIÈRE SIGNALÉ (§3 ter) : ce fichier interdisait l'orbite ;
# l'auteur l'a demandée le 2026-08-17.
#
# ⚠️ L'ORTHOGRAPHIE, elle, reste : deux des trois critères de réussite en
# dépendent (`Plan 3 mois.md:48`) — la barre doit projeter 3× une maison de 3
# OÙ QU'ELLE SOIT dans le cadre, idem pour les largeurs de rue. Et comme l'œil
# ne s'approche jamais (zoomer, c'est réduire `size`), la coupe de
# `Périmètre et coupes.md:42` tient toujours : pas de LOD, pas de distance.
# 🔄 2026-08-19 : la barre est passée à 6 niveaux, et il y en a trois. L'argument
# tient — il porte sur le RAPPORT, 16,2 m contre 8,1 m. Mais le critère du vault
# dit encore 9 : à trancher dans `Questions ouvertes.md`, pas ici.
#
# Le prix payé : sous ~15° on regarde des façades, qui sont des murs nus d'une
# seule teinte. Angle de contrôle (silhouettes, hauteurs), pas angle de jeu —
# d'où le plancher à 6°, possible sans devenir la vue par défaut.
#
# LES GESTES
#   molette                zoom
#   clic gauche glissé     attraper le sol ; clic bref : sélectionner
#   Ctrl + clic glissé     tourner et incliner autour du point visé
#   Q / E                  quart de tour, recalé sur les multiples de 90°
#   flèches ← →            lacet par crans de 15°
#   flèches ↑ ↓            hauteur du regard par crans de 8°
#   T                      bascule vue de dessus ⇄ hauteur précédente

signal vue_changee(lacet: float, hauteur: float)
signal clic_sol(position_ecran: Vector2)

const HAUTEUR_DEFAUT := 32.0   # l'angle historique : il reste celui du démarrage
const HAUTEUR_MIN := 6.0       # sous 15° on regarde des façades nues, voir en-tête
const HAUTEUR_MAX := 90.0      # à pic
const RECUL := 6500.0          # inclut les versants extérieurs pendant l'orbite
const TAILLE_MIN := 40.0
const TAILLE_MAX := 2400.0

const CRAN_LACET := 15.0
const CRAN_HAUTEUR := 8.0
const SENS_ORBITE := 0.30      # degrés par pixel de souris
const SUIVI := 18.0            # rattrapage de l'angle affiché, par seconde
const SEUIL_GLISSE := 5.0      # tolère le tremblement d'un clic, en pixels

var camera: Camera3D
var taille := 1200.0

# CIBLES, pas valeurs affichées. `lacet` n'est PAS ramené dans [0, 360[ :
# l'accumuler évite le saut 359° → 0° pendant l'interpolation.
var lacet := 30.0
var hauteur := HAUTEUR_DEFAUT

var _lacet_vu := 30.0
var _hauteur_vu := HAUTEUR_DEFAUT
var _appui := false
var _glisse := false
var _orbite := false
var _hauteur_avant := HAUTEUR_DEFAUT
var _depart := Vector2.ZERO
var _ancre := Vector3.ZERO
var _ancre_ecran := Vector2.ZERO
var _ancre_active := false
var _zoom_actif := false
var _taille_cible := 1200.0


func _ready() -> void:
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.near = 0.05
	camera.far = 14000.0
	camera.position = Vector3(0.0, 0.0, RECUL)
	add_child(camera)
	_appliquer()


func _process(delta: float) -> void:
	# Interpolation exponentielle : indépendante du framerate. Sans elle, un
	# quart de tour est une téléportation dont on ressort désorienté.
	if is_equal_approx(_lacet_vu, lacet) and is_equal_approx(_hauteur_vu, hauteur) and not _zoom_actif:
		return
	var k: float = 1.0 - exp(-SUIVI * delta)
	_lacet_vu = lerpf(_lacet_vu, lacet, k)
	_hauteur_vu = lerpf(_hauteur_vu, hauteur, k)
	if absf(_lacet_vu - lacet) < 0.02:
		_lacet_vu = lacet
	if absf(_hauteur_vu - hauteur) < 0.02:
		_hauteur_vu = hauteur
	if _zoom_actif:
		taille = lerpf(taille, _taille_cible, k)
		if absf(taille - _taille_cible) < 0.02:
			taille = _taille_cible
			_zoom_actif = false
	_appliquer()
	if _ancre_active:
		_accrocher()


func _appliquer() -> void:
	# ⚠️ `taille` n'est PAS passée telle quelle. En ortho, le sol visible vaut
	# `size / sin(hauteur)` : à 10° la ville de 1 084 m ne projetait plus que
	# 188 m, une bande au milieu d'un écran vide (mesuré à la 1re capture).
	# Le sinus rend la quantité de sol indépendante de l'angle ; le rapport à
	# sin(32°) garde la vue par défaut identique à ce qu'elle était.
	# Les bâtiments, eux, grandissent — c'est ce qu'on vient chercher.
	camera.size = taille * sin(deg_to_rad(_hauteur_vu)) / sin(deg_to_rad(HAUTEUR_DEFAUT))
	rotation_degrees = Vector3(-_hauteur_vu, _lacet_vu, 0.0)
	vue_changee.emit(_lacet_vu, _hauteur_vu)


func viser(cible: Vector2, t: float) -> void:
	# Les repères clavier (V B R I) recadrent sans redresser l'angle : sinon
	# regarder la barre depuis l'ouest serait impossible.
	_annuler_geste()
	position = Vector3(cible.x, position.y, cible.y)
	taille = clampf(t, TAILLE_MIN, TAILLE_MAX)
	_appliquer()


## Sans interpolation : une passe `--essai` n'attend pas la caméra.
func caler(l: float, h: float) -> void:
	_annuler_geste()
	lacet = l
	hauteur = clampf(h, HAUTEUR_MIN, HAUTEUR_MAX)
	_lacet_vu = lacet
	_hauteur_vu = hauteur
	_appliquer()


## Recale sur le multiple de 90° plutôt que d'ajouter 90 : après une orbite
## libre on retombe sur les vues cardinales, sans traîner l'écart de la souris.
func _quart_de_tour(sens: float) -> void:
	_ancre_active = false
	if sens > 0.0:
		lacet = (floorf(lacet / 90.0) + 1.0) * 90.0
	else:
		lacet = (ceilf(lacet / 90.0) - 1.0) * 90.0


func _sol(pos: Vector2) -> Vector3:
	var origine := camera.project_ray_origin(pos)
	var direction := camera.project_ray_normal(pos)
	return origine - direction * (origine.y / direction.y)


func _accrocher() -> void:
	position += _ancre - _sol(_ancre_ecran)


func _annuler_geste() -> void:
	_appui = false
	_glisse = false
	_orbite = false
	_ancre_active = false
	_zoom_actif = false
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)


func _notification(quoi: int) -> void:
	if quoi == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		_annuler_geste()
		lacet = _lacet_vu
		hauteur = _hauteur_vu


# Une prise commencée sur le sol se termine même au-dessus d'un panneau.
func _input(e: InputEvent) -> void:
	if not _appui:
		return
	if e is InputEventMouseMotion:
		var m := e as InputEventMouseMotion
		if not (m.button_mask & MOUSE_BUTTON_MASK_LEFT):
			_annuler_geste()
			return
		_glisse = _glisse or m.position.distance_to(_depart) >= SEUIL_GLISSE
		if _orbite:
			lacet -= m.relative.x * SENS_ORBITE
			hauteur = clampf(hauteur - m.relative.y * SENS_ORBITE, HAUTEUR_MIN, HAUTEUR_MAX)
		elif _glisse:
			_ancre_ecran = m.position
			_accrocher()
		get_viewport().set_input_as_handled()
	elif e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT and not e.pressed:
		var clic: bool = not _orbite and not _glisse and not e.ctrl_pressed \
			and e.position.distance_to(_depart) < SEUIL_GLISSE
		_appui = false
		_glisse = false
		_orbite = false
		Input.set_default_cursor_shape(Input.CURSOR_ARROW)
		get_viewport().set_input_as_handled()
		if clic and get_viewport().gui_get_hovered_control() == null:
			clic_sol.emit(e.position)


func remettre_nord() -> void:
	_annuler_geste()
	lacet = _lacet_vu + wrapf(-_lacet_vu, -180.0, 180.0)


func basculer_dessus() -> void:
	_annuler_geste()
	if hauteur >= HAUTEUR_MAX - 0.5:
		hauteur = _hauteur_avant
	else:
		_hauteur_avant = hauteur
		hauteur = HAUTEUR_MAX


func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventMouseButton:
		# Les panneaux peuvent transmettre la molette même avec MOUSE_FILTER_STOP.
		if get_viewport().gui_get_hovered_control() != null:
			return
		var b := e as InputEventMouseButton
		if b.pressed and b.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN] and not _appui:
			_ancre_ecran = b.position
			_ancre = _sol(b.position)
			_ancre_active = true
			if not _zoom_actif:
				_taille_cible = taille
			var sens := 1.0 if b.button_index == MOUSE_BUTTON_WHEEL_UP else -1.0
			_taille_cible = clampf(_taille_cible * pow(0.88, sens * b.factor), TAILLE_MIN, TAILLE_MAX)
			_zoom_actif = true
			get_viewport().set_input_as_handled()
		elif b.button_index == MOUSE_BUTTON_LEFT and b.pressed:
			caler(_lacet_vu, _hauteur_vu)
			_appui = true
			_orbite = b.ctrl_pressed
			_depart = b.position
			_ancre_ecran = b.position
			_ancre = _sol(b.position)
			_ancre_active = true
			Input.set_default_cursor_shape(Input.CURSOR_DRAG)
			get_viewport().set_input_as_handled()
	elif e is InputEventKey and (e as InputEventKey).pressed \
			and not (e as InputEventKey).echo:
		match (e as InputEventKey).keycode:
			KEY_Q: _quart_de_tour(1.0)
			KEY_E: _quart_de_tour(-1.0)
			KEY_LEFT:
				_ancre_active = false
				lacet += CRAN_LACET
			KEY_RIGHT:
				_ancre_active = false
				lacet -= CRAN_LACET
			KEY_UP:
				_ancre_active = false
				hauteur = clampf(hauteur + CRAN_HAUTEUR, HAUTEUR_MIN, HAUTEUR_MAX)
			KEY_DOWN:
				_ancre_active = false
				hauteur = clampf(hauteur - CRAN_HAUTEUR, HAUTEUR_MIN, HAUTEUR_MAX)
			KEY_T: basculer_dessus()
