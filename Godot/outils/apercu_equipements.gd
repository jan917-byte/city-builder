extends SceneTree
## Godot --path Godot --script res://outils/apercu_equipements.gd -- [avant]

func _initialize() -> void:
	call_deferred("capturer")

func capturer() -> void:
	var jeu = load("res://maquette.tscn").instantiate()
	root.add_child(jeu)
	jeu.vitesse = 0.0
	jeu.mois = 0.0
	jeu.interface.hide()
	jeu.moniteur_performances.hide()
	jeu.horloge_trafic.stop()
	jeu.trafic.set_process(false)
	var couche := CanvasLayer.new()
	root.add_child(couche)
	var label := Label.new()
	label.position = Vector2(28, 24)
	label.add_theme_font_size_override("font_size", 28)
	label.add_theme_color_override("font_color", Color("213d36"))
	var fond := StyleBoxFlat.new()
	fond.bg_color = Color("f5f5ec")
	fond.content_margin_left = 12
	fond.content_margin_right = 12
	fond.content_margin_top = 8
	fond.content_margin_bottom = 8
	label.add_theme_stylebox_override("normal", fond)
	couche.add_child(label)
	var suffixe := "avant" if "avant" in OS.get_cmdline_user_args() else "apres"
	for vue in [[36, "1 · Université", 150.0], [20, "2 · Mairie", 90.0], [16, "3 · Église", 80.0]]:
		var mi: MeshInstance3D = jeu.noeuds["i"][vue[0]]
		var centre := mi.get_aabb().get_center()
		jeu.pivot.viser(Vector2(centre.x, centre.z), vue[2])
		jeu.pivot.position.y = 7.0
		jeu.pivot.caler(30.0, 35.0)
		label.text = vue[1]
		for image in 4:
			await process_frame
			await RenderingServer.frame_post_draw
		await jeu._capturer("equipement_%d_%s" % [vue[0], suffixe])
		if suffixe == "apres":
			jeu.pivot.caler(210.0 if vue[0] == 20 else 30.0, 32.0)
			jeu.pivot.viser(Vector2(centre.x, centre.z), 100.0 if vue[0] == 36 else 50.0)
			jeu.pivot.position.y = 7.0
			await process_frame
			await jeu._capturer("equipement_%d_detail" % vue[0])
			jeu.interface.montrer("i", vue[0], false)
			jeu._maj_apercu()
			await jeu._capturer_apercu("equipement_%d_miniature" % vue[0])
	quit()
