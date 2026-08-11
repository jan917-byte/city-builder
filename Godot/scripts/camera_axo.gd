extends Node3D
# Caméra ORTHOGRAPHIQUE, angle fixe, zoom + panoramique + rotations à 90°.
#
# L'orthographie n'est pas un choix esthétique, elle est exigée par deux des
# trois critères de réussite (`Plan 3 mois.md:48`) :
#
#   · « la barre de 1974 comme un objet aberrant de 9 niveaux au milieu de
#     rangées à 3 » — en ortho, 27 m projettent 3× plus que 9 m OÙ QUE SOIT
#     l'objet dans le cadre. En perspective, la barre au fond paraîtrait
#     normale.
#   · « trouver monstrueuses les rues à 20 et 22 m » — idem pour les largeurs.
#
# Et « s'approcher » en orthographie, c'est réduire `size`, pas avancer : le
# zoom ne réintroduit ni LOD ni façades. La coupe de `Périmètre et coupes.md:42`
# (« caméra axonométrique fixe → élimine le LOD et la question des façades »)
# reste donc entièrement prise. C'est l'ORBITE LIBRE qui la romprait, en
# amenant l'œil au niveau de la rue — d'où son absence ici.

const ELEVATION := 32.0        # degrés au-dessus de l'horizon, jamais modifiés
const RECUL := 1500.0          # en ortho, ce qui est derrière la caméra est clippé
const TAILLE_MIN := 40.0
const TAILLE_MAX := 1600.0

var camera: Camera3D
var taille := 1200.0
var lacet := 30.0
var _glisse := false


func _ready() -> void:
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.near = 0.05
	camera.far = 4000.0
	camera.position = Vector3(0.0, 0.0, RECUL)
	add_child(camera)
	_appliquer()


func _appliquer() -> void:
	camera.size = taille
	rotation_degrees = Vector3(-ELEVATION, lacet, 0.0)


func viser(cible: Vector2, t: float) -> void:
	position = Vector3(cible.x, position.y, cible.y)
	taille = clampf(t, TAILLE_MIN, TAILLE_MAX)
	_appliquer()


func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventMouseButton:
		var b := e as InputEventMouseButton
		if b.button_index == MOUSE_BUTTON_WHEEL_UP and b.pressed:
			taille = clampf(taille * 0.88, TAILLE_MIN, TAILLE_MAX)
			_appliquer()
		elif b.button_index == MOUSE_BUTTON_WHEEL_DOWN and b.pressed:
			taille = clampf(taille / 0.88, TAILLE_MIN, TAILLE_MAX)
			_appliquer()
		elif b.button_index in [MOUSE_BUTTON_MIDDLE, MOUSE_BUTTON_RIGHT]:
			_glisse = b.pressed
	elif e is InputEventMouseMotion and _glisse:
		# Le panoramique suit le lacet : glisser vers la droite décale la
		# ville vers la droite, quel que soit l'angle courant.
		var m := e as InputEventMouseMotion
		var k: float = taille / 900.0
		var a: float = deg_to_rad(lacet)
		var dx: float = -m.relative.x * k
		var dz: float = -m.relative.y * k / sin(deg_to_rad(ELEVATION))
		position += Vector3(dx * cos(a) + dz * sin(a), 0.0,
			-dx * sin(a) + dz * cos(a))
	elif e is InputEventKey and (e as InputEventKey).pressed \
			and not (e as InputEventKey).echo:
		match (e as InputEventKey).keycode:
			KEY_Q:
				lacet = fmod(lacet + 90.0, 360.0)
				_appliquer()
			KEY_E:
				lacet = fmod(lacet - 90.0 + 360.0, 360.0)
				_appliquer()
