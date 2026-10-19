extends SceneTree
## Godot --path Godot --script res://outils/apercu_batiments_cour.gd -- --reperes=<json> [--avant]
## 🏚️ Les bâtiments de cour (2026-10-19) : six cœurs d'îlot vus de haut, chaque
## bâtiment de cour numéroté par son fid. `--reperes` : [[fid, x, z], …] en repère Godot.

func _initialize() -> void:
	call_deferred("capturer")

func capturer() -> void:
	var avant := false
	var reperes := []
	for a in OS.get_cmdline_user_args():
		if a == "--avant":
			avant = true
		elif a.begins_with("--reperes="):
			reperes = JSON.parse_string(FileAccess.get_file_as_string(a.get_slice("=", 1)))
	var jeu = load("res://maquette.tscn").instantiate()
	root.add_child(jeu)
	jeu.vitesse = 0.0
	jeu.mois = 6.0
	jeu.interface.hide()
	jeu.moniteur_performances.hide()
	jeu.paysage.mat_nuages.set_shader_parameter("horloge", 0.0)
	for r in reperes:
		var l := Label3D.new()
		l.text = str(int(r[0]))
		l.position = Vector3(float(r[1]), 22.0, float(r[2]))
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.no_depth_test = true
		l.fixed_size = true
		l.pixel_size = 0.0018
		l.font_size = 30
		l.outline_size = 10
		l.modulate = Color("b3261e")
		root.add_child(l)
	var couche := CanvasLayer.new()
	root.add_child(couche)
	var label := Label.new()
	label.position = Vector2(24, 24)
	label.add_theme_font_size_override("font_size", 26)
	label.add_theme_color_override("font_color", Color("213d36"))
	var fond := StyleBoxFlat.new()
	fond.bg_color = Color("f5f5ec")
	fond.content_margin_left = 14
	fond.content_margin_right = 14
	fond.content_margin_top = 8
	fond.content_margin_bottom = 8
	label.add_theme_stylebox_override("normal", fond)
	couche.add_child(label)
	await process_frame
	jeu._rafraichir(true)
	# [îlot, lacet, hauteur, taille]
	for vue in [[15, 30.0, 55.0, 90.0], [23, 30.0, 55.0, 110.0], [33, 30.0, 55.0, 100.0],
			[62, 30.0, 55.0, 90.0], [66, 30.0, 55.0, 90.0], [72, 30.0, 55.0, 90.0]]:
		jeu._viser_objet("i", int(vue[0]), float(vue[3]))
		jeu.pivot.caler(float(vue[1]), float(vue[2]))
		jeu.trafic.regler_detail(jeu.pivot.taille)
		jeu._dernier_peint = -1.0
		jeu._rafraichir(true)
		label.text = "îlot %d · %s" % [vue[0], "avant" if avant else "après"]
		for frame in 6:
			await process_frame
			await RenderingServer.frame_post_draw
		await jeu._capturer("cour_%d_%s" % [vue[0], "avant" if avant else "apres"])
	quit()
