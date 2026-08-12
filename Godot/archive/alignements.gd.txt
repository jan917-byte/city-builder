extends MultiMeshInstance3D
# Les arbres d'alignement, et leur croissance.
#
# C'est le SEUL endroit du prototype où le temps se voit sans lire un chiffre.
# Tout le reste — canopée, surchauffe, budget — se lit dans l'interface ; ici
# ça pousse.
#
# 07 exporte TOUS les emplacements plantables (1 278) avec, chacun, le seuil de
# canopée à partir duquel il est occupé. La position ne dépend donc pas de la
# densité : un arbre planté reste où il est, et les suivants se glissent entre.
# Avant, faire monter la canopée redistribuait tout l'alignement d'un coup.
#
# Un MultiMesh = UN draw call quelle que soit la quantité. C'est exactement
# l'usage que `Génération procédurale.md:74` lui réserve — et c'est pour ça que
# les 69 îlots, eux, n'en ont pas : ce sont 69 formes distinctes.

# De combien la canopée doit dépasser le seuil d'un emplacement pour que son
# arbre soit adulte. Sans cette marge, les arbres apparaîtraient à taille
# adulte d'un seul coup — ce qui est précisément ce qu'on ne veut pas montrer.
const MARGE_CROISSANCE := 0.06

var _slots := []           # [{fid, base: Transform3D, seuil, ech}]
var _par_fid := {}         # fid -> [index dans _slots]
var _dernier := {}         # fid -> dernière canopée appliquée
var visibles := 0


func batir(alignements: Dictionary, feuillage: Color) -> void:
	var blob := SphereMesh.new()
	blob.radius = 3.0
	blob.height = 7.0
	blob.radial_segments = 6
	blob.rings = 3

	for cle in alignements:
		var fid := int(cle)
		_par_fid[fid] = []
		for a in (alignements[cle] as Array):
			var t := Transform3D(Basis(), Vector3.ZERO)
			t = t.rotated(Vector3.UP, float(a[4]))
			# L'origine est posée SUR le sol ; l'échelle s'appliquera autour
			# d'elle, donc l'arbre grandit depuis sa base et ne s'enfonce pas.
			t.origin = Vector3(float(a[0]), float(a[1]), float(a[2]))
			_par_fid[fid].append(_slots.size())
			_slots.append({
				"fid": fid, "base": t, "seuil": float(a[5]), "ech": float(a[3]),
			})

	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = blob
	mm.instance_count = _slots.size()
	multimesh = mm

	for k in _slots.size():
		var s: Dictionary = _slots[k]
		# Une variation de VALEUR, pas de teinte : « les teintes sont fixes »
		# (Direction artistique l.67).
		var f: float = 0.88 + 0.24 * fmod(abs(s["seuil"]) * 37.0, 1.0)
		mm.set_instance_color(k, Color(feuillage.r * f, feuillage.g * f,
			feuillage.b * f))
		_poser(k, 0.0)
	print("  Aligne.  %d emplacements sur %d tronçons plantables"
		% [_slots.size(), _par_fid.size()])


## Met à jour les tronçons dont la canopée a bougé, et eux seuls. Repasser sur
## les 1 278 emplacements à chaque image coûterait plus cher que tout le reste
## de la scène réunie.
func rafraichir(ville, t: float) -> void:
	for fid in _par_fid:
		var can: float = ville.valeur("r", fid, "canopee", t)
		if absf(can - float(_dernier.get(fid, -1.0))) < 0.0005:
			continue
		_dernier[fid] = can
		for k in _par_fid[fid]:
			_poser(k, can)
	visibles = 0
	for s in _slots:
		if float(_dernier.get(s["fid"], 0.0)) >= s["seuil"]:
			visibles += 1


func _poser(k: int, canopee: float) -> void:
	var s: Dictionary = _slots[k]
	var pousse: float = clampf(
		(canopee - float(s["seuil"])) / MARGE_CROISSANCE, 0.0, 1.0)
	var t: Transform3D = s["base"]
	if pousse <= 0.0:
		# Échelle nulle : l'instance existe toujours, elle ne se voit plus.
		# Moins cher que redimensionner le MultiMesh à chaque plantation.
		multimesh.set_instance_transform(k, t.scaled_local(Vector3.ZERO))
		return
	var e: float = float(s["ech"]) * pousse
	var h: float = 7.0 * 0.42 * e     # le centre du blob monte d'un demi-blob
	var p := t
	p.origin += Vector3(0.0, h, 0.0)
	multimesh.set_instance_transform(k, p.scaled_local(Vector3(e, e, e)))
