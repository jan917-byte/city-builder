extends SceneTree
## 🔥 LA FUMÉE DES SOUCHES, à juger : le cœur ancien en juillet, novembre et
## janvier (avec et sans neige), même graine, bouffées figées, puis les toits plats. Îlots numérotés.
## Godot --path Godot --position 6000,6000 --script res://outils/apercu_fumee.gd

const Saison := preload("res://scripts/saison.gd")
const Fumees := preload("res://scripts/fumees.gd")

var jeu


func _initialize() -> void:
	call_deferred("capturer")


func capturer() -> void:
	root.size = Vector2i(1600, 1000)
	jeu = load("res://maquette.tscn").instantiate()
	root.add_child(jeu)
	jeu.vitesse = 0.0
	jeu.interface.hide()
	jeu.moniteur_performances.hide()
	if jeu.ouverture != null:
		jeu.ouverture.hide()
		jeu.ouverture._reperes.hide()
		# Le guide recadre la caméra au fil des images : sans ceci, deux vues sur quatre partaient ailleurs.
		jeu.ouverture.process_mode = Node.PROCESS_MODE_DISABLED
	jeu.set_process(false)
	jeu.paysage.mat_nuages.set_shader_parameter("horloge", 0.0)
	(jeu.flocons.material as ShaderMaterial).set_shader_parameter("horloge", 3.0)
	Fumees._mat.set_shader_parameter("horloge", 4.0)
	var s := Saison.new(7)
	jeu.changer_saison(s)
	await process_frame
	for fid in jeu.noeuds["i"]:
		var mi: MeshInstance3D = jeu.noeuds["i"][fid]
		if mi.get_node_or_null("Fumee") == null:
			continue
		var b := mi.get_aabb()
		var l := Label3D.new()
		l.text = str(fid)
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.no_depth_test = true
		l.fixed_size = true
		l.pixel_size = 0.0012
		l.font_size = 26
		l.outline_size = 8
		l.position = b.get_center() + Vector3(0.0, b.size.y * 0.5 + 4.0, 0.0)
		jeu.monde.add_child(l)
	var e: Array = s.neige_hiver(1)
	var neige := (float(e[0]) + Saison.ARRIVEE_MOIS + float(e[1])) * 0.5
	var dates := [
		["1_juillet", 4.5], ["2_novembre", 8.85],
		["3_janvier", float(e[0]) - 0.1], ["4_neige", neige],
	]
	# « plats » : la barre de 1974 et ses voisins, souches des toits plats (2026-10-19).
	for v in [["pres", ["i", 22], 150.0, 32.0, 38.0], ["quartier", ["i", 14], 420.0, 34.0, 38.0],
			["plats", ["i", 32], 170.0, 38.0, 38.0]]:
		for d in dates:
			await _vue(v, d[1])
			await jeu._capturer("fumee_%s_%s" % [v[0], d[0]])
			print("  %s %s : %.1f °C, fumée %.2f" % [v[0], d[0], s.temperature(d[1]), s.fumee(d[1])])
	quit()


func _vue(v: Array, mois: float) -> void:
	jeu.mois = mois
	jeu._viser_objet(v[1][0], int(v[1][1]), float(v[2]))
	jeu.pivot.caler(float(v[3]), float(v[4]))
	jeu._dernier_peint = -1.0
	jeu._rafraichir(true)
	for f in 6:
		await process_frame
		await RenderingServer.frame_post_draw
	jeu.pivot._zoom_actif = false
	jeu._viser_objet(v[1][0], int(v[1][1]), float(v[2]))
	jeu.pivot.caler(float(v[3]), float(v[4]))
	await process_frame
	await RenderingServer.frame_post_draw
