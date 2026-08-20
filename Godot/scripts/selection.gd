extends Node
# Le clic : rend un couple (couche, fid) et ne sait rien de la ville.
#
# Le raycast marche en orthographique — `project_ray_origin` y rend un point sur
# le plan de la caméra. Les corps viennent de `create_trimesh_collision()`, un
# par objet : d'où un nœud par îlot et par tronçon.

signal survole(couche: String, fid: int)
signal choisi(couche: String, fid: int)

const PORTEE := 6000.0     # la caméra recule de 1500 et voit loin

var camera: Camera3D

var survol_couche := ""
var survol_fid := -1
var sel_couche := ""
var sel_fid := -1


func _process(_delta: float) -> void:
	if camera == null:
		return
	var r := sonder(camera.get_viewport().get_mouse_position())
	if r[0] != survol_couche or r[1] != survol_fid:
		survol_couche = r[0]
		survol_fid = r[1]
		survole.emit(survol_couche, survol_fid)


func _unhandled_input(e: InputEvent) -> void:
	if not (e is InputEventMouseButton):
		return
	var b := e as InputEventMouseButton
	if b.button_index != MOUSE_BUTTON_LEFT or not b.pressed:
		return
	var r := sonder(b.position)
	sel_couche = r[0]
	sel_fid = r[1]
	choisi.emit(sel_couche, sel_fid)


func sonder(pos: Vector2) -> Array:
	var espace := camera.get_world_3d().direct_space_state
	var p := PhysicsRayQueryParameters3D.create(
		camera.project_ray_origin(pos),
		camera.project_ray_origin(pos) + camera.project_ray_normal(pos) * PORTEE)
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
