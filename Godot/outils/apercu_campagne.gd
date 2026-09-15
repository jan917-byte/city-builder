extends SceneTree
## Trois cadrages fixes pour comparer le SVG, les sorties et les versants.
func _initialize() -> void:
	call_deferred("capturer")

func capturer() -> void:
	var jeu = load("res://maquette.tscn").instantiate()
	root.add_child(jeu)
	jeu.vitesse = 0.0
	jeu.interface.hide()
	jeu.moniteur_performances.hide()
	jeu.paysage.mat_nuages.set_shader_parameter("horloge", 0.0)
	var couche := CanvasLayer.new()
	root.add_child(couche)
	var label := Label.new()
	label.position = Vector2(24, 24)
	label.add_theme_font_size_override("font_size", 24)
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
	var positions := [Vector3(-340, 2, -310), Vector3(-510, 65, -320),
		Vector3(-810, 80, 50), Vector3(820, 80, 50)]
	for texte in ["①", "②", "③a", "③b"]:
		var numero := Label.new()
		numero.text = texte
		numero.add_theme_font_size_override("font_size", 24)
		numero.add_theme_color_override("font_color", Color("213d36"))
		numero.add_theme_stylebox_override("normal", fond)
		couche.add_child(numero)
		reperes.append(numero)
	var suffixe := "avant" if "--avant" in OS.get_cmdline_user_args() else "apres"
	for vue in [["dessus", 0.0, 90.0, 2800.0, "① Champs du SVG · ② Sorties de ville · ③ Montagnes"],
			["relief", 30.0, 38.0, 3000.0, "③ Les montagnes prolongent le bord du dessin"],
			["champs", 0.0, 90.0, 1300.0, "① Parcelles agricoles · contours et sens de culture"]]:
		jeu.pivot.viser(Vector2.ZERO, vue[3])
		jeu.pivot.caler(vue[1], vue[2])
		label.text = vue[4]
		for k in reperes.size():
			reperes[k].visible = vue[0] != "champs"
			reperes[k].position = jeu.pivot.camera.unproject_position(positions[k])
		for frame in 5:
			await process_frame
			await RenderingServer.frame_post_draw
		await jeu._capturer("campagne_" + vue[0] + "_" + suffixe)
	print("Campagne : trois cadrages rendus.")
	quit()
