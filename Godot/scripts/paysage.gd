extends Node3D
## Le décor extérieur ne porte ni sélection ni données de simulation.
const Constructeur := preload("res://scripts/constructeur.gd")
const Materiaux := preload("res://scripts/materiaux.gd")
var mat_nuages: ShaderMaterial
# Un arbre de forêt pousse en peuplement : plus haut qu'un pommier, et sa
# couronne s'étale pour fermer le couvert, sinon le bois se lit en savane.
const FORET_ECHELLE := 1.4
const FORET_LARGEUR := 1.45
const FORET_TUILE := 600.0

## `mat_rue` : le matériau des rues de la ville, pour que la sortie les continue sans changer de teinte.
func batir(d: Dictionary, palette: Dictionary, mat_rue: Material) -> void:
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/paysage.gdshader")
	mat.set_shader_parameter("demi_emprise", Vector2(d.demi_emprise[0], d.demi_emprise[1]))
	_maille("Versants", d.sol, mat)
	if d.has("sorties"):
		_maille("AccotementsSorties", d.sorties.accotements, mat)
		_maille("RoutesSorties", d.sorties.sol, mat_rue)
		if d.sorties.has("marquage"):
			_maille("MarquageSorties", d.sorties.marquage, mat_rue)
	if d.has("fermes"):
		_maille("CheminsFermes", d.fermes.sol, mat_rue)
		_maille("Fermes", d.fermes.bati, mat_rue).cast_shadow = 			GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	var eau := Materiaux.eau(palette)
	eau.set_shader_parameter("brume_exterieure", Vector2(d.demi_emprise[0], d.demi_emprise[1]))
	_maille("IlseExterieure", d.eau, eau)
	# 🌳 La forêt est plantée des RECETTES DE LA VILLE (`Constructeur.arbre`),
	# en plus léger : un bois et un jardin sont le même monde. Feuillu, sapin,
	# peuplier : l'essence et la teinte du peuplement (6e nombre) sont posées
	# par `repartir` dans paysage.py.
	var demi := Vector2(d.demi_emprise[0], d.demi_emprise[1])
	var vert := Color(palette["_feuillage"]).srgb_to_linear()
	var brun := Color(palette["_tronc"])
	# Les valeurs de la ville (`maquette.gd`, VALEUR_ESSENCE), un cran plus
	# sombres : un bois se lit en masse.
	var teintes := [vert * 0.56, Color(vert.r * 0.42, vert.g * 0.50, vert.b * 0.47),
		vert * 0.54]
	var essences := [Constructeur.FEUILLU, Constructeur.CONIFERE, Constructeur.PEUPLIER]
	for k in (d.arbres as Array).size():
		var mesh := Constructeur.arbre(essences[k], brun, demi)
		# Un lot par TUILE et non un pour toute la vallée : un MultiMesh ne se
		# découpe pas à l'écran, et de près on dessinait la forêt entière.
		var tuiles := {}
		for a in d.arbres[k]:
			var cle := Vector2i(floori(float(a[0]) / FORET_TUILE),
				floori(float(a[2]) / FORET_TUILE))
			if not tuiles.has(cle):
				tuiles[cle] = []
			(tuiles[cle] as Array).append(a)
		for cle in tuiles:
			var liste: Array = tuiles[cle]
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.use_colors = true
			mm.mesh = mesh
			mm.instance_count = liste.size()
			for j in mm.instance_count:
				var a: Array = (liste[j] as Array).duplicate()
				a[3] = float(a[3]) * FORET_ECHELLE
				var t := Constructeur.pose(a, essences[k])
				if essences[k] == Constructeur.FEUILLU:
					t.basis = t.basis * Basis.from_scale(
						Vector3(FORET_LARGEUR, 1.0, FORET_LARGEUR))
				mm.set_instance_transform(j, t)
				var f: float = float(a[5]) if a.size() > 5 else 0.85 + fmod(a[4], 1.0) * 0.3
				mm.set_instance_color(j, (teintes[k] as Color) * f)
			# ⚠️ Sans `material_override` : la couronne et le tronc portent
			# chacun le leur, sinon le tronc ressort vert.
			_instances("Foret%d_%d_%d" % [k, cle.x, cle.y], mm, null)
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


func _maille(nom: String, d: Dictionary, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = nom
	mi.mesh = Constructeur.maillage(d)
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi

func _instances(nom: String, mm: MultiMesh, mat: Material) -> MultiMeshInstance3D:
	var mi := MultiMeshInstance3D.new()
	mi.name = nom
	mi.multimesh = mm
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi
