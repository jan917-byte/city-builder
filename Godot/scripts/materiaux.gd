extends RefCounted
# Cinq matériaux, zéro texture.
#
# « Aucune texture — la couleur est portée par le matériau. Un `sous_type` =
# une teinte. Rien à peindre, jamais. » (Direction artistique l.19)
#
# La couleur voyage dans ARRAY_COLOR, donc UN matériau suffit pour les 69
# îlots : c'est `vertex_color_use_as_albedo` qui fait tout le travail.


static func surface(rugosite: float = 0.95) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.albedo_color = Color.WHITE
	m.roughness = rugosite
	m.metallic = 0.0
	m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	# Le sens des faces est prouvé des deux côtés : 07 vérifie les NORMALES
	# (376/376 murs vers l'extérieur, 270/270 toits vers le haut) et émet les
	# sommets en sens horaire, la convention de face avant de Godot.
	m.cull_mode = BaseMaterial3D.CULL_BACK
	return m


static func eau(teinte: Color) -> StandardMaterial3D:
	var m := surface(0.25)
	m.vertex_color_use_as_albedo = false
	m.albedo_color = teinte
	m.metallic = 0.15
	m.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX
	return m


static func feuillage() -> StandardMaterial3D:
	var m := surface(0.98)
	# Le MultiMesh porte ses couleurs par instance.
	m.vertex_color_use_as_albedo = true
	m.cull_mode = BaseMaterial3D.CULL_BACK
	return m


## Le décor : lumière fixe et calme. « Pas de météo d'ambiance, pas de golden
## hour, pas de ciel gris » (Direction artistique l.69). Ce qui creuse les
## volumes n'est pas la lumière, c'est l'occlusion — bakée en couleur de
## sommet par 07, et complétée ici par le SSAO.
static func environnement(ciel: Color, ambiant: Color) -> Environment:
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = ciel
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = ambiant
	e.ambient_light_energy = 0.85

	e.ssao_enabled = true
	e.ssao_radius = 2.0
	e.ssao_intensity = 2.4
	e.ssao_power = 1.5
	e.ssao_detail = 0.5

	# ⚠ Le SSAO travaille en espace vue ; son rayon ne se comporte pas
	# pareil en projection orthographique. Si c'est cassé à l'écran, l'AO
	# bakée par 07 tient debout seule — c'est pour ça qu'elle est la
	# fondation et le SSAO le complément, et pas l'inverse.
	return e
