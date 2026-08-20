extends SceneTree
# Sonde d'API — à lancer AVANT d'écrire quoi que ce soit d'autre.
#
#   Godot_..._console.exe --headless --path <Godot/> --script res://outils/sonde_api.gd
#
# `Moteur et architecture.md:32` interdit de vibe-coder du GDScript (pollution
# des API Godot 3 → 4). On fait donc vérifier les signatures par ClassDB, avec
# sortie ≠ 0 au premier manque.
#
# Canari, pas garantie : l'ordre des arguments, le sens d'enroulement et
# l'espace colorimétrique se mesurent à l'écran.

const METHODES := {
	"ArrayMesh": ["add_surface_from_arrays", "surface_get_array_len"],
	"MultiMesh": ["set_instance_transform", "set_instance_color"],
	"Camera3D": ["set_orthogonal", "project_ray_origin"],
	"Image": ["save_png"],
	"FileAccess": [],
}

const PROPRIETES := {
	"StandardMaterial3D": ["vertex_color_use_as_albedo", "albedo_color",
		"cull_mode", "roughness", "metallic", "shading_mode"],
	"Camera3D": ["projection", "size", "near", "far"],
	"Environment": ["ssao_enabled", "ssao_radius", "ssao_intensity",
		"ambient_light_source", "ambient_light_color", "ambient_light_energy",
		"background_mode", "background_color"],
	"DirectionalLight3D": ["directional_shadow_max_distance", "light_energy",
		"light_color", "shadow_enabled"],
	"MultiMesh": ["transform_format", "use_colors", "instance_count", "mesh"],
	"MeshInstance3D": ["mesh", "material_override"],
	"MultiMeshInstance3D": ["multimesh"],
}

# Un mauvais nom passerait la compilation et casserait au rendu.
const ENUMS := {
	"Mesh.ARRAY_MAX": Mesh.ARRAY_MAX,
	"Mesh.ARRAY_VERTEX": Mesh.ARRAY_VERTEX,
	"Mesh.ARRAY_NORMAL": Mesh.ARRAY_NORMAL,
	"Mesh.ARRAY_COLOR": Mesh.ARRAY_COLOR,
	"Mesh.ARRAY_INDEX": Mesh.ARRAY_INDEX,
	"Mesh.PRIMITIVE_TRIANGLES": Mesh.PRIMITIVE_TRIANGLES,
}


func _init() -> void:
	var manques := 0

	for cls in METHODES:
		if not ClassDB.class_exists(cls):
			push_error("MANQUE  classe %s" % cls)
			manques += 1
			continue
		for m in METHODES[cls]:
			if not ClassDB.class_has_method(cls, m):
				push_error("MANQUE  %s.%s()" % [cls, m])
				manques += 1

	for cls in PROPRIETES:
		if not ClassDB.class_exists(cls):
			push_error("MANQUE  classe %s" % cls)
			manques += 1
			continue
		var noms := {}
		for p in ClassDB.class_get_property_list(cls):
			noms[p["name"]] = true
		for p in PROPRIETES[cls]:
			if not noms.has(p):
				push_error("MANQUE  %s.%s" % [cls, p])
				manques += 1

	for e in ENUMS:
		print("  %-32s = %s" % [e, ENUMS[e]])

	# Le contrat qui compte le plus : un ArrayMesh vraiment construit.
	var essai := _essai_array_mesh()
	if essai != "":
		push_error("MANQUE  ArrayMesh : %s" % essai)
		manques += 1

	print("sonde : %d manque(s) sur Godot %s" % [manques,
		Engine.get_version_info()["string"]])
	quit(1 if manques > 0 else 0)


func _essai_array_mesh() -> String:
	# Exactement les tableaux que le constructeur utilisera.
	var v := PackedVector3Array([Vector3(0, 0, 0), Vector3(1, 0, 0), Vector3(0, 0, 1)])
	var n := PackedVector3Array([Vector3.UP, Vector3.UP, Vector3.UP])
	var c := PackedColorArray([Color.RED, Color.RED, Color.RED])
	var idx := PackedInt32Array([0, 1, 2])

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)          # obligatoire AVANT d'indexer
	arrays[Mesh.ARRAY_VERTEX] = v
	arrays[Mesh.ARRAY_NORMAL] = n
	arrays[Mesh.ARRAY_COLOR] = c
	arrays[Mesh.ARRAY_INDEX] = idx

	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	if m.get_surface_count() != 1:
		return "aucune surface creee"
	if m.surface_get_array_len(0) != 3:
		return "surface a %d sommets au lieu de 3" % m.surface_get_array_len(0)
	return ""
