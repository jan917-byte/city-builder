extends SubViewport
# 🔎 LA MINIATURE DE LA FICHE (décision 12) : l'objet choisi, seul, montré dans
# l'état qui SERA livré. La ville, elle, garde son état réel jusqu'à la fin du
# chantier — c'est tout le partage entre les deux images.
#
# 🔴 AUCUNE GÉOMÉTRIE N'EST RECRÉÉE : les maillages sont CEUX de la ville,
# repris par référence, avec le même matériau et les mêmes uniformes
# d'instance. Une vignette dessinée à part mentirait dès la recette suivante.
#
# Son monde est à lui (`own_world_3d`) : ni ville autour, ni thème, ni contour.

const Materiaux := preload("res://scripts/materiaux.gd")

## Le format de la miniature dans la fiche : 320 px de panneau moins ses deux
## marges de 12 px. La fiche s'y accorde — elle lit cette constante.
const TAILLE := Vector2i(296, 168)
## 🔴 RENDUE TROIS FOIS PLUS GRANDE, puis réduite par la fiche. Les fenêtres et
## les rangs de tuiles sont des motifs qui s'effacent sous ~1,5 px : à 296 px de
## large, un étage fait 6 px et la façade sortait nue.
const SURECHANTILLON := 3
## Le lacet suit la caméra, la hauteur non : les panneaux sont sur les TOITS, et
## à 6° la miniature ne montrerait que des façades.
const HAUTEUR := 46.0
## 🔴 COURT, et c'est une contrainte d'OMBRE : la carte d'ombre part de la
## caméra, un recul de 900 m mettait l'objet hors de sa portée et la miniature
## n'avait aucune ombre portée. En ortho, reculer ne change rien à l'image.
const RECUL := 60.0
const MARGE := 1.15      # l'objet ne touche pas le bord du cadre
## 🔴 CE QUE LE CADRE MONTRE AU PLUS, en mètres de large. Mesuré le 2026-08-26 :
## un îlot fait 110 m de diamètre à la médiane, 220 m au neuvième décile, et le
## plus long tronçon 221 m — tout ça tient. Au-delà, l'objet est montré par son
## MILIEU : une berge de 347 m cadrée en entier est un cheveu.
const CADRE_MAX_M := 240.0
## La plaque passe SOUS le sol dessiné par 07 : au-dessus elle le raye.
const SOUS_LE_SOL := -0.20

var _cam: Camera3D
var _sol: MeshInstance3D
var _objet: MeshInstance3D
var _futur: MeshInstance3D
var _lacet := 1.0e9      # aucun lacet réel : le premier appel cadre toujours
## Ce que le cadre doit contenir. Les points de la PLAQUE, montés au faîtage :
## les huit coins de la boîte englobante cadrent un îlot en biais sur sa
## diagonale, et l'objet ne remplit plus que la moitié du cadre.
var _points := PackedVector3Array()


func batir(mat_objet: Material, mineral: Color, ciel: Color, ambiant: Color,
		soleil: Color) -> void:
	size = TAILLE * SURECHANTILLON
	own_world_3d = true
	transparent_bg = true
	# 2× et non 4× : le suréchantillonnage fait déjà le plus gros du lissage.
	msaa_3d = Viewport.MSAA_2X
	# Rien à rendre tant que rien n'est choisi.
	render_target_update_mode = SubViewport.UPDATE_DISABLED

	var we := WorldEnvironment.new()
	we.environment = Materiaux.environnement(ciel, ambiant)
	# 🔴 SANS SSAO. Il travaille en espace vue : dans un cadre de 100 m son
	# rayon de 2 m couvre le tiers de l'image et noircit les façades entières.
	# L'occlusion bakée par 07 dans la couleur de sommet tient seule.
	we.environment.ssao_enabled = false
	add_child(we)
	# Le recul plus le cadre le plus large : juste de quoi couvrir l'objet, et
	# la carte d'ombre reste fine là où on la regarde.
	add_child(Materiaux.soleil(soleil, RECUL + 2.0 * CADRE_MAX_M))

	_cam = Camera3D.new()
	_cam.name = "CameraApercu"
	_cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	_cam.near = 0.05
	_cam.far = 4000.0
	add_child(_cam)

	# La plaque au sol. Le sol d'un îlot bâti n'est dessiné nulle part — c'est
	# le terrain qui passe dessous —, et sans elle l'objet flotte sur du vide.
	_sol = MeshInstance3D.new()
	_sol.name = "Plaque"
	_sol.position.y = SOUS_LE_SOL
	var m := Materiaux.surface()
	m.albedo_color = mineral
	_sol.material_override = m
	add_child(_sol)

	_objet = MeshInstance3D.new()
	_objet.name = "Objet"
	_objet.material_override = mat_objet
	add_child(_objet)

	# Le futur livré : la géométrie de reconstruction, celle-là même que la
	# ville découvrira à la fin du chantier.
	_futur = MeshInstance3D.new()
	_futur.name = "Futur"
	_futur.material_override = mat_objet
	add_child(_futur)

	# La miniature ne joue ni le thème, ni le calque, ni la sélection : elle
	# montre l'objet tel qu'il sera. Posé une fois, jamais repeint.
	for mi in [_objet, _futur]:
		mi.set_instance_shader_parameter("teinte", Color.WHITE)
		mi.set_instance_shader_parameter("calque", Color(1.0, 1.0, 1.0, 0.0))
		mi.set_instance_shader_parameter("maquette_blanche", 0.0)


## Change d'objet. `sol` peut être nul : une berge n'a pas d'emprise.
func montrer(objet: Mesh, futur: Mesh, sol: Mesh) -> void:
	_objet.mesh = objet
	_futur.mesh = futur
	_sol.mesh = sol
	render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_semer_points()
	_cadrer()


## Ce qui coûte est la vue à part : sans sélection, elle s'éteint entièrement.
func eteindre() -> void:
	if render_target_update_mode == SubViewport.UPDATE_DISABLED:
		return
	_objet.mesh = null
	_futur.mesh = null
	_sol.mesh = null
	render_target_update_mode = SubViewport.UPDATE_DISABLED


## La miniature tourne avec la ville : sans ça, l'objet du panneau ne ressemble
## plus à celui qu'on vient de cliquer à l'écran.
func viser(lacet: float) -> void:
	if absf(lacet - _lacet) < 0.05:
		return
	_lacet = lacet
	_cadrer()


## 🔴 L'EFFET INSTANTANÉ (décision 12) : ces trois nombres sont l'état VISÉ, pas
## l'état de la ville. `equipe` est la part de toit couverte, `futur` découvre
## la géométrie reconstruite, `berge` pousse les trois crans de la rive.
func regler(equipe: float, futur: bool, berge: float) -> void:
	_futur.visible = futur and _futur.mesh != null
	for mi in [_objet, _futur]:
		mi.set_instance_shader_parameter("equipe", equipe)
		mi.set_instance_shader_parameter("etat_berge", berge)


## Les points à contenir, calculés UNE FOIS par objet : le cadrage se refait à
## chaque quart de tour, il ne peut pas relire des milliers de sommets.
func _semer_points() -> void:
	_points = PackedVector3Array()
	if _objet.mesh == null:
		return
	var b: AABB = _objet.mesh.get_aabb()
	if _sol.mesh != null:
		b = b.merge((_sol.mesh as Mesh).get_aabb())
	if _futur.mesh != null:
		b = b.merge((_futur.mesh as Mesh).get_aabb())
	var bas := b.position.y
	var haut := b.position.y + b.size.y
	if _sol.mesh != null and _sol.mesh.get_surface_count() > 0:
		var som: PackedVector3Array = _sol.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		for v in som:
			_points.append(Vector3(v.x, bas, v.z))
			_points.append(Vector3(v.x, haut, v.z))
		return
	# Une berge n'a pas de plaque : ses huit coins font l'affaire.
	for k in 8:
		_points.append(b.get_endpoint(k))


func _cadrer() -> void:
	if _points.is_empty():
		return
	_cam.rotation_degrees = Vector3(-HAUTEUR, _lacet, 0.0)
	var base := _cam.transform.basis
	# Le centre est celui de l'IMAGE, pas celui du volume : un objet cadré sur
	# le milieu de sa boîte se décale dès qu'on le regarde en biais.
	var x0 := INF
	var x1 := -INF
	var y0 := INF
	var y1 := -INF
	var z1 := -INF
	for p in _points:
		var u := p.dot(base.x)
		var v := p.dot(base.y)
		x0 = minf(x0, u)
		x1 = maxf(x1, u)
		y0 = minf(y0, v)
		y1 = maxf(y1, v)
		z1 = maxf(z1, p.dot(base.z))
	_cam.position = base.x * ((x0 + x1) * 0.5) + base.y * ((y0 + y1) * 0.5) \
		+ base.z * (z1 + RECUL)
	# En ortho, `size` est la hauteur vue : la largeur en découle par le format.
	var format := float(TAILLE.x) / float(TAILLE.y)
	_cam.size = minf(maxf(y1 - y0, (x1 - x0) / format) * MARGE,
		CADRE_MAX_M / format)
