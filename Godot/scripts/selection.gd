extends Node
# Le clic : rend un couple (couche, fid) et ne sait rien de la ville.
#
# Les corps viennent de `create_trimesh_collision()`, un par objet : d'où un
# nœud par îlot et par tronçon.

signal survole(couche: String, fid: int)
signal choisi(couche: String, fid: int)

var camera: Camera3D

var survol_couche := ""
var survol_fid := -1
var sel_couche := ""
var sel_fid := -1
## Les pictogrammes posés au-dessus d'un objet, couche -> {fid: Sprite3D} : vus
## par-dessus les toits (`no_depth_test`), ils passent donc avant le rayon.
var icones := {}


func _process(_delta: float) -> void:
	if camera == null:
		return
	var r := sonder(camera.get_viewport().get_mouse_position())
	if r[0] != survol_couche or r[1] != survol_fid:
		survol_couche = r[0]
		survol_fid = r[1]
		survole.emit(survol_couche, survol_fid)


func choisir(pos: Vector2) -> void:
	var r := sonder(pos)
	sel_couche = r[0]
	sel_fid = r[1]
	choisi.emit(sel_couche, sel_fid)


func sonder(pos: Vector2) -> Array:
	var icone := _sonder_icones(pos)
	if not icone.is_empty():
		return icone
	var espace := camera.get_world_3d().direct_space_state
	var p := PhysicsRayQueryParameters3D.create(
		camera.project_ray_origin(pos),
		camera.project_ray_origin(pos) + camera.project_ray_normal(pos) * camera.far)
	var touche := espace.intersect_ray(p)
	if touche.is_empty():
		return ["", -1]
	# Le corps est un ENFANT du MeshInstance3D : c'est lui qui porte le fid.
	var n: Node = touche["collider"]
	while n != null and not n.has_meta("fid"):
		n = n.get_parent()
	if n == null:
		return ["", -1]
	return [str(n.get_meta("couche")), int(n.get_meta("fid"))]


## Le disque du pictogramme, mesuré à l'écran : rayon 15 sur 32 (`Pastilles.pictogramme`).
func _sonder_icones(pos: Vector2) -> Array:
	for couche in icones:
		for fid in icones[couche]:
			var s: Sprite3D = icones[couche][fid]
			if s == null or not s.is_visible_in_tree() or s.texture == null \
					or camera.is_position_behind(s.global_position):
				continue
			var centre := camera.unproject_position(s.global_position)
			var bord := camera.unproject_position(s.global_position
				+ camera.global_basis.x * s.pixel_size * s.texture.get_width() * 15.0 / 32.0)
			if pos.distance_to(centre) <= centre.distance_to(bord):
				return [couche, int(fid)]
	return []
