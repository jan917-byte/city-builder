extends SceneTree
## Godot --headless --path Godot --script res://outils/essai_trafic.gd
const Trafic := preload("res://scripts/trafic.gd")
const Ville := preload("res://scripts/ville.gd")
const Donnees := preload("res://scripts/donnees.gd")
var echecs := 0

func verifier(ok: bool, message: String) -> void:
	if not ok:
		echecs += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("executer")

func executer() -> void:
	var d := Donnees.charger()
	var ville := Ville.new()
	ville.charger(d)
	var trafic := Trafic.new()
	root.add_child(trafic)
	trafic.set_process(false)
	trafic.batir(d, ville)
	for fermees in [{}, {55: true}, {55: true, 54: true, 21: true}]:
		plus_courts(trafic, fermees)
	for fermees in [{}, {55: true}, {55: true, 54: true, 21: true}, ville.routes]:
		trafic._fermees = fermees.duplicate()
		var t := Time.get_ticks_usec()
		trafic._maj_roulantes(0.0, true)
		print("  raccord après %d fermetures : %.1f ms" % [fermees.size(),
			(Time.get_ticks_usec() - t) / 1000.0])
		circuits(trafic)
	trafic._fermees.clear()
	trafic._maj_roulantes(0.0, true)
	trafic._semer_circuit()
	trafic._process(8.0)
	var grands_pas := []
	for a in trafic._roulantes:
		grands_pas.append([a["arc"], float(a["phase"]) + trafic._temps_trafic * float(a["v"])])
	trafic._semer_circuit()
	for i in 480:
		trafic._process(1.0 / 60.0)
	for k in grands_pas.size():
		var a: Dictionary = trafic._roulantes[k]
		verifier(a["arc"] == grands_pas[k][0], "Le trajet dépend du nombre d'images")
		verifier(absf(float(a["phase"]) + trafic._temps_trafic * float(a["v"])
			- float(grands_pas[k][1])) < 0.02, "Distance perdue sur une image lente")
	anneau()
	print("TRAFIC : chemins de référence, fermetures, raccords et pas de temps : %d échec(s)" % echecs)
	trafic.free()
	quit(1 if echecs else 0)

func circuits(t: Node) -> void:
	var recus := {}
	for e in t._arc_L.size():
		var f: int = t._suivant(e)
		verifier(t._arc_tete[e] == t._arc_tete[t._arc_inverse[f]], "Sortie déconnectée")
		if not t._indispo_courant.has(t._arc_fid[e]):
			verifier(not t._indispo_courant.has(t._arc_fid[f]), "Entrée dans une rue fermée")
			recus[f] = int(recus.get(f, 0)) + 1
		var courbe: Curve3D = t._courbe_arc(e)
		var suivante: Curve3D = t._courbe_arc(f)
		var fin := courbe.sample_baked(courbe.get_baked_length(), true)
		verifier(fin.distance_to(suivante.sample_baked(0.0, true)) < 0.001,
			"Saut de position au carrefour")
		verifier(is_finite(t._arc_L[e]) and t._arc_L[e] > 0.0, "Trajet de longueur invalide")
	for e in t._arc_L.size():
		if not t._indispo_courant.has(t._arc_fid[e]):
			verifier(int(recus.get(e, 0)) == 1, "Une fermeture concentre les circuits")

## Oracle volontairement simple : relaxation complète, sans tas ni arbre de flux.
func plus_courts(t: Node, fermees: Dictionary) -> void:
	var n: int = t._deb.size() - 1
	var bloquees := PackedByteArray()
	bloquees.resize(t._vers.size())
	for e in bloquees.size():
		bloquees[e] = 1 if fermees.has(t._fid_arete[e]) else 0
	for src in range(0, n, 11):
		var attendu := PackedFloat64Array()
		attendu.resize(n)
		attendu.fill(INF)
		attendu[src] = 0.0
		for tour in n - 1:
			var change := false
			for u in n:
				for e in range(t._deb[u], t._deb[u + 1]):
					if bloquees[e] == 1:
						continue
					var v: int = t._vers[e]
					var nd: float = attendu[u] + t._temps[e]
					if nd < attendu[v]:
						attendu[v] = nd
						change = true
			if not change:
				break
		var obtenu: Array = t._dijkstra(src, bloquees)
		for v in n:
			if fermees.is_empty() and v != src and is_finite(attendu[v]):
				verifier(t._t_ref.has(src * n + v), "Référence des détours incomplète")
			verifier((is_inf(attendu[v]) and is_inf(obtenu[2][v]))
				or absf(attendu[v] - float(obtenu[2][v])) < 0.00001,
				"Chemin plus court manqué ou fermeture ignorée")

func anneau() -> void:
	var t := Trafic.new()
	t.ville = Ville.new()
	t.ville.routes = {1: {"hierarchie": "rue"}}
	t._batir_graphe({"1": [[], [[0, 0, 20, 0, 20, 20, 0, 20, 0, 0]]]})
	verifier(t._deb.size() == 2 and t._vers.size() == 2, "L'anneau isolé disparaît")
	verifier(absf(t._temps[0] - 9.6) < 0.001, "Longueur de l'anneau perdue")
	t.free()
	t = Trafic.new()
	t.ville = Ville.new()
	t.ville.routes = {1: {"hierarchie": "rue"}, 2: {"hierarchie": "rue"}}
	t._batir_graphe({"1": [[], [[0, 0, 20, 0]]], "2": [[], [[20, 0, 40, 0]]]})
	t._affectation({}, true)
	verifier(t._t_ref.has(3) and absf(float(t._t_ref.get(3, INF)) - 2.4) < 0.001,
		"Le nœud de degré 2 n'a pas de référence avant fermeture")
	t.free()
