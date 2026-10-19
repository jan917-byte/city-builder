extends RefCounted
# 🔥 La fumée des souches : retrouvées dans le maillage de 07 à leur teinte, comme
# la maquette blanche les efface (`materiaux.gd`). Un nœud par îlot, ENFANT de son
# maillage : il se cache avec lui. La bouffée vit dans `fumee.gdshader`.

const SHADER := preload("res://shaders/fumee.gdshader")
const BOUFFEES := 6                              # par souche, étalées sur la vie d'une bouffée
const TEINTE := Vector3(0.198, 0.133, 0.100)     # PAL.CHEMINEE #7B6659 en linéaire

static var compte := 0
static var _quad: QuadMesh
static var _mat: ShaderMaterial


## Les souches d'une tranche de maillage, en bouffées ; null s'il n'y en a pas.
static func noeud(d: Dictionary, debut: int, nb: int) -> MultiMeshInstance3D:
	var vs: PackedVector3Array = d["v"]
	var cs: PackedColorArray = d["c"]
	var uvs: PackedVector2Array = d.get("uv", PackedVector2Array())
	var denses: PackedFloat32Array = d.get("dense", PackedFloat32Array())
	var idx: PackedInt32Array = d["i"]
	var vus := {}
	var souches: Array = []   # [somme x, somme z, n, haut, rang, suit]
	for k in nb:
		var s: int = idx[debut + k]
		if vus.has(s):
			continue
		vus[s] = true
		var c := cs[s]
		if Vector3(c.r, c.g, c.b).distance_to(TEINTE) > 0.01:
			continue
		if not uvs.is_empty() and uvs[s].length_squared() >= 0.01:
			continue
		# Sans canal (le maillage réparé), rang 1e6 : du bâti neuf, comme dans 07.
		var rang := 1.0e6 if denses.is_empty() else denses[s * 4]
		var suit := 0.0 if denses.is_empty() else denses[s * 4 + 1]
		if not denses.is_empty() and denses[s * 4 + 2] < -0.5:
			continue   # une ruine ne fume pas
		var p := vs[s]
		var la: Array = []
		for e in souches:
			if Vector2(e[0] / e[2] - p.x, e[1] / e[2] - p.z).length() < 1.2:
				la = e
				break
		if la.is_empty():
			souches.append([p.x, p.z, 1.0, p.y, rang, suit])
			continue
		la[0] += p.x
		la[1] += p.z
		la[2] += 1.0
		if p.y > la[3]:
			la[3] = p.y
			la[4] = rang
			la[5] = suit
	if souches.is_empty():
		return null
	if _mat == null:
		_quad = QuadMesh.new()
		_mat = ShaderMaterial.new()
		_mat.shader = SHADER
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = _quad
	mm.instance_count = souches.size() * BOUFFEES
	var rng := RandomNumberGenerator.new()
	var j := 0
	for e in souches:
		var o := Vector3(e[0] / e[2], e[3], e[1] / e[2])
		# Tiré du LIEU (35) : mêmes souches allumées aux mêmes froids.
		rng.seed = hash(Vector2i(roundi(o.x * 10.0), roundi(o.z * 10.0)))
		var phase := rng.randf()
		var seuil := rng.randf() * 0.9
		for b in BOUFFEES:
			mm.set_instance_transform(j, Transform3D(Basis(), o))
			mm.set_instance_custom_data(j, Color(e[4], e[5],
				fposmod(phase + float(b) / BOUFFEES, 1.0), seuil))
			j += 1
	compte += souches.size()
	var mi := MultiMeshInstance3D.new()
	mi.name = "Fumee"
	mi.multimesh = mm
	mi.material_override = _mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.extra_cull_margin = 16.0   # la bouffée monte de 8 m et part de 12 au vent
	mi.add_to_group("fumees")
	return mi
