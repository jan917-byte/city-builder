extends Node3D
# Caméra ORTHOGRAPHIQUE : zoom, panoramique, et — depuis le 2026-08-17 —
# ORBITE : lacet libre sur 360°, hauteur du regard réglable de 6° à 90°.
#
# 🔄 RETOUR EN ARRIÈRE SIGNALÉ (§3 ter). Ce fichier interdisait explicitement
# l'orbite : « C'est l'ORBITE LIBRE qui romprait la coupe, en amenant l'œil au
# niveau de la rue — d'où son absence ici. » L'auteur a demandé le contraire le
# 2026-08-17 : voir la ville sous tous ses angles. Ce qui suit dit ce qui est
# préservé et ce qui ne l'est plus, pour qu'on n'ait pas à le redécouvrir.
#
# CE QUI EST PRÉSERVÉ, ET C'EST L'ESSENTIEL — l'ORTHOGRAPHIE.
# Elle est exigée par deux des trois critères de réussite (`Plan 3 mois.md:48`) :
#   · « la barre de 1974 comme un objet aberrant de 9 niveaux au milieu de
#     rangées à 3 » — en ortho, 27 m projettent 3× plus que 9 m OÙ QUE SOIT
#     l'objet dans le cadre. En perspective, la barre au fond paraîtrait normale.
#     🔄 2026-08-19 : la barre est descendue à 6 niveaux et il y en a trois
#     (`04`, `04c`). L'argument sur l'ortho ne bouge pas — il porte sur le
#     RAPPORT des hauteurs, et 16,2 m contre 8,1 m se lisent encore. Ce qui
#     bouge est le critère du vault, qui dit toujours 9 : à l'auteur de
#     trancher s'il le réécrit ou s'il annule la baisse.
#   · « trouver monstrueuses les rues à 20 et 22 m » — idem pour les largeurs.
# Et « s'approcher » en orthographie, c'est réduire `size`, pas avancer. La coupe
# de `Périmètre et coupes.md:42` (« caméra axonométrique fixe → élimine le LOD et
# la question des façades ») reste donc prise POUR LE LOD : l'œil ne se rapproche
# jamais, aucune distance n'existe, rien ne peut se simplifier au loin.
#
# CE QUI NE L'EST PLUS, ET QUI EST LE PRIX À PAYER : sous ~15° de hauteur, on
# regarde la ville par ses FAÇADES, et les façades sont des murs nus d'une seule
# teinte (`README.md`, « ce que la maquette ne montre pas »). L'angle bas n'est
# donc pas un point de vue de jeu — c'est un point de vue de contrôle, bon pour
# juger une silhouette et des hauteurs, mauvais pour juger un quartier. Le plancher
# à 6° existe pour qu'il reste possible sans devenir la vue par défaut.
#
# LES GESTES
#   molette                zoom
#   clic droit glissé      tourner autour de la ville (lacet + hauteur)
#   clic milieu glissé     déplacer  (maj + clic droit fait la même chose)
#   Q / E                  quart de tour, recalé sur les multiples de 90°
#   flèches ← →            lacet par crans de 15°
#   flèches ↑ ↓            hauteur du regard par crans de 8°
#   T                      bascule vue de dessus ⇄ hauteur précédente

signal vue_changee(lacet: float, hauteur: float)

const HAUTEUR_DEFAUT := 32.0   # l'angle historique : il reste celui du démarrage
const HAUTEUR_MIN := 6.0       # sous 15° on regarde des façades nues, voir en-tête
const HAUTEUR_MAX := 90.0      # à pic
const RECUL := 1500.0          # en ortho, ce qui est derrière la caméra est clippé
const TAILLE_MIN := 40.0
const TAILLE_MAX := 1600.0

const CRAN_LACET := 15.0
const CRAN_HAUTEUR := 8.0
const SENS_ORBITE := 0.30      # degrés par pixel de souris
const SUIVI := 18.0            # rattrapage de l'angle affiché, par seconde

var camera: Camera3D
var taille := 1200.0

# CIBLES, pas valeurs affichées. `lacet` n'est volontairement PAS ramené dans
# [0, 360[ : laisser Q/E l'accumuler évite tout saut de 359° → 0° pendant
# l'interpolation. cos/sin s'en moquent, et l'affichage normalise lui-même.
var lacet := 30.0
var hauteur := HAUTEUR_DEFAUT

var _lacet_vu := 30.0
var _hauteur_vu := HAUTEUR_DEFAUT
var _glisse := false
var _orbite := false
var _hauteur_avant := HAUTEUR_DEFAUT


func _ready() -> void:
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.near = 0.05
	camera.far = 4000.0
	camera.position = Vector3(0.0, 0.0, RECUL)
	add_child(camera)
	_appliquer()


func _process(delta: float) -> void:
	# Interpolation exponentielle : indépendante du framerate, et sans elle un
	# quart de tour est une téléportation dont on ressort désorienté — c'est
	# exactement ce qu'on voulait éviter en ouvrant la caméra.
	if is_equal_approx(_lacet_vu, lacet) and is_equal_approx(_hauteur_vu, hauteur):
		return
	var k: float = 1.0 - exp(-SUIVI * delta)
	_lacet_vu = lerpf(_lacet_vu, lacet, k)
	_hauteur_vu = lerpf(_hauteur_vu, hauteur, k)
	if absf(_lacet_vu - lacet) < 0.02:
		_lacet_vu = lacet
	if absf(_hauteur_vu - hauteur) < 0.02:
		_hauteur_vu = hauteur
	_appliquer()


func _appliquer() -> void:
	# ⚠️ `taille` n'est PAS passée telle quelle à la caméra, et c'est le seul
	# endroit du fichier qui mérite d'être lu deux fois.
	#
	# En orthographie, la profondeur de sol visible vaut `size / sin(hauteur)` :
	# à 10° la ville de 1 084 m ne projette plus que 188 m et se recroqueville
	# en une bande au milieu d'un écran vide — mesuré à la première capture.
	# En multipliant par `sin(hauteur)`, la QUANTITÉ DE SOL visible devient
	# indépendante de l'angle : tourner autour de la ville ne la fait plus ni
	# grossir ni fondre. Le rapport à sin(32°) garde la vue par défaut EXACTEMENT
	# telle qu'elle était avant le 2026-08-17 — un repère qui bouge n'est plus
	# un repère.
	#
	# Ce qui grandit, en revanche, c'est la hauteur des bâtiments à l'écran : un
	# mur projette sa hauteur entière quel que soit l'angle. C'est précisément ce
	# qu'on vient chercher en descendant le regard.
	camera.size = taille * sin(deg_to_rad(_hauteur_vu)) / sin(deg_to_rad(HAUTEUR_DEFAUT))
	rotation_degrees = Vector3(-_hauteur_vu, _lacet_vu, 0.0)
	vue_changee.emit(_lacet_vu, _hauteur_vu)


func viser(cible: Vector2, t: float) -> void:
	# Un repère de clavier (V B R I) recadre et rezoome, mais ne redresse JAMAIS
	# l'angle : sinon regarder la barre depuis l'ouest serait impossible.
	position = Vector3(cible.x, position.y, cible.y)
	taille = clampf(t, TAILLE_MIN, TAILLE_MAX)
	_appliquer()


## Pose l'angle SANS interpolation. Réservé aux captures automatiques : une
## passe `--essai` n'attend pas que la caméra ait fini de tourner.
func caler(l: float, h: float) -> void:
	lacet = l
	hauteur = clampf(h, HAUTEUR_MIN, HAUTEUR_MAX)
	_lacet_vu = lacet
	_hauteur_vu = hauteur
	_appliquer()


## Recale sur le multiple de 90° suivant (ou précédent) plutôt que d'ajouter 90 :
## après une orbite libre on retombe sur les quatre vues cardinales, au lieu de
## traîner l'écart pris à la souris.
func _quart_de_tour(sens: float) -> void:
	if sens > 0.0:
		lacet = (floorf(lacet / 90.0) + 1.0) * 90.0
	else:
		lacet = (ceilf(lacet / 90.0) - 1.0) * 90.0


func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventMouseButton:
		var b := e as InputEventMouseButton
		if b.button_index == MOUSE_BUTTON_WHEEL_UP and b.pressed:
			taille = clampf(taille * 0.88, TAILLE_MIN, TAILLE_MAX)
			_appliquer()
		elif b.button_index == MOUSE_BUTTON_WHEEL_DOWN and b.pressed:
			taille = clampf(taille / 0.88, TAILLE_MIN, TAILLE_MAX)
			_appliquer()
		elif b.button_index == MOUSE_BUTTON_MIDDLE:
			_glisse = b.pressed
		elif b.button_index == MOUSE_BUTTON_RIGHT:
			# 🔄 Le clic droit déplaçait la vue jusqu'au 2026-08-17. Il tourne
			# maintenant, et le panoramique garde deux entrées : le clic milieu,
			# et maj + clic droit pour les souris qui n'ont pas de molette
			# cliquable.
			_orbite = b.pressed and not b.shift_pressed
			_glisse = b.pressed and b.shift_pressed
	elif e is InputEventMouseMotion:
		var m := e as InputEventMouseMotion
		if _orbite:
			lacet -= m.relative.x * SENS_ORBITE
			hauteur = clampf(hauteur - m.relative.y * SENS_ORBITE,
				HAUTEUR_MIN, HAUTEUR_MAX)
		elif _glisse:
			_deplacer(m.relative)
	elif e is InputEventKey and (e as InputEventKey).pressed \
			and not (e as InputEventKey).echo:
		match (e as InputEventKey).keycode:
			KEY_Q: _quart_de_tour(1.0)
			KEY_E: _quart_de_tour(-1.0)
			KEY_LEFT: lacet += CRAN_LACET
			KEY_RIGHT: lacet -= CRAN_LACET
			KEY_UP:
				hauteur = clampf(hauteur + CRAN_HAUTEUR, HAUTEUR_MIN, HAUTEUR_MAX)
			KEY_DOWN:
				hauteur = clampf(hauteur - CRAN_HAUTEUR, HAUTEUR_MIN, HAUTEUR_MAX)
			KEY_T:
				if hauteur >= HAUTEUR_MAX - 0.5:
					hauteur = _hauteur_avant
				else:
					_hauteur_avant = hauteur
					hauteur = HAUTEUR_MAX


func _deplacer(rel: Vector2) -> void:
	# Le panoramique suit le lacet AFFICHÉ : glisser vers la droite décale la
	# ville vers la droite, quel que soit l'angle courant.
	# ⚠️ `camera.size`, PAS `taille` : depuis la compensation d'angle les deux ne
	# sont plus égales, et se tromper de nombre fait glisser la ville trois fois
	# trop vite dès qu'on descend le regard.
	var k: float = camera.size / 900.0
	var a: float = deg_to_rad(_lacet_vu)
	var dx: float = -rel.x * k
	# 1/sin convertit un déplacement à l'écran en déplacement au SOL : plus le
	# regard est rasant, plus un pixel couvre de mètres. Combiné à la
	# compensation de `_appliquer`, le sinus s'annule — la ville suit le curseur
	# à la même vitesse à 6° comme à 90°. Aucun garde-fou nécessaire : la hauteur
	# ne descend jamais à 0, où la division exploserait.
	var dz: float = -rel.y * k / sin(deg_to_rad(_hauteur_vu))
	position += Vector3(dx * cos(a) + dz * sin(a), 0.0,
		-dx * sin(a) + dz * cos(a))
