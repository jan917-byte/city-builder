extends SceneTree
## Godot --path Godot --script res://outils/apercu_berges.gd -- [avant]

func _initialize() -> void:
	call_deferred("capturer")

func capturer() -> void:
	var jeu = load("res://maquette.tscn").instantiate()
	root.add_child(jeu)
	jeu.vitesse = 0.0
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
	for etat in [0, 2]:
		if etat == 2:
			jeu.ville.crediter_essai_ke(20000.0)
			for fid in jeu.ville.berges:
				jeu.ville.transformer_berge(fid, 2, 0.0)
			jeu.mois = 30.0
			jeu._rafraichir(true)
		for vue in [
			["1 · Quai du centre", "centre", Vector2(75.12, -9.75), 105.0, 200.0, 38.0],
			["2 · Raccord du pont", "raccord", Vector2(238.53, 36.75), 100.0, 200.0, 38.0],
			["3 · Rive des champs", "champs", Vector2(378.9, 376.72), 150.0, 200.0, 24.0],
			["4 · Rive opposée", "gauche", Vector2(200.0, -72.0), 110.0, 20.0, 32.0]]:
			jeu.pivot.viser(vue[2], vue[3])
			jeu.pivot.position.y = 0.0
			jeu.pivot.caler(vue[4], vue[5])
			label.text = vue[0] + (" · Renaturée" if etat == 2 else " · Départ")
			for frame in 4:
				await process_frame
				await RenderingServer.frame_post_draw
			await jeu._capturer("rive_%s_%d_%s" % [vue[1], etat, suffixe])
	quit()
