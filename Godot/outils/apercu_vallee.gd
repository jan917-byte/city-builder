extends SceneTree
## Godot --path Godot --script res://outils/apercu_vallee.gd
func _initialize() -> void:
	call_deferred("capturer")

func capturer() -> void:
	var jeu = load("res://maquette.tscn").instantiate()
	root.add_child(jeu)
	jeu.vitesse = 0.0
	jeu.mois = 0.0
	jeu.interface.hide()
	jeu.moniteur_performances.hide()
	jeu.paysage.mat_nuages.set_shader_parameter("horloge", 0.0)
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
	var reperes: Array[Label] = []
	for k in 4:
		var numero := Label.new()
		numero.text = str(k + 1)
		numero.add_theme_font_size_override("font_size", 23)
		numero.add_theme_color_override("font_color", Color("213d36"))
		numero.add_theme_stylebox_override("normal", fond)
		couche.add_child(numero)
		reperes.append(numero)
	for vue in [["ensemble", 30.0, 32.0, 1550.0, "1 · Ville  →  2 · Champs  →  3 · Forêt  →  4 · Montagnes"],
			["inverse", 210.0, 32.0, 1550.0, "Vallée · versant opposé"],
			["panorama", 30.0, 25.0, 2200.0, "Wehrau · une ville dans sa vallée"],
			["dessus", 0.0, 90.0, 1500.0, "Vallée · raccords et cours de l’Ilse"],
			["proche", 30.0, 32.0, 650.0, "Ville · les quartiers restent lisibles"]]:
		jeu.pivot.viser(Vector2.ZERO, vue[3])
		jeu.pivot.caler(vue[1], vue[2])
		label.text = vue[4]
		var points := [Vector3(0, 20, 0), Vector3(-300, 3, 220),
			Vector3(-690, 60, 0), Vector3(-1100, 280, -400)]
		for k in 4:
			reperes[k].visible = vue[0] in ["ensemble", "panorama"]
			var ecran: Vector2 = jeu.pivot.camera.unproject_position(points[k])
			reperes[k].position = Vector2(clampf(ecran.x, 24, root.size.x - 64),
				clampf(ecran.y, 110, root.size.y - 64))
		for frame in 5:
			await process_frame
			await RenderingServer.frame_post_draw
		await jeu._capturer("vallee_" + vue[0])
		if vue[0] == "ensemble":
			jeu.paysage.mat_nuages.set_shader_parameter("horloge", 40.0)
			await jeu._capturer("vallee_nuages_40s")
			jeu.paysage.mat_nuages.set_shader_parameter("horloge", 0.0)
	label.text = "Diagnostic · le paysage s’efface"
	jeu._habiller_monde(true)
	assert(not jeu.paysage.visible)
	await jeu._capturer("vallee_diagnostic")
	jeu._habiller_monde(false)
	assert(jeu.paysage.visible)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	jeu.pivot.viser(Vector2.ZERO, 1200.0)
	jeu.pivot.caler(30.0, 32.0)
	for visible in [false, true]:
		jeu.paysage.visible = visible
		for frame in 30:
			await process_frame
		var debut := Time.get_ticks_usec()
		for frame in 120:
			await process_frame
		print("Vallée · décor %s : %.2f ms/image" % [visible, (Time.get_ticks_usec()-debut)/120000.0])
	print("Vallée : cinq cadrages rendus, diagnostic et retour validés.")
	quit()
