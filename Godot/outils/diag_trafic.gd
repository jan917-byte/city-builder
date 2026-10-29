extends SceneTree
## Godot --headless --path Godot --script res://outils/diag_trafic.gd
## Deux minutes de trafic au mois 0, la pulsation au rythme du jeu (×1) : compte
## les voitures qui s'allument ou s'éteignent hors carrefour, les contacts entre
## voitures visibles, et la vitesse la plus basse des virages. Mesure, n'échoue pas.
const Trafic := preload("res://scripts/trafic.gd")
const Ville := preload("res://scripts/ville.gd")
const Donnees := preload("res://scripts/donnees.gd")
const DUREE := 120.0
const PAS := 1.0 / 30.0
## 3 s entre deux `avancer`, soit 0,03 mois à 90 s le mois (maquette.MOIS_PAR_SECONDE).
const PULSATION := 3.0
## Bord du carrefour : la courbe démarre 4 m avant le nœud (`_courbe_arc`).
const BORD := 6.0


func _initialize() -> void:
	call_deferred("executer")


func executer() -> void:
	var d := Donnees.charger()
	var ville := Ville.new()
	ville.charger(d)
	var t := Trafic.new()
	root.add_child(t)
	t.set_process(false)
	var t0 := Time.get_ticks_msec()
	t.batir(d, ville)
	print("  bâtir le trafic : %d ms" % (Time.get_ticks_msec() - t0))
	# 🐢 La vitesse la plus basse de chaque arc, rangée par manœuvre à son bout.
	var par := {}
	for e in t._arc_L.size():
		if t._indispo_courant.has(t._arc_fid[e]):
			continue
		var f: int = t._arc_suivant[e]
		var u: Vector2 = t._arc_dir[e]
		var w: Vector2 = t._arc_dir[f]
		var genre := "tout droit"
		if f == t._arc_inverse[e]:
			genre = "demi-tour"
		elif u.dot(w) < 0.7:
			genre = "à droite" if u.cross(w) > 0.0 else "à gauche"
		var hier := str(ville.routes[t._arc_fid[e]].get("hierarchie", "rue"))
		if hier != "rue":
			continue
		var l: Array = par.get(genre, [])
		l.append(Array(t._profils[e]).min() * 3.6)
		par[genre] = l
	for genre in par:
		var l: Array = par[genre]
		l.sort()
		print("  rue à 30 km/h, %s : %d arcs, au plus lent %.0f km/h (médiane)" % [genre, l.size(), l[l.size() / 2]])
	var n: int = t._roulantes.size()
	var vus := t._visibles_roule.duplicate()
	var apparitions := [0, 0]
	var effacements := [0, 0]
	var contacts := {}
	var genres := {}
	var images := 0
	var prochaine := PULSATION
	var temps := 0.0
	while temps < DUREE:
		t._process(PAS)
		temps += PAS
		images += 1
		if temps >= prochaine:
			prochaine += PULSATION
			t._maj_roulantes(t._mois + 0.0001, false)
		for k in n:
			if t._visibles_roule[k] == vus[k]:
				continue
			var bord := _au_carrefour(t, k)
			if t._visibles_roule[k] == 1:
				apparitions[0 if bord else 1] += 1
			else:
				effacements[0 if bord else 1] += 1
		vus = t._visibles_roule.duplicate()
		if images % 6 != 0:
			continue
		var poses := []
		var grille := {}
		for k in n:
			if t._visibles_roule[k] == 0:
				poses.append(null)
				continue
			var p := _pose(t, k)
			poses.append(p)
			var c := Vector2i(floori(p[0].x / 6.0), floori(p[0].y / 6.0))
			var l: Array = grille.get(c, [])
			l.append(k)
			grille[c] = l
		for k in n:
			if poses[k] == null:
				continue
			var pk: Array = poses[k]
			var c := Vector2i(floori(pk[0].x / 6.0), floori(pk[0].y / 6.0))
			for dx in range(-1, 2):
				for dz in range(-1, 2):
					for j in (grille.get(c + Vector2i(dx, dz), []) as Array):
						if j <= k:
							continue
						var pj: Array = poses[j]
						var ecart: Vector2 = pj[0] - pk[0]
						var long := absf(ecart.dot(pk[1]))
						var trav := absf(ecart.dot(Vector2(pk[1].y, -pk[1].x)))
						if long < 3.2 and trav < 1.6:
							var cle: int = k * 100000 + int(j)
							if not contacts.has(cle):
								contacts[cle] = true
								var ek := int((t._roulantes[k] as Dictionary)["arc"])
								var ej := int((t._roulantes[j] as Dictionary)["arc"])
								var genre := "croisement"
								if ek == ej:
									genre = "même arc"
								elif t._arc_suivant[ek] == ej or t._arc_suivant[ej] == ek:
									genre = "arc suivant"
								elif (pk[1] as Vector2).dot(pj[1]) > 0.7:
									genre = "même sens, autre arc"
								genres[genre] = int(genres.get(genre, 0)) + 1
	var visibles := 0
	for v in t._visibles_roule:
		visibles += v
	print("DIAG TRAFIC sur %d s : %d voitures visibles sur %d en circuit" % [int(DUREE), visibles, n])
	print("  apparitions : %d au carrefour, %d en pleine rue" % apparitions)
	print("  effacements : %d au carrefour, %d en pleine rue" % effacements)
	print("  contacts : %d paires — %s" % [contacts.size(), genres])
	t.free()
	quit(0)


func _avance(t: Node, k: int) -> float:
	var a: Dictionary = t._roulantes[k]
	return clampf(float(a["phase"]) + t._temps_trafic * float(a["v"]), 0.0, t._arc_L[int(a["arc"])])


func _au_carrefour(t: Node, k: int) -> bool:
	var e := int((t._roulantes[k] as Dictionary)["arc"])
	var s := _avance(t, k)
	return s < BORD or t._arc_L[e] - s < BORD


## La pose que le shader calcule, recopiée : [position xz, direction xz].
func _pose(t: Node, k: int) -> Array:
	var e := int((t._roulantes[k] as Dictionary)["arc"])
	var s: float = _avance(t, k) / t._arc_L[e] * float(t.PAS_COURBE - 1)
	var i: int = mini(int(floor(s)), t.PAS_COURBE - 2)
	var f: float = s - float(i)
	var base: int = (e * t.PAS_COURBE + i) * 4
	var px: PackedFloat32Array = t._trajets_pixels
	var loc := Vector3(lerpf(px[base], px[base + 4], f), 0.0, lerpf(px[base + 1], px[base + 5], f))
	var dir := Vector3(lerpf(px[base + 2], px[base + 6], f), 0.0, lerpf(px[base + 3], px[base + 7], f))
	var tr: Transform3D = t._arc_t[e]
	var p := tr * loc
	var u := (tr.basis * dir)
	return [Vector2(p.x, p.z), Vector2(u.x, u.z).normalized()]
