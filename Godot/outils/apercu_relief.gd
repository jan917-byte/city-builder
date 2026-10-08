extends SceneTree
## Godot --path Godot --script res://outils/apercu_relief.gd -- [--avant]
## Fenêtres en creux et balcons en saillie, peints par le shader (2026-10-08) :
## quatre cadrages de près puis de loin, et ce que ça coûte par image.

func _initialize() -> void:
	call_deferred("capturer")

func capturer() -> void:
	var jeu = load("res://maquette.tscn").instantiate()
	root.add_child(jeu)
	jeu.vitesse = 0.0
	jeu.mois = 0.0
	jeu.interface.hide()
	jeu.moniteur_performances.hide()
	# Les ombres de nuages bougent : figées, avant et après ont la même lumière.
	jeu.paysage.mat_nuages.set_shader_parameter("horloge", 0.0)
	var args := OS.get_cmdline_user_args()
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
	var suffixe := "avant" if "--avant" in args else "apres"
	await process_frame
	jeu._rafraichir(true)
	# [nom, légende, îlot, lacet, hauteur, taille]
	var vues := [
		["1_compact", "1 · Îlot compact 49 · balcons", 49, 30.0, 22.0, 45.0],
		["2_collectif", "2 · Collectifs de 1995 · îlot 60", 60, 30.0, 24.0, 55.0],
		["3_coeur", "3 · Cœur ancien · îlot 15", 15, 120.0, 22.0, 45.0],
		["4_moyen", "4 · Vue moyenne", 62, 30.0, 30.0, 220.0],
	]
	for vue in vues:
		jeu._viser_objet("i", int(vue[2]), float(vue[5]))
		jeu.pivot.caler(float(vue[3]), float(vue[4]))
		jeu._dernier_peint = -1.0
		jeu._rafraichir(true)
		label.text = vue[1]
		for frame in 6:
			await process_frame
			await RenderingServer.frame_post_draw
		await jeu._capturer("relief_%s_%s" % [vue[0], suffixe])

	# Le banc : même cadrage, vsync levé, le GPU seul départage.
	label.hide()
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var vp_rid := root.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(vp_rid, true)
	for vue in [["de près", 49, 30.0, 22.0, 45.0], ["ville entière", 62, 30.0, 32.0, 900.0]]:
		jeu._viser_objet("i", int(vue[1]), float(vue[4]))
		jeu.pivot.caler(float(vue[2]), float(vue[3]))
		jeu._rafraichir(true)
		for frame in 30:
			await process_frame
		var gpu := 0.0
		var t0 := Time.get_ticks_usec()
		for frame in 300:
			await process_frame
			gpu += RenderingServer.viewport_get_measured_render_time_gpu(vp_rid)
		print("relief %s · %-14s %6.2f ms/image · GPU %5.2f ms" % [suffixe, vue[0],
			(Time.get_ticks_usec() - t0) / 300000.0, gpu / 300.0])
	quit()
