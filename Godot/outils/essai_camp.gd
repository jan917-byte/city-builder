extends SceneTree
## Sans --headless : le pilote factice ne conserve pas les matrices MultiMesh.
## Vérifie le repère source (Y nord) → Godot (Z sud) sur le vrai MultiMesh.
func _initialize() -> void:
	var donnees: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/wehrau.json"))
	var camp = preload("res://scripts/camp.gd").new()
	root.add_child(camp)
	camp.batir(donnees)
	var erreurs := 0
	for fid in [1082, 1083, 1084]:
		var mm: MultiMesh = camp.maillage_champ(fid, camp.places(fid))
		for k in mm.instance_count:
			var g: float = camp._places[fid][k][3]
			var attendu := Vector3(cos(g), 0, -sin(g))
			if mm.get_instance_transform(k).basis.x.distance_to(attendu) > 0.001:
				erreurs += 1
		if mm.mesh.surface_get_material(0) == null:
			erreurs += 1
	print("CONTAINERS : %d erreur(s), orientation et matière des trois camps" % erreurs)
	quit(1 if erreurs else 0)
