extends SceneTree
## Godot --path Godot --script res://outils/apercu_crue_ponts.gd

func _initialize() -> void:
	call_deferred("capturer")

func capturer() -> void:
	var jeu = load("res://maquette.tscn").instantiate()
	root.add_child(jeu)
	jeu.set_process(false)
	jeu.vitesse = 0.0
	jeu.interface.hide()
	jeu.moniteur_performances.hide()
	jeu.horloge_trafic.stop()
	jeu.trafic.set_process(false)
	var sans_ombre := "sans_ombre" in OS.get_cmdline_user_args()
	if sans_ombre:
		for e in jeu.get_children():
			if e is DirectionalLight3D:
				e.shadow_enabled = false
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
	for vue in [
		["1 · Dépôt de crue", "boue_centre", Vector2(75.12, -9.75), 105.0, 200.0, 38.0],
		["2 · Pont détruit", "pont_casse", Vector2(216.0, 67.0), 72.0, 200.0, 27.0],
		["3 · Pont reconstruit", "pont_neuf", Vector2(216.0, 67.0), 72.0, 200.0, 27.0],
		["4 · Bord du dépôt", "boue_rive", Vector2(200.0, -72.0), 110.0, 20.0, 32.0]]:
		if vue[1] == "pont_neuf":
			jeu.ville.crediter_essai_ke(20000.0)
			for fid in jeu.ruines_ponts:
				jeu.ville.reparer("r", fid, 0.0)
			jeu.mois = 60.0
			jeu._rafraichir(true)
			for fid in jeu.ruines_ponts:
				assert(not jeu.ruines_ponts[fid].visible, "Les débris doivent disparaître")
				assert(jeu.reparations["r"][fid].visible, "Le pont doit être livré")
		jeu.pivot.viser(vue[2], vue[3])
		jeu.pivot.position.y = 0.0
		jeu.pivot.caler(vue[4], vue[5])
		label.text = vue[0]
		for frame in 6:
			await process_frame
			await RenderingServer.frame_post_draw
		await jeu._capturer(vue[1] + ("_sans_ombre" if sans_ombre else ""))
		if vue[1] in ["pont_casse", "pont_neuf"] and not sans_ombre:
			var neuf: bool = vue[1] == "pont_neuf"
			jeu.apercu.montrer(jeu.noeuds["r"][168].mesh,
				jeu.reparations["r"][168].mesh, null,
				jeu.ruines_ponts[168].mesh)
			jeu.apercu.regler(0.0, 0.0, 0.0, neuf, 0.0)
			jeu.apercu.viser(200.0)
			await jeu._capturer_apercu("miniature_" + vue[1])
			for fid in [145, 169]:
				var centre: Vector3 = jeu.ruines_ponts[fid].mesh.get_aabb().get_center()
				jeu.pivot.viser(Vector2(centre.x, centre.z), 88.0)
				jeu.pivot.caler(200.0, 32.0)
				label.text = "%s · Pont %d" % ["3" if neuf else "2", fid]
				for frame in 4:
					await process_frame
					await RenderingServer.frame_post_draw
				await jeu._capturer("%s_%d" % [vue[1], fid])
			if neuf:
				jeu.pivot.viser(Vector2(216.0, 67.0), 72.0)
				jeu.pivot.caler(20.0, 38.0)
				label.text = "5 · Raccords, vue opposée"
				for frame in 4:
					await process_frame
					await RenderingServer.frame_post_draw
				await jeu._capturer("pont_raccords_inverse")
	quit()
