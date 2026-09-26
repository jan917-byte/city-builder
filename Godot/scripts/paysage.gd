extends Node3D
## Le décor extérieur ne porte ni sélection ni données de simulation.
const Constructeur := preload("res://scripts/constructeur.gd")
const Materiaux := preload("res://scripts/materiaux.gd")
var mat_nuages: ShaderMaterial

## `mat_rue` : le matériau des rues de la ville, pour que la sortie les continue sans changer de teinte.
func batir(d: Dictionary, teinte_eau: Color, mat_rue: Material) -> void:
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/paysage.gdshader")
	mat.set_shader_parameter("demi_emprise", Vector2(d.demi_emprise[0], d.demi_emprise[1]))
	_maille("Versants", d.sol, mat)
	if d.has("sorties"):
		_maille("AccotementsSorties", d.sorties.accotements, mat)
		_maille("RoutesSorties", d.sorties.sol, mat_rue)
		if d.sorties.has("marquage"):
			_maille("MarquageSorties", d.sorties.marquage, mat_rue)
	var eau := Materiaux.eau(teinte_eau)
	eau.set_shader_parameter("brume_exterieure", Vector2(d.demi_emprise[0], d.demi_emprise[1]))
	_maille("IlseExterieure", d.eau, eau)
	var feuillage := mat.duplicate() as ShaderMaterial
	feuillage.set_shader_parameter("arbres", true)
	# Feuillu, sapin, peuplier : l'essence et la teinte du peuplement (6e
	# nombre) sont posées par `repartir` dans paysage.py.
	var teintes := [Color("496640"), Color("304e41"), Color("587246")]
	for essence in (d.arbres as Array).size():
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = Constructeur.maillage(d.modeles[essence])
		mm.instance_count = d.arbres[essence].size()
		for k in mm.instance_count:
			var a: Array = d.arbres[essence][k]
			var b := Basis(Vector3.UP, a[4]).scaled(Vector3.ONE * a[3])
			mm.set_instance_transform(k, Transform3D(b, Vector3(a[0], a[1], a[2])))
			var f: float = float(a[5]) if a.size() > 5 else 0.85 + fmod(a[4], 1.0) * 0.3
			mm.set_instance_color(k, (teintes[essence] as Color).srgb_to_linear() * f)
		_instances("Foret%d" % essence, mm, feuillage)
	mat_nuages = ShaderMaterial.new()
	mat_nuages.shader = preload("res://shaders/nuages.gdshader")
	mat_nuages.set_shader_parameter("demi_emprise", Vector2(d.demi_emprise[0], d.demi_emprise[1]))
	var nuages := MultiMesh.new()
	nuages.transform_format = MultiMesh.TRANSFORM_3D
	nuages.use_custom_data = true
	nuages.mesh = Constructeur.maillage(d.nuage)
	nuages.instance_count = d.nuages.size()
	for k in nuages.instance_count:
		var n: Array = d.nuages[k]
		var b := Basis(Vector3.UP, float(n[5]) * TAU).scaled(
			Vector3(n[3], float(n[3]) * 0.42, float(n[3]) * 0.55))
		nuages.set_instance_transform(k, Transform3D(b, Vector3(n[0], n[1], n[2])))
		nuages.set_instance_custom_data(k, Color(n[5], 0, 0, 1))
	var bancs := _instances("Nuages", nuages, mat_nuages)
	bancs.extra_cull_margin = 800.0
	# L'ombre du banc sur le versant est ce qui dit son altitude, vu d'en haut.
	bancs.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON


func _maille(nom: String, d: Dictionary, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	mi.name = nom
	mi.mesh = Constructeur.maillage(d)
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)

func _instances(nom: String, mm: MultiMesh, mat: Material) -> MultiMeshInstance3D:
	var mi := MultiMeshInstance3D.new()
	mi.name = nom
	mi.multimesh = mm
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi
